#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_jackett.sh
# Description:  This script is for creating a Jackett CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_jackett.sh)"

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

# CT SSH Port
SSH_PORT_VAR='22'

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=0

# Developer enable git mounts inside CT (0 is enabled, 1 is disabled)
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
CT_HOSTNAME_VAR='jackett'
# Container IP Address (192.168.50.120)
CT_IP_VAR='192.168.50.120'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.50.5'
# DNS Server
CT_DNS_SERVER_VAR='192.168.50.5'
# Container Number
CTID_VAR='120'
# Container VLAN
CT_TAG_VAR='50'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='2'
# Container allocated RAM
CT_RAM_VAR='512'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Jackett'
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

# #---- Configure New CT OS
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntubasics.sh

# #---- Create MediaLab Group and User
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_addmedialabuser.sh

#---- Jackett ----------------------------------------------------------------------

section "Install ${CT_HOSTNAME_VAR^} software"

#---- Prerequisites
msg "Downloading Jackett..."
pct exec $CTID -- wget --content-disposition $( curl -s https://api.github.com/repos/Jackett/Jackett/releases | grep Jackett.Binaries.LinuxAMDx64.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) -P /tmp/
pct exec $CTID -- bash -c 'tar -zxf /tmp/Jackett.Binaries.LinuxAMDx64.tar.gz -C /opt; rm /tmp/Jackett.Binaries.LinuxAMDx64.tar.gz'

msg "Setting /opt/Jackett folder permissions..."
pct exec $CTID -- bash -c 'chown -hR 1605:65605 /opt/Jackett'

#---- Installing Jackett
msg "Setting Jackett system.d user..."
pct exec $CTID -- sed -i 's/^User=${JACKETT_USER}/User=media/g' /opt/Jackett/install_service_systemd.sh
pct exec $CTID -- sed -i 's/^Group=${JACKETT_USER}/Group=medialab/g' /opt/Jackett/install_service_systemd.sh

msg "Installing Jackett"
pct exec $CTID -- bash -c '/opt/Jackett/install_service_systemd.sh'

if [ $(pct exec $CTID -- systemctl is-active --quiet jackett.service; echo $?) != 0 ]; then
  warn "${CT_HOSTNAME_VAR^} installation status: ${RED}Fail${NC}
  Failed to install ${CT_HOSTNAME_VAR^}. User intervention required. Exiting installation script in 3 second."
  sleep 3
  exit 0
fi
echo

#---- Apply Jackett settings
section "Apply ${CT_HOSTNAME_VAR^} Easy Script application settings"
if [ $ES_AUTO = 0 ]; then
  msg "Applying ${CT_HOSTNAME_VAR^} Easy Script application settings..."
  source ${DIR}/source/pve_medialab_ct_jackett_settings/pve_medialab_ct_jackett_settings.sh
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
        source ${DIR}/source/pve_medialab_ct_jackett_settings/pve_medialab_ct_jackett_settings.sh
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

  --  ${WHITE}http://$CT_IP:9117${NC} (password: not set)\n
  --  ${WHITE}http://${CT_HOSTNAME}:9117${NC}
  
Simply add your torrent indexers."
echo

# Cleanup
trap cleanup EXIT