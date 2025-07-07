#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     geterr_sw.sh
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

# Modify '/etc/sudoers'
# Enable media to su to root without pwd
echo "$app_uid ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo -e "$app_uid ALL=(root) NOPASSWD: /bin/bash -c \"source /home/media/.flexget/cookbook/cookbook.sh\"" >> /etc/sudoers

# Create FlexGet dir(s)
su -s /bin/bash $app_uid -c "mkdir -m 775 -p /home/$app_uid/flexget"
su -s /bin/bash $app_uid -c "mkdir -m 775 -p /home/$app_uid/.flexget"

# Create FileBot dirs(s)
su -s /bin/bash $app_uid -c "mkdir -m 775 -p /home/$app_uid/filebot"

#---- Install Python3

# Install python3
apt-get install python3 -y
# apt-get install python3.8-venv -y 2> /dev/null
apt-get install python3.10-venv -y

# Install python3 venv (media)
su -s /bin/bash $app_uid -c "python3 -m venv ~/flexget/"

# Upgrade virtualenv tools
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install --upgrade pip setuptools"

# Install libtorrent
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install libtorrent"


#---- Install Guessit
apt-get install python3-guessit -y


#---- Install FlexGet

# Install Flexget
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install flexget"

# Install cloudscraper
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install cloudscraper"

# Install Deluge-client
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install deluge-client"

# Run Flexget activate
su -s /bin/bash $app_uid -c "source ~/flexget/bin/activate"
echo

#---- Install FileBot

# Install Java
apt-get install openjdk-18-jre-headless -y

# FileBot dependencies
apt-get --install-recommends install libmediainfo-dev -y
apt-get --install-recommends install -y mediainfo -y
apt-get install p7zip -y


# Install FileBot
su -s /bin/bash $app_uid -c "cd /home/$app_uid/filebot && curl -fsSL https://raw.githubusercontent.com/filebot/plugins/master/installer/tar.sh | sh -xu 2> /dev/null"
ln -sf /home/media/filebot/filebot.sh /usr/local/bin/filebot
su -s /bin/bash $app_uid -c "filebot -script fn:sysinfo"

#---- Create App backup folder on NAS

# Create backup dir on NAS
if [ -d "/mnt/backup" ]
then
  # Create backup dir 
  su -s /bin/bash $app_uid -c "mkdir -p /mnt/backup/$REPO_PKG_NAME"
fi
#-----------------------------------------------------------------------------------