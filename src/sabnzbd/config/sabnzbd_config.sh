#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     sabnzbd_config.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )
COMMON="$DIR/../../../common"
SHARED="$DIR/../../../shared"

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"       # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Create 'dl_client_catergory_LIST'
dl_type='usenet'
dlclient_category_LIST=()
dirwatch_LIST=()
while IFS=':' read -r category destdir watchdir aliases ext
do
  [[ "$category" =~ ^\#.*$ ]] && continue
    # Create 'dl_client_catergory_LIST'
    dlclient_category_LIST+=( "$category:$(eval echo "$destdir"):$(eval echo "$watchdir"):$(echo "$aliases" | sed 's/,/, /g'):$ext" )
    # Create dirwatch_LIST
    if ! [ -z "$watchdir" ]
    then
      dirwatch_LIST+=( "$(eval echo "$watchdir")?c=$category" )
    fi
done < $SHARED/src/dlclient_category_list.txt

#---- Body -------------------------------------------------------------------------

# Stop SABnzbd service
# SABnzbd uses a non-standard method to start SAB. Func scripts do not work.
if [ "$(systemctl is-active sabnzbdplus)" = 'active' ]
then
  # Stop service
  sudo service sabnzbdplus stop
  # Waiting to hear from service
  while ! [[ "$(systemctl is-active sabnzbdplus)" == 'inactive' ]]
  do
    echo -n .
  done
fi

# Create Download dir
runuser $app_uid -c 'mkdir -p /mnt/downloads/usenet/{queue,tmp,intermediate,complete,nzb} 2> /dev/null'
while IFS=':' read -r category destdir watchdir aliases ext
do
  # Create destination dir
  if ! [ -z "$destdir" ]
  then
    runuser $app_uid -c "mkdir -p $destdir 2> /dev/null"
  fi
  # Create watch dir
  if ! [ -z "$watchdir" ]
  then
    runuser $app_uid -c "mkdir -p $watchdir 2> /dev/null"
  fi
done < <( printf '%s\n' "${dlclient_category_LIST[@]}" )

# Create SABnzbd scripts dir
if ! [ -d "/home/media/.sabnzbd/scripts" ]
then
  runuser $app_uid -c "mkdir -p /home/media/.sabnzbd/scripts 2> /dev/null"
fi

# Create SABnzbd email tmpl dir
if ! [ -d "/home/media/.sabnzbd/email_tmpl" ]
then
  runuser $app_uid -c "mkdir -p /home/media/.sabnzbd/email_tmpl 2> /dev/null"
fi

# Copy Python scripts to SABnzbd scripts dir
cp -f $DIR/*.py /home/media/.sabnzbd/scripts/
chown $app_uid:$app_guid /home/media/.sabnzbd/scripts/*
sudo chmod +x /home/media/.sabnzbd/scripts/*


#---- Set basic configuration settings

# Remove inbuilt [categories] section from 'sabnzbd.ini'
sed -i '/^\[categories\]/,/\[[^]]*\]$/d' /home/media/.sabnzbd/sabnzbd.ini

# Set misc section settings - 'sabnzbd.ini'
# Here we edit the miscellaneous section parameters using mostly Trash Guides
# configuration recommendations. The values are in 'sabnzbd_misc_presets.txt'.
while IFS=';' read -r section param value
do
  # Skip lines that start with "#", "\s" and empty lines
  [[ "$section" =~ ^[[:space:]]*$|^#.*$ ]] && continue
  # Set sabnzbd.ini param
  crudini --set /home/media/.sabnzbd/sabnzbd.ini $section $param $value
done < $DIR/sabnzbd_misc_presets.txt


# Set backup dir
if [ -d "/mnt/backup/$app" ]
then
  crudini --set /home/media/.sabnzbd/sabnzbd.ini misc backup_dir /mnt/backup/$app
fi


# Append default [categories] section to 'sabnzbd.ini'
echo "[categories]
[[*]]
name = *
order = 0
pp = 3
script = None
dir = ""
newzbin = ""
priority = 0" >> /home/media/.sabnzbd/sabnzbd.ini

# Set category section settings - 'sabnzbd.ini'
# Here we create the category arrays (i.e radarr-movies, sonarr-series etc)
# from the common shared file 'dlclient_category_list.txt'.
# Initialize list array
category_LIST=()
# Set DL type
dl_type=usenet
# Set cnt
cnt=1
## CATEGORY DESTDIR WATCHDIR ALIASES
while IFS=':' read -r category dstdir watchdir aliases
do
  # Skip lines that start with "#", "\s" and empty lines
  [[ "$category" =~ ^[[:space:]]*$|^#[[:space:]]+.*$ ]] && continue
  # Evaluate dstdir variable
  eval "dir=$dstdir"
  # Create category list
  category_LIST+=( "[[$category]]" )
  category_LIST+=( "name = $category" )
  category_LIST+=( "order = $cnt" )
  category_LIST+=( "pp = \"\"" )
  category_LIST+=( "script = replace_for.py" )
  category_LIST+=( "dir = $dir" )
  category_LIST+=( "newzbin = $aliases" )
  category_LIST+=( "priority = -100" )
  # Add +1 to $cnt
  cnt=$(( $cnt+1 ))
done < $SHARED/src/dlclient_category_list.txt
# Append to 'sabnzbd.ini' (section [categories])
printf '%s\n' "${category_LIST[@]}" >> /home/media/.sabnzbd/sabnzbd.ini

#---- Reload systemd manager configuration

# SABnzbd uses a non-standard method to start SAB. Func scripts do not work.
if [ "$(systemctl is-active sabnzbdplus)" = 'inactive' ]
then
  sudo systemctl daemon-reload
  # Start service
  sudo service sabnzbdplus start
  # Waiting to hear from service
  while ! [[ "$(systemctl is-active sabnzbdplus)" == 'active' ]]
  do
    echo -n .
  done
fi
#-----------------------------------------------------------------------------------