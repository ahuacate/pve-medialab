#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_kodirsync_user_manager.sh
# Description:  This script is for Kodirsync User Manager
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_DIR="$DIR/../../common"
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"
SHARED_DIR="$DIR/../../shared"
TEMP_DIR=$(mktemp -d)

#---- Dependencies -----------------------------------------------------------------

# Check for kodirsync hostname
if [[ ! "$HOSTNAME" =~ ^kodirsync[.-]?[0-9]+?[0-9]+?$ ]]
then
  echo -e "PVE CT hostname check: \033[0;31mThis is not a 'kodirsync' CT\033[0m\n\nPVE Kodirsync must have a hostname of 'kodirsync'. Fix the issue and try again..."
  exit 0
fi

# Run Bash Header
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------

# Chroot Home
CHROOT='/home/chrootjail'
HOME_BASE="$CHROOT/homes"
GROUP='chrootjail'

#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='Kodirsync User Manager'

#---- Other Files ------------------------------------------------------------------
#----- Functions -------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Select a task
while true
do
section "Select a task"
echo
msg_box "#### PLEASE READ CAREFULLY ####\n
Kodirsync User Manager serves as your frontend toolbox for managing and configuring a Linux-based device, specifically a Kodi media player, to establish a secure connection with your Kodirsync PVE CT server. Kodirsync is compatible with CoreELEC or LibreELEC Kodi players. Upon creating a new user account, an installer package is emailed to the user to prepare their remote device. Once installed, a Kodirsync user can:

  --  Rsync mirror selected media categories, which are fully managed by the server.
  --  Perform daily synchronization of any newly added media.
  --  Automatically prune the oldest remote media files to accommodate new media.
  --  Fill the remote device disk up to a specified data limit (% GB).

The installation procedure consists of two parts. The first part involves creating a Kodirsync user account, selecting the NAS media libraries accessible to the new user, generating a private ssh ed25519 Rsync access key, and packaging the Kodirsync installation package, which will be emailed to the user.

The second part involves running our Kodirsync client installer package on your Linux-based Kodi hardware"

echo
msg "Select a Kodirsync toolbox task"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Create a new user account" \
"Delete a user account" \
"Modify an existing user rsync shares" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]; then
  #---- Create a new user account
  source $DIR/pve_medialab_ct_kodirsync_user_add.sh
elif [ "$RESULTS" = 'TYPE02' ]; then
  #---- Delete a existing user account
  source $DIR/pve_medialab_ct_kodirsync_user_delete.sh
elif [ "$RESULTS" = 'TYPE03' ]; then
  #---- Modify a existing users rsync shares
  source $DIR/pve_medialab_ct_kodirsync_user_modify.sh
elif [ "$RESULTS" = 'TYPE00' ]; then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  sleep 1
  echo
  exit 0
fi
done
#-----------------------------------------------------------------------------------