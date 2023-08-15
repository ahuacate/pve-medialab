#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_common_copyfiles.sh
# Description:  Copy Kodirsync application files to client
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Move Kodirsync files to '$app_dir' and '$ssh_dir'

# Create 'app_dir' installation dir
mkdir -p "$app_dir"
chmod 775 "$app_dir"
chown -R "$user:$user_grp" "$app_dir"

# Create '$known_hosts_file' if missing
known_hosts_file="$ssh_dir/known_hosts"
if [ ! -f "$known_hosts_file" ]
then
  # Create the known_hosts file
  touch "$known_hosts_file"

  # Set the appropriate ownership and permissions
  chmod 600 "$known_hosts_file"
  chown "$user:$user_grp" "$known_hosts_file"
fi

# Remove old Kodirsync entry(s) in $known_hosts file
# Get the Kodirsync server hostname and IP 
hostname_id_LIST=( "$(sed -n "s/^localdomain_address_url=\(['\"]\?\)\(.*\)\1/\2/p" "$selftar_dir/kodirsync_clientapp_user.cfg")" )
hostname_id_LIST+=( "$(sed -n "s/^localdomain_address_url=\(['\"]\?\)\([^\.]*\)\..*$/\2/p" "$selftar_dir/kodirsync_clientapp_user.cfg")" )
hostname_id_LIST+=( "$(sed -n "s/^local_ip_address=\(.*\)/\1/p" $selftar_dir/kodirsync_clientapp_user.cfg)" )
for entry in "${hostname_id_LIST[@]}"
do
  # Remove entry
  ssh-keygen -f "$known_hosts_file" -R "$entry"
done

# Remove old Kodirsync user ssh keys
while IFS= read -r file
do
  # Skip iteration if no files found
  if [ -z "$file" ]
  then
    continue
  fi

  # Delete the matched file
  rm -f "$file" 2> /dev/null
done < <( find "$ssh_dir" -type f -name "*_kodirsync_id_ed25519" )

# Create exclude array of certain filenames
exclude_files=(
  "-iname install.sh"
  "-o -iname kodirsync_clientapp_install_common_cron.sh"
  "-o -iname kodirsync_clientapp_install_format_disk_ext4.sh"
  "-o -iname kodirsync_clientapp_install_format_disk_exfat.sh"
  "-o -iname kodirsync_clientapp_install_elec.sh"
  "-o -iname kodirsync_clientapp_install_elec_entware.sh"
  "-o -iname kodirsync_clientapp_uninstall_elec.sh"
  "-o -iname kodirsync_clientapp_install_linux.sh"
  "-o -iname kodirsync_clientapp_uninstall_linux.sh"
  "-o -iname kodirsync_clientapp_install_linux_storage.sh"
  "-o -iname kodirsync_clientapp_kodi_install_favorites.sh"
  "-o -iname Start-Kodirsync.sh"
  "-o -iname Stop-Kodirsync.sh"
  "-o -iname Start-Kodirsync.png"
  "-o -iname Stop-Kodirsync.png"
  "-o -iname Update-Widget.bash"
)

# Copy App files to $app_dir
find "$selftar_dir" -type f \( -iname "*.sh" -o -iname "*.cfg" -o -iname "*.py" \) -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec chmod +x {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/$(basename "$1")"; fi' sh {} "$app_dir" \;
find "$selftar_dir" -type f -iname "*.txt" -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/$(basename "$1")"; fi' sh {} "$app_dir" \;

# Copy 'kodirsync_control_list' to $app_dir (rename)
find "$selftar_dir" -type f -iname "kodirsync_control_list.tmpl" -exec chown "$user:$user_grp" {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/kodirsync_control_list.txt"; fi' sh {} "$app_dir" \;
find "$selftar_dir" -type f -iname "kodirsync_control_list.tmpl" -exec chown "$user:$user_grp" {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/kodirsync_control_list.tmpl"; fi' sh {} "$app_dir" \;

# Copy sslh files to $app_dir
find "$selftar_dir" -type f \( -iname "*.crt" -o -name "*.key" \) -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec chmod 600 {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/$(basename "$1")"; fi' sh {} "$app_dir" \;
# Copy ssh files to $app_dir
find "$selftar_dir" -type f \( -iname "*_kodirsync_id_ed25519" -o -name "kodirsync_node_rsa_key.ppk" -o -name "kodirsync_node_rsa_key.pub" -o -name "kodirsync_node_rsa_key" \) -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec chmod 600 {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/$(basename "$1")"; fi' sh {} "$app_dir" \;

# Copy ssh files to $ssh_dir
find "$selftar_dir" -type f \( -iname "*_kodirsync_id_ed25519" -o -name "kodirsync_node_rsa_key" \) -not \( $(printf '%s\n' "${exclude_files[@]}") \) -exec chown $user:$user_grp {} \; -exec chmod 600 {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/$(basename "$1")"; fi' sh {} "$ssh_dir" \;

# Copy 'termux_widget' to $app_dir
mkdir -p "$app_dir/termux_widget"
find "$selftar_dir" -type f \( -iname "Start-Kodirsync.bash" -o -iname "Start-Kodirsync.png" -o -iname "Stop-Kodirsync.bash" -o -iname "Stop-Kodirsync.png" -o -iname "Update-Widget.bash" \) -exec chown $user:$user_grp {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/$(basename "$1")"; fi' sh {} "$app_dir/termux_widget" \;

# Copy kodi 'icon' and 'thumb' to $app_dir
find "$selftar_dir" -type f \( -iname "kodi_icon*.png" -o -iname "kodi_thumb*.png" \) -exec chown $user:$user_grp {} \; -exec sh -c 'if [ ! -f "$2/$(basename "$1")" ]; then cp -f "$1" "$2/$(basename "$1")"; fi' sh {} "$app_dir" \;
#-----------------------------------------------------------------------------------