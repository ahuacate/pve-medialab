#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_configbuilder.sh
# Description:  Source script for configuring Vidcoderr App
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Maximum bandwith/bitrate Mbps args (whole numbers only)
BW_SD='2'
BW_HD_STD='4'
BW_HD_PLUS='8'
BW_4K='15'
BW_4K_HDR='25'

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Pull CT vidocoderr.ini file
# pct pull $CTID /usr/local/bin/vidcoderr/vidcoderr.ini ${TEMP_DIR}/vidcoderr.ini

# Services to stop
services=( vidcoderr_watchdir_std.timer
  vidcoderr_watchdir_std.service
  vidcoderr_inotify_std.service
  SimpleHTTPServerWithUpload.service
)


# Stop and disable services
for service in "${services[@]}"
do
  if [ "$(pct exec $CTID -- systemctl is-active "$service")" = "active" ]
  then
    pct exec $CTID -- systemctl stop "$service"
    while ! [[ "$(pct exec $CTID -- systemctl is-active "$service")" == 'inactive' ]]
    do
      echo -n .
    done
    pct exec $CTID -- systemctl disable "$service" &> /dev/null
  fi
done


# Check Intel integrated graphics hardware
# iHD driver indicates support for the QSV and VA-API interfaces.
# i965 driver indicates only support for the VA-API interface, which should only be used on pre-Broadwell platforms.
# We use ffmpeg to test for hardware acceleration
if [[ $(lscpu | grep "Vendor ID:\s*GenuineIntel") ]] && \
[[ $(vainfo 2> /dev/null | grep -i -E "^vainfo:(\s)?Driver version:.*(i965|iHD)") ]]
then
  # Set CPU type
  cpu_type="intel"
  # Check if Intel QSV is available ( '0' none; '1' available )
  if [[ $(pct exec $CTID -- ffmpeg -hide_banner -hwaccels | grep qsv) ]]
  then
    intel_qsv_support=1
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" INTEL_QSV_ARG 1
  else
    intel_qsv_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" INTEL_QSV_ARG 0
  fi
  # Check if VA-API is available ( '0' none; '1' available )
  if [[ $(pct exec $CTID -- ffmpeg -hide_banner -hwaccels | grep vaapi) ]]
  then
    vaapi_support=1
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" VAAPI_ARG 1
  else
    vaapi_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" VAAPI_ARG 0
  fi
else
  intel_qsv_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" INTEL_QSV_ARG 0
fi

# Check AMD APU hardware
if [[ $(lscpu | grep "Vendor ID:\s*AuthenticAMD") ]] && \
[[ $(vainfo 2> /dev/null | grep -i -E "^vainfo:(\s)?Driver version:.*(Radeon|AMD)") ]]
then
  # Set CPU type
  cpu_type="amd"
  # Check if AMD VCE is available ( '0' none; '1' available )
  if [[ $(pct exec $CTID -- ffmpeg -hide_banner -hwaccels | grep amf) ]]
  then
    amd_amf_support=1
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" AMD_AMF_ARG 1
  else
    amd_amf_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" AMD_AMF_ARG 0
  fi
  # Check if VA-API is available ( '0' none; '1' available )
  if [[ $(pct exec $CTID -- ffmpeg -hide_banner -hwaccels | grep vaapi) ]]
  then
    vaapi_support=1
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" VAAPI_ARG 1
  else
    vaapi_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" VAAPI_ARG 0
  fi
else
  amd_amf_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" AMD_AMF_ARG 0
fi

# Check if Nvidia GPU is available ( '0' none; '1' available )
if [[ $(lspci | grep -i nvidia) ]] && \
[[ $(vainfo 2> /dev/null | grep -i -E "^vainfo:(\s)?Driver version:.*(nvidia|VDPAU|NVDEC)") ]]
then
  nvidia_support=1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_GPU_ARG 1
  # Check if AMD VCE is available ( '0' none; '1' available )
  if [[ $(pct exec $CTID -- ffmpeg -hide_banner -hwaccels | grep nvenc) ]]
  then
    nvenc_support=1
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_NVENC_ARG 1
  else
    nvenc_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_NVENC_ARG 0
  fi
  # Check if Nvidia AQ is supported
  if [[ $(pct exec $CTID -- ffmpeg -hide_banner -hwaccel cuvid -c:v h264_cuvid -v quiet -h264_flags +aq -i input.mp4 -f null - 2>&1 >/dev/null) ]]
  then
    nvidia_aq_support=1
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_AQ_ARG 1
  else
    nvidia_aq_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_AQ_ARG 0
  fi
  # Check if VA-API is available ( '0' none; '1' available )
  if [[ $(pct exec $CTID -- ffmpeg -hide_banner -hwaccels | grep vaapi) ]]
  then
    vaapi_support=1
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" VAAPI_ARG 1
  else
    vaapi_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" VAAPI_ARG 0
  fi
else
  nvidia_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_GPU_ARG 0
fi

# Check HEVC hardware encoding is supported
if [[ $(pct exec $CTID -- vainfo 2> /dev/null | grep -i VAProfileHEVC) ]]
then
  hevc_hardware_support=1
else
  hevc_hardware_support=0
fi

# Check H264 hardware encoding is supported
if [[ $(pct exec $CTID -- vainfo 2> /dev/null | grep -i VAProfileH264) ]]
then
  h264_hardware_support=1
else
  h264_hardware_support=0
fi


#---- Set Encoder CPU or GPU
# If two GPU options exist you must select one only. If only one GPU option exists
# this option is not valid.

if [ "$cpu_type" = 'intel' ] && [ "$nvidia_support" = 1 ]
then
  #### Chooese between Intel CPU or Nvidia GPU ####
  msg "Select an option from the menu:"
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" )
  OPTIONS_LABELS_INPUT=( "Intel on-board GPU" "Nvidia PCIe GPU" )
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  if [ "$RESULTS" = 'TYPE01' ]
  then
    # Set Intel encoder GPU
    nvidia_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_GPU_ARG 0
    nvenc_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_NVENC_ARG 0
    nvidia_aq_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_AQ_ARG 0
  elif [ "$RESULTS" = 'TYPE02' ]
  then
    # Set Nvidia encoder GPU
    intel_qsv_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" INTEL_QSV_ARG 0
  fi
elif [ "$cpu_type" = 'amd' ] && [ "$nvidia_support" = 1 ]
then
  #### Chooese between Intel CPU or Nvidia GPU ####
  msg "Select an option from the menu:"
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" )
  OPTIONS_LABELS_INPUT=( "AMD on-board GPU" "Nvidia PCIe GPU" )
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  if [ "$RESULTS" = 'TYPE01' ]
  then
    # Set Intel encoder GPU
    nvidia_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_GPU_ARG 0
    nvenc_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_NVENC_ARG 0
    nvidia_aq_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_AQ_ARG 0
  elif [ "$RESULTS" = 'TYPE02' ]
  then
    # Set Nvidia encoder GPU
    amd_amf_support=0
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" AMD_AMF_ARG 0
  fi
fi


#---- Configure Vidcoderr watch service

section "Watch folders"

# Select watch folders
# in_stream dir
unset display_msg1
while IFS=',' read -r label media_type src dst encode_str arg
do
  display_msg1+=( "$(echo $(if [ ${arg} == 1 ]; then printf "${GREEN}enabled${NC}"; else printf "${RED}disabled${NC}"; fi),${src},${dst})" )
done < <(pct exec $CTID -- cat /usr/local/bin/vidcoderr/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_IN_STREAM*|^INPUT_WATCH_IN_HOMEVIDEO|INPUT_WATCH_IN_UNSORTED' | sed 's/^.*=//')
# stream dir
unset display_msg2
while IFS=',' read -r label media_type src dst encode_str arg
do
  display_msg2+=( "$(echo $(if [ ${arg} == 1 ]; then printf "${GREEN}enabled${NC}"; else printf "${RED}disabled${NC}"; fi),${src},${dst})" )
done < <(pct exec $CTID -- cat /usr/local/bin/vidcoderr/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_STREAM_*' | sed 's/^.*=//')

msg_box "#### PLEASE READ CAREFULLY - WATCH FOLDERS ####\n
Vidcoderr comes with a default configuration that automatically watches all 'autoadd' folders located in the '/public/autoadd/vidcoderr/' directory. However, you can customize Vidcoderr to also monitor your main video libraries, such as movies, series, pron, and documentaries. Once the video is encoded, it will be saved in the corresponding '/video/stream/{documentary,movies,series,porn,series}' folder. Please keep in mind that the original input video files will remain unaltered."
printf '%s\n' "${display_msg1[@]}" | column -t -s "," -N "${WHITE}STATUS${NC},${WHITE}INPUT${NC},${WHITE}OUTPUT${NC}" | indent2
echo
msg "The User has the option to enable encoding of your main video library folders (default disabled).\n"
printf '%s\n' "${display_msg2[@]}" | column -t -s "," -N "${WHITE}STATUS${NC},${WHITE}INPUT${NC},${WHITE}OUTPUT${NC}" | indent2
echo

msg "Select the sources to enable from the menu:"
OPTIONS_LABELS_INPUT=$(pct exec $CTID -- cat /usr/local/bin/vidcoderr/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_STREAM_*' | sed 's/^.*=//' | awk -F ',' '{print $2, "--", $3}')
OPTIONS_VALUES_INPUT=$(pct exec $CTID -- cat /usr/local/bin/vidcoderr/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_STREAM_*' | awk -F '=' '{print $1}')
makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
multiselect SELECTED "$OPTIONS_STRING"
# Set src dir array
input_watch_stream_param_LIST=()
while read -r line
do
  # Check if pattern exists
  found=false
  for pattern in "${RESULTS[@]}"
  do
    # Enable stream encoding
    if [[ "$pattern" == "$line" ]]
    then
      found=true
      pct exec $CTID -- sed -i "/^$line/s/[0-9]$/1/" /usr/local/bin/vidcoderr/vidcoderr.ini
      break
    fi
  done

  # Disable stream encoding
  if [ "$found" = false ]
  then
    pct exec $CTID -- sed -i "/^$line/s/[0-9]$/0/" /usr/local/bin/vidcoderr/vidcoderr.ini
  fi
done < <( pct exec $CTID -- cat /usr/local/bin/vidcoderr/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_STREAM_*' | awk -F '=' '{print $1}' )


#---- Configure Vidcoderr encoder bandwidth

section "Encoder bandwidth"

# Set maximum stream bandwidth
msg_box "#### PLEASE READ CAREFULLY - ENCODER BANDWIDTH ####\n
You can set a maximum video encoder bitrate limit (Mbps) to restrict the output stream video file bitrate limit and file size. We recommend that you do not set a bitrate higher than 25-50% of your internet connection upload bandwidth limit. You should also consider the number of client devices and the slowest client's internet access bandwidth speed limit. A maximum bitrate setting ratio of 1:1 is applied to 4K 2160p video. A pro rata ratio is then applied to 1440p, 1080p, 720p down to 480p.

This setting does not affect 'home video' encodes. Home video encodes always use an optimum bitrate, so there is no noticeable quality difference from the input original file."

msg "Select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" )
OPTIONS_LABELS_INPUT=( "SD streaming - ${BW_SD} Mbps, low quality" "HD standard streaming - ${BW_HD_STD} Mbps" "HD plus streaming - ${BW_HD_PLUS} Mbps" "4K streaming - ${BW_4K} Mbps ( Recommended - Good quality balance)" "4K HDR streaming - ${BW_4K_HDR} Mbps" "None, leave at default 15 Mbps" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  # SD stream speed setting
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_MAXIMUM_BITRATE ${BW_SD}
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_SD}${NC} Mbps"
  echo
elif [ "$RESULTS" = 'TYPE02' ]
then
  # HD stream speed setting
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_MAXIMUM_BITRATE ${BW_HD_STD}
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_HD_STD}${NC} Mbps"
  echo
elif [ "$RESULTS" = 'TYPE03' ]
then
  # HD stream speed setting
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_MAXIMUM_BITRATE ${BW_HD_PLUS}
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_HD_PLUS}${NC} Mbps"
  echo
elif [ "$RESULTS" = 'TYPE04' ]
then
  # 4K stream speed setting
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_MAXIMUM_BITRATE ${BW_4K}
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_4K}${NC} Mbps"
  echo
elif [ "$RESULTS" = 'TYPE05' ]
then
  # 4K HDR stream speed setting
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_MAXIMUM_BITRATE ${BW_4K_HDR}
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_4K_HDR}${NC} Mbps"
  echo
elif [ "$RESULTS" = 'TYPE06' ]
then
  # None
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_MAXIMUM_BITRATE 15
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}15${NC} Mbps (default)"
  echo
fi


#---- Configure Vidcoderr 10bit option

section "Codec, bitrate and video resolution"

# Display msg2
display_msg2=()
display_msg2+=( "$(if [ "$hevc_hardware_support" = 1 ]; then echo "-- HEVC hardware support:yes:fast"; else echo "-- HEVC hardware support:no:n/a";fi)" )
display_msg2+=( "$(if [ "$h264_hardware_support" = 1 ]; then echo "-- H264 hardware support:yes:fast"; else echo "-- H264 hardware support:no:n/a";fi)" )
display_msg2+=( "-- x265 software support:yes:slow" "-- x264 software support:yes:slow" )

# Display msg1
if [ "$hevc_hardware_support" = 1 ]
then
display_msg1="Your hardware has the capability to support High Efficiency Video Coding (HEVC), also known as H.265, for video encoding. HEVC provides superior quality compared to H.264 because it reduces the risk of color banding and supports encoding of 4K high dynamic range (HDR) 10-bit video.

$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "ENCODER PROFILE,STATUS,SPEED" | indent2)

However, it's important to keep in mind that not all video player clients or displays are compatible with HEVC 10-bit or HEVC HDR. If played on unsupported displays, HDR video may appear washed out.

If you choose to use HEVC, you can either process 4K HDR video files and retain the HDR metadata, or you can transcode HDR to SDR using tone-mapping. The latter option can improve SDR display quality, but it is a slow process. Note that HDR to SDR tone-mapping requires a newer generation CPU due to its high CPU intensity.

Additionally, you have the option to resize your video to either 1080P or 720P or leave it as is.

x265 10bit is the preset default for all 'autoadd' home videos.

Finally, if your hardware does not support HEVC or H.264 encoding, software encoders in the x.265 or h.264 codec format are available. The speed of software-based encoding is dependent on your installed CPU model. x265 is of superior quality compared to x264."
elif [ "$hevc_hardware_support" = 0 ]
then
display_msg1="Your Vidcoderr hardware is not capable of supporting High Efficiency Video Coding (HEVC), also known as H.265, for video encoding. This means that hardware encoding to HEVC 8-bit, HEVC 10-bit, H.265, or 4K HDR is not possible. However, you still have a range of encoding options available:

$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "ENCODER PROFILE,STATUS,SPEED" | indent2)

In the absence of hardware support, software-based encoding can be used. Its speed depends on the CPU model installed in your system. x265 provides superior quality compared to x264. x265 10bit is the preset default for all 'autoadd' home videos.

Regardless of the encoding system you choose, you have the option to transcode HDR to SDR using tone-mapping, which can enhance SDR display quality, but this process can be slow. Note that HDR to SDR tone-mapping requires a newer generation CPU due to its high CPU intensity. You can also opt to resize your video to either 1080P or 720P, or keep it at its original size."
fi

# Display message
msg_box "#### PLEASE READ CAREFULLY - CODECS, BITRATES AND VIDEO RESOLUTION ####\n
$(echo -e "$display_msg1")"

# Select encoder
# Initialize list arrays
OPTIONS_VALUES_INPUT=()
OPTIONS_LABELS_INPUT=()
msg "Choose a hardware encoder format:"
# HEVC HW encode
if [ "$hevc_hardware_support" = 1 ]
then
  OPTIONS_VALUES_INPUT+=( "TYPE01" )
  OPTIONS_LABELS_INPUT+=( "Enable hardware HEVC 10bit encode (recommended)" )
fi
# HEVC HW encode
if [ "$h264_hardware_support" = 1 ]
then
  OPTIONS_VALUES_INPUT+=( "TYPE02" )
  OPTIONS_LABELS_INPUT+=( "Enable hardware H264 encode (recommended)" )
fi
# x265 & x264 SW encode
OPTIONS_VALUES_INPUT+=( "TYPE03" )
OPTIONS_LABELS_INPUT+=( "Enable software x.265 encode - painfully slow, superior quality, small file size" )
OPTIONS_VALUES_INPUT+=( "TYPE04" )
OPTIONS_LABELS_INPUT+=( "Enable software x264 encode - slow, good quality" )

makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  # Enable HW HEVC encode
  hevc_hardware_support=1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" HW_HEVC 1
  # Disable
  h264_hardware_support=0
  x264_software_support=0
  x265_software_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" HW_H264 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X264_ARG 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X265_ARG 0
elif [ "$RESULTS" = 'TYPE02' ]
then
  # Enable HW H264 encode
  h264_hardware_support=1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" HW_H264 1
  # Disable
  hevc_hardware_support=0
  x264_software_support=0
  x265_software_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" HW_HEVC 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X264_ARG 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X265_ARG 0
elif [ "$RESULTS" = 'TYPE03' ]
then
  # Enable SW x265 encode
  x265_software_support=1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X265_ARG 1
  # Disable
  hevc_hardware_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" HW_HEVC 0
  h264_hardware_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" HW_H264 0
  x264_software_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X264_ARG 0
  intel_qsv_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" INTEL_QSV_ARG 0
  nvidia_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_GPU_ARG 0
  nvenc_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_NVENC_ARG 0
  nvidia_aq_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_AQ_ARG 0
  amd_amf_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" AMD_AMF_ARG 0
  vaapi_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" VAAPI_ARG 0
elif [ "$RESULTS" = 'TYPE04' ]
then
  # Enable SW x264 encode
  x264_software_support=1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X264_ARG 1
  # Disable
  hevc_hardware_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" HW_HEVC 0
  h264_hardware_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" HW_H264 0
  x265_software_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X265_ARG 0
  intel_qsv_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" INTEL_QSV_ARG 0
  nvidia_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_GPU_ARG 0
  nvenc_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_NVENC_ARG 0
  nvidia_aq_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" NVIDIA_AQ_ARG 0
  amd_amf_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" AMD_AMF_ARG 0
  vaapi_support=0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" VAAPI_ARG 0
fi


# Select SW encoder profile
if [ "$h264_software_support" = 1 ]
then
  # Display msg
  display_msg1="You have chosen the x264 software encoder. You must now choose a x264 encoding profile."

  msg_box "#### PLEASE READ CAREFULLY - VIDEO X264 PROFILE ####\n\n$(echo -e "$display_msg1")"

  msg "Select a software encoder (x264 or x265) from the menu:"
  # Options for software encoder
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" )
  OPTIONS_LABELS_INPUT=( "x264 - standard settings" \
  "x264-avbr - average variable bitrate (AVBR) ratecontrol" \
  "x264-quick - increase encoding speed, no perceptible loss in video quality" \
  "x264-avbr & x264-quick - combination of both (Recommended)" )

  # Profile levels
  # 1 enables x264
  # 2 enables x264-avbr ( Use average variable bitrate (AVBR) ratecontrol )
  # 3 enables x264-quick ( Increase encoding speed with no perceptible loss in video quality, avoiding quality problems with some encoder presets )
  # 4 enables options 2 & 3 (Recommended)
  if [ "$RESULTS" = 'TYPE01' ]
  then
    # Enable SW x264
    msg "Modifying vidcoderr.ini settings..."
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X264_ARG 1
    info "Software encodes: ${YELLOW}x264${NC}"
  elif [ "$RESULTS" = 'TYPE02' ]
  then
    # Enable SW x264-avbr
    msg "Modifying vidcoderr.ini settings..."
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X264_ARG 2
    info "Software encodes: ${YELLOW}x264-avbr${NC}"
  elif [ "$RESULTS" = 'TYPE03' ]
  then
    # Enable SW x264-quick
    msg "Modifying vidcoderr.ini settings..."
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X264_ARG 3
    info "Software encodes: ${YELLOW}x264-quick${NC}"
  elif [ "$RESULTS" = 'TYPE04' ]
  then
    # Enable SW x264-avbr & x264-quick
    msg "Modifying vidcoderr.ini settings..."
    pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" X264_ARG 4
    info "Software encodes: ${YELLOW}x264-avbr & x264-quick${NC}"
  fi
  echo
fi

# Select a video resolution and HDR option
msg "Select a output resolution option from the menu:"
if [ "$hevc_hardware_support" = 1 ]
then
  # Options for HEVC enabled
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" "TYPE07" "TYPE08" )
  OPTIONS_LABELS_INPUT=( "4K HDR - full 4K HDR display quality" \
  "4K SDR - full 4K SDR display quality (SDR tone-mapping enabled)" \
  "2K HDR - 1080p HDR resolution limit (resize)" \
  "2K SDR - 1080p resolution limit (resize & SDR tone-mapping enabled)" \
  "720P SDR - 720p resolution limit (resize & SDR tone-mapping enabled)" \
  "4K SDR limit - HDR input files are ignored" \
  "2K SDR limit - HDR input files are ignored (resize)" \
  "720P SDR limit - HDR input files are ignored (resize)" )
elif [ "$hevc_hardware_support" = 0 ]
then
  # Options for HEVC disabled
  OPTIONS_VALUES_INPUT=( "TYPE02" "TYPE04" "TYPE05" "TYPE06" "TYPE07" "TYPE08" )
  OPTIONS_LABELS_INPUT=( "4K SDR - full 4K SDR display quality (SDR tone-mapping enabled)" \
  "2K SDR - 1080p resolution limit (resize & SDR tone-mapping enabled)" \
  "720P SDR - 720p resolution limit (resize & SDR tone-mapping enabled)" \
  "4K SDR limit - HDR input files are ignored" \
  "2K SDR limit - HDR input files are ignored (resize)" \
  "720P SDR limit - HDR input files are ignored (resize)" )
fi
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  # Enable 4K HDR
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_HDR_CONTENT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENABLE_RESIZE_LIMIT 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" CONVERT_HDR_TO_SDR 0
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}4K HDR${NC}"
  echo
elif [ "$RESULTS" = 'TYPE02' ]
then
  # Enable 4K SDR
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_HDR_CONTENT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENABLE_RESIZE_LIMIT 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" CONVERT_HDR_TO_SDR 1
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}4K SDR${NC}"
  info "HDR to SDR tone-mapping status: ${YELLOW}enabled${NC}"
  echo
elif [ "$RESULTS" = 'TYPE03' ]
then
  # Enable 2K HDR
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_HDR_CONTENT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENABLE_RESIZE_LIMIT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_RESIZE_LIMIT '--1080p'
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" CONVERT_HDR_TO_SDR 0
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}2K/1080P HDR${NC}"
  echo
elif [ "$RESULTS" = 'TYPE04' ]
then
  # Enable 2K SDR
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_HDR_CONTENT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENABLE_RESIZE_LIMIT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_RESIZE_LIMIT '--1080p'
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" CONVERT_HDR_TO_SDR 1
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}2K/1080P SDR${NC}"
  info "HDR to SDR tone-mapping status: ${YELLOW}enabled${NC}"
  echo
elif [ "$RESULTS" = 'TYPE05' ]
then
  # Enable 720P SDR
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_HDR_CONTENT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENABLE_RESIZE_LIMIT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_RESIZE_LIMIT '--720p'
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" CONVERT_HDR_TO_SDR 0
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}720P SDR${NC}"
  info "HDR to SDR tone-mapping status: ${YELLOW}enabled${NC}"
  echo
elif [ "$RESULTS" = 'TYPE06' ]
then
  # Enable 4K SDR limit
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_HDR_CONTENT 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENABLE_RESIZE_LIMIT 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" CONVERT_HDR_TO_SDR 0
  info "HDR input status: ${YELLOW}disabled${NC} ( off )"
  info "Maximum video output resolution: ${YELLOW}4K SDR${NC}"
  echo
elif [ "$RESULTS" = 'TYPE07' ]
then
  # Enable 2K SDR limit
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_HDR_CONTENT 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENABLE_RESIZE_LIMIT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_RESIZE_LIMIT '--1080p'
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" CONVERT_HDR_TO_SDR 0
  info "HDR input status: ${YELLOW}disabled${NC} ( off )"
  info "Maximum video output resolution: ${YELLOW}2K/1080P SDR${NC}"
  echo
elif [ "$RESULTS" = 'TYPE08' ]
then
  # Enable 720P SDR limit
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_HDR_CONTENT 0
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENABLE_RESIZE_LIMIT 1
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" ENCODE_RESIZE_LIMIT '--720p'
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" CONVERT_HDR_TO_SDR 0
  info "HDR input status: ${YELLOW}disabled${NC} ( off )"
  info "Maximum video output resolution: ${YELLOW}720P SDR${NC}"
  echo
fi


#---- Configure Vidcoderr audio

section "Set audio quality"

# Audio Format
msg_box "#### PLEASE READ CAREFULLY - AUDIO FORMAT ####\n
You can choose from preset audio bitrate limits and select either surround sound (which supports 5.1, 7.1, and Atmos) or limit the audio stream to 2-channel stereo. These presets are only applicable to series and movie video encodes, and will not affect home videos. Home videos will always use a fixed audio preset of Dolby Digital EAC-3 384 Kbps."

msg "Select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" "TYPE07" )
OPTIONS_LABELS_INPUT=( "Stereo - 96 Kbps - low quality" "Stereo - 128 Kbps - Average quality" "Stereo - 192 Kbps - Good quality ( Recommended )" "Stereo - 384 Kbps - Excellent quality" "Surround - 384 Kbps - Good quality ( Recommended )" "Surround - 448 Kbps - Excellent quality" "Surround - 640 Kbps - Fidelity quality" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  # Audio bitrate / format
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_BITRATE 96
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_CHANNELS stereo
  info "Audio stream encoder set at: ${YELLOW}96 Kbps Stereo${NC}"
  echo
elif [ "$RESULTS" = 'TYPE02' ]
then
  # Audio bitrate / format
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_BITRATE 128
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_CHANNELS stereo
  info "Audio stream encoder set at: ${YELLOW}128 Kbps Stereo${NC}"
  echo
elif [ "$RESULTS" = 'TYPE03' ]
then
  # Audio bitrate / format
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_BITRATE 192
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_CHANNELS stereo
  info "Audio stream encoder set at: ${YELLOW}192 Kbps Stereo${NC}"
  echo
elif [ "$RESULTS" = 'TYPE04' ]
then
  # Audio bitrate / format
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_BITRATE 384
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_CHANNELS stereo
  info "Audio stream encoder set at: ${YELLOW}384 Kbps Stereo${NC}"
  echo
elif [ "$RESULTS" = 'TYPE05' ]
then
  # Audio bitrate / format
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_BITRATE 384
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_CHANNELS surround
  info "Audio stream encoder set at: ${YELLOW}384 Kbps Surround${NC}"
  echo
elif [ "$RESULTS" = 'TYPE06' ]
then
  # Audio bitrate / format
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_BITRATE 448
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_CHANNELS surround
  info "Audio stream encoder set at: ${YELLOW}448 Kbps Surround${NC}"
  echo
elif [ "$RESULTS" = 'TYPE07' ]
then
  # Audio bitrate / format
  msg "Modifying vidcoderr.ini settings..."
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_BITRATE 640
  pct exec $CTID -- crudini --set /usr/local/bin/vidcoderr/vidcoderr.ini "" DST_STREAM_AUDIO_CHANNELS surround
  info "Audio stream encoder set at: ${YELLOW}640 Kbps Surround${NC}"
  echo
fi

#---- Start Systemd ----------------------------------------------------------------

# Start Vidcoderr system.d services
# Enable and start services if necessary
# Standard Watch Service
services=(
  vidcoderr_watchdir_std.timer
  vidcoderr_inotify_std.service
  SimpleHTTPServerWithUpload.service
)
for service in "${services[@]}"
do
  if [ "$(pct exec $CTID -- systemctl is-active "$service")" == "inactive" ]
  then
    pct exec $CTID -- systemctl enable --quiet "$service"
    pct exec $CTID -- systemctl restart "$service"
    while ! [ "$(pct exec $CTID -- systemctl is-active "$service")" == "active" ]
    do
      echo -n .
    done
    info "Systemd '$service' status: ${GREEN}running${NC}"
  else
    info "Systemd '$service' status: ${GREEN}running${NC}"
  fi
done
echo

#---- Finish Line ------------------------------------------------------------------
section "Completion Status"

#---- Set display text
# Get port
port=$(pct exec $CTID -- awk -F "=" '/HTTPSERVER_PORT/ {print $2}' /usr/local/bin/vidcoderr/vidcoderr.ini)
# Get IP type (ip -4 addr show eth0)
if [ "$(pct exec $CTID -- ip addr show eth0  | grep -q dynamic > /dev/null; echo $?)" = 0 ]
then
  ip_type='dhcp - best assign a IP reservation'
else
  ip_type='static IP'
fi
# Web access URL
display_msg1=( "http://$(pct exec $CTID -- hostname).$(pct exec $CTID -- hostname -d):$port/" )
display_msg1+=( "http://$(pct exec $CTID -- hostname -I | sed -r 's/\s+//g'):$port/ ($ip_type)" )
# Autoadd dir
display_msg2=( "in_unsorted:/mnt/public/autoadd/vidcoderr/out_unsorted" )
display_msg2=( "in_homevideo:/mnt/video/homevideo" )
# Main library
if [ "$main_videolibrary" = 1 ]
then
  display_msg3_var='enabled'
elif [ "$main_videolibrary" = 0 ]
then
  display_msg3_var='disabled'
fi

msg_box "${HOSTNAME^} configuration is complete.

Vidcoderr has been set up to automatically monitor and encode video content in the designated folders. Please note that video encoding is a time-consuming process, so we kindly ask for your patience while waiting for the output video files.

$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "INPUT,OUTPUT" | indent2)

Your main library (i.e series, movies) watch status is '$display_msg3_var'.

If you have a single video file that you would like to encode, you can either copy it into the '/public/autoadd/vidcoderr/in_homevideo' or '/public/autoadd/vidcoderr/inunsorted' folders, or make use of our Vidcoderr http-file-server (HFS) web-based upload tool.

$(printf '%s\n' "${display_msg1[@]}" | indent2)

The configuration file /usr/local/bin/vidcoderr/vidcoderr.ini allows for more advanced modifications, but any changes made will require Vidcoderr to be restarted.

$(if [ -n "$CT_PASSWORD" ] && [ -n "$REPO_PKG_NAME" ]; then echo -e "The default ${REPO_PKG_NAME^} CT root password is: '$CT_PASSWORD'"; fi)
More information here: https://github.com/ahuacate/medialab"

# Display Installation error report
printf '%s\n' "${display_dir_error_MSG[@]}"
printf '%s\n' "${display_permission_error_MSG[@]}"
printf '%s\n' "${display_chattr_error_MSG[@]}"
source ${COMMON_PVE_SRC_DIR}/pvesource_error_log.sh
#-----------------------------------------------------------------------------------