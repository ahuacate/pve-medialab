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

# Check if the crontab entry already exists in the crontab file
string="kodirsync_clientapp_run.sh"
crontab -l -u $user | grep -v "$string" | crontab - -u $user 2>/dev/null

# If the crontab entry does not exist, add it to the crontab file
(crontab -l -u $user; echo "$crontab_entry") | crontab -u $user -
#-----------------------------------------------------------------------------------