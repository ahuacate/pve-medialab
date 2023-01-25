#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     servarr_ct_sw.sh
# Description:  Source script for Servarr App CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"
installdir="/opt"              # {Update me if needed} Install Location
bindir="${installdir}/${app^}" # Full Path to Install Location
datadir="/var/lib/${app}/"       # {Update me if needed} AppData directory to use
app_bin=${app^}                # Binary Name of the app
app_uid=${APP_USERNAME}        # App UID
app_guid=${APP_GRPNAME}        # App GUID

# Application selector
if [ ${app} == 'lidarr' ]; then
    app_port="8686"                                          # Default App Port; Modify config.xml after install if needed
    app_prereq="curl sqlite3 libchromaprint-tools mediainfo" # Required packages
    app_umask="0002"                                         # UMask the Service will run as
    branch="master"                                          # {Update me if needed} branch to install
elif [ ${app} == 'prowlarr' ]; then
    app_port="9696"           # Default App Port; Modify config.xml after install if needed
    app_prereq="curl sqlite3" # Required packages
    app_umask="0002"          # UMask the Service will run as
    branch="develop"          # {Update me if needed} branch to install
elif [ ${app} == 'radarr' ]; then
    app_port="7878"           # Default App Port; Modify config.xml after install if needed
    app_prereq="curl sqlite3" # Required packages
    app_umask="0002"          # UMask the Service will run as
    branch="master"           # {Update me if needed} branch to install
elif [ ${app} == 'readarr' ]; then
    app_port="8787"           # Default App Port; Modify config.xml after install if needed
    app_prereq="curl sqlite3" # Required packages
    app_umask="0002"          # UMask the Service will run as
    branch="develop"          # {Update me if needed} branch to install
elif [ ${app} == 'whisparr' ]; then
    app_port="6969"           # Default App Port; Modify config.xml after install if needed
    app_prereq="curl sqlite3" # Required packages
    app_umask="0002"          # UMask the Service will run as
    branch="nightly"          # {Update me if needed} branch to install
fi

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

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
su -c "mkdir -p /mnt/backup/${app,,}" ${app_uid}


#---- Installing App

# Updating container OS
apt-get update -y

# Install Mediainfo
apt-get install mediainfo -y

# App Pre-requisites
apt-get install $app_prereq -y

# App download
ARCH=$(dpkg --print-architecture)
# get arch
dlbase="https://$app.servarr.com/v1/update/$branch/updatefile?os=linux&runtime=netcore"
case "$ARCH" in
"amd64") DLURL="${dlbase}&arch=x64" ;;
"armhf") DLURL="${dlbase}&arch=arm" ;;
"arm64") DLURL="${dlbase}&arch=arm64" ;;
*)
    echo "Arch not supported"
    exit 1
    ;;
esac
# Download installation files
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
#-----------------------------------------------------------------------------------