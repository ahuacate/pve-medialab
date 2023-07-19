#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     update-ct.sh
# Description:  System.d updater for CT OS and installed applications
# Note:         Customize for each OS and application.
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $DIR/basic_bash_utility.sh

#---- Static Variables -------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Stop list of systemd services
# Enter all the SW 'system.d.service' here
systemd_LIST=()
while IFS= read -r line
do
  [[ "$line" =~ ^\#.*$ ]] && continue
  systemd_LIST+=( "$line" )
done << EOF
sabnzbdplus.service
EOF

#---- Functions --------------------------------------------------------------------
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