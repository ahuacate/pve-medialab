#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_script.sh
# Description:  Kodirsync script for Linux & Kodi (CoreELEC/LibreELEC) hosts
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

#---- Create B/W control list
function rsync_getcontrollist() {
  # creates array of blacklist and whitelist entries
  # output control list file name: "${rsync_control_LIST[@]}"

  # Set source
  source='~/'

  # Get rsync control lists from source
  i=0 check_code=1
  while [ ! "$check_code" = 0 ] && [[ "$i" -le "$connect_retrycount" ]]
  do

  # Set Chk Cnt
	i=$(($i+1))

	# Run rsync cmd
  rsync -avI \
  --no-relative \
  --include='kodirsync_control_list.txt' \
  --exclude='*' \
  -e "$rsync_ssh_cmd" \
	$rsync_username@$rsync_address:$source \
	$work_dir 2>/dev/null

	# Process logs
	check_code=$?
	if [ ! "$check_code" = 0 ] && [ "$i" = "$connect_retrycount" ]
  then
	  echo -e "#---- WARNING - RSYNC CONTROL FILES\nError Code ("$check_code") : $(date)\nFunction : rsync_getcontrollist\nRetry count : "$connect_retrycount"x failed attempts\n" >> $logfile
	  exit 1
	elif [ ! $check_code = 0 ] && [[ "$i" -lt "$connect_retrycount" ]]
  then
	  sleep $connect_retrysleep
	elif [ "$check_code" = 0 ]
  then
	  echo -e "#---- SUCCESS - RSYNC CONTROL FILES\nTime : $(date)\nFunction : rsync_getcontrollist\n" >> $logfile
	fi
  done
}

# Get Kodirsync server file list
function get_server_filelist() {
  # This function gets a file list from the Kodirsync server.
  # Sample: file path;file size in bytes;epoch file date
  # Includes filtering by regex.
  # Output array: "${all_server_LIST[@]}"

  # Set source
  source='\$HOME/'

  # Create file list
  i=0 check_code=1
  while [ ! "$check_code" = 0 ] && [[ "$i" -le "$connect_retrycount" ]]
  do
    # Set Chk Cnt
    i=$(($i+1))

    # Create server find cmd to create list of media files
    eval "expanded_cmd=\"find '"$source"' -regextype posix-extended -not -iregex '.*/($exclude_dir_filter_regex)/.*|.*/($black_dir_filter_regex)/.*' -type f -regextype posix-extended -not -iregex '.*/($exclude_file_filter_regex)$' -type f -regextype posix-extended -iregex '.*\\.($video_format_filter_regex)$|.*\\.($image_format_filter_regex)$|.*\\.($audio_format_filter_regex)$|.*\\.($audiobook_format_filter_regex)$|.*\\.($subtitle_format_filter_regex)$' -printf '%P;%s;%T@\\n' 2> /dev/null | sort -t ';' -k3 -n --reverse\""

    # Run SSH cmd
    "${ssh_cmd[@]}" "$rsync_username@$rsync_address" "bash -c \"$expanded_cmd\"" > $tempfile

    # Check ssh status
    check_code=$?
    if [ ! "$check_code" = 0 ] && [ "$i" = "$connect_retrycount" ]
    then
      echo -e "#---- WARNING - GET SERVER FILE LIST\nError Code ($check_code) : $(date)\nFunction : get_server_filelist\nRetry count : "$connect_retrycount"x failed attempts\n" >> $logfile
      exit 1
    elif [ ! "$check_code" = 0 ] && [[ "$i" -lt "$connect_retrycount" ]]
    then
      sleep $connect_retrysleep
    elif [ "$check_code" = 0 ]
    then
      # Initialize array
      all_server_LIST=()
      # Read the file line by line and append each line to the array
      while IFS= read -r line
      do
        all_server_LIST+=("$line")
      done < "$tempfile"

      echo -e "#---- SUCCESS - GET SERVER FILE LIST\nTime : $(date)\nFunction : get_server_filelist\n" >> $logfile
    fi
  done
}

# Create server share list
function get_server_sharelist() {
  # This function gets the dir share list from the Kodirsync server
  # Includes filtering by regex.
  # Output array: "${share_server_LIST[@]}"

  # Set source
  source='\$HOME/'

  # Create Kodirsync share dir list
  i=0 check_code=1
  while [ ! "$check_code" = 0 ] && [[ "$i" -le "$connect_retrycount" ]]
  do
    # Set Chk Cnt
    i=$(($i+1))

    # Get Kodirsync server share dirs - step 1
    # Cmd arg '$expanded_cmd_1' gets all the non-video dir shares only (i.e photo, music)
    eval "expanded_cmd_1=\"find '"$source"' -mindepth 1 -maxdepth 2 -regextype posix-extended -not -iregex '(.*/)?($exclude_os_dir_filter_regex)(/.*)?|(.*/)?($exclude_dir_filter_regex)(/.*)?|(.*/)?($black_dir_filter_regex)(/.*)?|(.*/)?($video_subfolder_dir_filter_regex)(/.*)?' -type d -printf '%P\\n'\""

    # Get Kodirsync server share dirs - step 2
    # Cmd arg '$expanded_cmd_2' gets all the video sub dir shares (i.e series, movies)
    eval "expanded_cmd_2=\"find '"$source"' -mindepth 1 -maxdepth 2 -regextype posix-extended -not -iregex '(.*/)?($exclude_os_dir_filter_regex)(/.*)?|(.*/)?($exclude_dir_filter_regex)(/.*)?|(.*/)?($black_dir_filter_regex)(/.*)?' -regextype posix-extended -iregex '(.*/)?($video_subfolder_dir_filter_regex)(/.*)?' -type d -printf '%P\\n'\""

    # Run SSH cmd - step 1
    "${ssh_cmd[@]}" "$rsync_username@$rsync_address" "bash -c \"$expanded_cmd_1\"" > $tempfile
    check_code_1=$?
    # Run SSH cmd - step 2
    "${ssh_cmd[@]}" "$rsync_username@$rsync_address" "bash -c \"$expanded_cmd_2\"" >> $tempfile
    check_code_2=$?

    # Check ssh status
    check_code=$(( check_code_1 + check_code_2 ))
    if [ ! "$check_code" = 0 ] && [ "$i" = "$connect_retrycount" ]
    then
      # Make log entry - fail
      echo -e "#---- WARNING - GET SERVER SHARE LIST\nError Code ("$check_code") : $(date)\nFunction : get_server_sharelist\nRetry count : "$connect_retrycount"x failed attempts\n" >> $logfile
      exit 1
    elif [ ! "$check_code" = 0 ] && [[ "$i" -lt "$connect_retrycount" ]]
    then
      sleep $connect_retrysleep
    elif [ "$check_code" = 0 ]
    then
      # Initialize array
      share_server_LIST=()

      # Read the file line by line and append each line to the array
      while IFS= read -r line
      do
        share_server_LIST+=("$line")
      done < "$tempfile"

      # Make log entry - success
      echo -e "#---- SUCCESS - GET SERVER SHARE LIST\nTime : $(date)\nFunction : get_server_sharelist\n" >> $logfile
    fi

    # Check if Kodirsync server shares are none
    if [ "${#share_server_LIST[@]}" -eq 0 ]
    then
      # Make log entry - fail (no shares available)
      echo -e "#---- WARNING - GET SERVER SHARE LIST\nError Code ("no shares available") : $(date)\nFunction : get_server_sharelist\nRetry count : "$connect_retrycount"x failed attempts\n" >> $logfile
      exit 1
    fi
  done
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check for Internet connectivity
# List of well-known websites to test connectivity (in case one is blocked)
websites=( "google.com 443" "github.com 443" "cloudflare.com 443" "apple.com 443" "amazon.com 443" )
# Loop through each website in the list
for website in "${websites[@]}"
do
  # Test internet connectivity
  nc -zw1 $website > /dev/null 2>&1
  # Check the exit status of the ping command
  if [ $? = 0 ]
  then
    # Flag to track if internet connection is up
    connection_up=1
    break
  else
  # Flag to track if internet connection is down
  connection_up=0
  fi
done

# Create Mktemp file
tempfile=$(mktemp)
# Create temp work dir
work_dir=$(mktemp -dt -p /tmp kodirsync-XXXXXX)


#---- Set configuration variable overrides
# Overrides are for Termux portable storage disks and ELEC/Linux re-check.
# The override temporarily sets the $app_dir, $dst_dir and $throttle for use
# with Termux Android devices.
# Must run after read of config files.

if [ "$ostype" = 'termux' ]
then
  # Search for priority '$dst_dir' location with '.kodirsync_storage' file
  # Android exFAT mount path. Full path '/storage/XXXX-XXXX/Android/data/com.termux/files/'.
  dst_dir_chk=""
  while IFS= read -r path
  do
    # Check for hidden file '.kodirsync_storage'
    if [ -f "$path/.kodirsync_storage" ]
    then
      dst_dir_chk="$path"
    fi
  done < <(find /storage -path "*/$android_path/$kodirsync_storage_dir" -type d 2> /dev/null)

  # Set '$dst_dir' location
  if [ -n "$dst_dir_chk" ] && [ -d "$dst_dir_chk" ]
  then
    # Priority directory found and exists, set $dist_dir
    dst_dir="$dst_dir_chk"
  else
    # No storage dir found
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync destination directory not found.\nBye...\n\e[39m"
    exit 0
  fi

  # Other Termux/Android overrides
  # Rsync throttle enable ('1' for enabled, '0' for disabled)
  if [ "$termux_throttle" = 1 ]
  then
    # Rsync throttle disabled
    throttle=0
  fi

  # Limit destination storage capacity (bytes)
  # Apply user preset $dst_max_storage_limit.
  # Apply exFAT storage limit $android_storage_cap.
  # Set $dst_max_limit
  if [ "$dst_max_storage_limit" = 0 ]
  then
    # Limit - apply Android cap limit
    dst_max_limit=$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))
  else
    # Limit - check preset $dst_max_storage_limit is not greater than exFAT limit ($android_storage_cap)
    if (( $(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 )) < $(( $dst_max_storage_limit * 1024 * 1024 * 1024 )) ))
    then
      dst_max_limit=$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))
    else
      dst_max_limit=$(( $dst_max_storage_limit * 1024 * 1024 * 1024 ))
    fi
  fi

  # Set storage to folder type ('1' for disk based, '2' for folder based)
  storage_type='2'
else
  # ELEC and Linux client - check & set variable overrides
  # Search for priority '$dst_dir' location with hidden kodirsync_storage' file
  # Check Android exFAT/ext4 mount path. Android path is '/storage/XXXX-XXXX/Android/data/com.termux/files/'.
  dst_dir_chk=""
  while IFS= read -r path
  do
    # Check for hidden file '.kodirsync_storage'
    if [ -f "$path/.kodirsync_storage" ]
    then
      dst_dir_chk="$path"
    fi
  done < <(find / \( -path "*/$android_path/$kodirsync_storage_dir" -o -path "*/$kodirsync_storage_dir" \) -type d 2> /dev/null)

  # Set '$dst_dir' location
  if [ -n "$dst_dir_chk" ] && [ -d "$dst_dir_chk" ]
  then
    # Priority directory found and exists, set $dist_dir
    dst_dir="$dst_dir_chk"
  else
    # No storage dir found
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync destination directory not found.\nBye...\n\e[39m"
    exit 0
  fi

  # Limit destination storage capacity (bytes)
  # Apply user preset $dst_max_storage_limit.
  # Apply exFAT storage limit $android_storage_cap.
  # Set $dst_max_limit
  # Get storage filesystem type
  device=$(df -Ph "$dst_dir" | awk 'NR==2 {print $1}' | sed 's/ //g')
  stor_fs=$(blkid -o value -s TYPE "$device")
  # Apply filesystem & storage capacity overrides
  if [ "$stor_fs" = 'exfat' ]
  then
    # Set destination storage limit (bytes) - exFAT ('0' for unlimited, other specified)
    if [ "$dst_max_storage_limit" = 0 ]
    then
      # Limit - apply Android cap limit
      dst_max_limit=$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))
    else
      # Limit - check preset $dst_max_storage_limit is not greater than exFAT limit ($android_storage_cap)
      if (( $(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 )) < $(( $dst_max_storage_limit * 1024 * 1024 * 1024 )) ))
      then
        dst_max_limit=$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))
      else
        dst_max_limit=$(( $dst_max_storage_limit * 1024 * 1024 * 1024 ))
      fi
    fi
  else
    # Set destination storage limit (bytes) - ext4 ('0' for unlimited, other specified)
    if [ "$dst_max_storage_limit" = 0 ]
    then
      dst_max_limit=0
    else
      dst_max_limit=$(( $dst_max_storage_limit * 1024 * 1024 * 1024 ))
    fi
  fi

  # Mountpoint check status ('1' for valid, '0' for invalid)
  # Here we check if $dst_dir is a mounted USB disk with the wrong disk label.
  # If the disk label is wrong (i.e 'kodirsync') then $storage_type is et to folder.
  mnt_point_chk=$(echo $dst_dir | grep -q -E "^(/var/media/.*/$kodirsync_storage_dir|/mnt/.*/$kodirsync_storage_dir)" && echo "1" || echo "0")
  if [ "$mnt_point_chk" = 1 ]
  then
    # Get the device information for the given path
    device=$(df -P "$dst_dir" | awk 'NR==2 {print $1}')

    # Get the FS information for the device
    fstype=$(udevadm info --query=property --name="$device" 2> /dev/null \
    | grep "ID_FS_TYPE=" \
    | cut -d "=" -f 2 \
    | awk -v def="not avail" '{print} END { if(NR==0) {print def} }')

    # Get the disk label using udevadm
    label=$(udevadm info --query=property --name="$device" 2> /dev/null \
    | awk -F "=" '/ID_FS_LABEL=/ {print $2}')

    if [ ! "$label" = 'kodirsync' ]
    then
      # Update args for writing to Kodirsync user config files
      # Value '1' for disk, '2' for folder
      name='storage_type'
      value='2'
      sed -i "s#^${name}\=.*#${name}\=${value}#g" $app_dir/kodirsync_clientapp_user.cfg

      # Set $storage_type
      storage_type=2

      # Wrong disk label
      echo -e "\e[93m[WARNING]\e[39m \e[97mDisk label 'kodirsync' not set for device $device.\nThe disk should have a disk label named 'kodirsync'.\n\e[39m"
    else
      # Update args for writing to Kodirsync user config files
      # Value '1' for disk, '2' for folder
      name='storage_type'
      value='1'
      sed -i "s#^${name}\=.*#${name}\=${value}#g" $app_dir/kodirsync_clientapp_user.cfg

      # Set $storage_type
      storage_type=1
    fi
  fi
fi


#---- Check destination storage status (type - '1' for disk, '2' for dir)

if [ "$storage_type" = 1 ] && [ ! "$ostype" = 'termux' ]
then
  # Disk based storage - set $mnt_point
  # $mnt_point is the '../kodirsync' dir used for a disk mount. The mountpoint is
  # '/mnt/kodirsync' or '/var/media/kodirsync' depending on your client device OS.
  # The disk label is 'kodirsync' which is set by the Linux/ELEC Kodirsync installer.

  # Get mountpoint $mnt_point
  mnt_point=$(echo "$dst_dir" | sed 's|\(/kodirsync\)/.*|\1|')

  # Check disk storage mnt status ('1' for valid, '0' for invalid)
  storage_type_status=$(mountpoint -q "$mnt_point" && echo "1" || echo "0")
elif [ "$storage_type" = 2 ]
then
  # Set destination dir status ('1' for valid, '0' for invalid)
  storage_type_status=$([ -d "$dst_dir" ] && echo "1" || echo "0")
fi

# If storage status returns '0' - exit script ('1' for valid, '0' for invalid)
if [ "$storage_type_status" = 0 ]
then
  # Log job fail & exit
  echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
  echo -e "#---- WARNING - DESTINATION STORAGE FAIL\nFail Time : $(date)\n" >> $logfile
  echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
  exit 1
fi


#---- Destination storage maximum capacity limit (for both disk and folder storage in bytes)

# Get disk or dir capacity and apply $storage_prov_factor
dst_max_cap=$(df -Pk "$dst_dir" \
| awk -v storage_prov_factor="$storage_prov_factor" '(NR==2) {OFMT="%0.f"; sum = (($3 + $4) * (storage_prov_factor/100)) * 1024; print sum }')

# Set $storage_cap (bytes)
if [ "$dst_max_limit" = 0 ]
then
  # Set storage capacity to disk maximum
  storage_cap=$dst_max_cap
elif [ ! "$dst_max_limit" = 0 ]
then
  # Check $dst_max_cap does not exceed limits (bytes)
  if (( $dst_max_limit > $dst_max_cap ))
  then
    # $storage_cap is smaller than maximum allowed
    storage_cap=$dst_max_cap
  else
    # $storage_cap is set to maximum allowed
    storage_cap=$dst_max_limit
  fi
fi


#---- Set maximum file size clip

# Set video file size clip
if [ ! "$max_video_size" = 0 ]
then
  # Set $max_video_size_limit in bytes
  max_video_size_limit=$(( max_video_size * 1024 * 1024 * 1024 ))
else
  # Set to unlimited 100Gb limit
  max_video_size_limit=107374182400
fi

# Set other file size clip
if [ ! "$max_other_size" = 0 ]
then
  # Set $max_video_size_limit in bytes
  max_other_size_limit=$(( max_other_size * 1024 * 1024 * 1024 ))
else
  # Set to unlimited 100Gb limit
  max_other_size_limit=107374182400
fi


#---- Check & update SSH keys in '$HOME/.ssh' dir

# Key name list
ssh_key_LIST=( "${rsync_username}_kodirsync_id_ed25519" )

# Check key is in '$HOME/.ssh' dir
for filename in "${ssh_key_LIST[@]}"; do
  # Check if '.ssh' directory exists, create if necessary
  if [ ! -d "$HOME/.ssh" ]
  then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
  fi

  # Update or Copy key file
  cp -f "$app_dir/$filename" "$HOME/.ssh/"
  
  # Chmod permissions to RW
  chmod 600 "$HOME/.ssh/$filename"
done


#---- Create log entry - start

# Create log entry
echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile


#---- Check & Set LAN connection status & type
# Check for LAN connectivity using IP address and host name.
# rsync_connection_type: '1' for SSLH, '2' for PF, '3' for LAN connection

# Check LAN connectivity 1 - hostname.localdomain
localdomain_address_url1=$localdomain_address_url
ssh -q -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
-o "BatchMode yes" \
-o "StrictHostKeyChecking no" \
-o "ConnectTimeout 5" \
-p $ssh_port \
$rsync_username@$localdomain_address_url1 echo OK
lan_server_domain_status1=$?

# Check LAN connectivity 2 - hostname only
# Remove the domain name from $localdomain_address_url
localdomain_address_url2=${localdomain_address_url%%.*}
ssh -q -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
-o "BatchMode yes" \
-o "StrictHostKeyChecking no" \
-o "ConnectTimeout 5" \
-p $ssh_port \
$rsync_username@$localdomain_address_url2 echo OK
lan_server_domain_status2=$?

# Check LAN connectivity - IP address
ssh -q -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
-o "BatchMode yes" \
-o "StrictHostKeyChecking no" \
-o "ConnectTimeout 5" \
-p $ssh_port \
$rsync_username@$local_ip_address echo OK
lan_server_ip_status=$?

# Set LAN server connection status & url
if [ "$lan_server_domain_status1" = 0 ]
then
  # Set LAN active
  lan_address="$localdomain_address_url1"
  lan_server_status=1

  # Set 'rsync_connection_type' temporary override
  rsync_connection_type=3

  # Create log entry
  echo -e "#---- SUCCESS - CHECKING LAN AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 3 [LAN connection $lan_address:$ssh_port]\n" >> $logfile
elif [ ! "$lan_server_domain_status1" = 0 ] && [ "$lan_server_domain_status2" = 0 ]
then
  # Set LAN active
  lan_address="$localdomain_address_url2"
  lan_server_status=1

  # Set 'rsync_connection_type' temporary override
  rsync_connection_type=3

  # Create log entry
  echo -e "#---- SUCCESS - CHECKING LAN AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 3 [LAN connection $lan_address:$ssh_port]\n" >> $logfile
elif [ ! "$lan_server_domain_status" = 0 ] && [ "$lan_server_ip_status" = 0 ]
then
  # Set LAN active
  lan_address="$local_ip_address"
  lan_server_status=1

  # Set 'rsync_connection_type' temporary override
  rsync_connection_type=3

  # Create log entry
  echo -e "#---- SUCCESS - LAN NETWORK AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 3 [LAN connection $lan_address:$ssh_port]\n" >> $logfile
elif [ ! "$lan_server_domain_status" = 0 ] && [ ! "$lan_server_ip_status" = 0 ]
then
  # Set LAN inactive
  lan_server_status=0

  # If LAN inactive & no internet WAN access then exit ('0' is disabled, '1' is enabled)
  if [ "$connection_up" = 0 ]
  then
    # Create log entry
    echo -e "#---- WARNING - LAN & WAN RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [WAN and LAN]\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
  fi
fi


#---- Check & Set remote WAN connection status & type
# Check for WAN connectivity
# rsync_connection_type: '1' for SSLH, '2' for PF, '3' for LAN connection
# Only sets if 'lan_server_status=0' (disabled)

if [ "$rsync_connection_type" = 1 ] && [ "$lan_server_status" = 0 ]
then
  # Check SSLH server status
  ssh -q -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
  -o "BatchMode yes" \
  -o "StrictHostKeyChecking no" \
  -o "ConnectTimeout 5" \
  -o ProxyCommand="openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert $app_dir/sslh.crt -key $app_dir/sslh-kodirsync.key" \
  $rsync_username@$localdomain_address_url echo OK
  sslh_server_status=$?

  if [ "$sslh_server_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- SUCCESS - RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC set to use Type 1 [SSLH connection $sslh_address_url:$sslh_port]\n" >> $logfile
  elif [ ! "$sslh_server_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- WARNING - RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [SSLH and LAN]\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    # Exit on fail
    exit 1
  fi
elif [ "$rsync_connection_type" = 2 ] && [ "$lan_server_status" = 0 ]
then
  # Check PF SSH server status
  ssh -q -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
  -o "BatchMode yes" \
  -o "StrictHostKeyChecking no" \
  -o "ConnectTimeout 5" \
  -p  $pf_port \
  $rsync_username@$localdomain_address_url echo OK
  pf_server_status=$?

  if [ "$pf_server_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- SUCCESS - RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC set to use Type 2 [PF connection $pf_address_url:$pf_port]\n" >> $logfile
  elif [ ! "$pf_server_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- WARNING - RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [PF and LAN]\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    # Exit on fail
    exit 1
  fi
fi


#---- Set SSH connection cmd script

# rsync_connection_type: '1' for SSLH, '2' for PF, '3' for LAN connection
if [ "$rsync_connection_type" = 1 ]
then
  # Set SSLH WAN ssh cmd script - rsync version
  rsync_ssh_cmd="ssh -i $ssh_dir/${rsync_username}_kodirsync_id_ed25519 -T -x -c aes128-gcm@openssh.com -o Compression=no -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -o ProxyCommand='openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert $app_dir/sslh.crt -key $app_dir/sslh-kodirsync.key'"

  # Set SSLH WAN ssh cmd script - ssh version
  # The ssh version uses an array to enclose the ssh cmd to fix issues I had passing the 'proxycommand' args.
  ssh_cmd=("ssh" "-i" "$ssh_dir/${rsync_username}_kodirsync_id_ed25519" "-o" "StrictHostKeyChecking=no" "-o" "ConnectTimeout=$ssh_connecttimeout" "-o" "ServerAliveInterval=$ssh_serveraliveinterval" "-o" "ProxyCommand=openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert $app_dir/sslh.crt -key $app_dir/sslh-kodirsync.key")

  # Set Rsync address
  rsync_address="$sslh_address_url"
elif [ "$rsync_connection_type" = 2 ]
then
  # Set PF WAN ssh cmd script - rsync version
  rsync_ssh_cmd="ssh -i $ssh_dir/${rsync_username}_kodirsync_id_ed25519 -T -x -c aes128-gcm@openssh.com -o Compression=no -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -p $pf_port"

  # Set PF ssh cmd script - ssh version
  # The ssh version uses an array to enclose the ssh cmd to fix issues I had passing the 'proxycommand' args.
  ssh_cmd=("ssh" "-i" "$ssh_dir/${rsync_username}_kodirsync_id_ed25519" "-o" "StrictHostKeyChecking=no" "-o" "ConnectTimeout=$ssh_connecttimeout" "-o" "ServerAliveInterval=$ssh_serveraliveinterval" "-p $pf_port")

  # Set Rsync address
  rsync_address="$pf_address_url"
elif [ "$rsync_connection_type" = 3 ]
then
  # Set LAN ssh cmd script - rsync version
  rsync_ssh_cmd="ssh -i $ssh_dir/${rsync_username}_kodirsync_id_ed25519 -T -x -c aes128-gcm@openssh.com -o Compression=no -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -p $ssh_port"

  # Set LAN ssh cmd script - ssh version
  # The ssh version uses an array to enclose the ssh cmd to fix issues I had passing the 'proxycommand' args.
  ssh_cmd=("ssh" "-i" "$ssh_dir/${rsync_username}_kodirsync_id_ed25519" "-o" "StrictHostKeyChecking=no" "-o" "ConnectTimeout=$ssh_connecttimeout" "-o" "ServerAliveInterval=$ssh_serveraliveinterval" "-p $ssh_port")
  
  # Set Rsync address
  rsync_address="$lan_address"
fi


#---- Run Rsync and retrieve lists
# Run rsync and retrieve from server 'kodirsync_control_list.txt'.

# Get rsync control lists
rsync_getcontrollist


#---- Create lists
# Create lists, args and arrays
source $app_dir/kodirsync_clientapp_list1.sh


#---- Create Kodirsync control list regex and arrays
# Whitelist and Blacklist are based on category source and media folder names only.
# Whitelist and Blacklist do NOT use filenames. Only filename parent folder name.
# Server and client 'kodirsync_control_list.txt' files are combined.

# Initialize array
input_control_LIST=()

# Read 'kodirsync_control_list.txt' - server file
if [ -f "$work_dir/kodirsync_control_list.txt" ]
then
  while IFS= read -r line
  do
    # Check for non-conforming lines
    [[ "$line" =~ ^\#.*$|^$|^\ .*$|^sample.*$ ]] && continue
    [[ ! "$line" =~ ^[bBwW]\;.*$ ]] && continue

    # Trim leading/trailing whitespace
    line=${line##+([[:space:]])}
    line=${line%%+([[:space:]])}

    # Create array list
    input_control_LIST+=( "$line" )
  done < <( cat "$work_dir/kodirsync_control_list.txt" )
fi

# Read 'kodirsync_control_list.txt' - client file
if [ -f "$control_list_src" ]
then
  while IFS= read -r line
  do
    # Check for non-conforming lines
    [[ "$line" =~ ^\#.*$|^$|^\ .*$|^sample.*$ ]] && continue
    [[ ! "$line" =~ ^[bBwW]\;.*$ ]] && continue

    # Trim leading/trailing whitespace
    line=${line##+([[:space:]])}
    line=${line%%+([[:space:]])}

    # Check if pattern exists
    found=false
    for pattern in "${input_control_LIST[@]}"
    do
      if [[ "$pattern" == "$line" ]]; then
        found=true
        break
      fi
    done
    if [ "$found" = false ]
    then
      input_control_LIST+=( "$line" )
    fi
  done < <( cat "$control_list_src" )
else
  # If no '$control_list_src' exist copy tmpl
  cp $app_dir/kodirsync_control_list.tmpl $app_dir/kodirsync_control_list.txt
fi

# Initialize master, whitelist and blacklist
master_control_LIST=()
white_control_regex_LIST=()
black_control_regex_LIST=()

# Create control list regex arrays
while IFS=';' read -r condition src_category name
do
  # Check for non-conforming lines
  [[ "$condition" =~ ^\#.*$|^$|^\s.*$|^sample.*$ ]] && continue
  [[ ! "$condition" =~ ^[bBwW]$ ]] && continue

  # Create master b/w list array
  master_control_LIST+=( "$condition;$src_category;$name" )

  # Check for alias 'name' wildcard '*'
  if [[ "$name" =~ ^.*(\*|\.\*)$ ]]
  then
    name="$(printf '%q' "$(echo "$name" | sed 's/\(\.\)\?\*$//')").*"
  else
    name="$(printf "%q" "$name")/.*"
  fi

  # Modify '$src_category' to include '(stream)?'
  src_category="$(printf '%q' "$src_category")"

  # White list array
  if [[ "$condition" =~ ^[wW]$ ]]
  then
    # Check if pattern exists
    found=false
    for pattern in "${white_control_regex_LIST[@]}"
    do
      if [[ "$pattern" == "$src_category(/.*)?/$name" ]]
      then
        found=true
        break
      fi
    done
    if [ "$found" = false ]
    then
      # Create regex list array
      white_control_regex_LIST+=( "$src_category(/.*)?/$name" )
    fi
  fi

  # Black list array
  if [[ "$condition" =~ ^[bB]$ ]]
  then
    # Check if pattern exists
    found=false
    for pattern in "${black_control_regex_LIST[@]}"
    do
      if [[ "$pattern" == "$src_category(/.*)?/$name" ]]
      then
        found=true
        break
      fi
    done
    if [ "$found" = false ]
    then
      black_control_regex_LIST+=( "$src_category(/.*)?/$name" )
    fi
  fi
done < <( printf '%s\n' "${input_control_LIST[@]}" | sed 'y/äöüÄÖÜß/aouAOUs/;y/ÄÖÜß/äöüß/' | uniq -u )

# Create simple regex lists (non-sed)
# Iterate over the array elements
# Create '$white_dir_filter_regex'
result=""
if [ ${#white_control_regex_LIST[@]} -eq 0 ]
then
  # Check array is empty, add a dummy entry line
  result+="dummy_entry|"
else
  for element in "${white_control_regex_LIST[@]}"
  do
    # Concatenate the element with the pipe symbol
    result+="${element}|"
  done
fi
# Remove the trailing pipe symbol
white_dir_filter_regex="${result%|}"

# Create '$black_dir_filter_regex'
result=""
if [ ${#black_control_regex_LIST[@]} -eq 0 ]
then
  # Check array is empty, add a dummy entry line
  result+="dummy_entry|"
else
  for element in "${black_control_regex_LIST[@]}"
  do
    # Concatenate the element with the pipe symbol
    result+="${element}|"
  done
fi
# Remove the trailing pipe symbol
black_dir_filter_regex="${result%|}"


#---- Get server share list

# Get server base share list (i.e video/documentary, video/series, music, photo)
get_server_sharelist


#---- Create Kodirsync share list regex

# Create simple regex line (non-sed)
# Iterate over the array elements
# Create '$share_dir_filter_regex1'
result=""
for element in "${share_server_LIST[@]}"
do
  # Concatenate the element with the pipe symbol
  result+="${element}|"
done
# Remove the trailing pipe symbol
share_dir_filter_regex1="${result%|}"

# Create '$share_dir_filter_regex2'
result=""
for element in "${share_server_LIST[@]}"
do
  # If $element contains two dirs (i.e video/movies)
  if [[ "$element" =~ ^.*\/.*$ ]]
  then
    element=$(echo "$element" | sed 's#/#(/#; s#$#)?#')
  fi
  # Concatenate the element with the pipe symbol
  result+="${element}|"
done
# Remove the trailing pipe symbol
share_dir_filter_regex2="${result%|}"


#---- Get server file lists

# Get server file list
get_server_filelist


#---- Create Kodirsync share dirs on local

# Remove old or depreciated Kodirsync share dirs
find "$dst_dir" -mindepth 1 -maxdepth 2 -type d -regextype posix-extended -not -iregex ".*/(rsync_tmp)(/.*)?$|.*/($exclude_os_dir_filter_regex)(/.*)?$|$dst_dir/($share_dir_filter_regex2)$" 2> /dev/null -exec rm -rf "{}" \;

# Create latest/current Kodirsync share dirs
# These dirs match Kodirsync server
while read -r line
do
  # Create dst share dirs
	mkdir -p "$dst_dir/$line"
done < <( printf '%s\n' "${share_server_LIST[@]}" )


#---- Create download list of files - server files
# Note: Speed processing this part of the script depends on hardware. Be patient.
echo "Creating new download list. This can be slow, be patient..."

# Initialize dl list array
dl_server_LIST=()

dl_total_size=0

# Set net dl size
avail_storage_bytes="$storage_cap"

# Prioritize whitelist entries for download - video, music, photos, audio, audiobook files only
# All file video, audio and audiobook metadata including subtitles are excluded at this stage
# Make whitelist elements of the "${all_server_LIST[@]}" array
for element in "${all_server_LIST[@]}"
do
  # Add line if entry if available storage space
  while IFS=';' read -r file size date
  do
    # Extract the size portion from $size
    size="${size%%[!0-9]*}"

    # Check if the line matches the whitelist pattern
    [[ ! "$file" =~ ^(.*/)?($white_dir_filter_regex)(/.*)?$ ]] && continue
    # Check if the line matches the file extension pattern
    [[ ! "$file" =~ ^.*\.($video_format_filter_regex|$audio_format_filter_regex|$audiobook_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$ ]] && continue

    # Check if the video is HDR/HDR10 encoded ('1' for enabled/allowed, '0' for disabled)
    if [ "$hdr_enable" = 0 ]
    then
      [[ "$file" =~ ^.*(\[.*)?($exclude_hdr_filter_regex)(.*\])?.*$ ]] && continue
    fi

    # Add entry only if '$size' is less than available storage
    if [[ "$size" -le "$avail_storage_bytes" ]]
    then
      # Add line to dl list
      dl_server_LIST+=( "$element" )

      # Deduct entry file size from $avail_storage_bytes
      avail_storage_bytes=$(( avail_storage_bytes - size ))

      # Add the DL file total size $dl_total_size (bytes)
      dl_total_size=$(( dl_total_size + size ))
    fi
  done < <( echo "$element" )
done

# Add remaining entries - non-whitelist - video, music, photos, audio, audiobook files only
# All file video, audio and audiobook metadata including subtitles are excluded at this stage
# Make non-whitelist elements of the "${all_server_LIST[@]}" array
for element in "${all_server_LIST[@]}"
do
  # Add line if entry if available storage space
  while IFS=';' read -r file size date
  do
    # Extract the size portion from $size
    size="${size%%[!0-9]*}"

    # Check if the line matches the whitelist pattern
    [[ "$file" =~ ^(.*/)?($white_dir_filter_regex)(/.*)?$ ]] && continue

    # Check if the line matches the file extension pattern
    [[ ! "$file" =~ ^.*\.($video_format_filter_regex|$audio_format_filter_regex|$audiobook_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$ ]] && continue

    # Check if the video is HDR/HDR10 encoded ('1' for enabled/allowed, '0' for disabled)
    if [ "$hdr_enable" = 0 ]
    then
      [[ "$file" =~ ^.*(\[.*)?($exclude_hdr_filter_regex)(.*\])?.*$ ]] && continue
    fi

    # Check if 'video file' exceeds maximum file size limit
    [[ "$file" =~ ^.*\.($video_format_filter_regex)$ ]] && [[ "$size" -gt "$max_video_size_limit" ]] && continue

    # Check if 'other file' exceeds maximum file size limit
    [[ "$file" =~ ^.*\.($audio_format_filter_regex|$audiobook_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$ ]] && [[ "$size" -gt "$max_other_size_limit" ]] && continue

    # Add file entry only if storage space is available
    if [[ "$size" -le "$avail_storage_bytes" ]]
    then
      # Add line to dl list
      dl_server_LIST+=( "$element" )

      # Deduct entry file $size from $avail_storage_bytes
      avail_storage_bytes=$(( avail_storage_bytes - size ))

      # Add the DL file total size $dl_total_size (bytes)
      dl_total_size=$(( dl_total_size + size ))
    fi
  done < <( echo "$element" )
done

# Add subtitle files
# Subtitle files are of nominal file size and added to the disk without storage
# space calculations. 
# Find matching subtitle for "${dl_server_LIST[@]}" dl list
# Create a tmp copy
tmp_dl_server_LIST=( "${dl_server_LIST[@]}" )
# Iterate over the array elements
for element in "${tmp_dl_server_LIST[@]}"
do
  # Match subtitle in "${all_server_LIST[@]}"
  filename=$(printf '%q' "$element" | awk -F';' '{print $1}')
  element_regex="${filename%.*}.*\.($subtitle_format_filter_regex)"

  # Iterate over all_server_LIST and check for matches for subtitle files
  for line in "${all_server_LIST[@]}"
  do
    # Match subtitle in "${all_server_LIST[@]}"
    line_col1=$(echo "$line" | awk -F';' '{print $1}')
    if [[ "$line_col1" =~ ^$element_regex$ ]]
    then
      # Add subtitle file to "${dl_server_LIST[@]}"
      dl_server_LIST+=( "$line" )
    fi
  done
done


#---- Create current client list of files - local files
# This is a list of current client files before rsync is performed.

# Create a current list of destination files
all_client_LIST=()
while IFS= read -r line
do
  all_client_LIST+=("$line")
done < <( find "$dst_dir" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex)(/.*)?|.*/rsync_tmp(/.*)?|.*/kodirsync_app(/.*)?" -type f -regextype posix-extended -not -iregex ".*/($exclude_file_filter_regex)$" -type f -regextype posix-extended -iregex ".*\.($video_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$|.*\.($audio_format_filter_regex)$|.*\.($audiobook_format_filter_regex)$|.*\.($subtitle_format_filter_regex)$" -printf '%P;%s;%T@\n' 2> /dev/null | sort -t ';' -k3n )


#---- Prune, remove old and depreciated media files from destination

# Run 'kodirsync_clientapp_prune.sh'
source $app_dir/kodirsync_clientapp_prune.sh


#---- Perform rsync task

# Display msg ( for terminal only)
echo "Total disk kodirsync storage capacity: $storage_cap bytes or $(($storage_cap / (1024 * 1024 * 1024)))GB"
echo "Total download size: $dl_total_size bytes or $(($dl_total_size / (1024 * 1024 * 1024)))GB"
echo "Remaining Kodirsync storage space: $avail_storage_bytes bytes or $(($avail_storage_bytes / (1024 * 1024 * 1024)))GB"

# Create rsync input file list
printf '%s\n' "${dl_server_LIST[@]}" | awk -F';' '{ print $1 }' > $work_dir/rsync_process_list.txt

# Create log entry
echo -e "#---- ACTION - RSYNC TASK ONLY\nTime : $(date)\nRsync list : rsync_process_list.txt\n" >> $logfile

# Run 'kodirsync_clientapp_rsync_main.sh'
source $app_dir/kodirsync_clientapp_rsync_main.sh


#---- Finish Line ------------------------------------------------------------------

# Create log entry
echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
#-----------------------------------------------------------------------------------