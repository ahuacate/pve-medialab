#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_run.sh
# Description:  Default Kodirsync client run script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

#---- Check script is not already running

# Check for existing running script pid
script_sleep_time=3000  # Script sleep time (sec)
script_cnt_timeout=10  # Script timeout count limit
c=0
while [ 1 ]; do
    # Get current script pid
    pid=$(pgrep -f "$(basename $0)"| grep -x -v $$)

    # Filter non-existent pid(s)
    pid=$(echo "$pid" | xargs -n1 sh -c 'kill -0 "$1" 2>/dev/null && echo "$1"' --)

    if [ -n "$pid" ]; then
        # Print screen msg
        echo -e "Script '"$(basename $0)"' is already running with pid ${pid}.\nTrying again in ${script_sleep_time} seconds (Attempt: $((${c} + 1)) of ${script_cnt_timeout})."

        # Set sleep period or timeout
        ((c++)) && ((c==${script_cnt_timeout})) && exit 0
        sleep $script_sleep_time
    else
        break  # Clear to run script
    fi
done

#---- Static Variables -------------------------------------------------------------

# App dir
app_dir="$DIR"

# SSH dir
ssh_dir="$HOME/.ssh"

# Log file life duration (days)
log_life=14

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

#---- Cleanup trap function
cleanup() {
    # Add cleanup actions here
    rm -Rf "$work_dir" 2> /dev/null

    # Kill any orphaned rsync processes
    rsync_pids=()  # Initialize rsync_pids array
    # Use ps to find the PID of rsync/ssh commands with the specific source file
    escaped_rsync_match=$(printf "%q" "$rsync_username@$rsync_address")
    rsync_pids+=( $(pgrep -f "^(rsync.*$escaped_rsync_match|ssh.*$escaped_rsync_match)") )
    for pid in "${rsync_pids[@]}"; do
        if [ -n "$pid" ]; then
            echo "Killing orphaned PID and its children: $pid"
            kill -TERM "$pid" 2> /dev/null  # Send SIGTERM to the process
            sleep 0.1  # Wait for a moment before sending SIGKILL if needed
            kill -KILL "$pid" 2> /dev/null  # Send SIGKILL to the process
        fi
    done
}

# Set up trap to call the cleanup function on script exit or specific signals
trap cleanup EXIT SIGHUP SIGINT SIGTERM


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create temp work dir
work_dir=$(mktemp -dt -p /tmp kodirsync-XXXXXX)

# Log files
mkdir -p "$app_dir/logs"
now=$(date +"%F")
logfile="$app_dir/logs/kodirsync-${now}.log"

# Remove log files older than $log_life days
find "$app_dir/logs" -name "kodirsync-*.log" -type f -mtime +$log_life -delete

# LAN Network check (1 is UP, other is down)
lan_network_status=$(ip route | grep "linkdown" > /dev/null; echo $?)

# Check LAN network status
if [ ! "$lan_network_status" = 1 ]; then
    # Log Job fail
    echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
    echo -e "#---- WARNING - LAN NETWORK FAIL\nFail Time : $(date)\n" >> ${logfile}
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
fi

# Check if client is Termux or Linux/CoreELEC/LibreELEC
if [ $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]; then
    # Set OS type to Termux
    ostype='termux'
    source $app_dir/kodirsync_clientapp_install_termux_deps.sh  # Install Termux-Android dependencies
elif [ "$(uname)" == "Linux" ] && [ ! $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]; then
    # Set Linux OS type
    ostype=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
else
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync is supported on CoreELEC, LibreELEC, Linux and Termux only.\nBye...\n\e[39m"
    exit 0  # Exit script. OS not supported
fi


# Run Kodirsync Git updater
# Not available to Termux-Android clients 
github_updater=$(sed -n "s/^github_updater=\(['\"]\?\)\(.*\)\1/\2/p" "$app_dir/kodirsync_clientapp_user.cfg")
if [ "$github_updater" = 1 ] && [ ! "$ostype" = 'termux' ]; then
    # Run Kodirsync Git updater
    source <(cat "$app_dir/kodirsync_clientapp_gitupdater.sh") "arg_parent"  # The arg 'arg_parent' tells kodirsync_clientapp_gitupdater.sh the script originates from a parent script.
fi


#---- Read default config settings (must be before user cfg)
source "$app_dir/kodirsync_clientapp_default.cfg"


#---- Read user config settings
source "$app_dir/kodirsync_clientapp_user.cfg"


#---- Run Kodirsync script

# Run Kodirsync main script
source $app_dir/kodirsync_clientapp_script.sh


#---- Run Kodirsync node synchronization script
if [ "$node_sync" = 1 ] && [ ! "$ostype" = 'termux' ] && [[ "$rsync_connection_type" =~ (1|2) ]]; then
  bash $app_dir/kodirsync_clientapp_node_run.sh
fi

# Ensure the cleanup function is also called when your script exits normally
exit 0
#-----------------------------------------------------------------------------------------------------------------------