#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchprune.sh
# Description:  Inotifywait watch prune script for Vidcoderr
# Usage:  All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Read vidcoderr.ini file
source /usr/local/bin/vidcoderr/vidcoderr.ini

# Log files
LOG=${APP_HOME}/vidcoderr_watchdir.log
if [ -f ${LOG} ]; then
  touch ${LOG}
fi

# Functions
function trim_log() {
  # Limit error log file size
  lcnt=$( cat ${LOG} | wc -l)
  # wc -l ${LOG} | read lcnt other
  if [ $lcnt -gt 300 ] ; then
    ((start=$lcnt-99))
    tail +$start ${LOG} > ${LOG}N
    mv ${LOG}N ${LOG}
  fi
}

function make_log() {
  trim_log
  echo "$datetime: $dir$filename job sent to encoder."} >> ${LOG}
}

function make_error_log() {
  trim_log
  echo $(printf -- '-%.0s' {1..84}) >> ${LOG}
  echo "ERROR: $datetime" >> ${LOG}
  echo "Input file: $dir$filename changed $event" >> ${LOG}
  if ! [ -z ${1+x} ]; then
    echo "Reason/Issue: $1" >> ${LOG}
  fi
  echo $(printf -- '-%.0s' {1..84}) >> ${LOG}
}

function sourcefile_error_log() {
  trim_log
  echo $(printf -- '-%.0s' {1..84}) >> ${LOG}
  echo "ERROR: $datetime" >> ${LOG}
  echo "Input file: $dir$filename file type is not compatible." >> ${LOG}
  echo "$(printf -- '-%.0s' {1..84})" >> ${LOG}
  if [ $(echo ${dir} | grep -w "^.*/autoadd/vidcoderr/.*" > /dev/null; echo $?) == 0 ]; then
    # Set source file error log
    SRC_ERROR_LOG=${dir}/README-source_file_type.error.log
    # Create source file error log ( /autoadd/vidcoderr/ )
    echo $(printf -- '-%.0s' {1..84}) > ${SRC_ERROR_LOG}
    echo "ERROR: $datetime" >> ${SRC_ERROR_LOG}
    echo -e "Input file: $dir$filename file type is not compatible.\nCompatible source/input video formats are listed here:" >> ${SRC_ERROR_LOG}
    echo "https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/source/pve_medialab_ct_vidcoderr_settings/video_format_filter.txt" >> ${SRC_ERROR_LOG}
    echo "$(printf -- '-%.0s' {1..84})" >> ${SRC_ERROR_LOG}
  fi
}

#---- Static Variables -------------------------------------------------------------

# Inotifywait events
EVENTS='-e delete'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Video format
VIDEO_FORMAT_FILTER=$(cat ${APP_HOME}/video_format_filter.txt |  awk '{print}' ORS='|' | sed 's/|$//')

# Create arrays
unset input_dir_prune_array
unset watch_dir_prune_array
while IFS=',' read -r label src dst encode_str arg; do
  if [ ${arg} == 1 ]; then
    # All input dirs
    input_dir_prune_array+=( "$(echo ${label},${src},${dst},${encode_str} | sed "s/'//g")" )
    # Inotifywait watch dirs
    watch_dir_prune_array+=( "$(echo ${src} | sed "s/'//g")" )
  fi
done < <(cat ${APP_HOME}/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_STREAM_*' | sed 's/^.*=//')

#---- Body -------------------------------------------------------------------------

EVENTS='-e delete'
# EVENTS='-e close_write,moved_to'
# Vidcoderr Inotify script
inotifywait -m -r ${EVENTS} ${watch_dir_prune_array[*]} \
  --timefmt '%Y-%m-%dT%H:%M:%S' \
  --format '%T;%w;%f;%e' \
| while IFS=';' read datetime dir filename event; do
  #---- Process event
  if [[ ${event} == *"DELETE"* ]] && [[ "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
    #---- Action on 'delete' event
    echo hello2
    # Delete associated DST file
    FILENAME_SHORT="$(echo ${filename} | sed 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed 's/ \.\([a-z0-9]*\)$/\.\1/' | sed 's/\(.[a-z0-9]*$\)//')"
    while IFS=',' read -r label src dst encode_str arg; do
      if [ $(echo ${dir} | grep -w "^${src}.*" > /dev/null; echo $?) == 0 ]; then
        if [[ "${dir}" == "${src}" ]]; then
          FILE_PARENT_DIR=""
        else
          FILE_PARENT_DIR="$(echo "$dir" | sed -e "s|${src}||g")"
        fi
        if [ -d "${dst}${FILE_PARENT_DIR}" ]; then
          cd "$dst$FILE_PARENT_DIR" && find . -type f -iname "${FILENAME_SHORT}*" -delete 2> /dev/null
        fi
        # cd "$dst" && find . -mindepth 1 -empty -type d -exec du {} + | cut -f 2- | sed 's/^/"/;s/$/"/' | xargs rm -Rf 2> /dev/null
        cd "$dst" && find . -type d -empty -delete 2> /dev/null
      fi
    done < <(printf '%s\n' ${input_dir_prune_array[@]})
  fi

  #Prune DST stream media, delete orphaned folders & README-source_file_type.error.log error files
  if ! [ ${DST_STREAM_AGE} == 0 ]; then
    while IFS=',' read -r label src dst encode_str; do
      # Delete source log warnings after 1day
      cd "$src" && find . -type f \( ! -iname ".foo_protect" \) -name README-source_file_type.error.log -mtime +1 -delete
      # Prune aged stream media
      if [ $(echo "$dst" | grep -w "^.*/stream/.*" > /dev/null; echo $?) == 0 ]; then
        cd "$dst" && find .* -type f \( ! -iname ".foo_protect" \) -mtime +${DST_STREAM_AGE} -delete
        # cd "$dst" && find . -mindepth 1 -empty -type d -exec du {} + | cut -f 2- | sed 's/^/"/;s/$/"/' | xargs rm -Rf 2> /dev/null
        cd "$dst" && find . -type d -empty -delete 2> /dev/null
      fi
    done < <(printf '%s\n' ${input_dir_array[@]})
    # Return to working dir
    cd "$transcode"
  fi
done