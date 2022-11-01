#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchdir_process.sh
# Description:  Inotifywait watch dir script for Vidcoderr
# Usage:  All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

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
#---- Functions --------------------------------------------------------------------

# Create encoder log entry
function make_encoder_log() {
  trim_log
  echo "${SRC_DATETIME}: ${SRC_FILE} job sent to encoder." >> ${LOG}
}

#---- Body -------------------------------------------------------------------------

#---- Create encoder input args
# 1=SRC_MID_DIR; 2=DST_DIR; 3=SRC_DIR; 4=SRC_CATEGORY; 5=SRC_SIZE; 6=SRC_FILENAME; 7=SRC_FILE; 8=ENCODE_STR; 9=SRC_EPOCHTIME; 10=SRC_DATETIME
while IFS=';' read -r VAR1 VAR2 VAR3 VAR4 VAR5 VAR6 VAR7 VAR8 VAR9 VAR10; do
  # Set vars
  SRC_MID_DIR="$VAR1"
  DST_DIR="$VAR2"
  SRC_DIR="$VAR3"
  SRC_CATEGORY="$VAR4"
  SRC_SIZE="$VAR5"
  SRC_FILENAME="$VAR6"
  SRC_FILE="$VAR7"
  ENCODE_STR="$VAR8"
  SRC_EPOCHTIME="$VAR9"
  SRC_DATETIME="$VAR10"

  # Set DST filename & type
  if [[ "$(echo "${SRC_FILENAME##*.}")" == 'mkv' ]]; then
    FORMAT_EXT='--mp4 '
    ENCODE_OUTPUT_FILENAME="$(echo ${SRC_FILENAME} | sed 's/\(.[a-z0-9]*$\)/\.mp4/')"
    ENCODE_OUTPUT_FILENAME_EXT='mp4'
  else
    FORMAT_EXT=""
    ENCODE_OUTPUT_FILENAME="$(echo ${SRC_FILENAME} | sed 's/\(.[a-z0-9]*$\)/\.mkv/')"
    ENCODE_OUTPUT_FILENAME_EXT='mkv'
  fi

  # Set SRC/DST filename short ( for alias searches )
  FILENAME_SHORT="$(echo ${SRC_FILENAME} | sed -e 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed -e 's/ \.\([a-z0-9]*\)$/\.\1/' | sed -e 's/\(.[a-z0-9]*$\)//')"


  #---- Video stream settings
  # Check for HDR source video
  COLORS=$(ffprobe -show_streams -v error "${SRC_FILE}" 2> /dev/null | egrep "^color_transfer|^color_space=|^color_primaries=" | head -3)
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
  if [[ "${SRC_HEIGHT_VAR}" -ge 1 ]] && [[ "${SRC_HEIGHT_VAR}" -le 660 ]]; then
    SRC_HEIGHT=480
  elif [[ "${SRC_HEIGHT_VAR}" -ge 661 ]] && [[ "${SRC_HEIGHT_VAR}" -le 890 ]]; then
    SRC_HEIGHT=720
  elif [[ "${SRC_HEIGHT_VAR}" -ge 891 ]] && [[ "${SRC_HEIGHT_VAR}" -le 1200 ]]; then
    SRC_HEIGHT=1080
  elif [[ "${SRC_HEIGHT_VAR}" -ge 1201 ]]; then
    SRC_HEIGHT=2160
  fi

  # Check SRC bitrate
  SRC_BITRATE=$(mediainfo --Output='Video;%BitRate/String%' "${SRC_FILE}" | sed 's/[^0-9]*//g')

  # Check audio channels and language
  unset input_audiostream_array
  input_audiostream_array+=( "$(ffprobe "${SRC_FILE}" -show_entries stream=index:stream_tags=language -select_streams a -v 0 -of compact=p=0:nk=1 2> /dev/null)" )
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
  if [ ${SRC_HEIGHT} == 480 ] && [[ ${SRC_BITRATE} -gt ${DST_STREAM_BITRATE_480} ]]; then
    ENCODE_ENABLED=1
  elif [ ${SRC_HEIGHT} == 720 ] && [[ ${SRC_BITRATE} -gt ${DST_STREAM_BITRATE_720} ]]; then
    ENCODE_ENABLED=1
  elif [ ${SRC_HEIGHT} == 1080 ] && [[ ${SRC_BITRATE} -gt ${DST_STREAM_BITRATE_1080} ]]; then
    ENCODE_ENABLED=1
  elif [ ${SRC_HEIGHT} == 2160 ] && [[ ${SRC_BITRATE} -gt ${DST_STREAM_BITRATE_2160} ]]; then
    ENCODE_ENABLED=1
  else
    ENCODE_ENABLED=0
  fi
  
  # Apply HDR encoding arg
  if [ ${ENCODE_HDR_CONTENT} == 0 ] && [ ${SRC_HDR} == 1 ]; then
    ENCODE_ENABLED=0
  fi

  # Check for: 1) 4K resize to 1080p; 2) SDR conversion
  if [ ${ENCODE_HDR_CONTENT} == 1 ] && [ ${CONVERT_HDR_TO_SDR} == 1 ] && [ ${SRC_HDR} == 1 ] && [[ "${SRC_CATEGORY}" == 'in_stream' || "${SRC_CATEGORY}" == 'in_unsorted' ]] && [ ${ENABLE_RESIZE_LIMIT} == 0 ]; then
    # SDR conversion only
    ENCODE_ENABLED=1
    ENCODE_STR="${IN_STREAM_ENCODE_ARG} ${SDR_FILTER}"
  elif [ ${ENCODE_HDR_CONTENT} == 1 ] && [ ${CONVERT_HDR_TO_SDR} == 1 ] && [ ${SRC_HDR} == 1 ] && [[ "${SRC_CATEGORY}" == 'in_stream' || "${SRC_CATEGORY}" == 'in_unsorted' ]] && [ ${ENABLE_RESIZE_LIMIT} == 1 ] && [ ${SRC_HEIGHT} -ge 1201 ]; then
    # SDR conversion & resize all 4K content
    ENCODE_ENABLED=1
    ENCODE_STR="${IN_STREAM_ENCODE_ARG} ${ENCODE_RESIZE_LIMIT} ${SDR_FILTER}"
  elif [[ ${CONVERT_HDR_TO_SDR} == 0 || ${SRC_HDR} == 0 ]] && [[ "${SRC_CATEGORY}" == 'in_stream' || "${SRC_CATEGORY}" == 'in_unsorted' ]] && [ ${ENABLE_RESIZE_LIMIT} == 1 ] && [ ${SRC_HEIGHT} -ge 1201 ]; then
    # Resize all 4k content
    ENCODE_ENABLED=1
    ENCODE_STR="${IN_STREAM_ENCODE_ARG} ${ENCODE_RESIZE_LIMIT}"
  fi
  
  #---- Write Queue job
  if [[ "${SRC_SIZE}" -gt "${SRC_STREAM_MIN_SIZE}" ]]; then
    # Create batch queue
    ARG1="${SRC_FILE}"
    ARG2="${ENCODER_FMT}${FORMAT_EXT}${HW_ENCODER}${NVIDIA_AQ}${MAIN_AUDIO}${ADD_AUDIO}${ENCODE_STR}"
    ARG3="${SRC_MID_DIR}"
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
    make_encoder_log
  fi
done< <( printf '%s\n' "${input_file_LIST[@]}" )
#-----------------------------------------------------------------------------------