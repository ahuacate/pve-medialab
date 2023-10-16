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

#---- UTF-8 Ascii cleanup

cleanup_utf8() {
    # Makes all input text UTF-8 ascii compliant

    # Usage:
        # Make $name UTF-8 ascii (func cleanup_utf8)
        # name=$(cleanup_utf8 "$name")

    # Set argument parameters
    local input="$1"
    # Set other variables
    local cleaned_input=$(echo "$input" | sed 's/ä/a/g; s/ö/o/g; s/ü/u/g; s/Ä/A/g; s/Ö/O/g; s/Ü/U/g; s/ß/ss/g')
    echo "$cleaned_input"
}


#---- Get Kodirsync remote server b/w control list file

function get_remote_control_list() {
    # Gets blacklist and whitelist control list file from remote server.
    #
    # Parameters:
    #   None.
    #
    # Output:
    #   - "${rsync_control_LIST[@]}"
    #
    # Usage:
    #   get_remote_control_list

    # Set other variables
    local source='~/'
    local max_retries="$rsync_retry_cnt"  # Maximum number of retries (adjust as needed)

    # Get control list file from server
    local i
    for ((i = 0; retry <= max_retries; i++)); do
        # Run cmd
        rsync -avI \
        --no-relative \
        --include='kodirsync_control_list.txt' \
        --exclude='*' \
        -e "$rsync_ssh_cmd" \
        $rsync_username@$rsync_address:$source \
        $work_dir 2>/dev/null

        # Exit code
        local exit_code=$?

        # Process exit codes
        if [ "$exit_code" = 0 ]; then
            # On success
            echo -e "#---- SUCCESS - RSYNC CONTROL FILES\nTime : $(date)\nFunction : get_remote_control_list\n" >> $logfile  # Log entry

            return 0  # Set exit code
        else
            # On fail
            if [ $i -lt $max_retries ]; then
                sleep $rsync_retry_sleep  # Apply sleep period before retry
            else
                echo -e "#---- WARNING - RSYNC CONTROL FILES\nError Code ("$exit_code") : $(date)\nFunction : get_remote_control_list\nScript line number : $LINENO\nRetry count : "$ssh_connect_retrycount"x failed attempts\n" >> $logfile  # Log entry

                return 1  # Set exit code
            fi
        fi
    done
}


#---- Get Kodirsync remote server file list

function get_remote_file_LIST() {
    # Gets a complete file list, regex filtered, from the remote server.
    # All non media files are filtered out.
    #
    # Parameters:
    #   None.
    #
    # Output:
    #   - ${all_remote_LIST[@]}
    #
    # Usage:
    #   get_remote_file_LIST

    # Set other variables
    local source='\$HOME/'
    local max_retries="$rsync_retry_cnt"  # Maximum number of retries (adjust as needed)

    # Get list from server
    local i
    for ((i = 0; i <= max_retries; i++)); do
        # Cmd - Get list of media files
        eval "expanded_cmd=\"find '"$source"' -regextype posix-extended -not -iregex '.*/($exclude_dir_filter_regex)/.*|.*/($black_dir_filter_regex)/.*' -type f -regextype posix-extended -not -iregex '.*/($exclude_file_filter_regex)$' -type f -regextype posix-extended -iregex '.*\\.($video_format_filter_regex)$|.*\\.($image_format_filter_regex)$|.*\\.($audio_format_filter_regex)$|.*\\.($audiobook_format_filter_regex)$|.*\\.($subtitle_format_filter_regex)$' -printf '%P;%s;%T@\\n' 2> /dev/null | sort -t ';' -k3 -n --reverse\""

        # Run cmd
        all_remote_LIST=()  # Initialize array
        mapfile -t all_remote_LIST < <("${ssh_cmd[@]}" "$rsync_username@$rsync_address" "bash -c \"$expanded_cmd\"")  # Run cmd and read the output into the array directly

        # Exit code
        local exit_code=$?  # Capture the exit code of the first command in the pipe

        # Process exit codes
        if [ "$exit_code" = 0 ]; then
            # On success
            echo -e "#---- SUCCESS - GET SERVER FILE LIST\nTime : $(date)\nFunction : get_remote_file_LIST\n" >> $logfile  # Log entry
            return 0  # Set exit code
        else
            # On fail
            if [ $i -lt $max_retries ]; then
                sleep $rsync_retry_sleep  # Apply sleep period before retry
            else
                echo -e "#---- WARNING - GET SERVER FILE LIST\nError Code ($check_code) : $(date)\nFunction : get_remote_file_LIST\nScript line number : $LINENO\nRetry count : "$ssh_connect_retrycount"x failed attempts\n" >> $logfile  # Log entry
                return 1  # Set exit code
            fi
        fi
    done
}


#---- Create Kodirsync remote server base dir share list

function make_basedir_LIST() {
    # Creates a list of the remote server base dir shares.
    # Filtering by regex.
    #
    # Parameters:
    #   1. "${all_remote_LIST[@]}""
    #
    # Output:
    #   - ${remote_basedir_LIST[@]}
    #
    # Usage:
    #   make_basedir_LIST

    # Iterate through all_remote_LIST 
    local item
    local new_entry
    local already_exists
    local first_dir
    remote_basedir_LIST=()  # Initialize the remote_basedir_LIST array
    for item in "${all_remote_LIST[@]}"; do
        # Check if a directory should be excluded
        if [[ "$item" =~ ^((.*/)?($exclude_os_dir_filter_regex)(/.*)?|(.*/)?($exclude_dir_filter_regex)(/.*)?|(.*/)?($black_dir_filter_regex)(/.*)?) ]]; then
            continue
        fi

        # Check if item matches video file regex
        if [[ "$item" =~ ^($video_subfolder_dir_filter_regex)(/.*)? ]]; then
            new_entry="${BASH_REMATCH[1]}"
            
            # Check if the new entry is not already in remote_basedir_LIST
            already_exists=false
            for entry in "${remote_basedir_LIST[@]}"; do
                if [[ "$entry" == "$new_entry" ]]; then
                    already_exists=true
                    continue 2
                fi
            done
            
            # Add the new entry if it doesn't already exist
            if ! "$already_exists"; then
                remote_basedir_LIST+=( "$new_entry" )
                continue
            fi
        else
            # If it's not a video file, use sed to extract the first directory
            first_dir="$(echo "$item" | sed 's/\/.*//' )"
            if [ -n "$first_dir" ]; then
                new_entry="$first_dir"
                
                # Check if the new entry is not already in remote_basedir_LIST
                already_exists=false
                for entry in "${remote_basedir_LIST[@]}"; do
                    if [[ "$entry" == "$new_entry" ]]; then
                        already_exists=true
                        continue 2
                    fi
                done
                
                # Add the new entry if it doesn't already exist
                if ! "$already_exists"; then
                    remote_basedir_LIST+=( "$new_entry" )
                fi
            fi
        fi
    done
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check for Internet connectivity
# List of well-known websites to test connectivity (in case one is blocked)
websites=( "google.com 443" "github.com 443" "cloudflare.com 443" "apple.com 443" "amazon.com 443" )
# Loop through each website in the list
for website in "${websites[@]}"; do
    # Test internet connectivity
    nc -zw1 $website > /dev/null 2>&1
    # Check the exit status of the ping command
    if [ $? = 0 ]; then
        connection_up=1  # Flag to track if internet connection is up
        break
    else
        connection_up=0  # Flag to track if internet connection is down
    fi
done


#---- Set configuration overrides
# A override temporarily sets script variables and arguments for local
# device OS compatibility.

if [ "$ostype" = 'termux' ]; then
    # Android Termux clients
    # Search for priority '$dst_dir' location with '.kodirsync_storage' file
    # Android exFAT mount path. Full path '/storage/XXXX-XXXX/Android/data/com.termux/files/'.
    dst_dir_chk=""
    while IFS= read -r path; do
        # Check for hidden file '.kodirsync_storage'
        if [ -f "$path/.kodirsync_storage" ]; then
            dst_dir_chk="$path"
        fi
    done < <(find /storage -path "*/$android_path/$kodirsync_storage_dir" -type d 2> /dev/null)

    # Set '$dst_dir' location
    if [ -n "$dst_dir_chk" ] && [ -d "$dst_dir_chk" ]; then
        dst_dir="$dst_dir_chk"  # Priority directory found and exists, set $dist_dir
    else
        echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync destination directory not found.\nBye...\n\e[39m"  # No storage dir found
        exit 0
    fi

    # Rsync throttle enable ('1' for enabled, '0' for disabled)
    if [ "$termux_throttle" = 0 ]; then
        throttle=0  # Rsync throttle disabled
    elif [ "$termux_throttle" = 1 ]; then
        throttle=1  # Rsync throttle enabled
    fi

    # Limit destination storage capacity (bytes)
    # Apply user preset $dst_max_storage_limit.
    # Apply exFAT storage limit $android_storage_cap.
    # Set $dst_max_limit
    if [ "$dst_max_storage_limit" = 0 ]; then
        dst_max_limit=$((android_storage_cap * 1024 * 1024 * 1024 * 1024))  # Limit - apply Android cap limit
    else
        # Limit - check preset $dst_max_storage_limit is not greater than exFAT limit ($android_storage_cap)
        if (( $((android_storage_cap * 1024 * 1024 * 1024 * 1024)) < $((dst_max_storage_limit * 1024 * 1024 * 1024)) )); then
            dst_max_limit=$((android_storage_cap * 1024 * 1024 * 1024 * 1024))
        else
            dst_max_limit=$((dst_max_storage_limit * 1024 * 1024 * 1024))
        fi
    fi

    # Set storage to folder type ('1' for disk based, '2' for folder based)
    storage_type='2'

    # Set rsync thread limit for Termux (override)
    max_rsync_threads_lan=$max_rsync_threads_termux  # Sets a thread limit for Termux
    max_rsync_threads_lan=$max_rsync_threads_termux  # Sets a thread limit for Termux
else
    # ELEC and Linux client
    # Search for priority '$dst_dir' location with hidden kodirsync_storage' file
    # Check Android exFAT/ext4 mount path. Android path is '/storage/XXXX-XXXX/Android/data/com.termux/files/'.
    dst_dir_chk=""
    while IFS= read -r path; do
        # Check for hidden file '.kodirsync_storage'
        if [ -f "$path/.kodirsync_storage" ]; then
            dst_dir_chk="$path"
        fi
    done < <(find / \( -path "*/$android_path/$kodirsync_storage_dir" -o -path "*/$kodirsync_storage_dir" \) -type d 2> /dev/null)

    # Set '$dst_dir' location
    if [ -n "$dst_dir_chk" ] && [ -d "$dst_dir_chk" ]; then
        dst_dir="$dst_dir_chk"  # Priority directory found and exists, set $dist_dir
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
    if [ "$stor_fs" = 'exfat' ]; then
        # Set destination storage limit (bytes) - exFAT ('0' for unlimited, other specified)
        if [ "$dst_max_storage_limit" = 0 ]; then
            dst_max_limit=$((android_storage_cap * 1024 * 1024 * 1024 * 1024))  # Limit - apply Android cap limit
        else
            # Limit - check preset $dst_max_storage_limit is not greater than exFAT limit ($android_storage_cap)
            if (( $((android_storage_cap * 1024 * 1024 * 1024 * 1024)) < $((dst_max_storage_limit * 1024 * 1024 * 1024)) )); then
                dst_max_limit=$((android_storage_cap * 1024 * 1024 * 1024 * 1024))
            else
                dst_max_limit=$((dst_max_storage_limit * 1024 * 1024 * 1024))
            fi
        fi
    else
        # Set destination storage limit (bytes) - ext4 ('0' for unlimited, other specified)
        if [ "$dst_max_storage_limit" = 0 ]; then
            dst_max_limit=0
        else
            dst_max_limit=$((dst_max_storage_limit * 1024 * 1024 * 1024))
        fi
    fi

    # Mountpoint check status ('1' for valid, '0' for invalid)
    # Here we check if $dst_dir is a mounted USB disk with the wrong disk label.
    # If the disk label is wrong (i.e 'kodirsync') then $storage_type is et to folder.
    mnt_point_chk=$(echo $dst_dir | grep -q -E "^(/var/media/.*/$kodirsync_storage_dir|/mnt/.*/$kodirsync_storage_dir)" && echo "1" || echo "0")
    if [ "$mnt_point_chk" = 1 ]; then
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

        if [ ! "$label" = 'kodirsync' ]; then
            # Update args for writing to Kodirsync user config files
            name='storage_type'
            value='2'  # Value '1' for disk, '2' for folder
            sed -i "s#^${name}\=.*#${name}\=${value}#g" $app_dir/kodirsync_clientapp_user.cfg
            storage_type=2  # Set $storage_type

            # Wrong disk label
            echo -e "\e[93m[WARNING]\e[39m \e[97mDisk label 'kodirsync' not set for device $device.\nThe disk should have a disk label named 'kodirsync'.\n\e[39m"
        else
            # Update args for writing to Kodirsync user config files
            name='storage_type'
            value='1'  # Value '1' for disk, '2' for folder
            sed -i "s#^${name}\=.*#${name}\=${value}#g" $app_dir/kodirsync_clientapp_user.cfg
            storage_type=1  # Set $storage_type
        fi
    fi
fi


#---- Set "$dst_dir/rsync_tmp" dir
rsync_tmp="$dst_dir/rsync_tmp"
mkdir -p "$rsync_tmp/multipart"  # Include a multipart partial rsync dir


#---- Check destination storage status (type - '1' for disk, '2' for dir)

if [ "$storage_type" = 1 ] && [ ! "$ostype" = 'termux' ]; then
    # Disk based storage - set $mnt_point
    # $mnt_point is the '../kodirsync' dir used for a disk mount. The mountpoint is
    # '/mnt/kodirsync' or '/var/media/kodirsync' depending on your client device OS.
    # The disk label is 'kodirsync' which is set by the Linux/ELEC Kodirsync installer.

    # Get mountpoint $mnt_point
    mnt_point=$(echo "$dst_dir" | sed 's|\(/kodirsync\)/.*|\1|')

    # Check disk storage mnt status ('1' for valid, '0' for invalid)
    storage_type_status=$(mountpoint -q "$mnt_point" && echo "1" || echo "0")
elif [ "$storage_type" = 2 ]; then
    # Set destination dir status ('1' for valid, '0' for invalid)
    storage_type_status=$([ -d "$dst_dir" ] && echo "1" || echo "0")
fi

# If storage status returns '0' - exit script ('1' for valid, '0' for invalid)
if [ "$storage_type_status" = 0 ]; then
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
if [ "$dst_max_limit" = 0 ]; then
    storage_cap=$dst_max_cap  # Set storage capacity to disk maximum (bytes)
elif [ ! "$dst_max_limit" = 0 ]; then
    # Check $dst_max_cap does not exceed limits (bytes)
    if ((dst_max_limit > dst_max_cap)); then
        storage_cap=$dst_max_cap  # Set storage capacity to disk maximum (bytes)
    else
        storage_cap=$dst_max_limit  # Set storage capacity to max limit (bytes)
    fi
fi


#---- Set maximum file size clip

# Set video file size clip
if [ ! "$max_video_size" = 0 ]; then
    # Set $max_video_size_limit in bytes
    max_video_size_limit=$((max_video_size * 1024 * 1024 * 1024))
else
    # Set to unlimited 100Gb limit
    max_video_size_limit=107374182400
fi

# Set other file size clip
if [ ! "$max_other_size" = 0 ]; then
    # Set $max_video_size_limit in bytes
    max_other_size_limit=$((max_other_size * 1024 * 1024 * 1024))
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

while true; do
    # Check LAN connectivity 1 - hostname.localdomain
    localdomain_address_url1=$localdomain_address_url
    ssh -q -i $HOME/.ssh/"$rsync_username"_kodirsync_id_ed25519 \
    -o "BatchMode yes" \
    -o "StrictHostKeyChecking no" \
    -o "ConnectTimeout 5" \
    -p $ssh_port \
    $rsync_username@$localdomain_address_url1 echo OK
    # Check the return code
    if [ $? = 0 ]; then
        lan_address="$localdomain_address_url1"
        lan_server_status=1  # Set LAN active
        rsync_connection_type=3   # Set 'rsync_connection_type' temporary override
        echo -e "#---- SUCCESS - CHECKING LAN AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 3 [LAN connection $lan_address:$ssh_port]\nScript line number : $LINENO\n" >> $logfile  # Create log entry
        break  # Break out of the loop when LAN is active
    fi

    # Check LAN connectivity 2 - hostname only
    # Remove the domain name from $localdomain_address_url
    localdomain_address_url2="${localdomain_address_url%%.*}"
    ssh -q -i $HOME/.ssh/"$rsync_username"_kodirsync_id_ed25519 \
    -o "BatchMode yes" \
    -o "StrictHostKeyChecking no" \
    -o "ConnectTimeout 5" \
    -p $ssh_port \
    $rsync_username@$localdomain_address_url2 echo OK
    # Check the return code
    if [ $? = 0 ]; then
        lan_address="$localdomain_address_url2"
        lan_server_status=1  # Set LAN active
        rsync_connection_type=3   # Set 'rsync_connection_type' temporary override
        echo -e "#---- SUCCESS - CHECKING LAN AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 3 [LAN connection $lan_address:$ssh_port]\nScript line number : $LINENO\n" >> $logfile  # Create log entry
        break  # Break out of the loop when LAN is active
    fi

    # Check LAN connectivity - IP address
    if [[ "$local_ip_address" =~ ^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$ ]]; then
        ssh -q -i $HOME/.ssh/"$rsync_username"_kodirsync_id_ed25519 \
        -o "BatchMode yes" \
        -o "StrictHostKeyChecking no" \
        -o "ConnectTimeout 5" \
        -p $ssh_port \
        $rsync_username@$local_ip_address echo OK
        # Check the return code
        if [ $? = 0 ]; then
            lan_address="$local_ip_address"
            lan_server_status=1  # Set LAN active
            rsync_connection_type=3   # Set 'rsync_connection_type' temporary override
            echo -e "#---- SUCCESS - CHECKING LAN AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 3 [LAN connection $lan_address:$ssh_port]\nScript line number : $LINENO\n" >> $logfile  # Create log entry
            break  # Break out of the loop when LAN is active
        fi
    fi

    # If LAN inactive & no internet WAN access then exit ('0' is disabled, '1' is enabled)
    if [ "$connection_up" = 0 ]; then
        # Create log entry
        echo -e "#---- WARNING - LAN & WAN RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [WAN and LAN]\n" >> $logfile
        echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
        exit 1
    fi

    # Set LAN inactive
    lan_server_status=0
    break
done


#---- Check & Set remote WAN connection status & type
# Check for WAN connectivity
# rsync_connection_type: '1' for SSLH, '2' for PF, '3' for LAN connection
# Only sets if 'lan_server_status=0' (disabled)

if [ "$rsync_connection_type" = 1 ] && [ "$lan_server_status" = 0 ]; then
    # Check SSLH server status
    ssh -q -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
    -o "BatchMode yes" \
    -o "StrictHostKeyChecking no" \
    -o "ConnectTimeout 5" \
    -o ProxyCommand="openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert $app_dir/sslh.crt -key $app_dir/sslh-kodirsync.key" \
    $rsync_username@$localdomain_address_url echo OK
    sslh_server_status=$?

    if [ "$sslh_server_status" = 0 ]; then
        # Create log entry
        echo -e "#---- SUCCESS - RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC set to use Type 1 [SSLH connection $sslh_address_url:$sslh_port]\n" >> $logfile
    elif [ ! "$sslh_server_status" = 0 ]; then
        # Create log entry
        echo -e "#---- WARNING - RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [SSLH and LAN]\nScript line number : $LINENO\n" >> $logfile
        echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
        # Exit on fail
        exit 1
    fi
elif [ "$rsync_connection_type" = 2 ] && [ "$lan_server_status" = 0 ]; then
    # Check PF SSH server status
    ssh -q -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
    -o "BatchMode yes" \
    -o "StrictHostKeyChecking no" \
    -o "ConnectTimeout 5" \
    -p  $pf_port \
    $rsync_username@$localdomain_address_url echo OK
    pf_server_status=$?

    if [ "$pf_server_status" = 0 ]; then
        # Create log entry
        echo -e "#---- SUCCESS - RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC set to use Type 2 [PF connection $pf_address_url:$pf_port]\nScript line number : $LINENO\n" >> $logfile
    elif [ ! "$pf_server_status" = 0 ]; then
        # Create log entry
        echo -e "#---- WARNING - RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [PF and LAN]\n" >> $logfile
        echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
        # Exit on fail
        exit 1
    fi
fi


#---- Set SSH connection cmd script

# rsync_connection_type: '1' for SSLH, '2' for PF, '3' for LAN connection
if [ "$rsync_connection_type" = 1 ]; then
    # Set SSLH WAN ssh cmd script - rsync version
    rsync_ssh_cmd="ssh -i $ssh_dir/${rsync_username}_kodirsync_id_ed25519 -T -x -c aes128-gcm@openssh.com -o Compression=no -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -o ServerAliveCountMax=$ssh_serveralivecountmax -o ProxyCommand='openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert $app_dir/sslh.crt -key $app_dir/sslh-kodirsync.key'"

    # Set SSLH WAN ssh cmd script - ssh version
    # The ssh version uses an array to enclose the ssh cmd to fix issues I had passing the 'proxycommand' args.
    ssh_cmd=("ssh" "-i" "$ssh_dir/${rsync_username}_kodirsync_id_ed25519" "-o" "StrictHostKeyChecking=no" "-o" "ConnectTimeout=$ssh_connecttimeout" "-o" "ServerAliveInterval=$ssh_serveraliveinterval" "-o" "ServerAliveCountMax=$ssh_serveralivecountmax" "-o" "ProxyCommand=openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert $app_dir/sslh.crt -key $app_dir/sslh-kodirsync.key")

    # Set Rsync address
    rsync_address="$sslh_address_url"
elif [ "$rsync_connection_type" = 2 ]; then
    # Set PF WAN ssh cmd script - rsync version
    rsync_ssh_cmd="ssh -i $ssh_dir/${rsync_username}_kodirsync_id_ed25519 -T -x -c aes128-gcm@openssh.com -o Compression=no -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -o ServerAliveCountMax=$ssh_serveralivecountmax -p $pf_port"

    # Set PF ssh cmd script - ssh version
    # The ssh version uses an array to enclose the ssh cmd to fix issues I had passing the 'proxycommand' args.
    ssh_cmd=("ssh" "-i" "$ssh_dir/${rsync_username}_kodirsync_id_ed25519" "-o" "StrictHostKeyChecking=no" "-o" "ConnectTimeout=$ssh_connecttimeout" "-o" "ServerAliveInterval=$ssh_serveraliveinterval" "-o" "ServerAliveCountMax=$ssh_serveralivecountmax" "-p $pf_port")

    # Set Rsync address
    rsync_address="$pf_address_url"
elif [ "$rsync_connection_type" = 3 ]; then
    # Set LAN ssh cmd script - rsync version
    rsync_ssh_cmd="ssh -i $ssh_dir/${rsync_username}_kodirsync_id_ed25519 -T -x -c aes128-gcm@openssh.com -o Compression=no -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -o ServerAliveCountMax=$ssh_serveralivecountmax -p $ssh_port"

    # Set LAN ssh cmd script - ssh version
    # The ssh version uses an array to enclose the ssh cmd to fix issues I had passing the 'proxycommand' args.
    ssh_cmd=("ssh" "-i" "$ssh_dir/${rsync_username}_kodirsync_id_ed25519" "-o" "StrictHostKeyChecking=no" "-o" "ConnectTimeout=$ssh_connecttimeout" "-o" "ServerAliveInterval=$ssh_serveraliveinterval" "-o" "ServerAliveCountMax=$ssh_serveralivecountmax" "-p $ssh_port")
    
    # Set Rsync address
    rsync_address="$lan_address"
fi

#-----------------------------------------------------------------------------------

#---- Step 1 - Get remote server lists and files

# Get Kodirsync remote server b/w control list file
get_remote_control_list


#---- Step 2 - Create default regex filters

# Create default regex filters
source $app_dir/kodirsync_clientapp_list1.sh


#---- Step 3 - Create Kodirsync control list regex and arrays
# Whitelist and Blacklist are based on category source and media folder names only.
# Whitelist and Blacklist do NOT use filenames. Only filename parent folder name.
# Remote server and local 'kodirsync_control_list.txt' files are combined.

# Check for 'kodirsync_control_list.txt' file - local version
if [ ! -e "$app_dir/kodirsync_control_list.txt" ]; then
    cp "$app_dir/kodirsync_control_list.tmpl" "$app_dir/kodirsync_control_list.txt"  # Copy template file
fi

# Combine remote and local 'kodirsync_control_list.txt' files
if [ -e "$app_dir/kodirsync_control_list.txt" ] && [ -e "$work_dir/kodirsync_control_list.txt" ]; then
    cat "$app_dir/kodirsync_control_list.txt" "$work_dir/kodirsync_control_list.txt" | uniq -u > "$work_dir/tmp_control_list.txt"
elif [ -e "$app_dir/kodirsync_control_list.txt" ]; then
    cat "$app_dir/kodirsync_control_list.txt" | uniq -u > "$work_dir/tmp_control_list.txt"
elif [ -e "$work_dir/kodirsync_control_list.txt" ]; then
    cat "$work_dir/kodirsync_control_list.txt" | uniq -u > "$work_dir/tmp_control_list.txt"
else
    exit 1  # Both input files are missing
fi

# Create new b/w regex lists
white_control_regex_LIST=()  # Initialize array
black_control_regex_LIST=()  # Initialize array
while IFS=';' read -r condition src_category name; do
    # Remove non-conforming entries
    [[ "$condition" =~ ^\#.*$|^$|^\s.*$|^sample.*$ ]] && continue
    [[ ! "$condition" =~ ^[bBwW]$ ]] && continue

    # Trim leading/trailing whitespace
    condition=${condition##+([[:space:]])}
    condition=${condition%%+([[:space:]])}
    src_category=${src_category##+([[:space:]])}
    src_category=${src_category%%+([[:space:]])}
    name=${name##+([[:space:]])}
    name=${name%%+([[:space:]])}

    # Make $name UTF-8 ascii (func cleanup_utf8)
    name=$(cleanup_utf8 "$name")

    # Escape $name and check for alias wildcard '*'
    if [[ "$name" =~ ^.*(\*|\.\*)$ ]]; then
        name="$(printf '%q' "$(echo "$name" | sed 's/\(\.\)\?\*$//')").*"
    else
        name="$(printf "%q" "$name")/.*"
    fi

    # Escape $src_category to include '(stream)?'
    src_category="$(printf '%q' "$src_category")"

    # White list array
    if [[ "$condition" =~ ^[wW]$ ]]; then
        # Check if pattern exists
        found=false
        for pattern in "${white_control_regex_LIST[@]}"; do
            if [[ "$pattern" == "$src_category(/.*)?/$name" ]]; then
                found=true
                break
            fi
        done

        if [ "$found" = false ]; then
            white_control_regex_LIST+=( "$src_category(/.*)?/$name" )  # Add regex list array
        fi
    fi

    # Black list array
    if [[ "$condition" =~ ^[bB]$ ]]; then
        # Check if pattern exists
        found=false
        for pattern in "${black_control_regex_LIST[@]}"; do
            if [[ "$pattern" == "$src_category(/.*)?/$name" ]]; then
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            black_control_regex_LIST+=( "$src_category(/.*)?/$name" )  # Add regex list array
        fi
    fi
done < <( cat "$work_dir/tmp_control_list.txt" )

# Create simple b/w regex vars (non-sed, one liners)
# Create '$white_dir_filter_regex'
result=""
if [ ${#white_control_regex_LIST[@]} = 0 ]; then
    result+="dummy_entry|"  # Check array is empty, add a dummy entry line
else
    for element in "${white_control_regex_LIST[@]}"; do
        result+="${element}|"  # Concatenate the element with the pipe symbol
    done
fi
white_dir_filter_regex="${result%|}" # Create '$white_dir_filter_regex' (remove the trailing pipe symbol)

# Create '$black_dir_filter_regex'
result=""
if [ ${#black_control_regex_LIST[@]} = 0 ]; then
    result+="dummy_entry|"  # Check array is empty, add a dummy entry line
else
    for element in "${black_control_regex_LIST[@]}"; do
        result+="${element}|"  # Concatenate the element with the pipe symbol
    done
fi
black_dir_filter_regex="${result%|}"  # Create '$black_dir_filter_regex' (remove the trailing pipe symbol)


#---- Step 4 - Get Kodirsync remote server file list
# Gets a complete file list, regex filtered, from the remote server.

get_remote_file_LIST
if [ $? = 1 ]; then
    # Print display message
    echo -e "#---- WARNING - Terminal Error\nFunction : get_remote_file_LIST\nCheck log file to resolve the problem.\n"
    exit 1  # Exit on fail
fi


#---- Step 4 - Setup local base dir shares
# Create local base dir shares to match remote server shares
# Remove depreciated local base dir shares

# Make base dir list (i.e video/documentary, video/series, music, photo)
make_basedir_LIST

# Create simple base dir regex vars (non-sed, one liners)
result=""  # Initialize array
for element in "${remote_basedir_LIST[@]}"; do
    # If $element contains two dirs (i.e video/movies)
    if [[ "$element" =~ ^.*\/.*$ ]]; then
        element=$(echo "$element" | sed 's#/#(/#; s#$#)?#')
    fi
    result+="${element}|"  # Concatenate the element with the pipe symbol
done
share_dir_filter_regex="${result%|}"  # Create '$share_dir_filter_regex' (remove the trailing pipe symbol)

# Remove depreciated local base dirs
find "$dst_dir" -mindepth 1 -maxdepth 2 -type d -regextype posix-extended -not -iregex ".*/(rsync_tmp)(/.*)?$|.*/($exclude_os_dir_filter_regex)(/.*)?$|$dst_dir/($share_dir_filter_regex)$" 2> /dev/null -exec rm -rf "{}" \;

# Update local base dirs (match kodirsync remote user settings)
while read -r line; do
	mkdir -p "$dst_dir/$line"  # Create base dirs
done < <( printf '%s\n' "${remote_basedir_LIST[@]}" )


#---- Step 5 - Prepare remote file list

# Note: Speed processing this part of the script depends on hardware. Be patient.
echo "Creating remote download file list. This can be slow, be patient..."

# Create a list of all local files (regex filtered)
all_local_LIST=()  # Initialize array
while IFS= read -r line; do
    all_local_LIST+=("$line")
done < <( find "$dst_dir" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex)(/.*)?|.*/rsync_tmp(/.*)?|.*/kodirsync_app(/.*)?" -type f -regextype posix-extended -not -iregex ".*/($exclude_file_filter_regex)$" -type f -regextype posix-extended -iregex ".*\.($video_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$|.*\.($audio_format_filter_regex)$|.*\.($audiobook_format_filter_regex)$|.*\.($subtitle_format_filter_regex)$" -printf '%P;%s;%T@\n' 2> /dev/null | sort -t ';' -k3n )

# Filter remote file list
white_all_remote_LIST=()  # Initialize array
other_all_remote_LIST=()  # Initialize array
subtitle_all_remote_LIST=()  # Initialize array
for remote_item in "${all_remote_LIST[@]}"; do
    # Use IFS to set the delimiter to semicolon
    IFS=';' read -r remote_file remote_size remote_date <<< "$remote_item"

    # Check if remote_file $remote_size is greater than storage capacity
    remote_size="${remote_size%%[!0-9]*}"  # Removes non numeric characters
    [[ "$remote_size" -gt "$storage_cap" ]] && continue

    # # Check $remote_file is a acceptable remote_file format
    # [[ ! "$remote_file" =~ ^.*\.($video_format_filter_regex|$audio_format_filter_regex|$audiobook_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$ ]] && continue

    # Check $remote_file is HDR/HDR10 type ('1' for enabled/allowed, '0' for disabled)
    if [ "$hdr_enable" = 0 ]; then
        [[ "$remote_file" =~ ^.*(\[.*)?($exclude_hdr_filter_regex)(.*\])?.*$ ]] && continue
    fi

    # Check if $remote_file type exceeds maximum remote_file remote_size limits
    if [[ "$remote_file" =~ ^.*\.($video_format_filter_regex)$ ]] && [[ "$remote_size" -gt "$max_video_size_limit" ]]; then
        continue  
    elif [[ "$remote_file" =~ ^.*\.($audio_format_filter_regex|$audiobook_format_filter_regex|$subtitle_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$ ]] && [[ "$remote_size" -gt "$max_other_size_limit" ]]; then
        continue
    fi
    # Add to new list - subtitles
    if [[ "$remote_file" =~ ^.*\.($subtitle_format_filter_regex)$ ]]; then
        subtitle_all_remote_LIST+=( "$remote_item" )  # Add entry to list
        continue
    fi

    # Add to new all list - whitelist
    if [[ "$remote_file" =~ ^(.*/)?($white_dir_filter_regex)(/.*)?$ ]]; then
        white_all_remote_LIST+=( "$remote_item" )  # Add entry to list
        continue
    fi

    # Add to new all list - other
    other_all_remote_LIST+=( "$remote_item" )
done


# Create dl list
adjusted_storage_cap=$storage_cap  # Decrement as files are added to dl list (bytes)
total_dl_size=0  # Accrued total dl size (bytes)
dl_remote_LIST=()  # Initialize array
keep_local_LIST=()  # Initialize array
# Step 1 : "${white_all_remote_LIST[@]}"
for remote_item in "${white_all_remote_LIST[@]}"; do
    # Use IFS to set the delimiter to semicolon
    IFS=';' read -r remote_file remote_size remote_date <<< "$remote_item"

    # Proceed adding files only if storage space is available
    if [[ "$remote_size" -ge "$adjusted_storage_cap" ]]; then
        continue  # Storage space is full
    fi

    # Make UTF-8 ascii (func cleanup_utf8)
    remote_file=$(cleanup_utf8 "$remote_file")

    # Check for existing local file by iterating through the local array
    for local_item in "${all_local_LIST[@]}"; do
        # Use IFS to set the delimiter to semicolon
        IFS=';' read -r local_file local_size local_date <<< "$local_item"

        # Make UTF-8 ascii (func cleanup_utf8)
        local_file=$(cleanup_utf8 "$local_file")

        # Compare local and remote entries
        if [ "$local_file" = "$remote_file" ]; then
            keep_local_LIST+=( "$local_item" )  # Match found
            adjusted_storage_cap=$((adjusted_storage_cap - local_size))  # Deduct existing file size from available storage capacity (bytes)  
            total_dl_size=$((total_dl_size + local_size))  # Accrued total dl size (bytes)
            continue 2
        fi
    done

    # Add to dl list
    dl_remote_LIST+=( "$remote_item" )
    adjusted_storage_cap=$((adjusted_storage_cap - remote_size))  # Deduct new file size from available storage capacity (bytes)  

    # Add matching subtitle (video files only)
    if [[ "$remote_file" =~ .*\.($video_format_filter_regex)$ ]]; then
        # Check for subtitle file by iterating through the subtitle array
        for sub_item in "${subtitle_all_remote_LIST[@]}"; do
            # Use IFS to set the delimiter to semicolon
            IFS=';' read -r sub_file sub_size sub_date <<< "$sub_item"

            # Make UTF-8 ascii (func cleanup_utf8)
            sub_file=$(cleanup_utf8 "$sub_file")

            # Compare local and remote entries
            if [[ "$sub_file" =~ ^"${remote_file%.*}".*\.$subtitle_format_filter_regex$ ]]; then
                dl_remote_LIST+=( "$sub_item" )  # Match found - add to dl list
                adjusted_storage_cap=$((adjusted_storage_cap - sub_size))  # Deduct new file size from available storage capacity (bytes)
                total_dl_size=$((total_dl_size + sub_size))  # Accrued total dl size (bytes)
                # continue 2
            fi
        done
    fi
done

# Step 2 : "${other_all_remote_LIST[@]}"
for remote_item in "${other_all_remote_LIST[@]}"; do
    # Use IFS to set the delimiter to semicolon
    IFS=';' read -r remote_file remote_size remote_date <<< "$remote_item"

    # Proceed adding files only if storage space is available
    if [[ "$remote_size" -ge "$adjusted_storage_cap" ]]; then
        continue  # Storage space is full
    fi

    # Make UTF-8 ascii (func cleanup_utf8)
    remote_file=$(cleanup_utf8 "$remote_file")

    # Check for existing local file by iterating through the local array
    for local_item in "${all_local_LIST[@]}"; do
        # Use IFS to set the delimiter to semicolon
        IFS=';' read -r local_file local_size local_date <<< "$local_item"

        # Make UTF-8 ascii (func cleanup_utf8)
        local_file=$(cleanup_utf8 "$local_file")

        # Compare local and remote entries
        if [ "$local_file" = "$remote_file" ]; then
            keep_local_LIST+=( "$local_item" )  # Match found
            adjusted_storage_cap=$((adjusted_storage_cap - local_size))  # Deduct existing file size from available storage capacity (bytes)  
            total_dl_size=$((total_dl_size + local_size))  # Accrued total dl size (bytes)
            continue 2
        fi
    done

    # Add to dl list
    dl_remote_LIST+=( "$remote_item" )
    adjusted_storage_cap=$((adjusted_storage_cap - remote_size))  # Deduct new file size from available storage capacity (bytes)  

    # Add matching subtitle (video files only)
    if [[ "$remote_file" =~ .*\.($video_format_filter_regex)$ ]]; then
        # Check for subtitle file by iterating through the subtitle array
        for sub_item in "${subtitle_all_remote_LIST[@]}"; do
            # Use IFS to set the delimiter to semicolon
            IFS=';' read -r sub_file sub_size sub_date <<< "$sub_item"

            # Make UTF-8 ascii (func cleanup_utf8)
            sub_file=$(cleanup_utf8 "$sub_file")

            # Compare local and remote entries
            if [[ "$sub_file" =~ ^"${remote_file%.*}".*\.($subtitle_format_filter_regex)$ ]]; then
                dl_remote_LIST+=( "$sub_item" )  # Match found - add to dl list
                adjusted_storage_cap=$((adjusted_storage_cap - sub_size))  # Deduct new file size from available storage capacity (bytes)
                total_dl_size=$((total_dl_size + sub_size))  # Accrued total dl size (bytes)
                # continue 2
            fi
        done
    fi
done


#---- Prune, remove old and depreciated media files from destination

# Run 'kodirsync_clientapp_prune.sh'
source $app_dir/kodirsync_clientapp_prune.sh


#---- Perform rsync task

# Create log entry
echo -e "#---- STORAGE CAPACITY\nTime : $(date)\nTotal dl file cnt : ${#dl_remote_LIST[@]}\nTotal Kodirsync storage capacity : $(($storage_cap / (1024 * 1024 * 1024)))GB\nTotal download size : $(($total_dl_size / (1024 * 1024 * 1024)))GB\nRemaining Kodirsync storage space : $((adjusted_storage_cap / (1024 * 1024 * 1024)))GB\n" >> $logfile

# Display msg ( for terminal only)
echo "Total disk kodirsync storage capacity: $storage_cap bytes or $(($storage_cap / (1024 * 1024 * 1024)))GB"
echo "Total download size: $total_dl_size bytes or $((total_dl_size / (1024 * 1024 * 1024)))GB"
echo "Remaining Kodirsync storage space: $adjusted_storage_cap bytes or $((adjusted_storage_caps / (1024 * 1024 * 1024)))GB"

# Create rsync dl list
printf '%s\n' "${dl_remote_LIST[@]}" > $work_dir/rsync_process_list.txt

# Copy human friendly dl list to '$dst_dir/rsync_tmp' (for manual user viewer checking only)
awk -F';' '{ printf "%s;%.2f GB\n", $1, $2 / 1073741824 }' "$work_dir/rsync_process_list.txt" > "$dst_dir/rsync_tmp/rsync_process_list.txt"

# Run 'kodirsync_clientapp_connect.sh'
source $app_dir/kodirsync_clientapp_connect.sh


#---- Job Finish

# Create log entry - finish
echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
#-----------------------------------------------------------------------------------