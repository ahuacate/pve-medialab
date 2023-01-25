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
  pid=$(<<<"$pid" xargs -n1 sh -c 'kill -0 "$1" 2>/dev/null && echo "$1"' --)

  if [ -n "$pid" ]
  then
    # Print screen msg
    echo -e "Script '"$(basename $0)"' is already running with pid ${pid}.\nTrying again in ${script_sleep_time} seconds (Attempt: $((${c} + 1)) of ${script_cnt_timeout})."
    # Set sleep period or timeout
    ((c++)) && ((c==${script_cnt_timeout})) && exit 0
    sleep ${script_sleep_time}
  else
    # Clear to run script
    break
  fi
done

#---- Static Variables -------------------------------------------------------------

# App dir
app_dir="$DIR"

# Log files
mkdir -p "$app_dir"/logs
now=$(date +"%F")
logfile="$app_dir/logs/kodirsync-${now}.log"

# LAN Network check (1 is UP, other is down)
lan_network_status=$(ip route | grep "linkdown" > /dev/null; echo $?)

# # Internet access check (Checking multiple urls incase one is blocked)
# url_check_LIST=( "google.com|443" \
# "github.com|443" )
# while IFS='|' read -r url port
# do
#   # Check url
#   nc -zw1 ${url} ${port} 2> /dev/null
#   if [[ $? == '1' ]]
#   then
#     # Set access status (1 is UP, other is down)
#     internet_access_status=0
#     continue
#   else
#     # Set access status (1 is UP, other is down)
#     internet_access_status=1
#     break
#   fi
# done< <( printf '%s\n' "${url_check_LIST[@]}" )

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check LAN network status
if [ ! "${lan_network_status}" = '1' ]
then
  # Log Job fail
  echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
  echo -e "#---- WARNING - LAN NETWORK FAIL\nFail Time : $(date)\n" >> ${logfile}
  echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
  exit 1
fi

# Run Kodirsync Git updater
source <( cat $app_dir/kodirsync_clientapp_gitupdater.sh ) 

# Read default config settings (must be before user cfg)
source $app_dir/kodirsync_clientapp_default.cfg

# Read user config settings
source $app_dir/kodirsync_clientapp_user.cfg


#---- Run script
# Run Kodirsync main script
source $app_dir/kodirsync_clientapp_script.sh
#-----------------------------------------------------------------------------------------------------------------------