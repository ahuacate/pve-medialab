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
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

# Download setup script
wget -qL https://github.com/ahuacate/proxmox-lxc-media/raw/master/scripts/jackett_setup_ubuntu_1804.sh

# Detect modules and automatically load at boot
load_module aufs
load_module overlay

# Select storage location
STORAGE_LIST=( $(pvesm status -content rootdir | awk 'NR>1 {print $1}') )
if [ ${#STORAGE_LIST[@]} -eq 0 ]; then
  warn "'Container' needs to be selected for at least one storage location."
  die "Unable to detect valid storage location."
elif [ ${#STORAGE_LIST[@]} -eq 1 ]; then
  STORAGE=${STORAGE_LIST[0]}
else
  msg "\n\nMore than one storage locations detected.\n"
  PS3=$'\n'"Which storage location would you like to use? "
  select s in "${STORAGE_LIST[@]}"; do
    if [[ " ${STORAGE_LIST[@]} " =~ " ${s} " ]]; then
      STORAGE=$s
      break
    fi
    echo -en "\e[1A\e[K\e[1A"
  done
fi
info "Using '$STORAGE' for storage location."
echo

echo -e "In the next step you must enter your desired Proxmox container settings. \nOr simply press 'ENTER' to accept our defaults."
echo

# Set container IPv4 Address
read -p "Enter IPv4 address: " -e -i 192.168.50.120/24 IP
info "Container IPv4 address is $IP."
echo

# Set container VLAN tag
read -p "Enter VLAN ID: " -e -i 50 TAG
info "Container VLAN is $TAG."
echo

# Set container Gateway IPv4 Address
read -p "Enter Gateway IPv4 address: " -e -i 192.168.50.5 GW
info "Container Gateway IPv4 address is $GW."
echo

# Set container ID
read -p "Enter container CTID: " -e -i 120 CTID
info "Container ID is $CTID."
echo

# Set container Virtual Disk Size
read -p "Enter container Virtual Disk Size (Gb): " -e -i 8 DISK_SIZE
info "Container Virtual Disk is $DISK_SIZE."
echo

# Set container Memory
read -p "Enter amount of container Memory (Mb): " -e -i 512 RAM
info "Container allocated memory is $RAM."
echo

# Set container Hostname
read -p "Enter your LXC Hostname: " -e -i jackett HOSTNAME
info "Container hostname is $HOSTNAME."
echo

# Set container password
read -p "Enter container root password: " -e -i ahuacate PWD
info "Container root password is '$PWD'."
echo

# Download latest OS LXC template
msg "Updating LXC template list..."
pveam update >/dev/null
msg "Downloading LXC template..."
OSTYPE=ubuntu
OSVERSION=${OSTYPE}-18
mapfile -t TEMPLATES < <(pveam available -section system | sed -n "s/.*\($OSVERSION.*\)/\1/p" | sort -t - -k 2 -V)
TEMPLATE="${TEMPLATES[-1]}"
pveam download local $TEMPLATE >/dev/null ||
  die "A problem occured while downloading the LXC template."
ARCH=$(dpkg --print-architecture)
#HOSTNAME=jackett
TEMPLATE_STRING="local:vztmpl/${TEMPLATE}"

# Create LXC
msg "Creating LXC container..." 
pct create $CTID $TEMPLATE_STRING --arch $ARCH --cores 1 --hostname $HOSTNAME --cpulimit 1 --memory $RAM \
  --net0 name=eth0,bridge=vmbr0,tag=$TAG,firewall=1,gw=$GW,ip=$IP,type=veth \
  --ostype $OSTYPE --rootfs $STORAGE:$DISK_SIZE --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password $PWD >/dev/null

# Add LXC mount points
pct set $CTID -mp0 /mnt/pve/cyclone-01-backup/$HOSTNAME,mp=/mnt/backup
pct set $CTID -mp1 /mnt/pve/cyclone-01-public,mp=/mnt/public

# Unprivileged container mapping
cat << EOF >> /etc/pve/lxc/$CTID.conf
# User media | Group medialab
lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100
EOF
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid

# Create a backup folder on NAS
msg "Creating backup folder on NAS..."
mkdir -p /mnt/pve/cyclone-01-backup/$HOSTNAME
chown 1607:65607 /mnt/pve/cyclone-01-backup/$HOSTNAME

# Start container
msg "Starting container..."
pct start $CTID

# Create new container users and groups
msg "Creating new container users and groups..."
pct exec $CTID -- groupadd -g 65605 medialab
pct exec $CTID -- useradd -u 1605 -g medialab -m media

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
msg "Set container time to match host..."
MOUNT=$(pct mount $CTID | cut -d"'" -f 2)
ln -fs $(readlink /etc/localtime) ${MOUNT}/etc/localtime
pct unmount $CTID && unset MOUNT

# Update container OS
msg "Updating container OS..."
pct exec $CTID -- apt-get update >/dev/null
pct exec $CTID -- apt-get -qqy upgrade >/dev/null

# Install prerequisites
#msg "Installing prerequisites..."
#pct exec $CTID -- apt-get install -y software-properties-common >/dev/null

# Setup container for Software script
msg "Starting $HOSTNAME software installation script..."
pct push $CTID jackett_setup_ubuntu_1804.sh /jackett_setup_ubuntu_1804.sh -perms 755
pct exec $CTID -- bash -c "/jackett_setup_ubuntu_1804.sh"

# Get network details and show completion message
IP=$(pct exec $CTID ip a s dev eth0 | sed -n '/inet / s/\// /p' | awk '{print $2}')
info "Successfully created $HOSTNAME LXC to $CTID."
msg "

$HOSTNAME is reachable by going to the following URLs.

      http://${IP}:9117
      http://${HOSTNAME}.local:9117

"
