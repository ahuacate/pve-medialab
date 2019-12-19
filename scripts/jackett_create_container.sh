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
wget -qL https://github.com/whiskerz007/proxmox_hassio_lxc/raw/master/setup.sh

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
read -p "Enter IPv4 address: " -e -i 192.168.110.131/24 IP
info "Container IPv4 address is $IP."
echo

# Set container VLAN tag
read -p "Enter VLAN ID: " -e -i 110 TAG
info "Container VLAN is $TAG."
echo

# Set container Gateway IPv4 Address
read -p "Enter Gateway IPv4 address: " -e -i 192.168.110.5 GW
info "Container Gateway IPv4 address is $GW."
echo

# Set container ID
read -p "Enter container CTID: " -e -i 131 CTID
info "Container ID is $CTID."
echo

# Set container Virtual Disk Size
read -p "Enter container Virtual Disk Size (Gb): " -e -i 30 DISK_SIZE
info "Container Virtual Disk is $DISK_SIZE."
echo

# Set container Memory
read -p "Enter amount of container Memory (Gb): " -e -i 2048 RAM
info "Container allocated memory is $RAM."
echo

# Set container password
read -p "Enter container root password: " -e -i hassio PWD
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
HOSTNAME=hassio
TEMPLATE_STRING="local:vztmpl/${TEMPLATE}"

# Create LXC
msg "Creating LXC container..." 
pct create $CTID $TEMPLATE_STRING --arch $ARCH --cores 1 --hostname $HOSTNAME --cpulimit 1 --memory $RAM --features nesting=1 \
  --net0 name=eth0,bridge=vmbr0,tag=$TAG,firewall=1,gw=$GW,ip=$IP,type=veth \
  --ostype $OSTYPE --rootfs $STORAGE:$DISK_SIZE --swap 256 --unprivileged 0 --onboot 1 --startup order=2 --password $PWD >/dev/null

# Add LXC mount points
pct set $CTID -mp0 /mnt/pve/cyclone-01-backup/hassio,mp=/mnt/backup
pct set $CTID -mp1 /mnt/pve/cyclone-01-public,mp=/mnt/public

# Modify LXC permissions to support Docker
LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
cat <<EOF >> $LXC_CONFIG
lxc.cgroup.devices.allow: a
lxc.cap.drop:
EOF

# Add access to ttyACM,ttyS,ttyUSB,net/tun devices
LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
cat <<'EOF' >> $LXC_CONFIG
lxc.autodev: 1
lxc.hook.autodev: bash -c 'for dev in $(ls /dev/tty{ACM,S,USB}* 2>/dev/null) $([ -d "/dev/bus" ] && find /dev/bus -type c) /dev/mem /dev/net/tun; do mkdir -p $(dirname ${LXC_ROOTFS_MOUNT}${dev}); for link in $(udevadm info --query=property $dev | sed -n "s/DEVLINKS=//p"); do mkdir -p ${LXC_ROOTFS_MOUNT}$(dirname $link); cp -dR $link ${LXC_ROOTFS_MOUNT}${link}; done; cp -dR $dev ${LXC_ROOTFS_MOUNT}${dev}; done'
EOF

# Create a hassio backup folder on NAS
msg "Creating hassio backup folder on NAS..."
mkdir -p /mnt/pve/cyclone-01-backup/hassio &&
chown 1607:65607 /mnt/pve/cyclone-01-backup/hassio

# Start container
msg "Starting container..."
pct start $CTID

# Create new container users and groups
msg "Creating new container users and groups..."
pct exec $CTID -- groupadd -g 65607 privatelab
pct exec $CTID -- useradd -u 1607 -g privatelab -m typhoon

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
msg "Installing prerequisites..."
pct exec $CTID -- apt-get install -y software-properties-common >/dev/null
pct exec $CTID -- apt-get install -y apparmor-utils >/dev/null
pct exec $CTID -- apt-get install -y apt-transport-https >/dev/null
pct exec $CTID -- apt-get install -y ca-certificates >/dev/null
pct exec $CTID -- apt-get install -y socat >/dev/null
# pct exec $CTID -- apt-get install -y python3-pip >/dev/null

# Setup container for Hass.io
msg "Starting whiskerz007 hassio installation script..."
pct push $CTID setup.sh /setup.sh -perms 755
pct exec $CTID -- bash -c "/setup.sh"

# Get network details and show completion message
IP=$(pct exec $CTID ip a s dev eth0 | sed -n '/inet / s/\// /p' | awk '{print $2}')
info "Successfully created Hass.io LXC to $CTID."
msg "

Hass.io is reachable by going to the following URLs.

      http://${IP}:8123
      http://${HOSTNAME}.local:8123

"
