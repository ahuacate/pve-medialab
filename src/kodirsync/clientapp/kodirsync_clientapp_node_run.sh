#!/usr/bin/env bash
set -x
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_node_run.sh
# Description:  Default Kodirsync node run script
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

# Debug file
debug=$app_dir/logs/debug.txt
rm $debug 2> /dev/null  # Start a fresh debug file

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

# Create temp work dir (if missing)
if [ -z "$work_dir" ]; then
    work_dir=$(mktemp -dt -p /tmp kodirsync-XXXXXX)
fi

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
if [ "$(uname)" == "Linux" ] && [ ! $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]; then
    # Set Linux OS type
    ostype=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
else
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync node sync is supported on CoreELEC, LibreELEC and Linux only.\nBye...\n\e[39m"
    exit 0
fi

# Read default config settings (must be before user cfg)
source "$app_dir/kodirsync_clientapp_default.cfg"

# Read user config settings
source "$app_dir/kodirsync_clientapp_user.cfg"

# Check if Kodirsync node is enabled ('1' for enabled, '0' for disabled)
if [ "$node_sync" = 0 ]; then
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync node sync is disabled.\nBye...\n\e[39m"
    exit 0  # Exit script.
fi

#---- Create list of node variables

# Function to extract each node settings and append them to the array
node_settings_LIST=() # Initialize an empty array to store the node settings
function extract_node_settings() {
    # Extract each node parameter values from config input file

    # Set argument parameters
    local node_number="$1"
    local config_file="$2"

    # Read config file parameters
    local node_localdomain_address_url=$(grep -oE "^node${node_number}_localdomain_address_url='[^']*'" "$config_file" | cut -d "'" -f 2)
    local node_local_ip_address=$(grep -oE "^node${node_number}_local_ip_address='[^']*'" "$config_file" | cut -d "'" -f 2)
    local node_ssh_port=$(grep -oE "^node${node_number}_ssh_port='[^']*'" "$config_file" | cut -d "'" -f 2)
    local node_user=$(grep -oE "^node${node_number}_user='[^']*'" "$config_file" | cut -d "'" -f 2)
    local node_dst_max_storage_limit=$(grep -oE "^node${node_number}_dst_max_storage_limit='[^']*'" "$config_file" | cut -d "'" -f 2)
    local node_hdr_enable=$(grep -oE "^node${node_number}_hdr_enable='[^']*'" "$config_file" | cut -d "'" -f 2)
    local node_ssh_private_key_path=$(grep -oE "^node${node_number}_ssh_private_key_path=(['\"]?)([^'\"]+)" "$config_file" | sed -E "s/node${node_number}_ssh_private_key_path=(['\"]?)([^'\"]+)/\2/")

    # Check if any of the required variables is empty
    if [ -z "$node_ssh_port" ] || [ -z "$node_user" ] || [ -z "$node_dst_max_storage_limit" ] || [ -z "$node_hdr_enable" ] || [ -z "$node_ssh_private_key_path" ]; then
        return 1
    fi

    # Check if either localdomain_address_url or local_ip_address is empty
    if [ -z "$node_localdomain_address_url" ] && [ -z "$node_local_ip_address" ]; then
        return 1
    fi

    # Create a node settings entry and add it to the list
    local node_settings="$node_localdomain_address_url;$node_local_ip_address;$node_ssh_port;$node_user;$node_dst_max_storage_limit;$node_hdr_enable;$node_ssh_private_key_path"
    node_settings_LIST+=("$node_settings")
}

# Loop through node settings and extract them
i=1
while grep -q "node${i}_" "$app_dir/kodirsync_clientapp_user.cfg"; do
    extract_node_settings "$i" "$app_dir/kodirsync_clientapp_user.cfg"
    i=$((i+1))
done

# Display the extracted node settings
for i in "${!node_settings_LIST[@]}"; do
    echo "entry$((i+1)) >>> ${node_settings_LIST[i]}"
done

# Check if "${node_settings_LIST[@]}" contains node entries
if [ "${#node_settings_LIST[@]}" = 0 ]; then
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync node sync is not available.\nBye...\n\e[39m"
    exit 0
fi

#---- Perform tasks

while IFS=';' read -r node_localdomain_address_url node_local_ip_address node_ssh_port node_user node_dst_max_storage_limit node_hdr_enable node_ssh_private_key_path; do
    # Eval variables
    eval "node_localdomain_address_url=$node_localdomain_address_url"
    eval "node_local_ip_address=$node_local_ip_address"
    eval "node_ssh_port=$node_ssh_port"
    eval "node_user=$node_user"
    eval "node_dst_max_storage_limit=$node_dst_max_storage_limit"
    eval "node_hdr_enable=$node_hdr_enable"
    eval "node_ssh_private_key_path=$node_ssh_private_key_path"


    # Create ul lists
    source $app_dir/kodirsync_clientapp_node_script.sh

    # Run Kodirsync node synchronization - '$kodirsync_app' files
    if [ "${#ul_node_app_LIST[@]}" -ne 0 ]; then
        local_dir="$local_app_dir"  # local $kodirsync_app dir
        node_dir="$node_app_dir"  # node $kodirsync_app dir
        printf '%s\n' "${ul_node_app_LIST[@]}" | awk -F';' '{ print $1 }' > $work_dir/rsync_ul_list.txt  # rsync ul list
        
        # Step 1: Copy new files to node
        source $app_dir/kodirsync_clientapp_node_connect.sh
    fi

    # Run Kodirsync node synchronization - '$kodirsync_storage' files
    if [ "${#ul_node_storage_LIST[@]}" -ne 0 ]; then
        local_dir="$local_src_dir"  # local $kodirsync_storage dir
        node_dir="$node_dst_dir"  # node $kodirsync_storage dir
        printf '%s\n' "${ul_node_storage_LIST[@]}" | awk -F';' '{ print $1 }' > $work_dir/rsync_ul_list.txt   # rsync ul list

        # Step 1: Prune old files and dirs from destination
        source $app_dir/kodirsync_clientapp_node_prune.sh
    
        # Step 2: Copy new files to destination
        source $app_dir/kodirsync_clientapp_node_connect.sh
    fi
done < <( printf '%s\n' "${node_settings_LIST[@]}" )


# Create log entry - finish
echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
#-----------------------------------------------------------------------------------------------------------------------