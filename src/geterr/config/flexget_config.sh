#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     flexget_config.sh
# Description:  Source script for configuring Geterr SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )
COMMON_DIR="$DIR/../../../common"
COMMON_PVE_SRC_DIR="$DIR/../../../common/pve/src"
SHARED_DIR="$DIR/../../../shared"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_DIR/bash/src/basic_bash_utility.sh

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"       # App name
app_uid="$APP_USERNAME"    # App UID
app_guid="$APP_GRPNAME"    # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create FlexGet 'dl_client_category_LIST'
dl_type='torrent'
dlclient_category_LIST=()
while IFS=':' read -r category destdir watchdir aliases ext
do
  [[ "$category" =~ ^\#.*$ ]] && continue
    # Create 'dl_client_category_LIST'
    dlclient_category_LIST+=( "$category:$(eval echo "$destdir"):$(eval echo "$watchdir"):$(echo "$aliases" | sed 's/,/, /g'):$ext" )
done < <( cat $SHARED_DIR/src/dlclient_category_list.txt | egrep '^manual-.*' )

# Create FlexGet torrent folders on NAS 
if [ -d "/mnt/downloads" ]
then
  # Create torrent dl dirs
  su - $app_uid -c "mkdir -p /mnt/downloads/torrent/{incomplete,complete}"
  # Create label destination dirs
  while IFS=':' read -r category destdir watchdir aliases ext
  do
    # Create destination dir
    if [ -n "$destdir" ]
    then
      su - $app_uid -c "mkdir -p $destdir"
    fi
    # Create watch dir
    if [ -n "$watchdir" ]
    then
      su - $app_uid -c "mkdir -p $watchdir"
    fi
  done < <( printf '%s\n' "${dlclient_category_LIST[@]}" )
fi


#---- Copy Cookbook files

# Copy FlexGet files to cookbook dir
cp -R $DIR/cookbook /home/$app_uid/.flexget/

# Copy 'dlclient_category_list.txt' to cookbook dir
cp $SHARED_DIR/src/dlclient_category_list.txt /home/$app_uid/.flexget/cookbook/

# Set file permissions
chown -R "$app_uid":"$app_guid" /home/$app_uid/.flexget


#---- Setup FlexGet system.d units

# Copy system.d 'flexget.service' unit
cp $DIR/flexget.service /etc/systemd/system/

# Copy system.d 'flexget.timer' unit
cp $DIR/flexget.timer /etc/systemd/system/

# Enable system.d service units
systemctl enable --quiet flexget.timer
systemctl enable --quiet flexget.service

# Starting system.d 'flexget.timer' unit
if [ "$(systemctl is-active flexget.timer)" == "inactive" ]
then
  systemctl start flexget.timer
  while ! [[ "$(systemctl is-active flexget.timer)" == "active" ]]
  do
    echo -n .
  done
fi

# Starting system.d 'flexget.service' unit
if [ "$(systemctl is-active flexget.service)" == "inactive" ]
then
  systemctl start flexget.service
  while ! [[ "$(systemctl is-active flexget.service)" == "active" ]]
  do
    echo -n .
  done
fi
#-----------------------------------------------------------------------------------