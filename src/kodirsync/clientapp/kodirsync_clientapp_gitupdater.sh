#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_gitupdater.sh
# Description:  Updates clients default script files to latest version     
# ----------------------------------------------------------------------------------

# This file cannot be run directly because its tasked to replace itself.
# Must be run using the cmd:
#    source <( cat ${app_dir}/kodirsync_clientapp_gitupdater.sh )

#---- Source Github
# bash -c "$(curl -L https://raw.githubusercontent.com/ahuacate/pve-medialab/main/src/kodirsync/clientapp/kodirsync_clientapp_gitupdater.sh)"

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

#---- Check Auto or manual run
# Auto run on the 7th day of the month, continue to parent script if not
day_of_month=$(date +%d)
if [ "$day_of_month" != "07" ] && [ ! -z "$1" ]; then
    unset $1
    return
fi

#---- Cleanup trap function
if [ ! -z "$1" ]; then
    cleanup() {
        # Add cleanup actions here
        rm -Rf "$work_dir" 2> /dev/null
    }

    # Set up trap to call the cleanup function on script exit or specific signals
    trap cleanup EXIT SIGHUP SIGINT SIGTERM
fi


#---- Static Variables -------------------------------------------------------------

# GitHub credentials
git_dl_user='ahuacate'      # Git user
git_dl_repo='pve-medialab'  # Git repository
git_dl_branch='main'        # Git branch


#---- Other Variables --------------------------------------------------------------

# Set $app_dir
if [ -z "$app_dir" ]; then
    app_dir=$(find / -type d -name kodirsync_app -not -path "/storage/*" -not -path "/tmp/*")
fi

# Check if $app_dir is still empty
if [ -z "$app_dir" ]; then
    # Print display message
    echo "kodirsync_app directory not found. Exiting the script."
    exit 1  # Exit the script with a non-zero status
fi

# Log files
now=$(date +"%F")
logfile="$app_dir/logs/kodirsync-${now}.log"


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
    kodirsync_clientapp_dev_clean.sh
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
    kodirsync_clientapp_kodi_libraryscan.py
    kodirsync_clientapp_kodi_node_run.py
    kodirsync_clientapp_kodi_run.py
    kodirsync_clientapp_kodi_status.py
    kodirsync_clientapp_list1.sh
    kodirsync_clientapp_node_connect.sh
    kodirsync_clientapp_node_prune.sh
    kodirsync_clientapp_node_run.sh
    kodirsync_clientapp_node_script.sh
    kodirsync_clientapp_prune.sh
    kodirsync_clientapp_run_deps.sh
    kodirsync_clientapp_run.sh
    kodirsync_clientapp_script.sh
    kodirsync_clientapp_uninstall_elec.sh
    kodirsync_clientapp_uninstall_linux.sh
    kodirsync_clientapp_user.cfg
    kodirsync_control_list.tmpl
    kodirsync_node_install_storage.sh
    kodi_icon_idle.png
    kodi_icon_start.png
    kodi_icon_stop.png
    kodi_thumb_cleanup.png
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

            # Download file
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
            # Log entry
            echo -e "#---- WARNING - GIT SCRIPT UPDATE FAIL\nGitHub connection issues: Check your internet connection and try again.\nProceeding with the current installed version." >> "$logfile"

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

# Check for existing Kodirsync events
# List of script names or keywords to check
# 'kodirsync_id' and 'kodirsync_node' will discover any rsync or ssh events (associates with key name)
script_names=(
  kodirsync_id
  kodirsync_node
)
for script_name in "${script_names[@]}"; do
    pids=$(pgrep -f "$script_name" | grep -v "$$")  # Get PIDs of running scripts except the current one ($$)
    # If PIDs exist
    if [ -n "$pids" ]; then
        for pid in $pids; do
            return  # Return to parent script (skip GitHub update)
        done
    fi
done

# Create temp work dir (if missing)
if [ -z "$work_dir" ]; then
    work_dir=$(mktemp -dt -p /tmp kodirsync-XXXXXX)
fi

# Backup 'kodirsync_clientapp_user.cfg' to $work_dir
if [ -e "$app_dir/kodirsync_clientapp_user.cfg" ]; then
    cp -f "$app_dir/kodirsync_clientapp_user.cfg" "$work_dir/kodirsync_clientapp_user.cfg.old"
fi

# Get Kodirsync User permissions
file_perms=$(ls -ld $app_dir | awk '{print $3 ":" $4}')

#---- Download latest GitHub app files (main branch)

# Run GitHub updater
dl_github_updates "$git_dl_user" "$git_dl_repo" "$git_dl_branch"
if [ $? = 1 ]; then
    # Log entry
    echo -e "#---- WARNING - GIT SCRIPT UPDATE FAIL\nGitHub connection issues: Check your internet connection and try again.\nProceeding with the current installed version." >> "$logfile"
    echo -e "#---- GIT SCRIPT UPDATE FINISHED ---------------------------------------------------\n" >> "$logfile"
    return  # Process exit codes
fi


#---- Remove files in $app_dir (keeping ssh keys & user config)

# Exclude regex of files and dirs
exclude_update_file_regex='.*\.(key|ppk|pub|crt|db)$|.*kodirsync_id_ed25519$|.*kodirsync_node_rsa_key$|.*/kodirsync_clientapp_user.cfg.old$|.*/kodirsync_control_list.txt$'
exclude_update_dir_regex='\.*|cache|\#recycle|\@eaDir|lost+found|images|logs'

# Remove old local app files
find "$app_dir" -regextype posix-extended -not -iregex ".*/($exclude_update_dir_regex)/.*" -type f -regextype posix-extended -not -iregex ".*/($exclude_update_file_regex)" -exec rm -f {} \;


#---- Update $app_dir with latest files

# Copy GitHub latest files to $app_dir
for source_file in "${git_update_LIST[@]}"; do
    # Copy $entry to App dir
    cp -f -r "$work_dir/$source_file" "$app_dir/$source_file"
    chown "$file_perms" "$app_dir/$source_file"

    # Set executable file permissions
    if [[ "$source_file" =~ ^.*\.(sh|cfg|bash|py)$ ]]; then
        chmod +x "$app_dir/$source_file" 2> /dev/null  # Chmod +x any exec file
    fi
done

#---- Update new GitHub User config file ( kodirsync_clientapp_user.cfg ) with old user values

if [ -e "$work_dir/kodirsync_clientapp_user.cfg.old" ]; then
    old_config_file="$work_dir/kodirsync_clientapp_user.cfg.old"
    new_config_file="$app_dir/kodirsync_clientapp_user.cfg"

    # Loop through the lines in the old config file
    while IFS= read -r line; do
        # Check if the line is a valid variable assignment (no # and no leading space)
        if [[ $line =~ ^[^#\ ]+= ]]; then
            # Extract the variable name and value
            variable_name="${line%%=*}"
            variable_value="${line#*=}"

            # Check if the variable exists in the new configuration file
            if grep -q "^$variable_name=" "$new_config_file"; then
                # Variable exists in the new config, update its value
                awk -v var="$variable_name" -v val="$variable_value" -F '=' '$1 == var {$2=val}1' OFS='=' "$new_config_file" > "$new_config_file.tmp" && mv "$new_config_file.tmp" "$new_config_file"
            fi
        fi
    done < "$old_config_file"

    cp -f "$work_dir/kodirsync_clientapp_user.cfg.old" "$app_dir/kodirsync_clientapp_user.cfg.old"  # Copy backup to $app_dir (overwrite any previous copy)
fi


#---- Update entries in kodi favourites.xml

if [ -d "/storage/.kodi/addons" ]; then
    source $app_dir/kodirsync_clientapp_kodi_install_favourites.sh
fi

#---- Update cron if required
config_file="$app_dir/kodirsync_clientapp_user.cfg"
variable_name='cron_run_time'

# Check if the variable exists in the config file
if grep -q "^$variable_name=" "$config_file"; then
    value=$(grep "^$variable_name=" "$config_file" | awk -F= '{print $2}')
    eval "$variable_name=\"$value\""  # set bash variable

    # Update cron to user settings
    user=$(ls -ld $app_dir | awk '{print $3}')  # sets user
    source $app_dir/kodirsync_clientapp_install_common_cron.sh
fi


#---- Finish Line ------------------------------------------------------------------

# Finish Job log
echo -e "#---- GIT SCRIPT UPDATE FINISHED ---------------------------------------------------\n" >> $logfile
#-----------------------------------------------------------------------------------