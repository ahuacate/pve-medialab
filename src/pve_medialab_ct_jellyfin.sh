#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_jellyfin.sh
# Description:  This script is for creating a Proxmox Jellyfin CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_jellyfin.sh)"

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Easy Script Section Head
SECTION_HEAD='PVE Jellyfin'

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
HOSTNAME='jellyfin'
# Description for the Container (one word only, no spaces). Shown in the web-interface CT’s summary. 
DESCRIPTION=''
# Virtual OS/processor architecture.
ARCH='amd64'
# Allocated memory or RAM (MiB).
MEMORY='2048'
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
IP='192.168.50.111'
# IP address (IPv6). Only works with static IP (DHCP=0).
IP6=''
# Default gateway for traffic (IPv4). Only works with static IP (DHCP=0).
GW='192.168.50.5'
# Default gateway for traffic (IPv6). Only works with static IP (DHCP=0).
GW6=''

#---- PVE CT
#----[CT_GENERAL_OPTIONS]
# Unprivileged container status 
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
CT_MOUNT=''
# Allow nesting. Best used with unprivileged containers with additional id mapping.
CT_NESTING='1'
# A public key for connecting to the root account over SSH (insert path).

#----[CT_ROOTFS_OPTIONS]
# Virtual Disk Size (GB).
CT_SIZE='10'
# Explicitly enable or disable ACL support.
CT_ACL='1'

#----[CT_STARTUP_OPTIONS]
# Startup and shutdown behavior ( '--startup order=1,up=1,down=1' ). Order is a non-negative number defining the general startup order. Up=1 means first to start up. Shutdown in done with reverse ordering so down=1 means last to shutdown.
CT_ORDER='2'
CT_UP='2'
CT_DOWN='2'

#----[CT_NET_OPTIONS]
# Name of the network device as seen from inside the VM/CT.
CT_NAME='eth0'
CT_TYPE='veth'

#----[CT_OTHER]
# OS Version
CT_OSVERSION='22.04'
# CTID numeric ID of the given container.
CTID='111'

#----[App_UID_GUID]
# App user
APP_USERNAME='media'
# App user group
APP_GRPNAME='medialab'


#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for CT ( new version )
unset pvesm_required_LIST
pvesm_required_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  pvesm_required_LIST+=( "$line" )
done << EOF
# Example
audio:Audiobooks and podcasts
backup:CT settings backup storage
books:Ebooks and Magazines
music:Music, Albums and Songs
photo:Photographic image collection
transcode:Video transcoding disk or folder
video:All video libraries (i.e movies, series, homevideos)
EOF

#---- Body -------------------------------------------------------------------------

#---- Introduction
source ${COMMON_PVE_SRC_DIR}/pvesource_ct_intro.sh

#---- Setup PVE CT Variables
# Ubuntu NAS (all)
source ${COMMON_PVE_SRC_DIR}/pvesource_set_allvmvars.sh

# Check & create required PVE CT subfolders (all)
# source ${COMMON_DIR}/nas/src/nas_subfolder_installer_precheck.sh

#---- Create OS CT
source ${COMMON_PVE_SRC_DIR}/pvesource_ct_createvm.sh

#---- Pre-Configuring PVE CT
section "Pre-Configure ${HOSTNAME^} ${VM_TYPE^^}"

# MediaLab CT unprivileged mapping
if [ ${CT_UNPRIVILEGED} == '1' ]; then
  source ${COMMON_PVE_SRC_DIR}/pvesource_ct_medialab_ctidmapping.sh
fi

# Create CT Bind Mounts
source ${COMMON_PVE_SRC_DIR}/pvesource_ct_createbindmounts.sh

# VA-API Install & Setup for CT
source ${COMMON_PVE_SRC_DIR}/pvesource_ct_medialab_vaapipassthru.sh

#---- Configure New CT OS
source ${COMMON_PVE_SRC_DIR}/pvesource_ct_ubuntubasics.sh

#---- Create MediaLab Group and User
# source ${COMMON_PVE_SRC_DIR}/pvesource_ct_ubuntu_addmedialabuser.sh # Not required when doing a Jellyfin UID and GID edit

#---- Jellyfin ---------------------------------------------------------------------

section "Installing ${HOSTNAME^} software"

# Create SW installation package script
msg "Creating Jellyfin installation package..."
cat << 'EOF' > ${REPO_TEMP}/${GIT_REPO}/installpkg.sh
#!/usr/bin/env bash

# Installing HTTPS transport for APT
apt-get install apt-transport-https curl gnupg -y 2>/dev/null

# Importing the GPG signing key (signed by the Jellyfin Team)
curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg

# Adding a Jellyfin repository list
echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main unstable" | sudo tee /etc/apt/sources.list.d/jellyfin.list

# Updating container OS (be patient, might take a while)
apt-get update -y 2>/dev/null

# Installing Jellyfin software
apt-get install jellyfin -y 2>/dev/null

# Stop the service
if [ $(systemctl is-active jellyfin.service) == "active" ]; then
  systemctl stop jellyfin.service
  # Wait for service is 'stopped'
  while true; do
    if [ $(systemctl is-active jellyfin.service) != "active" ]; then
      break
    fi
    sleep 2
  done
fi

# Edit the Jellyfin UID and GID
OLDUID=$(id -u jellyfin)
OLDGID=$(id -g jellyfin)
usermod -u 1605 jellyfin >/dev/null
groupmod -g 65605 jellyfin >/dev/null
usermod -s /bin/bash jellyfin >/dev/null
find / \( -path /mnt \) -prune -o -user "$OLDUID" -exec chown -h 1605 {} \; 2>/dev/null
find / \( -path /mnt \) -prune -o -group "$OLDGID" -exec chgrp -h 65605 {} \; 2>/dev/null

# Edit /lib/systemd/system/jellyfin.service
# sed -i "s/^User =.*/User = media/g" /lib/systemd/system/jellyfin.service
# sed -i "s/^Group =.*/Group = medialab/g" /lib/systemd/system/jellyfin.service

# Restart Jellyfin service
systemctl daemon-reload
systemctl restart jellyfin

# Sleep and exit
sleep 3
exit
EOF

# Run the SW installation package script
pct push $CTID ${REPO_TEMP}/${GIT_REPO}/installpkg.sh /tmp/installpkg.sh -perms 755
pct exec $CTID -- bash -c "/tmp/installpkg.sh"
echo

# Check Install SW status
pct_check_systemctl "jellyfin.service"

#---- Create App settings backup folder on NAS
pct exec $CTID -- runuser ${APP_USERNAME} -c "mkdir -p /mnt/backup/${HOSTNAME,,}"


#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

#---- Set display text
unset display_msg1
# Web access URL
if [ -n "${IP}" ] && [ ! ${IP} == 'dhcp' ]; then
  display_msg1+=( "https://${IP}:8096/" )
elif [ -n "${IP6}" ] && [ ! ${IP6} == 'dhcp' ]; then
  display_msg1+=( "https://${IP6}:8096/" )
elif [ ${IP} == 'dhcp' ] || [ ${IP6} == 'dhcp' ]; then
  display_msg1+=( "http://$(pct exec $CTID -- bash -c "hostname -I | sed 's/ //g'"):8096/ (dhcp assigned IP based URL)" )
fi
display_msg1+=( "http://${HOSTNAME}.$(hostname -d):8096/ (Recommended URL)" )

msg_box "${HOSTNAME^} installation was a success. Web-interface is available at:

$(printf '%s\n' "${display_msg1[@]}" | indent2)

More information about configuring ${HOSTNAME^} is available here:

$(echo "https://github.com/ahuacate/jellyfin" | indent2)

Installation error log is available here: /tmp/${HOSTNAME,,}_pve_error_report.log"
echo

#---- Error Report
# Display error report and print to log file
source ${COMMON_PVE_SRC_DIR}/pvesource_error_log.sh | tee /tmp/${HOSTNAME,,}_pve_error.log
#-----------------------------------------------------------------------------------