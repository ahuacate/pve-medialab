#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchdir_list1.sh
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


#---- Create input dir lists

# Initialize list arrays
input_dir_LIST=()
watch_dir_LIST=()
exclude_dir_LIST=()
input_autoadd_dir_LIST=()
exclude_dir_filter_LIST=()
while IFS=',' read -r label media_type src dst encode_str arg
do
  if [ "$arg" = 1 ]
  then
    # Create input dir list entry
    input_dir_LIST+=( "$label,$media_type,$src,$dst,$encode_str" )

    # Rsync & Inotifywait watch dirs
    watch_dir_LIST+=( "$src" )
  fi

  # Create autoadd dir list entry
  if [ "$media_type" = 'autoadd' ]
  then
    # Create input autoadd dir list entry
    input_autoadd_dir_LIST+=( "$src;$arg" )
  fi

  # Create exclude base dir list entry
  exclude_dir_filter_LIST+=( "$src;$dst" )
done < <( cat $APP_HOME/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_*' | sed 's/^.*=//' )


#---- Create other lists

# Create file extension lists
# Video file format (.ext) types
video_format_filter_LIST=()
video_format_filter_LIST+=( "$(cat $APP_HOME/video_format_filter.txt)" )
# Other file format (.ext) types
other_format_filter_LIST=()
other_format_filter_LIST+=( "$(cat $APP_HOME/other_format_filter.txt)" )
# All file format (.ext) types
all_format_filter_LIST=()
all_format_filter_LIST+=( "$(cat $APP_HOME/video_format_filter.txt $APP_HOME/other_format_filter.txt)" )

# Create video format filter from text file
# (i.e webm|mkv|mk3d|mka|mks|flv|vob)
video_format_filter_regex="$(sed 's/$/|/' "$APP_HOME/video_format_filter.txt" | tr -d '\n' | sed 's/|$//')"

# Create subtitle format filter from text file
# (i.e srt|ssa|vtt)
subtitle_format_filter_regex="$(sed 's/$/|/' "$APP_HOME/subtitle_format_filter.txt" | tr -d '\n' | sed 's/|$//')"

# Create exclude filter from text file - filetype
# (i.e *.partial~|#recycle|.foo_protect)
exclude_file_filter_regex="$(sed 's/$/|/' "$APP_HOME/exclude_file_filter.txt" | tr -d '\n' | sed 's/|$//')"

# Create exclude filter from text file - dir & exclude_dir_filter.txt
# (i.e @eaDir|tmp) and includes all base dirs
printf "%s\n" "${exclude_dir_filter_LIST[@]}" | awk -F ';' '{printf "%s$\n%s$\n", $1, $2}' > $APP_HOME/tmp_dir_filter.txt
cat "$APP_HOME/exclude_dir_filter.txt" >> $APP_HOME/tmp_dir_filter.txt
exclude_dir_filter_regex1="$(sed 's/$/|/' "$APP_HOME/tmp_dir_filter.txt" | tr -d '\n' | sed 's/|$//')"

# Create exclude filter from text file - exclude_dir_filter.txt only
# (i.e @eaDir|tmp) only
exclude_dir_filter_regex2="$(sed 's/$/|/' "$APP_HOME/exclude_dir_filter.txt" | tr -d '\n' | sed 's/|$//')"

# Create other filter from text file - other format
# (i.e log)
other_format_filter_regex="$(sed 's/$/|/' "$APP_HOME/other_format_filter.txt" | tr -d '\n' | sed 's/|$//')"

# Create Rsync Video filter
cat $APP_HOME/video_format_filter.txt | sed 's/^/+ *./' | sed '1i\+ */' | sed '$a\- *' > $APP_HOME/rsync_video_format_filter.txt
#-----------------------------------------------------------------------------------