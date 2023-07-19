#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_linux_storage.sh
# Description:  Kodirsync client storage install script (for Linux and CoreELEC/LibreELEC).
#               Select a disk and format to ext4 or select a existing storage dir.
#               Not for Termux.
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Disk label name
disk_label_name=kodirsync

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Function to check if a device is mounted and perform an unmount if needed
unmount_device() {
  local dev_path="$1"

  # Check if the device is mounted
  if mountpoint -q "$dev_path"
  then
    umount "$dev_path" >/dev/null 2>&1
    wait
  fi
}
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Initialize array of disks
devices=()

# Array of devices - non-formatted blank disks
while read -r block
do
  # Check block is a suitable physical actual disk
  [[ ! $block =~ ^(sd[a-z]|nvme[0-9]n[0-9])$ ]] && continue

  # Check if block device is a system disk
  if parted -s "/dev/$block" print 2>&1 | awk '/Number/ {flag=1; next} flag' | grep -qi -e "boot" -e "bios" -e "bios_grub" -e "esp" -e "system" -e "sys" -e "root" -e "swap" -e "home" -e "usr"; then
    continue
  fi

  # Check block device is in use
  if blkid -o device | grep -q "^/dev/$block.*$"; then
    continue
  fi

  # Add to devices list
  devices+=( "/dev/$block" )
done < <( ls /sys/block/ 2>/dev/null )

# Array of devices - existing disks
while read -r device
do
  # Check mountpoint against generic linux system mounts
  mountpoint=$(df -h "$device" 2> /dev/null | awk 'NR > 1 { print $6 }')
  [[ $(echo "$mountpoint" 2> /dev/null | grep -E '^/$|^/dev$|^/flash|^/storage$|^/dev/shm|^/var$|^/etc$|^/rpool|^/run|^/sys') ]] && continue

  # Get the parent disk device ID
  if [[ "$device" =~ ^/dev/sd[a-z][0-9]$ ]]
  then
    # Remove the partition number to get the whole disk path
    device="${device%[0-9]}"
  elif [[ "$device" =~ ^/dev/nvme[0-9]n[0-9]p[0-9]$ ]]
  then
    # Remove the partition p prefix (if present) to get the whole disk path
    device=${device%%p*}
  fi

  # Check if device is a system disk
  if parted -s "$device" print 2>&1 | awk '/Number/ {flag=1; next} flag' | grep -qi -e "boot" -e "bios" -e "bios_grub" -e "esp" -e "system" -e "sys" -e "root" -e "swap" -e "home" -e "usr"; then
    continue
  fi

  # Add to devices list
  devices+=( "$device" )
done < <( blkid -o device 2> /dev/null | grep -E '/dev/sd[a-z]$|/dev/nvme[0-9]n[0-9]$|/dev/sd[a-z][0-9]*$|/dev/nvme[0-9]n[0-9]p[0-9]*$' )


# Create a list of any available disk device (non-system)
# Create an empty array
declare -a disks=()
declare -a disk_menu=()

# Iterate over the devices
if [ ! "${#devices[@]}" = 0 ]
then
  for device in "${devices[@]}"
  do
    # Get the device type
    type=$(udevadm info --query=property --name="$device" | grep "DEVTYPE=" | cut -d "=" -f 2)

    # Check if the device is a disk and not in use by the system
    # if [ "$type" = "disk" ] && [ -z "$mountpoint" ]; then
    if [ "$type" = "disk" ]
    then
      # Get the UUID, model, capacity, and device path of the disk
      dev_path="$device"
      uuid=$(udevadm info --query=property --name="$device" 2> /dev/null \
      | grep "ID_FS_UUID=" \
      | cut -d "=" -f 2 \
      | awk -v def="not avail" '{print} END { if(NR==0) {print def} }')
      model=$(udevadm info --query=property --name="$device" 2> /dev/null \
      | grep "ID_MODEL=" \
      | cut -d "=" -f 2 \
      | awk -v def="not avail" '{print} END { if(NR==0) {print def} }')
      fstype=$(udevadm info --query=property --name="$device" 2> /dev/null \
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
      serial=$(udevadm info --query=property --name="$device" 2> /dev/null \
      | grep "ID_SERIAL=" \
      | cut -d "=" -f 2 \
      | awk -v def="not avail" '{print} END { if(NR==0) {print def} }')

      # Add the disk information to the array
      disks+=( "$dev_path;$uuid;$model;$fstype;$capacity;$type;$rota;$mountpoint;$serial" )
      disk_menu+=( "$dev_path  $model  \"$capacity\"" )
    fi
  done
fi


#---- Set available storage types and menu options

# Check for existing storage dirs
chk_existing=$(find / \( -path "*/$android_path/$kodirsync_storage_dir" -o -path "*/$kodirsync_storage_dir" \) -type d -exec sh -c 'if [ -e "$1/.kodirsync_storage" ]; then echo "$(dirname "$1")"; fi' sh {} \; 2> /dev/null | sed '/^$/d' | uniq)

# Create display msgs
display_msg1="${WHITE}Disk Based${NC} - Select a storage device (SATA, eSATA or USB disk), for use as a dedicated media storage device. A Linux ext4 or exFAT filesystem  is required. If reformatting is required all existing data on the device will be lost forever. You have '"${#disks[@]}"x' available disk(s)."
display_msg2="${WHITE}Folder Based${NC} - Select a storage folder location on your machine. You will be prompted to enter a full directory path expressed in the Linux path standard. For example, '/storage' or '/mnt/media'."
display_msg3="${WHITE}Existing Kodirsync storage${NC} - Select your existing storage folder."

if [ "${#disks[@]}" = 0 ]
then
  # Available options are folder based storage only
  # Print msg display
  msg "Your destination storage option is limited to a storage folder only. The installer could not detect any available disks.\n$(printf '%s\n' "1) $display_msg2" | indent)\n$(if [ -n "$chk_existing" ]; then printf '%s\n' "2) $display_msg3\n" | indent; fi)"

  # Menu options
  build_menu=( "Folder based - Select a storage folder location on your machine" )
  # Add existing to $build_menu
  if [ -n "$chk_existing" ]
  then
    build_menu+=( "Existing storage - Select your existing Kodirsync storage folder" )
  fi
  # Add 'Quit' to $build_menu
  build_menu+=( "Quit - I want to quit and exit this installer" )
else
  # Available options include disk and folder based storage
  # Print msg display
  msg "Your available destination storage options:\n
  $(printf '%s\n' "1) $display_msg1" | indent)\n
  $(printf '%s\n' "2) $display_msg2" | indent)\n
  $(if [ -n "$chk_existing" ]; then printf '%s\n' "3) $display_msg3\n" | indent; fi)"

  # Menu options
  build_menu=( 
    "Disk based - Select a device (SATA or USB disk)"
    "Folder based - Select a new destination storage location on your machine"
    )
  # Add existing to $build_menu
  if [ -n "$chk_existing" ]
  then
    build_menu+=( "Existing storage - Select your existing Kodirsync storage folder" )
  fi
  # Add 'Quit' to $build_menu
  build_menu+=( "Quit - I want to quit and exit this installer" )
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
      elif [[ "${choice,,}" =~ ^existing.* ]]
      then
        # Set storage type to dir
        storage_type=2
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
        uuid=$(echo "$stor_disk" | awk -F';' '{ print $2 }')
        model=$(echo "$stor_disk" | awk -F';' '{ print $3 }')
        fstype=$(echo "$stor_disk" | awk -F';' '{ print $4 }')
        capacity=$(echo "$stor_disk" | awk -F';' '{ print $5 }')
        dev_path=$(echo "$stor_disk" | awk -F';' '{ print $1 }')
        rota=$(echo "$stor_disk" | awk -F';' '{ print $7 }')
        mountpoint=$(echo "$stor_disk" | awk -F';' '{ print $8 }')
        echo
        break
      fi
    else
      msg="Invalid input. Please try again."
    fi
  done


  # Format selected disk if required
  if [[ ! "$fstype" =~ ^($disk_fs)$ ]]
  then
    # Set display msg
    display_msg1=$(echo "$stor_disk" | awk -F';' '{ print $1, $3, "\""$5"\"" }')
    msg "To ensure compatibility and optimal performance, it is necessary to format your selected disk with either the Linux ext4 or exFAT filesystem. For fixed Linux installations like CoreELEC or LibreELEC devices, it is recommended to use the ext4 file system due to its lower overhead and native compatibility with Linux. The ext4 filesystem does not have any limitations on disk size.\n\nOn the other hand, if maximum disk portability is your priority, selecting exFAT over ext4 is preferable. exFAT is supported natively by CoreELEC, LibreELEC, Windows, Mac, Android, and Linux (including Termux), making it ideal for seamless file sharing across multiple platforms. Since Android has a 2TB limitation on USB disks, we will create a 2TB partition to accommodate this restriction.\n\nAll existing disk partitions and data will be ${RED}permanently erased${NC}.\n\n
    $(printf '%s\n' "$display_msg1" | indent)\n"

    # Select disk FS
    while true
    do
      # Display installer menu options
      msg "Select a disk filesystem. Your menu options:\n"
      menu_display=(
        "1) FS ext4 -- Limited portability. For Linux/ELEC devices only (recommended)"
        "2) FS exFAT -- Portable with devices (Android/Termux, Linux, Windows users)"
      )
      printf '%s\n' "${menu_display[@]}" | indent

      # Prompt user to enter their choice
      read -p "Enter your choice: " choice

      # Determine action based on user's choice
      case $choice in
        1)
          # FS Ext4 - option 1
          info "You have chosen filesystem : ${YELLOW}ext4${NC}"
          format_fstype=ext4
          echo
          break
          ;;
        2)
          # FS exFAT - option 2
          info "You have chosen filesystem : ${YELLOW}exfat${NC}"
          format_fstype=exfat
          echo
          break
          ;;
        *)
          # Invalid choice
          warn "Invalid choice. Try again..."
          ;;
      esac
    done

    # Ask to perform disk format
    while true
    do
      read -p "Proceed to format the selected disk to $format_fstype [y/n]?: " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          msg "Wiping, erasing and formatting disk to $format_fstype filesystem..."
          # Stopping Samba
          systemctl stop nmbd smbd

          # Unmounting any existing mount points
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
          done < <( blkid -o device | grep -E "^${dev_path}(p)?([1-9])?" )

          # Erasing selected disk disk
          dd if=/dev/zero of="$dev_path" bs=512 count=1 conv=notrunc >/dev/null
          wait

          # Formatting disk
          if [ "$format_fstype" = ext4 ]
          then
            # FS formatting - ext4
            source $DIR/kodirsync_clientapp_install_format_disk_ext4.sh
          elif [ "$format_fstype" = exfat ]
          then
            # FS formatting - exFAT
            source $DIR/kodirsync_clientapp_install_format_disk_exfat.sh
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

  # Wait for disks to be ready
  udevadm settle

  # Mount the storage disk
  # Create mount point on local machine
  mkdir -p "$mnt_point"

  # Check OS type and mount
  if [ "$os_type" = 1 ]
  then
    if [ "$rota" = 1 ] && [ "$format_fstype" = ext4 ]
    then
      # Set mount args for ssd disk - ext4
      mount -t ext4 -o discard /dev/disk/by-uuid/$uuid "$mnt_point" 2> /dev/null # for trim
    elif [ "$rota" = 0 ] && [ "$format_fstype" = ext4 ]
    then
      # Set mount args for rotational disk - ext4
      mount -t ext4 /dev/disk/by-uuid/$uuid "$mnt_point" 2> /dev/null # no trim
    elif [[ "$rota" =~ ^(0|1)$ ]] && [ "$format_fstype" = exfat ]
    then
      # Set mount args for disk - exfat
      mount -t exfat /dev/disk/by-label/$disk_volume_label "$mnt_point" 2> /dev/null # no trim
    fi
  elif [ "$os_type" = 2 ]
  then
    echo -e "UUID="$uuid" "$mnt_point" ext4 defaults 0 0" >> /etc/fstab
    mount "$mnt_point"
  fi
  
  # Restart nmbd smbd
  systemctl restart nmbd smbd
  wait

  # Set destination and application vars
  if [ "$format_fstype" = ext4 ]
  then
    # Set '$dst_dir' - ext4
    dst_dir="$mnt_point/$kodirsync_storage_dir"
    if [ ! -d "$dst_dir" ]
    then
      # Make destination dir '$dst_dir'
      mkdir -p "$dst_dir"
    fi

    # Set '$app_dir' - ext4
    app_dir="$mnt_point/$kodirsync_app_dir"
    if [ ! -d "$app_dir" ]
    then
      # Make destination dir '$app_dir'
      mkdir -p "$app_dir"
    fi

    # Set '$smb_dir'
    smb_dir="$mnt_point"
  elif [ "$format_fstype" = exfat ]
  then
    # Set $dst_dir - exFAT
    # ExFAT dir path makes it portable for all clients (i.e ELEC/Android/Termux/Linux)
    dst_dir="$mnt_point/$android_path/$kodirsync_storage_dir"

    # Make destination dir '$dst_dir'
    mkdir -p "$dst_dir"

    # Set $app_dir - exFAT
    app_dir="$mnt_point/$android_path/$kodirsync_app_dir"

    # Make destination dir '$app_dir'
    mkdir -p "$app_dir"

    # Set '$smb_dir'
    smb_dir="$mnt_point/$android_path"
  fi

  # Chown dirs and contents
  chown "$user:$user_grp" "$dst_dir" 2>/dev/null
  find "$dst_dir" ! -name ".kodirsync_storage" -exec chown "$user:$user_grp" {} + 2>/dev/null
fi


#---- Folder type actions
# This is for existing mountpoint folders or folder based destination storage.

if [ "$storage_type" = 2 ]
then
  # Initialize & declare array
  existing_dst_dir_LIST=()
  while read line
  do
    # Create dst dir list
    existing_dst_dir_LIST+=( "$line" )
  done < <( find / \( -path "*/$android_path/$kodirsync_storage_dir" -o -path "*/$kodirsync_storage_dir" \) -type d -exec sh -c 'if [ -e "$1/.kodirsync_storage" ]; then echo "$1"; fi' sh {} \; 2> /dev/null | sed '/^$/d' | uniq )

  # Existing storage locations exist
  if [ ! "${#existing_dst_dir_LIST[@]}" = 0 ]
  then
    # Display the menu
    msg "We have found possible existing destination folder locations. Choose an existing destination storage folder or select 'None' to create a new storage location."
    echo

    # Iterate over the options array and display the menu items
    echo "0. None. I want to create a new storage location" | indent
    for ((i=0; i<${#existing_dst_dir_LIST[@]}; i++)); do
      echo "$((i+1)). ${existing_dst_dir_LIST[$i]}" | indent
    done

    # Function to validate the choice
    validate_choice() {
      local input=$1
      if [[ $input =~ ^[0-${#existing_dst_dir_LIST[@]}]$ ]]; then
        if [ $input -eq 0 ]; then
          selected_storage="None"
        else
          selected_storage="${existing_dst_dir_LIST[$((input-1))]}"
        fi
        info "Your Kodirsync destination folder is set: $selected_storage"
      else
        msg "Invalid choice. Please try again."
        return 1
      fi
    }

    # Read and validate the user's choice
    while true; do
      read -p "Enter your choice (0-${#existing_dst_dir_LIST[@]}): " choice
      if validate_choice "$choice"; then
        break
      fi
    done
    echo

    # Set '$dst_dir' & '$app_dir' & '$app_dir' path
    if [[ ! "$selected_storage" =~ ^None.*$ ]]
    then
      # Set '$dst_dir'
      dst_dir="$selected_storage"

      # Chown '$dst_dir' dir and contents
      chown "$user:$user_grp" "$dst_dir" 2>/dev/null
      find "$dst_dir" ! -name ".kodirsync_storage" -exec chown "$user:$user_grp" {} + 2>/dev/null

      # Set '$app_dir'
      app_dir=$(find / \( -path "*/$android_path/$kodirsync_app_dir" -o -path "*/$kodirsync_app_dir" \) -type d -print 2> /dev/null | sed '/^$/d' | uniq)
      if [ ! -n "$app_dir" ]
      then
         # Make destination dir '$app_dir'
        app_dir="$(dirname "$selected_storage" | sed "/\/$kodirsync_app_dir$/! s/$/\/$kodirsync_app_dir/")"
        mkdir -p "$app_dir"
      fi

      # Chown '$app_dir' dir and contents
      chown -R "$user:$user_grp" "$app_dir" 2>/dev/null

      # Set '$smb_dir'
      smb_dir="$(dirname "$selected_storage")"

      # Set arg
      existing_dir_check=1
    else
      existing_dir_check=0
    fi
  else
    existing_dir_check=0
  fi
fi

# Manual folder input entry
if [ "$existing_dir_check" = 0 ]
then
  # display msgs
  display_msg1=( "  --  /volume1/media" \
  "  --  /var/media" )
  error_msg1=( "Your input path is not valid:"
  " "
  "  --  the input path must exist"
  "  --  the input path can end with ../$kodirsync_storage_dir"
  "  --  the input path can end with ../kodirsync/$kodirsync_storage_dir"
  "  --  the input path cannot contain 'kodirsync' within the path ../kodirsync/sample"
  "  --  the input path must comply with Linux layout conventions (forward '/')"
  "  --  the input path must be an absolute path"
  "Try again..." )

  # Ask the user to input a valid dst dir
  msg "You must input a Kodirsync destination storage folder. Input the Linux absolute
  path (full path) of an existing folder at next prompt. Examples only:\n\n$(printf '%s\n' "${display_msg1[@]}")\n"
  while true
  do
    read -p "Enter the absolute folder path:" -r man_dst_dir
    # Check path conforms
    output=$(echo "$man_dst_dir" | grep -E '^[a-zA-Z0-9._/-\ ]+$' | grep -E "^.*/$kodirsync_storage_dir(/)?$")
    check=$?
    if [ -d "$man_dst_dir" ] && [ "$check" -eq 1 ]
    then
      warn "$(printf '%s\n' "${error_msg1[@]}")\n"
      sleep 1
    elif [ -d "$man_dst_dir" ] && [ "$check" -eq 0 ]
    then
      # Set '$dst_dir'
      dst_dir="$(echo "$man_dst_dir" | sed 's/\/$//' | sed "/\/$kodirsync_storage_dir$/! s/$/\/$kodirsync_storage_dir/")"

      # Make '$dst_dir'
      mkdir -p "$dst_dir" 2> /dev/null

      # Chown '$dst_dir' dir and contents
      chown -R "$user:$user_grp" "$dst_dir"

      # Set '$app_dir'
      app_dir="$(echo "$man_dst_dir" | sed 's/\/$//' | sed "/\/$kodirsync_app_dir$/! s/$/\/$kodirsync_app_dir/")"

      # Make '$app_dir'
      mkdir -p "$app_dir" 2> /dev/null

      # Chown '$app_dir' dir and contents
      chown -R "$user:$user_grp" "$app_dir"

      # Set '$smb_dir'
      smb_dir="$(echo "$man_dst_dir" | sed 's/\/$//')"

      info "Your Kodirsync destination folder is set : ${YELLOW}$dst_dir${NC}"
      echo
      break
    elif [ ! -d "$man_dst_dir" ]
    then
      warn "$(printf '%s\n' "${error_msg1[@]}")\n"
      sleep 1
    fi
  done
fi

# Create Kodirsync hidden ID file to identify a storage disk
# A hidden file named ".kodirsync_storage" is made in the storage dir. 
if [ ! -f "$dst_dir/.kodirsync_storage" ]
then
  # Create hidden file
  touch "$dst_dir/.kodirsync_storage"
  chattr +i "$dst_dir/.kodirsync_storage" 2> /dev/null
fi
#-----------------------------------------------------------------------------------