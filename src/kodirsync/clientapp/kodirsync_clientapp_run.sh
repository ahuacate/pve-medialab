#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_run.sh
# Description:  Default Kodirsync client run script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )


#---- Dependencies -----------------------------------------------------------------

#---- Check script is not already running

# Script sleep time (sec)
script_sleep_time=3000
# Script timeout count limit
script_cnt_timeout=10
# Check for existing running script pid
# Checks for
c=0
while [ 1 ]
do
  # Get current script pid
  pid=$(pgrep -f "$(basename $0)"| grep -x -v $$)

  # Filter non-existent pid(s)
  # pid=$(<<<"$pid" xargs -n1 sh -c 'kill -0 "$1" 2>/dev/null && echo "$1"' --)
  pid=$(echo "$pid" | xargs -n1 sh -c 'kill -0 "$1" 2>/dev/null && echo "$1"' --)


  if [ -n "$pid" ]
  then
    # Print screen msg
    echo -e "Script '"$(basename $0)"' is already running with pid ${pid}.\nTrying again in ${script_sleep_time} seconds (Attempt: $((${c} + 1)) of ${script_cnt_timeout})."
    # Set sleep period or timeout
    ((c++)) && ((c==${script_cnt_timeout})) && exit 0
    sleep $script_sleep_time
  else
    # Clear to run script
    break
  fi
done

#---- Static Variables -------------------------------------------------------------

# App dir
app_dir="$DIR"

# SSH dir
ssh_dir="$HOME/.ssh"


# Log files
mkdir -p "$app_dir"/logs
now=$(date +"%F")
logfile="$app_dir/logs/kodirsync-${now}.log"
days_to_keep=14

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------


#---- Prerequisites

# Remove log files older than $days_to_keep days
find "$app_dir/logs" -name "kodirsync-*.log" -type f -mtime +$days_to_keep -delete

# LAN Network check (1 is UP, other is down)
lan_network_status=$(ip route | grep "linkdown" > /dev/null; echo $?)

# Check LAN network status
if [ ! "$lan_network_status" = 1 ]
then
  # Log Job fail
  echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
  echo -e "#---- WARNING - LAN NETWORK FAIL\nFail Time : $(date)\n" >> ${logfile}
  echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
  exit 1
fi

# Check if client is Termux or Linux/CoreELEC/LibreELEC
if [ $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]
then
  # Set OS type to Termux
  ostype='termux'

  # Install Termux-Android dependencies
  source $app_dir/kodirsync_clientapp_install_termux_deps.sh
elif [ "$(uname)" == "Linux" ] && [ ! $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]
then
  # Set Linux OS type
  ostype=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
else
  echo -e "\e[93m[WARNING]\e[39m \e[97mKodirsync is supported on CoreELEC, LibreELEC, Linux and Termux only.\nBye...\n\e[39m"
  exit 0
fi


# Run Kodirsync Git updater
# Not available to Termux-Android clients 
github_updater=$(sed -n "s/^github_updater=\(['\"]\?\)\(.*\)\1/\2/p" "$app_dir/kodirsync_clientapp_user.cfg")
if [ "$github_updater" = 1 ] && [ ! "$ostype" = 'termux' ]
then
  # Run Kodirsync Git updater
  # The arg 'arg_parent' tells kodirsync_clientapp_gitupdater.sh the script originates from a parent script.
  source <(cat "$app_dir/kodirsync_clientapp_gitupdater.sh") "arg_parent"
fi


# Read default config settings (must be before user cfg)
source "$app_dir/kodirsync_clientapp_default.cfg"

# Read user config settings
source "$app_dir/kodirsync_clientapp_user.cfg"


#---- Run script

# Run Kodirsync main script
source $app_dir/kodirsync_clientapp_script.sh

# Run Kodirsync node synchronization
if [ "$node_sync" = 1 ] && [ ! "$ostype" = 'termux' ]
then
  source $app_dir/kodirsync_clientapp_node_sync.sh
fi
#-----------------------------------------------------------------------------------------------------------------------