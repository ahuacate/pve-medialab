#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_encoder_pre-processor.sh
# Description:  Creates video encoder arguments for encoder engine
# Usage:        All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# Parent:       'vidcoderr_watchdir.sh'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

#---- Hardware video encoders
# ( '0' none; '1' available )

# Initialize list array
hw_encoder_LIST=()

# Nvidia GPU
if [ "$NVIDIA_GPU_ARG" = 1 ]
then
  # Set Nvidia nvenc
  hw_encoder_LIST+=( "--nvenc" )
  # Set Nvidia temporal aq
  if [ "$NVIDIA_AQ_ARG" = 1 ] && [ "$HW_HEVC" = 1 ]
  then
    hw_encoder_LIST+=( "--nvenc-temporal-aq" )
  fi
fi

# Intel Quick Sync Video (qsv)
if [ "$INTEL_QSV_ARG" = 1 ]
then
  hw_encoder_LIST+=( "--qsv" )
fi

# AMD Video Coding Engine (amf)
if [ "$AMD_AMF_ARG" = 1 ]
then
  hw_encoder_LIST+=( "--amf" )
fi

# VA-API
if [ "$VAAPI_ARG" = 1 ]
then
  hw_encoder_LIST+=( "--vaapi" )
fi

# HEVC 10bit
if [ "$HW_HEVC" = 1 ]
then
  hw_encoder_LIST+=( "--hevc" )
fi

# hw_encoder string
if [ "${#hw_encoder_LIST[@]}" = 0 ]
then
  hw_encoder=""
else
  hw_encoder="$(printf "%s " "${hw_encoder_LIST[@]}")"
fi

#---- Software video encoders
# HEVC and H264 hardware encoding is the default when supported. 
# If hardware encoding is not available then software encoding is used.
# ( '0' none; '1' available )

# Initialize list array
sw_encoder_LIST=()

if [ "$HW_HEVC" = 0 ] && [ "$HW_H264" = 0 ]
then
  # x265 software HEVC
  if [ "$X265_ARG" = 1 ]
  then
    sw_encoder_LIST+=( "--x265" )
  fi

  # x264 software H.264
  if [ "$X264_ARG" = 1 ]
  then
    sw_encoder_LIST+=( "--x264" )
  elif [ "$X264_ARG" = 2 ]
  then
    sw_encoder_LIST+=( "--x264-avbr" )
  elif [ "$X264_ARG" = 3 ]
  then
    sw_encoder_LIST+=( "--x264-quick" )
  elif [ "$X264_ARG" = 4 ]
  then
    sw_encoder_LIST+=( "--x264-avbr --x264-quick" )
  fi
fi

# sw_encoder string
if [ "${#sw_encoder_LIST[@]}" = 0 ]
then
  sw_encoder=""
else
  sw_encoder="$(printf "%s " "${sw_encoder_LIST[@]}")"
fi

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Create encoder input args

# 1=src_mid_path; 2=dst_path; 3=src_path; 4=label; 5=file size; 6=file name; 7=full file path; 8=encode_str; 9=file epochtime; 10=file date & time
while IFS=';' read -r var1 var2 var3 var4 var5 var6 var7 var8 var9 var10
do
  # Set vars
  src_mid_path="$var1"
  dst_path="$var2"
  src_path="$var3"
  label="$var4"
  file_size="$var5"
  filename="$var6"
  src_file="$var7"
  encode_str="$var8"
  epochtime="$var9"
  date_time="$var10"

  # Set DST filename & type
  if [[ "$(echo "${filename##*.}")" == 'mkv' ]]
  then
    format_ext='--mp4 '
    encode_output_filename="$(echo "$filename" | sed 's/\(.[a-z0-9]*$\)/\.mp4/')"
    encode_output_filename_ext='mp4'
  else
    format_ext=""
    encode_output_filename="$(echo "$filename" | sed 's/\(.[a-z0-9]*$\)/\.mkv/')"
    encode_output_filename_ext='mkv'
  fi

  # Set SRC/DST filename short ( for alias searches )
  filename_short="$(echo "$filename" | sed -e 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed -e 's/ \.\([a-z0-9]*\)$/\.\1/' | sed -e 's/\(.[a-z0-9]*$\)//')"


  #---- Video stream settings

  # Check for HDR source video
  colors=$(ffprobe -show_streams -v error "$src_file" 2> /dev/null | egrep "^color_transfer|^color_space=|^color_primaries=" | head -3)
  for C in $colors
  do
    if [[ "$C" = "color_space="* ]]
    then
      colorspace=${C##*=}
    elif [[ "$C" = "color_transfer="* ]]
    then
      colortransfer=${C##*=}
    elif [[ "$C" = "color_primaries="* ]]
    then
      colorprimaries=${C##*=}
    fi
  done
  if [ "$colorspace" = "bt2020nc" ] && [ "$colortransfer" = "smpte2084" ] && [ "$colorprimaries" = "bt2020" ]
  then
    src_hdr=1
  else
    src_hdr=0
  fi

  # Check SRC video codec
  src_codec=$(mediainfo --Inform="Video;%Format%" "$src_file")

  # Check SRC video height
  src_height_var=$(mediainfo --Inform="Video;%Height%" "$src_file" | sed 's/[^0-9]*//g')
  if [[ "$src_height_var" -ge 1 ]] && [[ "$src_height_var" -le 660 ]]
  then
    src_height=480
  elif [[ "$src_height_var" -ge 661 ]] && [[ "$src_height_var" -le 890 ]]
  then
    src_height=720
  elif [[ "$src_height_var" -ge 891 ]] && [[ "$src_height_var" -le 1200 ]]
  then
    src_height=1080
  elif [[ "$src_height_var" -ge 1201 ]]
  then
    src_height=2160
  fi

  # Check SRC bitrate
  src_bitrate=$(mediainfo --Output='Video;%BitRate/String%' "$src_file" | sed 's/[^0-9]*//g')

  # Check audio channels and language
  input_audiostream_array=()
  input_audiostream_array+=( "$(ffprobe "$src_file" -show_entries stream=index:stream_tags=language -select_streams a -v 0 -of compact=p=0:nk=1 2> /dev/null)" )
  if [ $(echo ${input_audiostream_array[*]} | grep -w ".*${LANG_DEFAULT}.*" > /dev/null; echo $?) = 0 ]
  then
    while IFS='|' read -r index lang
    do
      if [ "$index" = 1 ] && [ "$lang" = "$LANG_DEFAULT" ]
      then
        main_audio="--main-audio 1=${DST_STREAM_AUDIO_CHANNELS} "
        add_audio=""
        break
      elif [ ! "$index" = 1 ] && [ "$lang" = "$LANG_DEFAULT" ]
      then
        main_audio="--main-audio 1=${DST_STREAM_AUDIO_CHANNELS} "
        add_audio="--add-audio ${index}=${DST_STREAM_AUDIO_CHANNELS} "
        break
      fi
    done < <( printf '%s\n' "${input_audiostream_array[@]}" )
  else
    main_audio="--main-audio 1=${DST_STREAM_AUDIO_CHANNELS} "
    add_audio=""
  fi

  #---- Encode Status - encode, passthru or ignore file

  # Check SRC bitrate
  if [ "$src_height" = 480 ] && [[ "$src_bitrate" -gt "$DST_STREAM_BITRATE_480" ]]
  then
    encode_enabled=1
  elif [ "$src_height" = 720 ] && [[ "$src_bitrate" -gt "$DST_STREAM_BITRATE_720" ]]
  then
    encode_enabled=1
  elif [ "$src_height" = 1080 ] && [[ "$src_bitrate" -gt "$DST_STREAM_BITRATE_1080" ]]
  then
    encode_enabled=1
  elif [ "$src_height" = 2160 ] && [[ "$src_bitrate" -gt "$DST_STREAM_BITRATE_2160" ]]
  then
    encode_enabled=1
  else
    encode_enabled=0
  fi

  # Set HDR encoding arg
  # Applied to label 'in_stream' and 'in_unsorted' only
  if [ "$ENCODE_HDR_CONTENT" = 0 ] && [ "$src_hdr" = 1 ] && [[ "$label" == 'in_stream' || "$label" == 'in_unsorted' ]]
  then
    encode_enabled=0
  fi


  # Here we construct the encoder string from the vidcoderr.ini variables.
  # Label 'in_stream' and 'in_unsorted' are processed differently to 'in_homevideo'.

  # Initialize list array
  encode_str_LIST=()

  # Label Category - 'in_stream' and 'in_unsorted'
  if [[ "$label" == 'in_stream' || "$label" == 'in_unsorted' ]]
  then
    # Set default label category args
    encode_str_LIST+=( "$IN_STREAM_ENCODE_ARG" )

    # Resize video
    if [ "$ENABLE_RESIZE_LIMIT" = 1 ]
    then
      encode_str_LIST+=( "$ENCODE_RESIZE_LIMIT" )
    fi

    # HDR-in and convert to SDR enabled
    if [ "$src_hdr" = 1 ] && [ "$CONVERT_HDR_TO_SDR" = 1 ]
    then
      encode_str_LIST+=( "$SDR_FILTER" )
    fi

    # Final $encode_str
    encode_str="$(printf "%s " "${encode_str_LIST[@]}")"
  fi

  # Home videos (autoadd - 'in_homevideo') are encoded to achieve the
  # highest quality with no perceptible loss in visual quality.
  # Your main Vidcoderr settings are overridden. Home videos will be encoded
  # using the x265 10bit encoder. Settings can be manually overridden in
  # the vicoderr.ini file.

  # Label Category - 'in_homevideo'
  if [ "$label" = 'in_homevideo' ]
  then
    # Set default label category args
    encode_str_LIST+=( "$IN_HOMEVIDEO_ENCODE_ARG" )

    # Resize video
    if [ "$ENABLE_RESIZE_LIMIT" = 1 ]
    then
      encode_str_LIST+=( "$ENCODE_RESIZE_LIMIT" )
    fi

    # HDR-in and convert to SDR enabled
    if [ "$src_hdr" = 1 ] && [ "$CONVERT_HDR_TO_SDR" = 1 ]
    then
      encode_str_LIST+=( "$SDR_FILTER" )
    fi

    # Final $encode_str
    encode_str="$(printf "%s " "${encode_str_LIST[@]}")"

    # Set SW encoder - override
    sw_encoder="$HV_SW_ENCODER "

    # Set HW encoder - override
    hw_encoder="$HV_HW_ENCODER "

    # Set Nvidia AQ off
    NVIDIA_AQ=""

    # Force encode on
    encode_enabled=1
  fi


  #---- Write Queue job

  if [[ "$file_size" -gt "$SRC_STREAM_MIN_SIZE" ]]
  then
    # Create batch queue
    arg1="$src_file"
    arg2="${sw_encoder}${format_ext}${hw_encoder}${NVIDIA_AQ}${main_audio}${add_audio}${encode_str}"
    arg3="$src_mid_path"
    arg4="$label"
    arg5="$encode_output_filename"
    arg6="$dst_path"
    arg7="$encode_enabled"
    echo "$arg1;$arg2;$arg3;$arg4;$arg5;$arg6;$arg7" >> $QUEUE_FILE

    # Make log entry
    make_log "Sent to encoder processor queue file."
  fi
done < <( printf '%s\n' "${input_file_LIST[@]}" )


#---- Run Vidcoderr ( other-transcode )
sleep 1
if ! [[ $(pgrep -fl "vidcoderr_encoder_processor.sh") ]]
then
  echo "Pre-processing complete"
  /usr/local/bin/vidcoderr/vidcoderr_encoder_processor.sh &
fi
#-----------------------------------------------------------------------------------