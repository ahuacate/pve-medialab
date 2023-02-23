#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_deluge.sh
# Description:  This script is for creating a Deluge CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_deluge.sh)"

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

#---- Other Variables --------------------------------------------------------------

# Container Hostname
CT_HOSTNAME_VAR='deluge'
# Container IP Address (192.168.30.113)
CT_IP_VAR='192.168.30.113'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.30.5'
# DNS Server
CT_DNS_SERVER_VAR='192.168.30.5'
# Container Number
CTID_VAR='113'
# Container VLAN
CT_TAG_VAR='30'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='8'
# Container allocated RAM
CT_RAM_VAR='1024'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Deluge'
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

#---- Deluge -----------------------------------------------------------------------

section "Install ${CT_HOSTNAME_VAR^} software"

#---- Prerequisites
msg "Installing software-properties-common..."
pct exec $CTID -- apt-get install software-properties-common -y > /dev/null

#---- Installing Deluge
msg "Installing ${CT_HOSTNAME_VAR^} software (be patient, might take a while)..."
pct exec $CTID -- apt-get install -y deluged deluge-web deluge-console > /dev/null

msg "Create system.d file..."
cat << 'EOF' > $TEMP_DIR/deluged.service
[Unit]
Description=Deluge Bittorrent Client Daemon
After=network-online.target

[Service]
Type=simple
User=media
Group=medialab
UMask=007
ExecStart=/usr/bin/deluged -d
KillMode=process
Restart=on-failure
# Configures the time to wait before service is stopped forcefully.
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID $TEMP_DIR/deluged.service /etc/systemd/system/deluged.service

cat << 'EOF' > $TEMP_DIR/deluge-web.service
[Unit]
Description=Deluge Bittorrent Client Web Interface
After=network-online.target
Wants=deluged.service

[Service]
Type=simple
User=media
Group=medialab
UMask=027
ExecStart=/usr/bin/deluge-web -d
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID $TEMP_DIR/deluge-web.service /etc/systemd/system/deluge-web.service

msg "Enabling system.d file(s)..."
pct exec $CTID -- systemctl enable deluged.service > /dev/null
pct exec $CTID -- systemctl enable deluge-web.service > /dev/null

msg "Starting system.d file(s)..."
pct exec $CTID -- systemctl restart deluged.service > /dev/null
pct exec $CTID -- systemctl restart deluge-web.service > /dev/null

# Waiting for services to start
while true; do
  if [ $(pct exec $CTID -- systemctl is-active deluged.service) = "active" ]; then
    break
  fi
  sleep 1
done
while true; do
  if [ $(pct exec $CTID -- systemctl is-active deluge-web.service) = "active" ]; then
    break
  fi
  sleep 1
done


if [ $(pct exec $CTID -- systemctl is-active --quiet deluged.service; echo $?) != 0 ]; then
  warn "${CT_HOSTNAME_VAR^} installation status: ${RED}Fail${NC}
  Failed to install ${CT_HOSTNAME_VAR^}. User intervention required. Exiting installation script in 3 second."
  sleep 5
  exit 0
fi
if [ $(pct exec $CTID -- systemctl is-active --quiet deluge-web.service; echo $?) != 0 ]; then
  warn "${CT_HOSTNAME_VAR^} installation status: ${RED}Fail${NC}
  Failed to install ${CT_HOSTNAME_VAR^}. User intervention required. Exiting installation script in 3 second."
  sleep 5
  exit 0
fi
echo


#---- Apply Deluge settings
section "Apply ${CT_HOSTNAME_VAR^} Easy Script application settings"
if [ $ES_AUTO = 0 ]; then
  msg "Applying ${CT_HOSTNAME_VAR^} Easy Script application settings..."
  source ${DIR}/source/pve_medialab_ct_deluge_settings/pve_medialab_ct_deluge_settings.sh
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
        source ${DIR}/source/pve_medialab_ct_deluge_settings/pve_medialab_ct_deluge_settings.sh
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

  --  ${WHITE}http://$CT_IP:8112${NC} (password:deluge)\n
  --  ${WHITE}http://${CT_HOSTNAME}:8112${NC}
  
For configuring ${CT_HOSTNAME_VAR^} we have instructions:

  --  ${WHITE}https://github.com/ahuacate/deluge${NC}"
echo

# Cleanup
trap cleanup EXIT