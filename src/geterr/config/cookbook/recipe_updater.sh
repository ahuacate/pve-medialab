#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     recipe_updater.sh
# Description:  Source script for FlexGet recipes from GitHub
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

# Set vars from source
app_uid="$1"
app_gid="$2"
config_home="$3"
upgrade_recipe="$4"
recipe_src_dir_path="$5"

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Git server
GIT_SERVER='https://github.com'
# Git user
GIT_USER='ahuacate'
# Git repository
GIT_REPO='pve-medialab'
# Git branch
GIT_BRANCH='main'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check 'recipe_update' arg
if [ "$upgrade_recipe" = 0 ]
then
  # 'recipe_update' arg is disabled/off
  return
fi

# Check for GIT pkg
if [[ ! $(dpkg -s git 2> /dev/null) ]]
then
  apt-get install git -y
fi

# Check current day and time
current_day=$(date +%u) # 1-7 (Monday-Sunday)
# Check if it's Sunday
if [ ! "$current_day" = 7 ]
then
    # Skip update if wrong day
    return
fi

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


#---- Update FlexGet recipes

# Download Github repo
git clone --recurse-submodules https://github.com/$GIT_USER/${GIT_REPO}.git /tmp
chmod -R 777 "/tmp/$GIT_REPO"

# Update 'recipe_00' folders
for recipe_src_dir_path in $(find /tmp/$GIT_REPO/src/geterr/config -type d -name 'recipe_00')
do
# Copy and overwrite the find copies, excluding certain files
  cp -Rf --exclude='variables_default.yml' --exclude='my_filter_lookup_list.txt' $recipe_src_dir_path $config_home/cookbook/
  # Chown recipe dir
  chown -R $app_uid:$app_gid $config_home/cookbook/recipe_00
  # Chmod +x all shell scripts
  chmod -R +x $config_home/cookbook/recipe_00/*.sh
done


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