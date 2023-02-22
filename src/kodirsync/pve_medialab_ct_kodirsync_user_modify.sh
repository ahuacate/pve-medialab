#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_kodirsync_user_delete.sh
# Description:  This script is for deleting a Kodirsync client/user account
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Chroot Home
CHROOT='/home/chrootjail'
HOME_BASE="$CHROOT/homes"
GROUP="chrootjail"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#----- Functions -------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Select a username to modify
user_LIST=()
user_LIST+=( $(cat /etc/passwd | awk -F':' 'BEGIN{OFS=FS} $4 == "65608" {($4="chrootjail");print $1, $4}') )
# Check for existing users
if [ "${#user_LIST[@]}" == '0' ]
then
  msg "There are currently no Kodirsync users installed. Bye..."
  sleep 1
  return
fi
# Make selection
msg "Identify and select a Kodirsync user to modify from the menu..."
OPTIONS_VALUES_INPUT=( "$(printf '%s\n' "${user_LIST[@]}" | awk -F':' '{ print $1 }')" )
OPTIONS_LABELS_INPUT=( "$(printf '%s\n' "${user_LIST[@]}" | awk -F':' '{if ($1 != "none" && $2 != "none") print "User name: "$1, "| Member of group: "$2;}')" )
OPTIONS_VALUES_INPUT+=( "TYPE00" )
OPTIONS_LABELS_INPUT+=( "None. Skip this task." )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
if [ "$RESULTS" = "TYPE00" ]; then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  sleep 1
  echo
  return
fi

# Set username to delete
username="$RESULTS"

#---- Umount existing user bind mounts
if [[ $(grep "${HOME_BASE}/$username" /etc/fstab) ]]
then
  while read dir
  do
    if mount | grep $dir > /dev/null; then
      umount $dir 2>/dev/null
    fi
    # Remove fstab entry
    sed -i "\@${dir}@d" /etc/fstab
    # Delete bind mnt folder
    rm -R $dir 2>/dev/null
  done < <( grep "${HOME_BASE}/$username" /etc/fstab | awk '{print $2}' ) # listing of bind mounts
fi

#----- Create user shares
source $DIR/pve_medialab_ct_kodirsync_user_shares.sh
#-----------------------------------------------------------------------------------