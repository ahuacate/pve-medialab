#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_termux.sh
# Description:  Termux installation script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Perform apt update
apt update -y

# Perform apt upgrade
apt upgrade -y


#---- Setup Termux Widgets

# Widget dirs
termux_tasks_dir='/data/data/com.termux/files/home/.shortcuts/tasks'
termux_shortcuts_dir='/data/data/com.termux/files/home/.shortcuts'
termux_icons_dir='/data/data/com.termux/files/home/.shortcuts/icons'

# Create Widget script dirs
if [ ! -d "$termux_shortcuts_dir" ]
then
  mkdir -p "$termux_shortcuts_dir"
  chmod 700 -R "$termux_shortcuts_dir"
fi
if [ ! -d "$termux_tasks_dir" ]
then
  mkdir -p "$termux_tasks_dir"
  chmod 700 -R "$termux_tasks_dir"
fi

# Widget script icon dir
if [ ! -d "$termux_icons_dir" ]
then
  mkdir -p "$termux_icons_dir"
  chmod -R a-x,u=rwX,go-rwx "$termux_icons_dir"
fi

# Move widget scripts
find "$DIR" -type f \( -iname "Start-Kodirsync.bash" -o -iname "Stop-Kodirsync.bash" -o -iname "Update-Widget.bash" \) -exec chown $user:$user_grp {} \; -exec chmod 700 {} \; -exec cp -f {} "$termux_shortcuts_dir/" \;

# Move widget icons
find "$DIR" -type f \( -iname "Start-Kodirsync.png" -o -iname "Stop-Kodirsync.png" \) -exec chown $user:$user_grp {} \; -exec chmod 0600 {} \; -exec cp -f {} "$termux_icons_dir/" \;

# DL Android widget APK (to default downloads dir)
if [ ! -f "$HOME/downloads/com.termux.widget_13.apk" ]
then
  curl -f -o $HOME/downloads/com.termux.widget_13.apk https://f-droid.org/repo/com.termux.widget_13.apk
fi
#-----------------------------------------------------------------------------------