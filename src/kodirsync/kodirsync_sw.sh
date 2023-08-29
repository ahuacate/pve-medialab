#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_sw.sh
# Description:  Setup for Kodirsync CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_DIR="$DIR/../../common"
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"
SHARED_DIR="$DIR/../../shared"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_DIR/bash/src/basic_bash_utility.sh

# Read variables
source /tmp/pve_ct_variables.sh

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"           # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Install Crudini
apt-get install crudini -y

# Install acl
apt-get install -y acl >/dev/null

# Install putty tools
apt-get install -y putty-tools >/dev/null

# Set default adduser start range for dynamically allocated UIDs
sed -i "s/^FIRST_UID=.*/FIRST_UID=50000/g" /etc/adduser.conf
sed -i "s/^UID_MIN.*/UID_MIN                 50000/g" /etc/login.defs


#---- Create SSH Chroot jail Environment
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_installchroot.sh


#---- Create /root/.ssh folder

# Create .ssh dir
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Removing ForceCommand internal-sftp
sed -i 's|^[#]*\s*        ForceCommand internal-sftp||g' /etc/ssh/sshd_config
sed -i 's/^\s*\(#\{0,1\}\)ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config
sed -i 's/^\s*\(#\{0,1\}\)ClientAliveCountMax.*/ClientAliveCountMax 15/' /etc/ssh/sshd_config
pct_restart_systemctl "ssh.service"


#---- Create server conf folder

# Create conf dir
mkdir -p /usr/local/bin/kodirsync

# Copy 'kodirsync.conf' to '/usr/local/bin/kodirsync'
cp $DIR/config/kodirsync.conf /usr/local/bin/kodirsync/

# Edit conf file
local_ip_address="$(hostname -I | sed 's/\s//g')"
localdomain_address_url="$(hostname).$(hostname -d)"
crudini --set /usr/local/bin/kodirsync/kodirsync.conf "" ssh_port "$SSH_PORT"
crudini --set /usr/local/bin/kodirsync/kodirsync.conf "" local_ip_address "$local_ip_address"
crudini --set /usr/local/bin/kodirsync/kodirsync.conf "" localdomain_address_url "$localdomain_address_url"


#---- Kodirsync Whitelist & Blacklist file

# Copy 'kodirsync_control_list.txt' to video share
chown "$app_uid:$app_guid" $DIR/config/kodirsync_control_list.tmpl
sudo -u $app_uid cp $DIR/config/kodirsync_control_list.tmpl /mnt/video/kodirsync_control_list.txt

#---- Install Fail2ban
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_installfail2ban.sh
#-----------------------------------------------------------------------------------