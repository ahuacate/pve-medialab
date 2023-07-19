#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_sw.sh
# Description:  Source script for App SW
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
app="$REPO_PKG_NAME"           # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Install Crudini
apt-get install crudini -y

# Install vainfo
apt-get install vainfo -y

# Installing Ruby
apt-get install ruby-full -y

# Install bc
apt-get install bc -y

# Install MKVToolNix
wget -q --show-progress -O /usr/share/keyrings/gpg-pub-moritzbunkus.gpg https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg
apt-get update -y
apt-get install mkvtoolnix mkvtoolnix-gui -y

# Install FFmpeg
apt-get install ffmpeg -y

# Install Mediainfo
apt-get install mediainfo -y

# Install MPV
apt-get install mpv -y

# Install MPV
apt-get install inotify-tools -y

# Install Translate
apt-get install translate-shell -y

# Check Intel hardware
if lscpu | grep -q "Vendor ID:\s*GenuineIntel"; then
  # Install encoder kernels
  # apt-get install i965-va-driver-shaders -y
  apt-get install intel-media-va-driver-non-free -y
  # apt-get install libva-intel-vaapi-driver -y

  # Try to load the iHD driver, on fail use i965 driver
  if vainfo 2>&1 | grep -q '^.*iHD_drv_video\.so$'; then
    # If iHD fails, set the driver to i965
    if vainfo 2>&1 | grep -q '^.*dri/iHD_drv_video\.so.*failed$'; then
      # Permanently set the driver to iHD
      echo "export LIBVA_DRIVER_NAME=i965" >> ~/.bashrc
      echo "export LIBVA_DRIVER_NAME=i965" >> /home/$app_uid/.bashrc
      source ~/.bashrc
      su $app_uid -c "source ~/.bashrc"
    else
      # If pass, permanently set the driver to iHD
      echo "export LIBVA_DRIVER_NAME=iHD" >> ~/.bashrc
      echo "export LIBVA_DRIVER_NAME=iHD" >> /home/$app_uid/.bashrc
      source ~/.bashrc
      su $app_uid -c "source ~/.bashrc"
    fi 
  else
    # Permanently set the driver to i965
    echo "export LIBVA_DRIVER_NAME=i965" >> ~/.bashrc
    echo "export LIBVA_DRIVER_NAME=i965" >> /home/$app_uid/.bashrc
    source ~/.bashrc
    su $app_uid -c "source ~/.bashrc"
  fi
fi


# Check AMD hardware
if lscpu | grep -q "Vendor ID:\s*AuthenticAMD"; then
  # Install encoder kernels
  apt install build-essential dkms -y
  wget https://repo.radeon.com/amdgpu-install/22.40.3/ubuntu/jammy/amdgpu-install_5.4.50403-1_all.deb
  apt-get install ./amdgpu-install_5.3.50300-1_all.deb -y
  apt-get update
  amdgpu-install -y --accept-eula --opencl=legacy --headless --no-dkms --no-32 -y
  apt-get install libva-mesa-driver libva-dev -y
fi

#---- Install Don Melton Other Video Transcoding
gem install other_video_transcoding
echo "PATH="$PATH:/usr/local/bin/other-transcode"" >> ~/.bashrc
echo "PATH="/usr/local/bin:$PATH"" >> ~/.bashrc

#---- Install Vidcoderr
# Create CT vidcoder dir
mkdir -p /usr/local/bin/vidcoderr
chown $app_uid:$app_guid /usr/local/bin/vidcoderr

# Copy config files to /usr/local/bin/vidcoderr
cp $DIR/config/*.sh $DIR/config/*.ini /usr/local/bin/vidcoderr/

# Copy SimpleHTTPServerWithUpload scripts to /usr/local/bin/vidcoderr
cp $DIR/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.sh /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.sh
cp $DIR/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.py /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.py

# Copy filters to /usr/local/bin/vidcoderr
cp $DIR/config/video_format_filter.txt /usr/local/bin/vidcoderr/video_format_filter.txt
cp $DIR/config/other_format_filter.txt /usr/local/bin/vidcoderr/other_format_filter.txt
cp $DIR/config/exclude_file_filter.txt /usr/local/bin/vidcoderr/exclude_file_filter.txt
cp $DIR/config/exclude_dir_filter.txt /usr/local/bin/vidcoderr/exclude_dir_filter.txt
cp $DIR/config/subtitle_format_filter.txt /usr/local/bin/vidcoderr/subtitle_format_filter.txt

# Copy global control list template to /usr/local/bin/vidcoderr
cp $DIR/config/vidcoderr_control_list.tmpl /usr/local/bin/vidcoderr/vidcoderr_control_list.tmpl

# Set ownership & rights
chmod a+rx /usr/local/bin/vidcoderr/*.ini /usr/local/bin/vidcoderr/*.sh /usr/local/bin/vidcoderr/*.py
chown $app_uid:$app_guid /usr/local/bin/vidcoderr/*.sh
chown $app_uid:$app_guid /usr/local/bin/vidcoderr/*.txt
chown $app_uid:$app_guid /usr/local/bin/vidcoderr/*.tmpl
chown $app_uid:$app_guid /usr/local/bin/vidcoderr/*.ini

# Copy to 'transcode/vidcoderr' dir
if [ ! -f "/mnt/transcode/vidcoderr/vidcoderr_control_list.txt" ]
then
  sudo -u $app_uid cp "/usr/local/bin/vidcoderr/vidcoderr_control_list.tmpl" "/mnt/transcode/vidcoderr/vidcoderr_control_list.txt"
fi

# Setup vidcoderr_watchdir log
cat << 'EOF' > /etc/logrotate.d/vidcoderr_watchdir
/usr/local/bin/vidcoderr/watchdir.log
{
  rotate daily
  maxsize 1M
  rotate 0
}
EOF
chmod 644 /etc/logrotate.d/vidcoderr_watchdir
chown root:root /etc/logrotate.d/vidcoderr_watchdir
touch /usr/local/bin/vidcoderr/vidcoderr_watchdir.log
chown -R $app_uid:$app_guid /usr/local/bin/vidcoderr/vidcoderr_watchdir.log
chown -R $app_uid:$app_guid /etc/logrotate.d/vidcoderr_watchdir

# Copy Systemd services
cp $DIR/config/vidcoderr_watchdir_std.service /etc/systemd/system/vidcoderr_watchdir_std.service
cp $DIR/config/vidcoderr_watchdir_std.timer /etc/systemd/system/vidcoderr_watchdir_std.timer
cp $DIR/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.service /etc/systemd/system/SimpleHTTPServerWithUpload.service
cp $DIR/config/vidcoderr_inotify_std.service /etc/systemd/system/vidcoderr_inotify_std.service
#-----------------------------------------------------------------------------------