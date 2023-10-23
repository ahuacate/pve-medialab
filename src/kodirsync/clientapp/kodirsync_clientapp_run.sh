#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_run.sh
# Description:  Default Kodirsync client run script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

#---- Check script is not already running

# Define the script timeout in seconds
timeout=3600  # 1 hour

# Define the retry interval in seconds
retry_interval=60  # 1 minute

# Initialize the timer
start_time=$(date +%s)

# Define a function to check if the script is running
is_script_running() {
    pgrep -f "$0" | grep -v "$$"
}

# Main loop to check if the script is running
while true; do
    if is_script_running; then
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ $elapsed_time -ge $timeout ]; then
            echo "Script '$0' is still running after $timeout seconds. Exiting."
            exit 1
        else
            echo "Script '$0' is still running. Waiting $retry_interval seconds."
            sleep $retry_interval
        fi
    else
        break
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

# Debug file
debug="$app_dir/logs/debug.log"
rm -f $debug 2> /dev/null  # Remove old debug log

# Remove log files older than $log_life days
find "$app_dir/logs" -name "kodirsync-*.log" -type f -mtime +$log_life -delete

# LAN Network check (1 is UP, other is down)
lan_network_status=$(ip route | grep "linkdown" > /dev/null; echo $?)

# Check LAN network status
if [ ! "$lan_network_status" = 1 ]; then
    # Log Job fail
    echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
    echo -e "#---- WARNING - LAN NETWORK FAIL\nFail Time : $(date)\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
fi

# Set client OS - Termux or Linux/CoreELEC/LibreELEC
if [ $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]; then
    ostype='termux'  # Set OS type to Termux
elif [ "$(uname)" == "Linux" ] && [ ! $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]; then
    ostype=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)  # Set Linux OS type
else
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync is supported on CoreELEC, LibreELEC, Linux and Termux only.\nBye...\n\e[39m"
    exit 0  # Exit script. OS not supported
fi

# Check client dependencies (SW and OS version)
source $app_dir/kodirsync_clientapp_run_deps.sh

# Run Kodirsync Git updater
# Not available to Termux-Android clients 
github_updater=$(sed -n "s/^github_updater=\(['\"]\?\)\(.*\)\1/\2/p" "$app_dir/kodirsync_clientapp_user.cfg")
if [ "$github_updater" = 1 ] && [ ! "$ostype" = 'termux' ]; then
    # Run Kodirsync Git updater
    bash -c "$(curl -L https://raw.githubusercontent.com/ahuacate/pve-medialab/main/src/kodirsync/clientapp/kodirsync_clientapp_gitupdater.sh) arg_parent"  # The arg 'arg_parent' tells kodirsync_clientapp_gitupdater.sh the script originates from a parent script.
fi

#---- Read default config settings (must be before user cfg)
source "$app_dir/kodirsync_clientapp_default.cfg"


#---- Read user config settings
source "$app_dir/kodirsync_clientapp_user.cfg"


#---- Run Kodirsync script

# Run Kodirsync main script
source $app_dir/kodirsync_clientapp_script.sh


#---- Update Kodi library

# Run kodi-send cmd to Kodi localhost to clean/update media library
if [[ "$ostype" =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]; then
    libraryscan_file=$(find / -type f -path '*/script.module.kodirsync/*' -name 'kodirsync_clientapp_kodi_libraryscan.py')
    python3 "$libraryscan_file" > /dev/null 2>&1
fi


#---- Run Kodirsync node synchronization script
if [ "$node_sync" = 1 ] && [ ! "$ostype" = 'termux' ] && [[ "$rsync_connection_type" =~ (1|2) ]]; then
  bash $app_dir/kodirsync_clientapp_node_run.sh
fi

# Ensure the cleanup function is also called when your script exits normally
exit 0
#-----------------------------------------------------------------------------------------------------------------------