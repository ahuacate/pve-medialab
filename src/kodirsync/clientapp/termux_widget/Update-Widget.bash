#!/data/data/com.termux/files/usr/bin/bash
# ----------------------------------------------------------------------------------
# Filename:     Update-Widget.bash
# Description:  Updates Android widget 'Start-Kodirsync' & 'Stop-Kodirsync' scripts
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Widget dirs
termux_tasks_dir='/data/data/com.termux/files/home/.shortcuts/tasks'
termux_shortcuts_dir='/data/data/com.termux/files/home/.shortcuts'
termux_icons_dir='/data/data/com.termux/files/home/.shortcuts/icons'

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
#---- Body

# Move widget scripts
find "/storage" \( -path "*/????-????/$android_path/$kodirsync_app_dir/termux_widget/*" -o -path "*/????-????/*/$kodirsync_app_dir/termux_widget/*" \) -type f -iname "*.bash" -not -name "Update-Widget.bash" -exec cp -f {} "$termux_shortcuts_dir/" \; 2>/dev/null

# Move widget icons
find "/storage" \( -path "*/????-????/$android_path/$kodirsync_app_dir/termux_widget/*" -o -path "*/????-????/*/$kodirsync_app_dir/termux_widget/*" \) -type f -iname "*.png" -exec cp -f {} "$termux_icons_dir/" \; 2>/dev/null

# Exit & close Termux
exit 0
#-----------------------------------------------------------------------------------