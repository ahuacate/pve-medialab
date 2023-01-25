#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_common_install.sh
# Description:  Kodirsync client common install script (for Linux and CoreELEC/LibreELEC)
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create a list of any available disk device (non-system)
# Create an empty array
declare -a disks=()
declare -a disk_menu=()
# Iterate over the block devices
if blkid -o device 2> /dev/null
then
  for device in $(blkid -o device 2> /dev/null | egrep '/dev/sd[a-z]|/dev/nvme[0-9]n[0-9]')
  do
    # Get the device type and mountpoint
    type=$(udevadm info --query=property --name="$device" | grep "DEVTYPE=" | cut -d "=" -f 2)
    mountpoint=$(df -h "$device" 2> /dev/null | awk 'NR > 1 { print $6 }')

    # Check mountpoint against generic linux system mounts
    [[ $(echo "$mountpoint" 2> /dev/null | egrep '^/$|^/dev$|^/flash|^/storage$|^/dev/shm|^/var$|^/etc$|^/rpool|^/run|^/sys') ]] && continue

    # Check if the device is a disk and not in use by the system
    # if [ "$type" = "disk" ] && [ -z "$mountpoint" ]; then
    if [ "$type" = "disk" ]
    then
      # Get the UUID, model, capacity, and device path of the disk
      dev_path="$device"
      uuid=$(udevadm info --query=property --name="$device" \
      | grep "ID_FS_UUID=" \
      | cut -d "=" -f 2 \
      | awk -v def="not avail" '{print} END { if(NR==0) {print def} }')
      model=$(udevadm info --query=property --name="$device" \
      | grep "ID_MODEL=" | cut -d "=" -f 2 \
      | awk -v def="not avail" '{print} END { if(NR==0) {print def} }')
      fstype=$(udevadm info --query=property --name="$device" \
      | grep "ID_FS_TYPE=" \
      | cut -d "=" -f 2 \
      | awk -v def="not avail" '{print} END { if(NR==0) {print def} }')
      capacity=$(hdparm -I "${device}" 2> /dev/null \
      | awk -F":" '/device size with M \= 1024\*1024:/ { print $2 }' \
      | sed 's/^[[:space:]]*//' \
      | awk -v def="not avail" '{print} END { if(NR==0) {print def} }')
      rota=$(udevadm info --attribute-walk --name="$device" 2> /dev/null \
      | grep -F 'ATTR{queue/rotational}' \
      | cut -d\" -f2 \
      | awk -v def="not avail" '{print} END { if(NR==0) {print def} }') # '1' is for ssd, '0' for rotational disk

      # Add the disk information to the array
      disks+=( "$dev_path|$uuid|$model|$fstype|$capacity|$type|$rota|$mountpoint" )
      disk_menu+=( "$dev_path  $model  \"$capacity\"" )
    fi
  done
fi

#---- Set available storage types and menu options

# Create display msgs
display_msg1="${WHITE}Disk Based${NC} - Select a storage device (SATA, eSATA or USB disk),
for use as a dedicated media storage device. A Linux ext4 filesystem  is required.
If reformatting is required all existing data on the device will be lost forever.
You have '"${#disks[@]}"x' available disk(s)."
display_msg2="${WHITE}Folder Based${NC} - Select a storage folder location on your machine.
You will be prompted to enter a full directory path expressed
in the Linux path standard. For example, '/storage' or '/mnt/media'."
if [ "${#disks[@]}" = 0 ]
then
  # Available options are folder based storage only
  # Print msg display
  msg "Your destination storage option is limited to a storage folder only. The installer could not detect any available disks.\n$(printf '%s\n' "1) $display_msg2" | indent)\n"
  # Menu options
  build_menu=( 
    "Folder based - Select a storage folder location on your machine"
    "Quit- I want to quit and exit this installer"
    )
else
  # Available options include disk and folder based storage
  # Print msg display
  msg "Your available destination storage options:\n
  $(printf '%s\n' "1) $display_msg1" | indent)\n
  $(printf '%s\n' "2) $display_msg2" | indent)\n"
  # Menu options
  build_menu=( 
    "Disk based - Select a device (SATA, eSATA or USB disk)"
    "Folder based - Select a storage folder location on your machine"
    "Quit- I want to quit and exit this installer"
    )
fi

# Display the storage option menu
while true
do
  msg "Select your destination storage location and type..."
  echo
  for i in "${!build_menu[@]}"
  do
    printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${build_menu[i]}"
  done
  if [[ "$msg" ]]; then echo "$msg"; fi
  msg=""; printf "Enter your selection (1 to ${#build_menu[@]}): "
  read -r user_input

  # Process the user's input
  if [[ "$user_input" =~ ^[1-9]$ ]] && (( user_input <= ${#build_menu[@]} ))
  then
    ((user_input--))
    # Execute the corresponding action
    if [[ "${choices[user_input]}" ]]; then
      msg="Invalid option. Please try again."
    else
      choice=${build_menu[user_input]}
      # Do something with the chosen option
      info "Your selection:\n  $choice"

      # Set action on menu choice
      if [[ "${choice,,}" =~ ^disk.* ]]
      then
        # Set storage type to disk
        storage_type=1
      elif [[ "${choice,,}" =~ ^folder.* ]]
      then
        # Set storage type to dir
        storage_type=2
        echo hello
      elif [[ "${choice,,}" =~ ^quit.* ]]
      then
        # Action for quitting
        warn "You have chosen to skip this installer and quit. Bye..."
        sleep 1
        exit 0
      fi
      echo
      break
    fi
  else
    msg="Invalid input. Please try again."
  fi
done


#---- Disk type actions
if [ "$storage_type" = 1 ]
then
  # Display the disk_menu if selected
  while true
  do
    for i in "${!disk_menu[@]}"
    do
      printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${disk_menu[i]}"
    done
    if [[ "$msg" ]]; then echo "$msg"; fi
    msg=""; printf "Enter your selection (1 to ${#disk_menu[@]}): "
    read -r user_input

    # Process the user's input
    if [[ "$user_input" =~ ^[1-9]$ ]] && (( user_input <= ${#disk_menu[@]} ))
    then
      ((user_input--))
      # Execute the corresponding action
      if [[ "${choices[user_input]}" ]]
      then
        msg="Invalid option. Please try again."
      else
        choice=${disk_menu[user_input]}
        # Do something with the chosen option
        info "Your selection:\n  $choice"
        # Set the storage disk
        stor_disk=${disks[user_input]}
        # Set disk variables
        uuid=$(echo "$stor_disk" | awk -F'|' '{ print $2 }')
        model=$(echo "$stor_disk" | awk -F'|' '{ print $3 }')
        fstype=$(echo "$stor_disk" | awk -F'|' '{ print $4 }')
        capacity=$(echo "$stor_disk" | awk -F'|' '{ print $5 }')
        dev_path=$(echo "$stor_disk" | awk -F'|' '{ print $1 }')
        rota=$(echo "$stor_disk" | awk -F'|' '{ print $7 }')
        mountpoint=$(echo "$stor_disk" | awk -F'|' '{ print $8 }')
        echo
        break
      fi
    else
      msg="Invalid input. Please try again."
    fi
  done

  # Format selected disk if required
  if [ ! "$fstype" = "$disk_fs" ]
  then
    # Set display msg
    display_msg1=$(echo "$stor_disk" | awk -F'|' '{ print $1, $3, "\""$5"\"" }')
    msg "Your selected disk requires formatting to the Linux ext4 filesystem.\nAll existing partitions and data will be ${RED}permanently erased${NC}.\n
    $(printf '%s\n' "$display_msg1" | indent)\n"
    # Ask to perform disk format
    while true
    do
      read -p "Proceed to format the selected disk to ext4 [y/n]?: " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          msg "Wiping, erasing and formatting disk to $disk_fs filesystem..."
          # Stopping Samba
          systemctl stop nmbd smbd
          # Unmounting any existing mount pounts
          while read line
          do
            # Check OS type and run task
            if [ "$os_type" = 1 ]
            then
              # Check if the specified mount point exists and remove
              if mount | grep -q "$line"
              then
                # Umount the mount point
                umount -l "$line"
              fi
            elif [ "$os_type" = 2 ]
            then
              # Check if the specified mount point exists and remove
              if mount | grep -q "$line"
              then
                # Umount the mount point
                umount -l "$line"
              fi
              # Check if the mount point exists in the fstab file
              if grep -q "$line" /etc/fstab
              then
                # Delete the mount point from the fstab file
                line_regex=$(echo "$line" | sed "s/${escape_string_regex}/g")
                sed -i "/${line_regex}/d" /etc/fstab
              fi
            fi
          done < <( blkid -o device | egrep "^${dev_path}(p)?([1-9])?" )

          # Erasing selected disk disk
          dd if=/dev/zero of="$dev_path" bs=512 count=1 conv=notrunc >/dev/null
          # Formatting disk
          mkfs.ext4 -F -q -L $(basename "$mnt_point") "$dev_path"
          # Disk Over-Provisioning
          if [ "$rota" = 1 ]
          then
            tune2fs -m "$over_prov_ssd" "$dev_path"
          else
            tune2fs -m "$over_prov_rot" "$dev_path"
          fi
          # Update uuid (Set again if changed during formatting)
          uuid=$(blkid -s UUID -o value "$dev_path" 2> /dev/null)
          break
          ;;
        [Nn]*)
          msg "You have chosen not to format your selected disk. To choose another option run\nthis script again and start again. Exiting in 2 seconds..."
          sleep 2
          exit 0
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  fi

  # Create mount point on local machine
  mkdir -p "$mnt_point"

  # Set dst_dir
  dst_dir="$mnt_point"

  # Mount the storage disk
  # Check OS type and run task
  if [ "$os_type" = 1 ]
  then
    if [ "$rota" = 1 ]
    then
      # Set mount args for ssd disk
      mount -t ext4 -o discard /dev/disk/by-uuid/$uuid "$mnt_point" 2> /dev/null # for trim
    else
      # Set mount args for rotational disk
      mount -t ext4 /dev/disk/by-uuid/$uuid "$mnt_point" 2> /dev/null # no trim
    fi
  elif [ "$os_type" = 2 ]
  then
    echo -e "UUID="$uuid" "$mnt_point "ext4 defaults 0 0" >> /etc/fstab
    mount "$mnt_point"
  fi
  
  # Restart nmbd smbd
  systemctl restart nmbd smbd
fi


#---- Folder type actions
if [ "$storage_type" = 2 ]
then
  # Check for existing kodirsync storage folder
  output=$(find / 2> /dev/null -regex '^.*\/kodirsync[/]?\(video\|music\|photo\|audio\|homevideo\)' ! -regex "^"$app_dir"" -print -quit)
  if [ "$(echo $output | sed '/^$/d' | wc -l)" -eq 1 ]
  then
    # Set basename path to destination folder
    existing_dst_dir=$(echo "$output" | sed -n 's/^\(.*\)kodirsync.*$/\1kodirsync/p')
    # Ask the user to accept or not
    while true; do
      msg "An existing destination storage folder has been located:\n$(echo "$existing_dst_dir" | indent)\n"
      read -p "Do you want to synchronise to '"$existing_dst_dir"' [y/n]? " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          # Set 'dst_dir' path
          dst_dir="$existing_dst_dir"
          existing_dir_check=1
          info "Your Kodirsync destination folder is set : ${YELLOW}"$dst_dir"${NC}"
          echo
          break
          ;;
        [Nn]*)
          existing_dir_check=0
          echo
          break
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  fi

  # Manual folder entry
  if [ "$existing_dir_check" = 0 ]
  then
    # display msgs
    display_msg1=( "  --  /volume1/media" \
    "  --  /var/media" )
    error_msg1=( "Your input path is not valid:"
    " "
    "  --  the input path must exist"
    "  --  the input path can end with ../kodirsync"
    "  --  the input path cannot contain 'kodirsync' within the path ../kodirsync/sample"
    "  --  the input path must comply with Linux layout conventions (forward '/')"
    "  --  the input path must be an absolute path"
    "Try again..." )
    # Ask the user to input a valid dst dir
    msg "You must input a Kodirsync destination storage folder. Input the Linux absolute
    path (full path) of an existing folder at next prompt. Examples only:\n\n$(printf '%s\n' "${display_msg1[@]}")\n"
    while true
    do
      read -p "Enter the folder path:" -r man_dst_dir
      # Check path conforms
      output=$(echo "$man_dst_dir" \
      | egrep '^[a-zA-Z0-9._/-\ ]+$' \
      | egrep '^.*\/kodirsync(\/)?$')
      check=$?
      if [ -d "$man_dst_dir" ] && [ "$check" -eq 1 ]
      then
        warn "$(printf '%s\n' "${error_msg1[@]}")\n"
        sleep 1
      elif [ -d "$man_dst_dir" ] && [ "$check" -eq 0 ]
      then
        dst_dir="$(echo "$man_dst_dir" | sed 's/\/$//')"
        info "Your Kodirsync destination folder is set : ${YELLOW}"$dst_dir"${NC}"
        echo
        break
      elif [ ! -d "$man_dst_dir" ]
      then
        warn "$(printf '%s\n' "${error_msg1[@]}")\n"
        sleep 1
      fi
    done
  fi
fi


#---- Set other Kodirsync options
# Set HDR arg
msg "${WHITE}#### PLEASE READ CAREFULLY - DISABLE HDR CONTENT ####${NC}
You have the option to disable HDR video content if:

  --  your media player cannot play 4K HDR formatted video media
  --  your TV cannot display 4K HDR formatted video media
  --  your media player does not support HDR to SDR tone-mapping playback

Disabling 4K HDR stops your Kodirsync client downloading any 4K HDR video content
which may mean you will not receive all video media content.\n"

while true; do
  read -p "Do you want to enable HDR downloading [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      # Set to HDR enabled ('1' for enabled, '0' for disabled)
      info "HDR status is set: ${YELLOW}enabled${NC}"
      hdr_enable=1
      echo
      break
      ;;
    [Nn]*)
      # Set to HDR disabled ('1' for enabled, '0' for disabled)
      info "HDR status is set: ${YELLOW}disabled${NC}"
      hdr_enable=0
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

# Set video size limit
while true
do
  # Display installer menu options
  msg "Select a maximum video file size. Your menu options:\n"
  menu_display=(
    "1) Unlimited -- no limit (Recommended)"
    "2) 40GB -- Extreme"
    "3) 30GB -- Superior"
    "4) 20GB -- Excellent (Recommended)"
    "5) 15GB -- Good"
    "6) 10GB -- Moderate"
    "7) 8GB -- Reasonable"
    "8) 5GB -- On the limit"
    "9) 3GB -- Low end"
  )
  printf '%s\n' "${menu_display[@]}" | indent

  # Prompt user to enter their choice
  read -p "Enter your choice: " choice

  # Determine action based on user's choice
  case $choice in
    1)
      # Set value
      max_video_size=0
      info "You have chosen a video limit: ${YELLOW}unlimited${NC} (GB)"
      echo
      break
      ;;
    2)
      # Set value
      max_video_size=40
      info "You have chosen a video limit: ${YELLOW}"$max_video_size"${NC} (GB)"
      echo
      break
      ;;
    3)
      # Set value
      max_video_size=30
      info "You have chosen a video limit: ${YELLOW}"$max_video_size"${NC} (GB)"
      echo
      break
      ;;
    4)
      # Set value
      max_video_size=20
      info "You have chosen a video limit: ${YELLOW}"$max_video_size"${NC} (GB)"
      echo
      break
      ;;
    5)
      # Set value
      max_video_size=15
      info "You have chosen a video limit: ${YELLOW}"$max_video_size"${NC} (GB)"
      echo
      break
      ;;
    6)
      # Set value
      max_video_size=10
      info "You have chosen a video limit: ${YELLOW}"$max_video_size"${NC} (GB)"
      echo
      break
      ;;
    7)
      # Set value
      max_video_size=8
      info "You have chosen a video limit: ${YELLOW}"$max_video_size"${NC} (GB)"
      echo
      break
      ;;
    8)
      # Set value
      max_video_size=5
      info "You have chosen a video limit: ${YELLOW}"$max_video_size"${NC} (GB)"
      echo
      break
      ;;
    9)
      # Set value
      max_video_size=3
      info "You have chosen a video limit: ${YELLOW}"$max_video_size"${NC} (GB)"
      echo
      break
      ;;
    *)
      # Invalid choice
      warn "Invalid choice. Try again..."
      ;;
  esac
done


#---- Move Kodirsync app files to 'app_dir'

# Create 'app_dir' installation dir
mkdir -p "$app_dir"
chmod 775 "$app_dir"
chown -R "$user":"$user_grp" "$app_dir"

# Create exclude array of certain filenames
exclude_files=(
  "-iname install.sh"
  "-o -iname kodirsync_clientapp_common_install.sh"
  "-o -iname kodirsync_clientapp_elec_install.sh"
  "-o -iname kodirsync_clientapp_elec_uninstall.sh"
  "-o -iname kodirsync_clientapp_linux_install.sh"
  "-o -iname kodirsync_clientapp_linux_uninstall.sh"
)

# Find and move files
find $selftar_dir -type f \( -iname "*.sh" -o -iname "*.cfg" \) -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec chmod +x {} \; -exec mv {} "$app_dir" \;
find $selftar_dir -type f -iname "*.txt" -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec mv {} "$app_dir" \;
find $selftar_dir -type f -iname "*.crt" -o -name "*.key" -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec chmod 600 {} \; -exec mv {} "$ssh_dir" \;
find $selftar_dir -type f -iname "*_kodirsync_id_ed25519" -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec chmod 600 {} \; -exec mv {} "$ssh_dir" \;

# # Find user ssh key & add to known hosts
# file=$(find $ssh_dir -type f -name "*_kodirsync_id_ed25519")
# if [ -n "$file" ]
# then
#   # Check if file content is in known_hosts
#   if ! grep -q -F "$(cat "$file")" "$ssh_dir/known_hosts"
#   then
#     # Add file content to known_hosts
#     echo hello
#     # cat "$file" >> "$ssh_dir/known_hosts"
#   fi
# fi


#---- Iterate over the array and update the values in the user configuration file

# Args for writing to Kodirsync user config files
user_config_arg_LIST=(
  "storage_type"
  "dst_dir"
  "max_video_size"
  "hdr_enable"
)
for name in "${user_config_arg_LIST[@]}"
do
  # Use the eval command to retrieve the value of the variable with the same name as the current option
  value=$(eval "echo \$$name")
  sed -i "s#^${name}\=.*#${name}\=${value}#g" $app_dir/kodirsync_clientapp_user.cfg
done

# # Run Kodirsync Git updater
# source <( cat $app_dir/kodirsync_clientapp_gitupdater.sh )
#-----------------------------------------------------------------------------------------------------------------------