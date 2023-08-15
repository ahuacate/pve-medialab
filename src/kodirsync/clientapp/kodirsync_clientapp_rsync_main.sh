#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_rsync_main.sh
# Description:  Script controls rsync operations
# Usage:        All variables/args set in 'kodirsync_clientapp_default.cfg'
#               Requires parent file 'kodirsync_clientapp_script.sh'
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Set Kodirsync server source dir
source='.'

# Overrides for Android/Termux hosts
# Override the rsync threads for Android/Termux to single rsync thread only
if [ "$ostype" = 'termux' ]
then
  # Override max LAN rsync thread
  max_rsync_threads_lan='1'

  # Override max remote rsync thread
  max_rsync_threads_remote='1'
fi

# Convert '$throttle_bw_limit' Mbps to Kb
throttle_bw_limit_kb=$((throttle_bw_limit_mbps * 1000 / 8))

# Create rsync temporary dir - 'rsync_tmp'
mkdir -p $dst_dir/rsync_tmp

# Copy dl list to '$dst_dir' (for manual user viewer checking only)
cp $work_dir/rsync_process_list.txt $dst_dir/rsync_tmp/rsync_process_list.txt

#---- Run Rsync

# Connect to Kodirsync rsync server
if [[ "$rsync_connection_type" =~ ^(1|2)$ ]]
then
  #---- Convert Start & End times to seconds
  # Here we calculate the throttle start and end times using the user settings
  # '$throttle_start_time' and '$throttle_end_time' from the
  # user file '$kodirsync_clientapp_user.cfg'.

  # Convert start time to seconds
  start_hours=$((10#${throttle_start_time:0:2}))
  start_minutes=$((10#${throttle_start_time:3:2}))
  start_time_seconds=$((start_hours * 3600 + start_minutes * 60))

  # Convert end time to seconds
  end_hours=$((10#${throttle_end_time:0:2}))
  end_minutes=$((10#${throttle_end_time:3:2}))
  end_time_seconds=$((end_hours * 3600 + end_minutes * 60))

  # Calculate duration in seconds
  # This is the throttle duration in seconds
  duration_seconds=$((end_time_seconds - start_time_seconds))


  #---- Run throttled managed rsync
  while true
  do
    # Convert current time to hours, minutes, and seconds
    current_hours=$(date +%H)
    current_minutes=$(date +%M)
    current_seconds=$(date +%S)

    # Convert current time to seconds
    current_time_seconds=$((10#$current_hours * 3600 + 10#$current_minutes * 60 + 10#$current_seconds))

    if [[ "$current_time_seconds" -lt "$start_time_seconds" ]] || [[ "$current_time_seconds" -gt "$end_time_seconds" ]] && [ "$throttle" = 1 ]
    then
      #---- Full bandwidth - no throttle

      # Calculate the remaining time until the start of the next throttle period
      if [[ "$current_time_seconds" -lt "$start_time_seconds" ]]
      then
        remaining_seconds=$((start_time_seconds - current_time_seconds))
      else
        remaining_seconds=$((start_time_seconds + 86400 - current_time_seconds))
      fi

      # Run rsync cmd
      # When referencing positional parameters greater than 9, you need to use
      # an array to correctly pass the parameter value.

      # Required variables to script (passed with array '${args[@]}')
      # rsync_sleep_time="$1"         # Sleep time between retries
      # rsync_cnt_timeout="$2"       # Maximum number of retries
      # ssh_cmd="$3"                 # SSH command (if required)
      # logfile="$4"                 # Path to the log file
      # work_dir="$5"                # Working directory for rsync
      # throttle_bw_limit_kb="$6"    # Throttle bandwidth limit in kilobits per second
      # rsync_username="$7"          # Rsync username
      # rsync_address="$8"           # Rsync server address
      # source="$9"                  # Source directory/file
      # dst_dir="$10"                # Destination directory
      # max_rsync_threads_remote="$11"  # Max rsync threads
      args=("$rsync_sleep_time" \
      "$rsync_cnt_timeout" \
      "$rsync_ssh_cmd" \
      "$logfile" \
      "$work_dir" \
      "0" \
      "$rsync_username" \
      "$rsync_address" \
      "$source" \
      "$dst_dir" \
      "$max_rsync_threads_remote")

      # The '&' at the end of the command is used to run the script in the background,
      # allowing it to execute independently while the throttle part of the script
      # continues to manage the remaining time.
      source "$app_dir/kodirsync_clientapp_rsync_throttle.sh" "${args[@]}" &

      # Save the process pid
      process_pid=$!

      # Display msg
      echo "Remaining run-time before throttle: ${remaining_seconds}s"

      # Sleep for a shorter interval if rsync successful and beak out of loop
      # Kill rsync process if '$remaining_seconds' expired
      for ((i=0; i<$remaining_seconds; i++)); do
        if ! kill -0 "$process_pid" >/dev/null 2>&1; then
          echo "Rsync has completed and finished. Exiting..."
          completed_successfully=true
          break  # Break out of the loop when rsync finishes
        fi
        sleep 1s
      done

      # Check if the process is still running
      if kill -0 "$process_pid" >/dev/null 2>&1; then
        # Display msg
        echo "Killing rsync process. Continuing with throttled bandwidth settings."

        # Stop the process pid
        kill $process_pid

        # Set rsync return code ('0' for finished, '1' for continue)
        rsync_continue_code=1
      else
        echo "Process has been killed. Exiting..."
        break
      fi
    elif [[ "$current_time_seconds" -ge "$start_time_seconds" ]] && [[ "$current_time_seconds" -le "$end_time_seconds" ]] && [ "$throttle" = 1 ]
    then
      #---- Throttle bandwidth

      # Calculate the remaining time until the end of the throttle period
      remaining_seconds=$((end_time_seconds - current_time_seconds))

      # Throttle arg tuner - args
      # Optimize the threads and BW limit for throttled connections
      # Required variables to script (passed with array '${args[@]}')
      # rsync_sleep_time="$1"        # Sleep time between retries
      # rsync_cnt_timeout="$2"       # Maximum number of retries
      # ssh_cmd="$3"                 # SSH command (if required)
      # work_dir="$4"                # Working directory for rsync
      # throttle_bw_limit_kb="$5"    # Throttle bandwidth limit in kilobits per second
      # rsync_username="$6"          # Rsync username
      # rsync_address="$7"           # Rsync server address
      # source="$8"                  # Source directory/file
      # dst_dir="$9"                # Destination directory
      # max_rsync_threads_remote="$10"  # Max rsync threads
      args=("$rsync_sleep_time" \
      "$rsync_cnt_timeout" \
      "$rsync_ssh_cmd" \
      "$work_dir" \
      "$throttle_bw_limit_kb" \
      "$rsync_username" \
      "$rsync_address" \
      "$source" \
      "$dst_dir" \
      "$max_rsync_threads_remote")

      # Run throttle arg tuner
      source "$app_dir/kodirsync_clientapp_rsync_throttle_tune.sh" "${args[@]}"

      # Run rsync - args
      # Required variables to script (passed with array '${args[@]}')
      # rsync_sleep_time="$1"        # Sleep time between retries
      # rsync_cnt_timeout="$2"       # Maximum number of retries
      # ssh_cmd="$3"                 # SSH command (if required)
      # logfile="$4"                 # Path to the log file
      # work_dir="$5"                # Working directory for rsync
      # bw_limit_tune="$6"           # Throttle bandwidth limit in kilobits per second
      # rsync_username="$7"          # Rsync username
      # rsync_address="$8"           # Rsync server address
      # source="$9"                  # Source directory/file
      # dst_dir="$10"                # Destination directory
      # rsync_threads_tune="$11"     # Max rsync threads
      args=("$rsync_sleep_time" \
      "$rsync_cnt_timeout" \
      "$rsync_ssh_cmd" \
      "$logfile" \
      "$work_dir" \
      "$bw_limit_tune" \
      "$rsync_username" \
      "$rsync_address" \
      "$source" \
      "$dst_dir" \
      "$rsync_threads_tune")

      # The '&' at the end of the command is used to run the script in the background,
      # allowing it to execute independently while the throttle part of the script
      # continues to manage the remaining time.
      # Run rsync
      source "$app_dir/kodirsync_clientapp_rsync_throttle.sh" "${args[@]}" &

      # Save the process pid
      process_pid=$!

      # Display msg
      echo "Remaining run-time under throttle: ${remaining_seconds}s"

      # Sleep for a shorter interval if rsync successful and beak out of loop
      # Kill rsync process if '$remaining_seconds' expired
      for ((i=0; i<$remaining_seconds; i++)); do
        if ! kill -0 "$process_pid" >/dev/null 2>&1; then
          # Display msg
          echo "Rsync has completed and finished. Exiting."
          break  # Break out of the loop when rsync finishes
        fi
        sleep 1s
      done

      # Check if the process is still running
      if kill -0 "$process_pid" >/dev/null 2>&1; then
        # Display msg
        echo "Killing rsync process. Continuing with full bandwidth settings."

        # Stop the process pid
        kill $process_pid

        # Set rsync return code ('0' for finished, '1' for continue)
        rsync_continue_code=1
      else
        echo "Process has been killed. Exiting..."
        break
      fi
    elif [ "$throttle" = 0 ]
    then
      #---- Full bandwidth - throttle off

      # Run rsync cmd
      # When referencing positional parameters greater than 9, you need to use
      # an array to correctly pass the parameter value.

      # Required variables to script (passed with array '${args[@]}')
      # rsync_sleep_time="$1"         # Sleep time between retries
      # rsync_cnt_timeout="$2"       # Maximum number of retries
      # ssh_cmd="$3"                 # SSH command (if required)
      # logfile="$4"                 # Path to the log file
      # work_dir="$5"                # Working directory for rsync
      # throttle_bw_limit_kb="$6"    # Throttle bandwidth limit in kilobits per second
      # rsync_username="$7"          # Rsync username
      # rsync_address="$8"           # Rsync server address
      # source="$9"                  # Source directory/file
      # dst_dir="$10"                # Destination 
      # max_rsync_threads_remote="$11"  # Max rsync threads
      args=("$rsync_sleep_time" \
      "$rsync_cnt_timeout" \
      "$rsync_ssh_cmd" \
      "$logfile" \
      "$work_dir" \
      "0" \
      "$rsync_username" \
      "$rsync_address" \
      "$source" \
      "$dst_dir" \
      "$max_rsync_threads_remote")

      # No '&' at the end of the command because no throttling.
      source "$app_dir/kodirsync_clientapp_rsync_throttle.sh" "${args[@]}"
    
      # Set rsync return code ('0' for finished, '1' for continue)
      rsync_continue_code=0
    fi

    #---- Check rsync return code

    # Action on '$rsync_continue_code'
    if [ "$rsync_continue_code" = 1 ]
    then
      # Apply a rsync reconnection delay.
      sleep 15s
    else
      break
      # rsync_fail_count=0
    fi
  done
elif [ "$rsync_connection_type" = 3 ]
then
  # Standard rsync - LAN connections only (full bandwidth)
  if [ "$stor_fs" = exfat ] || [ "$ostype" = 'termux' ]
  then
    # Configure for rsync filesystem compatibility -exFAT or Termux/Android OS
    # ExFAT filesystem is not compatible with the rsync '-a' archive option.
    cat $work_dir/rsync_process_list.txt | xargs -I {} -P $max_rsync_threads_lan \
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
    --modify-window=1 \
    --size-only \
    $rsync_username@$rsync_address:"$source/{}" "$dst_dir"
  else
    # Configure for rsync filesystem compatibility - ext4
    cat $work_dir/rsync_process_list.txt | xargs -I {} -P $max_rsync_threads_lan \
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
    $rsync_username@$rsync_address:"$source/{}" "$dst_dir"
  fi
fi
#-----------------------------------------------------------------------------------