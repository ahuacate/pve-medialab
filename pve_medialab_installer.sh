#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_installer.sh
# Description:  Installer script for PVE Homelab
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#---- Source Github
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/main/pve_medialab_installer.sh)"

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/pve-medialab/pve_medialab_installer.sh

#---- Installer Vars ---------------------------------------------------------------

# Git server
GIT_SERVER='https://github.com'
# Git user
GIT_USER='ahuacate'
# Git repository
GIT_REPO='pve-medialab'
# Git branch
GIT_BRANCH='main'
# Git common
GIT_COMMON='0'

# Edit this list to set installer products.
# vm_LIST=( "name:build:vm_type:desc" )
# name        ---> name of the main application
# build_model ---> build model/version of the name (i.e omv build version for a nas)
# vm_type     ---> 'vm' or 'ct'
# desc        ---> description of the main application name
# Sample: vm_LIST=( "pihole:pihole:ct:DNS sinkhole with optional dhcp server"
# "ddclient:ddclient:ct:dynamic dns updater"
# "guacamole:guacamole:ct:clientless remote desktop gateway" )
# Fields must match GIT_APP_SCRIPT dir and filename:
# i.e .../<build_type>/${GIT_REPO}_<vm_type>_<app_name>_installer.sh '(i.e .../ubuntu/pve_nas_ct_nas_installer.sh')
vm_LIST=( "deluge:deluge:ct:deluge torrent downloader"
"jellyfin:jellyfin:ct:jellyfin media server"
"lidarr:lidarr:ct:lidarr music collection manager"
"nzbget:nzbget:ct:nzbget usenet downloader"
"prowlarr:prowlarr:ct:prowlarr index manager"
"radarr:radarr:ct:radarr movie collection manager"
"readarr:readarr:ct:readarr book collection manager"
"sonarr:sonarr:ct:sonarr series collection manager"
"vidcoderr:vidcoderr:ct:video transcoder application"
"whisparr:whisparr:ct:naughty movie collection manager"
"kodirsync:kodirsync:ct:remote media library synchronizing tool"
"flexget:flexget:ct:flexget & filebot rss downloader (documentary manager)" )

#-----------------------------------------------------------------------------------
# NO NOT EDIT HERE DOWN
#---- Dependencies -----------------------------------------------------------------

# Internet connectivity check
# Checking multiple urls incase one is blocked
url_check_LIST=(
  "google.com:443"
  "github.com:443"
  )
# Set a counter to keep track
cnt=0
while IFS=':' read -r url port
do
  cnt=$((cnt + 1))
  # Use the nc command to connect to the hostname and port
  # (0 is UP, other is down)
  nc -zw1 $url $port 2> /dev/null
  if [ $? = 1 ]
  then
    # Print a fail message if it is the last url
    if [[ "$cnt" == ${#url_check_LIST[@]} ]]
    then
      echo "Checking for internet connectivity..."
      echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your PVE hosts internet connection and try again..."
      echo
      exit 0
    fi
    # Try another url
    continue
  else
    # Url passes
    break
  fi
done< <( printf '%s\n' "${url_check_LIST[@]}" )

#---- Static Variables -------------------------------------------------------------

#---- Set Package Installer Temp Folder
REPO_TEMP='/tmp'
cd "$REPO_TEMP"

#---- Local Repo path (check if local)
# For local SRC a 'developer_settings.git' file must exist in repo dir
REPO_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P | sed "s/${GIT_USER}.*/${GIT_USER}/" )"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

#---- Package loader
if [ -f "$REPO_PATH/common/bash/src/pve_repo_loader.sh" ] && [[ $(sed -n 's/^dev_git_mount=//p' $REPO_PATH/developer_settings.git 2> /dev/null) == '0' ]]
then
  # Download Local loader (developer)
  source $REPO_PATH/common/bash/src/pve_repo_loader.sh
else
  # Download Github loader
  wget -qL - https://raw.githubusercontent.com/${GIT_USER}/common/main/bash/src/pve_repo_loader.sh -O $REPO_TEMP/pve_repo_loader.sh
  chmod +x "$REPO_TEMP/pve_repo_loader.sh"
  source $REPO_TEMP/pve_repo_loader.sh
fi

#---- Body -------------------------------------------------------------------------

#---- Run Installer
source $REPO_PATH/$GIT_REPO/common/bash/src/pve_repo_installer_main.sh
#-----------------------------------------------------------------------------------