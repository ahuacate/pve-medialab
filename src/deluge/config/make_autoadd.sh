#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     make_autoadd.sh
# Description:  Source script for creating Deluge autoadd.conf
# ----------------------------------------------------------------------------------

#---- Prerequisites
#---- Create 'autoadd.conf'

# Deluge autoadd basic default presets
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

# Start autoadd.conf file
echo '{
    "next_id": 2,
    "watchdirs": {}
}' > /tmp/autoadd.conf

# Add to autoadd.conf file
cnt=1
while IFS=':' read -r category destdir watchdir aliases ext
do
  # Create autoadd.conf
  if [ ! -z ${watchdir+x} ]
  then
    jq ".watchdirs += {\"${cnt}\": {"abspath": \"${watchdir}\","add_paused": "${add_paused}","add_paused_toggle": "${add_paused_toggle}","append_extension": "${append_extension}","append_extension_toggle": "${append_extension_toggle}","auto_managed": "${auto_managed}","auto_managed_toggle": "${auto_managed_toggle}","copy_torrent": "${copy_torrent}","copy_torrent_toggle": "${copy_torrent_toggle}","delete_copy_torrent_toggle": "${delete_copy_torrent_toggle}","download_location": \"${download_location}\","download_location_toggle": "${download_location_toggle}","enabled": "${enabled}","label": \"${category}\","label_toggle": "${label_toggle}","max_connections": "${max_connections}","max_connections_toggle": "${max_connections_toggle}","max_download_speed": "${max_download_speed}","max_download_speed_toggle": "${max_download_speed_toggle}","max_upload_slots": "${max_upload_slots}","max_upload_slots_toggle": "${max_upload_slots_toggle}","max_upload_speed": "${max_upload_speed}","max_upload_speed_toggle": "${max_upload_speed_toggle}","move_completed": "${move_completed}","move_completed_path": \"${move_completed_path}\","move_completed_toggle": "${move_completed_toggle}","owner": \"${owner}\","path": \"${watchdir}\","queue_to_top": "${queue_to_top}","queue_to_top_toggle": "${queue_to_top_toggle}","remove_at_ratio": "${remove_at_ratio}","remove_at_ratio_toggle": "${remove_at_ratio_toggle}","seed_mode": "${seed_mode}","stop_at_ratio": "${stop_at_ratio}","stop_at_ratio_toggle": "${stop_at_ratio_toggle}","stop_ratio": "${stop_ratio}","stop_ratio_toggle": "${stop_ratio_toggle}"}}" /tmp/autoadd.conf >> /tmp/autoadd.tmp.conf
    mv /tmp/autoadd.tmp.conf /tmp/autoadd.conf
    # add to cnt
    cnt=$(($cnt+1))
  fi
done <<< $(printf '%s\n' "${dlclient_category_LIST[@]}")

# Create autoadd.conf file
cat /tmp/autoadd.conf | sed -e '1s/^/\{\n  "file": 2,\n  "format": 1\n\}/' > /home/$app_uid/.config/deluge/autoadd.conf
chown "$app_uid":"$app_guid" /home/$app_uid/.config/deluge/autoadd.conf
#-----------------------------------------------------------------------------------