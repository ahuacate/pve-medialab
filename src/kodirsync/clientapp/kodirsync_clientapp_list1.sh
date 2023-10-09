#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     Kodirsync_list1.sh
# Description:  Source script for creating Kodirsync regex filters and lists
# Usage:        Requires kodirsync_clientapp_script.sh
# Usage:        All variables/args set in:
#                   'kodirsync_clientapp_user.cfg'
#                   'kodirsync_clientapp_default.cfg'
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Function ---------------------------------------------------------------------

# Function regex simple one-liner
function regex_simple_list() {
  # Creates a simple one-liner regex from a file list
  # "$2" is output name
  # Simple list example: "avi|mpeg|mkv"
  local input="$1"
  local result
  local tmp_array=()

  # Check if the input file is empty
  if [ ! -s "$input" ]
  then
    # Add a dummy entry line
    tmp_array+=("dummy_entry")
  fi

  # Create array list
  while IFS= read -r line
  do
    # Trim leading/trailing whitespace
    line=${line##+([[:space:]])}
    line=${line%%+([[:space:]])}

    # Check for non-conforming lines
    [[ "$line" =~ ^\#.*$|^$|^\ .*$|^sample.*$|^[bBwW]$ ]] && continue

    # Create array list
    if [[ "$line" =~ ^\\.*$ ]]
    then
      # Add if $line starts with "\" escape (to avoid double escape)"
      tmp_array+=( "$line" )
    else
      # Escape $line name
      tmp_array+=( "$(printf '%q' "$line")" )
    fi
  done < <( cat "$input" )

  # Iterate over the array elements
  result=""
  for element in "${tmp_array[@]}"; do
    # Concatenate the element with the pipe symbol
    result+="${element}|"
  done

  # Remove the trailing pipe symbol
  result="${result%|}"

  # Assign the result to the variable passed as the second argument
  declare -g "$2=$result"
}

# Function regex simple sed one-liner
function regex_simple_sed_list() {
  # Creates a simple sed one-liner regex from a file list.
  # For use with cmd sed
  # "$2" is output name
  # Simple list example: "avi|mpeg|mkv"
  local input="$1"
  local result
  local tmp_array=()

  # Check if the input file is empty
  if [ ! -s "$input" ]
  then
    # Add a dummy entry line
    tmp_array+=("dummy_entry")
  fi

  while IFS= read -r line
  do
    # Trim leading/trailing whitespace
    line=${line##+([[:space:]])}
    line=${line%%+([[:space:]])}

    # Check for non-conforming lines
    [[ "$line" =~ ^\#.*$|^$|^\ .*$|^sample.*$|^[bBwW]$ ]] && continue

    # Create array list
    if [[ "$line" =~ ^\\.*$ ]]
    then
      # Add if $line starts with "\" escape (to avoid double escape)"
      tmp_array+=( "$line" )
    else
      # Escape $line name
      tmp_array+=( "$(printf '%q' "$line")" )
    fi
  done < <( cat "$input" )

  # Iterate over the array elements
  result=""
  for element in "${tmp_array[@]}"; do
    # Concatenate the element with the pipe symbol
    result+="${element}\|"
  done

  # Remove the trailing pipe symbol
  result="${result%\\|}"

  # Assign the result to the variable passed as the second argument
  declare -g "$2=$result"
}

# Function list array
function simple_array_list() {
  local input="$1"
  local tmp_array=()

  # Check if the input file is empty
  if [ ! -s "$input" ]
  then
    # Add a dummy entry line
    tmp_array+=("dummy_entry")
  fi

  while IFS= read -r line
  do
    # Trim leading/trailing whitespace
    line=${line##+([[:space:]])}
    line=${line%%+([[:space:]])}

    # Check for non-conforming lines
    [[ "$line" =~ ^\#.*$|^$|^\ .*$|^sample.*$|^[bBwW]$ ]] && continue

    # Create array list
    if [[ "$line" =~ ^\\.*$ ]]; then
      # Add if $line starts with "\" escape (to avoid double escape)"
      tmp_array+=("$line")
    else
      # Escape $line name
      tmp_array+=("$(printf '%q' "$line")")
    fi
  done < <(cat "$input")

  # Assign the result to the variable passed as the second argument
  eval "$2=()"
  for element in "${tmp_array[@]}"; do
    eval "$2+=('$element')"
  done
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- Create list arrays

# Video file format (.ext) list array
# "${video_format_filter_LIST[@]}"
simple_array_list "$DIR/video_format_filter.txt" "video_format_filter_LIST"

# Other file format (.ext) list array
# "${other_format_filter_LIST[@]}"
simple_array_list "$DIR/other_format_filter.txt" "other_format_filter_LIST"

# All file format (.ext) list array
# "${all_format_filter_LIST[@]}"
# Join the arrays
all_format_filter_LIST=( "${video_format_filter_LIST[@]}" "${other_format_filter_LIST[@]}" )

# Exclude file list array
# "${exclude_file_filter[@]}"
simple_array_list "$DIR/exclude_file_filter.txt" "exclude_file_filter_LIST"

# Exclude dir list array
# "${exclude_dir_filter[@]}"
simple_array_list "$DIR/exclude_dir_filter.txt" "exclude_dir_filter_LIST"

# Exclude OS dir list array
# "${exclude_os_dir_filter[@]}"
simple_array_list "$DIR/exclude_os_dir_filter.txt" "exclude_os_dir_filter_LIST"


#---- Create simple regex lists (non-sed)

# Create format filter from text file - video
# (i.e webm|mkv|mk3d|mka|mks|flv|vob)
regex_simple_list "$DIR/video_format_filter.txt" "video_format_filter_regex"

# Create format filter from text file - subtitle
# (i.e srt|ssa|vtt)
regex_simple_list "$DIR/subtitle_format_filter.txt" "subtitle_format_filter_regex"

# Create format filter from text file - image
# (i.e bmp|tif|jpeg)
regex_simple_list "$DIR/image_format_filter.txt" "image_format_filter_regex"

# Create format filter from text file - audio
# (i.e wav|mp3)
regex_simple_list "$DIR/audio_format_filter.txt" "audio_format_filter_regex"

# Create format filter from text file - audiobook
# (i.e m4b|mka)
regex_simple_list "$DIR/audiobook_format_filter.txt" "audiobook_format_filter_regex"

# Create filter from text file - other
# (i.e log)
regex_simple_list "$DIR/other_format_filter.txt" "other_format_filter_regex"

# Create exclude filter from text file - filetype
# (i.e *.partial~|#recycle|.foo_protect)
regex_simple_list "$DIR/exclude_file_filter.txt" "exclude_file_filter_regex"

# Create exclude filter from text file - dir
# (i.e @eaDir|tmp)
regex_simple_list "$DIR/exclude_dir_filter.txt" "exclude_dir_filter_regex"

# Create exclude filter from text file - OS dir
# (i.e lost+found|images|\#recycle)
regex_simple_list "$DIR/exclude_os_dir_filter.txt" "exclude_os_dir_filter_regex"

# Create dir filter - Kodirsync dirs
# (i.e kodirsync_storage)
kodirsync_dir_filter_regex='kodirsync|kodirsync_storage|rsync_tmp'

# Create exclude filter - HDR
# (i.e hdr|HDR)
exclude_hdr_filter_regex='hdr|hdr10'

# Rsync part file extension (extension of rsync temporary file)
rsync_part_filter_regex='part|PART'

# Video subfolder shares
video_subfolder_dir_filter_regex='video(/|/stream/)?(documentary|movies|musicvideo|pron|series)?'


#---- Create simple regex lists (for SED only)

# Create format filter from text file - iso languages
# (i.e de\|eng\|it)
regex_simple_sed_list "$DIR/iso_language_codes.txt" "iso_lang_codes_sed_regex"
#-----------------------------------------------------------------------------------