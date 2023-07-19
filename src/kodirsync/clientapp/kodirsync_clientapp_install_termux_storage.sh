#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_termux_storage.sh
# Description:  Kodirsync client storage install script (for Termux).
#               Select a disk and format to ext4 or select a existing storage dir.
#               Not for Linux or LibreELEC/CoreELEC.
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------
#---- Prerequisites
#---- Check for existing '$dst_dir' and '$app_dst' folder

# Check for existing $dst_dir
dst_dir_chk=$(find /storage \( -path "*/????-????/$android_path/$kodirsync_storage_dir" -o -path "*/????-????/*/$kodirsync_storage_dir" \) -type d -exec sh -c 'if [ -e "$1/.kodirsync_storage" ]; then echo "$1"; fi' sh {} \; 2> /dev/null | sed '/^$/d' | uniq -u)

# Set $dst_dir
if [ -n "$dst_dir_chk" ]
then
  dst_dir="$dst_dir_chk"
fi

# Check for existing $app_dir
app_dir_chk=$(find /storage \( -path "*/????-????/$android_path/$kodirsync_app_dir" -o -path "*/????-????/*/$kodirsync_app_dir" \) -type d 2> /dev/null | sed '/^$/d' | uniq -u)

# Set $app_dir
if [ -n "$app_dir_chk" ]
then
  dst_dir="$app_dir_chk"
fi

# Return if '$dst_dir' and '$app_dst' exit
if [ -n "$app_dir_chk" ] && [ -n "$dst_dir_chk" ]
then
  return
fi


#---- Create '$dst_dir' and '$app_dir'

# Initialize & declare array
existing_dst_dir_LIST=()
while read line
do
  # Get dir size
  size=$(df -Ph "$line" | awk 'NR==2 {print $2}' | sed 's/ //g')
  # Add $line to array
  existing_dst_dir_LIST+=( "$line;$size" )
done < <( find /tmp \( -path "*/????-????/$android_path" \) -type d 2> /dev/null | sed '/^$/d' | uniq -u )

# Existing storage locations exist
if [ "${#existing_dst_dir_LIST[@]}" -gt 1 ]
then
  # Display the menu
  msg "We have found possible existing destination folder locations. Choose an existing destination storage folder or select 'None' to exit."
  echo

  # Iterate over the options array and display the menu items
  echo "0. None. I want to exit the installer." | indent
  for ((i=0; i<${#existing_dst_dir_LIST[@]}; i++)); do
    echo "$((i+1)). $(echo "${existing_dst_dir_LIST[$i]}" | awk -F';' '{print $1 "  (" $2")"}')" | indent
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
      info "Your Kodirsync storage path is set:\n$(echo $selected_storage | cut -d';' -f1)"
      selected_storage="$(echo "$selected_storage" | cut -d';' -f1)"
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
    dst_dir="$selected_storage/$kodirsync_storage_dir"
    if [ ! -n "$dst_dir" ]
    then
      # Make '$dst_dir'
      mkdir -p "$dst_dir"
    fi

    # Chown '$dst_dir' dir and contents
    chown -R "$user:$user_grp" "$dst_dir" 2>/dev/null
    find "$dst_dir" ! -name ".kodirsync_storage" -exec chown -R "$user:$user_grp" {} + 2>/dev/null

    # Set '$app_dir'
    app_dir="$selected_storage/$kodirsync_app_dir"
    if [ ! -n "$app_dir" ]
    then
      # Make '$app_dir'
      mkdir -p "$app_dir"
    fi

    # Chown '$app_dir' dir and contents
    chown -R "$user:$user_grp" "$app_dir" 2>/dev/null

    # Set arg
    existing_dir_check=1
  elif [[ "$selected_storage" =~ ^None.*$ ]]
  then
    msg "You have chosen to exit. Bye..."
    sleep 1
    exit 0
  fi
elif [ "${#existing_dst_dir_LIST[@]}" = 1 ]
then
    msg "No USB disks were detected. Please connect an existing exFAT USB disk or format a new disk using the Android option prompt. Once done, run this script again. Bye..."
    sleep 1
    exit 0
fi

# Create Kodirsync hidden ID file to identify a storage disk
# A hidden file named ".kodirsync_storage" is made in the storage dir. 
if [ -f "$dst_dir/.kodirsync_storage" ]
then
  # Create hidden file
  touch "$dst_dir/.kodirsync_storage"
  chattr +i "$dst_dir/.kodirsync_storage"
fi
#-----------------------------------------------------------------------------------