#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_rsync_throttle_tune.sh
# Description:  Optimize DL BW limit per rsync thread
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
rsync_sleep_time="${1}"         # Sleep time between retries
rsync_cnt_timeout="${2}"       # Maximum number of retries
rsync_ssh_cmd="${3}"           # SSH command
work_dir="${4}"                # Working directory for rsync
bw_limit="${5}"    # Throttle bandwidth limit in kilobits per second
rsync_username="${6}"          # Rsync username
rsync_address="${7}"           # Rsync server address
source="${8}"                  # Source directory/file
dst_dir="${9}"                # Destination directory
rsync_threads="${10}"         # Max rsync threads

#---- Run rsync file count

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
    cat $work_dir/rsync_process_list.txt | xargs -I {} -P 1 \
    rsync -v -e "$rsync_ssh_cmd" \
    --dry-run \
    --timeout=60 \
    --human-readable \
    --partial-dir=$dst_dir/rsync_tmp \
    --exclude '*.partial~' \
    --relative \
    --no-owner \
    --modify-window=1 \
    --size-only \
    --out-format="%f" \
    $rsync_username@$rsync_address:"$source/{}" "$dst_dir" | grep -E "\.$video_format_filter_regex$" > $work_dir/rsync_video_dl_list.txt
  else
    # Configure for rsync filesystem compatibility - ext4
    cat $work_dir/rsync_process_list.txt | xargs -I {} -P 1 \
    rsync -av -e "$rsync_ssh_cmd" \
    --dry-run \
    --timeout=60 \
    --human-readable \
    --partial-dir=$dst_dir/rsync_tmp \
    --exclude '*.partial~' \
    --relative \
    --no-owner \
    --out-format="%f" \
    $rsync_username@$rsync_address:"$source/{}" "$dst_dir" | grep -E "\.$video_format_filter_regex$" > $work_dir/rsync_video_dl_list.txt
  fi

  # Capture the rsync exit code
  exit_code=$?
  # Display rsync exit code
  echo "Rsync exit code: $exit_code"

  if [[ $exit_code -ne 0 ]]
  then
    # Apply retry delay
    sleep $rsync_sleep_time

    # Add to retry counter
    ((retry_count++))
  fi
done

# Return to parent script on fail
if [[ $exit_code -ne 0 ]]
then
  # Set $bw_limit_tune to default
  bw_limit_tune=$(( bw_limit_tune / rsync_threads ))

  # Set $rsync_threads_tune to default
  rsync_threads_tune=$rsync_threads

  # Return to parent script
  return
fi

#---- Set throttle args
# Optimize '$bw_limit' and '$rsync_threads' rsync args to
# maximise speed according to the number of video (large files) to rsync.
# Applies a % increase to widowed video files (at the tail if cnt is less
# than '$rsync_threads') by increasing the DL speed limit per thread.

# Set video DL file cnt
video_dl_cnt=$(cat $work_dir/rsync_video_dl_list.txt | grep -E "$video_format_filter_regex$" | wc -l 2> /dev/null) # DL cnt

if [ "$video_dl_cnt" -le "$rsync_threads" ]; then
  # Rsync threads
  new_rsync_threads="$video_dl_cnt"

  # BW limit per thread
  new_bw_limit=$((bw_limit / new_rsync_threads))
else
  if [ "$((video_dl_cnt % rsync_threads))" -eq 0 ]; then
    # Rsync threads
    new_rsync_threads="$rsync_threads"

    # BW limit per thread
    new_bw_limit=$((bw_limit / rsync_threads))
  else
    # Rsync threads
    new_rsync_threads="$rsync_threads"

    # Remaining DL cnt (non multiple members of $rsync_threads)
    remaining_dl_cnt="$(( video_dl_cnt % rsync_threads ))"

    # Calculate the percentage increase based on remaining_dl_cnt and video_dl_cnt
    percentage_increase=$(( remaining_dl_cnt * 100 / video_dl_cnt ))

    # Calculate the new bandwidth limit per thread based on the percentage increase
    new_bw_limit="$(( (bw_limit + (bw_limit * percentage_increase / 100)) / rsync_threads ))"
  fi
fi

# Update BW limit (per thread)
bw_limit_tune=$new_bw_limit

# Update rsync_thread count 
rsync_threads_tune=$new_rsync_threads
#-----------------------------------------------------------------------------------