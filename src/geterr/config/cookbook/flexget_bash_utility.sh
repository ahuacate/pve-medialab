#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     flexget_bash_utility.sh
# Description:  FlexGet bash utility file
#               Checks SRC, DST dirs, internet and required file status.
#               Exit on failure.
#               Requires 'cookbook.ini'
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Trim log file
function trim_log() {
  local log="$1"

  # Limit error log file size
  lcnt=$( cat $log | wc -l)
  # wc -l ${log} | read lcnt other
  if [ $lcnt -gt 300 ]
  then
    ((start=$lcnt-99))
    tail +$start $log > ${log}N
    mv ${log}N $log
  fi
}

# Make error log
function make_error_log() {
  # Usage: make_error_log "Type message here to appear in log file"
  local log="$1"
  local message="$2"

  echo $(printf -- '-%.0s' {1..84}) >> $log
  echo "ERROR: $datetime" >> $log
  if ! [ -z ${1+x} ]; then
    echo "Reason/Issue: $message" >> $log
  fi
  echo $(printf -- '-%.0s' {1..84}) >> $log
}

# Prune other log files
prune_log_files() {
  local recipe_dir="$1"
  local n_days="$2"

  # Prune all logs except for flexget.log that are older than n days
  find "$recipe_dir" -name "*.log" \
    -not -name "flexget.log" -type f -mtime +"$n_days" -delete
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Main Log files
log=$recipe_home/flexget.log
if [ ! -f "$log" ]
then
  touch "$log"
fi

# Trim log file
trim_log "$log"

# Prune log files older than n days (excluding flexget.log)
prune_log_files "$recipe_home" "3"


# Check for Internet connectivity
# List of well-known websites to test connectivity (in case one is blocked)
websites=( "google.com 443" "github.com 443" "cloudflare.com 443" "apple.com 443" "amazon.com 443" )
# Loop through each website in the list
for website in "${websites[@]}"
do
  # Test internet connectivity
  nc -zw1 $website > /dev/null 2>&1
  # Check the exit status of the ping command
  if [ $? = 0 ]
  then
    # Flag to track if internet connection is up
    connection_up=0
    break
  else
  # Flag to track if internet connection is down
  connection_up=1
  fi
done
# On connection fail
if [ "$connection_up" = 1 ]
then
  # Make error log
  make_error_log "Internet connectivity status: dead. Cannot proceed without a internet connection."
  exit 0
fi


#---- Check SRC and DST mounts

# Create FlexGet 'dl_client_category_LIST'
dl_type='torrent'
dlclient_category_LIST=()
while IFS=':' read -r category destdir watchdir aliases ext
do
  [[ "$category" =~ ^\#.*$ ]] && continue
    # Create 'dl_client_category_LIST'
    dlclient_category_LIST+=( "$category:$(eval echo "$destdir"):$(eval echo "$watchdir"):$(echo "$aliases" | sed 's/,/, /g'):$ext" )
done < <( cat /home/media/.flexget/cookbook/dlclient_category_list.txt | egrep '^manual-.*' )

# Create flexget torrent folders on NAS 
if [ -d "/mnt/downloads" ]
then
  # Create torrent dl dirs
  mkdir -p /mnt/downloads/torrent/{incomplete,complete} 2> /dev/null
  if [ ! $? = 0 ]
  then
    # Make error log
    make_error_log "Cannot create folders: /mnt/downloads/torrent/{incomplete,complete}. Exiting."
    exit 0
  fi
  # Create label destination dirs
  while IFS=':' read -r category destdir watchdir aliases ext
  do
    # Create destination dir
    if [ ! -z ${destdir+x} ] && [ "$destdir" != "" ]
    then
      mkdir -p $destdir 2> /dev/null
      if [ ! $? = 0 ]
      then
        # Make error log
        make_error_log "Cannot create folder: $destdir. Exiting."
        exit 0
      fi
    fi
    # Create watch dir
    if [ ! -z ${watchdir+x} ] && [ "$watchdir" != "" ]
    then
      mkdir -p $watchdir 2> /dev/null
      if [ ! $? = 0 ]
      then
        # Make error log
        make_error_log "Cannot create folder: $watchdir. Exiting."
        exit 0
      fi
    fi
  done < <( printf '%s\n' "${dlclient_category_LIST[@]}" )
else
  # Make error log
  make_error_log "Missing mount point: /mnt/downloads. Exiting."
  exit 0
fi
#-----------------------------------------------------------------------------------