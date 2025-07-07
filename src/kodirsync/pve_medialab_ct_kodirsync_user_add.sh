#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_kodirsync_user_add.sh
# Description:  This script is for creating a Kodirsync client/user account
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

# Input a Email Address with validation.
function input_emailaddress_val() {
  while true
  do
    read -p "Enter a valid email address for the new user: " email_var
    user_email=$(echo "$email_var" | sed 's/\s//g')
    i=$(echo "$email_var" | sed 's/\s//g')
    IFS="@"
    set -- $i
    msg "Validating email..."
    if [ "${#@}" -ne 2 ]; then
      warn "Your email address '$user_email' was rejected. Possible non-conformity input. Try again..."
    else
      # Check domain
      domain="$2"
      dig $domain | grep "ANSWER: 0" 1>/dev/null && domain_check=0
      if [ "${domain_check}" == '0' ]; then
        warn "Your email address '$user_email' was rejected. Email domain $domain check failed. Try again..."
      else
        info "User email is set is set : $user_email"
        echo
        break
      fi
    fi
  done
}

# Create a kodirsync username
function input_kodirsync_username_val() {
  while true
  do
    read -p "Enter a new user name : " username
    if [ ${#username} -gt 18 ]
    then
    msg "User name ${WHITE}'$username'${NC} is not valid. A user name is considered valid when all of the following constraints are satisfied:\n\n  --  it contains only lowercase characters\n  --  it begins with 3 alphabet characters\n  --  it contains at least 5 characters and at most is 10 characters long\n  --  it may include numerics and underscores\n  --  it doesn't contain any hyphens, periods or special characters [!#$&%*+-]\n\nTry again...\n"
    elif [[ "$username" =~ ^([a-z]{3})([_]?[a-z\d]){2,7}$ ]]; then
      info "Your user name is set : ${YELLOW}"$username"${NC}"
      echo
      break
    else
      msg "User name ${WHITE}'$username'${NC} is not valid. A user name is considered valid when all of the following constraints are satisfied:\n\n  --  it contains only lowercase characters\n  --  it begins with 3 alphabet characters\n  --  it contains at least 5 characters and at most is 10 characters long\n  --  it may include numerics and underscores\n  --  it doesn't contain any hyphens, periods or special characters [!#$&%*+-]\n\nTry again...\n"
    fi
  done
}

#---- Body -------------------------------------------------------------------------
# SSH_KEY_GEN='1' # Create new ssh keys set '1', no set '0'
# DEL_USER='1' # Delete existing user set '1', no set '0'
# CREATE_USER='1' # Create user set '1', no set '0'


#---- Create a new user
while true
do
  # Create username
  input_kodirsync_username_val

  # Input user email address
  input_emailaddress_val

  # Check for existing user conflict
  if [ $(egrep "^$username" /etc/passwd > /dev/null; echo $?) -eq 0 ]
  then
    warn "User '$username' already exists. Select an option..."
    OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
    OPTIONS_LABELS_INPUT=( "Try another user name" \
    "Skip this task. Exit this installer" )
    makeselect_input2
    singleselect SELECTED "$OPTIONS_STRING"

    if [ "$RESULTS" = 'TYPE01' ]; then
      echo
    elif [ "$RESULTS" = 'TYPE00' ]; then
      # Exit installation
      msg "You have chosen not to proceed. Aborting. Bye..."
      sleep 1
      echo
      return
    fi
  else
    break
  fi
done


#---- Create new user account 
section "Create new user account"

msg "Creating new user name '$username'..."
useradd -g $GROUP -m -d $HOME_BASE/"$username" -s /bin/bash "$username"
msg "Fixing '"$username"' home folder location to '$GROUP' setup..."
usermod -d /homes/"$username" "$username"
awk -v user=""$username"" -v path="/homes/"$username"" 'BEGIN{FS=OFS=":"}$1==username{$6=path}1' /etc/passwd > temp_file
mv temp_file /etc/passwd
msg "Copy '"$username"' password to chrooted /etc/passwd..."
cat /etc/passwd | grep "$username" >> $CHROOT/etc/passwd
cat /etc/group | grep chrootjail > $CHROOT/etc/group
msg "Add '"$username"' to medialab group..."
usermod -a -G 65605 "$username"
msg "Creating authorised keys folders and settings for user '"$username"'..."
mkdir -p $HOME_BASE/"$username"/.ssh
touch $HOME_BASE/"$username"/.ssh/authorized_keys
chmod -R 0700 $HOME_BASE/"$username"
chmod 600 $HOME_BASE/"$username"/.ssh/authorized_keys
chown -R "$username":$GROUP $HOME_BASE/"$username"
info "User created: ${YELLOW}"$username"${NC} of group $GROUP"
echo

# Generating new SSH keys
msg "Creating new SSH keys for '$username'..." 
ssh-keygen -o -q -t ed25519 -a 100 -f $HOME_BASE/"$username"/.ssh/"$username"_kodirsync_id_ed25519 -N ""
cat $HOME_BASE/"$username"/.ssh/"$username"_kodirsync_id_ed25519.pub >> $HOME_BASE/"$username"/.ssh/authorized_keys
# Create ppk key for Putty or Filezilla
msg "Creating a private PPK key (Putty or Filezilla)..."
puttygen $HOME_BASE/"$username"/.ssh/"$username"_kodirsync_id_ed25519 -o $HOME_BASE/"$username"/.ssh/"$username"_kodirsync_id_ed25519.ppk
info "User '"$username"' SSH keys have been added to the system."
# chown -R "$username":$GROUP $HOME_BASE/"$username"

# Generating new node SSH key pair
# These keys are used for Kodirsync node sync only
msg "Creating new SSH key pairs for Kodirsync node sync..." 
ssh-keygen -o -q -t rsa -f $TEMP_DIR/kodirsync_node_rsa_key -N ""
# Create ppk key for Putty or Filezilla
msg "Creating a private PPK key (Putty or Filezilla)..."
puttygen $TEMP_DIR/kodirsync_node_rsa_key -o $TEMP_DIR/kodirsync_node_rsa_key.ppk
info "Kodirsync node sync key pairs generated"

#---- Create user tmp dir

# Create the directory for bind mount
mkdir -p "$HOME_BASE/$username/tmp"

# Set ownership and permissions for the bind mount directory
chown "$username":"$GROUP" "$HOME_BASE/$username/tmp"
chmod 0777 "$HOME_BASE/$username/tmp"

# Add an entry to /etc/fstab for the bind mount
echo "/mnt/tmp $HOME_BASE/$username/tmp none bind,rwx,xattr,acl 0 0" >> /etc/fstab

# Mount the local mount point
mount "/mnt/tmp"
mount -a


#---- Create user shares

# Create user bind mounts
source $DIR/pve_medialab_ct_kodirsync_user_shares.sh


#---- Create installer package
source $DIR/pve_medialab_ct_kodirsync_user_pkg_builder.sh


#---- Backup User credentials & Installer to NAS

if [ -d "/mnt/backup/kodirsync" ]
then
  # Create user folder
  user_bak_dir="${username}_$(date +%Y%m%d)"
  mkdir -p "/mnt/backup/kodirsync/$user_bak_dir"
  chmod 0750 "/mnt/backup/kodirsync/$user_bak_dir"

  # Copy keys to User backup folder
  cp $HOME_BASE/$username/.ssh/${username}_kodirsync_id_ed25519* "/mnt/backup/kodirsync/$user_bak_dir/"

  # Copy 'installer.run' to User backup folder
  cp $HOME_BASE/$username/installer.run "/mnt/backup/kodirsync/$user_bak_dir/"

  # Copy Kodirsync node keys to User backup folder
  cp $TEMP_DIR/kodirsync_node_rsa_key* "/mnt/backup/kodirsync/$user_bak_dir/"
fi


#---- Email installer package

# Run Sendmail script
# You can run this script with the following arguments:
#   -t --to
#   -c --cc
#   -b --bcc
#   -s --subject
#   -h --html
#   -a --attach
#   ./pvesource_send_email.sh -t "hello@gmail.com" -c CC -b BCC -s
source ${COMMON_PVE_SRC_DIR}/pvesource_send_email.sh \
-t "$user_email" \
-c "vmclient.alias@virtual-alias.domain" \
-s "Kodirsync installer package [$user_email]" \
-h "$DIR/email_tml/email_body.html" \
-a "$HOME_BASE/$username/installer.run"
#-----------------------------------------------------------------------------------