#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_elec_uninstall.sh
# Description:  Kodirsync CoreElec/LibreElec client uninstall script
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
rm ~/.ssh/*_kodirsync_* 2> /dev/null
rm ~/.ssh/sslh* 2> /dev/null

# Remove ssh key from ssh known_hosts
sed -i "/^.*_kodirsync_id_ed25519/d" ~/.ssh/known_hosts

# Check if the specified mount point exists and remove
if mount | grep -q "$mnt_point"; then
    # Umount the mount point
    umount -l "$mnt_point"
fi
#-----------------------------------------------------------------------------------