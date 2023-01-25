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
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='PVE Kodirsync'

# Setting Variables
if [ -f /tmp/pve_ct_variables.sh ]
then
  mv /tmp/pve_ct_variables.sh . 2>/dev/null
  # Import Variables
  . ./pve_ct_variables.sh
fi

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
section "Performing Prerequisites"

msg "Installing ACL..."
apt-get install -y acl >/dev/null
msg "Installing Putty Tools..."
apt-get install -y putty-tools >/dev/null
msg "Setting default adduser start range for dynamically allocated UIDs..."
sed -i "s/^FIRST_UID=.*/FIRST_UID=50000/g" /etc/adduser.conf
sed -i "s/^UID_MIN.*/UID_MIN                 50000/g" /etc/login.defs
echo

#---- Create SSH Chroot jail Environment
# bash -c "export PARENT_EXEC_INSTALL_KODI_RSYNC=0 && export SSH_PORT=${SSH_PORT} && source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_installchroot.sh"
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_installchroot.sh
# PARENT_EXEC_INSTALL_KODI_RSYNC=0
# $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_installchroot.sh


#---- Create /root/.ssh folder
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Removing ForceCommand internal-sftp
sed -i 's|^[#]*\s*        ForceCommand internal-sftp||g' /etc/ssh/sshd_config
systemctl restart ssh 2>/dev/null

#---- Create conf folder
mkdir -p /usr/local/bin/kodirsync
# Create conf file
local_ip_address="$(hostname -I | sed 's/\s//g')"
localdomain_address_url="$(hostname).$(hostname -d)"
printf "%b\n" '# This is the Kodirsync configuration (.conf) settings file' \
"#" \
"# Enable remote sslh access. '0' to disable, '1' to enable" \
"sslh_enable=0" \
"sslh_port=443" \
"sslh_address_url=" \
"# Enable remote port forward (pf) access. '0' to disable, '1' to enable" \
"pf_enable=0" \
"pf_port=2222" \
"pf_address_url=" \
"# LAN access" \
"ssh_port=${SSH_PORT}" \
"local_ip_address=${local_ip_address}" \
"localdomain_address_url=${localdomain_address_url}" > /usr/local/bin/kodirsync/kodirsync.conf

#---- Create Rsync Whitelist & Blacklist file

# Run install script
chmod +x $DIR/config/rsync_control_list.sh
chown "media":"medialab" $DIR/config/rsync_control_list.sh
su media -s $DIR/config/rsync_control_list.sh


#---- Install Fail2ban
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_installfail2ban.sh
#-----------------------------------------------------------------------------------