#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_kodi_install_favorites.sh
# Description:  Setup Kodi run cmds in Kodi favorite menu
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Kodi favourites.xml file 
xml_file="/storage/.kodi/userdata/favourites.xml"

# Check for favourites.xml file
if [ ! -f "$xml_file" ]
then
  # Create favourites.xml file if missing
  echo -e "<favourites>\n</favourites>" > $xml_file
fi


#---- Copy files to Kodi addons dir

# Make script folder
script_dir='/storage/.kodi/addons/script.module.kodirsync'
mkdir -p $script_dir

# Copy python files to addons dir
kodi_files=(
  kodirsync_clientapp_kodi_run.py
  kodirsync_clientapp_kodi_gitupdater.py
  kodirsync_clientapp_kodi_status.py
  kodi_icon_start.png
  kodi_icon_stop.png
  kodi_thumb_start.png
  kodi_thumb_updater.png
  kodi_thumb_status.png
)
for file in "${kodi_files[@]}"; do
  # Copy file
  cp -f "$app_dir/$file" "$script_dir/" 2> /dev/null

  # Set permissions
  if [[ "$file" =~ \.(sh|py)$ ]]
  then
    chmod +x "$script_dir/$file" 2> /dev/null
  fi
done


#---- Create entries in favourites.xml

# Add 'Kodirsync start' cmd to Kodi favourites
entry="<favourite name=\"Kodirsync start\" thumb=\"$script_dir/kodi_thumb_start.png\">RunScript($script_dir/kodirsync_clientapp_kodi_run.py)</favourite>"
# Check if 'Kodirsync run' already exists in the file
if ! grep -q "<favourite name=\"Kodirsync start\"" "$xml_file"; then
  # Add the new entry at the end of the file
  sed -i "\$i$entry" "$xml_file"
  echo "New entry added to XML file '$xml_file':"
  tail -n 4 "$xml_file"
else
  echo "New entry already exists in XML file '$xml_file'. No changes made."
fi

# Add 'Kodirsync status' cmd to Kodi favourites
entry="<favourite name=\"Kodirsync status\" thumb=\"$script_dir/kodi_thumb_status.png\">RunScript($script_dir/kodirsync_clientapp_kodi_status.py)</favourite>"
# Check if 'Kodirsync run' already exists in the file
if ! grep -q "<favourite name=\"Kodirsync status\"" "$xml_file"; then
  # Add the new entry at the end of the file
  sed -i "\$i$entry" "$xml_file"
  echo "New entry added to XML file '$xml_file':"
  tail -n 4 "$xml_file"
else
  echo "New entry already exists in XML file '$xml_file'. No changes made."
fi

# Add 'Kodirsync sw updater' cmd to Kodi favourites
entry="<favourite name=\"Kodirsync sw updater\" thumb=\"$script_dir/kodi_thumb_updater.png\">RunScript($script_dir/kodirsync_clientapp_kodi_gitupdater.py)</favourite>"
# Check if 'Kodirsync run' already exists in the file
if ! grep -q "<favourite name=\"Kodirsync sw updater\"" "$xml_file"; then
  # Add the new entry at the end of the file
  sed -i "\$i$entry" "$xml_file"
  echo "New entry added to XML file '$xml_file':"
  tail -n 4 "$xml_file"
else
  echo "New entry already exists in XML file '$xml_file'. No changes made."
fi


#---- Restart Kodi

systemctl restart kodi
#-----------------------------------------------------------------------------------