#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_updater.sh
# Description:  Source script for updating Vidcoderr & host OS
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
# Stopping Vidcoderr system.d services
msg "Stopping Vidcoderr system.d services..."
if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir.service)" == "active" ]; then
  pct exec $CTID -- systemctl stop vidcoderr_watchdir.service
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchdir.service)" == "inactive" ]]; do
    echo -n .
  done
fi

if [ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchprune.service)" == "active" ]; then
  MAIN_VIDEOLIBRARY=1
  pct exec $CTID -- systemctl stop vidcoderr_watchprune.service
  while ! [[ "$(pct exec $CTID -- systemctl is-active vidcoderr_watchprune.service)" == "inactive" ]]; do
    echo -n .
  done
else
  MAIN_VIDEOLIBRARY=0
fi

#---- Perform OS updates
section "Perform OS update"
pct exec $CTID -- apt-get update -y
pct exec $CTID -- apt-get upgrade -y

#---- Perform Prerequisite updates
section "Perform prerequisite SW updates"
# Installing Ruby
msg "Prerequisite - Upgrading Ruby..."
pct exec $CTID -- apt-get upgrade ruby-full -yqq

# Install bc
msg "Prerequisite - Upgrading bc..."
pct exec $CTID -- apt-get upgrade bc -yqq

# Install MKVToolNix
msg "Prerequisite - Upgrading MKVToolNix..."
pct exec $CTID -- apt-get upgrade mkvtoolnix mkvtoolnix-gui -yqq

# Install FFmpeg
msg "Prerequisite - Upgrading FFmpeg..."
pct exec $CTID -- apt-get upgrade ffmpeg -yqq

# Install Mediainfo
msg "Prerequisite - Upgrading Mediainfo..."
pct exec $CTID -- apt-get upgrade mediainfo -yqq

# Install MPV
msg "Prerequisite - Upgrading MPV..."
pct exec $CTID -- apt-get upgrade mpv -yqq

# Install MPV
msg "Prerequisite - Upgrading Inotify..."
pct exec $CTID -- apt-get upgrade inotify-tools -yqq

# Install Translate
msg "Prerequisite - Upgrading Translate Shell..."
pct exec $CTID -- apt-get upgrade translate-shell -yqq

# Install encoder kernels
pct exec $CTID -- apt-get upgrade i965-va-driver-shaders -yqq
pct exec $CTID -- apt-get upgrade intel-media-va-driver-non-free -yqq

#---- Install latest Vidcoder scripts
section "Upgrade Vidcoderr scripts"
# vidcoderr_watchdir.sh script
msg "Updating vidcoderr_watchdir..."
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_watchdir.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
# vidcoderr_watchprune.sh script
msg "Updating vidcoderr_watchprune..."
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_watchprune.sh /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchprune.sh
# vidcoderr_encoder.sh script
msg "Updating vidcoderr_encoder..."
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/vidcoderr_encoder.sh /usr/local/bin/vidcoderr/vidcoderr_encoder.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_encoder.sh
# Input filters
msg "Updating format filters..."
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/video_format_filter.txt /usr/local/bin/vidcoderr/video_format_filter.txt
pct push $CTID ${DIR}/source/pve_medialab_ct_vidcoderr_settings/other_format_filter.txt /usr/local/bin/vidcoderr/other_format_filter.txt
pct exec $CTID -- chown media:medialab /usr/local/bin/vidcoderr/video_format_filter.txt
pct exec $CTID -- chown media:medialab /usr/local/bin/vidcoderr/other_format_filter.txt

#---- Upgrade Don Meltons Other Video Transcode
section "Don Meltons packages"
msg "Upgrading Other-Video package..."
pct exec $CTID -- bash -c "gem update other_video_transcoding"

# Restart Vidcoderr system.d services
# Enable and start Vidcoderr system.d services
pct exec $CTID -- systemctl restart vidcoderr_watchdir.service
pct exec $CTID -- systemctl restart vidcoderr_watchprune.service
sleep 5

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

if [ ${MAIN_VIDEOLIBRARY} = 1 ]; then
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
fi

#---- Finish Line ------------------------------------------------------------------
section "Update Status."

msg "Success. Vidcoderr upgrade has finished."