#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_inotify_std.sh
# Description:  Source script for inotify watch of autoadd inputs
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Vidcoderr home
APP_HOME='/usr/local/bin/vidcoderr'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create include file ext filter
# (i.e webm|mkv|mk3d|mka|mks|flv|vob) & (i.e srt|ssa|vtt)
inotify_include_filter_regex="(\.($(sed 's/$/|/' <(cat $APP_HOME/video_format_filter.txt $APP_HOME/subtitle_format_filter.txt) | tr -d '\n' | sed 's/|$//'))$)"

# Exclude sub-path list
# Here we enter the dirs which we want to exclude from inotifywait.
inotify_excluded_dir_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  inotify_excluded_dir_LIST+=( ".*/$(printf '%q' "$line")/.*" )
done << EOF
# Entry must not contain '/' at the start or end.
# Entry can be one or more dirs in series (i.e public/autoadd/vidcoderr/out_unsorted).
# Example:
# vidcoderr/out_unsorted
# out_unsorted
vidcoderr/out_unsorted
EOF


#---- Action on autoadd SRC file

inotifywait -m -r -e close_write,moved_to --include "$inotify_include_filter_regex" /mnt/public/autoadd/vidcoderr/ \
    --timefmt '%Y-%m-%dT%H:%M:%S' \
    --format '%T;%w;%f;%e' | \
    while IFS=';' read datetime dir filename event; do
      # Perform check - excluded dirs
      for pattern in "${inotify_excluded_dir_LIST[@]}"
      do
        if [[ "$dir" =~ $pattern ]]
        then
          continue 2
        fi
      done
      # Wait for 'vidcoderr_watchdir.sh' to be inactive
      while pgrep -fl "vidcoderr_watchdir.sh" </dev/null; do
        sleep 2
      done
      # Start 'vidcoderr_watchdir.sh'
      if ! [[ $(pgrep -fl "vidcoderr_watchdir.sh") ]]; then
        /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
      fi
    done
#-----------------------------------------------------------------------------------