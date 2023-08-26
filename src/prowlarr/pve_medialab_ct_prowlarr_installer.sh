#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_prowlarr_installer.sh
# Description:  This script is for creating a Proxmox Prowlarr CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#---- Source Github
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/main/pve_medialab_installer.sh)"

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/pve-medialab/pve_medialab_installer.sh

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Easy Script Section Head
SECTION_HEAD='PVE Prowlarr'

# PVE host IP
PVE_HOST_IP=$(hostname -i)
PVE_HOSTNAME=$(hostname)

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=1

# Developer enable git mounts inside CT  (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=1

# Set file source (path/filename) of preset variables for 'pvesource_ct_createvm.sh'
PRESET_VAR_SRC="$( dirname "${BASH_SOURCE[0]}" )/$( basename "${BASH_SOURCE[0]}" )"

#---- Other Variables --------------------------------------------------------------

#---- Common Machine Variables
# VM Type ( 'ct' or 'vm' only lowercase )
VM_TYPE='ct'
# Use DHCP. '0' to disable, '1' to enable.
NET_DHCP='1'
#  Set address type 'dhcp4'/'dhcp6' or '0' to disable.
NET_DHCP_TYPE='dhcp4'
# CIDR IPv4
CIDR='24'
# CIDR IPv6
CIDR6='64'
# SSHd Port
SSH_PORT='22'

#----[COMMON_GENERAL_OPTIONS]
# Hostname
HOSTNAME='prowlarr'
# Description for the Container (one word only, no spaces). Shown in the web-interface CT’s summary. 
DESCRIPTION=''
# Virtual OS/processor architecture.
ARCH='amd64'
# Allocated memory or RAM (MiB).
MEMORY='512'
# Limit number of CPU sockets to use.  Value 0 indicates no CPU limit.
CPULIMIT='0'
# CPU weight for a VM. Argument is used in the kernel fair scheduler. The larger the number is, the more CPU time this VM gets.
CPUUNITS='1024'
# The number of cores assigned to the vm/ct. Do not edit - its auto set.
CORES='1'

#----[COMMON_NET_OPTIONS]
# Bridge to attach the network device to.
BRIDGE='vmbr0'
# A common MAC address with the I/G (Individual/Group) bit not set. 
HWADDR=""
# Controls whether this interface’s firewall rules should be used.
FIREWALL='1'
# VLAN tag for this interface (value 0 for none, or VLAN[2-N] to enable).
TAG='50'
# VLAN ids to pass through the interface
TRUNKS=""
# Apply rate limiting to the interface (MB/s). Value "" for unlimited.
RATE=""
# MTU - Maximum transfer unit of the interface.
MTU=""

#----[COMMON_NET_DNS_OPTIONS]
# Nameserver server IP (IPv4 or IPv6) (value "" for none).
NAMESERVER='192.168.50.5'
# Search domain name (local domain)
SEARCHDOMAIN='local'

#----[COMMON_NET_STATIC_OPTIONS]
# IP address (IPv4). Only works with static IP (DHCP=0).
IP='192.168.50.121'
# IP address (IPv6). Only works with static IP (DHCP=0).
IP6=''
# Default gateway for traffic (IPv4). Only works with static IP (DHCP=0).
GW='192.168.50.5'
# Default gateway for traffic (IPv6). Only works with static IP (DHCP=0).
GW6=''

#---- PVE CT
#----[CT_GENERAL_OPTIONS]
# Unprivileged container. '0' to disable, '1' to enable/yes.
CT_UNPRIVILEGED='1'
# Memory swap
CT_SWAP='512'
# OS
CT_OSTYPE='ubuntu'
# Onboot startup
CT_ONBOOT='1'
# Timezone
CT_TIMEZONE='host'
# Root credentials
CT_PASSWORD='ahuacate'
# Virtual OS/processor architecture.
CT_ARCH='amd64'

#----[CT_FEATURES_OPTIONS]
# Allow using fuse file systems in a container.
CT_FUSE='0'
# For unprivileged containers only: Allow the use of the keyctl() system call.
CT_KEYCTL='0'
# Allow mounting file systems of specific types. (Use 'nfs' or 'cifs' or 'nfs;cifs' for both or leave empty "")
CT_MOUNT='nfs;cifs'
# Allow nesting. Best used with unprivileged containers with additional id mapping.
CT_NESTING='1'
# A public key for connecting to the root account over SSH (insert path).

#----[CT_ROOTFS_OPTIONS]
# Virtual Disk Size (GB).
CT_SIZE='5'
# Explicitly enable or disable ACL support.
CT_ACL='1'

#----[CT_STARTUP_OPTIONS]
# Startup and shutdown behavior ( '--startup order=1,up=1,down=1' ).
# Order is a non-negative number defining the general startup order. Up=1 means first to start up. Shutdown in done with reverse ordering so down=1 means last to shutdown.
# Up: Startup delay. Defines the interval between this container start and subsequent containers starts. For example, set it to 240 if you want to wait 240 seconds before starting other containers.
# Down: Shutdown timeout. Defines the duration in seconds Proxmox VE should wait for the container to be offline after issuing a shutdown command. By default this value is set to 60, which means that Proxmox VE will issue a shutdown request, wait 60s for the machine to be offline, and if after 60s the machine is still online will notify that the shutdown action failed. 
CT_ORDER='3'
CT_UP='30'
CT_DOWN='60'

#----[CT_NET_OPTIONS]
# Name of the network device as seen from inside the VM/CT.
CT_NAME='eth0'
CT_TYPE='veth'

#----[CT_OTHER]
# OS Version
CT_OSVERSION='22.04'
# CTID numeric ID of the given container.
CTID='121'

#----[App_UID_GUID]
# App user
APP_USERNAME='media'
# App user group
APP_GRPNAME='medialab'

#----[REPO_PKG_NAME]
# Repo package name
REPO_PKG_NAME='prowlarr'

#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for CT ( new version )
unset pvesm_required_LIST
pvesm_required_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  pvesm_required_LIST+=( "$line" )
done << EOF
# Example
backup:CT settings backup storage
EOF

#---- Body -------------------------------------------------------------------------

#---- Introduction
source $COMMON_PVE_SRC_DIR/pvesource_ct_intro.sh

#---- Setup PVE CT Variables
# Ubuntu NAS (all)
source $COMMON_PVE_SRC_DIR/pvesource_set_allvmvars.sh

# Check & create required PVE CT subfolders (all)
source $COMMON_DIR/nas/src/nas_subfolder_installer_precheck.sh

#---- Create OS CT
source $COMMON_PVE_SRC_DIR/pvesource_ct_createvm.sh

#---- Pre-Configuring PVE CT
section "Pre-Configure ${HOSTNAME^} ${VM_TYPE^^}"

# MediaLab CT unprivileged mapping
if [ "$CT_UNPRIVILEGED" = '1' ]
then
  source $COMMON_PVE_SRC_DIR/pvesource_ct_medialab_ctidmapping.sh
fi

# Create CT Bind Mounts
source $COMMON_PVE_SRC_DIR/pvesource_ct_createbindmounts.sh

#---- Configure New CT OS
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntubasics.sh

#---- Create MediaLab Group and User
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_addmedialabuser.sh

#---- Install CT 'auto-updater'
source $COMMON_PVE_SRC_DIR/pvesource_ct_autoupdater_installer.sh


#---- Prowlarr -----------------------------------------------------------------------

section "Install ${REPO_PKG_NAME^} software"

#---- Prerequisites

# Pushing scripts to CT
msg "Pushing repo scripts to NAS CT..."
pct push $CTID $REPO_TEMP/${GIT_REPO}.tar.gz /tmp/${GIT_REPO}.tar.gz
pct exec $CTID -- tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp


#---- Install Prowlarr SW
pct exec $CTID -- bash -c "export REPO_PKG_NAME=$REPO_PKG_NAME APP_USERNAME=$APP_USERNAME APP_GRPNAME=$APP_GRPNAME && /tmp/$GIT_REPO/shared/src/servarr_ct_sw.sh"

# Check Install CT SW status (active or abort script)
pct_check_systemctl "${REPO_PKG_NAME}.service"


#---- Install other SW
pct exec $CTID -- bash -c "export REPO_PKG_NAME=$REPO_PKG_NAME APP_USERNAME=$APP_USERNAME APP_GRPNAME=$APP_GRPNAME && /tmp/$GIT_REPO/src/$REPO_PKG_NAME/prowlarr_sw.sh"

# Check Install CT SW status (active or abort script)
pct_check_systemctl "flaresolverr.service"


#---- Copy preset settings file to CT and NAS
if [ $(find "$SRC_DIR/$REPO_PKG_NAME/config/" -name "${REPO_PKG_NAME}_backup_*.zip" -type f) ]
then
  pct exec $CTID -- bash -c "export REPO_PKG_NAME=$REPO_PKG_NAME APP_USERNAME=$APP_USERNAME APP_GRPNAME=$APP_GRPNAME"
  pct exec $CTID -- bash -c "su -c 'mkdir -p /mnt/backup/$REPO_PKG_NAME' $APP_USERNAME"
  pct exec $CTID -- bash -c "su -c 'mkdir -p /var/lib/$REPO_PKG_NAME/Backups/manual' $APP_USERNAME"
  # Copy App backup ahuacate settings file to CT & NAS
  backup_file=$(find $SRC_DIR/$REPO_PKG_NAME/config/ -name "${REPO_PKG_NAME}_backup_*.zip" -type f -exec basename {} 2> /dev/null \;)
  pct push $CTID $SRC_DIR/$REPO_PKG_NAME/config/$backup_file /var/lib/$REPO_PKG_NAME/Backups/manual/$backup_file
  pct exec $CTID -- chown "$APP_USERNAME":"$APP_GRPNAME" /var/lib/$REPO_PKG_NAME/Backups/manual/$backup_file
  pct exec $CTID -- bash -c "su -c 'cp /var/lib/$REPO_PKG_NAME/Backups/manual/$backup_file /mnt/backup/$REPO_PKG_NAME/$backup_file' $APP_USERNAME 2> /dev/null"
fi

#---- Finish Line ------------------------------------------------------------------
section "Completion Status"

#---- Set display text
# Get port
port='9696'
# Get IP type (ip -4 addr show eth0)
if [[ $(pct exec $CTID -- ip addr show eth0 | grep dynamic) ]]
then
  ip_type='dhcp - best use dhcp IP reservation'
else
  ip_type='static IP'
fi
# Web access URL
display_msg1=( "http://$(pct exec $CTID -- hostname).$(pct exec $CTID -- hostname -d):$port/" )
display_msg1+=( "http://$(pct exec $CTID -- hostname -I | sed -r 's/\s+//g'):$port/ ($ip_type)" )
# Backup preset file
if [ ! -z ${backup_file+x} ]
then
  display_msg2=( "Local: $backup_file" )
else
  display_msg2=( "Local: 'preset file not available'" )
fi
# Backup preset description
display_msg3=( "--  General ${REPO_PKG_NAME^} configuration and settings" \
"--  Includes Ahuacate customization" \
"--  Presets for Radarr, Sonarr, Lidarr" \
"--  Includes built-in FlareSolverr on host: http://localhost:8191/" \
"--  Sets backup destination: /mnt/backup/$REPO_PKG_NAME (preset to use NAS)" \
"--  Includes some configured public torrent indexers" \
"--  Doesn't include 3rd party account details (i.e usenet or private indexers)" )
# Check CT domain
if [ ! "$(hostname -d)" = 'local' ]
then 
  display_msg3+=( "--  Note: The default preset file uses the '.local' domain." \
  "    User must edit ${REPO_PKG_NAME^} app settings to use '.$(hostname -d)'" )
fi

# Print display
msg_box "${REPO_PKG_NAME^} installation was a success. The first start-up may take a few seconds so be patient. Web-interface is available on:

$(printf '%s\n' "${display_msg1[@]}" | indent2)

If the ${REPO_PKG_NAME^} settings preset file is available go to ${REPO_PKG_NAME^} WebGUI 'System' > 'Backup' and restore the backup filename:

$(printf '%s\n' "${display_msg2[@]}" | indent2)

The ${REPO_PKG_NAME^} setting preset file configures:

$(printf '%s\n' "${display_msg3[@]}" | indent2)

You MUST set your Servarr applications (i.e Radarr, Sonarr, Lidarr, Readarr) with your Prowlarr API key. Prowlarr also requires each Servarr client API key.

$(if [ ! -z ${CT_PASSWORD+x} ]; then echo "The default ${REPO_PKG_NAME^} CT root password is: '$CT_PASSWORD'"; fi)
More information here: https://github.com/ahuacate/medialab"

# Display Installation error report
printf '%s\n' "${display_dir_error_MSG[@]}"
printf '%s\n' "${display_permission_error_MSG[@]}"
printf '%s\n' "${display_chattr_error_MSG[@]}"
source $COMMON_PVE_SRC_DIR/pvesource_error_log.sh
#-----------------------------------------------------------------------------------