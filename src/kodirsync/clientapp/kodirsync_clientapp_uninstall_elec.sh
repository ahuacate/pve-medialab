#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_uninstall_elec.sh
# Description:  Kodirsync CoreElec/LibreElec client uninstall script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Stop System.d Services
function stop_systemctl() {
  # Usage: stop_systemctl "name.service"
  local service_name="$1"
  if [ "$(systemctl is-active $service_name)" = 'active' ]
  then
    # Stop service
    systemctl stop $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'inactive' ]]
    do
      echo -n .
    done
  fi
}

# Start System.d Services
function start_systemctl() {
  # Usage: start_systemctl "name.service"
  local service_name="$1"
  # Reload systemd manager configuration
  systemctl daemon-reload
  if [ "$(systemctl is-active $service_name)" = 'inactive' ]
  then
    # Start service
    systemctl start $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'active' ]]
    do
      echo -n .
    done
  fi
}

#---- Body -------------------------------------------------------------------------

#---- Remove crontab entry

# Check if the crontab entry already exists & remove in the crontab file
string="kodirsync_clientapp_run.sh"
crontab -l -u $user | grep -v "$string" | crontab - -u $user 2>/dev/null


#---- Remove Kodirsync known_hosts entries
# Here we remove any entry in known_hosts which starts with '$sslh_address_url',
# '$pf_address_url', '$localdomain_address_url' or '$local_ip_address'.
# Also check for "*_kodirsync_id_ed25519" (depreciated)

# Set '$known_hosts_file'
known_hosts_file="~/.ssh/known_hosts"

# Initialize array
known_hosts_entry=()

# Run nslookup command and capture the output for $localdomain_address_url
output=$(nslookup "$localdomain_address_url" 2>/dev/null)
# Check if nslookup was successful
if [ $? -eq 0 ]
then
  known_hosts_entry=$(echo "$output" | awk '/^Address: / { print $2 }' | sed 's/[[:space:]]*$//')
fi

# Check if the '$sslh_address_url' variable is set
if [ -n "$sslh_address_url" ]
then
  known_hosts_entry+=( "$sslh_address_url" )
fi

# Check if the '$sslh_address_url' variable is set
if [ -n "$pf_address_url" ]
then
  known_hosts_entry+=( "$pf_address_url" )
fi

# Check if the '$sslh_address_url' variable is set
if [ -n "$local_ip_address" ]
then
  known_hosts_entry+=( "$local_ip_address" )
fi

# Loop through the IP addresses and delete matching entries from known_hosts file
for ip_address in "${known_hosts_entry[@]}"; do
  sed -i "/^$ip_address/d" $known_hosts_file
done

# # Remove "*_kodirsync_id_ed25519" entry from known_hosts
# while IFS= read -r file
# do
#   # Skip iteration if no files found
#   if [ -z "$file" ]
#   then
#     continue
#   fi

#   # Check if file content is in known_hosts
#   # if grep -q -F "$(cat "$file")" "$known_hosts_file"
#   if grep -q -F -f "$file" "$known_hosts_file"
#   then
#     # Remove matching entry from known_hosts
#     sed -i "/$(cat "$file")/d" "$known_hosts_file" 2> /dev/null
#   fi

#   # Delete the matched file
#   rm "$file" 2> /dev/null
# done < <( find "$ssh_dir" -type f -name "*_kodirsync_id_ed25519" )


#---- Remove SSH keys

# Remove "*_kodirsync_id_ed25519"
rm "$ssh_dir/.*_kodirsync_id_ed25519" 2> /dev/null

# Remove sslh-kodirsync.key
rm $ssh_dir/sslh-kodirsync.key 2> /dev/null

# Remove sslh.crt
rm $ssh_dir/sslh.crt 2> /dev/null

#---- Remove App dir

# # Remove Kodirsync installation directory
# app_dir=$(find / \( -path "*/$android_path/$kodirsync_app_dir" -o -path "*/$kodirsync_app_dir" \) -type d -print 2> /dev/null | sed '/^$/d' | uniq)
# rm -rf "$app_dir" 2> /dev/null

#---- Umount any Kodirsync disk

# Check if the specified mount point exists and remove
if mount | grep -q "$mnt_point"; then
  # Umount the mount point
  umount -l "$mnt_point"
fi


#---- Remove Samba share

# SMB conf file
smb_config_file="/storage/.config/samba.conf"

# Remove Kodirsync Share configuration
if [ -f "$smb_config_file" ]
then
    # Stop services
    stop_systemctl "nmbd.service"
    wait
    stop_systemctl "smbd.service"

  # Check if the Kodirsync Share section exists in the config file
  if grep -q "^\[Kodirsync_Share\]" "$smb_config_file"; then
    # Delete the Kodirsync Share section from the config file
    sed -i '/^\[Kodirsync_Share\]/,/^$/d' "$smb_config_file"

    # Restart services
    start_systemctl "nmbd.service"
    wait
    start_systemctl "smbd.service"
  fi
fi
#-----------------------------------------------------------------------------------