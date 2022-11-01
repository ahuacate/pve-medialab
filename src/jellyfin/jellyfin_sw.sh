#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     jellyfin_sw.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"       # App name
app_uid=${APP_USERNAME}        # App UID
app_guid=${APP_GRPNAME}        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Installing Jellyfin

# Installing HTTPS transport for APT
apt-get install apt-transport-https curl gnupg -y

# Importing the GPG signing key (signed by the Jellyfin Team)
curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg

# Adding a Jellyfin repository list
echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main unstable" | sudo tee /etc/apt/sources.list.d/jellyfin.list

# Updating container OS (be patient, might take a while)
apt-get update -y

# Installing Jellyfin software
apt-get install jellyfin -y

# Stop the service
if [ $(systemctl is-active jellyfin.service) == "active" ]; then
  systemctl stop jellyfin.service
  # Wait for service is 'stopped'
  while true; do
    if [ $(systemctl is-active jellyfin.service) != "active" ]; then
      break
    fi
    sleep 2
  done
fi

# Edit the Jellyfin UID and GID
OLDUID=$(id -u jellyfin)
OLDGID=$(id -g jellyfin)
usermod -u 1605 jellyfin >/dev/null
groupmod -g 65605 jellyfin >/dev/null
usermod -s /bin/bash jellyfin >/dev/null
find / \( -path /mnt \) -prune -o -user "$OLDUID" -exec chown -h 1605 {} \; 2>/dev/null
find / \( -path /mnt \) -prune -o -group "$OLDGID" -exec chgrp -h 65605 {} \; 2>/dev/null

# Restart Jellyfin service
# Start the App
systemctl -q daemon-reload
systemctl enable --now -q jellyfin.service
#-----------------------------------------------------------------------------------