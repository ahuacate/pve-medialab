#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_elec.sh
# Description:  Default Kodirsync client run script
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

# Specify the path to the known_hosts file
known_hosts_file="$ssh_dir/known_hosts"

# Create '$known_hosts_file' if missing
if [ ! -f "$known_hosts_file" ]
then
  # Create the known_hosts file
  touch "$known_hosts_file"

  # Set the appropriate ownership and permissions
  chmod 600 "$known_hosts_file"
  chown "$user:$user_grp" "$known_hosts_file"
fi


# #---- Configure Samba
# # Here we create a SMB share of the new Kodirsync disk mount.

# # SMB conf file
# smb_config_file="/storage/.config/samba.conf"

# # Kodirsync SMB share
# kodirsync_share="[Kodirsync_Share]
#   path = $smb_dir
#   available = yes
#   browsable = yes
#   public = yes
#   writable = yes"

# # Update SMB shares
# if [ -f "/storage/.config/samba.conf" ]
# then
#   # Check if "Kodirsync Share" section already exists
#   if ! grep -q "^\[Kodirsync_Share\]" "$smb_config_file"; then
#     # Stop services
#     stop_systemctl "nmbd.service"
#     wait
#     stop_systemctl "smbd.service"

#     # Append the kodirsync_share configuration to the config file
#     printf "%s\n" "$kodirsync_share" >> "$smb_config_file"

#     # Restart services
#     start_systemctl "nmbd.service"
#     wait
#     start_systemctl "smbd.service"
#   fi
# else
#   # Stop services
#   stop_systemctl "nmbd.service"
#   wait
#   stop_systemctl "smbd.service"
  
#   # Create new 'samba.conf' with [Kodirsync Share]
#   cp /storage/.config/samba.conf.sample $smb_config_file
#   echo "" >> $smb_config_file
#   printf "%s\n" "$kodirsync_share" >> $smb_config_file

#   # Restart services
#   start_systemctl "nmbd.service"
#   wait
#   start_systemctl "smbd.service"
# fi
#-----------------------------------------------------------------------------------------------------------------------