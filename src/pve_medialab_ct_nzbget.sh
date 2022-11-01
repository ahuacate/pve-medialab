#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_nzbget.sh
# Description:  This script is for creating a Proxmox NZBGet CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_nzbget.sh)"

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
if [ $HOST_CPU_CORES -gt 4 ]; then 
  CT_CPU_CORES_VAR=$(( $HOST_CPU_CORES / 2 ))
elif [ $HOST_CPU_CORES -le 4 ]; then
  CT_CPU_CORES_VAR=2
fi

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=1

# Developer enable git mounts inside CT  (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=1

#---- Other Variables --------------------------------------------------------------

# Container Hostname
CT_HOSTNAME_VAR='nzbget'
# Container IP Address (192.168.30.112)
CT_IP_VAR='192.168.30.112'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.30.5'
# Container DNS Server
CT_DNS_SERVER_VAR='192.168.30.5'
# Container Number
CTID_VAR='112'
# Container VLAN
CT_TAG_VAR='30'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='8'
# Container allocated RAM
CT_RAM_VAR='1024'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab NZBGet'
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
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_addmedialabuser-nohomedir.sh

#---- NZBGet -----------------------------------------------------------------------

section "Install ${CT_HOSTNAME_VAR^} software"

#---- Prerequisites

#---- Installing NZBGet
msg "Downloading latest ${CT_HOSTNAME_VAR^} software version..."
pct exec $CTID -- bash -c 'cd /opt; curl -L -O --progress-bar https://nzbget.net/download/nzbget-latest-bin-linux.run'

msg "Installing ${CT_HOSTNAME_VAR^}..."
pct exec $CTID -- bash -c 'cd /opt; sh nzbget-latest-bin-linux.run > /dev/null'
pct exec $CTID -- chown -R 1605:65605 /opt/nzbget > /dev/null

msg "Creating nzbget.service system.d file..."
cat << 'EOF' > $TEMP_DIR/nzbget.service
[Unit]
Description=NZBGet Daemon
Documentation=http://nzbget.net/Documentation
After=network.target

[Service]
User=media
Group=medialab
ExecStart=/opt/nzbget/nzbget -D
ExecStop=/opt/nzbget/nzbget -Q
ExecReload=/opt/nzbget/nzbget -O
Type=forking
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID $TEMP_DIR/nzbget.service /etc/systemd/system/nzbget.service

msg "Enabling nzbget service system.d file..."
pct exec $CTID -- systemctl enable nzbget.service > /dev/null

msg "Starting nzbget.service system.d file..."
pct exec $CTID -- systemctl start nzbget.service > /dev/null

if [ $(pct exec $CTID -- systemctl is-active --quiet nzbget.service; echo $?) != 0 ]; then
  warn "${CT_HOSTNAME_VAR^} installation status: ${RED}Fail${NC}
  Failed to install ${CT_HOSTNAME_VAR^}. User intervention required. Exiting installation script in 3 second."
  sleep 3
  exit 0
fi
echo

#---- Apply NZBGet settings
section "Apply ${CT_HOSTNAME_VAR^} Easy Script application settings"
if [ $ES_AUTO = 0 ]; then
  msg "Applying ${CT_HOSTNAME_VAR^} Easy Script application settings..."
  pct exec $CTID -- systemctl stop nzbget.service > /dev/null
  sleep 2
  source ${DIR}/source/pve_medialab_ct_nzbget_settings/pve_medialab_ct_nzbget_settings.sh
  pct exec $CTID -- systemctl start nzbget.service > /dev/null
  echo
elif [ $(pct exec $CTID -- bash -c '[ -d "/mnt/downloads" ]'; echo $?) = 0 ]; then
  msg_box "#### PLEASE READ CAREFULLY ####\n
  You have the option to configure ${CT_HOSTNAME_VAR^} with our Easy Script application settings. Your ${CT_HOSTNAME_VAR^} software will then be fully configured to work with our suite of PVE Medialab CT's and applications."
  sleep 2
  echo
  while true; do
    read -p "Proceed to apply our ${CT_HOSTNAME_VAR^} application settings (Recommended) [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        msg "Applying ${CT_HOSTNAME_VAR^} Easy Script application settings..."
        pct exec $CTID -- systemctl stop nzbget.service > /dev/null
        sleep 2
        source ${DIR}/source/pve_medialab_ct_nzbget_settings/pve_medialab_ct_nzbget_settings.sh
        pct exec $CTID -- systemctl start nzbget.service > /dev/null
        echo
        break
        ;;
      [Nn]*)
        info "You have chosen to skip this step. Your ${CT_HOSTNAME_VAR^} application settings are software defaults."
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
fi

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "Success. ${CT_HOSTNAME_VAR^} installed into /opt/${CT_HOSTNAME_VAR}. Web-interface is available on:

  --  ${WHITE}http://$CT_IP:6789${NC}
      ( login: nzbget and password: tegbzn6789 )\n
  --  ${WHITE}http://${CT_HOSTNAME}:6789${NC}
  
More information about configuring ${CT_HOSTNAME_VAR^} is available here:

  --  ${WHITE}https://github.com/ahuacate/nzbget${NC}"
echo

# Cleanup
trap cleanup EXIT