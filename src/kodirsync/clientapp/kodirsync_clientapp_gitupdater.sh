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
# Auto run on day 7
# Manual usage: kodirsync_clientapp_gitupdate.sh "now"
dow=$(date +%u)
if [ ! "${dow}" == '7' ] && [ ! -z "$1" ]
then
  return
fi

#---- Static Variables -------------------------------------------------------------

# Git user
git_dl_user='ahuacate'
# Git repository
git_dl_repo='pve-medialab'
# Git branch
git_dl_branch='master'

# Set kodirsync app dir
if [ -z "${app_dir+x}" ]
then
  # OS Type
  ostype=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)

  # Set 'app_dir'
  if [[ ${ostype} =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]
  then
    app_dir='/storage/kodirsync'
  else
    app_dir='/usr/local/bin/kodirsync'
  fi
fi

# Log files
now=$(date +"%F")
logfile="$app_dir/logs/kodirsync-${now}.log"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Git Update files
git_update_LIST=( "kodirsync_clientapp_gitupdater.sh" \
"kodirsync_clientapp_default.cfg" \
"kodirsync_clientapp_script.sh" \
"audio_format_filter.txt" \
"audiobook_format_filter.txt" \
"image_format_filter.txt" \
"iso_language_codes.txt" \
"other_format_filter.txt" \
"video_format_filter.txt" \
"video_sub_format_filter.txt" )

#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Start Job log
echo -e "#---- GIT SCRIPT UPDATE -------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile

# Get Kodirsync User permissions
file_perms=$(ls -ld /usr/local/bin/kodirsync | awk '{print $3 ":" $4}')

# Make dl dir
dl_dir=/tmp/dl
mkdir -p $dl_dir

# Get Github update release
while IFS='' read -r filename
do
  # Download files
  curl --fail -o $dl_dir/$filename -f https://raw.githubusercontent.com/$git_dl_user/$git_dl_repo/$git_dl_branch/src/kodirsync/clientapp/$filename

  # dl status
  exit_status=$?
  
  if [ "$exit_status" != 0 ]
  then
    #---- Download success (fallback to current local file)
    # Create log entry
    error_MSG=( "$(echo -e "#---- WARNING - GIT SCRIPT UPDATE FAIL\nUpdate filename : ${filename}\nDownload issues. Check your internet connection and try again. File not updated.\n")" )
    printf "%s\n" "${error_MSG[@]}" >> $logfile

    # Print display for manual update
    if [ ! -z "$1" ]
    then
      printf "%s\n" "${error_MSG[@]}"
    fi
    # Delete temporary file
    rm $dl_dir/$filename 2> /dev/null
    # Try next file to dl
    continue
  fi

  #---- Download success 
  # Create log entry
  display_MSG=( "$(echo -e "Start time : $(date)\nUpdated filename : ${filename}\n")" )
  printf "%s\n" "${display_MSG[@]}" >> $logfile
  # Print display for manual update
  if [ ! -z "$1" ]
  then
    printf "%s\n" "${display_MSG[@]}"
    echo
  fi
  
  # Move new file to App dir
  rm "$app_dir/$filename" 2> /dev/null
  mv "$dl_dir/$filename" "$app_dir/$filename"
  chown "$file_perms" "$app_dir/$filename"
  # Chmod +x the exec files
  if [[ "$filename" =~ ^.*\.(sh|cfg)$ ]]
  then
    chmod +x "$app_dir/$filename"
  fi
done < <( printf '%s\n' "${git_update_LIST[@]}" )

# Remove dl dir
rm -R $dl_dir

# Finish Job log
echo -e "#---- GIT SCRIPT UPDATE FINISHED ---------------------------------------------------\n" >> $logfile
#-----------------------------------------------------------------------------------------------------------------------