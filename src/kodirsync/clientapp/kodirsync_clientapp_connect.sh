#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_connect.sh
# Description:  SSH rsync script to download files.
#               Includes:
#                       throttle option (i.e --bwlimit)
#                       auto single and parallel multipart rsync
# Usage         Requires parent files:
#                       'kodirsync_clientapp_script.sh'
#
#-----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

#---- Remote SSH bash scripts

# Watch for last multipart filename - function 'start_multipart_rsync'
cat <<EOF > "$work_dir/watch_for_last_multipart_template.sh"
#!/bin/bash

file="\$HOME/\$file_to_watch"

# Start a loop with a timeout
start_time=\$(date +%s)
timeout_seconds=120  # Set the timeout duration in seconds (e.g., 60 seconds)
timeout_expired=false

while true; do
    # Check if the file now exists
    if [ -e "\$file" ]; then
        echo "File has been created."
        break  # Exit the loop when the file is created
    fi

    # Check if the timeout has expired
    current_time=\$(date +%s)
    elapsed_time=\$((current_time - start_time))
    
    if [ "\$elapsed_time" -ge "\$timeout_seconds" ]; then
        echo "Timeout: File not created within \${timeout_seconds} seconds."
        timeout_expired=true
        break
    fi

    # Sleep for a short interval (e.g., 1 second) before checking again
    sleep 5
done

# Exit with a status code indicating whether the file was found or not
if [ "\$timeout_expired" = true ]; then
    exit 1  # Timeout expired
else
    sleep 2  # Sleep delay to make sure file is not being written to
    exit 0  # File found
fi
EOF


# Watch for multipart 'n' part filename - function 'make_multipart_file_LIST'
cat <<EOF > "$work_dir/watch_for_multipart_template.sh"
#!/bin/bash

file="\$HOME/tmp/kodirsync/$rsync_username/\$file_to_watch"

# Start a loop with a timeout
start_time=\$(date +%s)
timeout_seconds=120  # Set the timeout duration in seconds (e.g., 60 seconds)
timeout_expired=false

while true; do
    # Check if the file now exists
    if [ -e "\$file" ]; then
        echo "File has been created."
        break  # Exit the loop when the file is created
    fi

    # Check if the timeout has expired
    current_time=\$(date +%s)
    elapsed_time=\$((current_time - start_time))
    
    if [ "\$elapsed_time" -ge "\$timeout_seconds" ]; then
        echo "Timeout: File not created within \${timeout_seconds} seconds."
        timeout_expired=true
        break
    fi

    # Sleep for a short interval (e.g., 1 second) before checking again
    sleep 2
done

# Exit with a status code indicating whether the file was found or not
if [ "\$timeout_expired" = true ]; then
    exit 1  # Timeout expired
else
    sleep 2  # Sleep delay to make sure file is not being written to
    exit 0  # File found
fi
EOF


#---- Functions --------------------------------------------------------------------

#---- UTF-8 Ascii cleanup

cleanup_utf8() {
    # Makes all input text UTF-8 ascii compliant

    # Usage:
        # Make $name UTF-8 ascii (func cleanup_utf8)
        # name=$(cleanup_utf8 "$name")

    # Set argument parameters
    local input="$1"
    # Set other variables
    local cleaned_input=$(echo "$input" | sed 's/ä/a/g; s/ö/o/g; s/ü/u/g; s/Ä/A/g; s/Ö/O/g; s/Ü/U/g; s/ß/ss/g')
    echo "$cleaned_input"
}


#---- Atomic increment/decrement value
    # This function is used to synchronize and control concurrent operations
    # in increment and decrement of a file (var) values.
    # Parameters:
    #           1.  Initialize a variable temp file
    #               global_queue_cnt="$(mktemp)"  
    #               declare -r global_multipart_queue_cnt
    #           2.  Set initial start value
    #               printf '%d' "0" > "$global_multipart_queue_cnt"
    # Example Usage:
    #           1.  Increment a value by +1
    #               increment "$global_queue_cnt" "1"  # Can be any whole integer
    #           2.  Decrement a value by -1
    #               decrement "$global_queue_cnt" "1"  # Can be any whole integer
    #           3.  Get a variable value
    #               get_value "$global_queue_cnt"  # Example $(get_value "$global_queue_cnt")
_atomically_modify() {
    local -r file_name="$1"                 # file name for descriptor 0
    local -r operation="$2"                 # the transformation to perform
    local -r mod_value="$3"                 # increment or decrement value
    flock 0                                 # atomic from here until return
    trap 'trap - return; flock -u 0' return
    local after
    after="$("$operation" "mod_value")"     # read + modify
    printf '%s' "$after" > "$file_name"     # write
    printf '%s' "$after"                    # fetch (for the caller to use)
}

_increment_operation() { printf '%d' "$(("$(< /dev/stdin)" + mod_value))"; }
_decrement_operation() { printf '%d' "$(("$(< /dev/stdin)" - mod_value))"; }
_get_operation() { printf '%d' "$(< /dev/stdin)"; }

increment() { _atomically_modify "$1" '_increment_operation' < "$1" "$2"; }
decrement() { _atomically_modify "$1" '_decrement_operation' < "$1" "$2"; }
get_value() { _atomically_modify "$1" '_get_operation' < "$1"; }


#---- Function to run SSH cmd on server
function run_remote_ssh_command() {
    # run_remote_ssh_command() - Establishes an SSH connection and executes a Bash
    # command on a remote server.
    #
    # This function establishes an SSH connection to a remote server and runs the
    # specified Bash command on that server. It captures the command's output and
    # checks for any errors during execution.
    #
    # Parameters:
    #   1. expanded_cmd - The Bash command to be executed on the remote server.
    #   2. error_handle_cmd - The Bash command to be executed in case of an error
    #      (e.g., logging, breaking, continuing).
    #
    # Global Variables (Must be set before calling this function):
    #   - "${ssh_cmd[@]}" - An array containing the SSH command and its options.
    #   - "$rsync_username" - The username for the SSH connection.
    #   - "$rsync_address" - The address (hostname or IP) of the remote server.
    #
    # Example Usage:
    #   run_remote_ssh_command "ls -l" "echo 'Error occurred on remote server'"
    #
    # Notes:
    # - This function captures both the output of the remote command and its exit
    #   code. If the remote command exits with a non-zero code, it is considered an
    #   error, and the error_handle_cmd will be executed, allowing you to handle the
    #   error as needed (e.g., logging, breaking the script).

    # Set argument parameters
    local expanded_cmd="$1" # bash cmds
    local error_handle_cmd="${2:-return 1}"  # on fail, run bash cmd (i.e return 0, return 1). "return 1" if it's not provided

    ssh_result=$(
    "${ssh_cmd[@]}" "$rsync_username@$rsync_address" "bash -c \"$expanded_cmd\""
    )

    local check_code="$?"
    if [ "$check_code" -ne 0 ]; then
        echo -e "#---- WARNING - SSH ERROR\nError Code ($check_code) : $(date)\nFunction : ${FUNCNAME[${#FUNCNAME[@]} - 1]}\nScript line number : $LINENO\n" >> $logfile  # Print error log
        eval "$error_handle_cmd"  # Bash command to be executed in case of an error
    else
        echo "$ssh_result"  # Print cmd stdin result
    fi
}


#---- Function to optimize rsync bandwidth.

function rsync_bwlimit_tuner() {
    # Adjusts bandwidth settings for efficient rsync speed based on video file counts.
    # Calculates precise bandwidth management when concurrent downloads are at max capacity.
    #
    # Parameters:
    #   None.
    #
    # Globals (Must be set before calling):
    #   - max_bw_limit
    #   - rsync_threads
    #   - throttle
    #   - termux_throttle
    #
    # Output:
    #   - bw_tune (Adjusted rsync bandwidth limit)
    #
    # Usage:
    #   rsync_bwlimit_tuner

    # Create a background task to interrupt rsync at specified times
    if [ "$throttle" = 1 ] || [ "$termux_throttle" = 1 ]; then
        # Get the current time
        local current_time=$(date +%H:%M)

        # Check if the current time is within the specified range
        if [[ "$current_time" > "$throttle_start_time" && "$current_time" < "$throttle_end_time" ]]; then
        # Set rsync $bw_limit - limit
        local bw_tune="$((max_bw_limit / rsync_threads))"
        else
        # Set rsync $bw_limit - no limit
        local bw_tune=0
        fi
    else
        # Set rsync $bw_limit - no limit
        local bw_tune=0
    fi

    # Function code
    echo "$bw_tune"
}


#---- Function to check and compare for existing files

function compare_local_file() {
    # Checks if a local file exists and compares it to its remote counterpart.
    #
    # Parameters:
    #   1. source_file - Path to the remote file to be processed.
    #   2. dst_dir - Base storage path of the local file.
    #
    # Usage:
    #   compare_local_file "$ource_file" "$dst_dir"
    #
    # Global Variables (Must be set before calling this function):
    #   - work_dir - Directory containing 'rsync_process_list.txt'.
    #
    # Output:
    #   - Exit code status:
    #                  0 - Local and remote files have the same size.
    #                  1 - Local file doesn't exist or its size differs from remote.

    # Set argument parameters
    local source_file="$1"
    local dst_dir="$2"
    # Set other variables
    local source_filename=$(basename "$source_file")

    # Check local $source_file versus remote values
    if [ -f "$dst_dir/$source_file" ]; then
        local_size=$(ls -l "$dst_dir/$source_file" | awk '{print $5}') # local size
        remote_size=$(awk -F ';' -v source_file="$source_file" '$1 == source_file {print $2}' "$work_dir/rsync_process_list.txt")  # remote size
        if [ "$local_size" = "$remote_size" ]; then
            return 0  # Set exit code
        else
            return 1  # Set exit code
        fi
    else
        return 1  # Set exit code
    fi    
}


#---- Functions for multipart files

# Function to make multipart files on a remote server
function make_multipart_files() {
    # Splits a specified file into smaller chunks (multipart) on a remote server using SSH.
    #
    # Parameters:
    #   1. source_file - The path to the file on the remote server to be processed.
    #   2. source_size - The size of the file on the remote server.
    #
    # Global Variables (Must be set before calling this function):
    #   - ssh_connect_retrycount - Number of SSH connection retry attempts.
    #   - ssh_connect_retrysleep - Sleep time (in seconds) between SSH connection retries.
    #   - ssh_cmd - An array containing the SSH command and its options.
    #   - multipart_chunk_size - The size (in megabytes) of each multipart chunk.
    #   - logfile - The path to the log file for recording any errors or warnings.
    #
    # Usage:
    #   make_multipart_files "$source_file" "$source_size"

    # Set argument parameters
    local source_file="$1"  # file to download
    local source_size="$2"  # source file size (bytes)
    # Set other variables
    local source='.'  # Set current working dir
    local source_filename=$(basename "$source_file")

    # Check for existing multipart files on remote server
    local escaped_source_filename=$(printf "%q" "$source_filename")
    local i 
    for ((i = 0; i <= ssh_connect_retrycount; i++)); do
        # Cmd - Get multipart filenames and sizes 
        eval "expanded_cmd=\"find '$source/tmp/kodirsync/$rsync_username' -regextype posix-extended -not -iregex '.*/($exclude_dir_filter_regex)/.*' -type f -regextype posix-extended -regex '.*(${escaped_source_filename}\\.z[0-9]+$|${escaped_source_filename}\\.zip$)' -printf '%P;%s\\n' 2> /dev/null\""

        # Run the SSH command and capture the result
        multipart_file_LIST=()  # Initialize array
        local multipart_size_bytes=0  # Initialize value
        local zip_found=false  # Initialize value
        while IFS=';' read -r file size; do
            multipart_file_LIST+=( "$(echo "$file" | sed 's/^\.\///')" )
            multipart_size_bytes=$(( multipart_size_bytes + size ))

            # Check if the line ends with ".zip"
            if [[ "$file" == *.zip ]]; then
                zip_found=true
            fi
        done < <( run_remote_ssh_command "$expanded_cmd" "return 1" )  # Func run remote ssh command
        if [ $? -ne 0 ]; then
            sleep $ssh_connect_retrysleep
            continue  # Continue to the next iteration of the loop
        fi

        # Check if no zip file was found
        if [ "$zip_found" = false ]; then
            unset multipart_file_LIST  # Unset array
            break  # Break out of your loop or function if no zip file is found
        fi

        # Validate multipart file cnt
        if [ "${#multipart_file_LIST[@]}" -ne 0 ]; then
            local calc_multipart_cnt=$(( source_size / ((multipart_chunk_size * 1024) * 1024) + 1 ))  # Calc zip multipart file count (+1 is the zip file)
            if [ "$calc_multipart_cnt" = "${#multipart_file_LIST[@]}" ]; then
                return 0  # Use existing multipart files
            else
                unset multipart_file_LIST  # Unset array
                break  # Proceed to create multipart files
            fi
        else
            break  # Proceed to create multipart files
        fi
    done


    # Create zip chunk files on server
    local i
    for ((i = 0; i <= ssh_connect_retrycount; i++)); do
        # Cmd - Create zip split file
        eval "expanded_cmd=\"mkdir -p '$source/tmp/kodirsync/$rsync_username' && rm -f '$source/tmp/kodirsync/$rsync_username/${source_filename}'.* && zip -0 -s ${multipart_chunk_size}m '$source/tmp/kodirsync/$rsync_username/${source_filename}.zip' '$source/$source_file'\""
        
        # Run the SSH command
        # If the SSH connection is lost, the remote command will continue executing
        # without interruption, thanks to nohup .
        "${ssh_cmd[@]}" "$rsync_username@$rsync_address" "nohup bash -c \"$expanded_cmd > /dev/null 2>&1\" &"

        # Sleep for a short period (you can adjust the duration)
        sleep 2

        # Process ssh exit codes
        if [ $? = 0 ]; then
            return 0
        elif [ $? -ne 0 ]; then
            sleep $ssh_connect_retrysleep
            continue  # Continue to the next iteration of the loop
        fi
    done

    # Print log msg
    echo -e "#---- WARNING - SERVER MULTIPART FILE\nError Code (1) : $(date)\nFunction : make_multipart_files\nRetry count : "$ssh_connect_retrycount"x failed attempts\n" >> $logfile
    return 1
}

# Function to generate a list of server multipart filenames ${split_file_LIST[@]}
function make_multipart_file_LIST() {
    # Generates a list of server multipart filenames from a specified source file on
    # a remote server using SSH. Waits for multipart file (n) to be available before
    # continuing with script (default is 2x $rsync_threads +1).
    #
    # Parameters:
    #   1. source_file - Path to the source file on the remote server.
    #   2. source_size - The size of the file on the remote server.
    #
    # Global Variables (Must be set before calling this function):
    #   - ssh_connect_retrycount - SSH connection retry attempts.
    #   - ssh_connect_retrysleep - Sleep time (seconds) between SSH retries.
    #   - ssh_cmd - SSH command and options array.
    #   - logfile - Path to the log file for error and warning recording.
    #
    # Usage:
    #   make_multipart_file_LIST "$source_file" "$source_size"
    #
    # Notes:
    # - Generates a list of multipart filenames from the specified source file on
    #   the remote server. Captures errors and logs them to the specified file.

    # Set argument parameters
    local source_file="$1"
    local source_size="$2"
    # Set other variables
    local source='.'
    local source_filename="$(basename "$source_file")"

    # Attempt to generate the list of server multipart filenames
    local calc_multipart_cnt=$(( source_size / ((multipart_chunk_size * 1024) * 1024)))  # Calc zip multipart file count
    multipart_file_LIST=()  # Initialize the array

    # Loop to generate the entries
    local i
    for ((i = 2; i <= $calc_multipart_cnt; i++)); do
        local suffix=$(printf "%02d" $i)  # Format the suffix to have leading zeros if needed
        multipart_file_LIST+=("tmp/kodirsync/$rsync_username/${source_filename}.z${suffix}")  # Add the entry to the array
    done

    # Add the last multipart entries
    multipart_file_LIST+=("tmp/kodirsync/$rsync_username/${source_filename}.z01")
    multipart_file_LIST+=("tmp/kodirsync/$rsync_username/${source_filename}.zip")

    # Calculate the value for start file 'n' suffix
    local n_suffix=$(( 2 * rsync_threads + 1 ))

    # Ensure 'n' suffix does not exceed calc_multipart_cnt
    if [ "$n_suffix" -gt "$calc_multipart_cnt" ]; then
        n_suffix="$calc_multipart_cnt"
    fi

    # Ensure 'n' suffix is a 2-digit number (padded with leading zeros if necessary)
    n_suffix=$(printf "%02d" "$n_suffix")

    # Construct the file_to_watch variable
    local file_to_watch="$(printf '%q' "${source_filename}.z$n_suffix")"

    # Replace the placeholder in the script with the actual value
    local modified_script="$(mktemp -p $work_dir)"  # Create a temporary copy of the script
    cp "$work_dir/watch_for_multipart_template.sh" "$modified_script"
    sed -i "s#\\\$file_to_watch#$file_to_watch#" "$modified_script"

    # Watch for the 'n' multipart to be created on server before proceeding
    local i 
    for ((i = 1; i <= ssh_connect_retrycount; i++)); do
        "${ssh_cmd[@]}" "$rsync_username@$rsync_address" "bash -s" < "$modified_script"

        # Process ssh exit codes
        if [ $? = 0 ]; then
            return 0
        elif [ $? -ne 0 ]; then
            sleep $ssh_connect_retrysleep
            continue  # Continue to the next iteration of the loop
        fi
    done

    # Print log msg
    echo -e "#---- WARNING - SERVER MULTIPART FILE LIST\nError Code (1) : $(date)\nFunction : make_multipart_file_LIST\nRetry count : $ssh_connect_retrycount x failed attempts\n" >> "$logfile"
    result=1
    return 1
}

# Function to cleanup/remove local multipart jobs for a source file
function multipart_cleanup_local() {
    # Cleanup a multipart jobs from the local machine.
    #
    # Parameters:
    #   1. source_file - Path to the source file on the remote server.
    #
    # Global Variables (Must be set before calling this function):
    #   - rsync_tmp - temporary dir
    #
    # Usage:
    #   multipart_cleanup_local "$source_file"

    # Set argument parameters
    local source_file="$1"
    # Set other variables
    local source_filename=$(basename "$source_file" | sed -E 's/\.(z[0-9]+|[0-9]+|zip[0-9]*)$//')  # Get only the filename

    # Remove multipart local files
    local escaped_source_filename=$(printf "%q" "$source_filename")
    local delete_pids=()  # Define as a local array
    local file
    while IFS= read -r file; do
      # Start a background process to delete each file
      (rm -f "$file" 2> /dev/null; sleep 0.5) &

      # Store the PID of the background process
      delete_pids+=($!)
    done < <(find "$rsync_tmp" -type f -name "${escaped_source_filename}*")

    # Wait for all delete processes to complete
    for pid in "${delete_pids[@]}"; do
      wait "$pid"
    done
}

# Function to delete server multipart files for a source file
function multipart_cleanup_server() {
    # Cleanup a multipart jobs from the server.
    #
    # Parameters:
    #   1. source_file - Path to the source file on the remote server.
    #   2. expanded_cmd - SSH command.
    #
    # Global Variables (Must be set before calling this function):
    #   - run_remote_ssh_command - A ssh command function.
    #
    # Usage:
    #   multipart_cleanup_server "$source_file"

    # Set argument parameters
    local source_file="$1"
    # Set other variables
    local source_filename=$(basename "$source_file" | sed -E 's/\.(z[0-9]+|[0-9]+|zip[0-9]*)$//')  # Get only the filename
    local source='.'  # Set current working dir

    # Cmd - generate list of server multipart filenames
    local escaped_source_filename=$(printf "%q" "$source_filename")
    eval "expanded_cmd=\"find '$source/tmp/kodirsync/$rsync_username' -type f -name '${escaped_source_filename}*' -exec rm {} \\;\""
    # Run SSH cmd
    run_remote_ssh_command "$expanded_cmd" "return 0" # Func run remote ssh command
}


#---- Function to start rsync processes

# Multipart rsync
function start_multipart_rsync() {
    # Set argument parameters
    local source_file="$1"  # file to downloaded
    local dst_dir="$2"  # final destination base dir
    local source_size="$3"  # source file size (bytes)
    # Set other variables
    local source_filename=$(basename "$source_file")
    local source_dir=$(dirname "$source_file")
    local max_retries="$rsync_retry_cnt"  # Maximum number of retries (adjust as needed)
    local source='.'  # Set current working dir

    # Step 1 - Create multipart files on remote server
    (
    make_multipart_files "$source_file" "$source_size"
    ) &

    # Step 2 - Get a list of multipart filenames ${multipart_file_LIST[@]}
    make_multipart_file_LIST "$source_file" "$source_size"
    if [ $? -ne 0 ]; then
        multipart_cleanup_server "$source_file"  # Delete server multipart files
        return 1
    fi

    # Step 3 - Update queue counters
    increment "$global_multipart_queue_cnt" "${#multipart_file_LIST[@]}"
    increment "$global_job_cnt" "${#multipart_file_LIST[@]}"  # Increment $global_job_cnt

    # Step 4 - Start downloads
    # Background throttle subshell to interrupt rsync at specified times
    local throttle_pid
    if [ "$throttle" = 1 ] || [ "$termux_throttle" = 1 ]; then
        (
            while true; do
                # Get the current time
                local current_time=$(date +%H:%M)

                # Check if the current time is within the specified range
                if [[ "$current_time" > "$throttle_start_time" && "$current_time" < "$throttle_end_time" ]]; then
                    # Use ps to find the PID of rsync/ssh commands with the specific source file
                    local escaped_rsync_match=$(printf "%q" "$source_filename")
                    local interrupt_rsync_pids=()
                    interrupt_rsync_pids+=( $(pgrep -f "^(rsync.*${escaped_rsync_match}.*|xargs.*rsync -e.*)") )

                    # Iterate through the array and send SIGTERM to each PID and its children
                    for pid in "${interrupt_rsync_pids[@]}"; do
                        if [ -n "$pid" ]; then
                            echo "Killing PID and its children: $pid"
                            kill -TERM "$pid" 2> /dev/null  # Send SIGTERM to the process
                            sleep 0.5  # Wait for a moment before sending SIGKILL if needed
                            kill -KILL "$pid" 2> /dev/null  # Send SIGKILL to the process
                        fi
                    done
                fi

                # Sleep for a while before checking again
                sleep 300  # Sleep for 5 minute (adjust as needed)
            done
        ) &
      
        # Capture the PID of the background task
        throttle_pid=$!
    fi


    # Step 5 - Start rsync loop
    local retry
    for ((retry = 1; retry <= max_retries; retry++)); do
        # Set rsync --bwlimit value
        bw_tune=$(rsync_bwlimit_tuner)

        # Run rsync
        printf '%s\n' "${multipart_file_LIST[@]}" | xargs -P $rsync_threads -I% rsync -e "$rsync_ssh_cmd" "${rsync_args[@]}" "--bwlimit=$bw_tune" "$rsync_username@$rsync_address:$source/%" "$dst_dir/rsync_tmp"

        # Process rsync exit codes
        if [ $? = 0 ]; then
            # On rsync success
            mkdir -p "$dst_dir/$source_dir"   # Wait until the directory is created
            while [ ! -d "$dst_dir/$source_dir" ]; do
                sleep 0.5  # Sleep before checking again
            done

            # Reassemble multipart files to $dst_dir
            7z e "$rsync_tmp/$source_filename.zip" -o"$dst_dir/$source_dir" -w"$rsync_tmp" -aoa

            # Check the exit status of 7z
            if [ $? = 0 ]; then
                # On 7z success
                multipart_cleanup_server "$source_file"  # Delete server multipart files
                multipart_cleanup_local "$source_file"  # Delete local multipart files

                # Log entry
                echo -e "#---- MULTIPART SUCCESS\nDate : $(date)\nSource filename : $source_filename\n" >> "$logfile"
            else
                # On 7z fail
                multipart_cleanup_server "$source_file"  # Delete server multipart files
                multipart_cleanup_local "$source_file"  # Delete local multipart files
                rm -f "$dst_dir/$source_file" 2> /dev/null || true  # Delete local part destination if exists

                # Log entry
                echo -e "#---- MULTIPART 7z FAIL\nDate : $(date)\nSource filename : $source_filename\n" >> "$logfile"
            fi

            # Kill the throttle PID
            if [ -n "$throttle_pid" ]; then
                echo "Killing PID and its children: $pid"
                kill -TERM "$throttle_pid" 2> /dev/null  # Send SIGTERM to the throttle process
                sleep 0.5  # Wait for a moment before sending SIGKILL if needed
                kill -KILL "$throttle_pid" 2> /dev/null  # Send SIGKILL to the throttle process
            fi

            # Update queue counters
            decrement "$global_multipart_queue_cnt" "${#multipart_file_LIST[@]}"
            decrement "$global_job_cnt" "${#multipart_file_LIST[@]}"  # Decrement $global_job_cnt

            return 0  # Set exit code
        else
            # On rsync fail
            if [ $retry -lt $max_retries ]; then
                # Fail possibility is a missing 'n'th multipart file. Cause is dl is
                # faster than remote manufacture of multipart chunks.
                # Next step will watch for the last 'n' multipart to be created on
                # the remote server before proceeding with rsync of the multipart files.

                # Log entry
                echo -e "#---- MULTIPART RSYNC FAIL\nDate : $(date)\nRetry count $retry of $max_retries for:\n$source_file\n" >> "$logfile"

                # Rsync sleep period
                sleep $rsync_retry_sleep

                # Find last 'n' multipart file on first retry
                if [ "$retry" = 1 ]; then
                    # Initialize variables to hold the highest count and corresponding entry
                    local highest_count=0
                    local file_to_watch=""

                    # Regular expression pattern to match entries ending with ".z[0-9]+"
                    local pattern="\.z([0-9]+)$"

                    # Iterate through the array
                    local entry
                    for entry in "${multipart_file_LIST[@]}"; do
                        if [[ "$entry" =~ $pattern ]]; then
                            count="${BASH_REMATCH[1]}"
                            if ((count > highest_count)); then
                                highest_count="$count"
                                file_to_watch="$(printf '%q' "$entry")"
                            fi
                        fi
                    done

                    # Replace the placeholder in the script with the actual value
                    local modified_script="$(mktemp -p $work_dir)"  # Create a temporary copy of the script
                    cp "$work_dir/watch_for_last_multipart_template.sh" "$modified_script"
                    sed -i "s#\\\$file_to_watch#$file_to_watch#" "$modified_script"

                    # Watch for the last multipart to be created on server before continuing
                    local j
                    for ((j = 1; j <= ssh_connect_retrycount; j++)); do
                        "${ssh_cmd[@]}" "$rsync_username@$rsync_address" "bash -s" < "$modified_script"

                        # Process ssh exit codes
                        if [ $? = 0 ]; then
                            break
                        elif [ $? -ne 0 ]; then
                            sleep $ssh_connect_retrysleep
                            continue  # Continue to the next iteration of the loop
                        fi
                    done
                fi
            else
                # Kill the throttle PID
                if [ -n "$throttle_pid" ]; then
                    echo "Killing PID and its children: $pid"
                    kill -TERM "$throttle_pid" 2> /dev/null  # Send SIGTERM to the throttle process
                    sleep 0.5  # Wait for a moment before sending SIGKILL if needed
                    kill -KILL "$throttle_pid" 2> /dev/null  # Send SIGKILL to the throttle process
                fi

                # Kill PID of rsync/ssh commands
                local escaped_rsync_match=$(printf "%q" "$source_filename")
                local rsync_pids=()
                rsync_pids+=( $(pgrep -f "^(rsync.*${escaped_rsync_match}.*|ssh.*${escaped_rsync_match}.*|xargs.*rsync -e.*)") )
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

                # Delete multipart files
                multipart_cleanup_server "$source_file"  # Delete server multipart files
                multipart_cleanup_local "$source_file"  # Delete local multipart files

                # Log entry
                echo -e "#---- WARNING - MULTIPART RSYNC FAIL\nDate : $(date)\nReached retry count limit $retry of $max_retries for:\n$source_file\nSkipping file.\n" >> "$logfile"

                # Update queue counters
                decrement "$global_multipart_queue_cnt" "${#multipart_file_LIST[@]}"
                decrement "$global_job_cnt" "${#multipart_file_LIST[@]}"  # Decrement $global_job_cnt

                return 1  # Set exit code
            fi
        fi
    done
}

# Single rsync with retry loop
function start_single_rsync() {
    # Set argument parameters
    local source_file="$1"  # file to downloaded
    local dst_dir="$2"  # final destination base dir
    # Set other variables
    local max_retries="$rsync_retry_cnt"  # Maximum number of retries (adjust as needed)
    local source='.'  # Set current working dir

    # Background throttle subshell to interrupt rsync at specified times
    local throttle_pid
    if [ "$throttle" = 1 ] || [ "$termux_throttle" = 1 ]; then
        (
            while true; do
                # Get the current time
                local current_time=$(date +%H:%M)

                # Check if the current time is within the specified range
                if [[ "$current_time" > "$throttle_start_time" && "$current_time" < "$throttle_end_time" ]]; then
                    # Use ps to find the PID of rsync/ssh commands with the specific source file
                    local escaped_rsync_match=$(printf "%q" "$source_filename")
                    local interrupt_rsync_pids=()
                    interrupt_rsync_pids+=( $(pgrep -f "^(rsync.*${escaped_rsync_match}.*|xargs.*rsync -e.*)") )

                    # Iterate through the array and send SIGTERM to each PID and its children
                    for pid in "${interrupt_rsync_pids[@]}"; do
                        if [ -n "$pid" ]; then
                            echo "Killing PID and its children: $pid"
                            kill -TERM "$pid" 2> /dev/null  # Send SIGTERM to the process
                            sleep 0.5  # Wait for a moment before sending SIGKILL if needed
                            kill -KILL "$pid" 2> /dev/null  # Send SIGKILL to the process
                        fi
                    done
                fi

                # Sleep for a while before checking again
                sleep 300  # Sleep for 5 minute (adjust as needed)
            done
        ) &
      
        # Capture the PID of the background task
        throttle_pid=$!
    fi

    # Start rsync loop
    local retry
    for ((retry = 0; retry <= max_retries; retry++)); do
        # Set rsync --bwlimit value
        local bw_tune=$(rsync_bwlimit_tuner)

        # Run Rsync
        rsync -e "$rsync_ssh_cmd" "${rsync_args[@]}" "--bwlimit=$bw_tune" "$rsync_username@$rsync_address:$source/$source_file" "$dst_dir"

        # Process rsync exit codes
        if [ $? = 0 ]; then
            # Kill the throttle PID
            if [ -n "$throttle_pid" ]; then
                echo "Killing throttle process with PID: $throttle_pid"
                kill -TERM "$throttle_pid" 2> /dev/null  # Send SIGTERM to the throttle process
                sleep 1  # Wait for a moment before sending SIGKILL if needed
                kill -KILL "$throttle_pid" 2> /dev/null  # Send SIGKILL to the throttle process
            fi

            # On rsync success
            return 0  # Set exit code
        else
            # On rsync fail
            # Use ps to find the PID of rsync/ssh commands with the specific source file
            local escaped_rsync_match=$(printf "%q" "$source_file")
            local rsync_pids=()
            rsync_pids+=( $(pgrep -f "^(rsync.*$escaped_rsync_match|ssh.*$escaped_rsync_match)") )
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
                # Log entry
                echo -e "#---- SINGLE RSYNC FAIL\nDate : $(date)\nRetry count $retry of $max_retries for:\n$source_file\n" >> "$logfile"

                sleep $rsync_retry_sleep  # Apply sleep period before retry
            else
                # Kill the throttle PID
                if [ -n "$throttle_pid" ]; then
                    echo "Killing PID and its children: $pid"
                    kill -TERM "$throttle_pid" 2> /dev/null  # Send SIGTERM to the throttle process
                    sleep 1  # Wait for a moment before sending SIGKILL if needed
                    kill -KILL "$throttle_pid" 2> /dev/null  # Send SIGKILL to the throttle process
                fi

                # Log entry
                echo -e "#---- WARNING - SINGLE RSYNC FAIL\nDate : $(date)\nReached retry count limit for: $source_file\n" >> "$logfile"

                # Update queue counters (if func run in subshell, not required, use signal)
                # global_job_cnt=$(( global_job_cnt - 1 ))

                return=1  # Set exit code
            fi
        fi
    done
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

#---- Set rsync dl arguments by disk type / OS type

if [ "$stor_fs" = exfat ] || [ "$ostype" = 'termux' ]; then
    # Configure for rsync filesystem compatibility -exFAT or Termux/Android OS
    rsync_args_single=(
    --verbose
    --progress
    --timeout=$rsync_timeout
    --human-readable
    --partial-dir=$dst_dir/rsync_tmp
    --delete
    --exclude '*.partial~'
    --log-file=$logfile
    --relative
    --no-owner
    --modify-window=1
    --size-only
    )

    rsync_args_multipart=(
    --verbose
    --progress
    --timeout=$rsync_timeout
    --human-readable
    --partial-dir=$dst_dir/rsync_tmp/multipart
    --exclude '*.partial~'
    --log-file=$logfile
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
    --timeout=$rsync_timeout
    --human-readable
    --partial-dir=$dst_dir/rsync_tmp
    --delete
    --exclude '*.partial~'
    --log-file=$logfile
    --relative
    --no-owner
    )

    rsync_args_multipart=(
    --archive
    --verbose
    --progress
    --timeout=$rsync_timeout
    --human-readable
    --partial-dir=$dst_dir/rsync_tmp/multipart
    --delete
    --exclude '*.partial~'
    --log-file=$logfile
    --no-owner
    )
fi


#---- Set arguments by connection type
if [[ "$rsync_connection_type" =~ ^(1|2)$ ]]; then
    # Remote connections only (full bandwidth)
    rsync_threads="$max_rsync_threads_remote"  # Set rsync threads (parallel rsync)

    # Example of "${other_args[@]}" required by all rsync dl connections:
    # Tune overrides in this section if required.
    #   other_args=(
    #   "$rsync_retry_sleep"  # Sleep time between retries
    #   "$rsync_retry_cnt"    # Maximum number of retries
    #   "$logfile"            # Path to the log file
    #   "$source"             # Server source base dir on remote (i.e '.')
    #   "$dst_dir"            # Client destination base dir
    #   "$work_dir"           # Working dir for rsync tasks (this is a temp dir)
    #   "$rsync_threads"      # Max rsync threads (parallel rsync)
    #   )
    other_args=(
    "rsync_retry_sleep='$rsync_retry_sleep'"
    "rsync_retry_cnt='$rsync_retry_cnt'"
    "logfile='$logfile'"
    "source='$source'"
    "dst_dir='$dst_dir'"
    "work_dir='$work_dir'"
    "rsync_threads='$rsync_threads'"
    )
elif [ "$rsync_connection_type" = 3 ]; then
    # LAN connections only (full bandwidth)
    rsync_threads="$max_rsync_threads_lan"  # Set rsync threads (parallel rsync)

    # Example of "${other_args[@]}" required by all rsync dl connections:
    # Tune overrides in this section if required.
    #   other_args=(
    #   "$rsync_retry_sleep"  # Sleep time between retries
    #   "$rsync_retry_cnt"    # Maximum number of retries
    #   "$logfile"            # Path to the log file
    #   "$source"             # Server source base dir on remote (i.e '.')
    #   "$dst_dir"            # Client destination base dir
    #   "$work_dir"           # Working dir for rsync tasks (this is a temp dir)
    #   "$rsync_threads"      # Max rsync threads (parallel rsync)
    #   )
    other_args=(
    "rsync_retry_sleep='$rsync_retry_sleep'"
    "rsync_retry_cnt='$rsync_retry_cnt'"
    "logfile='$logfile'"
    "source='$source'"
    "dst_dir='$dst_dir'"
    "work_dir='$work_dir'"
    "rsync_threads='$rsync_threads'"
    )
fi

# Loop through the elements of the other_args array and eval each element
for arg in "${other_args[@]}"; do
    eval "$arg"
done


#---- Start dl rsync processes

# Check 'rsync_process_list.txt'
if [ -f "$work_dir/rsync_process_list.txt" ] && [[ $(cat "$work_dir/rsync_process_list.txt" | wc -l) -ge 1 ]]; then
    # Read the list of items to sync line by line
    IFS=$'\n' source_files=($(grep -E -v '^\s*$|^\s*#' "$work_dir/rsync_process_list.txt"))
else
    # Log entry & exit
    echo -e "#---- WARNING - RSYNC FAIL\nDate : $(date +"%F %T")\nInput file 'rsync_process_list.txt' empty.\n" >> "$logfile"
    trap cleanup EXIT  # Exit script
fi

# Initialize count files - $remaining_video_count
remaining_video_count="$(mktemp -p $work_dir)"  
declare -r remaining_video_count
printf '%d' "$(printf '%s\n' "${source_files[@]}" | cut -d';' -f1 | grep -E "\.($video_format_filter_regex)$" | wc -l)" > "$remaining_video_count"

# Initialize count files - $global_multipart_queue_cnt
global_multipart_queue_cnt="$(mktemp -p $work_dir)"  
declare -r global_multipart_queue_cnt
printf '%d' "0" > "$global_multipart_queue_cnt"

# Initialize count files - $global_job_cnt
global_job_cnt="$(mktemp -p $work_dir)"  
declare -r global_job_cnt
printf '%d' "0" > "$global_job_cnt"

# Loop through the source files and start rsync processes with limited concurrency
for ((i = 0; i < ${#source_files[@]}; i++)); do
    while true; do
        if [ "$(get_value $global_job_cnt)" -ge "$rsync_threads" ]; then
            sleep 2  # Recurring wait
        else
            break
        fi
    done

    # Set argument parameters
    source_file="$(echo "${source_files[i]}" | cut -d';' -f1)"
    source_filename="$(basename "$source_file")"
    source_size="$(echo "${source_files[i]}" | cut -d';' -f2)"

    # Decrement remaining video count upon processing each file
    if [[ "$source_filename" =~ $video_format_filter_regex ]]; then
        decrement "$remaining_video_count" "1"
    fi

    # Check for existing copies of destination files
    compare_local_file "$source_file" "$dst_dir"
    if [ $? = 0 ]; then
        continue  # If the file already exists locally, skip it
    fi

    # Enable multipart option (video files only)
    # The code calculates available free space and checks conditions for enabling
    # multipart transfer for video files. Multipart is applied based on file size,
    # remaining video count, and connection type.
    free_space_k=$(df -k -P "$rsync_tmp" | tail -n 1 | awk '{print $4}')  # Calculate the available free space in bytes
    free_space_bytes=$((free_space_k * 1024))
    # Check conditions for enabling multipart transfer
    if [[ "$source_filename" =~ $video_format_filter_regex ]] && \
    [[ "$((source_size * 2))" -lt "$free_space_bytes" ]] && \
    [[ "$(get_value $remaining_video_count)" -le "$((multipart_dl_begin * rsync_threads))" ]] && \
    [ "$multipart_threads" = 1 ] && \
    [[ "$rsync_connection_type" =~ (1|2) ]]; then
        multipart_option=1  # Multipart enabled
    else
        multipart_option=0  # Single enabled
    fi

    # Run rsync
    if [ "$multipart_option" = 1 ]; then
        #---- Multipart file processing

        # Run func 'start_multipart_rsync'
        rsync_args=("${rsync_args_multipart[@]}")
        start_multipart_rsync "$source_file" "$dst_dir" "$source_size"
    elif [ "$multipart_option" = 0 ]; then
        #---- Single file processing

        # Increment $global_job_cnt
        increment "$global_job_cnt" "1"

        # Run func 'start_single_rsync' in the background
        (
            rsync_args=("${rsync_args_single[@]}")
            start_single_rsync "$source_file" "$dst_dir"

            # Get the PID of the current subshell
            subshell_pid=$$
         
            # Decrement $global_job_cnt
            decrement "$global_job_cnt" "1"
            wait
        ) &
    fi
done

# Wait until global_job_cnt reaches 0
while true; do
    if [ "$(get_value $global_job_cnt)" -ne 0 ]; then
        sleep 2  # Recurring wait
    else
        break
    fi
done


#---- Cleanup remote and local multipart and rsync_tmp temprary dl files
# Only multipart files are removed. 'start_single_rsync' partial files are retained.

# Remove remote multipart files from remote server user dir
eval "expanded_cmd=\"find './tmp/kodirsync/$rsync_username' -regextype posix-extended -not -iregex '.*/($exclude_dir_filter_regex)/.*' -type f -exec rm {} \\;\""
# Run SSH cmd
run_remote_ssh_command "$expanded_cmd" "return 0" # Func run remote ssh command

# Remove local multipart files from 'rsync_tmp' dir
while IFS= read -r file; do
    (rm -f "$file" 2> /dev/null; sleep 0.5) &  # Start a background process to delete each file
done < <(find "$rsync_tmp" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex)(/.*)?|.*/kodirsync_app(/.*)?" -type f -regextype posix-extended -not -iregex ".*/($exclude_file_filter_regex)$" -type f -regextype posix-extended -iregex ".*\.(z[0-9]+|[0-9]+|zip[0-9]*)\..+$")
#-----------------------------------------------------------------------------------