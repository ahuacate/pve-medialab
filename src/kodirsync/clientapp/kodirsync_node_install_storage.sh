#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     Kodirsync_node_install_storage.sh
# Description:  Installer script for a Kodirsync node storage setup
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Setup storage
source $DIR/kodirsync_clientapp_install_linux_storage.sh


#---- Install Kodirsync node SSH public key

# Create '$authorized_keys' if missing
# Perform action according to host OS type ( '1' is ELEC, '2' is generic Linux)
if [ "$os_type" = 1 ]
then
  # OS type - ELEC
  authorized_keys="$ssh_dir/authorized_keys"
  if [ ! -f "$authorized_keys" ]
  then
    # Create the known_hosts file
    touch "$authorized_keys"

    # Set the appropriate ownership and permissions
    chmod 600 "$authorized_keys"
    chown "$user:$user_grp" "$authorized_keys"
  fi
elif [ "$os_type" = 2 ]
then
  # OS type - Linux
  authorized_keys="$ssh_dir/authorized_keys"
  if [ ! -f "$authorized_keys" ]
  then
    # Create the known_hosts file
    touch "$authorized_keys"

    # Set the appropriate ownership and permissions
    chmod 600 "$authorized_keys"
    chown "$user:$user_grp" "$authorized_keys"
  fi
fi

# Append the public node ssh key to the known_hosts file
if [ -f "$DIR/kodirsync_node_rsa_key.pub" ]
then
  cat "$DIR/kodirsync_node_rsa_key.pub" >> $authorized_keys
fi
#-----------------------------------------------------------------------------------