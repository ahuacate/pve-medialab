#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_linux_uninstall.sh
# Description:  Kodirsync Linux client uninstall script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Check if the crontab entry already exists in the crontab file
string="kodirsync_clientapp_run.sh"
crontab -l -u $user | grep -v "$string" | crontab - -u $user 2>/dev/null

# Remove kodirsync ssh & sslh keys
rm $ssh_dir/*_kodirsync_* 2> /dev/null
rm $ssh_dir/sslh* 2> /dev/null

# # Remove ssh key from ssh known_hosts
# sed -i "/^$.*_kodirsync_id_ed25519/d" $ssh_dir/known_hosts

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

# Remove Kodirsync installation directory
rm -rf "$app_dir" 2> /dev/null
#-----------------------------------------------------------------------------------