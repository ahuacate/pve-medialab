#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT
function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  [ ! -z ${CTID-} ] && cleanup_failed
  exit $EXIT
}
function warn() {
  local REASON="\e[97m$1\e[39m"
  local FLAG="\e[93m[WARNING]\e[39m"
  msg "$FLAG $REASON"
}
function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg "$FLAG $REASON"
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function section() {
  local REASON="  \e[97m$1\e[37m"
  printf -- '-%.0s' {1..100}; echo ""
  msg "$REASON"
  printf -- '-%.0s' {1..100}; echo ""
  echo
}
function cleanup_failed() {
  if [ ! -z ${MOUNT+x} ]; then
    pct unmount $CTID
  fi
  if $(pct status $CTID &>/dev/null); then
    if [ "$(pct status $CTID | awk '{print $2}')" == "running" ]; then
      pct stop $CTID
    fi
    pct destroy $CTID
  elif [ "$(pvesm list $STORAGE --vmid $CTID)" != "" ]; then
    pvesm free $ROOTFS
  fi
}
function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}
function load_module() {
  if ! $(lsmod | grep -Fq $1); then
    modprobe $1 &>/dev/null || \
      die "Failed to load '$1' module."
  fi
  MODULES_PATH=/etc/modules
  if ! $(grep -Fxq "$1" $MODULES_PATH); then
    echo "$1" >> $MODULES_PATH || \
      die "Failed to add '$1' module to load at boot."
  fi
}
function box_out() {
  set +u
  local s=("$@") b w
  for l in "${s[@]}"; do
	((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  tput setaf 3
  echo " -${b//?/-}-
| ${b//?/ } |"
  for l in "${s[@]}"; do
	printf '| %s%*s%s |\n' "$(tput setaf 7)" "-$w" "$l" "$(tput setaf 3)"
  done
  echo "| ${b//?/ } |
 -${b//?/-}-"
  tput sgr 0
  set -u
}


# Colour
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'

# Detect modules and automatically load at boot
load_module aufs
load_module overlay

# Set Temp Folder
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null


# Download external scripts
# wget -qL https://raw.githubusercontent.com/ahuacate/proxmox-lxc-media/master/scripts/jellyfin_setup_ct_18.04.sh
#chmod +x fileserver_setup_ct_18.04.sh

#########################################################################################
# This script is for creating your Proxmox Jellyfin CT - Ubuntu 18.04	      	          #
#                                                                 						          #
# Tested on Proxmox Version : pve-manager/6.1-3/37248ce6 (running kernel: 5.3.10-1-pve) #
#########################################################################################

# Command to run script
#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-lxc-media/master/scripts/jellyfin_create_ct_18.04.sh)"



# Introduction
clear
echo
box_out '#### PLEASE READ CAREFULLY ####' '' 'This script will create a Proxmox Jellyfin CT.' 'User input is required. The script may create, edit and/or change system' 'files on your Proxmox host. When an optional default setting is provided' 'you may accept the default by pressing ENTER on your keyboard or' 'change it to your preferred value.' '' 'Jellyfin CT will access your media library by accessing your Proxmox hosts' 'NFS mount points. The following prerequisites and credentials are required' 'before proceeding:' '' '      PREREQUISITE - PROXMOX HOST NFS MOUNTPOINT' '  --  "hostname"-audio (i.e cyclone-01-audio)' '  --  "hostname"-books (i.e cyclone-01-books)' '  --  "hostname"-music (i.e cyclone-01-music)' '  --  "hostname"-photo (i.e cyclone-01-photo)' '  --  "hostname"-public (i.e cyclone-01-public)' '  --  "hostname"-transcode (i.e cyclone-01-transcode)' '  --  "hostname"-video (i.e cyclone-01-video)' '' '      CREDENTIALS' '  --  IPv4 address for your new Jellyfin server.'
echo
sleep 5


# Select storage location
STORAGE_LIST=( $(pvesm status -content rootdir | awk 'NR>1 {print $1}') )
if [ ${#STORAGE_LIST[@]} -eq 0 ]; then
  warn "'Container' needs to be selected for at least one storage location."
  die "Unable to detect valid storage location."
elif [ ${#STORAGE_LIST[@]} -eq 1 ]; then
  STORAGE=${STORAGE_LIST[0]}
else
  msg "\n\nMore than one storage locations detected.\n"
  PS3=$'\n'"Which storage location would you like to use (Recommend local-zfs) ? "
  select s in "${STORAGE_LIST[@]}"; do
    if [[ " ${STORAGE_LIST[@]} " =~ " ${s} " ]]; then
      STORAGE=$s
      break
    fi
    echo -en "\e[1A\e[K\e[1A"
  done
fi
info "Using '$STORAGE' for storage location."
clear
echo


# Message about setting variables
section "Setting Jellyfin Variables"
msg "We need to set some variables. Variables are used to create and setup\nyour Proxmox File Server container. The next steps requires your input.\n\nYou can accept our default values by pressing ENTER on your keyboard.\nOr overwrite the default value by typing in your own value and\npress ENTER to accept/continue."
echo
echo


# Set Fileserver CT CT_HOSTNAME
read -p "Enter CT Hostname: " -e -i jellyfin CT_HOSTNAME
CT_HOSTNAME=${CT_HOSTNAME,,}
info "CT hostname is set: ${YELLOW}$CT_HOSTNAME${NC}."
echo

# Set Fileserver CT IPv4 Address
while true; do
msg "Our default network setup hosts all media devices on VLAN 50. Using our\ndefaults settings will ensure all media apps and network permissions work out\nof the box. If you do NOT have a VLAN aware network use for example:\n  --  192.168.${WHITE}1${NC}.111/24."
# read -p "Enter CT IPv4 address: " -e -i 192.168.50.111/24 CT_IP
read -p "Enter CT IPv4 address: " -e -i 192.168.1.201/24 CT_IP
if [ $(expr "$CT_IP" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\/[0-9][0-9]*$' >/dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 "$(echo "$CT_IP" | sed  's/\/.*//g')" > /dev/null; echo $?) != 0 ]; then
info "The CT IP address is set: ${YELLOW}$CT_IP${NC}."
echo
break
elif [ $(expr "$CT_IP" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\/[0-9][0-9]*$' >/dev/null; echo $?) != 0 ]; then
warn "There are problems with your input:
1.  Your IP address is incorrectly formatted. It must be in the IPv4 format
including a subnet mask (i.e xxx.xxx.xxx.xxx/24 ).
Try again..."
echo
elif [ $(expr "$CT_IP" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\/[0-9][0-9]*$' >/dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 "$(echo "$CT_IP" | sed  's/\/.*//g')" > /dev/null; echo $?) == 0 ]; then
warn "There are problems with your input:
1. Your IP address meets the IPv4 standard, BUT
2. Your IP address $(echo "$CT_IP" | sed  's/\/.*//g') is all ready in-use on your LAN.
Try again..."
echo
fi
done

# Set container VLAN CT_TAG
read -p "Is your network VLAN aware [yes/no]?: " -r
if [[ "$REPLY" == "y" || "$REPLY" == "Y" || "$REPLY" == "yes" || "$REPLY" == "Yes" ]]; then
  if [ $(echo "$(echo "$CT_IP" | sed  's/\/.*//g')" | awk -F"." '{print $3}') -gt 1 ];then
    msg "Hint: "${CT_HOSTNAME^}" IPv4 address is $(echo "$CT_IP" | sed  's/\/.*//g') so your VLAN tag is $(echo "$(echo "$CT_IP" | sed  's/\/.*//g')" | awk -F"." '{print $3}')."
    read -p "Enter the CT network VLAN tag: " -e -i $(echo "$(echo "$CT_IP" | sed  's/\/.*//g')" | awk -F"." '{print $3}') CT_TAG
    info "The CT VLAN is set: ${YELLOW}$CT_TAG${NC}."
  else
    CT_TAG=1
    info "The CT VLAN is set: ${YELLOW}disabled${NC}."
  fi
else
  CT_TAG=1
  info "The CT VLAN is set: ${YELLOW}disabled${NC}."
fi
echo

# Set container Gateway IPv4 Address
msg "Hint: "${CT_HOSTNAME^}" IPv4 address is $(echo "$CT_IP" | sed  's/\/.*//g') so your Gateway should be $(ip route show | grep default | awk '{print $3}')."
read -p "Enter a Gateway IPv4 address: " -e -i $(ip route show | grep default | awk '{print $3}') CT_GW
info "The CT Gateway is set: ${YELLOW}$CT_GW${NC}."
echo

# Set container ID
pct list > pct_list
CTID_IP="$(echo "$CT_IP" | sed  's/\/.*//g' | awk -F"." '{print $4}')"
if [ $CTID_IP -lt 100 ]; then
  CTID_TEMP=$(( $CTID_IP + 100 ))
elif [ $CTID_IP -gt 100 ]; then
  CTID_TEMP=$CTID_IP
fi
msg "Attempting to set and match your Jellyfin CT ID with the host section
value of your CT IP address: $(echo "$CT_IP" | sed  's/\/.*//g' | awk -F "." '{print $1, $2, $3, "\033[1;33m"$4"\033[0m"}' | sed 's/ /./g').
Attempting to set "${CT_HOSTNAME^}" CT ID as: ${YELLOW}$CTID_TEMP${NC}.
If CT ID ${YELLOW}$CTID_TEMP${NC} is unavailable a indexed or random CT ID will be assigned."
sleep 2
if [ $CTID_IP -lt 100 ] && [ "$(cat pct_list | grep -w $(( $CTID_IP + 100 )) > /dev/null; echo $?)" != 0 ]; then
  CTID=$(( $CTID_IP + 100 ))
  info "The CT ID is set: ${YELLOW}$CTID${NC}."
elif [ $CTID_IP -gt 100 ] && [ "$(cat pct_list | grep -w $CTID_IP > /dev/null; echo $?)" != 0 ]; then
  CTID=$CTID_IP
  info "The CT ID is set: ${YELLOW}$CTID${NC}."
elif [ "$(cat pct_list | grep -w $(( $CTID_IP + 100 )) > /dev/null; echo $?)" != 0 ] || [ "$(cat pct_list | grep -w $CTID_IP > /dev/null; echo $?)" != 0 ]; then
  echo
  read -p "CT ID ${YELLOW}$CTID_TEMP${NC} is NOT available.
Generating a valid CT ID (press ENTER to accept or type change): " -e -i $(pvesh get /cluster/nextid) CTID
  info "The CT ID is set: ${YELLOW}$CTID${NC}."
fi
echo

# Set container Virtual Disk Size
read -p "Enter CT Virtual Disk Size (Gb): " -e -i 20 CT_DISK_SIZE
info "CT virtual disk is set: ${YELLOW}$CT_DISK_SIZE Gb${NC}."
echo

# Set container Memory
read -p "Enter amount of CT RAM Memory to be allocated (Gb): " -e -i 2048 CT_RAM
info "CT allocated memory is set: ${YELLOW}$CT_RAM Mb${NC}."
echo



#### Creating the Proxmox Container ####
section "Creating the Proxmox CT: ${CT_HOSTNAME^}"

# Download latest OS LXC template
msg "Updating Proxmox LXC template list..."
pveam update >/dev/null
msg "Downloading Proxmox LXC template..."
OSTYPE=ubuntu
OSVERSION=${OSTYPE}-18
mapfile -t TEMPLATES < <(pveam available -section system | sed -n "s/.*\($OSVERSION.*\)/\1/p" | sort -t - -k 2 -V)
TEMPLATE="${TEMPLATES[-1]}"
pveam download local $TEMPLATE >/dev/null ||
  die "A problem occurred while downloading the LXC template."
ARCH=$(dpkg --print-architecture)
TEMPLATE_STRING="local:vztmpl/${TEMPLATE}"


# Create LXC
msg "Creating LXC container..."
if [ $CT_TAG -gt 1 ]; then
  pct create $CTID $TEMPLATE_STRING --arch $ARCH --cores 2 --hostname $CT_HOSTNAME --cpulimit 1 --memory $CT_RAM --features nesting=1,mount=nfs4 \
    --net0 name=eth0,bridge=vmbr0,tag=$CT_TAG,firewall=1,gw=$CT_GW,ip=$CT_IP,type=veth \
    --ostype $OSTYPE --rootfs $STORAGE:$CT_DISK_SIZE,acl=1 --swap 256 --unprivileged 0 --onboot 1 --startup order=1 >/dev/null
elif [ $CT_TAG == 1 ]; then
  pct create $CTID $TEMPLATE_STRING --arch $ARCH --cores 1 --hostname $CT_HOSTNAME --cpulimit 1 --memory $CT_RAM --features nesting=1,mount=nfs4 \
    --net0 name=eth0,bridge=vmbr0,firewall=1,gw=$CT_GW,ip=$CT_IP,type=veth \
    --ostype $OSTYPE --rootfs $STORAGE:$CT_DISK_SIZE,acl=1 --swap 256 --unprivileged 0 --onboot 1 --startup order=1 >/dev/null
fi
echo


#### Checking media access availability ####
section "Create ${CT_HOSTNAME^} CT bind mount points."
set +Eeuo pipefail

box_out '#### PLEASE READ CAREFULLY ####' '' 'Bind mounts allow you to access arbitrary directories from your' 'Proxmox VE host inside your new Jellyfin CT. In order to proceed you must' 'have available mount points on your Proxmox VE host.' '' '      PROXMOX VE HOST NFS/CIFS MOUNTPOINT' '  --  "hostname"-audio (i.e cyclone-01-audio)' '  --  "hostname"-books (i.e cyclone-01-books)' '  --  "hostname"-music (i.e cyclone-01-music)' '  --  "hostname"-photo (i.e cyclone-01-photo)' '  --  "hostname"-public (i.e cyclone-01-public)' '  --  "hostname"-transcode (i.e cyclone-01-transcode)' '  --  "hostname"-video (i.e cyclone-01-video)'

read -p "Have you configured your Proxmox VE host with media bind mount points: [y/n]?: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  msg "Checking for PVE mount points for ${CT_HOSTNAME^} CT..."
else
  warn "Cannot create a ${CT_HOSTNAME^} CT without a fully configured Proxmox VE host.\nPlease read: https://github.com/ahuacate/proxmox-node section 7.\nExiting installation script in 3 second."
  cleanup
  sleep 3
  exit 0
fi
echo

msg "Creating a list of available PVE mount points for ${CT_HOSTNAME^} CT..."
pvesm status | grep -E 'nfs|cifs' | awk '{print $1}' > pvesm_mountpoint_list_var01
msg "Select the mount points to be used for ${CT_HOSTNAME^} CT"
menu() {
  echo "Available options:"
  for i in "${!options[@]}"; do 
      printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
  done
  if [[ "$msg" ]]; then echo "$msg"; fi
}
mapfile -t options < pvesm_mountpoint_list_var01
prompt="Check an option to select all mount points (again to uncheck, ENTER when done): "
while menu && read -rp "$prompt" num && [[ "$num" ]]; do
  [[ "$num" != *[![:digit:]]* ]] &&
  (( num > 0 && num <= ${#options[@]} )) ||
  { msg="Invalid option: $num"; continue; }
  ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
  [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
done
echo
printf "Your selected mount points are:\n"; msg=" nothing"
for i in ${!options[@]}; do
  [[ "${choices[i]}" ]] && { printf "${YELLOW}Mount Point:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> pvesm_mountpoint_list_var02
done
echo

msg "You have chosen $(cat pvesm_mountpoint_list_var02 | wc -l)x PVE mount points for your ${CT_HOSTNAME^} CT.\nNext confirm the media type for each PVE mount point from the list below.\nAt each prompt enter your selection by entering the corresponding numerical\nvalue (i.e 1-7) for each entry."
echo
TYPE01="${YELLOW}Audio${NC} - Audiobooks and podcasts."
TYPE02="${YELLOW}Books${NC} - Ebooks and Magazines."
TYPE03="${YELLOW}Music${NC} - Music, Albumms and Songs."
TYPE04="${YELLOW}Photo${NC} - Photographic image collection."
TYPE05="${YELLOW}Public${NC} - General public storage."
TYPE06="${YELLOW}Transcode${NC} - Video transcoding disk (A must for transcoding)."
TYPE07="${YELLOW}Video${NC} - Video - All video libraries (i.e movies, TV, homevideos)."
while IFS=, read -r line
do
  PS3="Select the media type for each PVE mount point ${WHITE}$line${NC} (entering numeric) : "
  select media_type in "$TYPE01" "$TYPE02" "$TYPE03" "$TYPE04" "$TYPE05" "$TYPE06" "$TYPE07"
  do
  echo
  info "PVE mount point ${WHITE}$line${NC} is set as : $(echo $media_type | awk '{print $1}')"
  read -p "Confirm your selection is correct: [y/n]?: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo $(df -h -T | grep -E 'nfs|cifs' | awk '{print $7}' | grep $line) /mnt/$(echo ${media_type,,} | awk '{print $1}' | sed "s/\x1B\[\([0-9]\{1,2\}\(;[0-9]\{1,2\}\)\?\)\?[mGK]//g") >> pvesm_mountpoint_list_var03
    echo
    break
  else
    echo
    warn "No good. No problem. Try again."
    sleep 2
    echo
  fi
  done < /dev/tty
done < pvesm_mountpoint_list_var02
set -Eeuo pipefail
echo

# Create CT Bind Mount Points
IFS=' '
i=0
while read -r PVE_MNT CT_MNT; do
  msg "Creating ${CT_HOSTNAME^} CT bind mounts..."
  pct set -mp$i $PVE_MNT,mp=$CT_MNT
  ((i=i+1))
  info "${CT_HOSTNAME^} CT bind mount created: ${YELLOW}$PVE_MNT${NC} > ${YELLOW}$CT_MNT${NC}"
  echo
done < pvesm_mountpoint_list_var03

# Unprivileged container mapping
msg "Create unprivileged container mapping..."
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/$CTID.conf
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
info "Unprivileged container UID mapping is set: ${YELLOW}media${NC}."
info "Unprivileged container GID mapping is set: ${YELLOW}medialab${NC}."
echo


#### Configure and Install VA-API ####
section "Configure and Install VAAPI"

box_out '#### PLEASE READ CAREFULLY ####' '' 'Jellyfin supports hardware acceleration of video encoding/decoding/transcoding' 'using FFMpeg. Because we use Linux we will use the open source Intel/AMD' 'Video Acceleration API (VA-API).' '' 'But first we must configure VA-API for your PVE host system. VA-API can be' 'configured on hardmetal PVE hosts only - not VMs.' '' 'In the next steps we will check if your PVE host hardware' 'supports video encoding.'

# Checking for PVE host VA-API support
msg "Checking PVE host support for VA-API..."
if [ $(ls -l /dev/dri | grep renderD128 > /dev/null; echo $?) == 0 ]; then
  DRM=0
  info "VA-API renderD128 status: ${GREEN}Pass${NC}"
else
  warn "VA-API renderD128 status: ${RED}Fail${NC}\nCannot configure VA-API. Skipping this step."
  DRM=1
fi
echo

# Installing VA-INFO
if [ $DRM == 0 ]; then
  msg "Installing VAINFO..."
  apt-get install vainfo -y >/dev/null
  chmod 666 /dev/dri/renderD128 >/dev/null
  if [ $(dpkg -s vainfo >/dev/null 2>&1; echo $?) = 0 ]; then
    info "VAINFO status: ${GREEN}Pass${NC}"
  else
    warn "VAINFO status: ${RED}Fail${NC}\nCannot install vainfo. User intervention required. Skipping this step."
    DRM=1
  fi
  echo
fi

# Create a rc.local
if [ $DRM == 0 ]; then
  msg "Creating rc.local script to set permissions for /dev/dri/renderD128..."
  echo '#!/bin/sh -e
  /bin/chmod 666 /dev/dri/renderD128
  exit 0' > /etc/rc.local
  chmod +x /etc/rc.local
  bash /etc/rc.local
  info "rc.local chmod 666 /dev/dri/renderD128 status: ${YELLOW}OK${NC}."
  echo
fi

# Create access to PVE host video device
if [ $DRM == 0 ]; then
  msg "Create access to PVE host video device..."
  DRM_VAR01=$(ls -l /dev/dri | grep renderD128 | awk '{print $5}' | sed "s/,//")
  DRM_VAR02=$(ls -l /dev/dri | grep renderD128 | awk '{print $6}')
  echo -e "lxc.cgroup.devices.allow = c $DRM_VAR01:$DRM_VAR02 rwm
  lxc.cgroup.devices.allow = c $DRM_VAR01:0 rwm
  lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file" >> /etc/pve/lxc/$CTID.conf
  info "Access to PVE host video device status: ${YELLOW}OK${NC}."
  echo
fi


#### Configuring PVE CT General Defaults ####
section "Configuring CT ${CT_HOSTNAME^} CT General Defaults."

# Start container
if [ "$(pct status $CTID)" == "status: stopped" ]; then
  msg "Starting container..."
  pct start $CTID
  sleep 5
  info "CT $CTID status: ${YELLOW}$(pct status $CTID | awk '{print $2}')${NC}"
  echo
fi

# Set Container locale
msg "Setting container locale..."
pct exec $CTID -- sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
pct exec $CTID -- locale-gen >/dev/null

# Ubuntu fix to avoid prompt to restart services during "apt apgrade"
msg "Patching prompt for user inputs during container upgrades..."
pct exec $CTID -- sudo apt-get -y install debconf-utils >/dev/null
pct exec $CTID -- sudo debconf-get-selections | grep libssl1.0.0:amd64 >/dev/null
pct exec $CTID -- bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"

# Set container timezone to match host
msg "Setting container time to match PVE host..."
pct exec $CTID -- MOUNT=$(pct mount $CTID | cut -d"'" -f 2)
pct exec $CTID -- ln -fs $(readlink /etc/localtime) ${MOUNT}/etc/localtime
pct exec $CTID -- pct unmount $CTID && unset MOUNT

# Update container OS
msg "Updating container OS (be patient, might take a while)..."
pct exec $CTID -- apt-get -y update >/dev/null
pct exec $CTID -- apt-get -qqy upgrade >/dev/null
echo


#### Installing Jellyfin ####
section "Installing ${CT_HOSTNAME^} software."

msg "Prerequisite - Installing HTTPS transport for APT..."
pct exec $CTID -- apt-get install apt-transport-https >/dev/null
msg "Prerequisite - Installing GNU Privacy Guard..."
pct exec $CTID -- apt-get install gnupg gnupg2 gnupg1 -y >/dev/null
msg "Prerequisite - Import the GPG signing key (signed by the Jellyfin Team)..."
pct exec $CTID -- wget -O - https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | sudo apt-key add - >/dev/null
msg "Prerequisite - Add a repository Jellyfin list..."
pct exec $CTID -- echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/ubuntu $( lsb_release -c -s ) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list >/dev/null
msg "Prerequisite - Updating container OS (be patient, might take a while)..."
pct exec $CTID -- apt-get -y update >/dev/null
echo
msg "Installing Jellyfin software..."
pct exec $CTID -- apt-get install jellyfin -y >/dev/null
if [ $(pct exec $CTID -- dpkg -s jellyfin >/dev/null 2>&1; echo $?) = 0 ]; then
  info "Jellyfin status: ${GREEN}Pass${NC}"
else
  warn "Jellyfin status: ${RED}Fail${NC}\nFailed to install Jellyfin. User intervention required. Exiting installation script in 3 second."
  sleep 3
  exit 0
fi
echo


#### Fix Jellyfin UID and GID ####
section "Fix ${CT_HOSTNAME^} UID and GID."

box_out '#### PLEASE READ CAREFULLY ####' '' 'Jellyfin installation by default creates a username & group: jellyfin:jellyfin.' 'Jellyfin SW runs under the username "jellyfin". In order for Jellyfin SW' 'to have read and write access to the NAS bind mount points we need to modify' 'the jellyfin UID and GID to match media:medialab (1605:65605).' '' 'This action resolves any permission problems.'

# Creating UID GID fix script
msg "Modifying username Jellyfin UID:GID to 1605:65605..."
cat << 'EOF' > uid_gid_fix.sh
#!/usr/bin/env bash
systemctl stop jellyfin
sleep 5
OLDUID=$(id -u jellyfin)
OLDGID=$(id -g jellyfin)
usermod -u 1605 jellyfin
groupmod -g 65605 jellyfin
usermod -s /bin/bash jellyfin
find / \( -path /mnt \) -prune -o -user "$OLDUID" -exec chown -h 1605 {} \;
find / \( -path /mnt \) -prune -o -group "$OLDGID" -exec chgrp -h 65605 {} \;
systemctl restart jellyfin
exit
EOF
pct push $CTID uid_gid_fix.sh /tmp/uid_gid_fix.sh -perms 755
pct exec $CTID -- bash -c "/tmp/uid_gid_fix.sh"
info "Username jellyfin UID is set: ${YELLOW}$(pct exec 200 -- id -u jellyfin)${NC}"
info "Groupname jellyfin GID is set: ${YELLOW}$(pct exec 200 -- id -g jellyfin)${NC}"
echo


#### Finish ####
section "File Server CT - Completion Status."

echo
msg "${WHITE}Success.${NC}"
sleep 3

# # Get network details and show completion message
IP=$(pct exec $CTID ip a s dev eth0 | sed -n '/inet / s/\// /p' | awk '{print $2}')
clear
echo
echo
msg "Success. ${CT_HOSTNAME^} installation has completed.\n\nTo manage ${CT_HOSTNAME^} you can login to ${CT_HOSTNAME^}.\n\n  --  ${WHITE}https://${IP}:8096/${NC}\n  --  ${WHITE}https://${CT_HOSTNAME}:8096/${NC}\n"
