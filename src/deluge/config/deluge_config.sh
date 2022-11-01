#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     deluge_config.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Install libcrack2
if [ $(dpkg -s jq >/dev/null 2>&1; echo $?) != 0 ]; then
  apt-get install jq -y
fi

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"       # App name
app_uid=${APP_USERNAME}        # App UID
app_guid=${APP_GRPNAME}        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Create 'dl_client_catergory_LIST'
dl_type='torrent'
unset dlclient_category_LIST
unset dirwatch_LIST
while IFS=':' read -r category destdir watchdir aliases ext; do
  [[ "$category" =~ ^\#.*$ ]] && continue
    # Create 'dl_client_catergory_LIST'
    dlclient_category_LIST+=( "${category}:$(eval echo "${destdir}"):$(eval echo "${watchdir}"):$(echo ${aliases} | sed 's/,/, /g'):${ext}" )
done < /tmp/dlclient_category_list.txt

#---- Body -------------------------------------------------------------------------

#---- Configure Deluge

# Fix Python warning related to gettext
sed -i "s/gettext.install(I18N_DOMAIN, translations_path, names='ngettext', \*\*kwargs)/gettext.install(I18N_DOMAIN, translations_path, names=\['ngettext'\], \*\*kwargs)/g" /usr/lib/python3/dist-packages/deluge/i18n/util.py

# Create Download folders
runuser ${app_uid} -c 'mkdir -p /mnt/downloads/torrent/{incomplete,complete}'
while IFS=':' read -r category destdir watchdir aliases ext; do
    # Create destination dir
    if ! [ -z ${destdir} ]; then
      runuser ${app_uid} -c "mkdir -p ${destdir}"
    fi
    # Create watch dir
    if ! [ -z ${watchdir} ]; then
      runuser ${app_uid} -c "mkdir -p ${watchdir}"
    fi
done <<< $(printf '%s\n' "${dlclient_category_LIST[@]}")

# Download Deluge plugins 
runuser ${app_uid} -c "wget --content-disposition https://forum.deluge-torrent.org/download/file.php?id=6597 -P /home/${app_uid}/.config/deluge/plugins/" # Autoremove Plus

# Configure Deluge Auth
echo -e "appconnect:ahuacate:10" >> /home/${app_uid}/.config/deluge/auth

# Set Deluge preferences
systemctl restart deluged.service
while true; do
    if [ $(systemctl is-active deluged.service) == "active" ]; then
    break
    fi
    sleep 1
done
su -c 'deluge-console "config -s allow_remote True"' ${app_uid}
su -c 'deluge-console "config -s max_active_downloading 20"' ${app_uid}
su -c 'deluge-console "config -s max_active_limit 20"' ${app_uid}
su -c 'deluge-console "config -s max_active_seeding 20"' ${app_uid}
su -c 'deluge-console "config -s max_connections_global 200"' ${app_uid}
su -c 'deluge-console "config -s remove_seed_at_ratio true"' ${app_uid}
su -c 'deluge-console "config -s stop_seed_at_ratio true"' ${app_uid}
su -c 'deluge-console "config -s stop_seed_ratio 1.5"' ${app_uid}
su -c 'deluge-console "plugin -e autoremoveplus"' ${app_uid}
su -c 'deluge-console "plugin -e label"' ${app_uid}
su -c 'deluge-console "plugin -e execute"' ${app_uid}
su -c 'deluge-console "plugin -e autoadd"' ${app_uid}

# Create 'label.conf'
# Deluge label presets
apply_max='false'
apply_move_completed='true'
apply_queue='false'
auto_add='false'
auto_add_trackers='[]'
is_auto_managed='false'
max_connections='-1'
max_download_speed='-1'
max_upload_slots='-1'
max_upload_speed='-1'
move_completed='true'
prioritize_first_last='false'
remove_at_ratio='false'
stop_at_ratio='false'
stop_ratio='2.0'

echo '{
  "labels": {},
  "torrent_labels": {}
}' > /tmp/label.conf
while IFS=':' read -r category destdir watchdir aliases ext; do
  # Create label.conf
  jq ".labels += {\"${category}\": {"apply_max": "${apply_max}","apply_move_completed": "${apply_move_completed}","apply_queue": "${apply_queue}","auto_add": "${auto_add}","auto_add_trackers": "${auto_add_trackers}","is_auto_managed": "${is_auto_managed}","max_connections": "${max_connections}","max_download_speed": "${max_download_speed}","max_upload_slots": "${max_upload_slots}","max_upload_speed": "${max_upload_speed}","move_completed": "${move_completed}","move_completed_path": \"${destdir}\","prioritize_first_last": "${prioritize_first_last}","remove_at_ratio": "${remove_at_ratio}","stop_at_ratio": "${stop_at_ratio}","stop_ratio": "${stop_ratio}"}}" /tmp/label.conf >> /tmp/label.tmp.conf
  mv /tmp/label.tmp.conf /tmp/label.conf
done <<< $(printf '%s\n' "${dlclient_category_LIST[@]}")
# Edit flexget labels
tmp=$(mktemp)
jq '.labels."flexget-movies".move_completed = "false"' /tmp/label.conf > "$tmp" &&  mv "$tmp" /tmp/label.conf
jq '.labels."flexget-series".move_completed = "false"' /tmp/label.conf > "$tmp" &&  mv "$tmp" /tmp/label.conf
jq '.labels."flexget-documentary".move_completed = "false"' /tmp/label.conf > "$tmp" &&  mv "$tmp" /tmp/label.conf
jq '.labels."flexget-movies".apply_move_completed = "false"' /tmp/label.conf > "$tmp" &&  mv "$tmp" /tmp/label.conf
jq '.labels."flexget-series".apply_move_completed = "false"' /tmp/label.conf > "$tmp" &&  mv "$tmp" /tmp/label.conf
jq '.labels."flexget-documentary".apply_move_completed = "false"' /tmp/label.conf > "$tmp" &&  mv "$tmp" /tmp/label.conf
# Create label.conf file
cat /tmp/label.conf | sed -e '1s/^/\{\n  "file": 1,\n  "format": 1\n\}/' > /home/${app_uid}/.config/deluge/label.conf
chown ${app_uid}:${app_guid} /home/${app_uid}/.config/deluge/label.conf

# Create 'autoadd.conf'
# Deluge 'autoadd' presets
add_paused='true'
add_paused_toggle='false'
append_extension='.added'
append_extension_toggle='false'
auto_managed='true'
auto_managed_toggle='false'
copy_torrent='""'
copy_torrent_toggle='false'
delete_copy_torrent_toggle='false'
download_location='/mnt/downloads/torrent/incomplete'
download_location_toggle='true'
enabled='true'
label_toggle='true'
max_connections='0'
max_connections_toggle='false'
max_download_speed='0'
max_download_speed_toggle='false'
max_upload_slots='0'
max_upload_slots_toggle='false'
max_upload_speed='0'
max_upload_speed_toggle='false'
move_completed='true'
move_completed_path=''
move_completed_toggle='true'
owner='localclient'
queue_to_top='true'
queue_to_top_toggle='false'
remove_at_ratio='true'
remove_at_ratio_toggle='false'
seed_mode='false'
stop_at_ratio='true'
stop_at_ratio_toggle='false'
stop_ratio='0'
stop_ratio_toggle='false'

echo '{
    "next_id": 2,
    "watchdirs": {}
}' > /tmp/autoadd.conf
cnt=1
while IFS=':' read -r category destdir watchdir aliases ext; do
  # Create label.conf
  if ! [ -z ${watchdir} ]; then
    jq ".watchdirs += {\"${cnt}\": {"abspath": \"${watchdir}\","add_paused": "${add_paused}","add_paused_toggle": "${add_paused_toggle}","append_extension": "${append_extension}","append_extension_toggle": "${append_extension_toggle}","auto_managed": "${auto_managed}","auto_managed_toggle": "${auto_managed_toggle}","copy_torrent": "${copy_torrent}","copy_torrent_toggle": "${copy_torrent_toggle}","delete_copy_torrent_toggle": "${delete_copy_torrent_toggle}","download_location": \"${download_location}\","download_location_toggle": "${download_location_toggle}","enabled": "${enabled}","label": \"${category}\","label_toggle": "${label_toggle}","max_connections": "${max_connections}","max_connections_toggle": "${max_connections_toggle}","max_download_speed": "${max_download_speed}","max_download_speed_toggle": "${max_download_speed_toggle}","max_upload_slots": "${max_upload_slots}","max_upload_slots_toggle": "${max_upload_slots_toggle}","max_upload_speed": "${max_upload_speed}","max_upload_speed_toggle": "${max_upload_speed_toggle}","move_completed": "${move_completed}","move_completed_path": \"${move_completed_path}\","move_completed_toggle": "${move_completed_toggle}","owner": \"${owner}\","path": \"${watchdir}\","queue_to_top": "${queue_to_top}","queue_to_top_toggle": "${queue_to_top_toggle}","remove_at_ratio": "${remove_at_ratio}","remove_at_ratio_toggle": "${remove_at_ratio_toggle}","seed_mode": "${seed_mode}","stop_at_ratio": "${stop_at_ratio}","stop_at_ratio_toggle": "${stop_at_ratio_toggle}","stop_ratio": "${stop_ratio}","stop_ratio_toggle": "${stop_ratio_toggle}"}}" /tmp/autoadd.conf >> /tmp/autoadd.tmp.conf
    mv /tmp/autoadd.tmp.conf /tmp/autoadd.conf
    # add to cnt
    cnt=$(($cnt+1))
  fi
done <<< $(printf '%s\n' "${dlclient_category_LIST[@]}")
# Create label.conf file
cat /tmp/autoadd.conf | sed -e '1s/^/\{\n  "file": 2,\n  "format": 1\n\}/' > /home/${app_uid}/.config/deluge/autoadd.conf
chown ${app_uid}:${app_guid} /home/${app_uid}/.config/deluge/autoadd.conf


# Other settings
if [ $(systemctl is-active deluged.service) == "active" ]; then
  systemctl stop deluged.service
  while true; do
  if [ $(systemctl is-active deluged.service) == "inactive" ]; then
    break
  fi
  sleep 1
  done
fi
sed -i 's/"download_location":.*/"download_location": "\/mnt\/downloads\/torrent\/incomplete",/g' /home/${app_uid}/.config/deluge/core.conf
sed -i 's/"daemon_port":.*/"daemon_port": 58846,/g' /home/${app_uid}/.config/deluge/core.conf

# Start the App
if [ $(systemctl is-active deluged.service) != "active" ]; then
  systemctl start deluged.service
  while true; do
  if [ $(systemctl is-active deluged.service) == "active" ]; then
    break
  fi
  sleep 1
  done
fi
#-----------------------------------------------------------------------------------