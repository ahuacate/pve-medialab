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

#---- UTF-8 Ascii cleanup

cleanup_utf8() {
    # Makes all input text UTF-8 ascii compliant

    # Set argument parameters
    local input="$1"
    # Set other variables
    local cleaned_input=$(echo "$input" | sed 's/ä/a/g; s/ö/o/g; s/ü/u/g; s/Ä/A/g; s/Ö/O/g; s/Ü/U/g; s/ß/ss/g')
    echo "$cleaned_input"
}


#---- Get & set remote node variables

function get_node_var() {
    # Gets and sets all the required node setting variable
    #
    # Parameters:
    #   $1: bash script name (required)
    #   $2: optional argument 1
    #   $3: optional argument 2
    #
    # Global Variables (Must be set before calling this function):
    #   - ssh_connect_retrycount
    #   - node_ssh_port
    #   - node_user
    #   - lan_address
    #   - $HOME/.ssh/kodirsync_node_rsa_key
    #   - Function bash scripts
    #
    # Usage:
    #   get_node_var "bash script name" [optional_arg1] [optional_arg2]

    # Set argument parameters
    local bash_script="$1"  # node bash script
    # Set other variables
    local max_retries="$ssh_connect_retrycount"  # Maximum number of retries (adjust as needed)
    local ssh_cmd="ssh -i $HOME/.ssh/kodirsync_node_rsa_key -p $node_ssh_port $node_user@$lan_address"  # SSH command

    # Get list from server
    local i
    local success=false  # Initialize success flag

    # Set $node_dst_dir
    for ((i = 0; i <= max_retries; i++)); do
        result=$($ssh_cmd "bash -s" < "$work_dir/$bash_script")
        if [ $? = 0 ]; then
            echo "$result"
            success=true
            break
        elif [ $? -ne 0 ]; then
            sleep $ssh_connect_retrysleep  # Apply wait period
            if [ $i -eq $max_retries ]; then
                success=false  # If we reached max_retries, set success to false
            fi
            continue  # Continue to the next iteration of the loop
        fi
    done

    # Process exit codes
    if [ "$success" = false ]; then
        echo -e "#---- WARNING - NODE UPDATE ERROR\nFunction : get_remote_node_vars\nRetry count : "$ssh_connect_retrycount"x failed attempts\n" >> $logfile  # Log entry
        return 1  # Set exit code
    fi
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Set local $local_src_dir (kodirsync_storage dir)
local_src_dir=$(find / \( -path "*/$android_path/$kodirsync_storage_dir" -o -path "*/$kodirsync_storage_dir" \) -type d -execdir sh -c '[ -e "$1/.kodirsync_storage" ]' sh {} \; -print 2> /dev/null)
count=$(echo "$local_src_dir" | wc -l)
if [ $count -eq 0 ]; then
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync kodirsync_storage dir not found.\nBye...\n\e[39m"
    exit 1
fi

# Set local $local_app_dir (kodirsync_app dir)
local_app_dir=$(find / -type d -name kodirsync_app -not -path "/storage/*" -not -path "/tmp/*" 2> /dev/null)
count=$(echo "$local_app_dir" | wc -l)
if [ $count -eq 0 ]; then
    echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync kodirsync_app dir not found.\nBye...\n\e[39m"
    exit 1
fi

# # Set SSH key name
node_ssh_private_key_name=$(basename "$node_ssh_private_key_path")  

# Copy private ssh key to .ssh dir if required
if [ -e "$HOME/.ssh/$node_ssh_private_key_name" ]; then
    if [[ "$ostype" =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]; then
        chmod 600 "$HOME/.ssh/$node_ssh_private_key_name"  # Set the appropriate key permissions
    else
        sudo chmod 600 "$HOME/.ssh/$node_ssh_private_key_name"  # Set the appropriate key permissions
    fi
else
    cp -f "$node_ssh_private_key_path" "$HOME/.ssh/$node_ssh_private_key_name"  # Copy ssh key from var path to users .ssh dir

    # Set the appropriate key permissions
    if [[ "$ostype" =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]; then
        chmod 600 "$HOME/.ssh/$node_ssh_private_key_name"  # Set the appropriate key permissions
    else
        sudo chmod 600 "$HOME/.ssh/$node_ssh_private_key_name"  # Set the appropriate key permissions
    fi
fi


#---- Create log entry - start

# Create log entry
echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile

#---- Check & Set LAN node connection 
# Check for LAN connectivity using IP address and host name.

while true; do
    # Check LAN connectivity 1 - hostname.localdomain
    node_localdomain_address_url1=$node_localdomain_address_url
    ssh -q -i "$HOME/.ssh/$node_ssh_private_key_name" \
    -o "BatchMode yes" \
    -o "StrictHostKeyChecking no" \
    -o "ConnectTimeout 5" \
    -p $node_ssh_port \
    $node_user@$node_localdomain_address_url echo OK
    # Check the return code
    if [ $? = 0 ]; then
        lan_address="$node_localdomain_address_url1"
        lan_server_status=1  # Set LAN active
        break  # Break out of the loop when LAN is active
    fi

    # Check LAN connectivity 2 - hostname only
    # Remove the domain name from $localdomain_address_url
    node_localdomain_address_url2="${node_localdomain_address_url%%.*}"
    ssh -q -i "$HOME/.ssh/$node_ssh_private_key_name" \
    -o "BatchMode yes" \
    -o "StrictHostKeyChecking no" \
    -o "ConnectTimeout 5" \
    -p $node_ssh_port \
    $node_user@$node_localdomain_address_url2 echo OK
    # Check the return code
    if [ $? = 0 ]; then
        lan_address="$node_localdomain_address_url2"
        lan_server_status=1  # Set LAN active
        break  # Break out of the loop when LAN is active
    fi

    # Check LAN connectivity - IP address
    if [[ "$node_local_ip_address" =~ ^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$ ]]; then
        ssh -q -i "$HOME/.ssh/$node_ssh_private_key_name" \
        -o "BatchMode yes" \
        -o "StrictHostKeyChecking no" \
        -o "ConnectTimeout 5" \
        -p $node_ssh_port \
        $node_user@$node_local_ip_address echo OK
        # Check the return code
        if [ $? = 0 ]; then
            lan_address="$node_local_ip_address"
            lan_server_status=1  # Set LAN active
            break  # Break out of the loop when LAN is active
        fi
    else
        lan_server_status=0
    fi

    # Create log entry
    echo -e "#---- WARNING - LAN NODE RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail.\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
done


#---- Get and set all the required node setting variables

# Get node $node_dst_dir
cat <<EOF > "$work_dir/node_dst_dir.sh"
#!/bin/bash
directory_found=0
while IFS= read -r path; do
    if [ -e "\$path/.kodirsync_storage" ]; then
        echo "\$path"
        directory_found=1
    fi
done < <(find / -type d -name "$kodirsync_storage_dir" -print 2> /dev/null)
if [ \$directory_found -eq 0 ]; then
    exit 1
fi
EOF
node_dst_dir=$(get_node_var "node_dst_dir.sh")  # Set var $node_dst_dir
if [ $? = 1 ]; then
    # Create log entry
    echo -e "#---- WARNING - FUNCTION FAIL\nFail date : $(date)\nFunction : get_node_var \"node_dst_dir.sh\"\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
fi

# Get node $node_app_dir
cat <<EOF > "$work_dir/node_app_dir.sh"
#!/bin/bash
directory_found=0
while IFS= read -r path; do
    if [ -e "\$path" ]; then
        echo "\$path"
        directory_found=1
    fi
done < <(find / -type d -name kodirsync_app -not -path "/storage/*" -not -path "/tmp/*" -print 2> /dev/null)
if [ \$directory_found -eq 0 ]; then
    exit 1
fi
EOF
node_app_dir=$(get_node_var "node_app_dir.sh")  # Set var $node_app_dir
if [ $? = 1 ]; then
    # Create log entry
    echo -e "#---- WARNING - FUNCTION FAIL\nFail date : $(date)\nFunction : get_node_var \"node_app_dir.sh\"\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
fi

# Get node $node_stor_fs
cat <<EOF > "$work_dir/node_stor_fs.sh"
#!/bin/bash
device=\$(df -Ph "$node_dst_dir" | awk 'NR==2 {print \$1}' | sed 's/ //g')
node_stor_fs=\$(blkid -o value -s TYPE "\$device")
echo "\$node_stor_fs"
EOF
node_stor_fs=$(get_node_var "node_stor_fs.sh") # Set var $node_stor_fs
if [ $? = 1 ]; then
    # Create log entry
    echo -e "#---- WARNING - FUNCTION FAIL\nFail date : $(date)\nFunction : get_node_var \"node_stor_fs.sh\"\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
fi

# Get node $node_dst_max_cap
cat <<EOF > "$work_dir/node_dst_max_cap.sh"
#!/bin/bash
if [ -e "$node_dst_dir" ]; then
    echo \$(df -Pk "$node_dst_dir" | awk -v storage_prov_factor="$storage_prov_factor" '(NR==2) {OFMT="%0.f"; sum = ((\$3 + \$4) * (storage_prov_factor/100)) * 1024; print sum }')
else
    exit 1
fi
EOF
node_dst_max_cap=$(get_node_var "node_dst_max_cap.sh")  # Set var $node_dst_max_cap
if [ $? = 1 ]; then
    # Create log entry
    echo -e "#---- WARNING - FUNCTION FAIL\nFail date : $(date)\nFunction : get_node_var \"node_dst_max_cap.sh\"\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
fi

# Set node $rsync_tmp path
node_rsync_tmp="$node_dst_dir/rsync_tmp"


#---- Set maximum node storage capacity limit

# Apply filesystem & storage capacity overrides
if [ "$node_stor_fs" = 'exfat' ]; then
    # Set destination storage limit (bytes) - exFAT ('0' for unlimited, other specified)
    if [ "$node_dst_max_storage_limit" = 0 ]; then
        node_dst_max_limit=$((android_storage_cap * 1024 * 1024 * 1024 * 1024))  # Limit - apply Android cap limit
    else
        # Limit - check preset $node_dst_max_storage_limit is not greater than exFAT limit ($android_storage_cap)
        if (( $((android_storage_cap * 1024 * 1024 * 1024 * 1024)) < $((node_dst_max_storage_limit * 1024 * 1024 * 1024)) )); then
            node_dst_max_limit=$((android_storage_cap * 1024 * 1024 * 1024 * 1024))
        else
            node_dst_max_limit=$((node_dst_max_storage_limit * 1024 * 1024 * 1024))
        fi
    fi
else
    # Set destination storage limit (bytes) - ext4 ('0' for unlimited, other specified)
    if [ "$node_dst_max_storage_limit" = 0 ]; then
        node_dst_max_limit=0
    else
        node_dst_max_limit=$((node_dst_max_storage_limit * 1024 * 1024 * 1024))
    fi
fi

# Set $storage_cap (bytes)
if [ "$node_dst_max_limit" = 0 ]; then
    storage_cap=$node_dst_max_cap  # Set storage capacity to disk maximum (bytes)
elif [ ! "$node_dst_max_limit" = 0 ]; then
    # Check $node_dst_max_cap does not exceed limits (bytes)
    if ((node_dst_max_limit > node_dst_max_cap)); then
        storage_cap=$node_dst_max_cap  # Set storage capacity to disk maximum (bytes)
    else
        storage_cap=$node_dst_max_limit  # Set storage capacity to max limit (bytes)
    fi
fi


#---- Create regex lists

# Create lists, args and arrays
source $app_dir/kodirsync_clientapp_list1.sh


#---- Create download list of '$kodirsync_storage' files - local media files
# Note: Speed processing this part of the script depends on hardware. Be patient.
echo "Creating new download list. This can be slow, be patient..."


# Create a list of all local files (regex filtered)
all_local_LIST=()  # Initialize array
while IFS= read -r line; do
    all_local_LIST+=("$line")
done < <( find "$local_src_dir" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex)(/.*)?|.*/rsync_tmp(/.*)?|.*/kodirsync_app(/.*)?" -type f -regextype posix-extended -not -iregex ".*/($exclude_file_filter_regex)$" -type f -regextype posix-extended -iregex ".*\.($video_format_filter_regex)$|.*/photos/(.*/)?.*\.($image_format_filter_regex)$|.*\.($audio_format_filter_regex)$|.*\.($audiobook_format_filter_regex)$|.*\.($subtitle_format_filter_regex)$" -printf '%P;%s;%T@\n' 2> /dev/null | sort -t ';' -k3n )


# Filter local file list
other_all_local_LIST=()  # Initialize array
subtitle_all_local_LIST=()  # Initialize array
for local_item in "${all_local_LIST[@]}"; do
    # Use IFS to set the delimiter to semicolon
    IFS=';' read -r local_file local_size local_date <<< "$local_item"

    # Check if local_file $local_size is greater than storage capacity
    local_size="${local_size%%[!0-9]*}"  # Removes non numeric characters
    [[ "$local_size" -gt "$storage_cap" ]] && continue

    # Check $local_file is HDR/HDR10 type ('1' for enabled/allowed, '0' for disabled)
    if [ "$node_hdr_enable" = 0 ]; then
        [[ "$local_file" =~ ^.*(\[.*)?($exclude_hdr_filter_regex)(.*\])?.*$ ]] && continue
    fi

    # Add to new list - subtitles
    if [[ "$local_file" =~ ^.*\.($subtitle_format_filter_regex)$ ]]; then
        subtitle_all_local_LIST+=( "$local_item" )  # Add entry to list
        continue
    fi

    # Add to new all list - other
    other_all_local_LIST+=( "$local_item" )
done

# Create node media ul list
adjusted_storage_cap=$storage_cap  # Decrement as files are added to dl list (bytes)
total_ul_size=0  # Accrued total dl size (bytes)
ul_node_storage_LIST=()  # Initialize array
# Add media files and matching subtitles
for local_item in "${other_all_local_LIST[@]}"; do
    # Use IFS to set the delimiter to semicolon
    IFS=';' read -r local_file local_size local_date <<< "$local_item"

    # Proceed adding files only if storage space is available
    if [[ "$local_size" -ge "$adjusted_storage_cap" ]]; then
        continue  # Storage space is full
    fi

    # Make UTF-8 ascii (func cleanup_utf8)
    local_file=$(cleanup_utf8 "$local_file")

    # Add to ul list
    ul_node_storage_LIST+=( "$local_item" )
    adjusted_storage_cap=$((adjusted_storage_cap - local_size))  # Deduct new file size from available storage capacity (bytes)
    total_ul_size=$((total_ul_size + local_size))  # Accrued total dl size (bytes) 

    # Add matching subtitle (video files only)
    if [[ "$local_file" =~ .*\.($video_format_filter_regex)$ ]]; then
        # Check for subtitle file by iterating through the subtitle array
        for sub_item in "${subtitle_all_local_LIST[@]}"; do
            # Use IFS to set the delimiter to semicolon
            IFS=';' read -r sub_file sub_size sub_date <<< "$sub_item"

            # Make UTF-8 ascii (func cleanup_utf8)
            sub_file=$(cleanup_utf8 "$sub_file")

            # Compare local and remote entries
            if [[ "$sub_file" =~ ^"${local_file%.*}".*\.$subtitle_format_filter_regex$ ]]; then
                ul_node_storage_LIST+=( "$sub_item" )  # Match found - add to dl list
                adjusted_storage_cap=$((adjusted_storage_cap - sub_size))  # Deduct new file size from available storage capacity (bytes)
                total_ul_size=$((total_ul_size + sub_size))  # Accrued total dl size (bytes)
            fi
        done
    fi
done


#---- Create download list of local '$kodirsync_app' files - application script files

# Read the file line by line and append each line to the array
ul_node_app_LIST=()  # Initialize array
while IFS= read -r line; do
    ul_node_app_LIST+=( "$line" )
done < <(find "$local_app_dir" -regextype posix-extended -not -iregex ".*/($exclude_file_filter_regex)$|.*/\..*$" -regextype posix-extended -not -iregex "(.*/)?($exclude_os_dir_filter_regex)(/.*)?|(.*/)?($exclude_dir_filter_regex)(/.*)?|(.*/logs(/.*)?" -type f -printf '%P\n' 2> /dev/null)


#---- Log entries

# Create log entry
echo -e "#---- NODE CAPACITY\nTime : $(date)\nTotal Kodirsync node capacity : $(($storage_cap / (1024 * 1024 * 1024)))GB\nTotal upload size : $(($total_ul_size / (1024 * 1024 * 1024)))GB\nRemaining Kodirsync node space : $((adjusted_storage_cap / (1024 * 1024 * 1024)))GB\n" >> $logfile

# Display msg ( for terminal only)
echo "Total node storage capacity: $node_dst_max_limit bytes or $(($node_dst_max_limit / (1024 * 1024 * 1024)))GB"
echo "Total node storage transfer size: $total_ul_size bytes or $(($total_ul_size / (1024 * 1024 * 1024)))GB"
#-----------------------------------------------------------------------------------