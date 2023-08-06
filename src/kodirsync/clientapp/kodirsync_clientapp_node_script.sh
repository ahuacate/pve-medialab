#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_node_script.sh
# Description:  Kodirsync script for syncing media to another network
#               LAN CoreELEC/LibreELEC node disk storage.
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Get Kodirsync node storage dir
function get_node_storage_dir() {
  # This function gets the nodes '$kodirsync_storage_dir' and '$kodirsync_app_dir'.
  # Sets vars '$node_dst_dir' and '$node_app_dir'

  # Set source
  source='/'

  # Create file list
  i=0 check_code=1
  while [ ! "$check_code" = 0 ] && [[ "$i" -le "$connect_retrycount" ]]
  do
    # Set Chk Cnt
    i=$(($i+1))

    #---- Get $node_dst_dir folder
    # Prepare the find command with xargs to check for $kodirsync_storage_dir with '.kodirsync_storage' file inside
    find_cmd="find / -type d -name "$kodirsync_storage_dir" -print 2> /dev/null | xargs -I{} sh -c 'if [ -e \"{}/.kodirsync_storage\" ]; then echo \"{}\"; fi'"
    # SSH command to get the list of files on the remote server
    ssh_cmd="ssh -i $HOME/.ssh/$node_ssh_private_key_name -p $node_ssh_port $node_user@$lan_address"
    # Run SSH cmd
    node_dst_dir_chk=$($ssh_cmd "bash -c \"$find_cmd\"")

    #---- Get $node_app_dir folder
    # Prepare the find command to check for $kodirsync_app_dir
    find_cmd="find / -type d -name "$kodirsync_app_dir" -print 2> /dev/null"
    # SSH command to get the list of files on the remote server
    ssh_cmd="ssh -i $HOME/.ssh/$node_ssh_private_key_name -p $node_ssh_port $node_user@$lan_address"
    # Run SSH cmd
    node_app_dir_chk=$($ssh_cmd "bash -c \"$find_cmd\"")

    # Set check code
    if [ -n "$node_dst_dir_chk" ] && [ -n "$node_app_dir_chk" ]
    then
      check_code=0
    else
      check_code=1
    fi

    # Check ssh status
    if [ ! "$check_code" = 0 ]&& [ "$i" = "$connect_retrycount" ]
    then
      echo -e "#---- WARNING - GET NODE SERVER DESTINATION DIR\nError Code ($check_code) : $(date)\nFunction : get_node_storage_dir\nRetry count : "$connect_retrycount"x failed attempts\n" >> $logfile
      exit 1
    elif [ ! "$check_code" = 0 ] && [[ "$i" -lt "$connect_retrycount" ]]
    then
      sleep $connect_retrysleep
    elif [ "$check_code" = 0 ]
    then
      # Set $node_dst_dir
      node_dst_dir="$node_dst_dir_chk"
      # Set $node_app_dir
      node_app_dir="$node_app_dir_chk"
      echo "Success"
    fi
  done
}

# Get Kodirsync local storage dir
function get_local_storage_dir() {
  # This function gets the local '$kodirsync_storage_dir' and '$kodirsync_app_dir'.
  # Sets vars '$local_dst_dir' and '$local_app_dir'

  # Set source
  source='/'

  # Create file list
  i=0 check_code=1
  while [ ! "$check_code" = 0 ] && [[ "$i" -le "$connect_retrycount" ]]
  do
    # Set Chk Cnt
    i=$(($i+1))

    #---- Get $local_dst_dir folder
    # Get local $kodirsync_storage_dir
    local_dst_dir_chk=$(find / \( -path "*/$android_path/$kodirsync_storage_dir" -o -path "*/$kodirsync_storage_dir" \) -type d -execdir sh -c '[ -e "$1/.kodirsync_storage" ]' sh {} \; -print 2> /dev/null)

    #---- Get $local_app_dir folder
    # Get local $kodirsync_app_dir
    local_app_dir_chk=$(find / \( -path "*/$android_path/$kodirsync_app_dir" -o -path "*/$kodirsync_app_dir" \) -type d 2> /dev/null)

    # Set check code
    if [ -n "$local_dst_dir_chk" ] && [ -n "$local_app_dir_chk" ]
    then
      check_code=0
    else
      check_code=1
    fi

    # Check ssh status
    if [ ! "$check_code" = 0 ]&& [ "$i" = "$connect_retrycount" ]
    then
      echo -e "#---- WARNING - GET LOCAL SERVER DIR\nError Code ($check_code) : $(date)\nFunction : get_local_storage_dir\nRetry count : "$connect_retrycount"x failed attempts\n" >> $logfile
      exit 1
    elif [ ! "$check_code" = 0 ] && [[ "$i" -lt "$connect_retrycount" ]]
    then
      sleep $connect_retrysleep
    elif [ "$check_code" = 0 ]
    then
      # Set $local_dst_dir
      local_dst_dir="$local_dst_dir_chk"
      # Set $local_app_dir
      local_app_dir="$local_app_dir_chk"
      echo "Success"
    fi
  done
}


# Get Kodirsync node storage information
function get_node_storage_info() {
  # This function gets the nodes '$node_fs' and '$node_size'.
  # local node_ssh_private_key_path="$1"
  # local node_ssh_port="$2"
  # local node_user="$3"
  # local lan_address="$4"
  # local node_dst_dir="$5"
  # local storage_prov_factor="$6"


  # Set '$node_fs' var
  # Prepare the command to get the FS
  find_cmd=$(cat <<EOF
  device=\$(df -Ph "$node_dst_dir" | awk 'NR==2 {print \$1}' | sed 's/ //g')
  stor_fs=\$(blkid -o value -s TYPE "\$device")
  echo "\$stor_fs"
EOF
  )
  # Use heredoc to execute the find command directly on node
  node_fs=$(ssh -i "$HOME/.ssh/$node_ssh_private_key_name" -p $node_ssh_port $node_user@$lan_address /bin/sh <<EOF
  $find_cmd
EOF
  )

  # Set '$node_dst_dir_max_cap' var
  # Prepare the command to get the maximum available space on node
  get_max_capacity_cmd=$(cat <<EOF
  df -k "$node_dst_dir" | awk 'NR==2 {print \$2}'
EOF
  )
  # Use heredoc to execute the command on coreelec-02 and capture the output
  node_dst_dir_max_cap_kb=$(ssh -i "$HOME/.ssh/$node_ssh_private_key_name" -p "$node_ssh_port" "$node_user@$lan_address" /bin/sh <<EOF
  $get_max_capacity_cmd
EOF
  )
  # Convert the value to bytes
  node_dst_dir_max_cap=$((node_dst_dir_max_cap_kb * 1024 * storage_prov_factor / 100))
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create Mktemp file
[ ! -f "$tempfile" ] && tempfile=$(mktemp)

# Create temp work dir
[ ! -d "$work_dir" ] && work_dir=$(mktemp -dt -p /tmp kodirsync-XXXXXX)


# Use eval to expand the value of node_ssh_private_key_path
eval "node_ssh_private_key_path=\"$node_ssh_private_key_path\""

# Copy private ssh key to .ssh dir if required
if [[ ! "$node_ssh_private_key_path" =~ ^$HOME/\.ssh/.* ]]
then
  # Set ssh key name
  node_ssh_private_key_name=$(basename "$node_ssh_private_key_path")

  # Copy ssh key from var path to users .ssh dir
  cp -f "$node_ssh_private_key_path" "$HOME/.ssh/$node_ssh_private_key_name"

  # Chmod 600 ssh key
  if [[ "$ostype" =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]
  then
    chmod 600 "$HOME/.ssh/$node_ssh_private_key_name"
  else
    sudo chmod 600 "$HOME/.ssh/$node_ssh_private_key_name"
  fi
else
  # Set ssh key name
  node_ssh_private_key_name=$(basename "$node_ssh_private_key_path")

  # Chmod 600 ssh key
  if [[ "$ostype" =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]
  then
    chmod 600 "$HOME/.ssh/$node_ssh_private_key_name"
  else
    sudo chmod 600 "$HOME/.ssh/$node_ssh_private_key_name"
  fi
fi

#---- Check & Set LAN node connection status
# Check for LAN connectivity using IP address and host name.

# Check LAN connectivity 1 - hostname.localdomain
node_localdomain_address_url1=$node_localdomain_address_url
ssh -q -i "$HOME/.ssh/$node_ssh_private_key_name" \
-o "BatchMode yes" \
-o "StrictHostKeyChecking no" \
-o "ConnectTimeout 5" \
-p $node_ssh_port \
$node_user@$node_localdomain_address_url echo OK
lan_server_domain_status1=$?

# Check LAN connectivity 2 - hostname only
# Remove the domain name from $localdomain_address_url
node_localdomain_address_url2=${node_localdomain_address_url%%.*}
ssh -i "$HOME/.ssh/$node_ssh_private_key_name" \
-o "BatchMode yes" \
-o "StrictHostKeyChecking no" \
-o "ConnectTimeout 5" \
-p $node_ssh_port \
$node_user@$node_localdomain_address_url2 echo OK
lan_server_domain_status2=$?

# Check LAN connectivity - IP address
if [[ "$node_local_ip_address" =~ ^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$ ]]
then
  ssh -q -i "$HOME/.ssh/$node_ssh_private_key_name" \
  -o "BatchMode yes" \
  -o "StrictHostKeyChecking no" \
  -o "ConnectTimeout 5" \
  -p $node_ssh_port \
  $node_user@$node_local_ip_address echo OK
  lan_server_ip_status=$?
else
  lan_server_ip_status=0
fi

# Set LAN server connection status & url
if [ "$lan_server_domain_status1" = 0 ]
then
  # Set LAN active
  lan_address="$node_localdomain_address_url1"
  lan_server_status=1
elif [ ! "$lan_server_domain_status1" = 0 ] && [ "$lan_server_domain_status2" = 0 ]
then
  # Set LAN active
  lan_address="$node_localdomain_address_url2"
  lan_server_status=1
elif [ ! "$lan_server_domain_status" = 0 ] && [ "$lan_server_ip_status" = 0 ]
then
  # Set LAN active
  lan_address="$node_local_ip_address"
  lan_server_status=1
elif [ ! "$lan_server_domain_status" = 0 ] && [ ! "$lan_server_ip_status" = 0 ]
then
  # Set LAN inactive
  lan_server_status=0

  # If LAN inactive & no internet WAN access then exit ('0' is disabled, '1' is enabled)
  if [ "$connection_up" = 0 ]
  then
    # Create log entry
    echo -e "#---- WARNING - LAN NODE RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail.\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
  fi
fi


#---- Get and set local and node vars

# Get and set node $node_dst_dir and $node_app_dir
get_node_storage_dir

# Get and set node $node_fs and $node_size
get_node_storage_info

# Get and set local $dst_dir and $app_dir
get_local_storage_dir


#---- Set maximum node storage capacity limit

# Limit destination storage capacity (bytes)
# Apply user preset $node_dst_max_storage_limit.
# Apply exFAT storage limit $android_storage_cap.
# Set $node_dst_max_limit
# Apply filesystem & storage capacity overrides
if [ "$node_fs" = 'exfat' ]
then
  # Set destination storage limit (bytes) - exFAT ('0' for unlimited, other specified)
  if [ "$node_dst_max_storage_limit" = 0 ]
  then
    # No-limit
    if [ "$android_storage_cap" -ne 0 ] && [ "$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))" -lt "$node_dst_dir_max_cap" ]
    then
      # Set $node_dst_max_limit (bytes)
      node_dst_max_limit=$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))
    else
      # Set $node_dst_max_limit (bytes)
      node_dst_max_limit=$node_dst_dir_max_cap
    fi
  else
    # Limited - limited by preset '$node_dst_max_storage_limit'
    # Set $node_dst_max_limit (bytes)
    node_dst_max_limit=$(( $node_dst_max_storage_limit * 1024 * 1024 * 1024 ))

    if [ "$android_storage_cap" -ne 0 ] && [ "$(( $node_dst_max_storage_limit * 1024 * 1024 * 1024 ))" -lt "$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))" ] && [ "$(( $node_dst_max_storage_limit * 1024 * 1024 * 1024 ))" -lt "$node_dst_dir_max_cap" ]
    then
      # Set $node_dst_max_limit (bytes)
      node_dst_max_limit=$(( $node_dst_max_storage_limit * 1024 * 1024 * 1024 ))
    elif [ "$android_storage_cap" -ne 0 ] && [ "$(( $node_dst_max_storage_limit * 1024 * 1024 * 1024 ))" -ge "$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))" ] && [ "$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))" -lt "$node_dst_dir_max_cap" ]
    then
      # Set $node_dst_max_limit (bytes)
      node_dst_max_limit=$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))
    elif [ "$node_dst_max_limit" -ge "$node_dst_dir_max_cap" ]
    then
      # Set $node_dst_max_limit (bytes)
      node_dst_max_limit=$node_dst_dir_max_cap
    fi
  fi
else
  # Set destination storage limit (bytes) - non-exFAT ('0' for unlimited, other specified)
  if [ "$node_dst_max_storage_limit" = 0 ]
  then
    # No-limit
    # Set $node_dst_max_limit (bytes)
    node_dst_max_limit=$node_dst_dir_max_cap
  else
    # Limited - limited by preset '$node_dst_max_storage_limit'
    if [ "$(( $node_dst_max_storage_limit * 1024 * 1024 * 1024 ))" -lt "$node_dst_dir_max_cap" ]
    then
      # Set $node_dst_max_limit (bytes)
      node_dst_max_limit=$(( $node_dst_max_storage_limit * 1024 * 1024 * 1024 ))
    elif [ "$(( $node_dst_max_storage_limit * 1024 * 1024 * 1024 ))" -gt "$node_dst_dir_max_cap" ]
    then
      # Set $node_dst_max_limit (bytes)
      node_dst_max_limit=$node_dst_dir_max_cap
    fi
  fi
fi

#---- Create lists

# Create lists, args and arrays
source $app_dir/kodirsync_clientapp_list1.sh


#---- Create download list of '$kodirsync_storage' files - local media files
# Note: Speed processing this part of the script depends on hardware. Be patient.
echo "Creating new download list. This can be slow, be patient..."


# Create local file list
# Create a list array of local media files to be rsync to node
# Sample: file path;file size in bytes;epoch file date

# Initialize array
all_local_storage_LIST=()
# Read the file line by line and append each line to the array
while IFS= read -r line
do
  all_local_storage_LIST+=("$line")
done < <(find "$local_dst_dir" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex)/.*" -type f -regextype posix-extended -not -iregex ".*/($exclude_file_filter_regex)$" -type f -regextype posix-extended -iregex ".*\.($video_format_filter_regex)$|.*\.($image_format_filter_regex)$|.*\.($audio_format_filter_regex)$|.*\.($audiobook_format_filter_regex)$|.*\.($subtitle_format_filter_regex)$" -printf '%P;%s;%T@\n' 2> /dev/null | sort -t ';' -k3 -n -r)



# Make list of elements of the "${all_local_storage_LIST[@]}" array
# All video, audio and audiobook metadata are included
# Subtitles excluded at this stage
# Initialize dl list array
local_storage_LIST=()

# Set start size
client_total_size=0

# Set net node copy size
avail_storage_bytes="$node_dst_max_limit"

for element in "${all_local_storage_LIST[@]}"
do
  # Add line if entry if available storage space
  while IFS=';' read -r file size date
  do
    # Extract the size portion from $size
    size="${size%%[!0-9]*}"

    # Check if the line matches the file extension pattern
    [[ ! "$file" =~ ^.*\.($video_format_filter_regex|$audio_format_filter_regex|$audiobook_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$ ]] && continue
    # Check if the line matches 'kodirsync_app'
    [[ "$file" =~ ^.*/kodirsync_app/(.*/)?.*$ ]] && continue

    # Check if the video is HDR/HDR10 encoded ('1' for enabled/allowed, '0' for disabled)
    if [ "$node_hdr_enable" = 0 ]
    then
      [[ "$file" =~ ^.*(\[.*)?($exclude_hdr_filter_regex)(.*\])?.*$ ]] && continue
    fi

    # Add entry only if '$size' is less than available storage
    if [[ "$size" -le "$avail_storage_bytes" ]]
    then
      # Add line to dl list
      local_storage_LIST+=( "$element" )

      # Deduct entry file size from $avail_storage_bytes
      avail_storage_bytes=$(( avail_storage_bytes - size ))

      # Add the DL file total size $client_total_size (bytes)
      client_total_size=$(( client_total_size + size ))
    fi
  done < <( echo "$element" )
done

# Add subtitle files
# Subtitle files are of nominal file size and added to the disk without storage
# space calculations. 
# Find matching subtitle for "${local_storage_LIST[@]}"
# Create a tmp copy
tmp_local_storage_LIST=( "${local_storage_LIST[@]}" )
# Iterate over the array elements
for element in "${tmp_local_storage_LIST[@]}"
do
  # Match subtitle in "${all_local_storage_LIST[@]}"
  filename=$(printf '%q' "$element" | awk -F';' '{print $1}')
  element_regex="${filename%.*}.*\.($subtitle_format_filter_regex)"

  # Iterate over all_local_storage_LIST and check for matches for subtitle files
  for line in "${all_local_storage_LIST[@]}"
  do
    # Match subtitle in "${all_local_storage_LIST[@]}"
    line_col1=$(echo "$line" | awk -F';' '{print $1}')
    if [[ "$line_col1" =~ ^$element_regex$ ]]
    then
      # Add subtitle file to "${local_storage_LIST[@]}"
      local_storage_LIST+=( "$line" )
    fi
  done
done


#---- Create download list of '$kodirsync_app' files - application script files
# Create local file list
# Create a list array of local aoo files to be rsync to node

# Initialize array
local_app_LIST=()
# Read the file line by line and append each line to the array
while IFS= read -r line
do
  local_app_LIST+=( "$line" )
done < <(find "$local_app_dir" -regextype posix-extended -not -iregex ".*/($exclude_file_filter_regex)$|.*/\..*$" -regextype posix-extended -not -iregex "(.*/)?($exclude_os_dir_filter_regex)(/.*)?|(.*/)?($exclude_dir_filter_regex)(/.*)?" -type f -printf '%P\n' 2> /dev/null)


#---- Create rsync lists
# Create Kodirsync storage input file list
printf '%s\n' "${local_storage_LIST[@]}" | awk -F';' '{ print $1 }' > $work_dir/rsync_storage_list.txt

# Create Kodirsync app input file list
printf '%s\n' "${local_app_LIST[@]}" | awk -F';' '{ print $1 }' > $work_dir/rsync_app_list.txt

# Create log entry
echo -e "#---- ACTION - RSYNC STORAGE TASK ONLY\nTime : $(date)\nRsync list : rsync_storage_list.txt\n" >> $logfile
echo -e "#---- ACTION - RSYNC APP TASK ONLY\nTime : $(date)\nRsync list : rsync_app_list.txt\n" >> $logfile

#---- Display msg ( for terminal only)
echo "Total node storage capacity: $node_dst_max_limit bytes or $(($node_dst_max_limit / (1024 * 1024 * 1024)))GB"
echo "Total node storage transfer size: $client_total_size bytes or $(($client_total_size / (1024 * 1024 * 1024)))GB"
#-----------------------------------------------------------------------------------