#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_dev_clean.sh
# Description:  Forces update of all Kodi settings and full GitHub script update.
#               We RECOMMEND you make a backup of "$app_dir/kodirsync_clientapp_user.cfg"
#               file to a safe space.
#               A temporary backup copy is stored in your $app_dir.
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

# Remote GitHub version
# bash -c "$(curl -sSL https://raw.githubusercontent.com/ahuacate/pve-medialab/main/src/kodirsync/clientapp/kodirsync_clientapp_dev_clean.sh)" || echo "Failed to download the script."

# Local version (best use the remote version)
# file_path=$(find / -not -path "/tmp/*" -path "*/kodirsync_app/*" -type f -name "kodirsync_clientapp_dev_clean.sh" -print -quit 2>/dev/null) && [ -n "$file_path" ] && bash "$file_path" || echo "Kodirsync dev cleaner not found on this device" 

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# GitHub credentials
git_dl_user='ahuacate'      # Git user
git_dl_repo='pve-medialab'  # Git repository
git_dl_branch='main'        # Git branch

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

#---- Cleanup trap function
cleanup() {
    # Add cleanup actions here
    rm -Rf "$work_dir" 2> /dev/null
}

# Set up trap to call the cleanup function on script exit or specific signals
trap cleanup EXIT SIGHUP SIGINT SIGTERM


#---- File dl from GitHub
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

            # Download the file
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
            echo -e "$error_MSG"
            return 1
        fi
    done
    
    return 0
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Set $app_dir
if [ -z "$app_dir" ]; then
    app_dir=$(find / -type d -name kodirsync_app -not -path "/storage/*" -not -path "/tmp/*")
fi

# Check if $app_dir is still empty
if [ -z "$app_dir" ]; then
    # Print display message
    echo -e "#---- WARNING - Terminal Error\nCould not locate your 'kodirsync_app' folder.\nExiting script.\n"
    exit 1  # Exit the script with a non-zero status
fi

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


#---- Remove entries in kodi favourites.xml

# Clean favourites xml settings
if [ -e '/storage/.kodi/userdata/favourites.xml' ]; then
    # Kodi favourites.xml file 
    xml_file="/storage/.kodi/userdata/favourites.xml"

    # Entry list of Kodirsync
    favourite_name_LIST=()  # Initialize array
    favourite_name_LIST=(
    "Kodirsync start"
    "Kodirsync node start"
    "Kodirsync status"
    "Kodirsync sw updater"
    )

    # Check if 'Kodirsync run' already exists in the file
    for entry in "${favourite_name_LIST[@]}"; do
        if grep -q "<favourite name=\"$entry\"" "$xml_file"; then
            sed -i "/<favourite name=\"$entry\"/,/<\/favourite>/d" "$xml_file"  # Use sed to delete the matching entry from the XML file in-place
        fi
    done
fi

# 'script.module.kodirsync' folder
script_module_kodirsync_dir='/storage/.kodi/addons/script.module.kodirsync'
if [ -e "$script_module_kodirsync_dir" ]; then
    rm -f -r "$script_module_kodirsync_dir"/*  # Delete all files
fi


#---- Remove files in $app_dir (keeping ssh keys & user config)

# Exclude regex of files and dirs
exclude_update_file_regex='.*\.(key|ppk|pub|crt|db)$|.*kodirsync_id_ed25519$|.*kodirsync_node_rsa_key$|.*/kodirsync_clientapp_user.cfg.old$'
exclude_update_dir_regex='\.*|cache|\#recycle|\@eaDir|lost+found|images|logs'

# Remove old local app files
find "$app_dir" -regextype posix-extended -not -iregex ".*/($exclude_update_dir_regex)/.*" -type f -regextype posix-extended -not -iregex ".*/($exclude_update_file_regex)" -exec rm -f {} \;


#---- Download latest GitHub git updater app files (main branch)

git_update_LIST=()  # Initialize array
git_update_LIST=(
    kodirsync_clientapp_gitupdater.sh
    kodirsync_clientapp_user.cfg
)

# Run GitHub updater
dl_github_updates "$git_dl_user" "$git_dl_repo" "$git_dl_branch"
if [ $? = 1 ]; then
    return  # Process exit codes
fi


# Copy latest files to App dir
for source_file in "${git_update_LIST[@]}"; do
    # Copy $entry to App dir
    cp -f -r "$work_dir/$source_file" "$app_dir/$source_file"
    chown "$file_perms" "$app_dir/$source_file"

    # Set permissions
    if [[ "$source_filename" =~ ^.*\.(sh|cfg|bash|py)$ ]]; then
        chmod +x "$app_dir/$source_file"  # Chmod +x any exec file
    fi
done


#---- Update new GitHub config file ( kodirsync_clientapp_user.cfg ) with old values

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

    cp "$work_dir/kodirsync_clientapp_user.cfg.old" "$app_dir/kodirsync_clientapp_user.cfg.old"  # Copy backup to $app_dir
fi


#---- Perform full Kodirsync update

source $app_dir/kodirsync_clientapp_gitupdater.sh


#----- Ensure the cleanup function is also called when your script exits normally

# Finish Job log
echo -e "\n#---- SUCCESS\nFull cleanup and update has been completed.\n" 
exit 0
#-----------------------------------------------------------------------------------