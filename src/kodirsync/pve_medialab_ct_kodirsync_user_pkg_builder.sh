#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_kodirsync_user_pkg_builder.sh
# Description:  This script is for creating a Users installer package
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Chroot Home
CHROOT='/home/chrootjail'
HOME_BASE="$CHROOT/homes"
GROUP="chrootjail"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#----- Functions -------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Declare an array to hold the variables
declare -a server_var_LIST
declare -a user_var_LIST

# Read the lines of the configuration file into the array, filtering out empty lines and lines that begin with #
readarray -t server_var_LIST < <(grep -v "^#" /usr/local/bin/kodirsync/kodirsync.conf | grep . | grep =)
readarray -t user_var_LIST < <(grep -v "^#" $DIR/clientapp/kodirsync_clientapp_user.cfg | grep . | grep =)

# Iterate over the server array and extract the values of the variables into user cfg file
for line in "${server_var_LIST[@]}"; do
  var_name=$(echo "$line" | awk -F "=" '{print $1}')
  var_value=$(echo "$line" | awk -F "=" '{print $2}' | sed -r 's/(^[^"]*$)/"\1"/')
  eval "$var_name=$var_value"
  # Match var name in user configuration file
  if [[ $(printf '%s\n' "${user_var_LIST[@]}" | egrep "^$var_name\=") ]]; then
    sed -i -r "s#^${var_name}\=.*#${var_name}\=${var_value}#" $DIR/clientapp/kodirsync_clientapp_user.cfg
  fi
done

#---- Set Kodirsync user configuration file

# Set Kodirsync user configuration file connection type
# '1' for SSLH, '2' for PF, '3' for LAN connection
# Uses Func 'edit_config_value'
config_file="$DIR/clientapp/kodirsync_clientapp_user.cfg"

if [ "$sslh_enable" = 1 ]
then
  # sslh_enable
  key=rsync_connection_type
  value=1
  edit_config_value "$config_file" "$key" "$value"
elif [ "$pf_enable" = 1 ]
then
  # pf_enable
  key=rsync_connection_type
  value=2
  edit_config_value "$config_file" "$key" "$value"
elif [ "$pf_enable" = 0 ] && [ "$sslh_enable" = 0 ]
then
  # lan_enable (only)
  key=rsync_connection_type
  value=3
  edit_config_value "$config_file" "$key" "$value"
fi

# Set Kodirsync user configuration file user account
key=rsync_username
value="${username}"
edit_config_value "$config_file" "$key" "$value"

#---- Process ----------------------------------------------------------------------

#---- Selftar self-extracting package

# Make the Selftar installer run bash script
echo '#!/bin/bash

# Chmod files
chmod +x kodirsync_clientapp_installer.sh

# Run Kodirsync client installer
./kodirsync_clientapp_installer.sh' > $TEMP_DIR/install.sh

# Make a list of all the installer package files
# Declare an array to hold the file list
declare -a pkg_file_LIST
# Read the clientapp dir files into the array, filtering out unwanted files
pkg_file_LIST=($(find $DIR/clientapp -type f ! -name "*.tmp" ! -name ".*" ! -name "*.old" ! -name "*.bak"))
# Read Selftar install.sh file into array
pkg_file_LIST+=( "$TEMP_DIR/install.sh" )
# # Read User SSH key into array
# pkg_file_LIST+=( "$HOME_BASE/$username/.ssh/${username}_kodirsync_id_ed25519" )
# Read SSLH crt and key if available to tar package
if [ -f "/root/.ssh/sslh-kodirsync.key" ]
then
  pkg_file_LIST+=( "/root/.ssh/sslh-kodirsync.key" )
  pkg_file_LIST+=( "/root/.ssh/sslh.crt" )
fi

# Add files to tar archive & chmod +x executable files
# Start tar archive by adding the user ssh key
tar cf $TEMP_DIR/installer_pkg.tar \
-C $HOME_BASE/$username/.ssh ${username}_kodirsync_id_ed25519
while read line
do
  # Chmod +x script files
  if [[ "$line" == *.sh || "$line" == *.cfg ]]
  then
    # Chmod the file
    chmod +x $line
  fi
  # Add to tar file
  tar -rf $TEMP_DIR/installer_pkg.tar -C $(dirname "$line") $(basename "$line")
done < <( printf '%s\n' "${pkg_file_LIST[@]}" )

cp $TEMP_DIR/installer_pkg.tar /tmp/
# Make gzip
gzip -9 $TEMP_DIR/installer_pkg.tar

# Create Selftar self-executing tar file
# To run: (mkdir -p /tmp/selftar ; cd /tmp/selftar ; /tmp/installer.run)
selftar_dir='/tmp/selftar'
chmod +x $COMMON_DIR/bash/src/selftar.sh
$COMMON_DIR/bash/src/selftar.sh "$TEMP_DIR/installer_pkg.tar.gz" "/tmp/selftar/install.sh"
ls 
# Rename & move Selftar package installer
mv $TEMP_DIR/installer_pkg.tar.gz.run $HOME_BASE/$username/installer.run
#-----------------------------------------------------------------------------------