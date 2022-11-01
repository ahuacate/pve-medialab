#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_jellyfin.sh
# Description:  This script is for creating a Proxmox Jellyfin CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_jellyfin.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}/../../common/pve/source"

#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your PVE hosts internet connection and try again..."
  echo
  exit 0
fi

# Run Bash Header
source ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------

# Set Max CT Host CPU Cores 
HOST_CPU_CORES=$(( $(lscpu | grep -oP '^Socket.*:\s*\K.+') * ($(lscpu | grep -oP '^Core.*:\s*\K.+') * $(lscpu | grep -oP '^Thread.*:\s*\K.+')) ))
if [ ${HOST_CPU_CORES} -gt 4 ]; then 
  CT_CPU_CORES_VAR=$(( ${HOST_CPU_CORES} / 2 ))
elif [ ${HOST_CPU_CORES} -le 4 ]; then
  CT_CPU_CORES_VAR=2
fi

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=1

# Developer enable git mounts inside CT  (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=1

#---- Repo variables
# Git server
GIT_SERVER='https://github.com'
# Git user
GIT_USER='ahuacate'
# Git repository
GIT_REPO='pve-medialab'
# Git branch
GIT_BRANCH='master'
# Git common
GIT_COMMON='0'

#---- Other Variables --------------------------------------------------------------

# Container Hostname
CT_HOSTNAME_VAR='jellyfin'
# Container IP Address (192.168.50.111)
CT_IP_VAR='192.168.50.111'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.50.5'
# Container DNS Server
CT_DNS_SERVER_VAR='192.168.50.5'
# Container Number
CTID_VAR='111'
# Container VLAN
CT_TAG_VAR='50'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='10'
# Container allocated RAM
CT_RAM_VAR='2048'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Jellyfin'
#---- Do Not Edit
# Container Swap
CT_SWAP="$(( $CT_RAM_VAR / 2 ))"
# CT CPU Cores
CT_CPU_CORES="$CT_CPU_CORES_VAR"
# CT unprivileged status
CT_UNPRIVILEGED='1'
# Features (0 means none)
CT_FUSE='0'
CT_KEYCTL='0'
CT_MOUNT='0'
CT_NESTING='0'
# Startup Order
CT_STARTUP='2'
# Container Root Password ( 0 means none )
CT_PASSWORD='0'
# PVE Container OS (Not supported on 21.04)
OSTYPE='ubuntu'
OSVERSION='22.04'

# CT SSH Port
SSH_PORT_VAR='22' # Best not use default port 22

# App default UID/GUID
APP_USERNAME='media'
APP_GRPNAME='medialab'


#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for CT
cat << 'EOF' > pvesm_required_list
audio|Audiobooks and podcasts
backup|CT settings backup storage
books|Ebooks and Magazines
music|Music, Albums and Songs
photo|Photographic image collection
transcode|Video transcoding disk or folder
video|All video libraries (i.e movies, series, homevideos)
EOF

#---- Body -------------------------------------------------------------------------

#---- Introduction
source ${COMMON_PVE_SOURCE}/pvesource_ct_intro.sh

#---- Setup PVE CT Variables
source ${COMMON_PVE_SOURCE}/pvesource_ct_setvmvars.sh

#---- Create OS CT
source ${COMMON_PVE_SOURCE}/pvesource_ct_createvm.sh

#---- Pre-Configuring PVE CT
section "Pre-Configure ${OSTYPE^} CT"

# MediaLab CT unprivileged mapping
if [ $CT_UNPRIVILEGED = 1 ]; then
  source ${COMMON_PVE_SOURCE}/pvesource_ct_medialab_ctidmapping.sh
fi

# Create CT Bind Mounts
source ${COMMON_PVE_SOURCE}/pvesource_ct_createbindmounts.sh

# VA-API Install & Setup for CT
source ${COMMON_PVE_SOURCE}/pvesource_ct_medialab_vaapipassthru.sh

#---- Configure New CT OS
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntubasics.sh

#---- Jellyfin ---------------------------------------------------------------------

section "Installing ${CT_HOSTNAME_VAR^} software."

msg "Prerequisite - Installing HTTPS transport for APT..."
pct exec $CTID -- apt-get install apt-transport-https -qqy >/dev/null

msg "Prerequisite - Importing the GPG signing key (signed by the Jellyfin Team)..."
# pct exec $CTID -- bash -c 'wget -qO - https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo tee /usr/share/keyrings/jellyfin_team-archive-keyring.gpg.key >/dev/null'
pct exec $CTID -- bash -c 'curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg'

msg "Prerequisite - Adding a Jellyfin repository list..."
pct exec $CTID -- bash -c 'echo "deb [arch=$( dpkg --print-architecture ) signed-by=/usr/share/keyrings/jellyfin_team-archive-keyring.gpg.key] https://repo.jellyfin.org/$(cat /etc/os-release | grep '^ID=.*' | sed 's/^ID=//') $(cat /etc/os-release | grep '^VERSION_CODENAME=.*' | sed 's/^VERSION_CODENAME=//') main" | sudo tee /etc/apt/sources.list.d/jellyfin.list >/dev/null'
# pct exec $CTID -- bash -c 'echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list'

msg "Prerequisite - Updating container OS (be patient, might take a while)..."
pct exec $CTID -- apt-get -qqy update >/dev/null

msg "Installing Jellyfin software..."
pct exec $CTID -- apt-get install -qqy jellyfin >/dev/null
if [ $(pct exec $CTID -- dpkg -s jellyfin >/dev/null 2>&1; echo $?) != 0 ]; then
  warn "Jellyfin installation status: ${RED}Fail${NC}
  Failed to install Jellyfin. User intervention required. Exiting installation script in 3 second."
  sleep 3
  exit 0
fi

#---- Fix Jellyfin UID and GID
msg_box "The default Jellyfin installation creates a new Linux User and Group: jellyfin:jellyfin (UID:GUID).
In order for Jellyfin SW to have read and write access to your NAS bind mount points we modify the jellyfin UID and GUID to match our default media:medialab (1605:65605)."

# Creating UID GID fix script
msg "Modifying username Jellyfin UID:GID to 1605:65605..."
cat << 'EOF' > uid_gid_fix.sh
#!/usr/bin/env bash
systemctl stop jellyfin >/dev/null
sleep 5
OLDUID=$(id -u jellyfin)
OLDGID=$(id -g jellyfin)
usermod -u 1605 jellyfin >/dev/null
groupmod -g 65605 jellyfin >/dev/null
usermod -s /bin/bash jellyfin >/dev/null
find / \( -path /mnt \) -prune -o -user "$OLDUID" -exec chown -h 1605 {} \; 2>/dev/null
find / \( -path /mnt \) -prune -o -group "$OLDGID" -exec chgrp -h 65605 {} \; 2>/dev/null
systemctl restart jellyfin >/dev/null
sleep 3
exit
EOF
pct push $CTID uid_gid_fix.sh /tmp/uid_gid_fix.sh -perms 755
pct exec $CTID -- bash -c "/tmp/uid_gid_fix.sh"
info "Jellyfin UID is set: ${YELLOW}$(pct exec $CTID -- id -u jellyfin)${NC}"
info "Jellyfin GUID is set: ${YELLOW}$(pct exec $CTID -- id -g jellyfin)${NC}"
echo

#---- Create App settings backup folder on NAS
pct exec $CTID -- runuser ${APP_USERNAME} -c "mkdir -p /mnt/backup/${CT_HOSTNAME_VAR}"

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "Success. ${CT_HOSTNAME_VAR^} installation has completed. Web-interface is available on:

  --  ${WHITE}http://$CT_IP:8096/${NC}\n
  --  ${WHITE}http://${CT_HOSTNAME}:8096/${NC}
  
More information about configuring ${CT_HOSTNAME_VAR^} is available here:

  --  ${WHITE}https://github.com/ahuacate/jellyfin${NC}"
echo

# Cleanup
trap cleanup EXIT