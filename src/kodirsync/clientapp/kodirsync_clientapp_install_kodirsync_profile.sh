#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_kodirsync_profile.sh
# Description:  Creates the Kodirsync user profile on CoreELEC & LibreELEC
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Kodirsync default storage dir name
kodirsync_storage_dir='kodirsync_storage'

# Android/Termux exFAT dir
# Android exFAT path. Full path '/storage/XXXX-XXXX/Android/data/com.termux/files/$kodirsync_storage_dir'
android_path='Android/data/com.termux/files'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Kodirsync user profile name
user_profile='Kodirsync'

# Set the path to the profiles XML file
profiles_xml_file="/storage/.kodi/userdata/profiles.xml"

# Set the path to the sources XML file
sources_xml_file="/storage/.kodi/userdata/profiles/$user_profile/sources.xml"

# Search for priority '$dst_dir' location with '.kodirsync_storage' file
# Check Android exFAT mount path. Full path '/storage/XXXX-XXXX/Android/data/com.termux/files/'.
dst_dir_chk=$(find / \( -path "*/$android_path/$kodirsync_storage_dir" -o -path "*/$kodirsync_storage_dir" \) -type d -execdir sh -c '[ -e "$1/.kodirsync_storage" ]' sh {} \; -print 2> /dev/null)
# Set '$dst_dir' location
if [ -n "$dst_dir_chk" ] && [ -d "$dst_dir_chk" ]
then
  # Check if '$dst_dir' is 'media' mount
  if [[ "$dst_dir_chk" =~ ^/var/media/.*$ ]]
  then
    # Remove "/var" from $dst_dir_chk using sed
    dst_dir=$(echo "$dst_dir_chk" | sed 's|^/var||')
  else
    # Set $dist_dir
    dst_dir="$dst_dir_chk"
  fi
else
  # No storage dir found
  echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync storage destination directory not found. Run the Kodirsync installer before adding new Kodirsync profile to your Kodi player.\nBye...\n\e[39m"
  return
fi

# Check if the profile already exists in the XML file
if grep -q "<name>$user_profile</name>" "$profiles_xml_file"; then
  echo -e "\e[93m[WARNING]\e[39m \e[97mProfile $user_profile already exists in $profiles_xml_file.\nBye...\n\e[39m"
  return
fi


#---- Create new profile

# Get the current nextIdProfile value
next_id=$(awk -F'[<>]' '/<nextIdProfile>/{id=$3}END{print id}' "$profiles_xml_file")

# Increment the nextIdProfile value
new_id=$((next_id + 1))

# Create the new profile section
new_profile="<profile>
    <id>$new_id</id>
    <name>$user_profile</name>
    <directory pathversion="1">profiles/$user_profile/</directory>
    <thumbnail pathversion=\"1\"></thumbnail>
    <hasdatabases>true</hasdatabases>
    <canwritedatabases>true</canwritedatabases>
    <hassources>true</hassources>
    <canwritesources>true</canwritesources>
    <lockaddonmanager>false</lockaddonmanager>
    <locksettings>0</locksettings>
    <lockfiles>false</lockfiles>
    <lockmusic>false</lockmusic>
    <lockvideo>false</lockvideo>
    <lockpictures>false</lockpictures>
    <lockprograms>false</lockprograms>
    <lockgames>false</lockgames>
    <lockmode>0</lockmode>
    <lockcode></lockcode>
    <lastdate></lastdate>
</profile>"

# Update the nextIdProfile value
awk -v new_id="$new_id" -F'[<>]' '/<nextIdProfile>/{sub($3, new_id)}1' "$profiles_xml_file" > temp.xml
mv temp.xml "$profiles_xml_file"

# Insert the new profile section
awk -v profile="$new_profile" '/<\/profiles>/ { print profile; print $0; next }1' "$profiles_xml_file" > temp.xml
mv temp.xml "$profiles_xml_file"


#---- Create new profile userdata

# Create new profile userdate dir
mkdir -p /storage/.kodi/userdata/profiles/$user_profile
chmod 755 /storage/.kodi/userdata/profiles/$user_profile

# Set 'video' src
if [ -d "$dst_dir/video" ]
then
  # Initialize list array
  video_LIST=()
  # Media category
  name='video'
  # Share path
  share='video'
  # Add to list
  video_LIST+=( "<source>" "<name>$name</name>" "<path pathversion=\"1\">$dst_dir/$share/</path>" "<allowsharing>true</allowsharing>" "</source>" )

  # Set 'video/series' src
  # Media category
  name='series'
  # Share path
  share='video/series'
  if [ -d "$dst_dir/$share" ]
  then
    video_LIST+=( "<source>" "<name>$name</name>" "<path pathversion=\"1\">$dst_dir/$share/</path>" "<allowsharing>true</allowsharing>" "</source>" )
  fi

  # Set 'video/movies' src
  # Media category
  name='movies'
  # Share path
  share='video/movies'
  if [ -d "$dst_dir/$share" ]
  then
    video_LIST+=( "<source>" "<name>$name</name>" "<path pathversion=\"1\">$dst_dir/$share/</path>" "<allowsharing>true</allowsharing>" "</source>" )
  fi

  # Set 'video/pron' src
  # Media category
  name='pron'
  # Share path
  share='video/pron'
  if [ -d "$dst_dir/$share" ]
  then
    video_LIST+=( "<source>" "<name>$name</name>" "<path pathversion=\"1\">$dst_dir/$share/</path>" "<allowsharing>true</allowsharing>" "</source>" )
  fi

  # Set 'video/documentary' src
  # Media category
  name='documentary'
  # Share path
  share='video/documentary'
  if [ -d "$dst_dir/$share" ]
  then
    video_LIST+=( "<source>" "<name>$name</name>" "<path pathversion=\"1\">$dst_dir/$share/</path>" "<allowsharing>true</allowsharing>" "</source>" )
  fi

  # Set 'video/musicvideo' src
  # Media category
  name='musicvideo'
  # Share path
  share='video/musicvideo'
  if [ -d "$dst_dir/$share" ]
  then
    video_LIST+=( "<source>" "<name>$name</name>" "<path pathversion=\"1\">$dst_dir/$share/</path>" "<allowsharing>true</allowsharing>" "</source>" )
  fi
fi

# Set 'music' src
# Initialize list array
music_LIST=()
# Media category
name='music'
# Share path
share='music'
if [ -d "$dst_dir/$share" ]
then
  music_LIST=( "<source>" "<name>$name</name>" "<path pathversion=\"1\">$dst_dir/$share/</path>" "<allowsharing>true</allowsharing>" "</source>" )
fi

# Set 'pictures' src
# Initialize list array
pictures_LIST=()
# Media category
name='pictures'
# Share path
share='photos'
if [ -d "$dst_dir/$share" ]
then
  pictures_LIST=( "<source>" "<name>$name</name>" "<path pathversion=\"1\">$dst_dir/$share/</path>" "<allowsharing>true</allowsharing>" "</source>" )
fi

# Create '$sources_xml_file' 
new_sources="<sources>
    <programs>
        <default pathversion="1"></default>
    </programs>
    <video>
        <default pathversion="1"></default>
$(printf '%s\n' "${video_LIST[@]}" | awk '{ for(i=1; i<=8; i++) printf " "; print $0 }')
    </video>
    <music>
        <default pathversion="1"></default>
$(printf '%s\n' "${music_LIST[@]}" | awk '{ for(i=1; i<=8; i++) printf " "; print $0 }')
    </music>
    <pictures>
        <default pathversion="1"></default>
$(printf '%s\n' "${pictures_LIST[@]}" | awk '{ for(i=1; i<=8; i++) printf " "; print $0 }')
    </pictures>
    <files>
        <default pathversion="1"></default>
    </files>
    <games>
        <default pathversion="1"></default>
    </games>
</sources>"
printf '%s\n' "$new_sources" | sed '/^\s*$/d' > $sources_xml_file

#-----------------------------------------------------------------------------------
