#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_uninstall_linux.sh
# Description:  Kodirsync Linux client uninstall script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
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
known_hosts_file="$ssh_dir/known_hosts"

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

# Remove "*_kodirsync_id_ed25519" entry from known_hosts
while IFS= read -r file
do
  # Skip iteration if no files found
  if [ -z "$file" ]
  then
    continue
  fi

  # Check if file content is in known_hosts
  # if grep -q -F "$(cat "$file")" "$known_hosts_file"
  if grep -q -F -f "$file" "$known_hosts_file"
  then
    # Remove matching entry from known_hosts
    sed -i "/$(cat "$file")/d" "$known_hosts_file" 2> /dev/null
  fi

  # Delete the matched file
  rm "$file" 2> /dev/null
done < <( find "$ssh_dir" -type f -name "*_kodirsync_id_ed25519" )


#---- Remove SSH keys

# Remove "*_kodirsync_id_ed25519"
rm $ssh_dir/.ssh/*_kodirsync_id_ed25519 2> /dev/null

# # Remove sslh-kodirsync.key
# rm $ssh_dir/sslh-kodirsync.key 2> /dev/null

# # Remove sslh.crt
# rm $ssh_dir/sslh.crt 2> /dev/null


#---- Umount any Kodirsync disk

# Check if the specified mount point exists and remove
if mount | grep -q "$mnt_point"; then
  # Umount the mount point
  umount -q "$mnt_point"
fi

# Check if the mount point exists in the fstab file
if grep -q "$mnt_point" /etc/fstab; then
  # Delete the mount point from the fstab file
  sed -i "/${mnt_point_regex}/d" /etc/fstab
fi


#---- Remove App dir

# Remove Kodirsync installation directory
rm -rf "$app_dir" 2> /dev/null
#-----------------------------------------------------------------------------------