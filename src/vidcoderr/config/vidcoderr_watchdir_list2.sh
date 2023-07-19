#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchdir_list2.sh
# Description:  Source script for creating Vidcoderr lists (i.e whitelists etc)
# Usage:  Requires vidcoderr_watchdir.sh
# Usage:  All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Copy to 'transcode/vidcoderr' dir
if [ ! -f "/mnt/transcode/vidcoderr/vidcoderr_control_list.txt" ]
then
  sudo -u $app_uid cp "/usr/local/bin/vidcoderr/vidcoderr_control_list.tmpl" "/mnt/transcode/vidcoderr/vidcoderr_control_list.txt"
fi


#---- Create list array - existing video stream files

# Initialize list arrays
existing_file_LIST=()

# Loop through all enabled $dst_path
while IFS=',' read -r label media_type src_path dst_path encode_str
do
  # Adding video files in $dst_path
  while IFS= read -r file
  do
    # Get file path
    file_path="$(dirname "$file")"
    # Get the subfolder/mid path if it exists
    if [[ "$file_path" == "$dst_path" ]]; then
      dst_mid_path='.'
    else
      dst_mid_path="${file_path#$dst_path/}"
    fi
    # Get the filename
    filename=$(basename "$file")
    existing_file_LIST+=( "$dst_path/$dst_mid_path/$filename" )
  done < <( find "$dst_path" -type f \
  -regextype posix-extended -iregex ".*\.($video_format_filter_regex)" \
  -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex).*" \
  -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" 2> /dev/null )
done < <( printf '%s\n' "${input_dir_LIST[@]}" )


#---- Create list arrays - whitelist and blacklist

# Initialize whitelist and blacklist
white_LIST=()
black_LIST=()

while IFS=';' read -r condition src_category name
do
  # Check for non-conforming lines
  [[ "$condition" =~ ^\#.*$ ]] && continue

  # Check for alias name wildcard '*'
  if [[ "$name" =~ ^.*(\*|\.\*)$ ]]
  then
    name="$(printf '%q' "$(echo "$name" | sed 's/\(\.\)\?\*$//')").*"
  else
    name="$(printf "%q" "$name")/.*"
  fi

  # Modify '$src_category' to include '(stream)?'
  if ! [[ $(echo "$src_category" | grep -e ^.*/stream/.*$) ]]
  then
    src_category="$(printf '%q' "$src_category" | sed 's/video\//video(\/stream)?\//g')"
  fi

  # White list array
  if [[ "$condition" =~ ^[wW]$ ]]
  then
    # Check if pattern exists
    found=false
    for pattern in "${white_LIST[@]}"
    do
      if [[ "$pattern" == ".*/$src_category/.*/$name" ]]; then
        found=true
        break
      fi
    done
    if [ "$found" = false ]
    then
      white_LIST+=( ".*/$src_category/.*/$name" )
    fi
  fi

  # Black list array
  if [[ "$condition" =~ ^[bB]$ ]]
  then
    # Check if pattern exists
    found=false
    for pattern in "${black_LIST[@]}"
    do
      if [[ "$pattern" == ".*/$src_category/.*/$name" ]]; then
        found=true
        break
      fi
    done
    if [ "$found" = false ]
    then
      black_LIST+=( ".*/$src_category/.*/$name" )
    fi
  fi
done < <( cat "/mnt/transcode/vidcoderr/vidcoderr_control_list.txt" )
#-----------------------------------------------------------------------------------