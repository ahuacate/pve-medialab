#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_kodirsync.sh
# Description:  This script is for creating a Proxmox Kodirsync Server CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_kodirsync.sh)"

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
SSH_ENABLE=0

# Developer enable git mounts inside CT (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=1

#---- Other Variables --------------------------------------------------------------

# Container Hostname
CT_HOSTNAME_VAR='kodirsync'
# Container IP Address (192.168.50.121)
CT_IP_VAR='192.168.50.121'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.50.5'
# Container DNS Server
CT_DNS_SERVER_VAR='192.168.50.5'
# Container Number
CTID_VAR='121'
# Container VLAN
CT_TAG_VAR='50'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='2'
# Container allocated RAM
CT_RAM_VAR='512'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Kodirsync'
#---- Do Not Edit
# Container Swap
CT_SWAP="$(( $CT_RAM_VAR / 2 ))"
# CT CPU Cores
CT_CPU_CORES="$CT_CPU_CORES_VAR"
# CT unprivileged status
CT_UNPRIVILEGED='0'
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

# CT SSH Port
SSH_PORT_VAR='22' # Best not use default port 22


#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for CT
cat << 'EOF' > pvesm_required_list
audio|Audiobooks and podcasts
backup|CT settings backup storage
music|Music, Albums and Songs
photo|Photographic image collection
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

#---- Kodi Rsync -------------------------------------------------------------------

section "Setting up ${CT_HOSTNAME_VAR^}"

#---- Prerequisites

msg "Installing ACL..."
pct exec $CTID -- apt-get install -y acl >/dev/null
msg "Installing Putty Tools..."
pct exec $CTID -- apt-get install -y putty-tools >/dev/null
# # Change Home folder permissions
# msg "Setting default adduser home folder permissions (DIR_MODE 0750)..."
# pct exec $CTID -- sed -i "s/DIR_MODE=.*/DIR_MODE=0750/g" /etc/adduser.conf
# pct exec $CTID -- chmod -R 0750 /home >/dev/null
# Change first user UID to higher range
msg "Setting default adduser start range for dynamically allocated UIDs..."
pct exec $CTID -- sed -i "s/^FIRST_UID=.*/FIRST_UID=50000/g" /etc/adduser.conf
pct exec $CTID -- sed -i "s/^UID_MIN.*/UID_MIN                 50000/g" /etc/login.defs
echo


#---- Create SSH Chroot jail Environment
pct exec $CTID -- bash -c "export TEMP_DIR=${TEMP_DIR} && mkdir -p \${TEMP_DIR}"
pct push $CTID ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh ${TEMP_DIR}/pvesource_bash_defaults.sh -perms 755
pct push $CTID ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_installchroot.sh ${TEMP_DIR}/pvesource_ct_ubuntu_installchroot.sh -perms 755
pct push $CTID ${DIR}/source/pve_medialab_ct_kodirsync_chrootapplist ${TEMP_DIR}/pve_medialab_ct_kodirsync_chrootapplist
pct exec $CTID -- bash -c "export PARENT_EXEC_INSTALL_KODI_RSYNC=0 && export SSH_PORT=$SSH_PORT && source ${TEMP_DIR}/pvesource_ct_ubuntu_installchroot.sh"
pct exec $CTID -- bash -c "rm -rf ${TEMP_DIR} &> /dev/null"

#---- Create /root/.ssh folder
pct exec $CTID -- bash -c "mkdir -p /root/.ssh"
pct exec $CTID -- bash -c "chmod 700 /root/.ssh"

# Removing ForceCommand internal-sftp
pct exec $CTID -- sed -i 's|^[#]*\s*        ForceCommand internal-sftp||g' /etc/ssh/sshd_config
pct exec $CTID -- systemctl restart ssh 2>/dev/null

#---- Create Rsync Whitelist & Blacklist file
cat << 'EOF' > rsync_control_list.sh
#!/usr/bin/env bash
if [ -d /mnt/video/movies ] && [ ! -f /mnt/video/movies/rsync_control_list_global-movies.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/movies/rsync_control_list_global-movies.txt
fi
if [ -d /mnt/video/series ] && [ ! -f /mnt/video/series/rsync_control_list_global-series.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/series/rsync_control_list_global-series.txt
fi
if [ -d /mnt/video/pron ] && [ ! -f /mnt/video/pron/rsync_control_list_global-pron.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/pron/rsync_control_list_global-pron.txt
fi
if [ -d /mnt/video/homevideo ] && [ ! -f /mnt/video/homevideo/rsync_control_list_global-homevideo.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/homevideo/rsync_control_list_global-homevideo.txt
fi
if [ -d /mnt/video/musicvideo ] && [ ! -f /mnt/video/musicvideo/rsync_control_list_global-musicvideo.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/musicvideo/rsync_control_list_global-musicvideo.txt
fi
if [ -d /mnt/video/documentary ] && [ ! -f /mnt/video/documentary/rsync_control_list_global-documentary.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/video/documentary/rsync_control_list_global-documentary.txt
fi
if [ -d /mnt/music ] && [ ! -f /mnt/music/rsync_control_list_global-music.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\nTo whitelist your whole music collection use the following: < w|* >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/music/rsync_control_list_global-music.txt
fi
if [ -d /mnt/photo ] && [ ! -f /mnt/photo/rsync_control_list_global-photo.txt ]; then
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder name you want excluded from Kodi Rsync by marking it\n# with letter 'b' followed by a '|' (pipe).\n# Whitelist any media folder name you want to store on your client forever by\n# marking it with letter 'w' followed by a '|' (pipe). Kodi Rsync will never delete\n# this media folder from your client.\n# Folder names are case sensitive.\n# Use a wildcard * at the end of a partial folder name entry if you want to.\n# Blacklist example: < b|What We Did* > or < b|What We Did on Our Holiday (2014) >\n# Whitelist example: < w|Toy Story* > or < w|Toy Story (2019) >\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > /mnt/photo/rsync_control_list_global-photo.txt
fi
EOF
pct exec $CTID -- bash -c "export TEMP_DIR=${TEMP_DIR} && mkdir -p \${TEMP_DIR}"
pct push $CTID rsync_control_list.sh ${TEMP_DIR}/rsync_control_list.sh -perms 755
pct exec $CTID -- bash -c "source ${TEMP_DIR}/rsync_control_list.sh"
pct exec $CTID -- bash -c "rm -rf ${TEMP_DIR} &> /dev/null"

# #---- Install SSMTP
pct exec $CTID -- bash -c "export TEMP_DIR=${TEMP_DIR} && mkdir -p \${TEMP_DIR}"
pct push $CTID ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh ${TEMP_DIR}/pvesource_bash_defaults.sh -perms 755
pct push $CTID ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_installssmtp.sh ${TEMP_DIR}/pvesource_ct_ubuntu_installssmtp.sh -perms 755
pct exec $CTID -- bash -c "source ${TEMP_DIR}/pvesource_ct_ubuntu_installssmtp.sh"
pct exec $CTID -- bash -c "rm -rf ${TEMP_DIR} &> /dev/null"

#---- Install Fail2ban
pct exec $CTID -- bash -c "export TEMP_DIR=${TEMP_DIR} && mkdir -p \${TEMP_DIR}"
pct push $CTID ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh ${TEMP_DIR}/pvesource_bash_defaults.sh -perms 755
pct push $CTID ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_installfail2ban.sh ${TEMP_DIR}/pvesource_ct_ubuntu_installfail2ban.sh -perms 755
pct exec $CTID -- bash -c "export SSH_PORT=${SSH_PORT} && source ${TEMP_DIR}/pvesource_ct_ubuntu_installfail2ban.sh"
pct exec $CTID -- bash -c "rm -rf ${TEMP_DIR} &> /dev/null"

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "Success. Kodirsync has been created. Your Kodirsync server details are:

  --  IP Address : ${WHITE}${CT_IP}${NC}
  --  Port Number : ${WHITE}${SSH_PORT}${NC}

For remote internet connections setup pfSense HAProxy to manage inbound remote connections to this Kodirsync server (Recommended). Or you could configure 'port forwarding' on your WAN gateway device but this is not recommended due to potential security risks.
  
You can now create Kodirsync clients by running the the following command inside your Kodirsync CT (CLI):

  --  Step 1 : Enter 'Kodirsync' CT (PVE CLI)
      ${WHITE}pct enter $CTID${NC}

  --  Step 2 : Run the following CLI command inside your 'Kodirsync' CT
      ${WHITE}bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_kodirsync_addclient_installer.sh)\"${NC}"
echo

# Cleanup
trap cleanup EXIT