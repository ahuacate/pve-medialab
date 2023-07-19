#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     prune.sh
# Description:  Script to prune files and dirs after a period of time.
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# All variables are set in parent script 'recipe.sh'
# Variables file: 'variables_default.yml'

#---- Static Variables -------------------------------------------------------------

# Filter excludes
# filter_file_exclude_regex=(-name "*.foo_protect" -o -regex ".*\.part" -o -regex ".*\.tmp")
# filter_dir_exclude_regex=(-path "*/@")
filter_file_exclude=( ".foo_protect" "*\.part" "*\.tmp" )
filter_dir_exclude=( "@eaDir" )

# Minimum dir size (Mb)
dir_min=10

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Function to delete a file and its associated files
function delete_files() {
  file="$1"
  # Delete file
  rm -f "$file" 2> /dev/null
  # Delete associated files by removing the file extension and adding a wildcard
  assoc_files=$(find "$(dirname "$file")" -maxdepth 1 -name "$(basename "$file" "${file##*.}")*" -type f ! -path "$file")
  for assoc_file in $assoc_files; do
    rm -f "$assoc_file" 2> /dev/null
  done
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create in path list
input_path_LIST=()
# Documentary series check
if [[ "$prune_age_documentary_series" -gt 0 ]]
then
  input_path_LIST+=( "$storage_video/$path_documentary_series_dst;$prune_age_documentary_series" )
fi
# Documentary movies check
if [[ "$prune_age_documentary_movies" -gt 0 ]]
then
  input_path_LIST+=( "$storage_video/$path_documentary_movies_dst;$prune_age_documentary_movies" )
fi
# Unsorted check
if [[ "$prune_age_unsorted" -gt 0 ]]
then
  input_path_LIST+=( "$storage_downloads/$path_unsorted;$prune_age_unsorted" )
fi


#---- Find and remove old media files and empty dirs

# Create exclude list - folders
findargs=()
for i in "${filter_dir_exclude[@]}"
do
  findargs+=('-not' '-path' "*/$i/*")
done
# Create exclude list - files
for i in "${filter_file_exclude[@]}"
do
  findargs+=('!' '-iname' "$i")
done

# Remove old files
while IFS=';' read -r path prune_age
do
  # Remove old files
  while read -r var1
  do
    # Run delete function
    delete_files "$var1"
  done < <( find "$path" -mindepth 1 -depth "${findargs[@]}" -type f -mtime +"$prune_age" 2> /dev/null )

  # Remove small folders (folders without video media)
  while read -r dir_size dir_path
  do
    [[ "$dir_size" -lt "$dir_min" ]] && rm -rf "$dir_path" 2> /dev/null
  done < <( find "$path" -mindepth 1 -depth "${findargs[@]}" -type d 2> /dev/null -exec du -ks {} \; )
done < <( printf '%s\n' "${input_path_LIST[@]}" )
#-----------------------------------------------------------------------------------