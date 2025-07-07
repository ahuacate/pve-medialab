#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# File_name:    pve_medialab_ct_kodirsync_user_shares.sh
# Description:  This script is for setting up user shares
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Check for kodirsync hostname
if [[ ! "$HOSTNAME" =~ ^kodirsync[.-]?[0-9]+?[0-9]+?$ ]]
then
  echo -e "PVE CT hostname check: \033[0;31mThis is not a 'kodirsync' CT\033[0m\n\nPVE Kodirsync must have a hostname of 'kodirsync'. Fix the issue and try again..."
  exit 0
fi

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

#---- Select your video library source (main vs stream)
section "Select a video library source location"

# Set display text
display_msg1=( $(find /mnt/video/* -maxdepth 0 -type d 2> /dev/null | grep -v 'cctv$\|transcode$\|images$\|homevideo$\|stream$\|\@.*\|\..*') ) # Main library
if [ -d /mnt/video/stream ]; then
  display_msg2=( $(find /mnt/video/stream/* -maxdepth 0 -type d 2> /dev/null | grep -v 'cctv$\|transcode$\|images$\|homevideo$\|\@.*\|\..*') ) # Stream library
else
  display_msg2=( "Not available - /mnt/video/stream/ does not exist" )
fi

msg_box "#### PLEASE READ CAREFULLY - VIDEO LIBRARY SOURCE ####\n
You must select a video library source to configure for synchronization.

$(printf '%s\n' "${display_msg1[@]}" | column -s ":" -t -N "MAIN VIDEO LIBRARY" | indent2)

Or if you have Vidcoderr installed and configured you can synchronise with the smaller 'streamer' media library.

$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "VIDCODERR VIDEO STREAM LIBRARY" | indent2)

Select whats appropriate for your Kodirsync player client."

msg "Select a video library source..."
if [ -d /mnt/video/stream ]; then
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
  OPTIONS_LABELS_INPUT=( "Main video library - original media files" \
  "Vidcoderr streaming library - smaller compressed media files" \
  "None. Exit this installer" )
else
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
  OPTIONS_LABELS_INPUT=( "Main video library - original media files" \
  "None. Exit this installer" )
fi
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
if [ "$RESULTS" = 'TYPE01' ]; then
  library_type=1
elif [ "$RESULTS" = 'TYPE02' ]; then
  library_type=2
elif [ "$RESULTS" = 'TYPE00' ]; then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  sleep 1
  echo
  return
fi

#---- Select private media options
section "Select private media options (photo & homevideo)"

# Set display text
if [ $(find /mnt/photo/* -maxdepth 0 -type d 2> /dev/null | grep -v 'images$\|\@.*\|\..*' | wc -l) -gt 0 ]; then
  display_msg1=( $(find /mnt/photo/* -maxdepth 0 -type d 2> /dev/null | grep -v 'images$\|\@.*\|\..*' | sed 's#^#--  #' | sed s'/$/\n/') )
else
  display_msg1=( "--  no user photo libraries available" )
fi
if [ $(find /mnt/video/homevideo/* -maxdepth 0 -type d 2> /dev/null | grep -v 'images$\|\@.*\|\..*' | wc -l) -gt 0 ]; then
  display_msg2=( $(find /mnt/video/homevideo/* -maxdepth 0 -type d 2> /dev/null | grep -v 'images$\|\@.*\|\..*' | sed 's#^#--  #' | sed s'/$/\n/') )
else
  display_msg2=( "--  no user home video libraries available" )
fi

msg_box "#### PLEASE READ CAREFULLY - PRIVATE MEDIA OPTIONS ####\n
You have the option of allowing '$username' read only access to your users publicly available photo and homevideo libraries. '$username' can only synchronize a users public library, not their private home folder libraries. You have two synchronization options:

1) Full Access to users public library content
  --  /mnt/photo and all sub folders
  --  /mnt/video/homevideo and all sub folders
If you choose this method then all content in folders '/mnt/photo' and '/mnt/video/homevideo' will be accessible by '$username'. This includes all media and folders added in the future!

2) Restricted Access to users public library content
Select individual library user folders you want to allow access by '$username'. All non-selected folders are excluded. You can grant access to any or none of the following existing sub folders:

$(printf '%s\n' "${display_msg1[@]}" | column -s ":" -t -N "PRIVATE USER PHOTO FOLDERS" | indent2)

$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "PRIVATE USER HOMEVIDEO FOLDERS" | indent2)

3) No Access to any public library content
No access to 'photo' and 'homevideo' content (blocked)."
echo

msg "Select a media source type..."
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Full access to all users public libraries" \
"Restricted & limited access to users public libraries" \
"No access to public library content (blocked)" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
if [ "$RESULTS" = 'TYPE01' ]; then
  public_access_type=1
elif [ "$RESULTS" = 'TYPE02' ]; then
  public_access_type=2
elif [ "$RESULTS" = 'TYPE03' ]; then
  public_access_type=3
elif [ "$RESULTS" = 'TYPE00' ]; then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  sleep 1
  echo
  return
fi


#---- Select media folders
section "Select media library content folders"

# Create empty arrays
dir_input_LIST=()
bindmount_LIST=()

# Set main media folders
if [ "$library_type" = 1 ]
then
  # Main media
  main_dir_LIST=( $(find /mnt/video/* -maxdepth 0 -type d 2> /dev/null | grep -v 'cctv$\|transcode$\|images$\|homevideo$\|stream$\|\@.*\|\..*') ) # Main library
  var1='main video library'
elif [ "$library_type" = 2 ]
then
  # Stream media
  main_dir_LIST=( $(find /mnt/video/stream/* -maxdepth 0 -type d 2> /dev/null | grep -v 'cctv$\|transcode$\|images$\|homevideo$\|\@.*\|\..*') ) # Main library
  var1='stream video library'
fi

msg "Select the ${var1} folders you want synchronized..."
OPTIONS_LABELS_INPUT=$(printf '%s\n' "${main_dir_LIST[@]}")
OPTIONS_VALUES_INPUT=$(printf '%s\n' "${main_dir_LIST[@]}")
makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
multiselect_confirm SELECTED "$OPTIONS_STRING"
# Create input disk list array
for i in "${RESULTS[@]}"
do
  media_cat=$(basename $i)
  dir_input_LIST+=( "${i},$HOME_BASE/$username/video/$media_cat" )
done


# Set users public folder access
if [ "$public_access_type" = 1 ]
then
  # Full public photo access
  if [ -d /mnt/photo ]
  then
    dir_input_LIST+=( "/mnt/photo,$HOME_BASE/$username/photo" )
  fi
  # Full public homevideo access
  if [ -d /mnt/video/homevideo ]
  then
    dir_input_LIST+=( "/mnt/video/homevideo,$HOME_BASE/$username/homevideo" )
  fi
elif [ "$public_access_type" = 2 ]
then
  # Restricted public access
  public_dir_LIST=()
  public_dir_LIST+=( $(find /mnt/photo/* -maxdepth 0 -type d 2> /dev/null | grep -v 'cctv$\|transcode$\|images$\|homevideo$\|\@.*\|\..*') ) # Main library
  public_dir_LIST+=( $(find /mnt/video/homevideo/* -maxdepth 0 -type d 2> /dev/null | grep -v 'cctv$\|transcode$\|images$\|\@.*\|\..*') ) # Main library

  msg "Select the public folders you want synchronized..."
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${public_dir_LIST[@]}")
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${public_dir_LIST[@]}")
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  multiselect_confirm SELECTED "$OPTIONS_STRING"
  # Create input disk list array
  for i in "${RESULTS[@]}"; do
    d2=$(dirname "$i")
    d3=$(dirname "$d2")
    dir_input_LIST+=( "${i},$HOME_BASE/$username/$(basename "$d3")/$(basename "$d2")/$(basename "$i")" )
  done
fi


#---- Select audio options
section "Select audio options (music & audio)"

# Set display text
if [ -d /mnt/music ]
then
  display_msg1=( "Music library:available" )
  OPTIONS_LABELS_INPUT=( "/mnt/music" )
  OPTIONS_VALUES_INPUT=( "/mnt/music" )
else
  display_msg1=( "Music library:not available (/mnt/music does not exists)" )
fi
if [ -d /mnt/audio ]
then
  display_msg1+=( "Audio library:available" )
  OPTIONS_LABELS_INPUT+=( "/mnt/audio" )
  OPTIONS_VALUES_INPUT+=( "/mnt/audio" )
else
  display_msg1+=( "Audio library:not available (/mnt/audio does not exists)" )
fi
# # Add No Access
# OPTIONS_LABELS_INPUT+=( "No access. Share nothing here" )
# OPTIONS_VALUES_INPUT+=( "TYPE00" )


msg_box "#### PLEASE READ CAREFULLY - AUDIO OPTIONS ####\n
You have the option of allowing '$username' to access and synchronize your audio media libraries (i.e music, audio-books, podcasts).

$(printf '%s\n' "${display_msg1[@]}" | column -s ":" -t -N "LIBRARY,STATUS" | indent2)

If you want to deny '$username' access to all libraries select nothing."

OPTIONS_LABELS_INPUT=$(printf '%s\n' "${OPTIONS_LABELS_INPUT[@]}")
OPTIONS_VALUES_INPUT=$(printf '%s\n' "${OPTIONS_VALUES_INPUT[@]}")
makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
multiselect_confirm SELECTED "$OPTIONS_STRING"
# Create input disk list array
if [ ! "${#RESULTS[@]}" = 0 ]
then
  for i in "${RESULTS[@]}"
  do
    # [[ $i == 'TYPE00' ]] && continue
    media_cat=$(basename $i)
    dir_input_LIST+=( "${i},$HOME_BASE/$username/$media_cat" )
  done
fi

#---- Processing media folder inputs -----------------------------------------------

# Create bind mounts
while IFS=',' read -r local_mnt bind_mnt
do
  # Create the directory for bind mount
  mkdir -p "$bind_mnt"

  # Set ownership and permissions for the bind mount directory
  chown "$username":"$GROUP" "$bind_mnt"
  chmod 0700 "$bind_mnt"

  # Add an entry to /etc/fstab for the bind mount
  echo "$local_mnt $bind_mnt none bind,ro,xattr,acl 0 0" >> /etc/fstab

  # Mount the local mount point
  mount "$local_mnt"
done < <(printf '%s\n' "${dir_input_LIST[@]}")

# Create bind mount 'kodirsync_control_list.txt' to '~/video/kodirsync_control_list.txt'
if [ -f "/mnt/video/kodirsync_control_list.txt" ] && [ -d "/home/chrootjail/homes/$username" ]
then
  # Create mnt point file
  touch /home/chrootjail/homes/$username/kodirsync_control_list.txt

  # Create bind mnt
  mount --bind -o ro /mnt/video/kodirsync_control_list.txt /home/chrootjail/homes/$username/kodirsync_control_list.txt

  # Create fstab mnt
  echo "/mnt/video/kodirsync_control_list.txt /home/chrootjail/homes/$username/kodirsync_control_list.txt none bind,ro 0 0" >> /etc/fstab
fi

# Perform a global mount cmd
mount -a 2> /dev/null

info "Number of '$username' access shares created: ${YELLOW}"${#dir_input_LIST[@]}"x shares${NC}"
echo
#-----------------------------------------------------------------------------------