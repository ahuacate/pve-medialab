#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_updater.sh
# Description:  Source script for updating Vidcoderr & host OS
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )
COMMON_DIR="$DIR/../../common"
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"
SHARED_DIR="$DIR/../../shared"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_DIR/bash/src/basic_bash_utility.sh

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app_uid="media"        # App UID
app_guid="medialab"    # App GUID

# Get 'vidcoderr_watchdir_type' arg
vidcoderr_watchdir_type=$(awk -F "=" '/vidcoderr_watchdir_type/ {print $2}' /usr/local/bin/vidcoderr/vidcoderr.ini)

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Stop and disable several services
services=(
  vidcoderr_watchdir.service
  vidcoderr_rsync.timer
  vidcoderr_inotify_rsync.service
  vidcoderr_inotify.service
  SimpleHTTPServerWithUpload.service
)

for service in "${services[@]}"
do
  if [ "$(systemctl is-active "$service")" == "active" ]
  then
    systemctl stop "$service"
    while ! [ "$(systemctl is-active "$service")" == "active" ]
    do
      echo -n .
    done
    systemctl disable "$service" &> /dev/null
  fi
done


#---- Perform OS updates
apt-get update -y
apt-get upgrade -y


#---- Perform Prerequisite updates
# Installing Ruby
apt-get upgrade ruby-full -y

# Install bc
apt-get upgrade bc -y

# Install MKVToolNix
apt-get upgrade mkvtoolnix mkvtoolnix-gui -y

# Install FFmpeg
apt-get upgrade ffmpeg -y

# Install Mediainfo
apt-get upgrade mediainfo -y

# Install MPV
apt-get upgrade mpv -y

# Install MPV
apt-get upgrade inotify-tools -y

# Install Translate
apt-get upgrade translate-shell -y

# Install encoder kernels
apt-get upgrade i965-va-driver-shaders -y
apt-get upgrade intel-media-va-driver-non-free -y

#---- Install latest Vidcoderr scripts
# Copy config files to /usr/local/bin/vidcoderr
cp -f $DIR/config/*.sh /usr/local/bin/vidcoderr/
chmod a+rx /usr/local/bin/vidcoderr/*.sh

# Copy SimpleHTTPServerWithUpload scripts to /usr/local/bin/vidcoderr
cp -f $DIR/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.sh /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.sh
chmod a+rx /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.sh
cp -f $DIR/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.py /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.py
chmod a+rx /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.py

# Copy filters to /usr/local/bin/vidcoderr
cp -f $DIR/config/video_format_filter.txt /usr/local/bin/vidcoderr/video_format_filter.txt
cp -f $DIR/config/other_format_filter.txt /usr/local/bin/vidcoderr/other_format_filter.txt
cp -f $DIR/config/rsync_exclude_filter.txt /usr/local/bin/vidcoderr/rsync_exclude_filter.txt
# Chown media:medialab all txt files
chown $app_uid:$app_guid /usr/local/bin/vidcoderr/*.txt


#---- Upgrade Don Meltons Other Video Transcode
gem update other_video_transcoding

#---- Start Systemd ----------------------------------------------------------------

# Start Vidcoderr system.d services
case "$vidcoderr_watchdir_type" in
  1)
    # Standard Watch Service
    services=(
      vidcoderr_watchdir_rsync.timer
      vidcoderr_inotify_rsync.service
      SimpleHTTPServerWithUpload.service
    )
    ;;
  2)
    # Inotify Watch Service
    services=(
      vidcoderr_inotify.service
      SimpleHTTPServerWithUpload.service
    )
    ;;
  *)
    # Unknown watchdir_type
    echo "Unknown vidcoderr_watchdir_type: $vidcoderr_watchdir_type"
    exit 1
    ;;
esac

# Enable and start services if necessary
for service in "${services[@]}"
do
  if [ "$(systemctl is-active "$service")" == "inactive" ]
  then
    systemctl enable --quiet "$service"
    systemctl restart "$service"
    while ! [ "$(systemctl is-active "$service")" == "active" ]
    do
      echo -n .
    done
  fi
done
#-----------------------------------------------------------------------------------