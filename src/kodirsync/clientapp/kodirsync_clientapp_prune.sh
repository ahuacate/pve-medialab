#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_prune.sh
# Description:  Source script for pruning Kodirsync media and logs
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

# Display list of files in terminal (dev only)
echo "Local files..........."
printf '%s\n' "${all_client_LIST[@]}"
echo "Server files..........."
printf '%s\n' "${dl_server_LIST[@]}"

#---- Remove old or non-current media files from destination
# This is two step removal process. First check the $dst_dir.
# Second check the $rsync_tmp dir for orphaned or non-current temporary downloads.

# Remove old and depreciated $dst_dir files - step 1
# Iterate files in '${all_client_LIST[@]}' and '${dl_server_LIST[@]}' arrays
for client in "${all_client_LIST[@]}"
do
  # Extract col1 value from client (actual filename)
  client_col1=$(echo "$client" | cut -d';' -f1)
  found=false

  # Get filename basename
  filename=$(basename "$client_col1")
  
  # Check if the file matches the exclude pattern
  [[ "$(printf '%q' "$client_col1")" =~ ^.*/($exclude_dir_filter_regex)/.*$ ]] && continue
  [[ "$(printf '%q' "$filename")" =~ ^($exclude_file_filter_regex)$ ]] && continue
  [[ "$(printf '%q' "$filename")" =~ ^.*($rsync_part_filter_regex)$ ]] && continue

  # Iterate over each server in the dl_server_LIST array
  for server in "${dl_server_LIST[@]}"
  do
    # Extract col1 value from server
    server_col1=$(echo "$server" | cut -d';' -f1)

    # Check if col1 values match
    if [[ "$client_col1" == "$server_col1" ]]
    then
      found=true
      break
    fi
  done

  # If no match is found, remove the client file
  if ! $found
  then
    echo "$client_col1"
    # Remove the client file
    rm -f "$dst_dir/$client_col1" 2> /dev/null
  fi
done

# Remove old and depreciated $rsync_tmp files - step 2
# Iterate files in '${all_client_LIST[@]}' and '${dl_server_LIST[@]}' arrays
# Initialize array
client_rsync_tmp_LIST=()
while IFS= read -r client
do
  # Extract client filename
  client_filename=$(echo "$client" | sed -E "s/\.[A-Za-z0-9]{6}$//; s/\.($rsync_part_filter_regex)$//")
  client_filename=$(basename "$client_filename")
  found=false

  # Iterate over each server in the dl_server_LIST array
  for server in "${dl_server_LIST[@]}"
  do
    # Extract col1 value from server
    server_filename=$(echo "$server" | cut -d';' -f1)
    server_filename=$(basename "$server_filename")

    # Check if col1 values match
    if [[ "$client_filename" == "$server_filename" ]]
    then
      found=true
      break
    fi
  done

  # If no match is found, remove the client file
  if ! $found
  then
    # Remove the client file
    rm -f "$client" 2> /dev/null
  fi
done < <( find "$dst_dir/rsync_tmp" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex)(/.*)?" -type f -regextype posix-extended -iregex ".*\.($rsync_part_filter_regex)$|.*\.($video_format_filter_regex|$subtitle_format_filter_regex|$image_format_filter_regex|$audio_format_filter_regex|$audiobook_format_filter_regex)(\.[A-Za-z0-9]{6})?$" 2> /dev/null )


#---- Find old and non-current rsync '*.part' files
# Temporary '.PART' files do not inherit the timestamps of the original server files.
# Instead, the '.PART' files are created with the current timestamp at the time
# of their creation. So its possible to remove old or depreciated '.PART' files.

# Current epoch date
current_epoch=$(date +%s)
threshold=$((current_epoch - (rsync_part_age * 24 * 60 * 60)))  # Calculating threshold in seconds

# Remove '*.part' file if older than $threshold and non-current '*.part' files
while IFS=';' read -r file epoch_date
do
  # Extract client filename from rsync '*.part' (actual filename)
  actual_filename=$(echo "$file" | sed -E 's/\.part$//I')
  found=false

  # Iterate over each server in the dl_server_LIST array
  for server in "${dl_server_LIST[@]}"
  do
    # Extract col1 value from server
    server_col1=$(echo "$server" | cut -d';' -f1)

    # Check if col1 values match
    if [[ "$actual_filename" == "$server_col1" ]]
    then
      found=true
      break
    fi
  done
  # If no match is found, print the client file
  if ! $found
  then
    # Remove the client '*.part' file
    rm -f "$file" 2> /dev/null
  fi

  # Remove the client'*.part' file if older than $threshold
  if [[ "$epoch_date" -lt "$threshold" ]]
  then
    # Remove the '.PART' file
    rm -f "$file" 2> /dev/null
  fi
done < <( find "$dst_dir" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex)(/.*)?" -type f -regextype posix-extended -iregex ".*\.($rsync_part_filter_regex)$" -printf '%P;%T@\n' 2> /dev/null )


#---- Remove small or widowed dirs (folders with small files or without video media)
while IFS=$'\t' read -r dir_size dir_path
do
  # Extract the size portion from dir_size
  dir_size="${dir_size%%[!0-9]*}"

  # Set minimum dir size per content type
  # (i.e $dst_video_dir_minsize vs $dst_other_dir_minsize)
  if [[ "$dir_path" =~ ^$dst_dir/($video_subfolder_dir_filter_regex).*$ ]]
  then
    # Set for '$dst_video_dir_minsize'
    dst_dir_minsize="${dst_video_dir_minsize%%[!0-9]*}"
  else
    # Set for '$dst_other_dir_minsize'
    dst_dir_minsize="${dst_other_dir_minsize%%[!0-9]*}"
  fi
  # Check if the dir matches the exclude pattern
  [[ "$dir_path" =~ ^/$dst_dir/($share_dir_filter_regex2)$ ]] && continue

  # Delete dir if its under $dst_dir_minsize (KB)
  [[ "$dir_size" -lt "$dst_dir_minsize" ]] && rm -rf "$dir_path" 2> /dev/null
done < <( find "$dst_dir" -regextype posix-extended -not -regex ".*/($kodirsync_dir_filter_regex)$|.*/($exclude_dir_filter_regex)(/.*)?$|.*/($exclude_os_dir_filter_regex)(/.*)?$|.*/kodirsync_storage/($share_dir_filter_regex2)$" -type d -exec du -ks "{}" \; 2> /dev/null )
#-----------------------------------------------------------------------------------