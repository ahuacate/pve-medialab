#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_rsync_throttle.sh
# Description:  Standard rsync script. Includes throttle option (i.e --bwlimit).
# Usage:        All variables/args set in 'kodirsync_clientapp_default.cfg'
#               Requires parent file 'kodirsync_clientapp_rsync_main.sh'
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Set required parameters
# When referencing positional parameters greater than 9,
# you need to use curly braces ({}) to correctly expand the value.
# Source parameters must also be passed in array (when greater than 9 parameters).
rsync_sleep_time="${1}"        # Sleep time between retries
rsync_cnt_timeout="${2}"       # Maximum number of retries
rsync_ssh_cmd="${3}"           # SSH command
logfile="${4}"                 # Path to the log file
work_dir="${5}"                # Working directory for rsync
bw_limit="${6}"                # Throttle bandwidth limit in kilobits per second
rsync_username="${7}"          # Rsync username
rsync_address="${8}"           # Rsync server address
source="${9}"                  # Source directory/file
dst_dir="${10}"                # Destination directory
rsync_threads="${11}"          # Max rsync threads

#---- Run rsync 

# Set start vars
retry_count=0
exit_code=1

# Run rsync cmd
while [[ $exit_code -ne 0 && $retry_count -lt $rsync_cnt_timeout ]]
do
  # Throttle rsync transfer speed during selected period of time
  if [ "$stor_fs" = exfat ] || [ "$ostype" = 'termux' ]
  then
    # Configure for rsync filesystem compatibility -exFAT or Termux/Android OS
    # ExFAT filesystem is not compatible with the rsync '-a' archive option.
    cat $work_dir/rsync_process_list.txt | xargs -I {} -P $rsync_threads \
    rsync -v -e "$rsync_ssh_cmd" \
    --progress \
    --timeout=60 \
    --human-readable \
    --partial-dir=$dst_dir/rsync_tmp \
    --delete \
    --exclude '*.partial~' \
    --log-file=$logfile \
    --relative \
    --no-owner \
    --modify-window=1 \
    --size-only \
    --bwlimit=$bw_limit \
    $rsync_username@$rsync_address:"$source/{}" "$dst_dir"
  else
    # Configure for rsync filesystem compatibility - ext4
    cat $work_dir/rsync_process_list.txt | xargs -I {} -P $rsync_threads \
    rsync -av -e "$rsync_ssh_cmd" \
    --progress \
    --timeout=60 \
    --human-readable \
    --partial-dir=$dst_dir/rsync_tmp \
    --delete \
    --exclude '*.partial~' \
    --log-file=$logfile \
    --relative \
    --no-owner \
    --bwlimit=$bw_limit \
    $rsync_username@$rsync_address:"$source/{}" "$dst_dir"
  fi

  # Capture the rsync exit code
  exit_code=$?
  # Display rsync exit code
  echo "Rsync exit code: $exit_code"

  if [[ $exit_code -ne 0 ]]
  then
    # Create log entry - retry
    echo -e "#---- WARNING - RSYNC FAIL\nFail date : $(date)\nTrying again in $rsync_sleep_time seconds (Attempt: $retry_count of $rsync_cnt_timeout)\n" >> $logfile

    # Apply retry delay
    sleep $rsync_sleep_time

    # Add to retry counter
    ((retry_count++))
  fi
done

if [[ $exit_code -eq 0 ]]
then
  echo "Rsync completed successfully."
else
  # Create log entry - fail
  echo -e "#---- WARNING - RSYNC FAIL\nFail date : $(date)\nFailed to establish rsync connection. Exiting script.\n" >> $logfile
fi
#-----------------------------------------------------------------------------------