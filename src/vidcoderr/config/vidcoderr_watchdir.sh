#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchdir.sh
# Description:  Inotifywait watch dir script for Vidcoderr
# Usage:  All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

#---- Inotify vars
# Inotifywait events
events='-e close_write,moved_to'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Trim log file
function trim_log() {
  max_size=5000000 # 5 MB in bytes

  # Check if file exists
  if [ ! -f "$log" ]
  then
    touch $log
  fi
  # Check if file size is already smaller than max_size
  if [ $(wc -c <"$log") -le $max_size ]
  then
    echo "Log file is already smaller than 5 MB."
    return 0
  fi
  # Trim the file to max_size
  truncate -s $max_size "$log"
  # Trim the file to the last complete line
  truncate -s $(tail -n 1 "$log" | wc -c) $log
}

# Make error log report
function make_error_log() {
    # Set a optional fail reason msg
    # Example: make_error_log "Input file name is blacklisted: $filename"
    local error_message="$1"
    local file="$src_path/$filename"
    local timestamp=$(date +"%Y-%m-%d %T")

    # Create the error message
    local message=$(cat <<-EOF
$(printf -- '-%.0s' {1..5}) ERROR $(printf -- '-%.0s' {1..68})
Input file: $file
Reason/Issue: $error_message
$(printf -- '-%.0s' {1..84})
EOF
)

    # Append the error message to the log file
    echo -e "$message" >> "$log"
}

# Make normal log report
function make_log() {
    # Set a optional fail reason msg
    # Example: make_log "File sent to encoder."
    local std_message="$1"
    local file="$src_path/$filename"
    local timestamp=$(date +"%Y-%m-%d %T")

    # Create the error message
    local message=$(cat <<-EOF
$(printf -- '-%.0s' {1..84})
Input file: $file
Message: $std_message
$(printf -- '-%.0s' {1..84})
EOF
)

    # Append the error message to the log file
    echo -e "$message" >> "$log"
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Read vidcoderr.ini file
source /usr/local/bin/vidcoderr/vidcoderr.ini

# Check for transcode dir
mkdir -p "$TRANSCODE_DIR"
if ! [ -d "$TRANSCODE_DIR" ]
then
  echo "Fail: ${TRANSCODE_DIR}Usage: $0 cmd ..."
  exit -1;
fi

# Check for 'log' file
log="$APP_HOME/vidcoderr_watchdir.log"
if [ ! -f "$log" ]
then
  touch $log
fi

# Check encoder 'queue' file
if [ ! -f "$QUEUE_FILE" ]
then
  touch $QUEUE_FILE
fi

# Set rsync cutoff period (days)all_format_filter_LIST
rsync_cutoff_start_epoch=$(date  +'%s' --date="$RSYNC_CUTOFF_START days ago")
rsync_cutoff_end_epoch=$(date  +'%s' --date="$RSYNC_CUTOFF_END days ago")


#---- Run list scripts
source $APP_HOME/vidcoderr_watchdir_list1.sh
source $APP_HOME/vidcoderr_watchdir_list2.sh


#---- Standard watch service
# Pre-process input files and make 'input_file_LIST' entry

# Create an empty array list to store the file entries
input_file_LIST=()

while IFS=',' read -r label media_type src_path dst_path encode_str
do
  # Loop through the files in $src_dir
  while IFS= read -r file
  do
    # Get the file size in kb, epoch date, date time, file path, mid path, encode string and file name etc
    file_size="$(stat -c %s "$file")"
    epochtime="$(stat -c %Y "$file")"
    date_time="$(date -d "@$epochtime" +'%Y/%m/%d %H:%M:%S')"
    file_path="$(dirname "$file")"
    if [[ "$file_path" == "$src_path" ]]; then
      src_mid_path='.'
    else
      src_mid_path="${file_path#$src_path/}"
    fi
    filename="$(basename "$file")"
    encode_str=$(eval "echo "$encode_str"")

    # Filename short
    # Short output name - series
    if [[ "$filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]]
    then
      filename_short=$(echo "$filename" | sed -E 's/([sS][0-9]{2}[eE][0-9]{2}).*/\1/')
    # Short output name - movies (with id string)
    elif ! [[ "$filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]] && \
    [[ "$filename" =~ .*(\([0-9]{4}\)).* ]] && \
    [[ "$filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]]
    then
      filename_short=$(echo "${filename%.*}" | sed -E 's/(\{(imdb|tmdb|tvdb|tvmaze)[^}]*\}|\[(imdb|tmdb|tvdb|tvmaze)[^]]*\]).*/\1/')
    # Short output name - movies (without id string)
    elif ! [[ "$filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]] && \
    ! [[ "$filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]] && \
    [[ "$filename" =~ .*(\([0-9]{4}\)).* ]]
    then
      filename_short=$(echo "$filename" | sed -E 's/(\([0-9]{4}\)).*/\1/')
    # Short output name - other (not series or movies)
    elif ! [[ "$filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]] && \
    ! [[ "$filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]] && \
    ! [[ "$filename" =~ .*(\([0-9]{4}\)).* ]]
    then
      filename_short=$(echo "${filename%.*}")
    fi

    # Perform check - file size
    if [ "$file_size" -lt "$SRC_STREAM_MIN_SIZE" ]
    then
      # Make log entry
      make_error_log "Input file size is less than minimum ${SRC_STREAM_MIN_SIZE}Kb requirement"
      continue
    fi

    # Perform check - file age
    if [ "$epochtime" -lt "$rsync_cutoff_end_epoch" ] && [ "$epochtime" -gt "$rsync_cutoff_start_epoch" ]
    then
      continue
    fi

    # Perform check - file in processing queue
    if [[ $(grep -F "$src_path/$src_mid_path/$filename;" $QUEUE_FILE) ]]
    then
      continue
    fi

    # Perform check - file blacklisted
    for pattern in "${black_LIST[@]}"
    do
      if [[ "$file" =~ $pattern ]]
      then
        # Make log entry
        make_error_log "Input file name is blacklisted."
        continue 2
      fi
    done

    # Perform check - file exists in destination dir
    for pattern in "${existing_file_LIST[@]}"
    do
      if [[ "$pattern" =~ ^.*\/$(printf '%q' "$src_mid_path/$filename_short").* ]]
      then
        continue 2
      fi
    done

    #---- Process '/mnt/public/autoadd/...' input files
    # Autoadd inputs are processed differently to  standard 'series' or 'movie' content.
    # The files are moved from their source to the transcode folder for processing so
    # the $src_path is modified.
    if [ "$media_type" = 'autoadd' ]
    then
      # Remove non-compliant files from 'autoadd/vidcoderr/{in_homevideo,in_unsorted}'
      find "$src_path" -type f -name "$(printf "%q" "$filename_short")*" \
      -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex1).*" \
      -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" \
      -regextype posix-extended -not -iregex ".*($video_format_filter_regex)$" \
      -regextype posix-extended -not -iregex ".*($subtitle_format_filter_regex)$" \
      -exec rm {} \; \
      -o -type d \
      -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex1).*" \
      -empty -delete 2> /dev/null

      # Create transcode dirs
      mkdir -p "$TRANSCODE_DIR/$label"

      # Move media from 'autoadd/vidcoderr/{in_homevideo,in_unsorted}' to transcode dir
      # Move video and subtitle files only
      # Loop through the files in $src_dir
      while read line
      do
        rsync --remove-source-files --relative "$src_path/./$src_mid_path/$(basename "$line")" "$TRANSCODE_DIR/$label"
      done < <( find "$src_path/$src_mid_path" -type f -name "$(printf "%q" "$filename_short")*" \
      -regextype posix-extended -iregex ".*($video_format_filter_regex)$" \
      -o \
      -regextype posix-extended -iregex ".*($subtitle_format_filter_regex)$" \
      -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex1).*" 2> /dev/null )

      # Clean 'autoadd/vidcoderr/{in_homevideo,in_unsorted}' of old stuff (dirs etc)
      find "$src_path" -type f -name "$(printf "%q" "$filename_short")*" \
      -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex1).*" \
      -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" \
      -exec rm {} \; \
      -o -type d \
      -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex1).*" \
      -empty -delete 2> /dev/null

      # Set new $src_path to $TRANSCODE_DIR/$label dir
      src_path="$TRANSCODE_DIR/$label"
    fi

    # Add file to the input entry list
    # 1=src_mid_path; 2=dst_path; 3=src_path; 4=label; 5=file size; 6=file name; 7=full file path; 8=encode_str; 9=file epochtime; 10=file date & time
    input_file_LIST+=( "$src_mid_path;$dst_path;$src_path;$label;$file_size;$filename;$src_path/$src_mid_path/$filename;$encode_str;$epochtime;$date_time" )

  done < <( find "$src_path" -type f \
  -regextype posix-extended -iregex ".*\.($video_format_filter_regex)$" \
  -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex2)$" \
  -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" 2> /dev/null )

done < <( printf '%s\n' "${input_dir_LIST[@]}" )

#### Run video encoder pre-processor ####
if [ "${#input_file_LIST[@]}" -ge 1 ]
then
  source $APP_HOME/vidcoderr_encoder_pre-processor.sh
fi

# Run prune
source $APP_HOME/vidcoderr_watchdir_prune.sh


#---- Clean AutoAdd dirs

# Full clean-up of autoadd dirs
while IFS=';' read -r src arg
do
  # If active, run clean-up
  if [ "$arg" = 1 ]
  then
    # Remove small folders (i.e folders smaller than '$DST_STREAM_DIR_MINSIZE')
    while read -r dir_size dir_path
    do
      [[ "$dir_size" -lt "$DST_STREAM_DIR_MINSIZE" ]] && rm -rf "$dir_path" 2> /dev/null
    done < <( find "$src" -mindepth 1 -depth -type d \
    -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex1).*" \
    -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" \
    -exec du -ks {} \; 2> /dev/null )
  fi
done < <( printf '%s\n' "${input_autoadd_dir_LIST[@]}" )
#-----------------------------------------------------------------------------------