#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_common_cron.sh
# Description:  Default Kodirsync client cron entry
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Create new Cron file to run 'kodirsync_clientapp_run.sh'

# Construct the crontab entry
crontab_entry="$cron_run_time su - $user -c $app_dir/kodirsync_clientapp_run.sh"

# Check if the crontab file exists, create a blank one if not
if ! crontab -l >/dev/null 2>&1; then
  echo "" | crontab -
fi

# Check if the crontab entry already exists in the crontab file
existing_entry=$(crontab -l | grep -F "$app_dir/kodirsync_clientapp_run.sh")

# If the crontab entry does not exist, add it to the crontab file
if [ -z "$existing_entry" ]; then
  crontab -l | { cat; echo "$crontab_entry"; } | crontab - 2>/dev/null
  echo "Cron job added"
else
  # Edit the existing entry
  string="kodirsync_clientapp_run.sh"
  crontab -l -u $user | grep -v "$string" | crontab - -u $user 2>/dev/null  # write out current crontab
  crontab -l | { cat; echo "$crontab_entry"; } | crontab - 2>/dev/null
  echo "Cron job updated"
fi
#-----------------------------------------------------------------------------------