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
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
# Pull CT vidocoderr.ini file
# pct pull $CTID /usr/local/bin/vidcoderr/vidcoderr.ini ${TEMP_DIR}/vidcoderr.ini

# Stopping Vidcoderr system.d services 
if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir.service)" == "active" ]; then
  pct exec $CTID -- systemctl stop vidcoderr_watchdir.service
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir.service)" == "inactive" ]]; do
    echo -n .
  done
  pct exec $CTID -- systemctl disable vidcoderr_watchdir.service &> /dev/null
fi

if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_rsync.timer)" == "active" ]; then
  pct exec $CTID -- systemctl stop vidcoderr_rsync.timer
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_rsync.timer)" == "inactive" ]]; do
    echo -n .
  done
  pct exec $CTID -- systemctl disable vidcoderr_rsync.timer &> /dev/null
fi

if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_inotify_rsync.service)" == "active" ]; then
  pct exec $CTID -- systemctl stop vidcoderr_inotify_rsync.service
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_inotify_rsync.service)" == "inactive" ]]; do
    echo -n .
  done
  pct exec $CTID -- systemctl disable vidcoderr_inotify_rsync.service &> /dev/null
fi

if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_inotify.service)" == "active" ]; then
  pct exec $CTID -- systemctl stop vidcoderr_inotify.service
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_inotify.service)" == "inactive" ]]; do
    echo -n .
  done
  pct exec $CTID -- systemctl disable vidcoderr_inotify.service &> /dev/null
fi

if [ "$(pct exec $CTID -- systemctl is-active SimpleHTTPServerWithUpload.service)" == "active" ]; then
  pct exec $CTID -- systemctl stop SimpleHTTPServerWithUpload.service
  while ! [[ "$(pct exec $CTID -- systemctl is-active SimpleHTTPServerWithUpload.service)" == "inactive" ]]; do
    echo -n .
  done
  pct exec $CTID -- systemctl disable SimpleHTTPServerWithUpload.service &> /dev/null
fi

#---- Configure Vidcoderr
section "Configure Vidcoderr"

# Set library watch method
msg_box "#### PLEASE READ CAREFULLY - WATCH METHOD ####\n
The user must select a method to watch for new video content to process. Options are:

  --  Standard Watch Service: Schedule a video library scan to be performed every 6 hours (Recommended).
  --  Inotify Watch Service: Use Inotifywait to watch your video library.

Inotify Watch option requires your NAS to broker Inotify requests and forward the data to the Vidcoderr Inotifywait client. This requires additional system configuration and setup by the User. We recommend the Standard Watch service because it always works."

msg "Select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" )
OPTIONS_LABELS_INPUT=( "Standard Watch Service ( Recommended )" "Inotify Watch Service" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == 'TYPE01' ]; then
  # Set library watch method
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(VIDCODERR_WATCHDIR_TYPE.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr watch method: ${YELLOW}standard${NC}"
  VIDCODERR_WATCHDIR_TYPE=1
  echo
elif [ ${RESULTS} == 'TYPE02' ]; then
  # Set library watch method
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(VIDCODERR_WATCHDIR_TYPE.*\s*=\s*\).*\$#\12#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr watch method: ${YELLOW}inotify${NC}"
  VIDCODERR_WATCHDIR_TYPE=2
  echo
fi

# Select watch folders
# in_stream dir
unset display_msg1
while IFS=',' read -r label media_type src dst encode_str arg; do
  display_msg1+=( "$(echo $(if [ ${arg} == 1 ]; then printf "${GREEN}enabled${NC}"; else printf "${RED}disabled${NC}"; fi),${src},${dst})" )
done < <(pct exec $CTID -- cat /usr/local/bin/vidcoderr/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_IN_STREAM*|^INPUT_WATCH_IN_HOMEVIDEO|INPUT_WATCH_IN_UNSORTED' | sed 's/^.*=//')
# stream dir
unset display_msg2
while IFS=',' read -r label media_type src dst encode_str arg; do
  display_msg2+=( "$(echo $(if [ ${arg} == 1 ]; then printf "${GREEN}enabled${NC}"; else printf "${RED}disabled${NC}"; fi),${src},${dst})" )
done < <(pct exec $CTID -- cat /usr/local/bin/vidcoderr/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_STREAM_*' | sed 's/^.*=//')

msg_box "#### PLEASE READ CAREFULLY - WATCH FOLDERS ####\n
All public 'autoadd' watch folders (/public/autoadd/vidcoderr/...) are enabled by default.

The User has the option automatically encode all main video libraries (movies, series, pron, documentary). The encoded output file is stored in the corresponding '/video/stream/{documentary,movies,series,pron,series}' folder. The input video files remain unchanged."
printf '%s\n' "${display_msg1[@]}" | column -t -s "," -N "${WHITE}STATUS${NC},${WHITE}INPUT${NC},${WHITE}OUTPUT${NC}" | indent2
echo
msg "The User has the option to enable encoding of your main library video folders (default disabled).\n"
printf '%s\n' "${display_msg2[@]}" | column -t -s "," -N "${WHITE}STATUS${NC},${WHITE}INPUT${NC},${WHITE}OUTPUT${NC}" | indent2
echo
msg "Select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" )
OPTIONS_LABELS_INPUT=( "Enable encoding of your main video library files" "Disable encoding of your main video library files" "None. Leave as is set" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == 'TYPE01' ]; then
  # Enable stream encoding
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i 's#^\(INPUT_WATCH_STREAM_.*\s*,\s*\).*[0-9]$#\11#' /usr/local/bin/vidcoderr/vidcoderr.ini
  MAIN_VIDEOLIBRARY=1
  info "Vidcoderr main video library status: ${YELLOW}enabled${NC}"
  echo
elif [ ${RESULTS} == 'TYPE02' ]; then
  # Disable stream encoding
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i 's#^\(INPUT_WATCH_STREAM_.*\s*,\s*\).*[0-9]$#\10#' /usr/local/bin/vidcoderr/vidcoderr.ini
  MAIN_VIDEOLIBRARY=0
  info "Vidcoderr main video library status: ${YELLOW}disabled${NC}"
  echo
fi

# Set maximum stream bandwidth
msg_box "#### PLEASE READ CAREFULLY - STREAMING BANDWIDTH ####\n
The User can set a maximum video encode bitrate limit (Mbps). This restricts the output stream video file bitrate limit and file size.  We recommend you not set a bitrate higher than 25-50% of you internet connection upload bandwidth limit. The User should also consider the number of client devices and the slowest clients internet access bandwidth speed limit. A maximum bitrate setting ratio of 1:1 is applied to 4K 2160p video. A pro rata ratio is then applied to 1440p, 1080p, 720p down to 480p.

This setting does not affect 'home video' encodes. Home video encodes always use a optimum bitrate so there is no noticeable quality difference from the input original file."

msg "Select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" )
OPTIONS_LABELS_INPUT=( "SD streaming - ${BW_SD} Mbps, low quality" "HD standard streaming - ${BW_HD_STD} Mbps" "HD plus streaming - ${BW_HD_PLUS} Mbps" "4K streaming - ${BW_4K} Mbps ( Recommended - Good quality balance)" "4K HDR streaming - ${BW_4K_HDR} Mbps" "None, leave at default 15 Mbps" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == 'TYPE01' ]; then
  # SD stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_SD}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_SD}${NC} Mbps"
  echo
elif [ ${RESULTS} == 'TYPE02' ]; then
  # HD stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_HD_STD}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_HD_STD}${NC} Mbps"
  echo
elif [ ${RESULTS} == 'TYPE03' ]; then
  # HD stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_HD_PLUS}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_HD_PLUS}${NC} Mbps"
  echo
elif [ ${RESULTS} == 'TYPE04' ]; then
  # 4K stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_4K}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_4K}${NC} Mbps"
  echo
elif [ ${RESULTS} == 'TYPE05' ]; then
  # 4K HDR stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_4K_HDR}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_4K_HDR}${NC} Mbps"
  echo
elif [ ${RESULTS} == 'TYPE06' ]; then
  # None
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}default${NC} Mbps"
  echo
fi

# Enable HDR 10bit encodes
msg_box "#### PLEASE READ CAREFULLY - HDR VIDEO & RESOLUTION ####\n
The default video format is HEVC 10-bit. 10-bit HEVC format is superior in quality to H264 because it significantly reduces the risk of color banding. It also supports encoding 4K high dynamic range (HDR) video. But HEVC 10bit HDR is not always available on all supported player clients. HDR video played on unsupported displays will look washed out.

Vidcoderr has the option to transcode HDR to SDR using tone-mapping which improves the SDR display quality but is a slow process. HDR to SDR tone-mapping requires a newer generation CPU as the process is CPU intensive.

The User must choose whether Vidcoderr processes 4K HDR video files, retains HDR metadata, transcodes HDR to SDR, resize your video to 1080P, 720P or not. We recommend selecting '4K/2K HDR' only if your display clients are HDR compatible."

msg "Select a output quality option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" "TYPE07" "TYPE08" )
OPTIONS_LABELS_INPUT=( "4K HDR - full 4K HDR display quality" \
"4K SDR - full 4K SDR display quality (SDR tone-mapping enabled)" \
"2K HDR - 1080p HDR resolution limit (resize)" \
"2K SDR - 1080p resolution limit (resize & SDR tone-mapping enabled)" \
"720P SDR - 720p resolution limit (resize & SDR tone-mapping enabled)" \
"4K SDR limit - HDR input files are ignored" \
"2K SDR limit - HDR input files are ignored (resize)" \
"720P SDR limit - HDR input files are ignored (resize)" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == 'TYPE01' ]; then
  # 4K HDR
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENABLE_RESIZE_LIMIT.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(CONVERT_HDR_TO_SDR.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}4K${NC}"
  echo
elif [ ${RESULTS} == 'TYPE02' ]; then
  # 4K SDR
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENABLE_RESIZE_LIMIT.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(CONVERT_HDR_TO_SDR.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}4K${NC}"
  info "HDR to SDR tone-mapping status: ${YELLOW}enabled${NC}"
  echo
elif [ ${RESULTS} == 'TYPE03' ]; then
  # 2K HDR
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENABLE_RESIZE_LIMIT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENCODE_RESIZE_LIMIT.*\s*=\s*\).*\$#\1'--1080p'#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(CONVERT_HDR_TO_SDR.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}2K/1080P${NC}"
  echo
elif [ ${RESULTS} == 'TYPE04' ]; then
  # 2K SDR
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENABLE_RESIZE_LIMIT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENCODE_RESIZE_LIMIT.*\s*=\s*\).*\$#\1'--1080p'#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(CONVERT_HDR_TO_SDR.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}2K/1080P${NC}"
  info "HDR to SDR tone-mapping status: ${YELLOW}enabled${NC}"
  echo
elif [ ${RESULTS} == 'TYPE05' ]; then
  # 720P SDR
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENABLE_RESIZE_LIMIT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENCODE_RESIZE_LIMIT.*\s*=\s*\).*\$#\1'--720p'#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(CONVERT_HDR_TO_SDR.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR input status: ${YELLOW}enabled${NC}"
  info "Maximum video output resolution: ${YELLOW}720P${NC}"
  info "HDR to SDR tone-mapping status: ${YELLOW}enabled${NC}"
  echo
elif [ ${RESULTS} == 'TYPE06' ]; then
  # 4K SDR limit
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENABLE_RESIZE_LIMIT.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(CONVERT_HDR_TO_SDR.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR input status: ${YELLOW}disabled${NC} ( off )"
  info "Maximum video output resolution: ${YELLOW}4K${NC}"
  echo
elif [ ${RESULTS} == 'TYPE07' ]; then
  # 2K SDR limit
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENABLE_RESIZE_LIMIT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENCODE_RESIZE_LIMIT.*\s*=\s*\).*\$#\1'--1080p'#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(CONVERT_HDR_TO_SDR.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR input status: ${YELLOW}disabled${NC} ( off )"
  info "Maximum video output resolution: ${YELLOW}2K/1080P${NC}"
  echo
elif [ ${RESULTS} == 'TYPE08' ]; then
  # 720P SDR limit
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENABLE_RESIZE_LIMIT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(ENCODE_RESIZE_LIMIT.*\s*=\s*\).*\$#\1'--720p'#" /usr/local/bin/vidcoderr/vidcoderr.in
  pct exec $CTID -- sed -i "s#^\(CONVERT_HDR_TO_SDR.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR input status: ${YELLOW}disabled${NC} ( off )"
  info "Maximum video output resolution: ${YELLOW}720P${NC}"
  echo
fi

# Audio Format
msg_box "#### PLEASE READ CAREFULLY - AUDIO FORMAT ####\n
The User can select a audio bitrate limit preset and select either surround ( supports 5.1, 7.1, Atmos ) or limit the audio stream to 2-channel stereo only. These presets only apply to 'stream' video encodes. Home videos are not affected. Home videos use a fixed audio preset of Dolby Digital EAC-3 384 Kbps."

msg "Select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" "TYPE07" )
OPTIONS_LABELS_INPUT=( "Stereo - 96 Kbps - low quality" "Stereo - 128 Kbps - Average quality" "Stereo - 192 Kbps - Good quality ( Recommended )" "Stereo - 384 Kbps - Excellent quality" "Surround - 384 Kbps - Good quality ( Recommended )" "Surround - 448 Kbps - Excellent quality" "Surround - 640 Kbps - Fidelity quality" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == 'TYPE01' ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\196#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1stereo#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}96 Kbps Stereo${NC}"
  echo
elif [ ${RESULTS} == 'TYPE02' ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1128#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1stereo#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}128 Kbps Stereo${NC}"
  echo
elif [ ${RESULTS} == 'TYPE03' ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1192#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1stereo#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}192 Kbps Stereo${NC}"
  echo
elif [ ${RESULTS} == 'TYPE04' ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1384#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1stereo#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}384 Kbps Stereo${NC}"
  echo
elif [ ${RESULTS} == 'TYPE05' ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1384#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1surround#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}384 Kbps Surround${NC}"
  echo
elif [ ${RESULTS} == 'TYPE06' ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1448#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1surround#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}448 Kbps Surround${NC}"
  echo
elif [ ${RESULTS} == 'TYPE07' ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1640#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1surround#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}640 Kbps Surround${NC}"
  echo
fi

#---- Start Systemd ----------------------------------------------------------------

# Start Vidcoderr system.d service 
if [ ${VIDCODERR_WATCHDIR_TYPE} == '1' ]; then
  # Standard Watch Service
  msg "Enabling Vidcoderr Standard Watch Services..."
  pct exec $CTID -- systemctl enable --quiet vidcoderr_watchdir_rsync.timer
  pct exec $CTID -- systemctl enable --quiet vidcoderr_inotify_rsync.service
  pct exec $CTID -- systemctl enable --quiet SimpleHTTPServerWithUpload.service

  if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir_rsync.timer)" == "inactive" ]; then
    pct exec $CTID -- systemctl restart vidcoderr_watchdir_rsync.timer
    while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir_rsync.timer)" == "active" ]]; do
      echo -n .
    done
    info "Systemd 'vidcoderr_watchdir_rsync.timer' status: ${GREEN}running${NC}"
  else
    info "Systemd 'vidcoderr_watchdir_rsync.timer' status: ${GREEN}running${NC}"
  fi

  if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_inotify_rsync.service)" == "inactive" ]; then
    pct exec $CTID -- systemctl restart vidcoderr_inotify_rsync.service
    while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_inotify_rsync.service)" == "active" ]]; do
      echo -n .
    done
    info "Systemd 'vidcoderr_inotify_rsync.service' status: ${GREEN}running${NC}"
  else
    info "Systemd 'vidcoderr_inotify_rsync.service' status: ${GREEN}running${NC}"
  fi

  if [ "$(pct exec $CTID -- systemctl is-active SimpleHTTPServerWithUpload.service)" == "inactive" ]; then
    pct exec $CTID -- systemctl restart SimpleHTTPServerWithUpload.service
    while ! [[ "$(pct exec $CTID -- systemctl is-active SimpleHTTPServerWithUpload.service)" == "active" ]]; do
      echo -n .
    done
    info "Systemd 'SimpleHTTPServerWithUpload.service' status: ${GREEN}running${NC}"
  else
    info "Systemd 'SimpleHTTPServerWithUpload.service' status: ${GREEN}running${NC}"
  fi
elif [ ${VIDCODERR_WATCHDIR_TYPE} == '2' ]; then
  # Inotify Watch Service
  msg "Enabling Vidcoderr Inotify Watch Services..."
  pct exec $CTID -- systemctl enable --quiet vidcoderr_inotify.service
  if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_inotify.service)" == "inactive" ]; then
    pct exec $CTID -- systemctl restart vidcoderr_inotify.service
    while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_inotify.service)" == "active" ]]; do
      echo -n .
    done
    info "Systemd 'vidcoderr_inotify.service' status: ${GREEN}running${NC}"
  else
    info "Systemd 'vidcoderr_inotify.service' status: ${GREEN}running${NC}"
  fi

  if [ "$(pct exec $CTID -- systemctl is-active SimpleHTTPServerWithUpload.service)" == "inactive" ]; then
    pct exec $CTID -- systemctl restart SimpleHTTPServerWithUpload.service
    while ! [[ "$(pct exec $CTID -- systemctl is-active SimpleHTTPServerWithUpload.service)" == "active" ]]; do
      echo -n .
    done
    info "Systemd 'SimpleHTTPServerWithUpload.service' status: ${GREEN}running${NC}"
  else
    info "Systemd 'SimpleHTTPServerWithUpload.service' status: ${GREEN}running${NC}"
  fi
fi
echo

#---- Finish Line ------------------------------------------------------------------
section "Completion Status"

#---- Set display text
# Get port
port=$(pct exec $CTID -- awk -F "=" '/HTTPSERVER_PORT/ {print $2}' /usr/local/bin/vidcoderr/vidcoderr.ini)
# Get IP type
if [[ $(pct exec $CTID -- ip addr show eth0  | grep -q dynamic > /dev/null; echo $?) == 0 ]]; then # ip -4 addr show eth0 
    ip_type='dhcp - best assign a IP reservation'
else
    ip_type='static IP'
fi
# Web access URL
display_msg1=( "http://$(pct exec $CTID -- hostname).$(pct exec $CTID -- hostname -d):${port}/" )
display_msg1+=( "http://$(pct exec $CTID -- hostname -I | sed -r 's/\s+//g'):${port}/ (${ip_type})" )
# Autoadd dir
display_msg2=( "in_unsorted:/mnt/public/autoadd/vidcoderr/out_unsorted" )
display_msg2+=( "in_homevideo:/mnt/video/homevideo" )
display_msg2+=( "in_stream/documentary:/mnt/video/stream/documentary" )
display_msg2+=( "in_stream/movies:/mnt/video/stream/movies" )
display_msg2+=( "in_stream/musicvideo:/mnt/video/stream/musicvideo" )
display_msg2+=( "in_stream/pron:/mnt/video/stream/pron" )
display_msg2+=( "in_stream/series:/mnt/video/stream/series" )
# Main library
if [[ -z ${MAIN_VIDEOLIBRARY} ]]; then
display_msg3_var='unchanged'
else
  if [ ${MAIN_VIDEOLIBRARY} == 1 ]; then
    display_msg3_var='enabled'
  elif [ ${MAIN_VIDEOLIBRARY} == 0 ]; then
    display_msg3_var='disabled'
  fi
fi

msg_box "${HOSTNAME^} installation was a success.\n\nThe User can upload video files for encoding using the Vidcoderr http-file-server (hfs) frontend. HFS provides easy access to the NAS '/public/autoadd/vidcoderr/...' input folders.\n\n$(printf '%s\n' "${display_msg1[@]}" | indent2)\n\nVidcoderr will detect the uploaded file and start the encoder processor. Encoded output video files are stored by input type.\n\n$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "INPUT,OUTPUT" | indent2)\n\nVidcoderr main library watch status is '${display_msg3_var}'.\n\nMore complex tweaks can be made in the configuration file: /usr/local/bin/vidcoderr/vidcoderr.ini (Vidcoderr requires a restart after editing).\n\nMore information is available here: https://github.com/ahuacate/medialab"

# Display Installation error report
printf '%s\n' "${display_dir_error_MSG[@]}"
printf '%s\n' "${display_permission_error_MSG[@]}"
printf '%s\n' "${display_chattr_error_MSG[@]}"
source ${COMMON_PVE_SRC_DIR}/pvesource_error_log.sh
#-----------------------------------------------------------------------------------