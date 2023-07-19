#!/data/data/com.termux/files/usr/bin/bash
# ----------------------------------------------------------------------------------
# Filename:     Start-Kodirsync.bash
# Description:  Default Android widget 'Start-Kodirsync' script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Kodirsync default storage dir name
kodirsync_app_dir='kodirsync_app'

# Android/Termux exFAT dir
# Android exFAT path. Full path '/storage/XXXX-XXXX/Android/data/com.termux/files/$kodirsync_storage_dir'
android_path='Android/data/com.termux/files'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- Start Kodirsync

# Search for 'kodirsync_clientapp_run.sh' file
kodirsync_clientapp_run_src=$(find "/storage" \( -path "*/????-????/$android_path/$kodirsync_app_dir/*" -o -path "*/????-????/*/$kodirsync_app_dir/*" \) -name "kodirsync_clientapp_run.sh" -type f 2> /dev/null)

# Set ''kodirsync_clientapp_run.sh'' location
if [ -n "$kodirsync_clientapp_run_src" ]
then
  # Run 'kodirsync_clientapp_run.sh' script
  source "$kodirsync_clientapp_run_src"

  # Display msg
  echo "Kodirsync has finished. Bye..."

  # Exit & close Termux
  exit 0
else
  # File not found
  echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync file 'kodirsync_clientapp_run.sh' not found. Check your USB storage disk is connected with your Android file browser.\nBye...\n\e[39m"
  sleep 3

  # Exit & close Termux
  exit 0
fi
#-----------------------------------------------------------------------------------