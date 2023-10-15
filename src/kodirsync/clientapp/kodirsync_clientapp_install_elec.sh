#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_elec.sh
# Description:  This file is used by the installer and 'kodirsync_clientapp_run.sh'
#               script. Edit with caution.
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Stop System.d Services
function stop_systemctl() {
  # Usage: stop_systemctl "name.service"
  local service_name="$1"
  if [ "$(systemctl is-active $service_name)" = 'active' ]
  then
    # Stop service
    systemctl stop $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'inactive' ]]
    do
      echo -n .
    done
  fi
}

# Start System.d Services
function start_systemctl() {
  # Usage: start_systemctl "name.service"
  local service_name="$1"
  # Reload systemd manager configuration
  systemctl daemon-reload
  if [ "$(systemctl is-active $service_name)" = 'inactive' ]
  then
    # Start service
    systemctl start $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'active' ]]
    do
      echo -n .
    done
  fi
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

opkg update
opkg upgrade


#---- Install SW dependencies

# Required packages
pkg_LIST=(
    moreutils
    p7zip
)

# Install required packages if missing
for pkg in "${pkg_LIST[@]}"; do
    opkg install "$pkg"
done


#---- Check for known_hosts file

known_hosts_file="$ssh_dir/known_hosts"  # Specify the path to the known_hosts file

# Create '$known_hosts_file' if missing
if [ ! -f "$known_hosts_file" ]; then
    touch "$known_hosts_file"  # Create the known_hosts file

    # Set the appropriate ownership and permissions
    chmod 600 "$known_hosts_file"
    chown "$user:$user_grp" "$known_hosts_file"
fi
#-----------------------------------------------------------------------------------------------------------------------