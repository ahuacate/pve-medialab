#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     make_label.sh
# Description:  Source script for creating Deluge label.conf
# ----------------------------------------------------------------------------------

#---- Prerequisites
#---- Create 'label.conf'

# Deluge label basic default presets
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

# Start label.conf file
echo '{
  "labels": {},
  "torrent_labels": {}
}' > /tmp/label.conf

# Add to label.conf file
while IFS=':' read -r category destdir watchdir aliases ext
do
  # Create label.conf
  jq ".labels += {\"${category}\": {"apply_max": "${apply_max}","apply_move_completed": "${apply_move_completed}","apply_queue": "${apply_queue}","auto_add": "${auto_add}","auto_add_trackers": "${auto_add_trackers}","is_auto_managed": "${is_auto_managed}","max_connections": "${max_connections}","max_download_speed": "${max_download_speed}","max_upload_slots": "${max_upload_slots}","max_upload_speed": "${max_upload_speed}","move_completed": "${move_completed}","move_completed_path": \"${destdir}\","prioritize_first_last": "${prioritize_first_last}","remove_at_ratio": "${remove_at_ratio}","stop_at_ratio": "${stop_at_ratio}","stop_ratio": "${stop_ratio}"}}" /tmp/label.conf >> /tmp/label.tmp.conf
  mv /tmp/label.tmp.conf /tmp/label.conf
done < <( printf '%s\n' "${dlclient_category_LIST[@]}" )

# Edit manual labels
tmp=$(mktemp)
jq '.labels."manual-unsorted".move_completed = "true"' /tmp/label.conf > "$tmp" && mv "$tmp" /tmp/label.conf
jq '.labels."manual-movies".move_completed = "true"' /tmp/label.conf > "$tmp" && mv "$tmp" /tmp/label.conf
jq '.labels."manual-series".move_completed = "true"' /tmp/label.conf > "$tmp" && mv "$tmp" /tmp/label.conf
jq '.labels."manual-documentary-series".move_completed = "true"' /tmp/label.conf > "$tmp" && mv "$tmp" /tmp/label.conf
jq '.labels."manual-documentary-movies".move_completed = "true"' /tmp/label.conf > "$tmp" && mv "$tmp" /tmp/label.conf

# Create label.conf file
cat /tmp/label.conf | sed -e '1s/^/\{\n  "file": 1,\n  "format": 1\n\}/' > /home/$app_uid/.config/deluge/label.conf
chown "$app_uid":"$app_guid" /home/$app_uid/.config/deluge/label.conf
#-----------------------------------------------------------------------------------