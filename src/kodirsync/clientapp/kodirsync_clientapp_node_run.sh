#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_node_run.sh
# Description:  Default Kodirsync node run script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )


#---- Dependencies -----------------------------------------------------------------

#---- Check script is not already running

# Script sleep time (sec)
script_sleep_time=3000
# Script timeout count limit
script_cnt_timeout=10
# Check for existing running script pid
# Checks for
c=0
while [ 1 ]
do
  # Get current script pid
  pid=$(pgrep -f "$(basename $0)"| grep -x -v $$)

  # Filter non-existent pid(s)
  # pid=$(<<<"$pid" xargs -n1 sh -c 'kill -0 "$1" 2>/dev/null && echo "$1"' --)
  pid=$(echo "$pid" | xargs -n1 sh -c 'kill -0 "$1" 2>/dev/null && echo "$1"' --)


  if [ -n "$pid" ]
  then
    # Print screen msg
    echo -e "Script '"$(basename $0)"' is already running with pid ${pid}.\nTrying again in ${script_sleep_time} seconds (Attempt: $((${c} + 1)) of ${script_cnt_timeout})."
    # Set sleep period or timeout
    ((c++)) && ((c==${script_cnt_timeout})) && exit 0
    sleep $script_sleep_time
  else
    # Clear to run script
    break
  fi
done

#---- Static Variables -------------------------------------------------------------

# App dir
app_dir="$DIR"

# SSH dir
ssh_dir="$HOME/.ssh"

# Log files
mkdir -p "$app_dir"/logs
now=$(date +"%F")
logfile="$app_dir/logs/kodirsync-${now}.log"
days_to_keep=14

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------


#---- Prerequisites

# Remove log files older than $days_to_keep days
find "$app_dir/logs" -name "kodirsync-*.log" -type f -mtime +$days_to_keep -delete

# LAN Network check (1 is UP, other is down)
lan_network_status=$(ip route | grep "linkdown" > /dev/null; echo $?)

# Check LAN network status
if [ ! "$lan_network_status" = 1 ]
then
  # Log Job fail
  echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
  echo -e "#---- WARNING - LAN NETWORK FAIL\nFail Time : $(date)\n" >> ${logfile}
  echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
  exit 1
fi

# Check if client is Termux or Linux/CoreELEC/LibreELEC
if [ "$(uname)" == "Linux" ] && [ ! $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]
then
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
if [ "$node_sync" = 0 ]
then
  echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync node sync is disabled.\nBye...\n\e[39m"
  exit 0
fi

#---- Create list of node variables
# Create a node settings array list, "${node_settings_LIST[@]}", of all node[0-9] variables

# Set the path to the configuration file
config_file="$app_dir/kodirsync_clientapp_user.cfg"

# Function to extract node settings and append them to the array
extract_node_settings() {
  local node_number=$1
  local node_localdomain_address_url=$(grep -oE "node${node_number}_localdomain_address_url='[^']*'" "$config_file" | cut -d "'" -f 2)
  local node_local_ip_address=$(grep -oE "node${node_number}_local_ip_address='[^']*'" "$config_file" | cut -d "'" -f 2)
  local node_ssh_port=$(grep -oE "node${node_number}_ssh_port='[^']*'" "$config_file" | cut -d "'" -f 2)
  local node_user=$(grep -oE "node${node_number}_user='[^']*'" "$config_file" | cut -d "'" -f 2)
  local node_dst_max_storage_limit=$(grep -oE "node${node_number}_dst_max_storage_limit='[^']*'" "$config_file" | cut -d "'" -f 2)
  local node_hdr_enable=$(grep -oE "node${node_number}_hdr_enable='[^']*'" "$config_file" | cut -d "'" -f 2)
  local node_ssh_private_key_path=$(grep -oE "node${node_number}_ssh_private_key_path=(['\"]?)([^'\"]+)" "$config_file" | sed -E "s/node${node_number}_ssh_private_key_path=(['\"]?)([^'\"]+)/\2/")

  # Check if either localdomain_address_url or local_ip_address is empty
  if [[ ! -z "$node_localdomain_address_url" || ! -z "$node_local_ip_address" ]]; then
    local node_settings="$node_localdomain_address_url;$node_local_ip_address;$node_ssh_port;$node_user;$node_dst_max_storage_limit;$node_hdr_enable;$node_ssh_private_key_path"
    node_settings_LIST+=("$node_settings")
  fi
}

# Initialize an empty array to store the node settings
node_settings_LIST=()

# Loop through node settings and extract them
i=1
while grep -q "node${i}_" "$config_file"; do
  extract_node_settings "$i"
  i=$((i+1))
done

# Display the extracted node settings
for i in "${!node_settings_LIST[@]}"; do
  echo "entry$((i+1)) >>> ${node_settings_LIST[i]}"
done

# Check if "${node_settings_LIST[@]}" contains node entries
if [ "${#node_settings_LIST[@]}" = 0 ]
then
  echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync node sync is not available.\nBye...\n\e[39m"
  exit 0
fi


#---- Perform tasks

while IFS=';' read -r node_localdomain_address_url node_local_ip_address node_ssh_port node_user node_dst_max_storage_limit node_hdr_enable node_ssh_private_key_path
do
  # Run main script
  # Create list of $kodirsync_storage and $kodirsync_app files to transfer
  # Set variables
  source $app_dir/kodirsync_clientapp_node_script.sh


  #---- Perform rsync transfers

  # Run Kodirsync node synchronization - '$kodirsync_app' files
  if [ ! "${#local_app_LIST[@]}" = 0 ]
  then
    # Step 1: Copy new files to destination
    source $app_dir/kodirsync_clientapp_node_rsync_app.sh
  fi

  # Run Kodirsync node synchronization - '$kodirsync_storage' files
  if [ ! "${#local_storage_LIST[@]}" = 0 ]
  then
    # Step 1: Prune old files and dirs from destination
    source $app_dir/kodirsync_clientapp_node_prune.sh
  
    # Step 2: Copy new files to destination
    source $app_dir/kodirsync_clientapp_node_rsync_main.sh
  fi
done < <( printf '%s\n' "${node_settings_LIST[@]}" )
#-----------------------------------------------------------------------------------------------------------------------