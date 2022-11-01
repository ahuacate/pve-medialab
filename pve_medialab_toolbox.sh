#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_toolbox.sh
# Description:  Toolbox script for Medialab apps
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#---- Source Github
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_toolbox.sh)"

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/pve-medialab/pve_medialab_toolbox.sh

#---- Source -----------------------------------------------------------------------

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

# Set Package Installer Temp Folder
REPO_TEMP='/tmp'
cd ${REPO_TEMP}

# Script path variables
DIR="${REPO_TEMP}/${GIT_REPO}"
SRC_DIR="${DIR}/src"
COMMON_DIR="${DIR}/common"
COMMON_PVE_SRC_DIR="${DIR}/common/pve/src"
SHARED_DIR="${DIR}/shared"
TEMP_DIR="${DIR}/tmp"

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

# Installer cleanup
function installer_cleanup () {
rm -R ${REPO_TEMP}/common &> /dev/null
rm -R ${REPO_TEMP}/${GIT_REPO} &> /dev/null
rm ${REPO_TEMP}/common.tar.gz &> /dev/null
rm ${REPO_TEMP}/${GIT_REPO}.tar.gz &> /dev/null
}

#---- Static Variables -------------------------------------------------------------

#---- Local Repo path (check if local)
# For local SRC a 'developer_settings.git' file must exist in repo dir
REPO_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P | sed "s/${GIT_USER}.*/${GIT_USER}/" )"

#---- Other Variables --------------------------------------------------------------

# List of Medialab CT default hostnames. Edit this list to control the available installer CT.
# First field must match GIT_APP_SCRIPT filename 'pve_medialab_ct_<name>_toolbox.sh'
ct_LIST=( "ahuabooks:reading and podcast listening"
"deluge:torrent client"
"flexget:multipurpose media automation tool"
"jackett:bittorrent indexer"
"jellyfin:media content server"
"kodisync-server:offline media synctool server for Kodi"
"kodisync-client:kodisync client toolbox"
"lidarr:music collection manager"
"nzbget:binary newsgrabber for nzb files"
"radarr:movie collection manager"
"sonarr:series collection manager (TV)"
"vidcoderr:automated video file transcoder" )

# Easy Script Section Header Body Text
SECTION_HEAD='PVE Medialab'

#---- Other Files ------------------------------------------------------------------

#---- Package loader
if [ -f ${REPO_PATH}/common/bash/src/pve_repo_loader.sh ] && [[ $(sed -n 's/^dev_git_mount=//p' ${REPO_PATH}/developer_settings.git 2> /dev/null) == '0' ]]; then
  # Download Local loader (developer)
  source ${REPO_PATH}/common/bash/src/pve_repo_loader.sh
else
  # Download Github loader
  wget -qL - https://raw.githubusercontent.com/${GIT_USER}/common/master/bash/src/pve_repo_loader.sh -O ${REPO_TEMP}/pve_repo_loader.sh
  chmod +x ${REPO_TEMP}/pve_repo_loader.sh
  source ${REPO_TEMP}/pve_repo_loader.sh
fi

#---- Body -------------------------------------------------------------------------
# Do not edit here down

#---- Run Bash Header
source ${COMMON_PVE_SRC_DIR}/pvesource_bash_defaults.sh

#---- Run Installer
while true; do
  section "PVE Medialab Toolbox"

  msg_box "#### SELECT A PRODUCT TOOLBOX ####\n\nSelect a product toolbox from the list or 'None - Exit this installer' to leave.\n\nAny terminal inactivity is caused by background tasks be run, system updating or downloading of Linux files. So be patient because some tasks can be slow."
  echo
  # Create menu list
  pct_LIST=( $(pct list | awk 'NR > 1 { OFS = ":"; print $NF,$1 }') )
  unset OPTIONS_VALUES_INPUT
  unset OPTIONS_LABELS_INPUT
  while IFS=':' read NAME DESC; do
    if [[ $(printf '%s\n' "${pct_LIST[@]}" | grep -Po "^${NAME,,}[.-]?[0-9]+?:[0-9]+$") ]] && [ -f "${SRC_DIR}/${NAME,,}/pve_medialab_ct_${NAME,,}_toolbox.sh" ]; then
      OPTIONS_VALUES_INPUT+=( "${NAME,,}:$(printf '%s\n' "${pct_LIST[@]}" | grep -Po "^${NAME,,}[_-]?[0-9]?:[0-9]+$" | awk -F':' '{ print $2 }')" )
      OPTIONS_LABELS_INPUT+=( "${NAME^} Toolbox - ${DESC^}" )
    fi
  done < <( printf '%s\n' "${ct_LIST[@]}" )
  OPTIONS_VALUES_INPUT+=( "TYPE00" )
  OPTIONS_LABELS_INPUT+=( "None - Exit this installer" ) 
  # Menu options
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  # Set App name
  if [ ${RESULTS} == 'TYPE00' ]; then
    # Exit installation
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    sleep 1
    break
  else
    # Set Hostname
    APP_NAME=$(echo ${RESULTS} | awk -F':' '{ print $1 }')

    # Set CTID
    CTID=$(echo ${RESULTS} | awk -F':' '{ print $2 }')

    # Check NAS run status
    pct_start_waitloop

    # Set Installer App script name
    GIT_APP_SCRIPT="pve_medialab_ct_${APP_NAME}_toolbox.sh"

    #Run Installer
    source ${SRC_DIR}/${APP_NAME}/${GIT_APP_SCRIPT}
  fi

  # Reset Section Head
  SECTION_HEAD='PVE Medialab'
done

#---- Finish Line ------------------------------------------------------------------

#---- Cleanup
installer_cleanup