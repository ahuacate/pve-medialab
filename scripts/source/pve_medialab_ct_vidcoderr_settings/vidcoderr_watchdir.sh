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
  echo "$datetime: $dir$filename job sent to encoder." >> ${LOG}
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
EVENTS='-e close_write,moved_to'

#---- Hardware video encoders
if [ ${NVIDIA_AQ_ARG} = 1 ] && [ ${NVIDIA_GPU_ARG} = 1 ]; then
  HW_ENCODER='--nvenc --nvenc-temporal-aq '
elif [ ${NVIDIA_AQ_ARG} = 1 ] && [ ${NVIDIA_GPU_ARG} = 0 ]; then
  HW_ENCODER='--nvenc '
fi

# Intel Quick Sync Video
if [ ${INTEL_QSV_ARG} = 1 ]; then
  HW_ENCODER='--qsv '
fi

# VAAPI
if [ ${VAAPI_ARG} = 1 ]; then
  HW_ENCODER='--vaapi '
fi

# x264 software
if [ ${X264_ARG} = 1 ]; then
  HW_ENCODER='--x264 '
elif [ ${X264_ARG} = 2 ]; then
  HW_ENCODER='--x264-avbr '
elif [ ${X264_ARG} = 3 ]; then
  HW_ENCODER='--x264-quick '
elif [ ${X264_ARG} = 4 ]; then
  HW_ENCODER='--x264-avbr --x264-quick '
fi

# x265 software
if [ ${X265_ARG} = 1 ]; then
  HW_ENCODER='--x265 '
fi

# All Hardware encoding settings off
if [ ${NVIDIA_GPU_ARG} = 0 ] && [ ${INTEL_QSV_ARG} = 0 ] && [ ${VAAPI_ARG} = 0 ] && [ ${X264_ARG} = 0 ] && [ ${X265_ARG} = 0 ]; then
  HW_ENCODER=""
fi

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Video format
VIDEO_FORMAT_FILTER=$(cat ${APP_HOME}/video_format_filter.txt |  awk '{print}' ORS='|' | sed 's/|$//')

# Create arrays
unset input_dir_array
unset watch_dir_array
unset exclude_dir_array
while IFS=',' read -r label src dst encode_str arg; do
  if [ ${arg} == 1 ]; then
    # All input dirs
    input_dir_array+=( "$(echo ${label},${src},${dst},${encode_str} | sed "s/'//g")" )
    # Inotifywait watch dirs
    watch_dir_array+=( "$(echo ${src} | sed "s/'//g")" )
    # Exclude dirs from events or actions
    if [ $(echo ${src} | grep -w "^/mnt/public/autoadd/vidcoderr.*\|.*/cctv/.*\|.*/homevideo/.*\|.*/transcode/.*\|\..*" > /dev/null; echo $?) == 0 ]; then
      exclude_dir_array+=( "$(echo ${src})" )
    fi
  fi
done < <(cat ${APP_HOME}/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_*' | sed 's/^.*=//')
# Video file format (.ext) types
unset video_format_filter_array
video_format_filter_array+=( "$(cat ${APP_HOME}/video_format_filter.txt)" )
# Other file format (.ext) types
unset other_format_filter_array
other_format_filter_array+=( "$(cat ${APP_HOME}/other_format_filter.txt)" )
# All file format (.ext) types
unset all_format_filter_array
all_format_filter_array+=( "$(cat ${APP_HOME}/video_format_filter.txt ${APP_HOME}/other_format_filter.txt)" )

#---- Body -------------------------------------------------------------------------

# Transcode dir
mkdir -p ${TRANSCODE_DIR}
if ! [ -d ${TRANSCODE_DIR} ]; then
  echo "Fail: ${TRANSCODE_DIR}Usage: $0 cmd ..."
  exit -1;
fi

# Vidcoderr Inotify script
inotifywait -m -r ${EVENTS} ${watch_dir_array[*]} \
  --timefmt '%Y-%m-%dT%H:%M:%S' \
  --format '%T;%w;%f;%e' | \
  while IFS=';' read datetime dir filename event; do
  # Check SRC file size
  if [[ "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
    SRC_SIZE=$(du --apparent-size --block-size=M "${dir}${filename}" | awk -F'[^0-9]*' '{ print $1 }')
  fi

  #---- Process event
  if [[ ${event} == *"CLOSE_WRITE"* ]] && [[ "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]] && [ ${SRC_SIZE} -gt ${SRC_STREAM_MIN_SIZE} ]; then
    #---- Action on 'close_write' event
    # Set file & path variables
    while IFS=',' read -r label src dst encode_str; do
      if [ $(echo ${dir} | grep -w "^${src}.*" > /dev/null; echo $?) == 0 ]; then
        # Set video file parent dirs
        if [[ "${dir}" == "${src}" ]]; then
          FILE_PARENT_DIR=""
        else
          FILE_PARENT_DIR="$(echo "$dir" | sed "s|${src}||g")"
        fi
        # Set destination dir
        DST_DIR="${dst}"
        # Set source category
        SRC_CATEGORY="${label}"
        # Move and set vars from autoadd/vidcoderr/{in_homevideo,in_unsorted,in_stream}
        if [ $(echo ${dir} | grep -w "^.*/autoadd/vidcoderr/.*" > /dev/null; echo $?) == 0 ]; then
          cd /tmp && find "${dir}" -type f \( ! -name ".foo_protect" ! -name "EXCLUDE_LIST" $(printf ' -a ! -name *.%s\n' ${all_format_filter_array[@]}) \) -exec rm {} \;
          mkdir -p "${TRANSCODE_DIR}/${SRC_CATEGORY}/" > /dev/null
          rsync --remove-source-files --relative "${src}/./${FILE_PARENT_DIR}${filename}" "${TRANSCODE_DIR}/${SRC_CATEGORY}/"
          cd "$src" && find . -type d -empty -delete 2> /dev/null
          # Set new source dir
          SRC_DIR="${TRANSCODE_DIR}/${SRC_CATEGORY}/"
        else
          SRC_DIR="${src}"
        fi
        # Set encoder arg string
        ENCODE_STR=$(eval "echo "${encode_str}"")
      fi
    done < <(printf '%s\n' ${input_dir_array[@]})

    # Set SRC filename
    SRC_FILENAME="${filename}"
    SRC_FILE="${SRC_DIR}${FILE_PARENT_DIR}${SRC_FILENAME}"

    # Set DST filename & type
    if [ $(echo "${filename##*.}") == 'mkv' ]; then
      FORMAT_EXT='--mp4 '
      ENCODE_OUTPUT_FILENAME="$(echo ${filename} | sed 's/\(.[a-z0-9]*$\)/\.mp4/')"
      ENCODE_OUTPUT_FILENAME_EXT='mp4'
    else
      FORMAT_EXT=""
      ENCODE_OUTPUT_FILENAME="$(echo ${filename} | sed 's/\(.[a-z0-9]*$\)/\.mkv/')"
      ENCODE_OUTPUT_FILENAME_EXT='mkv'
    fi

    # Set SRC/DST filename short ( for alias searches )
    FILENAME_SHORT="$(echo ${filename} | sed -e 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed -e 's/ \.\([a-z0-9]*\)$/\.\1/' | sed -e 's/\(.[a-z0-9]*$\)//')"

    #---- Video stream settings
    # Check for HDR source video
    COLORS=$(ffprobe -show_streams -v error "${SRC_FILE}" |egrep "^color_transfer|^color_space=|^color_primaries=" |head -3)
    for C in $COLORS; do
      if [[ "$C" = "color_space="* ]]; then
        COLORSPACE=${C##*=}
      elif [[ "$C" = "color_transfer="* ]]; then
        COLORTRANSFER=${C##*=}
      elif [[ "$C" = "color_primaries="* ]]; then
        COLORPRIMARIES=${C##*=}
      fi      
    done    
    if [ "${COLORSPACE}" = "bt2020nc" ] && [ "${COLORTRANSFER}" = "smpte2084" ] && [ "${COLORPRIMARIES}" = "bt2020" ]; then 
      SRC_HDR=1
    else
      SRC_HDR=0
    fi

    # Check SRC video codec
    SRC_CODEC=$(mediainfo --Inform="Video;%Format%" "${SRC_FILE}")

    # Check SRC video height
    SRC_HEIGHT_VAR=$(mediainfo --Inform="Video;%Height%" "${SRC_FILE}" | sed 's/[^0-9]*//g')
    if ((1<= ${SRC_HEIGHT_VAR} && ${SRC_HEIGHT_VAR}<=660)); then
      SRC_HEIGHT=480
    elif ((661<=${SRC_HEIGHT_VAR} && ${SRC_HEIGHT_VAR}<=890)); then
      SRC_HEIGHT=720
    elif ((891<=${SRC_HEIGHT_VAR} && ${SRC_HEIGHT_VAR}<=1200)); then
      SRC_HEIGHT=1080
    elif ((1201<=${SRC_HEIGHT_VAR})); then
      SRC_HEIGHT=2160
    fi

    # Check SRC bitrate
    SRC_BITRATE=$(mediainfo --Output='Video;%BitRate/String%' "${SRC_FILE}" | sed 's/[^0-9]*//g')

    # Check audio channels and language
    unset input_audiostream_array
    input_audiostream_array+=( "$(ffprobe "${SRC_FILE}" -show_entries stream=index:stream_tags=language -select_streams a -v 0 -of compact=p=0:nk=1)" )
    if [ $(echo ${input_audiostream_array[*]}  | grep -w ".*${LANG_DEFAULT}.*" > /dev/null; echo $?) = 0 ]; then
      while IFS='|' read -r index lang; do
        if [ ${index} == 1 ] && [ ${lang} == ${LANG_DEFAULT} ]; then
          MAIN_AUDIO="--main-audio 1=${DST_STREAM_AUDIO_CHANNELS} "
          ADD_AUDIO=""
          break
        elif [ ! ${index} == 1 ] && [ ${lang} == ${LANG_DEFAULT} ]; then
          MAIN_AUDIO="--main-audio 1=${DST_STREAM_AUDIO_CHANNELS} "
          ADD_AUDIO="--add-audio ${index}=${DST_STREAM_AUDIO_CHANNELS} "
          break
        fi
      done < <(printf '%s\n' ${input_audiostream_array[@]})
    else
      MAIN_AUDIO="--main-audio 1=${DST_STREAM_AUDIO_CHANNELS} "
      ADD_AUDIO=""
    fi
    
    #---- Encode Status - encode, passthru or ignore file
    # Check SRC bitrate
    if [ ${SRC_HEIGHT} == 480 ] && [ ${SRC_BITRATE} -gt ${DST_STREAM_BITRATE_480} ]; then
      SRC_BITRATE_ENCODE=1
    elif [ ${SRC_HEIGHT} == 720 ] && [ ${SRC_BITRATE} -gt ${DST_STREAM_BITRATE_720} ]; then
      SRC_BITRATE_ENCODE=1
    elif [ ${SRC_HEIGHT} == 1080 ] && [ ${SRC_BITRATE} -gt ${DST_STREAM_BITRATE_1080} ]; then
      SRC_BITRATE_ENCODE=1
    elif [ ${SRC_HEIGHT} == 2160 ] && [ ${SRC_BITRATE} -gt ${DST_STREAM_BITRATE_2160} ]; then
      SRC_BITRATE_ENCODE=1
    else
      SRC_BITRATE_ENCODE=0
    fi
    
    # Check HDR encode capability
    if [ ${ENCODE_HDR_CONTENT} == 1 ] && [ ${SRC_HDR} == 1 ] || [ ${SRC_HDR} == 0 ]; then
      SRC_HDR_ENCODE=1
    elif [ ${ENCODE_HDR_CONTENT} == 0 ] && [ ${SRC_HDR} == 1 ]; then
      SRC_HDR_ENCODE=0
    else
      SRC_HDR_ENCODE=1
    fi

    # Encode Status
    if [ ${SRC_BITRATE_ENCODE} == 1 ] && [ ${SRC_HDR_ENCODE} == 1 ]; then
      ENCODE_ENABLED=1
    else
      ENCODE_ENABLED=0
    fi
    
    # Check for an existing DST file
    if [[ $(ls "${DST_DIR}${FILE_PARENT_DIR}${FILENAME_SHORT}"* 2> /dev/null) ]]; then
      while read line; do
        if [[ "$line" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
          DST_EXISTING_CHECK=1
        else
          DST_EXISTING_CHECK=0
        fi
      done < <( ls "${DST_DIR}${FILE_PARENT_DIR}${FILENAME_SHORT}"* 2> /dev/null )
    else
      DST_EXISTING_CHECK=0
    fi

    #---- Write Queue job
    if [ ${SRC_SIZE} -gt ${SRC_STREAM_MIN_SIZE} ]; then
      # Create batch queue
      ARG1="${SRC_FILE}"
      ARG2="${FORMAT_EXT}${HW_ENCODER}${NVIDIA_AQ}${MAIN_AUDIO}${ADD_AUDIO}${ENCODE_STR}"
      ARG3="${FILE_PARENT_DIR}"
      ARG4="${SRC_CATEGORY}"
      ARG5="${ENCODE_OUTPUT_FILENAME}"
      ARG6="${DST_DIR}"
      ARG7="${ENCODE_ENABLED}"
      echo "${ARG1};${ARG2};${ARG3};${ARG4};${ARG5};${ARG6};${ARG7}" >> ${QUEUE_FILE}
      
      # Run Vidcoderr ( other-transcode )
      sleep 1
      if ! [[ $(pgrep -fl "vidcoderr_encoder.sh") ]]; then
        /usr/local/bin/vidcoderr/vidcoderr_encoder.sh &
      fi
      make_log
    fi
  elif [[ ${event} == *"CLOSE_WRITE"* ]] && [[ ! "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]] || [ ${SRC_SIZE} -lt ${SRC_STREAM_MIN_SIZE} ]; then
    #---- Action on incompatible SRC file
    # Remove files from /autoadd/vidcoderr/ dirs
    if [ $(echo ${dir} | grep -w "^.*/autoadd/vidcoderr/.*" > /dev/null; echo $?) == 0 ]; then
      echo "write event 3"
      while IFS=',' read -r label src dst encode_str; do
        if [ $(echo ${dir} | grep -w "^${src}.*" > /dev/null; echo $?) == 0 ]; then
          # Set video file parent dirs
          if [[ "${dir}" == "${src}" ]]; then
            FILE_PARENT_DIR=""
          else
            FILE_PARENT_DIR="$(echo "$dir" | sed "s|${src}||g")"
          fi
          # Set SRC/DST filename short ( for alias searches )
          FILENAME_SHORT="$(echo ${filename} | sed -e 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed -e 's/ \.\([a-z0-9]*\)$/\.\1/' | sed -e 's/\(.[a-z0-9]*$\)//')"
          # Delete files
          cd "$dir" && find . -type f \( ! -name ".foo_protect" ! -name "EXCLUDE_LIST" $(printf ' -a ! -name *.%s\n' ${all_format_filter_array[@]}) \) -exec rm {} \;
          cd "$src" && find . -type f -iname "${FILENAME_SHORT}*" -delete 2> /dev/null
          cd "$src" && find . -type d -empty -delete 2> /dev/null
        fi
      done < <(printf '%s\n' ${input_dir_array[@]})
      # Write log
      if [[ ! "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
        sourcefile_error_log
      elif [ ${SRC_SIZE} -lt ${SRC_STREAM_MIN_SIZE} ]; then
        make_error_log "Input file size ( ${SRC_SIZE}MB ) less than Vidcoderr minimum ( ${SRC_STREAM_MIN_SIZE}MB )."
      fi
    elif [ $(echo ${dir} | grep -w "^.*/autoadd/vidcoderr/.*" > /dev/null; echo $?) == 1 ]; then
      echo "write event 4"
      # Write log
      if [[ ! "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
        sourcefile_error_log
      elif [ ${SRC_SIZE} -lt ${SRC_STREAM_MIN_SIZE} ]; then
        make_error_log "Input file size ( ${SRC_SIZE}MB ) less than Vidcoderr minimum ( ${SRC_STREAM_MIN_SIZE}MB )."
      fi
    fi
  fi

  # Prune DST stream media, delete orphaned folders & README-source_file_type.error.log error files
  if ! [ ${DST_STREAM_AGE} == 0 ]; then
    while IFS=',' read -r label src dst encode_str; do
      # Delete source log warnings after 1day
      cd "$src" && find . -type f \( ! -iname ".foo_protect" \) -name README-source_file_type.error.log -mtime +1 -delete
      # Prune aged stream media
      if [ $(echo ${dst} | grep -w "^.*/stream/.*" > /dev/null; echo $?) == 0 ]; then
        cd "$dst" && find .* -type f \( ! -iname ".foo_protect" \) -mtime +${DST_STREAM_AGE} -delete
        cd "$dst" && find . -mindepth 1 -empty -type d -exec du {} + | cut -f 2- | sed 's/^/"/;s/$/"/' | xargs rm -Rf 2> /dev/null
      fi
    done < <(printf '%s\n' ${input_dir_array[@]})
    # Return to working dir
    cd "$transcode"
  fi
done