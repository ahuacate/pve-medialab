#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_lidarr.sh
# Description:  This script is for creating a Proxmox Lidarr CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_lidarr.sh)"

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
CT_HOSTNAME_VAR='lidarr'
# Container IP Address (192.168.50.117)
CT_IP_VAR='192.168.50.117'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.50.5'
# Container DNS Server
CT_DNS_SERVER_VAR='192.168.50.5'
# Container Number
CTID_VAR='117'
# Container VLAN
CT_TAG_VAR='50'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='8'
# Container allocated RAM
CT_RAM_VAR='1024'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Lidarr'
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
music|Music, Albums and Songs
public|General public storage
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

#---- Lidarr -----------------------------------------------------------------------

section "Install ${CT_HOSTNAME_VAR^} software"

#---- Prerequisites
msg "Downloading prerequisites..."
pct exec $CTID -- apt-get install -y curl mediainfo sqlite3 libchromaprint-tools > /dev/null

#---- Installing Lidarr
msg "Downloading Lidarr..."
pct exec $CTID -- wget --content-disposition 'http://lidarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64' -P /tmp/
pct exec $CTID -- bash -c 'tar -zxf /tmp/Lidarr*.linux*.tar.gz -C /opt; rm /tmp/Lidarr*.linux*.tar.gz'

msg "Setting /opt/Lidarr folder permissions..."
pct exec $CTID -- bash -c 'chown -hR 1605:65605 /opt/Lidarr'

msg "Create lidarr.service system.d file..."
cat << 'EOF' > ${TEMP_DIR}/lidarr.service
[Unit]
Description=Lidarr Daemon
After=syslog.target network.target

[Service]
User=media
Group=medialab
Type=simple

ExecStart=/opt/Lidarr/Lidarr -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID ${TEMP_DIR}/lidarr.service /etc/systemd/system/lidarr.service

msg "Enabling lidarr.service system.d file..."
pct exec $CTID -- systemctl enable lidarr.service > /dev/null

msg "Starting lidarr.service system.d file..."
pct exec $CTID -- systemctl start lidarr.service > /dev/null

if [ $(pct exec $CTID -- systemctl is-active --quiet lidarr.service; echo $?) != 0 ]; then
  warn "${CT_HOSTNAME_VAR^} installation status: ${RED}Fail${NC}
  Failed to install ${CT_HOSTNAME_VAR^}. User intervention required. Exiting installation script in 3 second."
  sleep 3
  exit 0
fi

#---- Fix Lidarr API key
msg "Modifying configuration settings..."
if [ $(pct exec $CTID -- systemctl is-active lidarr.service) == "active" ]; then
  pct exec $CTID -- systemctl stop lidarr.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active lidarr.service) != "active" ]; then
    break
  fi
  sleep 5
  done
fi
pct exec $CTID -- sed -i 's|<ApiKey>.*|<ApiKey>1a0b9fd2dc144ec28141440f72616c74</ApiKey>|g' /home/media/.config/Lidarr/config.xml
pct exec $CTID -- systemctl daemon-reload > /dev/null
pct exec $CTID -- systemctl restart lidarr.service > /dev/null
echo

#---- Copy App settings file to NAS
if [ -f ${DIR}/source/pve_medialab_ct_${CT_HOSTNAME_VAR}_settings/${CT_HOSTNAME_VAR}_backup_*_0000.00.00_00.00.00.zip ]; then
  pct exec $CTID -- runuser ${APP_USERNAME} -c "mkdir -p /mnt/backup/${CT_HOSTNAME_VAR}/manual"
  # Copy Radarr backup ahuacate base file to NAS
  BACKUP_FILE=$(find ${DIR}/source/pve_medialab_ct_${CT_HOSTNAME_VAR}_settings -name *_0000.00.00_00.00.00.zip -type f -exec basename {} 2> /dev/null \;)
  pct exec $CTID -- runuser ${APP_USERNAME} -c "mkdir -p /home/media/.config/Lidarr/Backups/manual"
  pct push $CTID ${DIR}/source/pve_medialab_ct_${CT_HOSTNAME_VAR}_settings/${BACKUP_FILE} /home/media/.config/Lidarr/Backups/manual/${BACKUP_FILE}
fi

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "Success. ${CT_HOSTNAME_VAR^} installation has finished. The first start-up of ${CT_HOSTNAME_VAR^} may take a few seconds to be ready so be patient. Web-interface is available on:

  --  ${WHITE}http://${CT_IP}:8686${NC}\n
  --  ${WHITE}http://${CT_HOSTNAME}:8686${NC}\n"

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