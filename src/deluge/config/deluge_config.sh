#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     deluge_config.sh
# Description:  Source script for configuring SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $DIR/basic_bash_utility.sh

# Install jq
if [[ ! $(dpkg -s jq 2>/dev/null) ]]
then
  apt-get install jq -y
fi

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"       # App name
app_uid="$APP_USERNAME"    # App UID
app_guid="$APP_GRPNAME"    # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create 'dl_client_category_LIST'
dl_type='torrent'
dlclient_category_LIST=()
while IFS=':' read -r category destdir watchdir aliases ext
do
  [[ "$category" =~ ^\#.*$ ]] && continue
    # Create 'dl_client_category_LIST'
    dlclient_category_LIST+=( "$category:$(eval echo "$destdir"):$(eval echo "$watchdir"):$(echo "$aliases" | sed 's/,/, /g'):$ext" )
done < /tmp/dlclient_category_list.txt

# Fix Python warning related to gettext
sed -i "s/gettext.install(I18N_DOMAIN, translations_path, names='ngettext', \*\*kwargs)/gettext.install(I18N_DOMAIN, translations_path, names=\['ngettext'\], \*\*kwargs)/g" /usr/lib/python3/dist-packages/deluge/i18n/util.py

# Create torrent folders on NAS 
if [ -d "/mnt/downloads" ]
then
  # Create torrent dl dirs
  su - $app_uid -c "mkdir -p /mnt/downloads/torrent/{incomplete,complete}"
  # Create label destination dirs
  while IFS=':' read -r category destdir watchdir aliases ext
  do
    # Create destination dir
    if [ -n "$destdir" ]
    then
      su - $app_uid -c "mkdir -p $destdir"
    fi
    # Create watch dir
    if [ -n "$watchdir" ]
    then
      su - $app_uid -c "mkdir -p $watchdir"
    fi
  done < <( printf '%s\n' "${dlclient_category_LIST[@]}" )
fi

# Create Deluge plugins folder
su - $app_uid -c "mkdir -p /home/$app_uid/.config/deluge"

#---- Download Deluge plugins

# Autoremove Plus
su - $app_uid -c "wget --content-disposition https://forum.deluge-torrent.org/download/file.php?id=6597 -P /home/$app_uid/.config/deluge/plugins/" 

#---- Configure Deluge

# Set Deluge 3rd party app connectivity credentials/auth
echo -e "appconnect:ahuacate:10" >> /home/$app_uid/.config/deluge/auth
echo -e "flexget:ahuacate:10" >> /home/$app_uid/.config/deluge/auth

# Create label.conf file
source $DIR/make_label.sh

# Create autoadd.conf file
source $DIR/make_autoadd.sh

# Restart service (rescan plugins)
pct_restart_systemctl "deluged.service"

# Set Deluge preferences
su -c 'deluge-console "config -s allow_remote True"' $app_uid
su -c 'deluge-console "config -s max_active_downloading 20"' $app_uid
su -c 'deluge-console "config -s max_active_limit 20"' $app_uid
su -c 'deluge-console "config -s max_active_seeding 20"' $app_uid
su -c 'deluge-console "config -s max_connections_global 200"' $app_uid
su -c 'deluge-console "config -s remove_seed_at_ratio true"' $app_uid
su -c 'deluge-console "config -s stop_seed_at_ratio true"' $app_uid
su -c 'deluge-console "config -s stop_seed_ratio 1.2"' $app_uid
su -c 'deluge-console "plugin -e autoremoveplus"' $app_uid
su -c 'deluge-console "plugin -e label"' $app_uid
su -c 'deluge-console "plugin -e execute"' $app_uid
su -c 'deluge-console "plugin -e autoadd"' $app_uid

# Stop service
pct_stop_systemctl "deluged.service"

# Edit config
sed -i 's/"download_location":.*/"download_location": "\/mnt\/downloads\/torrent\/incomplete",/g' /home/$app_uid/.config/deluge/core.conf
sed -i 's/"daemon_port":.*/"daemon_port": 58846,/g' /home/$app_uid/.config/deluge/core.conf

# Restart the service
pct_start_systemctl "deluged.service"
#-----------------------------------------------------------------------------------