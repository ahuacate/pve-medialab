#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     sonarr_sw.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"       # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Installing Sonarr
# Adding Sonarr key
gpg --no-default-keyring --keyring /usr/share/keyrings/sonarr-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8 &> /dev/null

# Adding mono repository list
echo "deb [arch=$( dpkg --print-architecture ) signed-by=/usr/share/keyrings/sonarr-archive-keyring.gpg] https://apt.sonarr.tv/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list > /dev/null

# Updating container OS
apt-get -y update > /dev/null

# Install Mediainfo
apt-get -y install mediainfo

# Install Sonarr software
echo "sonarr sonarr/owning_user string $app_uid" | debconf-set-selections
echo "sonarr sonarr/owning_group string $app_guid" | debconf-set-selections
DEBIAN_FRONTEND=non-interactive apt-get install -y sonarr
#-----------------------------------------------------------------------------------