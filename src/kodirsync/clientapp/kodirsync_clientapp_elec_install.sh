#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_elec.sh
# Description:  Default Kodirsync client run script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Create ssh file

# Create user ssh 'authorized_keys' file if doesn't exist
if [ -f "$ssh_dir/authorized_keys" ]
then
  sudo touch $ssh_dir/authorized_keys 2> /dev/null
  sudo chmod 600 $ssh_dir/authorized_keys
fi


#---- Create new Cron file to run 'kodirsync_clientapp_run.sh'

# Construct the crontab entry
crontab_entry="$cron_run_time sh $app_dir/kodirsync_clientapp_run.sh"

# Check if the crontab entry already exists in the crontab file
string="kodirsync_clientapp_run.sh"
crontab -l -u $user | grep -v "$string" | crontab - -u $user 2>/dev/null

# If the crontab entry does not exist, add it to the crontab file
(crontab -l -u $user; echo "$crontab_entry") | crontab -u $user -

# # Create a new  user profile
# if [[ ${ostype} =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]
# then
#   msg "You can create a new Kodi local user profile called 'Kodirsync' on this device to for\nyour new rsync media library."
#   while true; do
#     read -p "Do you want to create a 'Kodirsync' user profile [y/n]? " -n 1 -r YN
#     echo
#     case $YN in
#       [Yy]*)
#         echo "Coming soon..."
#         break
#         ;;
#       [Nn]*)
#         info "You have chosen not set up a 'Kodirsync' profile. You can always manually create\na local profile at your Kodi player station."
#         echo
#         break
#         ;;
#       *)
#         warn "Error! Entry must be 'y' or 'n'. Try again..."
#         echo
#         ;;
#     esac
#   done
# fi

#-----------------------------------------------------------------------------------------------------------------------