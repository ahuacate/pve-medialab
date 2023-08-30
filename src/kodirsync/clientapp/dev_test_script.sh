#!/usr/bin/env bash

# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/main/src/kodirsync/clientapp/dev_test_script.sh)"

git_dl_user='ahuacate'
git_dl_repo='pve-medialab'
git_dl_branch='main'
filename=kodirsync_clientapp_gitupdater.sh
dl_dir=/var/media/kodirsync/kodirsync_app
curl --fail -o "$dl_dir/$filename" -f "https://raw.githubusercontent.com/$git_dl_user/$git_dl_repo/$git_dl_branch/src/kodirsync/clientapp/$filename"

rm -R /var/media/kodirsync/kodirsync_storage/video 2> /dev/null
rm -R /var/media/kodirsync/kodirsync_storage/rsync_tmp 2> /dev/null
rm -f /var/media/kodirsync/kodirsync_app/logs/*

python /storage/.kodi/addons/script.module.kodirsync/kodirsync_clientapp_kodi_gitupdater.py

rm -f /var/media/kodirsync/kodirsync_app/ray_script.sh
echo "bye ... rebooting"
reboot