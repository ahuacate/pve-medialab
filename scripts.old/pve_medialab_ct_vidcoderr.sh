#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_vidcoderr.sh
# Description:  This script is for creating a Proxmox Vidcoderr CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#---- Source Github
#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_vidcoderr.sh)"

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
CT_HOSTNAME_VAR='vidcoderr'
# Container IP Address (192.168.50.122)
CT_IP_VAR='192.168.50.122'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.50.5'
# Container DNS Server
CT_DNS_SERVER_VAR='192.168.50.5'
# Container Number
CTID_VAR='122'
# Container VLAN
CT_TAG_VAR='50'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='8'
# Container allocated RAM
CT_RAM_VAR='2048'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Vidcoderr'
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

# VA-API Install & Setup for CT
source ${COMMON_PVE_SOURCE}/pvesource_ct_medialab_vaapipassthru.sh

#---- Configure New CT OS
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntubasics.sh

#---- Create MediaLab Group and User
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_addmedialabuser.sh

#---- Videotrans -------------------------------------------------------------------

#---- Prerequisites
section "${CT_HOSTNAME_VAR^} Prerequisites"

# Installing Ruby
msg "Prerequisite - Installing Ruby..."
pct exec $CTID -- apt-get install ruby-full -yqq

# Install bc
msg "Prerequisite - Installing bc..."
pct exec $CTID -- apt-get install bc -yqq

# Install MKVToolNix
msg "Prerequisite - Installing MKVToolNix..."
pct exec $CTID -- wget -q --show-progress -O /usr/share/keyrings/gpg-pub-moritzbunkus.gpg https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg
pct exec $CTID -- apt-get update -yqq
pct exec $CTID -- apt-get install mkvtoolnix mkvtoolnix-gui -yqq

# Install FFmpeg
msg "Prerequisite - Installing FFmpeg..."
pct exec $CTID -- apt-get install ffmpeg -yqq

# Install Mediainfo
msg "Prerequisite - Installing Mediainfo..."
pct exec $CTID -- apt-get install mediainfo -yqq

# Install MPV
msg "Prerequisite - Installing MPV..."
pct exec $CTID -- apt-get install mpv -yqq

# Install MPV
msg "Prerequisite - Installing Inotify..."
pct exec $CTID -- apt-get install inotify-tools -yqq

# Install Translate
msg "Prerequisite - Installing Translate Shell..."
pct exec $CTID -- apt-get install translate-shell -yqq

# Install encoder kernels
pct exec $CTID -- apt-get install i965-va-driver-shaders -yqq
pct exec $CTID -- apt-get install intel-media-va-driver-non-free -yqq

#---- Install Don Melton Other Video Transcoding
section "Install Don Melton package"
msg "Installing Other-Video package..."
pct exec $CTID -- gem install other_video_transcoding
pct exec $CTID -- bash -c 'echo "PATH="$PATH:/usr/local/bin/other-transcode"" >> ~/.bashrc'
pct exec $CTID -- bash -c 'echo "PATH="/usr/local/bin:$PATH"" >> ~/.bashrc'

#---- Install Vidcoderr
section "Install Vidcoderr"

# Create Videocoderr
msg "Create '/usr/local/bin/vidcoderr' folder..."
pct exec $CTID -- mkdir -p /usr/local/bin/vidcoderr
pct exec $CTID -- chown media:medialab /usr/local/bin/vidcoderr
msg "Copying Vidcoderr configuration files to CT ( be patient, can take a while )..."
# Copy vidcoderr.ini file
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr.ini /usr/local/bin/vidcoderr/vidcoderr.ini
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr.ini
# vidcoderr_watchdir.sh script
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_watchdir.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
# vidcoderr_watchprune.sh script
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_watchprune.sh /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh
# vidcoderr_encoder.sh script
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_encoder.sh /usr/local/bin/vidcoderr/vidcoderr_encoder.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_encoder.sh
# Input filters
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/video_format_filter.txt /usr/local/bin/vidcoderr/video_format_filter.txt
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/other_format_filter.txt /usr/local/bin/vidcoderr/other_format_filter.txt
pct exec $CTID -- chown media:medialab /usr/local/bin/vidcoderr/video_format_filter.txt
pct exec $CTID -- chown media:medialab /usr/local/bin/vidcoderr/other_format_filter.txt
# Transcode queue file
pct exec $CTID -- touch /usr/local/bin/vidcoderr/queue.txt
pct exec $CTID -- chown media:medialab /usr/local/bin/vidcoderr/queue.txt

# Create vidcoderr_watchdir log
cat << 'EOF' > ${TEMP_DIR}/vidcoderr_watchdir
/usr/local/bin/vidcoderr/watchdir.log
{
  rotate daily
  maxsize 1M
  rotate 0
}
EOF
pct push $CTID ${TEMP_DIR}/vidcoderr_watchdir /etc/logrotate.d/vidcoderr_watchdir
pct exec $CTID -- chmod 644 /etc/logrotate.d/vidcoderr_watchdir
pct exec $CTID -- chown root:root /etc/logrotate.d/vidcoderr_watchdir
# Videocoderr log file
pct exec $CTID -- touch /usr/local/bin/vidcoderr/vidcoderr_watchdir.log
pct exec $CTID -- chown -R media:medialab /usr/local/bin/vidcoderr/vidcoderr_watchdir.log
pct exec $CTID -- chown -R media:medialab /etc/logrotate.d/vidcoderr_watchdir

#---- Install Vidcoderr
section "Create Vidcoderr system.d services"

# Systemd Vidcoderr Watchdir
msg "Creating Videocoderr system.d services..."
cat << 'EOF' > ${TEMP_DIR}/vidcoderr_watchdir.service 
[Unit]
Description = Medialab Videocoderr Watch
Documentation = https://github.com/ahuacate/pve-medialab
After = network.target

[Service]
PIDFile = /run/vidcoderr_watchdir/vidcoderr_watchdir.pid
User = media
Group = medialab
WorkingDirectory = /usr/local/bin/vidcoderr
ExecStartPre = /bin/mkdir /run/vidcoderr_watchdir
ExecStartPre = /bin/chown -R root:root /run/vidcoderr_watchdir
ExecStart = /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
ExecReload = kill -s HUP $MAINPID
ExecStop = kill -s TERM $MAINPID
ExecStopPost = rm -rf /run/vidcoderr_watchdir
#PrivateTmp = true
Restart=on-failure
RestartSec=1
PermissionsStartOnly=true

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID ${TEMP_DIR}/vidcoderr_watchdir.service /etc/systemd/system/vidcoderr_watchdir.service

# Systemd Vidcoderr Watchprune
cat << 'EOF' > ${TEMP_DIR}/vidcoderr_watchprune.service 
[Unit]
Description = Medialab Videocoderr Watchprune
Documentation = https://github.com/ahuacate/pve-medialab
After = network.target

[Service]
PIDFile = /run/vidcoderr_watchprune/watchprune.pid
User = media
Group = medialab
WorkingDirectory = /usr/local/bin/vidcoderr
ExecStartPre = /bin/mkdir /run/vidcoderr_watchprune
ExecStartPre = /bin/chown -R root:root /run/vidcoderr_watchprune
ExecStart = /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh
ExecReload = kill -s HUP $MAINPID
ExecStop = kill -s TERM $MAINPID
ExecStopPost = rm -rf /run/vidcoderr_watchprune
#PrivateTmp = true
Restart=on-failure
RestartSec=1
PermissionsStartOnly=true

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID ${TEMP_DIR}/vidcoderr_watchprune.service /etc/systemd/system/vidcoderr_watchprune.service

#---- Configure Vidcoderr
section "Configure Vidcoderr"

source ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_configbuilder.sh

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "Success. ${CT_HOSTNAME_VAR^} installation has finished.

The User can use the Vidcoderr Toolbox script to update Vidcoderr software and make change configuration settings.

More complex tweaks can be made in the configuration file: /usr/local/bin/vidcoderr/vidcoderr.ini ( Vidcoderr requires a restart after editing ).\n"

# Cleanup
trap cleanup EXIT


# # su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/public/autoadd/vidcoderr/in_homevideo/test1.mpg' media
# DIR='/mnt/pve/nas-01-git/ahuacate/pve-medialab/scripts'
# su -c 'mkdir -p /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2021)"' media && su -c 'wget -L - http://media.developer.dolby.com/DDP/MP4_HPL40_30fps_channel_id_51.mp4 -O /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2021)"/test1.mp4' media

# su -c 'mkdir -p /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2021)"' media && su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2021)"/test1.mpg' media
# su -c 'mkdir -p /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2022)"' media && su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2022)"/test2.mpg' media

# su -c 'mkdir -p /mnt/video/movies/"test (2021)"' media && su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/video/movies/"test (2021)"/test1.mpg' media


# CTID=122 && DIR='/mnt/pve/nas-01-git/ahuacate/pve-medialab/scripts' && pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr.ini /usr/local/bin/vidcoderr/vidcoderr.ini && pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr.ini && pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_watchdir.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh && pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh && pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_watchprune.sh /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh && pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh && pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_encoder.sh /usr/local/bin/vidcoderr/vidcoderr_encoder.sh && pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_encoder.sh

# su -c 'mkdir -p /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2022)"' media && su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s-h264.mov -O /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2022)"/test2.mov' media


# su -c 'mkdir -p /mnt/video/movies/"test (2021)"' media && su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/video/movies/"test (2021)"/test1.mpg' media

# su -c 'rm -R /mnt/video/movies/"test (2021)" &> /dev/null' media && su -c 'mkdir -p /mnt/video/movies/"test (2021)"' media && su -c 'cp -R /mnt/public/"test (2021)" /mnt/video/movies/' media

# su -c 'mkdir -p /mnt/video/movies/"test (2021)"' media && su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/video/movies/"test (2021)"/test1.mpg' media && su -c 'cp -R /mnt/video/movies/"test (2021)" /mnt/video/stream/movies/' media

echo "/mnt/video/transcode/vidcoderr/in_homevideo/swans.mp4,--main-audio 1=stereo --add-subtitle auto --crop auto --hevc --eac3,,in_homevideo,swans.mkv,/mnt/video/homevideo,0" >> /usr/local/bin/vidcoderr/queue.txt

CTID=122 && DIR='/mnt/pve/nas-01-git/ahuacate/pve-medialab/scripts' && pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_watchdir.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh && pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh && pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_encoder.sh /usr/local/bin/vidcoderr/vidcoderr_encoder.sh && pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_encoder.sh && pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_watchprune.sh /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh && pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh

/usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
/usr/local/bin/vidcoderr/vidcoderr_encoder.sh

su -c 'mkdir -p /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2021)"' media && su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/public/autoadd/vidcoderr/in_stream/movies/"test (2021)"/test1.mpg' media

wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /tmp/test1.mpg

su -c 'mkdir -p /mnt/public/autoadd/vidcoderr/in_stream/series/"Now, We Are Breaking Up"/"Season 1"/' media && su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/public/autoadd/vidcoderr/in_stream/series/"Now, We Are Breaking Up"/"Season 1"/"Now, We Are Breaking Up - S01E01 - Blind Date - [WEBRip-1080p x264 AAC 2.0 ].mpg"' media

su -c 'mkdir -p /mnt/public/autoadd/vidcoderr/in_stream/series/"Now, We Are Breaking Up"/"Season 1"/' media && su -c 'wget -L - https://img.photographyblog.com/reviews/samsung_galaxy_s21_ultra/sample_images/4K60p.mp4 -O /mnt/public/autoadd/vidcoderr/in_stream/series/"Now, We Are Breaking Up"/"Season 1"/"Now, We Are Breaking Up - S01E01 - Blind Date - [WEBRip-1080p x264 AAC 2.0 ].mp4"' media

su -c 'mkdir -p /mnt/video/series/"Now, We Are Breaking Up"/"Season 1"/' media && su -c 'wget -L - https://img.photographyblog.com/reviews/samsung_galaxy_s21_ultra/sample_images/4K60p.mp4 -O /mnt/video/series/"Now, We Are Breaking Up"/"Season 1"/"Now, We Are Breaking Up - S01E01 - Blind Date - [WEBRip-1080p x264 AAC 2.0 ].mp4"' media

su -c 'rm -R /mnt/video/series/"Now, We Are Breaking Up"' media
su -c 'rm /mnt/video/series/"Now, We Are Breaking Up"/"Season 1"/"Now, We Are Breaking Up - S01E01 - Blind Date - [WEBRip-1080p x264 AAC 2.0 ].mp4"' media

su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /mnt/public/autoadd/vidcoderr/in_stream/movies/test1.mpg' media

su -c 'mkdir -p /mnt/public/autoadd/vidcoderr/in_homevideo/fucker' media && su -c 'wget -L - https://img.photographyblog.com/reviews/samsung_galaxy_s21_ultra/sample_images/4K60p.mp4 -O /mnt/public/autoadd/vidcoderr/in_homevideo/fucker/homevid3.mp4' media

su -c 'wget -L - https://img.photographyblog.com/reviews/samsung_galaxy_s21_ultra/sample_images/4K60p.mp4 -O /mnt/public/autoadd/vidcoderr/in_homevideo/homevid2.mp4' media

su -c 'wget -L - https://img.photographyblog.com/reviews/samsung_galaxy_s21_ultra/sample_images/4K60p.mp4 -O /tmp/test2.mp4' media
su -c 'wget -L - https://users.wfu.edu/yipcw/atg/vid/katamari-star8-10s.mpg -O /tmp/test1.mpg' media

su -c 'mkdir -p /mnt/video/transcode/vidcoderr/in_stream/"test (2021)"' media && su -c 'cp /tmp/test1.mpg /mnt/video/transcode/vidcoderr/in_stream/"test (2021)"/test1.mpg' media && echo "/mnt/video/transcode/vidcoderr/in_stream/test (2021)/test1.mpg;--main-audio 1=stereo --add-subtitle auto --crop auto --hevc --stereo-bitrate 192 --target 2160p=15000 --target 1080p=7500 --target 720p=5000 --target 480p=3750;test (2021)/;in_stream;test1.mkv;/mnt/video/stream/movies/;1" > /usr/local/bin/vidcoderr/queue.txt

other-transcode --qsv /tmp/test2.mp4

su -c "cp /mnt/video/series/'DIY SOS'/'Season 32'/'DIY SOS - S32E02 - The Big Build - Corby - [SDTV XviD MP3 2.0 ].avi' /mnt/video/documentary/movies/'DIY SOS - S32E02 - The Big Build - Corby - [SDTV XviD MP3 2.0 ].avi'" media

su -c "mv /mnt/video/transcode/vidcoderr/in_stream/movies/'DIY SOS - S32E02 - The Big Build - Corby - [LOW Q HEVC AAC Stereo].mkv' /mnt/video/stream/documentary/'DIY SOS - S32E02 - The Big Build - Corby - [LOW Q HEVC AAC Stereo].mkv'" media
