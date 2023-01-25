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

# Select a username to delete
while true
do
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
  msg "Identify and select a Kodirsync user to delete from the menu..."
  OPTIONS_VALUES_INPUT=( "$(printf '%s\n' "${user_LIST[@]}" | awk -F':' '{ print $1 }')" )
  OPTIONS_LABELS_INPUT=( "$(printf '%s\n' "${user_LIST[@]}" | awk -F':' '{if ($1 != "none" && $2 != "none") print "User name: "$1, "| Member of group: "$2;}')" )
  OPTIONS_VALUES_INPUT+=( "TYPE00" )
  OPTIONS_LABELS_INPUT+=( "None. Skip this task." )
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
  if [ "${RESULTS}" == "TYPE00" ]
  then
    # Exit installation
    msg "You have chosen not to proceed. Aborting. Bye..."
    sleep 1
    echo
    return
  fi

  # Set username to delete
  username="${RESULTS}"

  # Umount existing user bind mounts
  if [[ $(grep "$HOME_BASE/$username" /etc/fstab) ]]
  then
    while read dir
    do
      if mount | grep $dir > /dev/null; then
        umount $dir 2>/dev/null
      fi
      # Remove fstab entry
      sed -i "\@${dir}@d" /etc/fstab
    done < <( grep "$HOME_BASE/$username" /etc/fstab | awk '{print $2}' )
  fi
  # Deleting existing user name
  userdel -r ${username} 2>/dev/null
  rm -R "$HOME_BASE/$username" 2>/dev/null
  sed -i "/^${username}/d" $CHROOT/etc/passwd
  info "User name ${WHITE}'$username'${NC} has been deleted."
  echo
  # Delete old username files from backup
  old_user_backup_LIST=( $(find /mnt/backup/kodirsync/* -maxdepth 0 -type d -iname "${username}_*" 2> /dev/null) )
  for folder in "${old_user_backup_LIST[@]}"
  do
    rm -rf "$folder"
  done
done
#-----------------------------------------------------------------------------------















# SSH_KEY_GEN='1' # Create new ssh keys set '1', no set '0'
# DEL_USER='1' # Delete existing user set '1', no set '0'
# CREATE_USER='1' # Create user set '1', no set '0'

#---- Create a new user
while true; do
  # Create username
  input_kodirsync_username_val
  # Input user email address
  input_emailaddress_val

  # Check for existing user conflict
  if [ $(egrep "^${username}" /etc/passwd > /dev/null; echo $?) -eq 0 ]; then
    warn "User '${username}' already exists. tray another user name."
    echo
  else
    # Create new user account
    SSH_KEY_GEN='1' # Create new ssh keys set '1', no set '0'
    DEL_USER='0' # Delete existing user set '1', no set '0'
    CREATE_USER='1' # Create user set '1', no set '0'
    break
  fi
done

#---- Process ----------------------------------------------------------------------

# Backing up existing SSH Keys
if [ $SSH_KEY_GEN = 1 ] && [ $EXISTING_USER = 0 ] && [ -f $HOME_BASE/${username}/.ssh/authorized_keys ]; then
  msg "Backing up existing '${username}' SSH keys..."
  mkdir -p $TEMP_DIR/${username}_$(date +%Y%m%d)_old
  cp $HOME_BASE/${username}/.ssh/authorized_keys $TEMP_DIR/${username,,}_$(date +%Y%m%d)_old/ 2>/dev/null
  info "Existing '${username}' SSH keys temporary backup complete."
  echo
fi

# Backing up existing rsync control list files (white & black lists)
if [ $EXISTING_USER = 0 ] && [ -f $HOME_BASE/${username}/rsync_control_list_user-movies.txt ] && [ -f $HOME_BASE/${username}/rsync_control_list_user-series.txt ]; then
  msg "Backing up existing '${username}' rsync control list files..."
  mkdir -p $TEMP_DIR/${username}_$(date +%Y%m%d)_rsyncfiles
  cp $HOME_BASE/${username}/rsync_control_list_user-*.txt $TEMP_DIR/${username,,}_$(date +%Y%m%d)_rsyncfiles/ 2>/dev/null
  info "Existing '${username}' rsync control list files temporary backup complete."
  echo
fi

# Deleting existing user data
if [ $EXISTING_USER = 0 ] && [ $(grep "$HOME_BASE/${username}" /etc/fstab > /dev/null; echo $?) -eq 0 ]; then
  # Umount existing user bind mounts
  grep "$HOME_BASE/${username}" /etc/fstab | awk '{print $2}' > kodirsync_umountlist
  while read dir; do
    if mount | grep $dir > /dev/null; then
      msg "Umounting bind mount: ${WHITE}$dir${NC}"
      umount $dir 2>/dev/null
      info "Bind mount status: ${YELLOW}Disabled.${NC}"
    else
      msg "Umounting bind mount: ${WHITE}$dir${NC}"
      info "Bind mount status: ${YELLOW}Already Disabled.${NC}"
    fi
  done < kodirsync_umountlist # listing of bind mounts
  echo
fi
# Deleting existing user name
if [ $EXISTING_USER = 0 ]; then
  msg "Deleting existing user '${username}' (including home folder)..."
  userdel -r ${username} 2>/dev/null
  rm -R $HOME_BASE/${username} 2>/dev/null
  sed "/${username}/d" $CHROOT/etc/passwd
  info "{$username} has been deleted."
  echo
fi


#---- Create new user account 
section "Create new user account"
msg "Creating new user name '${username}'..."
useradd -g ${GROUP} -m -d $HOME_BASE/${username} -s /bin/bash ${username}
msg "Fixing '${username}' home folder location to '${GROUP}' setup..."
usermod -d /homes/${username} ${username}
awk -v user="${username}" -v path="/homes/${username}" 'BEGIN{FS=OFS=":"}$1==username{$6=path}1' /etc/passwd > temp_file
mv temp_file /etc/passwd
msg "Copy '${username}' password to chrooted /etc/passwd..."
cat /etc/passwd | grep ${username} >> $CHROOT/etc/passwd
cat /etc/group | grep chrootjail > $CHROOT/etc/group
msg "Add '${username}' to medialab group..."
usermod -a -G 65605 ${username}
msg "Creating authorised keys folders and settings for user '${username}'..."
mkdir -p $HOME_BASE/${username}/.ssh
touch $HOME_BASE/${username}/.ssh/authorized_keys
chmod -R 0700 $HOME_BASE/${username}
chmod 600 $HOME_BASE/${username}/.ssh/authorized_keys
chown -R ${username}:${GROUP} $HOME_BASE/${username}
info "User created: ${YELLOW}${username}${NC} of group ${GROUP}"
echo
if [ $SSH_KEY_GEN = 1 ] && [ $EXISTING_USER = 0 ]; then
  # Using existing SSH keys
  msg "Copying existing (former) user SSH keys to your new '${username}'..."
  cat $TEMP_DIR/${username}_$(date +%Y%m%d)_old/authorized_keys >> $HOME_BASE/${username}/.ssh/authorized_keys
  #cp $TEMP_DIR/${username}_$(date +%Y%m%d)_old/* $HOME_BASE/${username}/.ssh/ 2>/dev/null
  chown -R ${username}:${GROUP} $HOME_BASE/${username}
  rm -R $TEMP_DIR/${username}_$(date +%Y%m%d)_old 2>/dev/null
  info "Existing '${username}' SSH keys have been re-added to the system."
  echo
elif [ $SSH_KEY_GEN = 0 ]; then
  # Generating new SSH keys
  msg "Creating new SSH keys for '${username}'..." 
  ssh-keygen -o -q -t ed25519 -a 100 -f $HOME_BASE/${username}/.ssh/${username}_id_ed25519 -N ""
  cat $HOME_BASE/${username}/.ssh/${username}_id_ed25519.pub >> $HOME_BASE/${username}/.ssh/authorized_keys
  # Create ppk key for Putty or Filezilla
  msg "Creating a private PPK key (Putty or Filezilla)..."
  puttygen $HOME_BASE/${username}/.ssh/${username}_id_ed25519 -o $HOME_BASE/${username}/.ssh/${username}_id_ed25519.ppk
  # chown -R ${username}:${GROUP} $HOME_BASE/${username}
  msg "Backing up '${username}' latest SSH Rsync keys..."
  mkdir -p /mnt/backup/kodirsync/sshkey/${username}_$(date +%Y%m%d)
  chmod 0750 /mnt/backup/kodirsync/sshkey/${username}_$(date +%Y%m%d)
  cp $HOME_BASE/${username}/.ssh/${username}_id_ed25519* /mnt/backup/kodirsync/sshkey/${username}_$(date +%Y%m%d)/
  info "User '${username}' SSH keys have been added to the system."
  echo
fi
if [ $EXISTING_USER = 0 ]; then
  msg "Restoring former Rsync control list file (white & black lists)..."
  cp $TEMP_DIR/${username}_$(date +%Y%m%d)_rsyncfiles/* $HOME_BASE/${username}/ 2>/dev/null
  info "User '${username}' Rsync control list files have been restored."
  echo
fi

