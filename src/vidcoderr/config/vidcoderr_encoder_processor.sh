#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_encoder_processor.sh
# Description:  Encode video queue file and post process to destination
# Usage:        All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# Parent:       'vidcoderr_watchdir.sh', 'vidcoderr_encoder_pre-processor.sh'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Read vidcoderr.ini file
source /usr/local/bin/vidcoderr/vidcoderr.ini

# Run list scripts
source $APP_HOME/vidcoderr_watchdir_list1.sh

# Check for queue file
if ! [ -f "$QUEUE_FILE" ]
then
  echo "Fail: ${QUEUE}Usage: $0 cmd ..."
  exit -1;
fi

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Test $QUEUE_FILE has a size greater than zero
while [ -s "$QUEUE_FILE" ]
do
# ---- Read queue file and set ARGS
  # Set encoder ARGS
  IFS=';' read -r arg1 arg2 arg3 arg4 arg5 arg6 arg7 <<< read line < $QUEUE_FILE
  src_file="$arg1"
  encode_args="$arg2"
  src_mid_path="$arg3"
  label="$arg4"
  encode_output_filename="$arg5"
  dst_path="$arg6"
  encode_enabled="$arg7"

  # Validate SRC file (delete queue if entry file missing)
  if ! [ -f "$src_file" ]
  then
    sed -i "1 d" $QUEUE_FILE
    continue
  fi


  #---- Encode enabled

  # Run Vidcoderr encoder and process files to destination
  if [ "$encode_enabled" = 1 ]
  then
    # Make encoder dir
    mkdir -p "$TRANSCODE_DIR/$label/$src_mid_path" # required for stream source media

    # Run Other-transcode
    cd "$TRANSCODE_DIR/$label/$src_mid_path" && other-transcode ${encode_args} "$src_file"
    sleep 5


    #---- Post-process encoded files
    # Here we rename and move the encoded files and all associated files (.srt, sub etc)
    # to their preset destination

    # Chg to transcode dir
    cd "$TRANSCODE_DIR"

    # Create and set video meta
    video_codec=$(mediainfo --Inform="Video;%Format%" "$TRANSCODE_DIR/$label/$src_mid_path/$encode_output_filename")
    audio_codec=$(mediainfo --Inform="Audio;%Format%" "$TRANSCODE_DIR/$label/$src_mid_path/$encode_output_filename" | sed 's/[-]//g')
    audio_channels=$(ffprobe -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 "$TRANSCODE_DIR/$label/$src_mid_path/$encode_output_filename" 2> /dev/null)
    height_var=$(mediainfo --Inform="Video;%Height%" "$TRANSCODE_DIR/$label/$src_mid_path/$encode_output_filename")
    if [ "$height_var" -ge 1 ] && [ "$height_var" -le 400 ]
    then
      video_res='LOW Q'
    elif [ "$height_var" -ge 401 ] && [ "$height_var" -le 660 ]
    then
      video_res='480p'
    elif [ "$height_var" -ge 661 ] && [ "$height_var" -le 890 ]
    then
      video_res='720p'
    elif [ "$height_var" -ge 891 ] && [ "$height_var" -le 1200 ]
    then
      video_res='1080p'
    elif [ "$height_var" -ge 1201 ] && [ "$height_var" -le 1440 ]
    then
      video_res='1440p'
    elif [ "$height_var" -ge 1441 ]
    then
      video_res='2160p'
    fi
    # Set video meta string
    dst_video_meta="[$video_res, $video_codec, $audio_codec, ${audio_channels^}]"

    # New video file name extension
    encode_output_filename_ext="${encode_output_filename##*.}"

    # Short version of new video file (no extension, strip video meta square brackets and any trailing [\s.-])
    # Capture imdbid or tmdbid between square brackets if they exist
    if [[ "$encode_output_filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]]
    then
      id_string="${BASH_REMATCH[0]}"
    else
      id_string=""
    fi

    # Short output name - series
    if [[ "$encode_output_filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]]
    then
      encode_output_filename_short=$(echo "$encode_output_filename" | sed -E 's/([sS][0-9]{2}[eE][0-9]{2}).*/\1/')
    # Short output name - movies (with id string)
    elif ! [[ "$encode_output_filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]] && \
    [[ "$encode_output_filename" =~ .*(\([0-9]{4}\)).* ]] && \
    [[ "$encode_output_filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]]
    then
      encode_output_filename_short=$(echo "${encode_output_filename%.*}" | sed -E 's/(\{(imdb|tmdb|tvdb|tvmaze)[^}]*\}|\[(imdb|tmdb|tvdb|tvmaze)[^]]*\]).*/\1/')
    # Short output name - movies (without id string)
    elif ! [[ "$encode_output_filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]] && \
    ! [[ "$encode_output_filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]] && \
    [[ "$encode_output_filename" =~ .*(\([0-9]{4}\)).* ]]
    then
      encode_output_filename_short=$(echo "$encode_output_filename" | sed -E 's/(\([0-9]{4}\)).*/\1/')
    else
    # Other unknown names
    encode_output_filename_short=$(echo "${encode_output_filename%.*}")
    fi

    # Set filename meta separator (fs) (- or . or _)
    if [ -n "$id_string" ]
    then
      # id string - yes
      separator_counts=$(echo "${encode_output_filename%.*}" | sed "s/$(echo "$id_string" | sed 's/[][]/\\&/g')//g" | grep -oE '[_\.-]' | sort | uniq -c)
    else
      # id string - no
      separator_counts=$(echo "${encode_output_filename%.*}" | grep -oE '[_\.-]' | sort | uniq -c)
    fi
    if [[ -n "$separator_counts" ]]
    then
      # Get the separator with the highest count
      fs=$(echo "$separator_counts" | awk '{print $2}' | head -n 1)
    else
      fs="-" # Default to "-"
    fi

    # Check for subtitle files in src dir
    while read line
    do
      # Check $line file name meets criteria (subtitle file and not '/mnt/transcode')
      if [[ "$line" =~ ^$TRANSCODE_DIR/* ]] || ! [[ "${line##*.}" =~ ^($subtitle_format_filter_regex)$ ]]
      then
        continue
      fi

      # Copy video file matching subtitle file to transcode dir
      if [[ "${line##*.}" =~ ^($subtitle_format_filter_regex)$ ]]
      then
        cp "$line" "$TRANSCODE_DIR/$label/$src_mid_path/" 2> /dev/null
      fi
    done < <( find "$(dirname "$src_file")" -type f -name "$(printf "%q" "$(basename "${encode_output_filename%.*}")")*" ! -name "$(printf "%q" "$(basename "${src_file}")")*" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex2).*" -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" )

    # Read the encoded transcode files, rename and move to destination
    while read line
    do
      # Check $line file name meets criteria (video or subtitle file)
      if [[ ! "${line##*.}" =~ ^($video_format_filter_regex)$ ]] && [[ ! "${line##*.}" =~ ^($subtitle_format_filter_regex)$ ]]
      then
        continue
      fi

      # Rename new video file & move
      if [ "$(basename "$line")" == "$encode_output_filename" ]
      then
        # Rename new video file
        dst_filename="$encode_output_filename_short $fs $dst_video_meta.$encode_output_filename_ext"
        mv "$TRANSCODE_DIR/$label/$src_mid_path/$encode_output_filename" "$TRANSCODE_DIR/$label/$src_mid_path/$dst_filename"

        # Move new video file to destination
        rsync --remove-source-files --relative "$TRANSCODE_DIR/$label/./$src_mid_path/$dst_filename" "$dst_path"
      fi

      # Rename subtitle file
      if [[ "${line##*.}" =~ ^($subtitle_format_filter_regex)$ ]]
      then
        # Extract language code
        if [[ "$(basename "$line")" =~ \.([a-z]{2,3})\.[^.]+$ ]]
        then
          # Extract language code
          language=${BASH_REMATCH[1]}

          # Lookup default vidcoderr.ini language and if match rename the subtitle file
          if [[ "${LANG_DEFAULT:0:2}" == "${language:0:2}" || "${LANG_DEFAULT:0:3}" == "${language:0:3}" ]]
          then
            # Rename file - default language code
            dst_filename="$encode_output_filename_short $fs $dst_video_meta.$LANG_DEFAULT.${line##*.}"
            mv "$line" "$TRANSCODE_DIR/$label/$src_mid_path/$dst_filename" 2>/dev/null

            # Move subtitle file to destination
            rsync --remove-source-files --relative "$TRANSCODE_DIR/$label/./$src_mid_path/$dst_filename" "$dst_path"
          else
            # Rename file - extracted lang code
            dst_filename="$encode_output_filename_short $fs $dst_video_meta.$language.${line##*.}"
            mv "$line" "$TRANSCODE_DIR/$label/$src_mid_path/$dst_filename" 2>/dev/null

            # Move subtitle file to destination
            rsync --remove-source-files --relative "$TRANSCODE_DIR/$label/./$src_mid_path/$dst_filename" "$dst_path"
          fi
        else
          # Detect language
          # Here we use translation SW to detect the subtitle language
          sleep 5
          language=$(trans -id "$(cat "$line" | sed '10,100!d' | sed '/^$/d' | sed '/^[0-9\<\-]/d' | awk '{ if ( length > x ) { x = length; y = $0 } }END{ print y }')" | grep -i 'ISO 639-3' | awk '{print $NF}')
          # If language code cannot be determine set to 'eng' code
          if [[ $? != 0 ]]
          then
            language='eng'
          fi
          # Rename file - extracted lang code
          dst_filename="$encode_output_filename_short $fs $dst_video_meta.$language.${line##*.}"
          mv "$line" "$TRANSCODE_DIR/$label/$src_mid_path/$dst_filename" 2>/dev/null
          # Move subtitle file to destination
          rsync --remove-source-files --relative "$TRANSCODE_DIR/$label/./$src_mid_path/$dst_filename" "$dst_path"
        fi
      fi

      # Delete old processed files
      if [ -f "$line" ]
      then
        rm -f "$line" >/dev/null 2>&1
      fi
    done < <( find "$TRANSCODE_DIR/$label/$src_mid_path" -type f -name "$(printf "%q" "$(basename "${encode_output_filename%.*}")")*" ! -name "$(printf "%q" "$(basename "${src_file}")")*" -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex2).*" -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" )


    #---- Cleanup

    # Delete all files matching filename of job file name
    find "$TRANSCODE_DIR" -type f -name "$(printf "%q" "$(basename "${encode_output_filename_short%.*}")")*" -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex1).*" -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" -delete 2> /dev/null
  fi


  #---- Encode disabled ( pass thru )
  # Here we rename and move the file which required no encoding and all
  # associated files (.srt, sub etc) to their preset destination

  if [ "$encode_enabled" = 0 ]
  then
    # Create and set video meta
    video_codec=$(mediainfo --Inform="Video;%Format%" "$src_file")
    audio_codec=$(mediainfo --Inform="Audio;%Format%" "$src_file" | sed 's/[-]//g')
    audio_channels=$(ffprobe -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 "$src_file" 2> /dev/null)
    height_var=$(mediainfo --Inform="Video;%Height%" "$src_file")
    if [ "$height_var" -ge 1 ] && [ "$height_var" -le 400 ]
    then
      video_res='LOW Q'
    elif [ "$height_var" -ge 401 ] && [ "$height_var" -le 660 ]
    then
      video_res='480p'
    elif [ "$height_var" -ge 661 ] && [ "$height_var" -le 890 ]
    then
      video_res='720p'
    elif [ "$height_var" -ge 891 ] && [ "$height_var" -le 1200 ]
    then
      video_res='1080p'
    elif [ "$height_var" -ge 1201 ] && [ "$height_var" -le 1440 ]
    then
      video_res='1440p'
    elif [ "$height_var" -ge 1441 ]
    then
      video_res='2160p'
    fi

    # Set video meta string
    dst_video_meta="[$video_res, $video_codec, $audio_codec, ${audio_channels^}]"

    # Passthru video file name extension
    passthru_src_filename_ext="${src_file##*.}"

    # Passthru video src filename
    passthru_src_filename="$(basename "$src_file")"

    # Short version of new video file (no extension, strip video meta square brackets and any trailing [\s.-])
    # Capture imdbid or tmdbid between square brackets if they exist
    if [[ "$passthru_src_filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]]
    then
      id_string="${BASH_REMATCH[0]}"
    else
      id_string=""
    fi

    # Short output name - series
    if [[ "$passthru_src_filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]]
    then
      passthru_output_filename_short=$(echo "$passthru_src_filename" | sed -E 's/([sS][0-9]{2}[eE][0-9]{2}).*/\1/')
    # Short output name - movies (with id string)
    elif ! [[ "$passthru_src_filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]] && \
    [[ "$passthru_src_filename" =~ .*(\([0-9]{4}\)).* ]] && \
    [[ "$passthru_src_filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]]
    then
      passthru_output_filename_short=$(echo "${passthru_src_filename%.*}" | sed -E 's/(\{(imdb|tmdb|tvdb|tvmaze)[^}]*\}|\[(imdb|tmdb|tvdb|tvmaze)[^]]*\]).*/\1/')
    # Short output name - movies (without id string)
    elif ! [[ "$passthru_src_filename" =~ .*([Ss][0-9]{2}[Ee][0-9]{2}).* ]] && \
    ! [[ "$passthru_src_filename" =~ [\[{](imdb|tmdb|tvdb|tvmaze)[^\]}]*[\]}] ]] && \
    [[ "$passthru_src_filename" =~ .*(\([0-9]{4}\)).* ]]
    then
      passthru_output_filename_short=$(echo "$passthru_src_filename" | sed -E 's/(\([0-9]{4}\)).*/\1/')
    else
    # Other unknown names
      passthru_output_filename_short=$(echo "${passthru_src_filename%.*}")
    fi

    # Set filename meta separator (fs) (- or . or _)
    if [ -n "$id_string" ]
    then
      # id string - yes
      separator_counts=$(echo "${passthru_src_filename%.*}" | sed "s/$(echo "$id_string" | sed 's/[][]/\\&/g')//g" | grep -oE '[_\.-]' | sort | uniq -c)
    else
      # id string - no
      separator_counts=$(echo "${passthru_src_filename%.*}" | grep -oE '[_\.-]' | sort | uniq -c)
    fi
    if [[ -n "$separator_counts" ]]
    then
      # Get the separator with the highest count
      fs=$(echo "$separator_counts" | awk '{print $2}' | head -n 1)
    else
      fs="-" # Default to "-"
    fi

    # Read the pass thru files, rename and move to destination
    while read line
    do
      # Check $line file name meets criteria (video or subtitle file)
      if [[ ! "${line##*.}" =~ ^($video_format_filter_regex)$ ]] && [[ ! "${line##*.}" =~ ^($subtitle_format_filter_regex)$ ]]
      then
        continue
      fi

      # Rename pass thru video file
      if [ "$(basename "$line")" == "$passthru_src_filename" ]
      then
        # Create pass thru video filename
        dst_filename="$passthru_output_filename_short $fs $dst_video_meta.$passthru_src_filename_ext"
        # mv "$TRANSCODE_DIR/$label/$src_mid_path/$encode_output_filename" "$TRANSCODE_DIR/$label/$src_mid_path/$dst_filename" 2>/dev/null

        # Copy video file to destination
        mkdir -p "$dst_path/$src_mid_path"
        cp "$line" "$dst_path/$src_mid_path/$dst_filename"
        # rsync --remove-source-files --relative "$TRANSCODE_DIR/$label/./$src_mid_path/$dst_filename" "$dst_path"
      fi

      # Rename subtitle file
      if [[ "${line##*.}" =~ ^($subtitle_format_filter_regex)$ ]]
      then
        # Extract language code
        if [[ "$(basename "$line")" =~ \.([a-z]{2,3})\.[^.]+$ ]]
        then
          # Extract language code
          language=${BASH_REMATCH[1]}

          # Lookup default vidcoderr.ini language and if match rename the subtitle file
          if [[ "${LANG_DEFAULT:0:2}" == "${language:0:2}" || "${LANG_DEFAULT:0:3}" == "${language:0:3}" ]]
          then
            # Rename file - default language code
            dst_filename="$passthru_output_filename_short $fs $dst_video_meta.$LANG_DEFAULT.${line##*.}"

            # Copy subtitle file to destination
            mkdir -p "$dst_path/$src_mid_path"
            cp "$line" "$dst_path/$src_mid_path/$dst_filename"
          else
            # Rename file - extracted lang code
            dst_filename="$passthru_output_filename_short $fs $dst_video_meta.$language.${line##*.}"

            # Move subtitle file to destination
            mkdir -p "$dst_path/$src_mid_path"
            cp "$line" "$dst_path/$src_mid_path/$dst_filename"
          fi
        else
          # Detect language
          # Here we use tans SW to attempt to detect the subtitle language
          sleep 5
          language=$(trans -id "$(cat "$line" | sed '10,100!d' | sed '/^$/d' | sed '/^[0-9\<\-]/d' | awk '{ if ( length > x ) { x = length; y = $0 } }END{ print y }')" | grep -i 'ISO 639-3' | awk '{print $NF}')
          # If language code cannot be determine set to 'eng' code
          if [[ $? != 0 ]]
          then
            language='eng'
          fi
            # Rename file - extracted lang code
            dst_filename="$passthru_output_filename_short $fs $dst_video_meta.$language.${line##*.}"

            # Move subtitle file to destination
            mkdir -p "$dst_path/$src_mid_path"
            cp "$line" "$dst_path/$src_mid_path/$dst_filename"
        fi
      fi
    done < <( find "$(dirname "$src_file")" -type f -name "$(printf "%q" "$(basename "${src_file%.*}")")*" -regextype posix-extended -not -iregex ".*($exclude_dir_filter_regex1).*" -regextype posix-extended -not -iregex ".*($exclude_file_filter_regex)$" )
  fi


  #---- Finish Stage

  # Delete empty folders from transcode folder
  find "$TRANSCODE_DIR" -mindepth 1 -type d -empty -regextype posix-extended -not -iregex ".*/($exclude_dir_filter_regex1).*" -exec rmdir "{}" \; >/dev/null 2>&1

  # Delete finished queue line from file $QUEUE_FILE
  sed -i "1 d" $QUEUE_FILE

  # Throttle time before next queue check
  sleep 15
done
#-----------------------------------------------------------------------------------