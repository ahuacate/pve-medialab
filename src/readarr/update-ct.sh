#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     update-ct.sh
# Description:  System.d updater for CT OS and installed applications
# Note:         Customize for each OS and application.
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Stop list of systemd services
# Enter all the SW 'system.d.service' here
systemd_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  systemd_LIST+=( "$line" )
done << EOF
readarr.service
EOF

#---- Functions --------------------------------------------------------------------

# Stop System.d Services
function pct_stop_systemctl() {
  # Usage: pct_stop_systemctl "name.service"
  local service_name="$1"
  if [ "$(systemctl is-active $service_name)" = 'inactive' ]
  then
    # Stop service
    sudo systemctl stop $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'inactive' ]]
    do
      echo -n .
    done
  fi
}

# Start System.d Services
function pct_start_systemctl() {
  # Usage: pct_start_systemctl "jellyfin.service"
  local service_name="$1"
  # Reload systemd manager configuration
  sudo systemctl daemon-reload
  if [ "$(systemctl is-active $service_name)" = 'inactive' ]
  then
    # Stop service
    sudo systemctl start $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'active' ]]
    do
      echo -n .
    done
  fi
}

#---- Body -------------------------------------------------------------------------

#---- Stop services

# Stop any running systemd service or applications in order to perform upgrades
for line in "${systemd_LIST[@]}"
do
  pct_stop_systemctl "$line"
done

#---- Update & Upgrade OS

# Update OS
apt-get update -y
apt-get upgrade -y

# Custom software upgrade commands here


#---- Restart services

# Restart services
for line in "${systemd_LIST[@]}"
do
  pct_start_systemctl "$line"
done
#-----------------------------------------------------------------------------------