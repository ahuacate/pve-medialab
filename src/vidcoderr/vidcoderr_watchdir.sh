#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchdir.sh
# Description:  Inotifywait watch dir script for Vidcoderr
# Usage:  All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Read vidcoderr.ini file
source /usr/local/bin/vidcoderr/vidcoderr.ini

# Transcode dir
mkdir -p ${TRANSCODE_DIR}
if ! [ -d ${TRANSCODE_DIR} ]; then
  echo "Fail: ${TRANSCODE_DIR}Usage: $0 cmd ..."
  exit -1;
fi

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
  if [ "${media_type}" == "autoadd" ] ; then
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

#---- Inotify vars
# Inotifywait events
EVENTS='-e close_write,moved_to'

#---- Rsync vars
# Rsync cutoff period (days)
RSYNC_CUTOFF_START_EPOCH=$(date  +'%s' --date="${RSYNC_CUTOFF_START} days ago")
RSYNC_CUTOFF_END_EPOCH=$(date  +'%s' --date="${RSYNC_CUTOFF_END} days ago")


#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Inotify Video format
VIDEO_FORMAT_FILTER=$(cat ${APP_HOME}/video_format_filter.txt |  awk '{print}' ORS='|' | sed 's/|$//')

# Rsync Video filter
cat ${APP_HOME}/video_format_filter.txt | sed 's/^/+ *./' | sed '1i\+ */' | sed '$a\- *' > ${APP_HOME}/rsync_video_format_filter.txt

# Encoder Queue file
if [ ! -f ${QUEUE_FILE} ]; then
  touch ${QUEUE_FILE}
fi

# Create List Arrays
unset input_dir_LIST
unset watch_dir_LIST
unset exclude_dir_LIST
while IFS=',' read -r label media_type src dst encode_str arg; do
  if [ "${arg}" = 1 ]; then
    # All input dirs
    input_dir_LIST+=( "$(echo ${label},${media_type},${src},${dst},${encode_str} | sed "s/'//g")" )
    # Rsync & Inotifywait watch dirs
    watch_dir_LIST+=( "$(echo ${src} | sed "s/'//g")" )
    # # Exclude dirs from events or actions
    # if [ $(echo ${src} | grep -w "^/mnt/public/autoadd/vidcoderr/out_unsorted/.*\|.*/cctv/.*\|.*/homevideo/.*\|.*/transcode/.*\|\..*" > /dev/null; echo $?) == 0 ]; then
    #   exclude_dir_LIST+=( "$(echo ${src})" )
    # fi
  fi
done < <(cat ${APP_HOME}/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_*' | sed 's/^.*=//')
# Video file format (.ext) types
unset video_format_filter_LIST
video_format_filter_LIST+=( "$(cat ${APP_HOME}/video_format_filter.txt)" )
# Other file format (.ext) types
unset other_format_filter_LIST
other_format_filter_LIST+=( "$(cat ${APP_HOME}/other_format_filter.txt)" )
# All file format (.ext) types
unset all_format_filter_LIST
all_format_filter_LIST+=( "$(cat ${APP_HOME}/video_format_filter.txt ${APP_HOME}/other_format_filter.txt)" )


#---- Body Type: Rsync -------------------------------------------------------------

if [ ${VIDCODERR_WATCHDIR_TYPE} == '1' ]; then
  #---- Run List
  source ${APP_HOME}/vidcoderr_watchdir_list.sh
 
  #---- Create Rsync DL list
  unset input_file_LIST
  while IFS=',' read -r label media_type src dst encode_str; do
    # Create new file list
    while IFS='|' read -r src_size epochtime datetime dir filename; do
      # Non-autoadd input
      if [ ! "${media_type}" == "autoadd" ] && [[ "${filename}" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]] && [ ${src_size} -gt ${SRC_STREAM_MIN_SIZE} ] && [[ ! $(echo "$dir" | grep -f ${APP_HOME}/rsync_black_LIST.txt) ]] && [[ ! $(grep -F "${dir}${filename};" ${QUEUE_FILE}) ]] && [ ${epochtime} -gt ${RSYNC_CUTOFF_END_EPOCH} ] && [ ${epochtime} -lt ${RSYNC_CUTOFF_START_EPOCH} ]; then
        # Set 'src_mid_dir' var
        if [[ "${dir}" == "${src}" ]]; then 
          src_mid_dir=""
        else
          src_mid_dir="$(echo "$dir" | sed "s|${src}||g" | sed 's/[^/]$/&\//')"
        fi

        # Check if file already exists in destination library
        if [[ "${existing_file_LIST[@]}" =~ ^.*("${dst}${src_mid_dir}$(echo "${filename%.*}" | sed 's/\[[^][]*\]$//g' | sed 's/ $//g')").*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
          source ${APP_HOME}/vidcoderr_watchdir_remove.sh
          continue
        fi

        # Set encoder arg string
        encode_str=$(eval "echo "${encode_str}"")

        # Set src dir
        src_dir="${src}"

        # New file list args
        # 1=SRC_MID_DIR; 2=DST_DIR; 3=SRC_DIR; 4=SRC_CATEGORY; 5=SRC_SIZE; 6=SRC_FILENAME; 7=SRC_FILE; 8=ENCODE_STR; 9=SRC_EPOCHTIME; 10=SRC=DATETIME
        input_file_LIST+=( "${src_mid_dir};${dst};${src_dir};${label};${src_size};${filename};${src_dir}${src_mid_dir}${filename};${encode_str};${epochtime};${datetime}" )
      fi

      # Autoadd input
      if [ "${media_type}" == "autoadd" ] && [[ "${filename}" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]] && [ ${src_size} -gt ${SRC_STREAM_MIN_SIZE} ] && [[ ! $(grep -F "${dir}${filename};" ${QUEUE_FILE}) ]]; then
        # Set 'src_mid_dir' var
        if [[ "${dir}" == "${src}" ]]; then
          src_mid_dir=""
        else
          src_mid_dir="$(echo "$dir" | sed "s|${src}||g" | sed 's/[^/]$/&\//')"
        fi

        # Check if file already exists in stream library
        if [[ "${existing_file_LIST[@]}" =~ ^.*("${dst}${src_mid_dir}$(echo "${filename%.*}" | sed 's/\[[^][]*\]$//g' | sed 's/ $//g')").*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
          source ${APP_HOME}/vidcoderr_watchdir_remove.sh
          continue
        fi

        # Set encoder arg string
        encode_str=$(eval "echo "${encode_str}"")

        # Set new src dir
        src_dir="${TRANSCODE_DIR}/${label}/"

        # Move media from autoadd/vidcoderr/{in_homevideo,in_unsorted,in_stream} and set vars
        cd /tmp && find "${dir}" -type f \( ! -name ".foo_protect" ! -name "EXCLUDE_LIST" $(printf ' -a ! -name *.%s\n' ${all_format_filter_LIST[@]}) \) -exec rm {} \;
        mkdir -p "${src_dir}" > /dev/null
        rsync --remove-source-files --relative "${src}/./${src_mid_dir}${filename}" "${src_dir}"
        cd "$src" && find . -type d -empty -delete 2> /dev/null

        # New file list args
        # 1=SRC_MID_DIR; 2=DST_DIR; 3=SRC_DIR; 4=SRC_CATEGORY; 5=SRC_SIZE; 6=SRC_FILENAME; 7=SRC_FILE; 8=ENCODE_STR; 9=SRC_EPOCHTIME; 10=SRC=DATETIME
        input_file_LIST+=( "${src_mid_dir};${dst};${src_dir};${label};${src_size};${filename};${src_dir}${src_mid_dir}${filename};${encode_str};${epochtime};${datetime}" )
      fi

      # Action on incompatible SRC file
      if [[ ! "${filename}" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]] || [ ! ${src_size} -gt ${SRC_STREAM_MIN_SIZE} ]; then
        source ${APP_HOME}/vidcoderr_watchdir_remove.sh
      fi

    done < <(rsync -nr -t --no-links --relative --list-only --out-format='%n' --min-size='1' --exclude-from ${APP_HOME}/rsync_exclude_filter.txt --prune-empty-dirs "${src}" | \
    cut -d' ' -f2- | sed 's/^ *//' | \
    awk -F' ' '{OFS=FS; gsub(/,/,"",$1); command="date -d\""$2" "$3"\" +%s"; $3=$2"#"$3; command | getline $2; close(command); print $0}' | \
    sed 's/ /|/;s/ /|/;s/ /|\//' | sed 's/\(.*\)\/\(.*\)\.\(.*\)$/\1\/|\2.\3/' | sed 's/#/ /' | sed '/^$/d' | \
    awk -F'|' 'NF==5 {print}')
  done< <(printf '%s\n' "${input_dir_LIST[@]}")

  #---- Run Processor
  if [ ${#input_file_LIST[@]} -ge 1 ]; then
    source ${APP_HOME}/vidcoderr_watchdir_process.sh
  fi

  #---- Run Prune
  source ${APP_HOME}/vidcoderr_watchdir_prune.sh
fi


#---- Body Type: Inotify -----------------------------------------------------------

if [ ${VIDCODERR_WATCHDIR_TYPE} == '2' ]; then
  # Vidcoderr Inotify script
  inotifywait -m -r ${EVENTS} ${watch_dir_LIST[*]} \
    --timefmt '%Y-%m-%dT%H:%M:%S' \
    --format '%T;%w;%f;%e' | \
    while IFS=';' read datetime dir filename event; do

    #---- Run List
    source ${APP_HOME}/vidcoderr_watchdir_list.sh

    #---- Create Rsync DL list
    unset input_file_LIST

    # Get SRC file size
    src_size=$(du --apparent-size --block-size=kB "${dir}${filename}" | awk -F'[^0-9]*' '{ print $1 }')

    # Get Epoch time
    epochtime=$(date -d "$datetime" +"%s")

    #---- Process valid event
    if [[ ${event} == *"CLOSE_WRITE"* ]] && [[ "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]] && [ ${src_size} -gt ${SRC_STREAM_MIN_SIZE} ]; then
      #---- Action on 'close_write' event
      # Set file & path variables
      while IFS=',' read -r label media_type src dst encode_str; do
        if [ $(echo ${dir} | grep -w "^${src}.*" > /dev/null; echo $?) == 0 ]; then

          # Set 'src_mid_dir' var
          if [[ "${dir}" == "${src}" ]]; then 
            src_mid_dir=""
          else
            src_mid_dir="$(echo "$dir" | sed "s|${src}||g" | sed 's/[^/]$/&\//')"
          fi

          # Check if file already exists in stream library
          if [[ "${existing_file_LIST[@]}" =~ ^.*("${src_mid_dir}$(echo "${filename%.*}" | sed 's/\[[^][]*\]$//g' | sed 's/ $//g')").*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
            source ${APP_HOME}/vidcoderr_watchdir_remove.sh
            continue
          fi

          # Set encoder arg string
          encode_str=$(eval "echo "${encode_str}"")
          
          # Move and set vars from autoadd/vidcoderr/{in_homevideo,in_unsorted,in_stream}
          if [ "${media_type}" == "autoadd" ]; then
            cd /tmp && find "${dir}" -type f \( ! -name ".foo_protect" ! -name "EXCLUDE_LIST" $(printf ' -a ! -name *.%s\n' ${all_format_filter_LIST[@]}) \) -exec rm {} \;
            mkdir -p "${TRANSCODE_DIR}/${label}/" > /dev/null
            rsync --remove-source-files --relative "${src}/./${src_mid_dir}${filename}" "${TRANSCODE_DIR}/${label}/"
            cd "$src" && find . -type d -empty -delete 2> /dev/null
            # Set new source dir
            src_dir="${TRANSCODE_DIR}/${label}/"
          else
            src_dir="${src}"
          fi

          # New file list args
          # 1=SRC_MID_DIR; 2=DST_DIR; 3=SRC_DIR; 4=SRC_CATEGORY; 5=SRC_SIZE; 6=SRC_FILENAME; 7=SRC_FILE; 8=ENCODE_STR; 9=SRC_EPOCHTIME; 10=SRC=DATETIME
          input_file_LIST+=( "${src_mid_dir};${dst};${src_dir};${label};${src_size};${filename};${src}${src_mid_dir}${filename};${encode_str};${epochtime};${datetime}" )
        fi
      done < <(printf '%s\n' "${input_dir_LIST[@]}")

      #---- Run Processor
      if [ ${#input_file_LIST[@]} -ge 1 ]; then
        source ${APP_HOME}/vidcoderr_watchdir_process.sh
      fi

      #---- Run Prune
      source ${APP_HOME}/vidcoderr_watchdir_prune.sh
    fi

    #---- Process invalid event
    if [[ ${event} == *"CLOSE_WRITE"* ]] && [[ ! "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]] || [ ${SRC_SIZE} -lt ${SRC_STREAM_MIN_SIZE} ]; then
      #---- Action on incompatible SRC file
      # Remove files from /autoadd/vidcoderr/ dirs
      while IFS=',' read -r label media_type src dst encode_str; do
        if [ $(echo ${dir} | grep -w "^${src}.*" > /dev/null; echo $?) == 0 ]; then
          source ${APP_HOME}/vidcoderr_watchdir_remove.sh
        fi
      done < <(printf '%s\n' ${input_dir_LIST[@]})
    fi
fi
#-----------------------------------------------------------------------------------