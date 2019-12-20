#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR:LXC] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  exit $EXIT
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}

# Prepare container OS
msg "Setting up container OS..."
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null
apt-get -y purge openssh-{client,server} >/dev/null
apt-get autoremove >/dev/null

# Update container OS
msg "Updating container OS..."
apt-get update >/dev/null
apt-get -qqy upgrade &>/dev/null

# Install prerequisites
msg "Installing prerequisites..."
apt-get -qqy install \
    python-urllib3 python3-openssl libcurl4-openssl-dev bzip2 subversion >/dev/null
sudo apt-get -y install curl >/dev/null

# Download Jackett
msg "Downloading Jackett..."
cd /opt
sudo curl -L -O $( curl -s https://api.github.com/repos/Jackett/Jackett/releases | grep Jackett.Binaries.LinuxAMDx64.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) >/dev/null

# Install Jackett
msg "Installing Jackett..."
tar zxvf /opt/Jackett.Binaries.LinuxAMDx64.tar.gz >/dev/null
sudo rm /opt/Jackett.Binaries.LinuxAMDx64.tar.gz >/dev/null

# Create Jackett home folders
msg "Creating Jackett home folders..."
mkdir -m 775 -p /home/media/.config/Jackett/Indexers
chown 1605:65605 /home/media/.config
chown 1605:65605 /home/media/.config/Jackett
chown 1605:65605 /home/media/.config/Jackett/Indexers

# Create Jackett Service file
msg "Creating Jackett service file..."
cat << EOF > /etc/systemd/system/jackett.service
[Unit]
Description=Jackett Daemon
After=network.target

[Service]
SyslogIdentifier=jackett
Restart=always
RestartSec=5
Type=simple
User=media
Group=medialab
Environment=XDG_CONFIG_HOME=/home/media/.config
WorkingDirectory=/opt/Jackett
ExecStart=/opt/Jackett/jackett --NoRestart
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
sleep 1
sudo systemctl enable jackett
sleep 1
sudo systemctl start jackett

# Stop Jackett
msg "Stopping Jackett..."
sudo systemctl stop jackett
sleep 5

# Set Jackett API key
#msg "Setting Jackett API key..."
#sed -i 's|"APIKey":.*|"APIKey": "s9tcqkddvjpkmis824pp6ucgpwcd2xnc",|g' /home/media/.config/Jackett/ServerConfig.json

# Downloading and Installing preconfigured Indexers
#msg "Installing preconfigured Jackett indexers..."
#svn checkout https://github.com/ahuacate/jackett/trunk/Indexers /home/media/.config/Jackett/Indexers
#chown 1605:65605 {/home/media/.config/Jackett/Indexers/*.json,/home/media/.config/Jackett/Indexers/*.bak}
#sudo systemctl restart jackett

# Cleanup container
#msg "Cleanup..."
#rm -rf /*_setup.sh /var/{cache,log}/* /var/lib/apt/lists/*
