#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     geterr_upgrade_sw.sh
# Description:  Upgrade Geterr SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# App uid
app_uid=media

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Stopping FlexGet system.d services

# Stopping system.d 'flexget.timer' unit
if [ "$(systemctl is-active flexget.timer)" == "active" ]
then
  systemctl stop flexget.timer
  while ! [[ "$(systemctl is-active flexget.timer)" == "inactive" ]]
  do
    echo -n .
  done
  systemctl disable flexget.timer &> /dev/null
fi

# Stopping system.d 'flexget.service' unit
if [ "$(systemctl is-active flexget.service)" == "active" ]
then
  systemctl stop flexget.service
  while ! [[ "$(systemctl is-active flexget.service)" == "inactive" ]]
  do
    echo -n .
  done
  systemctl disable flexget.service &> /dev/null
fi


#---- Stop FlexGet

# Get list of PIDs for all running flexget processes
PID_LIST=$(pgrep -u $app_uid flexget)

# Check if any flexget processes are running
if [ -n "$PID_LIST" ]
then
  # Send SIGTERM signal to all flexget processes
  kill -TERM $PID_LIST
  
  # Wait for all processes to be terminated
  while pgrep -u $app_uid flexget >/dev/null
  do
    sleep 1
  done
fi

#---- Wait for FileBot

# Set the time threshold for inactivity
inactive_threshold=30

# Set the initial time that filebot was last active to the current time
last_active_time=$(date +%s)

# Loop until filebot has been inactive for the threshold time
while true
do
  # Check if filebot is running
  if pgrep -u $app_uid filebot >/dev/null
  then
    # Filebot is running, so update the last active time
    last_active_time=$(date +%s)
  else
    # Filebot is not running, so check if it has been inactive for the threshold time
    current_time=$(date +%s)
    inactive_time=$((current_time - last_active_time))
    if [ $inactive_time -ge $inactive_threshold ]
    then
      # Filebot has been inactive for the threshold time, so exit the loop
      break
    fi
  fi
  
  # Wait for a short time before checking again
  sleep 10
done


#---- Update & Upgrade OS

# Update OS
apt-get update -y
apt-get upgrade -y

# Custom software upgrade commands here
# Upgrade tools
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install --upgrade pip setuptools"

# Upgrade libtorrent
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install --upgrade libtorrent"

# Upgrade Guessit
apt-get upgrade python3-guessit -y

# Upgrade FlexGet
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install --upgrade flexget"

# Upgrade cloudscraper
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install --upgrade cloudscraper"

# Upgrade Deluge-client
su -s /bin/bash $app_uid -c "~/flexget/bin/pip install --upgrade deluge-client"

# Upgrade FileBot
su -s /bin/bash $app_uid -c "cd /home/$app_uid/filebot && curl -fsSL https://raw.githubusercontent.com/filebot/plugins/master/installer/tar.sh | sh -xu 2> /dev/null"


#---- Restart FlexGet system.d units

# Enable system.d service units
systemctl enable --quiet flexget.timer
systemctl enable --quiet flexget.service

# Starting system.d 'flexget.timer' unit
if [ "$(systemctl is-active flexget.timer)" == "inactive" ]
then
  systemctl restart flexget.timer
  while ! [[ "$(systemctl is-active flexget.timer)" == "active" ]]
  do
    echo -n .
  done
fi
#-----------------------------------------------------------------------------------