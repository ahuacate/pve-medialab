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
readarray -t server_var_LIST < <(sed '/^\s*#/d;/^\s*$/d' /usr/local/bin/kodirsync/kodirsync.conf)
readarray -t user_var_LIST < <(sed '/^\s*#/d;/^\s*$/d' $DIR/clientapp/kodirsync_clientapp_user.cfg)

# Iterate over the server array and match the values of the variables into the user cfg file
for server_var in "${server_var_LIST[@]}"
do
  # Extract the variable name and value from the server configuration file
  server_param=$(echo "$server_var" | cut -d "=" -f1)
  server_value=$(echo "$server_var" | cut -d "=" -f2-)

  # Iterate over the user array and check if the variable name matches
  for user_var in "${user_var_LIST[@]}"
  do
    user_param=$(echo "$user_var" | cut -d "=" -f1)
    user_value=$(echo "$user_var" | cut -d "=" -f2)

    if [[ "$server_param" == "$user_param" ]]
    then
      # Update the value in the user configuration file
      crudini --set "$DIR/clientapp/kodirsync_clientapp_user.cfg" "" "$user_param" "$server_value"
      break
    fi
  done
done


#---- Set Kodirsync user configuration file

# Set Kodirsync user configuration file connection type
# '1' for SSLH, '2' for PF, '3' for LAN connection

# Set user conf location
user_config_file="$DIR/clientapp/kodirsync_clientapp_user.cfg"

if [ "$(crudini --get "/usr/local/bin/kodirsync/kodirsync.conf" "" "sslh_enable")" = 1 ]
then
  # sslh_enable
  key=rsync_connection_type
  value=1
  crudini --set "$user_config_file" "" "$key" "$value"
elif [ "$(crudini --get "/usr/local/bin/kodirsync/kodirsync.conf" "" "pf_enable")" = 1 ]
then
  # pf_enable
  key=rsync_connection_type
  value=2
  crudini --set "$user_config_file" "" "$key" "$value"
elif [ "$(crudini --get "/usr/local/bin/kodirsync/kodirsync.conf" "" "pf_enable")" = 0 ] && \
[ "$(crudini --get "/usr/local/bin/kodirsync/kodirsync.conf" "" "sslh_enable")" = 0 ]
then
  # lan_enable (only)
  key=rsync_connection_type
  value=3
  crudini --set "$user_config_file" "" "$key" "$value"
fi

# Set Kodirsync user configuration file user account
key=rsync_username
value="${username}"
crudini --set "$user_config_file" "" "$key" "$value"


#---- Create Selftar self-extracting package ---------------------------------------

# Make the Selftar installer run bash script
echo '#!/bin/bash

# Chmod files
chmod +x kodirsync_clientapp_installer.sh
chmod +x kodirsync_clientapp_install_termux_deps.sh

# Check if client is Termux or Linux/CoreELEC/LibreELEC
if [ $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]
then
  # Install Termux-Android dependencies
  source kodirsync_clientapp_install_termux_deps.sh
elif [ "$(uname)" == "Linux" ] && [ ! $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]
then
  # Install Linux dependencies
  echo "No dependencies to install"
else
  echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync is supported on CoreELEC, LibreELEC, Linux and Termux only.\nBye...\n\e[39m"
  exit 0
fi

# Run Kodirsync client installer
./kodirsync_clientapp_installer.sh' > $TEMP_DIR/install.sh

# Make a list of all the installer package files
# Declare an array to hold the file list
declare -a pkg_file_LIST

# Read the clientapp dir files into the array, filtering out unwanted files
pkg_file_LIST=($(find $DIR/clientapp -type f ! -name "*.tmp" ! -name ".*" ! -name "*.old" ! -name "*.bak"))

# Read Selftar install.sh file into array
pkg_file_LIST+=( "$TEMP_DIR/install.sh" )

# Read SSLH crt and key if available to tar package
if [ -f "/root/.ssh/sslh-kodirsync.key" ]
then
  pkg_file_LIST+=( "/root/.ssh/sslh-kodirsync.key" )
  pkg_file_LIST+=( "/root/.ssh/sslh.crt" )
fi

# Read kodirsync_node_rsa_key pairs if available to tar package
if [ -f "$TEMP_DIR/kodirsync_node_rsa_key" ]
then
  pkg_file_LIST+=( "$TEMP_DIR/kodirsync_node_rsa_key" )
  pkg_file_LIST+=( "$TEMP_DIR/kodirsync_node_rsa_key.pub" )
  pkg_file_LIST+=( "$TEMP_DIR/kodirsync_node_rsa_key.ppk" )
fi

# Add files to tar archive & chmod +x executable files
# Start tar archive by adding the user ssh key
tar cf $TEMP_DIR/installer_pkg.tar \
-C $HOME_BASE/$username/.ssh ${username}_kodirsync_id_ed25519

# Add remaining files to 'installer_pkg.tar'
while read line
do
  # Chmod +x script files
  if [[ "$line" =~ ^.*\.(sh|cfg)$ ]]
  then
    # Chmod the file
    chmod +x $line
  fi
  
  # Add to tar file
  tar -rf $TEMP_DIR/installer_pkg.tar -C $(dirname "$line") $(basename "$line")
done < <( printf '%s\n' "${pkg_file_LIST[@]}" )

# cp $TEMP_DIR/installer_pkg.tar /tmp/
# Make gzip
gzip -9 $TEMP_DIR/installer_pkg.tar

# Create Selftar self-executing tar file
# To run: (mkdir -p $PREFIX/tmp/selftar ; cd $PREFIX/tmp/selftar ; $PREFIX/tmp/installer.run)
selftar_dir='$PREFIX/tmp/selftar'
chmod +x $COMMON_DIR/bash/src/selftar.sh
$COMMON_DIR/bash/src/selftar.sh "$TEMP_DIR/installer_pkg.tar.gz" "\$PREFIX/tmp/selftar/install.sh"

# Rename & move Selftar package installer
mv $TEMP_DIR/installer_pkg.tar.gz.run $HOME_BASE/$username/installer.run
#-----------------------------------------------------------------------------------