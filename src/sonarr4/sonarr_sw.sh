#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     sonarr_sw.sh
# Description:  Source script for CT SW
#               This is Sonarr V4 develop install
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"       # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

app_port="8989"           # Default App Port; Modify config.xml after install if needed
app_prereq="curl sqlite3" # Required packages
app_umask="0002"          # UMask the Service will run as
branch="master"           # {Update me if needed} branch to install

# Constants
### Update these variables as required for your specific instance
installdir="/opt"              # {Update me if needed} Install Location
bindir="${installdir}/${app^}" # Full Path to Install Location
datadir="/var/lib/$app/"       # {Update me if needed} AppData directory to use
app_bin=${app^}                # Binary Name of the app


#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Installing Sonarr

#---- Prerequisites

# Stop the App if running
if service --status-all | grep -Fq "$app"; then
  systemctl stop $app
  systemctl disable $app.service
fi

# Create App Data folders
mkdir -p "$datadir"
mkdir -p "$datadir/Backups/manual"
chown -R "$app_uid":"$app_guid" "$datadir"
chmod 775 "$datadir"

# Create NAS backup folder
if [ -d "/mnt/backup" ]
then
    su - $app_uid -c "mkdir -p /mnt/backup/$app"
fi


#---- Installing App

# Updating container OS
apt-get update -y

# Install Mediainfo
apt-get install mediainfo -y

# App Pre-requisites
apt-get install $app_prereq -y

# Download installation files
DLURL=https://download.sonarr.tv/v4/develop/4.0.0.471/Sonarr.develop.4.0.0.471.linux-x64.tar.gz
wget --show-progress --content-disposition "$DLURL" -P /tmp
tar -xvzf /tmp/${app^}.*.tar.gz -C /tmp

# remove existing installs
# If you happen to run this script in the installdir the line below will delete the extracted files and cause the mv some lines below to fail.
rm -rf $bindir
mv "/tmp/${app^}" $installdir
chown "$app_uid":"$app_guid" -R "$bindir"
chmod 775 "$bindir"
rm -rf "/tmp/${app^}.*.tar.gz"
# Ensure we check for an update in case user installs older version or different branch
touch "$datadir"/update_required
chown "$app_uid":"$app_guid" "$datadir"/update_required

# Remove any previous app .service
rm -rf /etc/systemd/system/$app.service

# Create app .service with correct user startup
cat <<EOF | tee /etc/systemd/system/$app.service >/dev/null
[Unit]
Description=${app^} Daemon
After=syslog.target network.target
[Service]
User=$app_uid
Group=$app_guid
UMask=$app_umask
Type=simple
ExecStart=$bindir/$app_bin -nobrowser -data=$datadir
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

# Start the App
systemctl -q daemon-reload
systemctl enable --now -q "$app"


#---- Create App backup folder on NAS
if [ -d "/mnt/backup" ]
then
 su - $app_uid -c "mkdir -p /mnt/backup/$REPO_PKG_NAME"
fi
#-----------------------------------------------------------------------------------