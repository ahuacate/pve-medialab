#!/bin/ash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_kodirsync_clientapp_installer.sh
# Description:  Kodirsync script for installing client app
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_kodirsync_clientapp_installer.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your devices internet connection and try again..."
  echo
  exit 0
fi

# Terminal
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'
printf '\033[8;40;120t'

# Bash Messaging Functions
function warn() {
  local REASON="\e[97m$1\e[39m"
  local FLAG="\e[93m[WARNING]\e[39m"
  msg "$FLAG $REASON"
}
function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg "$FLAG $REASON"
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function indent() {
  sed 's/^/  /';
}
# Cleanup
function cleanup() {
  cd ..
  rm -rf $TEMP_DIR
  cd ~
  unset TEMP_DIR
}

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

# OS Type
OSTYPE=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
# Mount Point
if [ ${OSTYPE} = '"coreelec"' ] || [ ${OSTYPE} = '"libreelec"' ]; then
  SRC_FILE='/storage/backup/kodirsync_installerpackage.tar.gz'
else
  SRC_FILE='/tmp/kodirsync_installerpackage.tar.gz'
fi

#---- Other Variables --------------------------------------------------------------

#---- Other Files ------------------------------------------------------------------

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Unzip installation files
if [ -f "${SRC_FILE}" ]; then
  echo "Tar extract 'kodirsync_installerpackage.tar.gz' package to : ${YELLOW}$(pwd)${NC}"
  tar -xv -z -f ${SRC_FILE} > /dev/null
  pwd
  ls -al
  echo
else
  warn "Your Kodirsync installation package $(echo ${SRC_FILE}) is missing.\nCopy 'kodirsync_installerpackage.tar.gz' to your ${OSTYPE^} machine\nfolder location : ${YELLOW}$(dirname ${SRC_FILE})${NC}.\nThen try again ..."
  exit 0
fi

# Run
chmod +x pve_medialab_ct_kodirsync_clientappbuilder.sh
sh pve_medialab_ct_kodirsync_clientappbuilder.sh

# Cleanup
cleanup