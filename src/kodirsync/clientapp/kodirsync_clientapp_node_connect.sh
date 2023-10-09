#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_node_connect.sh
# Description:  SSH rsync script to push files to nodes
#
# Usage         Requires parent files:
#                       'kodirsync_clientapp_node_script.sh'
#
#-----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------


# Single rsync with retry loop
function start_single_node_rsync() {
    # Set other variables
    local max_retries="$rsync_retry_cnt"  # Maximum number of retries (adjust as needed)

    # Start rsync loop
    local retry
    for ((retry = 0; retry <= max_retries; retry++)); do

        # Run Rsync
        rsync -e "ssh -i $HOME/.ssh/$node_ssh_private_key_name" "${rsync_args[@]}" "$local_dir" $node_user@$lan_address:"$node_dir"

        # Process rsync exit codes
        if [ $? = 0 ]; then
            # On rsync success
            return 0  # Set exit code
        else
            # On rsync fail
            # Use ps to find the PID of rsync/ssh commands with the specific source file
            local rsync_pids=()
            rsync_pids+=( $(pgrep -f "^(rsync.*|ssh.*)") )
            # Iterate through the array and send SIGTERM to each PID and its children
            local pid
            for pid in "${rsync_pids[@]}"; do
                if [ -n "$pid" ]; then
                    echo "Killing PID and its children: $pid"
                    kill -TERM "$pid" 2> /dev/null  # Send SIGTERM to the process
                    sleep 0.5  # Wait for a moment before sending SIGKILL if needed
                    kill -KILL "$pid" 2> /dev/null  # Send SIGKILL to the process
                fi
            done

            if [[ $retry -lt $max_retries ]]; then
                sleep $rsync_retry_sleep  # Apply sleep period before retry
            else
                # Log entry
                echo -e "#---- WARNING - RSYNC FAIL\nFail date : $(date)\nReached retry count limit.\n" >> "$logfile"

                return=1  # Set exit code
            fi
        fi
    done
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

#---- Set rsync dl arguments by disk type / OS type

if [ "$node_stor_fs" = exfat ] || [ "$ostype" = 'termux' ]; then
    # Configure for rsync filesystem compatibility -exFAT or Termux/Android OS
    rsync_args_single=(
    --verbose
    --progress
    --timeout=60
    --human-readable
    --partial-dir=$node_rsync_tmp
    --delete
    --delete-before
    --exclude '*.partial~'
    --log-file=$logfile
    --files-from=$work_dir/rsync_ul_list.txt
    --relative
    --no-owner
    --modify-window=1
    --size-only
    )
else
    # Configure for rsync filesystem compatibility - ext4
    rsync_args_single=(
    --archive
    --verbose
    --progress
    --timeout=60
    --human-readable
    --partial-dir=$node_rsync_tmp
    --delete
    --delete-before
    --exclude '*.partial~'
    --log-file=$logfile
    --files-from=$work_dir/rsync_ul_list.txt
    --relative
    --no-owner
    )
fi


#---- Start dl rsync processes

# Check 'rsync_ul_list.txt'
if [ -f "$work_dir/rsync_ul_list.txt" ] && [[ $(cat "$work_dir/rsync_ul_list.txt" | wc -l) -ge 1 ]]; then
    # Read the list of items to sync line by line
    IFS=$'\n' source_files=($(grep -E -v '^\s*$|^\s*#' "$work_dir/rsync_ul_list.txt"))
else
    # Log entry & exit
    echo -e "#---- WARNING - RSYNC FAIL\nFail date : $(date +"%F %T")\nInput file 'rsync_ul_list.txt' empty.\n" >> "$logfile"
    trap cleanup EXIT  # Exit script
fi

# Run func 'start_single_node_rsync' 
rsync_args=("${rsync_args_single[@]}")
start_single_node_rsync
#-----------------------------------------------------------------------------------