#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_configbuilder.sh
# Description:  Source script for configuring Vidcoderr App
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Mbps maximum bandwith/bitrate args
BW_SD='3'
BW_HD='8'
BW_4K='15'
BW_4K_HDR='25'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
# Pull CT vidocoderr.ini file
pct pull $CTID /usr/local/bin/vidcoderr/vidcoderr.ini ${TEMP_DIR}/vidcoderr.ini

# in_stream dir
unset in_stream_dir_array
while IFS=',' read -r label src dst encode_str arg; do
  in_stream_dir_array+=( "$(echo $(if [ ${arg} == 1 ]; then printf "${GREEN}enabled${NC}"; else printf "${RED}disabled${NC}"; fi),${src},${dst})" )
done < <(cat ${TEMP_DIR}/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_IN_STREAM*|^INPUT_WATCH_IN_HOMEVIDEO|INPUT_WATCH_IN_UNSORTED' | sed 's/^.*=//')
# stream dir
unset stream_dir_array
while IFS=',' read -r label src dst encode_str arg; do
  stream_dir_array+=( "$(echo $(if [ ${arg} == 1 ]; then printf "${GREEN}enabled${NC}"; else printf "${RED}disabled${NC}"; fi),${src},${dst})" )
done < <(cat ${TEMP_DIR}/vidcoderr.ini | grep -E --color=never '^INPUT_WATCH_STREAM_*' | sed 's/^.*=//')

# Stopping Vidcoderr system.d services 
if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir.service)" == "active" ]; then
  pct exec $CTID -- systemctl stop vidcoderr_watchdir.service
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir.service)" == "inactive" ]]; do
    echo -n .
  done
fi

if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchprune.service)" == "active" ]; then
  pct exec $CTID -- systemctl stop vidcoderr_watchprune.service
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchprune.service)" == "inactive" ]]; do
    echo -n .
  done
fi

#---- Configure Vidcoderr
section "Configure Vidcoderr"

msg_box "#### PLEASE READ CAREFULLY - WATCH FOLDERS ####\n
Vidcoderr uses Inotifywait to watch selected folders for new video content to process. By default all public input folders ( public/autoadd/vidcoderr ) are active and enabled."
printf '%s\n' ${in_stream_dir_array[@]} | column -t -s "," -N "${WHITE}STATUS${NC},${WHITE}INPUT${NC},${WHITE}OUTPUT${NC}" | indent2
echo
msg "The User has the option to enable HEVC encoding of your main library video folders ( default disabled ).\n"
printf '%s\n' ${stream_dir_array[@]} | column -t -s "," -N "${WHITE}STATUS${NC},${WHITE}INPUT${NC},${WHITE}OUTPUT${NC}" | indent2
echo
msg "Vidcoderr configuration file can also be manually edited: /usr/local/bin/vidcoderr/vidcoderr.ini."
echo
msg "User must select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" )
OPTIONS_LABELS_INPUT=( "Enable encoding of your main video library files" "Disable encoding of your main video library files" "None. Leave as is" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == TYPE01 ]; then
  # Enable stream encoding
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i 's#^\(INPUT_WATCH_STREAM_.*\s*,\s*\).*[0-9]$#\11#' /usr/local/bin/vidcoderr/vidcoderr.ini
  MAIN_VIDEOLIBRARY=1
  info "Vidcoderr main video library status: ${YELLOW}enabled${NC}"
  echo
elif [ ${RESULTS} == TYPE02 ]; then
  # Disable stream encoding
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i 's#^\(INPUT_WATCH_STREAM_.*\s*,\s*\).*[0-9]$#\10#' /usr/local/bin/vidcoderr/vidcoderr.ini
  MAIN_VIDEOLIBRARY=0
  info "Vidcoderr main video library status: ${YELLOW}disabled${NC}"
  echo
fi

# Set maximum stream bandwidth
msg_box "#### PLEASE READ CAREFULLY - STREAMING BANDWIDTH ####\n
The User can set a maximum video encode bitrate limit ( Mbps ). This restricts the output stream video file bitrate limit and file size.  We recommend you not set a bitrate higher than 25-50% of you internet connection upload bandwidth limit. The User should also consider the number of client devices and the slowest clients internet access bandwidth speed limit. A maximum bitrate setting ratio of 1:1 is applied to 4K 2160p video. A pro rata ratio is then applied to 1080p, 720p down to 480p.

This setting does not affect 'home video' encodes. Home video encodes always use a optimum bitrate so there is no noticeable quality difference from the input original file."

msg "User must select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" )
OPTIONS_LABELS_INPUT=( "SD streaming - ${BW_SD} Mbps, low quality" "HD streaming - ${BW_HD} Mbps" "4K streaming - ${BW_4K} Mbps ( Recommended - Good quality balance)" "4K HDR streaming - ${BW_4K_HDR} Mbps" "None, leave at default 15 Mbps" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == TYPE01 ]; then
  # SD stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_SD}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_SD}${NC} Mbps"
  echo
elif [ ${RESULTS} == TYPE02 ]; then
  # HD stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_HD}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_HD}${NC} Mbps"
  echo
elif [ ${RESULTS} == TYPE03 ]; then
  # 4K stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_4K}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_4K}${NC} Mbps"
  echo
elif [ ${RESULTS} == TYPE04 ]; then
  # 4K HDR stream speed setting
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_MAXIMUM_BITRATE.*\s*=\s*\).*\$#\1${BW_4K_HDR}#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}${BW_4K_HDR}${NC} Mbps"
  echo
elif [ ${RESULTS} == TYPE05 ]; then
  # None
  info "Vidcoderr maximum bitrate for streaming encodes: ${YELLOW}default${NC} Mbps"
  echo
fi

# Enable HDR 10bit encodes
msg_box "#### PLEASE READ CAREFULLY - HDR VIDEO ####\n
The default video format is HEVC 10bit. The 10-bit HEVC format is superior in quality to H264 because it significantly reduces the risk of color banding. It also supports encoding 4K high dynamic range ( HDR ) video. But HEVC 10bit HDR is not always available on all supported player clients. HDR video played on unsupported players will look washed out and transcoding HDR to SDR generally produces poor results ( not supported ).

The User can choose whether Vidcoderr processes 4K HDR video files or not. We recommend only enabling if your clients are HDR compatible."

msg "User must select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" )
OPTIONS_LABELS_INPUT=( "Enable - enable HDR video encoding" "Disable - all HDR input files will be ignored" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == TYPE01 ]; then
  # Enable HDR
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\11#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR status: ${YELLOW}enabled${NC} ( on )"
  echo
elif [ ${RESULTS} == TYPE02 ]; then
  # Disable HDR
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(ENCODE_HDR_CONTENT.*\s*=\s*\).*\$#\10#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "HDR status: ${YELLOW}disabled${NC} ( off )"
  echo
fi

# Audio Format
msg_box "#### PLEASE READ CAREFULLY - AUDIO FORMAT ####\n
The User can select a audio bitrate limit preset and select either surround ( supports 5.1, 7.1, Atmos ) or limit the audio stream to 2-channel stereo only. These presets only apply to 'stream' video encodes. Home videos are not affected. Home videos use a fixed audio preset of Dolby Digital EAC-3 384 Kbps."

msg "User must select an option from the menu:"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" "TYPE07" )
OPTIONS_LABELS_INPUT=( "Stereo - 96 Kbps - low quality" "Stereo - 128 Kbps - Average quality" "Stereo - 192 Kbps - Good quality ( Recommended )" "Stereo - 384 Kbps - Excellent quality" "Surround - 384 Kbps - Good quality ( Recommended )" "Surround - 448 Kbps - Excellent quality" "Surround - 640 Kbps - Fidelity quality" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == TYPE01 ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\196#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1stereo#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}96 Kbps Stereo${NC}"
  echo
elif [ ${RESULTS} == TYPE02 ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1128#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1stereo#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}128 Kbps Stereo${NC}"
  echo
elif [ ${RESULTS} == TYPE03 ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1192#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1stereo#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}192 Kbps Stereo${NC}"
  echo
elif [ ${RESULTS} == TYPE04 ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1384#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1stereo#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}192 Kbps Stereo${NC}"
  echo
elif [ ${RESULTS} == TYPE05 ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1384#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1surround#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}384 Kbps Surround${NC}"
  echo
elif [ ${RESULTS} == TYPE06 ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1448#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1surround#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}448 Kbps Surround${NC}"
  echo
elif [ ${RESULTS} == TYPE07 ]; then
  # Audio bitrate / format
  msg "Modifying Vidcoderr.ini settings..."
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_BITRATE.*\s*=\s*\).*\$#\1640#" /usr/local/bin/vidcoderr/vidcoderr.ini
  pct exec $CTID -- sed -i "s#^\(DST_STREAM_AUDIO_CHANNELS.*\s*=\s*\).*\$#\1surround#" /usr/local/bin/vidcoderr/vidcoderr.ini
  info "Audio stream encoder set at: ${YELLOW}640 Kbps Surround${NC}"
  echo
fi

# Enable default Vidcoderr system.d services
pct exec $CTID -- systemctl enable --quiet vidcoderr_watchdir.service
pct exec $CTID -- systemctl restart vidcoderr_watchdir.service
sleep 2

# Checking Vidcoderr system.d service 
msg "Checking Vidcoderr Watchdir status..."
if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir.service)" == "inactive" ]; then
  msg "Starting Vidcoderr Watchdir..."
  pct exec $CTID -- systemctl restart vidcoderr_watchdir.service
  msg "Waiting to hear from Vidcoderr Watchdir..."
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir.service)" == "active" ]]; do
    echo -n .
  done
  info "Vidcoderr Watchdir status: ${GREEN}running${NC}"
  echo
else
  info "Vidcoderr Watchdir status: ${GREEN}running${NC}"
  echo
fi

# Enable main video library Vidcoderr system.d services ( vidcoderr_watchprune )
if [ ${MAIN_VIDEOLIBRARY} = 1 ]; then
  pct exec $CTID -- systemctl enable --quiet vidcoderr_watchprune.service
  pct exec $CTID -- systemctl restart vidcoderr_watchprune.service
  sleep 2
  msg "Checking Vidcoderr Watchprune status..."
  if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchprune.service)" == "inactive" ]; then
    msg "Starting Vidcoderr Watchprune..."
    pct exec $CTID -- systemctl restart vidcoderr_watchprune.service
    msg "Waiting to hear from Vidcoderr Watchprune.."
    while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchprune.service)" == "active" ]]; do
      echo -n .
    done
    info "Vidcoderr Watchprune status: ${GREEN}running${NC}"
    echo
  else
    info "Vidcoderr Watchprune status: ${GREEN}running${NC}"
    echo
  fi
else
  pct exec $CTID -- systemctl disable --quiet vidcoderr_watchprune.service
fi