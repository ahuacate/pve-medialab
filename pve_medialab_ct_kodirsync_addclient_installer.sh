#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_kodirsync_addclient_installer.sh
# Description:  Installer script for add a Proxmox Kodirsync Server client
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_kodirsync_addclient_installer.sh)"

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your PVE hosts internet connection and try again..."
  echo
  exit 0
fi

# Set Temp Folder
if [ -z "${TEMP_DIR+x}" ]; then
  TEMP_DIR=$(mktemp -d)
  cd $TEMP_DIR >/dev/null
else
  if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR >/dev/null
  fi
fi

#---- Static Variables -------------------------------------------------------------

# Git server
GIT_SERVER='https://github.com'
# Git user
GIT_USER='ahuacate'
# Git repository
GIT_REPO='pve-medialab'
# Git branch
GIT_BRANCH='master'
# Git common
GIT_COMMON='0'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Download Git common
if [ ${GIT_COMMON} = 0 ]; then
  wget -qL - ${GIT_SERVER}/${GIT_USER}/common/archive/master.tar.gz -O common.tar.gz
  tar -zxf common.tar.gz
  mv common-master common
fi

#---- Body -------------------------------------------------------------------------

# Download packages
wget -qL - ${GIT_SERVER}/${GIT_USER}/${GIT_REPO}/archive/${GIT_BRANCH}.tar.gz -O ${GIT_REPO}.tar.gz
tar -zxf ${GIT_REPO}.tar.gz
mv ${GIT_REPO}-${GIT_BRANCH} ${GIT_REPO}

# Run Installer
source ${TEMP_DIR}/${GIT_REPO}/scripts/pve_medialab_ct_kodirsync_addclient.sh