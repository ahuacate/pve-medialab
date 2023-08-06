#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_node_prune.sh
# Description:  Default Kodirsync node prune script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Step 1: Sort the list of files in the local work_dir/rsync_storage_list.txt
sort "$work_dir/rsync_storage_list.txt" > "$work_dir/sorted_list.txt"

# Step 2: Copy the sorted_list.txt to the remote server (destination)
scp -i "$HOME/.ssh/$node_ssh_private_key_name" -P "$node_ssh_port" "$work_dir/sorted_list.txt" "$node_user@$lan_address:/tmp/sorted_list.txt"
# Add a delay of 1 second to ensure the file is fully written
sleep 1

# Step 3: Run ssh command to remove extraneous files on the destination not in the list
ssh -i "$HOME/.ssh/$node_ssh_private_key_name" -p "$node_ssh_port" "$node_user@$lan_address" \
"cd $node_dst_dir && find . -type f ! -name '.kodirsync_storage' -not -path '*/rsync_tmp/*' -exec sh -c 'echo \"\${1#./}\"' sh {} \; 2> /dev/null | sort > /tmp/dest_files.txt \
&& while read -r file; do
  if ! grep -qxF \"\$file\" /tmp/sorted_list.txt; then
    echo \"Deleting file: $node_dst_dir/\$file\"
    rm -rf \"$node_dst_dir/\$file\"
    wait
  fi
done < /tmp/dest_files.txt"


# Step 4: Run ssh command to remove extraneous empty dirs on the destination not in the list
while true; do
  # Find empty directories on the remote server and save the list to a local file
  ssh -i "$HOME/.ssh/$node_ssh_private_key_name" -p "$node_ssh_port" "$node_user@$lan_address" \
    "cd $node_dst_dir && find . -not -path '\\(*/rsync_tmp/*|*/rsync_tmp\\)' -type d -empty -exec sh -c 'echo \"\${1#./}\"' sh {} \; 2> /dev/null | sort" > $work_dir/empty_dirs.txt
  # Add a delay of 1 second to ensure the file is fully written
  sleep 1

  # Check if there are any empty directories left
  if [ -s "$work_dir/empty_dirs.txt" ]; then
    # Loop through the list of empty directories and remove them if not present in sorted_list.txt
    while read -r dir; do
      if ! grep -qxF "$dir" $work_dir/sorted_list.txt; then
        echo "Deleting empty dir: $node_dst_dir/$dir"
        ssh -i "$HOME/.ssh/$node_ssh_private_key_name" -p "$node_ssh_port" "$node_user@$lan_address" "rm -rf \"$node_dst_dir/$dir\""
      fi
    done < $work_dir/empty_dirs.txt
  else
    # No more empty directories, exit the loop
    break
  fi
done
#-----------------------------------------------------------------------------------