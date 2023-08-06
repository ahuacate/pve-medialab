#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_node_rsync_app.sh
# Description:  Rsync transfer cmd script for '$kodirsync_app' files

# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- Run Rsync

# Define the maximum number of retry attempts and the delay between retries (in seconds)
max_retries=3
retry_delay=5

# Standard rsync - LAN connections only (full bandwidth)
if [ "$node_fs" = exfat ]
then
  # Configure for rsync filesystem compatibility - exFAT used by Termux/Android
  # ExFAT filesystem is not compatible with the rsync '-a' archive option.

  # Define a function to perform the rsync command with retry attempts
  function rsync_with_retries {
    local retries=0
    while [ $retries -lt $max_retries ]; do
      rsync -v -e "ssh -i $HOME/.ssh/$node_ssh_private_key_name" \
      --progress \
      --timeout=60 \
      --human-readable \
      --partial-dir=$node_app_dir/rsync_tmp \
      --delete \
      --exclude '*.partial~' \
      --log-file=$logfile \
      --files-from=$work_dir/rsync_app_list.txt \
      --relative \
      --no-owner \
      --modify-window=1 \
      --size-only \
      "$local_app_dir" $node_user@$lan_address:"$node_app_dir"

      # Check the exit status of the rsync command
      if [ $? -eq 0 ]; then
        # Success, exit the loop
        break
      else
        # Increment the retry count and wait for the retry delay
        ((retries++))
        sleep $retry_delay
        echo "Retrying rsync... Attempt $retries"
      fi
    done
  }

  rsync_with_retries
else
  # Configure for rsync filesystem compatibility - ext4

  # Define a function to perform the rsync command with retry attempts
  function rsync_with_retries {
    local retries=0
    while [ $retries -lt $max_retries ]; do
      rsync -av -e "ssh -i $HOME/.ssh/$node_ssh_private_key_name" \
      --progress \
      --timeout=60 \
      --human-readable \
      --partial-dir=$node_app_dir/rsync_tmp \
      --delete \
      --exclude '*.partial~' \
      --log-file=$logfile \
      --files-from=$work_dir/rsync_app_list.txt \
      --relative \
      --no-owner \
      "$local_app_dir" $node_user@$lan_address:"$node_app_dir"

      # Check the exit status of the rsync command
      if [ $? -eq 0 ]; then
        # Success, exit the loop
        break
      else
        # Increment the retry count and wait for the retry delay
        ((retries++))
        sleep $retry_delay
        echo "Retrying rsync... Attempt $retries"
      fi
    done
  }

  rsync_with_retries
fi
#-----------------------------------------------------------------------------------