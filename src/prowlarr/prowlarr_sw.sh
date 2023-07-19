#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     prowlarr_sw.sh
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

# Install Python
apt-get install python3 -y
apt-get install python3-pip -y
apt-get install python3.10-venv -y

# Install Git
apt-get install git -y

# Install Crudini
apt-get install crudini -y


#---- Install FlareSolverr

# Install SW
apt-get install xvfb -y
apt-get install -y libappindicator1 fonts-liberation -y
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg -i google-chrome*.deb 2> /dev/null
apt-get install -f -y
dpkg -i google-chrome*.deb
git -C /opt clone https://github.com/FlareSolverr/FlareSolverr.git
chown $app_uid:$app_guid /opt/FlareSolverr
su -s /bin/bash $app_uid -c "mkdir -m 775 -p /opt/FlareSolverr"
su -s /bin/bash $app_uid -c "python3 -m venv /opt/FlareSolverr"
su -s /bin/bash $app_uid -c "cd /opt/FlareSolverr && . /opt/FlareSolverr/bin/activate && /opt/FlareSolverr/bin/pip install -r requirements.txt"

# Copy system.d 'flexget.service' unit
cp $DIR/config/flaresolverr.service /etc/systemd/system/

# Enable system.d service units
systemctl enable --quiet flaresolverr.service

# Starting system.d 'flaresolverr.service' unit
if [ "$(systemctl is-active flaresolverr.service)" == "inactive" ]
then
  systemctl start flaresolverr.service
  while ! [[ "$(systemctl is-active flaresolverr.service)" == "active" ]]
  do
    echo -n .
  done
fi


#---- Create App backup folder on NAS
if [ -d "/mnt/backup" ]
then
  su - $app_uid -c "mkdir -p /mnt/backup/$REPO_PKG_NAME"
fi
#-----------------------------------------------------------------------------------