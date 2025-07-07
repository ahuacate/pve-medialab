#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_prune.sh
# Description:  Source script for pruning Kodirsync $dst_dir media & partial rsync files
# Usage:        All variables/args set in 'kodirsync_clientapp_default.cfg'
#               Requires parent file 'kodirsync_clientapp_script.sh'
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Remove all orphaned, erroneous and unknown mystery files

# Remove mystery files
while IFS= read file; do
    rm -f "$file" 2> /dev/null
    sleep 0.5
done < <(find "$dst_dir" -regextype posix-extended -not -iregex ".*/(rsync_tmp)(/.*)?$|.*/($exclude_dir_filter_regex)(/.*)?" -type f -regextype posix-extended -not -iregex ".*\.($rsync_part_filter_regex)$|.*\.($video_format_filter_regex|$subtitle_format_filter_regex|$image_format_filter_regex|$audio_format_filter_regex|$audiobook_format_filter_regex)$" -type f)


#---- Remove depreciated media files from destination storage

# Remove depreciated $dst_dir files that are not in keep_local_LIST
for item in "${all_local_LIST[@]}"; do
    # Use IFS to set the delimiter to semicolon
    IFS=';' read -r local_file _ <<< "$item"

    # Check if the item should be deleted
    should_delete=true
    for keep_item in "${keep_local_LIST[@]}"; do
        IFS=';' read -r keep_file _ <<< "$keep_item"
        if [[ "$local_file" =~ .*\.($subtitle_format_filter_regex)$ ]]; then
            if [[ "$local_file" =~ ^"${keep_file%.*}".*\.($subtitle_format_filter_regex)$ ]]; then
                should_delete=false  # Subtitle Match found so keep
                break
            fi
        else
            if [[ "$local_file" == "$keep_file" ]]; then
                should_delete=false  # Match found so keep
                break
            fi
        fi
    done

    # Delete the entry if it should be deleted
    if "$should_delete"; then
      rm -f "$dst_dir/$local_file"  # Remove depreciated file
    fi
done

# Find all empty directories excluding $rsync_tmp and "${remote_basedir_LIST[@]}"
exclude_pattern_LIST=()  # Initialize array
exclude_pattern_LIST+=(-not -path "$dst_dir/rsync_tmp")  # Exclude dir "$dst_dir/rsync_tmp"
for dir in "${remote_basedir_LIST[@]}"; do
  exclude_pattern_LIST+=(-not -path "$dst_dir/$dir")  # Add exclude dirs
done
find "$dst_dir" -mindepth 1 -type d -not -path "$dst_dir/rsync_tmp*" -exec bash -c 'shopt -s nullglob; files=("$1"/*); shopt -u nullglob; (( ${#files[@]} == 0 ))' _ {} \; -delete


#---- Remove old and depreciated $rsync_tmp files

# Create a list of valid $rsync_tmp files
partial_local_LIST=()  # Initialize array
while IFS= read file; do
    partial_local_LIST+=("$file")
done < <(find "$dst_dir/rsync_tmp" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex)(/.*)?" -type f -regextype posix-extended -iregex ".*\.($rsync_part_filter_regex)$|.*\.($video_format_filter_regex|$subtitle_format_filter_regex|$image_format_filter_regex|$audio_format_filter_regex|$audiobook_format_filter_regex)(\.(z[0-9]+|[0-9]+|zip[0-9]*))?$")

# Check for depreciated files
for partial_item in "${partial_local_LIST[@]}"; do
    regex_pattern="\.($rsync_part_filter_regex|z[0-9]+|[0-9]+|zip[0-9]*)$"  # Define the regex pattern using the variable
    partial_filename="$(basename "$partial_item")"  # Use the 'basename' command to remove the path
    partial_filename="$(echo "$partial_filename" | sed -E "s/$regex_pattern//")"  # Remove the matching extension

    # Check if the item should be deleted
    should_delete=true
    for keep_item in "${dl_remote_LIST[@]}"; do
        IFS=';' read -r keep_file _ <<< "$keep_item"
        keep_file="$(basename "$keep_file")"  # Use the 'basename' command to remove the path
        if [[ "$partial_filename" == "$keep_file" ]]; then
            should_delete=false  # Match found so keep
            break
        fi
    done

    # Delete the entry if it should be deleted
    if "$should_delete"; then
        rm -f "$partial_item"  # Remove rsync partial file
    fi
done
#-----------------------------------------------------------------------------------