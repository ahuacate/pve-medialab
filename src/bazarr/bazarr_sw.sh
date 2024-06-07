#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     bazarr_sw.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"       # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Add repository
apt-get install software-properties-common -y
add-apt-repository ppa:deadsnakes/ppa -y

# Perform update & upgrade
apt-get update -y
apt-get dist-upgrade -y

# Add Bazarr prerequisite apps
apt-get install 7zip python3-dev python3-pip python3-distutils unrar unzip zip -y
apt-get install libxml2-dev libxslt1-dev python3-dev python3-libxml2 python3-lxml unrar-free ffmpeg libatlas-base-dev -y

# Install Python
apt-get install python3.8 -y

# Install mediainfo
apt-get install mediainfo -y


#---- Install Bazarr

# Download latest release of Bazarr
wget https://github.com/morpheus65535/bazarr/releases/latest/download/bazarr.zip

# Create the Bazarr directory
mkdir /opt/bazarr
mkdir -p /opt/bazarr/data/backup $app_uid
chown -R $app_uid:$app_guid /opt/bazarr/data/backup
chmod 775 /opt/bazarr/data/backup
unzip bazarr.zip -d /opt/bazarr
cd /opt/bazarr

# Install the Python requirements:
python3 -m pip install --no-warn-script-location -r requirements.txt

# Chown user/group
chown -R $app_uid:$app_guid /opt/bazarr

# Copy system.d 'bazarr.service' unit
cp $DIR/config/bazarr.service /etc/systemd/system/

# Enable system.d service units
systemctl enable --quiet bazarr.service

# Starting system.d 'bazarr.service' unit
if [ "$(systemctl is-active bazarr.service)" == "inactive" ]
then
  systemctl start bazarr.service
  while ! [[ "$(systemctl is-active bazarr.service)" == "active" ]]
  do
    echo -n .
  done
fi


#---- Create App backup folder on NAS
if [ -d "/mnt/backup" ]; then
  su - $app_uid -c "mkdir -p /mnt/backup/$REPO_PKG_NAME"
fi
#-----------------------------------------------------------------------------------