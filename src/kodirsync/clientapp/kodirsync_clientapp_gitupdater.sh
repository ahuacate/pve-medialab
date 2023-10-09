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
# Auto run on the 7th day of the month, continue to parent script if not
day_of_month=$(date +%d)
if [ "$day_of_month" != "07" ] && [ ! -z "$1" ]; then
    unset $1
    return
fi


#---- Static Variables -------------------------------------------------------------

# GitHub credentials
git_dl_user='ahuacate'      # Git user
git_dl_repo='pve-medialab'  # Git repository
git_dl_branch='main'        # Git branch

# Set $app_dir
if [ -z "$app_dir" ]; then
    app_dir=$(find / -type d -name kodirsync_app -not -path "/storage/*" -not -path "/tmp/*")
fi

# Log files
now=$(date +"%F")
logfile="$app_dir/logs/kodirsync-${now}.log"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Git Update files
git_update_LIST=()  # Initialize array
git_update_LIST=(
    audiobook_format_filter.txt
    audio_format_filter.txt
    exclude_dir_filter.txt
    exclude_file_filter.txt
    exclude_os_dir_filter.txt
    image_format_filter.txt
    iso_language_codes.txt
    kodirsync_clientapp_connect.sh
    kodirsync_clientapp_default.cfg
    kodirsync_clientapp_gitupdater.sh
    kodirsync_clientapp_installer.sh
    kodirsync_clientapp_install_common_cfg_update.sh
    kodirsync_clientapp_install_common_copyfiles.sh
    kodirsync_clientapp_install_common_cron.sh
    kodirsync_clientapp_install_common_presets.sh
    kodirsync_clientapp_install_elec.sh
    kodirsync_clientapp_install_elec_entware.sh
    kodirsync_clientapp_install_format_disk_exfat.sh
    kodirsync_clientapp_install_format_disk_ext4.sh
    kodirsync_clientapp_install_kodirsync_profile.sh
    kodirsync_clientapp_install_linux.sh
    kodirsync_clientapp_install_linux_storage.sh
    kodirsync_clientapp_install_termux.sh
    kodirsync_clientapp_install_termux_deps.sh
    kodirsync_clientapp_install_termux_storage.sh
    kodirsync_clientapp_kodi_gitupdater.py
    kodirsync_clientapp_kodi_install_favourites.sh
    kodirsync_clientapp_kodi_node_run.py
    kodirsync_clientapp_kodi_run.py
    kodirsync_clientapp_kodi_status.py
    kodirsync_clientapp_list1.sh
    kodirsync_clientapp_node_connect.sh
    kodirsync_clientapp_node_prune.sh
    kodirsync_clientapp_node_run.sh
    kodirsync_clientapp_node_script.sh
    kodirsync_clientapp_script.sh
    kodirsync_clientapp_uninstall_elec.sh
    kodirsync_clientapp_uninstall_linux.sh
    kodirsync_clientapp_user.cfg
    kodirsync_control_list.tmpl
    kodirsync_node_install_storage.sh
    kodi_icon_idle.png
    kodi_icon_start.png
    kodi_icon_stop.png
    kodi_thumb_node_start.png
    kodi_thumb_start.png
    kodi_thumb_status.png
    kodi_thumb_updater.png
    other_format_filter.txt
    subtitle_format_filter.txt
    video_format_filter.txt
    termux_widget/Start-Kodirsync.bash
    termux_widget/Start-Kodirsync.png
    termux_widget/Stop-Kodirsync.bash
    termux_widget/Stop-Kodirsync.png
    termux_widget/Update-Widget.bash
)

# Kodi addon update files
kodi_addon_file_LIST=()  # Initialize array
kodi_addon_file_LIST=(
    kodirsync_clientapp_kodi_run.py
    kodirsync_clientapp_kodi_node_run.py
    kodirsync_clientapp_kodi_gitupdater.py
    kodirsync_clientapp_kodi_status.py
    kodi_icon_start.png
    kodi_icon_stop.png
    kodi_icon_idle.png
    kodi_thumb_node_start.png
    kodi_thumb_start.png
    kodi_thumb_updater.png
    kodi_thumb_status.png
)

#---- Functions --------------------------------------------------------------------

# File dl from GitHub
function dl_github_updates(){
    # Downloads latest branch of files from GitHub in Zip format.
    #
    # Parameters:
    #   1. git_dl_user - Git user at GitHub
    #   2. git_dl_repo - Git repo
    #   3. git_dl_branch - Git branch (main)
    #
    # Global Variables (Must be set before calling this function):
    #   - $work_dir - Path to work dir
    #   - $logfile - Path to the log file for error and warning recording.
    #
    # Usage:
    #   dl_github_updates "$git_dl_user" "$git_dl_repo" "$git_dl_branch"

    # Set argument parameters
    local git_dl_user="$1"  # Git user
    local git_dl_repo="$2"  # Git repository
    local git_dl_branch="$3"  # Git branch
    # Set other variables
    local max_retries=3
    local dl_url="https://raw.githubusercontent.com/$git_dl_user/$git_dl_repo/$git_dl_branch/src/kodirsync/clientapp"  # dl URL

    for entry in "${git_update_LIST[@]}"; do
        local retry=0
        local success=false
        
        while [ $retry -le $max_retries ]; do
            # Create the parent directory structure if it doesn't exist
            parent_dir="$(dirname "$work_dir/$entry")"
            mkdir -p "$parent_dir"

            # Download the ZIP archive
            curl -L -o "$work_dir/$entry" "$dl_url/$entry"
            
            # Check if the download was successful (exit code 0)
            if [ $? -eq 0 ]; then
                success=true
                break
            else
                ((retry++))
                sleep 3
            fi
        done

        # If all retries fail, log an error
        if [ "$success" = false ]; then
            error_MSG="#---- WARNING - GIT SCRIPT UPDATE FAIL"
            error_MSG+="\nGitHub connection issues: Check your internet connection and try again."
            error_MSG+="\nProceeded with the current installed version."
            
            echo -e "$error_MSG" >> "$logfile"
            echo "Skipping GitHub updates. Proceeding with the current installed version..."
            return 1
        fi
    done
    
    return 0
}

#---- Body -------------------------------------------------------------------------

#---- Start Job log
echo -e "#---- GIT SCRIPT UPDATE -------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile


#---- Prerequisites

# Create temp work dir (if missing)
if [ -z "$work_dir" ]; then
    work_dir=$(mktemp -dt -p /tmp kodirsync-XXXXXX)
fi

# Check for existing Kodirsync events
# List of script names or keywords to check
# 'kodirsync_id' and 'kodirsync_node' will discover any rsync or ssh events (associates with key name)
script_names=(
  kodirsync_id
  kodirsync_node
)

# Check $script_names list
for script_name in "${script_names[@]}"; do
    # Get PIDs of running scripts except the current one ($$)
    pids=$(pgrep -f "$script_name" | grep -v "$$")

    # If PIDs exist
    if [ -n "$pids" ]; then
        for pid in $pids; do
            return  # Return to parent script (skip GitHub update)
        done
    fi
done

# Get Kodirsync User permissions
file_perms=$(ls -ld $app_dir | awk '{print $3 ":" $4}')


#---- Download latest GitHub app files (main branch)

# Run GitHub updater
dl_github_updates "$git_dl_user" "$git_dl_repo" "$git_dl_branch"
if [ $? = 1 ]; then
    return  # Process exit codes
fi


#---- If GitHub download successful

# Create log entry
display_MSG=( "$(echo -e "Start time : $(date)\nApp files update completed\n")" )
printf "%s\n" "${display_MSG[@]}" >> $logfile

# Exclude regex of files and dirs
exclude_update_file_regex='.*\.(key|ppk|pub|crt|db)$|.*kodirsync_id_ed25519$|.*kodirsync_node_rsa_key$|.*/kodirsync_clientapp_user.cfg$'
exclude_update_dir_regex='\.*|cache|\#recycle|\@eaDir|lost+found|images|logs'


# Remove old local app files
find "$app_dir" -regextype posix-extended -not -iregex ".*/($exclude_update_dir_regex)/.*" -type f -regextype posix-extended -not -iregex ".*/($exclude_update_file_regex)" -exec rm -f {} \;

# Proceed with updating
for source_file in "${git_update_LIST[@]}"; do
    # Set other variables
    source_filename=$(basename "$source_file")
    source_dir=$(dirname "$source_file")

    # Check if $source_file is for Kodi addons folder
    match=false
    for entry in "${kodi_addon_file_LIST[@]}"; do
        if [[ "$entry" == "$source_filename" ]]; then
            match=true
            break
        fi
    done
    if [ "$match" = true ] && [ -d "/storage/.kodi/addons" ]; then
        kodi_script_dir='/storage/.kodi/addons/script.module.kodirsync'
        mkdir -p $kodi_script_dir  # Make Kodi addons script folder
        cp -f -r "$work_dir/$source_file" "$kodi_script_dir/" 2> /dev/null  # Overwrite existing file
        
        # Set permissions
        if [[ "$source_filename" =~ \.(sh|py)$ ]]; then
            chmod +x "$kodi_script_dir/$source_filename" 2> /dev/null  # Chmod +x any exec file
        fi

        continue  # Proceed to next entry
    fi

    # Copy $source_file to App dir
    cp -f -r "$work_dir/$source_file" "$app_dir/$source_file"
    chown "$file_perms" "$app_dir/$source_file"

    # Set permissions
    if [[ "$source_filename" =~ ^.*\.(sh|cfg|bash|py)$ ]]; then
        chmod +x "$app_dir/$source_file"  # Chmod +x any exec file
    fi
done


#---- Update entries in kodi favourites.xml
if [ -d "/storage/.kodi/addons" ]; then
    source $app_dir/kodirsync_clientapp_kodi_install_favorites.sh
fi


#---- Finish Line ------------------------------------------------------------------

# Finish Job log
echo -e "#---- GIT SCRIPT UPDATE FINISHED ---------------------------------------------------\n" >> $logfile
#-----------------------------------------------------------------------------------