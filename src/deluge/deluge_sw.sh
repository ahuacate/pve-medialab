#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     deluge_sw.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $DIR/basic_bash_utility.sh

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"    # App name
app_uid="$APP_USERNAME"     # App UID
app_guid="$APP_GRPNAME"     # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create Deluge plugins folder
su - $app_uid -c "mkdir -p /home/$app_uid/.config/deluge"

#---- Installing Deluge

#Installing software-properties-common
apt-get install software-properties-common -y

# Installing Deluge
apt-get install -y deluged deluge-web deluge-console

# Create app .service with correct user startup
cat <<EOF | tee /etc/systemd/system/deluged.service >/dev/null
[Unit]
Description=Deluge Bittorrent Client Daemon
After=network-online.target

[Service]
Type=simple
User=$app_uid
Group=$app_guid
UMask=007
ExecStart=/usr/bin/deluged -d
KillMode=process
Restart=on-failure
# Configures the time to wait before service is stopped forcefully.
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | tee /etc/systemd/system/deluge-web.service >/dev/null
[Unit]
Description=Deluge Bittorrent Client Web Interface
After=network-online.target
Wants=deluged.service

[Service]
Type=simple
User=$app_uid
Group=$app_guid
UMask=027
ExecStart=/usr/bin/deluge-web -d
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Start the App
systemctl -q daemon-reload
systemctl enable --now -q deluged.service
systemctl enable --now -q deluge-web.service

#---- Create App backup folder on NAS
if [ -d "/mnt/backup" ]
then
 su - $app_uid -c "mkdir -p /mnt/backup/$REPO_PKG_NAME"
fi
#-----------------------------------------------------------------------------------