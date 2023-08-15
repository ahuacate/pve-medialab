#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_gitupdater.sh
# Description:  Updates clients default script files to latest version     
# ----------------------------------------------------------------------------------

# This file cannot be run directly because its tasked to replace itself.
# Must be run using the cmd:
#    source <( cat ${app_dir}/kodirsync_clientapp_gitupdater.sh )

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

#---- Check Auto or manual run
# Auto run on day X, continue to parent script if not
# 7th day is Sunday
dow=$(date +%u)
if [ ! "$dow" = 7 ] && [ ! -z "$1" ]
then
  unset $1
  return
fi


#---- Static Variables -------------------------------------------------------------

# Git user
git_dl_user='ahuacate'
# Git repository
git_dl_repo='pve-medialab'
# Git branch
git_dl_branch='main'

# Set $app_dir
if [ -z "$app_dir" ]
then
  app_dir=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )
fi

# Log files
now=$(date +"%F")
logfile="$app_dir/logs/kodirsync-${now}.log"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Git Update files
git_update_LIST=( "kodirsync_clientapp_gitupdater.sh" \
"kodirsync_clientapp_default.cfg" \
"kodirsync_clientapp_run.sh" \
"kodirsync_clientapp_script.sh" \
"kodirsync_clientapp_prune.sh" \
"kodirsync_clientapp_list1.sh" \
"kodirsync_clientapp_node_run.sh" \
"kodirsync_clientapp_node_script.sh" \
"kodirsync_clientapp_node_rsync_main.sh" \
"kodirsync_clientapp_node_rsync_app.sh" \
"kodirsync_clientapp_node_prune.sh" \
"kodirsync_clientapp_rsync_main.sh" \
"kodirsync_clientapp_rsync_throttle.sh" \
"kodirsync_clientapp_rsync_throttle_tune.sh" \
"kodirsync_clientapp_kodi_gitupdater.py" \
"kodirsync_clientapp_kodi_run.py" \
"kodirsync_clientapp_kodi_status.py" \
"kodirsync_clientapp_kodi_install_favourites.sh" \
"kodirsync_control_list.tmpl" \
"audio_format_filter.txt" \
"audiobook_format_filter.txt" \
"exclude_dir_filter.txt" \
"exclude_file_filter.txt" \
"exclude_os_dir_filter.txt" \
"image_format_filter.txt" \
"iso_language_codes.txt" \
"other_format_filter.txt" \
"subtitle_format_filter.txt" \
"video_format_filter.txt" \
"kodi_icon_start.png" \
"kodi_icon_stop.png" \
"kodi_thumb_start.png" \
"kodi_thumb_status.png" \
"kodi_thumb_updater.png" \
"termux_widget/Start-Kodirsync.bash" \
"termux_widget/Stop-Kodirsync.bash" \
"termux_widget/Start-Kodirsync.png" \
"termux_widget/Stop-Kodirsync.png" \
"termux_widget/Update-Widget.bash" )

#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Start Job log
echo -e "#---- GIT SCRIPT UPDATE -------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile


#---- Prerequisites

# Check for existing Kodirsync events
# List of script names or keywords to check
# 'kodirsync_id' and 'kodirsync_node' will discover any rsync or ssh events (associates with key name)
script_names=(
  kodirsync_id
  kodirsync_node
)

# Check $script_names list
for script_name in "${script_names[@]}"
do
  # Get PIDs of running scripts except the current one ($$)
  pids=$(pgrep -f "$script_name" | grep -v "$$")

  # If pids exist
  if [ -n "$pids" ]
  then
    for pid in $pids; do
      # Return to parent script (skip GitHub update)
      return
    done
  fi
done

# Get Kodirsync User permissions
file_perms=$(ls -ld $app_dir | awk '{print $3 ":" $4}')

# Make dl dir
dl_dir=/tmp/dl
mkdir -p $dl_dir
mkdir -p $dl_dir/termux_widget

#---- Get Github update

# DL retry cnt max
max_retries=3

#---- Get Github update

# DL retry cnt max
max_retries=3

# Get Github update release
while IFS='' read -r filename
do
  # Start retry counter
  retries=0

  while [ "$retries" -lt "$max_retries" ]
  do
    # Download GitHub files
    echo "DL from GitHub: $filename"
    curl --fail -o "$dl_dir/$filename" -f "https://raw.githubusercontent.com/$git_dl_user/$git_dl_repo/$git_dl_branch/src/kodirsync/clientapp/$filename"

    # Check if curl command succeeded
    if [ $? -eq 0 ]
    then
      # Set exit status ('0' for failure, '1' for success)
      dl_status=1
      break  # Break out of the retry loop if download succeeded
    fi

    # On fail increase $retries cnt
    retries=$((retries + 1))
    # Display msg
    echo "DL attempt count: $retries"

    # Set exit status ('0' for failure, '1' for success)
    dl_status=0

    # Sleep before trying again
    sleep 3
  done
  
  # Download success - fail (fallback to current local files)
  if [ "$dl_status" = 0 ]
  then
    # Create log entry
    error_MSG=( "$(echo -e "#---- WARNING - GIT SCRIPT UPDATE FAIL\nUpdate filename : ${filename}\nDownload issues. Check your internet connection and try again. File not updated.\n")" )
    printf "%s\n" "${error_MSG[@]}" >> $logfile

    # Skip the update
    # After '$max_retries' connection failures we skip the updating process.
    echo "Skipping GitHub updates. Proceeding with current installed version..."
    break
  fi
done < <( printf '%s\n' "${git_update_LIST[@]}" )

#---- If GitHub download successful
# Only update if all files were downloaded successfully.

if [ "$dl_status" = 1 ]
then
  while IFS='' read -r filename
  do
    # Create log entry
    display_MSG=( "$(echo -e "Start time : $(date)\nUpdated filename : ${filename}\n")" )
    printf "%s\n" "${display_MSG[@]}" >> $logfile

    # Move new file to App dir
    rm "$app_dir/$filename" 2> /dev/null
    mv "$dl_dir/$filename" "$app_dir/$filename"
    chown "$file_perms" "$app_dir/$filename"

    # Chmod +x the exec files
    if [[ "$filename" =~ ^.*\.(sh|cfg|bash)$ ]]
    then
      chmod +x "$app_dir/$filename"
    fi
  done < <( printf '%s\n' "${git_update_LIST[@]}" )
fi


#---- Finish Line ------------------------------------------------------------------

# Remove temporary dl dir
rm -R "$dl_dir" 2> /dev/null

# Finish Job log
echo -e "#---- GIT SCRIPT UPDATE FINISHED ---------------------------------------------------\n" >> $logfile

# Parse $dl_status to python script (for Kodi installs)
echo "$dl_status"
#-----------------------------------------------------------------------------------------------------------------------
