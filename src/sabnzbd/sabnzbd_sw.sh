#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     sabnzbd_sw.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
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
add-apt-repository multiverse -y
add-apt-repository universe -y
add-apt-repository ppa:jcfp/nobetas -y

# Perform update & upgrade
apt-get update -y
apt-get dist-upgrade -y

# Install Crudini
apt-get install crudini -y

# Install Zip/7zip/unrar
apt-get install p7zip-full p7zip-rar -y

# Install par2-turbo
add-apt-repository ppa:jcfp/sab-addons -y
apt-get update -y
apt-get install par2-turbo -y


#---- Install SABnzbd

# Install SW
apt-get install sabnzbdplus -y

# Modify SABnzbd config file
crudini --set /etc/default/sabnzbdplus "" USER $app_uid:$app_guid
crudini --set /etc/default/sabnzbdplus "" PORT 8080
crudini --set /etc/default/sabnzbdplus "" HOST 0.0.0.0

# Start SABnzbd
sudo systemctl daemon-reload
# SABnzbd uses a non-standard method to start SAB. Func scripts do not work.
if [ "$(systemctl is-active sabnzbdplus)" = 'inactive' ]
then
  # Start service
  sudo service sabnzbdplus start
  # Waiting to hear from service
  while ! [[ "$(systemctl is-active sabnzbdplus)" == 'active' ]]
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