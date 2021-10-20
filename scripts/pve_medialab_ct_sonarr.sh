#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_sonarr.sh
# Description:  This script is for creating a Proxmox Sonarr CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_sonarr.sh)"

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

#---- Other Variables --------------------------------------------------------------

# Container Hostname
CT_HOSTNAME_VAR='sonarr'
# Container IP Address (192.168.50.115)
CT_IP_VAR='192.168.50.115'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.50.5'
# Container DNS Server
CT_DNS_SERVER_VAR='192.168.50.5'
# Container Number
CTID_VAR='115'
# Container VLAN
CT_TAG_VAR='50'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='8'
# Container allocated RAM
CT_RAM_VAR='1024'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Sonarr'
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
# PVE Container OS
OSTYPE='ubuntu'
OSVERSION='21.04'

# App default UID/GUID
APP_USERNAME='media'
APP_GRPNAME='medialab'

#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for CT
cat << 'EOF' > pvesm_required_list
backup|CT settings backup storage
downloads|General downloads storage
public|General public storage
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

#---- Configure New CT OS
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntubasics.sh

#---- Create MediaLab Group and User
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_addmedialabuser.sh

#---- Sonarr -----------------------------------------------------------------------

section "Install ${CT_HOSTNAME_VAR^} software"

#---- Installing mono
msg "Prerequisite - Adding mono key..."
pct exec $CTID -- bash -c 'gpg --no-default-keyring --keyring /usr/share/keyrings/mono_official-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &> /dev/null'

msg "Prerequisite - Adding mono repository list..."
pct exec $CTID -- bash -c 'echo "deb [arch=$( dpkg --print-architecture ) signed-by=/usr/share/keyrings/mono_official-archive-keyring.gpg] https://download.mono-project.com/repo/ubuntu stable-focal main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list > /dev/null'

msg "Prerequisite - Updating container OS (be patient, might take a while)..."
pct exec $CTID -- apt-get -qqy update > /dev/null

msg "Prerequisite - Installing mono (be patient, might take a few minutes)..."
pct exec $CTID -- apt-get install -qqy mono-devel
if [ $(pct exec $CTID -- dpkg -s mono-devel > /dev/null 2>&1; echo $?) != 0 ]; then
  warn "Mono installation status: ${RED}Fail${NC}
  Failed to install Mono. User intervention required. Exiting installation script in 3 second."
  sleep 3
  exit 0
fi

#---- Installing Sonarr
msg "Prerequisite - Adding Sonarr key..."
pct exec $CTID -- bash -c 'gpg --no-default-keyring --keyring /usr/share/keyrings/sonarr-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8 &> /dev/null'

msg "Prerequisite - Adding mono repository list..."
pct exec $CTID -- bash -c 'echo "deb [arch=$( dpkg --print-architecture ) signed-by=/usr/share/keyrings/sonarr-archive-keyring.gpg] https://apt.sonarr.tv/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list > /dev/null'

msg "Prerequisite - Updating container OS (be patient, might take a while)..."
pct exec $CTID -- apt-get -qqy update > /dev/null

msg "Installing Sonarr software..."
pct exec $CTID -- bash -c 'echo "sonarr sonarr/owning_user  string media" | debconf-set-selections'
pct exec $CTID -- bash -c 'echo "sonarr sonarr/owning_group string medialab" | debconf-set-selections'
pct exec $CTID -- bash -c 'DEBIAN_FRONTEND=non-interactive apt-get install -yqq sonarr'

if [ $(pct exec $CTID -- dpkg -s sonarr > /dev/null 2>&1; echo $?) != 0 ]; then
  warn "Sonarr installation status: ${RED}Fail${NC}
  Failed to install Mono. User intervention required. Exiting installation script in 3 second."
  sleep 3
  exit 0
fi

#---- Fix Sonarr UID and GUID & API key
msg "Modifying configuration settings..."
if [ $(pct exec $CTID -- systemctl is-active sonarr.service) == "active" ]; then
  pct exec $CTID -- systemctl stop sonarr.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active sonarr.service) != "active" ]; then
    break
  fi
  sleep 5
  done
fi
pct exec $CTID -- sed -i 's|<ApiKey>.*|<ApiKey>1a0b9fd2dc144ec28141440f72616c74</ApiKey>|g' /var/lib/sonarr/config.xml
pct exec $CTID -- systemctl daemon-reload > /dev/null
pct exec $CTID -- systemctl restart sonarr.service > /dev/null
echo

#---- Copy App settings file to NAS
if [ -f ${DIR}/source/pve_medialab_ct_${CT_HOSTNAME_VAR}_settings/${CT_HOSTNAME_VAR}_backup_*_0000.00.00_00.00.00.zip ]; then
  pct exec $CTID -- runuser ${APP_USERNAME} -c "mkdir -p /mnt/backup/${CT_HOSTNAME_VAR}/manual"
  # Copy Sonarr backup ahuacate base file to NAS
  BACKUP_FILE=$(find ${DIR}/source/pve_medialab_ct_${CT_HOSTNAME_VAR}_settings -name *_0000.00.00_00.00.00.zip -type f -exec basename {} 2> /dev/null \;)
  pct exec $CTID -- runuser ${APP_USERNAME} -c "mkdir -p /var/lib/sonarr/Backups/manual"
  pct push $CTID ${DIR}/source/pve_medialab_ct_${CT_HOSTNAME_VAR}_settings/${BACKUP_FILE} /var/lib/sonarr/Backups/manual/${BACKUP_FILE}
fi

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "Success. ${CT_HOSTNAME_VAR^} installation has finished. The first start-up may take a few seconds so be patient. Web-interface is available on:

  --  ${WHITE}http://$CT_IP:8989${NC}\n
  --  ${WHITE}http://${CT_HOSTNAME}:8989${NC}\n"

if [ -f ${DIR}/source/pve_medialab_ct_${CT_HOSTNAME_VAR}_settings/${CT_HOSTNAME_VAR}_backup_*_0000.00.00_00.00.00.zip ]; then
msg "An out-of-the-box ${CT_HOSTNAME_VAR^} setting preset file is included. Go to ${CT_HOSTNAME_VAR^} WebGUI 'System' > 'Backup' and restore the backup filename:

  --  ${WHITE}${BACKUP_FILE}${NC}

The file includes:

  --  Media Management, Root folders
  --  Profiles tuned ( 4K tuning, codecs, subs )
  --  Indexers sets: Jackett
  --  Download Client sets: Default Deluge and NZBGet
  --  Tags for 'hevc_only' and 'subs_eng'
  --  API key set ( so all Ahuacate medialab CTs can communicate )
  --  Backup set: /mnt/backup/sonarr ( all backups stored on NAS )

We recommend you install our presets because it saves time. Check the server IP addresses of your Download Clients and Indexers, and configure any Usenet Indexers.\n"
fi

# Cleanup
trap cleanup EXIT