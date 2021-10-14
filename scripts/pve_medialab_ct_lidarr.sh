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
cat << 'EOF' > $TEMP_DIR/lidarr.service
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
pct push $CTID $TEMP_DIR/lidarr.service /etc/systemd/system/lidarr.service

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
echo

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "Success. ${CT_HOSTNAME_VAR^} installation has finished. The first start-up of ${CT_HOSTNAME_VAR^} may take a few seconds to be ready so be patient. Web-interface is available on:

  --  ${WHITE}http://$CT_IP:8686${NC}\n
  --  ${WHITE}http://${CT_HOSTNAME}:8686${NC}
  
For configuring ${CT_HOSTNAME_VAR^} we have instructions:

  --  ${WHITE}https://github.com/ahuacate/lidarr${NC}"
echo

# Cleanup
trap cleanup EXIT