#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_encoder.sh
# Description:  Encode queue file for Vidcoderr
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Read vidcoderr.ini file
source /usr/local/bin/vidcoderr/vidcoderr.ini

# Check for queue file
if ! [ -f "$QUEUE_FILE" ]
then
  echo "Fail: ${QUEUE}Usage: $0 cmd ..."
  exit -1;
fi

#---- Static Variables -------------------------------------------------------------

OTHER_EXT_FILTER=$(cat $APP_HOME/other_format_filter.txt | sed -e '/log$/d' | sed '/^$/d')

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

while [ -s "$QUEUE_FILE "]
do
# ---- Read queue file and set ARGS
  # Set encoder ARGS
  IFS=';' read -r ARG1 ARG2 ARG3 ARG4 ARG5 ARG6 ARG7 <<< read line < ${QUEUE_FILE}
  SRC_FILE="$ARG1"
  ENCODE_ARGS="$ARG2"
  SRC_MID_DIR="$ARG3"
  SRC_CATEGORY="$ARG4"
  ENCODE_OUTPUT_FILENAME="$ARG5"
  DST_DIR="$ARG6"
  ENCODE_ENABLED="$ARG7"

  # Validate SRC file ( delete queue entry if not valid)
  if ! [ -f "$SRC_FILE" ]
  then
    sed -i "1 d" $QUEUE_FILE
    continue
  fi

  #---- Encode enabled
  if [ "$ENCODE_ENABLED" = '1' ]
  then
    # Make encoder dir
    mkdir -p "$TRANSCODE_DIR/$SRC_CATEGORY/$SRC_MID_DIR" # required for stream source media

    # Run Other-transcode
    cd "$TRANSCODE_DIR/$SRC_CATEGORY/$SRC_MID_DIR" && other-transcode ${ENCODE_ARGS} "$SRC_FILE"
    sleep 1

    #---- Post-process encoded files
    cd "$TRANSCODE_DIR"
    # DST Video filename
    ENCODE_OUTPUT_FILENAME_EXT="${ENCODE_OUTPUT_FILENAME##*.}"
    # ENCODE_OUTPUT_FILENAME_SHORT="$(echo ${ENCODE_OUTPUT_FILENAME} | sed -e 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed -e 's/ \.\([a-z0-9]*\)$/\.\1/' | sed -e 's/\(.[a-z0-9]*$\)//')"
    ENCODE_OUTPUT_FILENAME_SHORT="$(echo "$ENCODE_OUTPUT_FILENAME" | sed -e 's/\(.[a-z0-9]*$\)//' | sed 's/\(.*\)\[.*\]/\1/')"

    # Delete old matching files from destination folder
    rm -r -f "${DST_DIR}${SRC_MID_DIR}${ENCODE_OUTPUT_FILENAME_SHORT}"* &>/dev/null

    # Video meta
    VIDEO_CODEC=$(mediainfo --Inform="Video;%Format%" "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${ENCODE_OUTPUT_FILENAME}")
    AUDIO_CODEC=$(mediainfo --Inform="Audio;%Format%" "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${ENCODE_OUTPUT_FILENAME}" | sed 's/[-]//g')
    AUDIO_CHANNELS=$(ffprobe -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${ENCODE_OUTPUT_FILENAME}" 2> /dev/null)
    HEIGHT_VAR=$(mediainfo --Inform="Video;%Height%" "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${ENCODE_OUTPUT_FILENAME}")
    if [[ "${HEIGHT_VAR}" -ge 1 ]] && [[ "${HEIGHT_VAR}" -le 400 ]]; then
      VIDEO_RES='LOW Q'
    elif [[ "${HEIGHT_VAR}" -ge 401 ]] && [[ "${HEIGHT_VAR}" -le 660 ]]; then
      VIDEO_RES='480p'
    elif [[ "${HEIGHT_VAR}" -ge 661 ]] && [[ "${HEIGHT_VAR}" -le 890 ]]; then
      VIDEO_RES=='720p'
    elif [[ "${HEIGHT_VAR}" -ge 891 ]] && [[ "${HEIGHT_VAR}" -le 1200 ]]; then
      VIDEO_RES='1080p'
    elif [[ "${HEIGHT_VAR}" -ge 1201 ]] && [[ "${HEIGHT_VAR}" -le 1440 ]]; then
      VIDEO_RES='1440p'
    elif [[ "${HEIGHT_VAR}" -ge 1441 ]]; then
      VIDEO_RES='2160p'
    fi

    DST_VIDEO_META="[${VIDEO_RES} ${VIDEO_CODEC} ${AUDIO_CODEC} ${AUDIO_CHANNELS^}]"

    # Rename and move files
    while read line; do
      if [[ $line == "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${ENCODE_OUTPUT_FILENAME}" ]]; then
        # Rename video file
        DST_FILENAME="$(echo ${ENCODE_OUTPUT_FILENAME_SHORT} ${DST_VIDEO_META}.${ENCODE_OUTPUT_FILENAME_EXT})"
        mv "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${ENCODE_OUTPUT_FILENAME}" "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${DST_FILENAME}" 2>/dev/null
        # Move video file to destination
        rsync --remove-source-files --relative "$TRANSCODE_DIR/$SRC_CATEGORY/./${SRC_MID_DIR}${DST_FILENAME}" "${DST_DIR}"
      elif [[ "${OTHER_EXT_FILTER[*]}" =~ "${line##*.}" ]]; then
        # Detect subtitle language
        if [ $(echo $line | awk -F'.' '{print $(NF-1)}') == eng ] || [ $(echo $line | awk -F'.' '{print $(NF-1)}') == en ]; then
          # Rename file
          DST_FILENAME="$(echo ${ENCODE_OUTPUT_FILENAME_SHORT} ${DST_VIDEO_META}.eng.${line##*.})"
          mv "${line}" "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${DST_FILENAME}" 2>/dev/null
          # Move video file to destination
          rsync --remove-source-files --relative "$TRANSCODE_DIR/$SRC_CATEGORY/./${SRC_MID_DIR}${DST_FILENAME}" "${DST_DIR}"
        else
          # Detect language
          sleep 5
          LANGS=$(trans -id "$(cat ${line} | sed '10,100!d' | sed '/^$/d' | sed '/^[0-9\<\-]/d' | awk '{ if ( length > x ) { x = length; y = $0 } }END{ print y }')" | grep -i 'ISO 639-3' | awk '{print $NF}')
          if [[ $? != 0 ]]; then
            LANGS='eng'
          fi
          # Rename file
          DST_FILENAME="$(echo ${ENCODE_OUTPUT_FILENAME_SHORT} ${DST_VIDEO_META}.${LANGS}.${line##*.})"
          mv "${line}" "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${DST_FILENAME}" 2>/dev/null
          # Move video file to destination
          rsync --remove-source-files --relative "$TRANSCODE_DIR/$SRC_CATEGORY/./${SRC_MID_DIR}${DST_FILENAME}" "${DST_DIR}"
        fi
      fi
      # Delete old files
      rm "${line}" &> /dev/null
    done < <( ls "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${ENCODE_OUTPUT_FILENAME_SHORT}"* )

    # Delete empty folders from base encoder folder
    cd ${TRANSCODE_DIR} && find . -empty -type d -delete 2>/dev/null
  fi

  #---- Encode disabled ( pass thru )
  if [ ${ENCODE_ENABLED} == '0' ]; then
    # Video meta
    VIDEO_CODEC=$(mediainfo --Inform="Video;%Format%" "${SRC_FILE}")
    AUDIO_CODEC=$(mediainfo --Inform="Audio;%Format%" "${SRC_FILE}" | sed 's/[-]//g')
    AUDIO_CHANNELS=$(ffprobe -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 "${SRC_FILE}" 2> /dev/null)

    HEIGHT_VAR=$(mediainfo --Inform="Video;%Height%" "${SRC_FILE}")
    if [[ "${HEIGHT_VAR}" -ge 1 ]] && [[ "${HEIGHT_VAR}" -le 400 ]]; then
      VIDEO_RES='LOW Q'
    elif [[ "${HEIGHT_VAR}" -ge 401 ]] && [[ "${HEIGHT_VAR}" -le 660 ]]; then
      VIDEO_RES='480p'
    elif [[ "${HEIGHT_VAR}" -ge 661 ]] && [[ "${HEIGHT_VAR}" -le 890 ]]; then
      VIDEO_RES='720p'
    elif [[ "${HEIGHT_VAR}" -ge 891 ]] && [[ "${HEIGHT_VAR}" -le 1200 ]]; then
      VIDEO_RES='1080p'
    elif [[ "${HEIGHT_VAR}" -ge 1201 ]] && [[ "${HEIGHT_VAR}" -le 1440 ]]; then
      VIDEO_RES='1440p'
    elif [[ "${HEIGHT_VAR}" -ge 1441 ]]; then
      VIDEO_RES='2160p'
    fi
    DST_VIDEO_META="[${VIDEO_RES} ${VIDEO_CODEC} ${AUDIO_CODEC} ${AUDIO_CHANNELS^}]"

    # PASS & DST Video filename
    if [[ "${SRC_MID_DIR}" ]]; then
      PASS_INPUT_PATH=$(echo "${SRC_FILE}" | sed "s|/${SRC_MID_DIR}.*$||")
    else
      PASS_INPUT_PATH=$(dirname "${SRC_FILE}")
    fi
    # PASS_INPUT_PATH=$(echo "${SRC_FILE}" | sed "s|/${SRC_MID_DIR}.*$||")
    PASS_INPUT_FILENAME=$(basename "${SRC_FILE}")
    PASS_INPUT_FILENAME_EXT="${SRC_FILE##*.}"
    PASS_INPUT_FILENAME_SHORT="$(echo ${SRC_FILE##*/} | sed -e 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed -e 's/ \.\([a-z0-9]*\)$/\.\1/' | sed -e 's/\(.[a-z0-9]*$\)//')"

    # Delete old matching files from destination folder
    rm -r -f "${DST_DIR}${SRC_MID_DIR}${PASS_INPUT_FILENAME_SHORT}"* &>/dev/null

    # Rename and move files
    while read -r line; do
      if [[ $line == "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${PASS_INPUT_FILENAME}" ]]; then
        # Rename video file
        DST_FILENAME="$(echo ${PASS_INPUT_FILENAME_SHORT} ${DST_VIDEO_META}.${PASS_INPUT_FILENAME_EXT})"
        mv "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${PASS_INPUT_FILENAME}" "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${DST_FILENAME}" 2>/dev/null
        # Move video file to destination
        rsync --remove-source-files --relative "$TRANSCODE_DIR/$SRC_CATEGORY/./${SRC_MID_DIR}${DST_FILENAME}" "${DST_DIR}"
      elif [[ $line == "${SRC_FILE}" ]] && [[ ! $line == "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${PASS_INPUT_FILENAME}" ]]; then
        # Move video file to destination
        rsync --relative "${PASS_INPUT_PATH}/./${SRC_MID_DIR}${PASS_INPUT_FILENAME}" "${DST_DIR}"
      elif [[ "${OTHER_EXT_FILTER[*]}" =~ "${line##*.}" ]]; then
        # Detect subtitle language
        if [ $(echo $line | awk -F'.' '{print $(NF-1)}') == eng ] || [ $(echo $line | awk -F'.' '{print $(NF-1)}') == en ]; then
          LANGS='eng'
        else
          # Detect language
          LANGS=$(trans -id "$(cat ${line} | sed '10,100!d' | sed '/^$/d' | sed '/^[0-9\<\-]/d' | awk '{ if ( length > x ) { x = length; y = $0 } }END{ print y }')" | grep -i 'ISO 639-3' | awk '{print $NF}')
          if [[ $? != 0 ]]; then
            LANGS='eng'
          fi
        fi
        # Move subtitle file to destination
        if [ $(echo ${line} | grep -w "^${TRANSCODE_DIR}/.*" > /dev/null; echo $?) == 0 ]; then
          # Rename file
          DST_FILENAME="$(echo ${PASS_INPUT_FILENAME_SHORT} ${DST_VIDEO_META}.${LANGS}.${line##*.})"
          mv "${line}" "$TRANSCODE_DIR/$SRC_CATEGORY/${SRC_MID_DIR}${DST_FILENAME}" 2>/dev/null
          # Move subtitle file to destination
          rsync --remove-source-files --relative "$TRANSCODE_DIR/$SRC_CATEGORY/./${SRC_MID_DIR}${DST_FILENAME}" "${DST_DIR}"
        else
          # Copy subtitle file to destination
          rsync --relative "${PASS_INPUT_PATH}/./${SRC_MID_DIR}$(basename "${line}")" "${DST_DIR}"
        fi
      fi
    done < <( ls "${PASS_INPUT_PATH}/${SRC_MID_DIR}${PASS_INPUT_FILENAME_SHORT}"* )
  fi

  # Delete empty folders from base encoder folder
  cd "${TRANSCODE_DIR}" && find . -empty -type d -delete 2>/dev/null

  # Delete finished queue line
  sed -i "1 d" ${QUEUE_FILE}

  # Throttle the check
  sleep 15
done
#-----------------------------------------------------------------------------------