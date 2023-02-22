#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_flexget.sh
# Description:  This script is for creating a Proxmox Flexget CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_flexget.sh)"

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
CT_HOSTNAME_VAR='flexget'
# Container IP Address (192.168.30.114)
CT_IP_VAR='192.168.1.120'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.1.5'
# Container DNS Server
CT_DNS_SERVER_VAR='192.168.1.5'
# Container Number
CTID_VAR='114'
# Container VLAN
CT_TAG_VAR='0'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='8'
# Container allocated RAM
CT_RAM_VAR='1024'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Flexget'
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
audio|Audiobooks and podcasts
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


#---- Flexget ----------------------------------------------------------------------

section "Install ${CT_HOSTNAME_VAR^} software"

#---- Prerequisites
msg "Creating Flexget working folder & permissions..."
pct exec $CTID -- mkdir -m 775 -p /home/media/flexget
pct exec $CTID -- chown -hR 1605:65605 /home/media/flexget
pct push $CTID ${DIR}/source/pve_medialab_ct_flexget_settings/config.yml.sample /home/media/flexget/config.yml --group 65605 --user 1605

msg "Downloading prerequisites (be patient, might take a while)..."
pct exec $CTID -- apt-get install python3.8-venv -y > /dev/null
pct exec $CTID -- python3 -m venv ~/flexget/

#---- Installing Flexget
msg "Installing ${CT_HOSTNAME_VAR^} software (be patient, might take a while)..."
pct exec $CTID -- bash -c 'cd ~/flexget/; bin/pip install flexget'
pct exec $CTID -- bash -c 'source ~/flexget/bin/activate'

#---- Apply Flexget settings
section "Apply ${CT_HOSTNAME_VAR^} Easy Script application settings"
if [ $ES_AUTO = 0 ]; then
  msg "Applying ${CT_HOSTNAME_VAR^} Easy Script application settings..."
  source ${DIR}/source/pve_medialab_ct_flexget_settings/pve_medialab_ct_flexget_settings.sh
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
        source ${DIR}/source/pve_medialab_ct_flexget_settings/pve_medialab_ct_flexget_settings.sh
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

msg "Success. ${CT_HOSTNAME_VAR^} installation has finished. The first start-up of ${CT_HOSTNAME_VAR^} may take a few seconds to be ready so be patient. Web-interface is available on:

  --  ${WHITE}http://$CT_IP:8686${NC}\n
  --  ${WHITE}http://${CT_HOSTNAME}:8686${NC}
  
For configuring ${CT_HOSTNAME_VAR^} we have instructions:

  --  ${WHITE}https://github.com/ahuacate/lidarr${NC}"
echo

# Cleanup
trap cleanup EXIT