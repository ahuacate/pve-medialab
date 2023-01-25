#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_vidcoderr_installer.sh
# Description:  This script is for creating a Proxmox Vidcoderr CT
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
SECTION_HEAD='PVE Vidcoderr'

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
HOSTNAME='vidcoderr'
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
TAG='0'
# VLAN ids to pass through the interface
TRUNKS=""
# Apply rate limiting to the interface (MB/s). Value "" for unlimited.
RATE=""
# MTU - Maximum transfer unit of the interface.
MTU=""

#----[COMMON_NET_DNS_OPTIONS]
# Nameserver server IP (IPv4 or IPv6) (value "" for none).
NAMESERVER='192.168.1.5'
# Search domain name (local domain)
SEARCHDOMAIN='local'

#----[COMMON_NET_STATIC_OPTIONS]
# IP address (IPv4). Only works with static IP (DHCP=0).
IP='192.168.1.122'
# IP address (IPv6). Only works with static IP (DHCP=0).
IP6=''
# Default gateway for traffic (IPv4). Only works with static IP (DHCP=0).
GW='192.168.1.5'
# Default gateway for traffic (IPv6). Only works with static IP (DHCP=0).
GW6=''

#---- PVE CT
#----[CT_GENERAL_OPTIONS]
# Unprivileged container status 
CT_UNPRIVILEGED='0'
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
CTID='122'

#----[App_UID_GUID]
# App user
APP_USERNAME='media'
# App user group
APP_GRPNAME='medialab'

#----[REPO_PKG_NAME]
# Repo package name (do not edit)
REPO_PKG_NAME='vidcoderr'


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
public:General public storage
transcode:Video transcoding disk or folder
video:All video libraries (i.e movies, series, homevideos)
EOF

#---- Body -------------------------------------------------------------------------

#---- Introduction
source $COMMON_PVE_SRC_DIR/pvesource_ct_intro.sh

#---- Setup PVE CT Variables
# Ubuntu NAS (all)
source $COMMON_PVE_SRC_DIR/pvesource_set_allvmvars.sh

# Check & create required PVE CT subfolders (all)
source ${COMMON_DIR}/nas/src/nas_subfolder_installer_precheck.sh

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

# VA-API Install & Setup for CT
source $COMMON_PVE_SRC_DIR/pvesource_ct_medialab_vaapipassthru.sh

#---- Configure New CT OS
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntubasics.sh

#---- Create MediaLab Group and User
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_addmedialabuser.sh

#---- Vidcoderr --------------------------------------------------------------------

#---- Prerequisites
section "${HOSTNAME^} Prerequisites"

# Installing Ruby
msg "Prerequisite - Installing Ruby..."
pct exec $CTID -- apt-get install ruby-full -yqq

# Install bc
msg "Prerequisite - Installing bc..."
pct exec $CTID -- apt-get install bc -yqq

# Install MKVToolNix
msg "Prerequisite - Installing MKVToolNix..."
pct exec $CTID -- wget -q --show-progress -O /usr/share/keyrings/gpg-pub-moritzbunkus.gpg https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg
pct exec $CTID -- apt-get update -yqq
pct exec $CTID -- apt-get install mkvtoolnix mkvtoolnix-gui -yqq

# Install FFmpeg
msg "Prerequisite - Installing FFmpeg..."
pct exec $CTID -- apt-get install ffmpeg -yqq

# Install Mediainfo
msg "Prerequisite - Installing Mediainfo..."
pct exec $CTID -- apt-get install mediainfo -yqq

# Install MPV
msg "Prerequisite - Installing MPV..."
pct exec $CTID -- apt-get install mpv -yqq

# Install MPV
msg "Prerequisite - Installing Inotify..."
pct exec $CTID -- apt-get install inotify-tools -yqq

# Install Translate
msg "Prerequisite - Installing Translate Shell..."
pct exec $CTID -- apt-get install translate-shell -yqq

# Install encoder kernels
pct exec $CTID -- apt-get install i965-va-driver-shaders -yqq
pct exec $CTID -- apt-get install intel-media-va-driver-non-free -yqq

#---- Install Don Melton Other Video Transcoding
section "Install Don Melton package"
msg "Installing Other-Video package..."
pct exec $CTID -- gem install other_video_transcoding
pct exec $CTID -- bash -c 'echo "PATH="$PATH:/usr/local/bin/other-transcode"" >> ~/.bashrc'
pct exec $CTID -- bash -c 'echo "PATH="/usr/local/bin:$PATH"" >> ~/.bashrc'

#---- Install Vidcoderr
section "Setup Vidcoderr"

# Create Vidcoderr
msg "Copying Vidcoderr files to CT ( be patient, can take a while )..."

# Create CT vidcoder dir
pct exec $CTID -- mkdir -p /usr/local/bin/vidcoderr
pct exec $CTID -- chown media:medialab /usr/local/bin/vidcoderr

# Copy vidcoderr.ini file
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr.ini /usr/local/bin/vidcoderr/vidcoderr.ini
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr.ini
# Copy vidcoderr_watchdir.sh script
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_watchdir.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
# Copy vidcoderr_watchdir_list.sh script
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_watchdir_list.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir_list.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir_list.sh
# Copy vidcoderr_watchdir_process.sh script
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_watchdir_process.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir_process.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir_process.sh
# Copy vidcoderr_watchdir_prune.sh script
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_watchdir_prune.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir_prune.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir_prune.sh
# Copy vidcoderr_encoder.sh script
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_encoder.sh /usr/local/bin/vidcoderr/vidcoderr_encoder.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_encoder.sh

# Copy inotify script
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_inotify_rsync.sh /usr/local/bin/vidcoderr/vidcoderr_inotify_rsync.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_inotify_rsync.sh

# Copy SimpleHTTPServerWithUpload scripts
pct push $CTID $SRC_DIR/vidcoderr/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.sh /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.sh

pct push $CTID $DIR/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.py /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.py
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.py

# Copy filters
pct push $CTID $SRC_DIR/vidcoderr/video_format_filter.txt /usr/local/bin/vidcoderr/video_format_filter.txt
pct push $CTID $SRC_DIR/vidcoderr/other_format_filter.txt /usr/local/bin/vidcoderr/other_format_filter.txt
pct push $CTID $SRC_DIR/vidcoderr/rsync_exclude_filter.txt /usr/local/bin/vidcoderr/rsync_exclude_filter.txt


# Chown media:medialab all txt files
pct exec $CTID -- bash -c 'chown media:medialab /usr/local/bin/vidcoderr/*.txt'

# Setup vidcoderr_watchdir log
cat << 'EOF' > $DIR/vidcoderr_watchdir
/usr/local/bin/vidcoderr/watchdir.log
{
  rotate daily
  maxsize 1M
  rotate 0
}
EOF
pct push $CTID $DIR/vidcoderr_watchdir /etc/logrotate.d/vidcoderr_watchdir
pct exec $CTID -- chmod 644 /etc/logrotate.d/vidcoderr_watchdir
pct exec $CTID -- chown root:root /etc/logrotate.d/vidcoderr_watchdir
pct exec $CTID -- touch /usr/local/bin/vidcoderr/vidcoderr_watchdir.log
pct exec $CTID -- chown -R media:medialab /usr/local/bin/vidcoderr/vidcoderr_watchdir.log
pct exec $CTID -- chown -R media:medialab /etc/logrotate.d/vidcoderr_watchdir

# Copy Systemd services
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_watchdir_rsync.service /etc/systemd/system/vidcoderr_watchdir_rsync.service
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_watchdir_rsync.timer /etc/systemd/system/vidcoderr_watchdir_rsync.timer
pct push $CTID $SRC_DIR/vidcoderr/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.service /etc/systemd/system/SimpleHTTPServerWithUpload.service
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_inotify_rsync.service /etc/systemd/system/vidcoderr_inotify_rsync.service
pct push $CTID $SRC_DIR/vidcoderr/vidcoderr_inotify.service /etc/systemd/system/vidcoderr_inotify.service
echo

#---- Configure Vidcoderr
source $SRC_DIR/vidcoderr/vidcoderr_configbuilder.sh
#-----------------------------------------------------------------------------------