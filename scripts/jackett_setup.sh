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

# Download Jackett
msg "Downloading Jackett..."
cd /opt
sudo curl -L -O $( curl -s https://api.github.com/repos/Jackett/Jackett/releases | grep Jackett.Binaries.LinuxAMDx64.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) >/dev/null

# Install Jackett
msg "Installing Jackett..."
tar zxvf /opt/Jackett.Binaries.LinuxAMDx64.tar.gz >/dev/null
sudo rm /opt/Jackett.Binaries.LinuxAMDx64.tar.gz >/dev/null

# Create Jackett Service file
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


# Install hassio-cli
msg "Installing hassio-cli..."
docker pull homeassistant/amd64-hassio-cli >/dev/null
ARCH=$(dpkg --print-architecture)
HASSIO_CLI_PATH=/usr/sbin/hassio-cli
cat << EOF > $HASSIO_CLI_PATH
#!/bin/bash
set -o errexit

HASSIO_TOKEN=\$(jq --raw-output '.access_token' /usr/share/hassio/homeassistant.json)

docker container run --rm -it --init \
  --security-opt apparmor="docker-default" \
  -e HASSIO_TOKEN=\${HASSIO_TOKEN} \
  --network=hassio \
  --add-host hassio:172.30.32.2 \
  homeassistant/${ARCH}-hassio-cli \
  /bin/bash -c "sed -i '/HASSIO_TOKEN/ s/^/#/' /bin/cli.sh; /bin/cli.sh"
EOF
chmod +x $HASSIO_CLI_PATH

# Cleanup container
msg "Cleanup..."
rm -rf /setup.sh /var/{cache,log}/* /var/lib/apt/lists/*
