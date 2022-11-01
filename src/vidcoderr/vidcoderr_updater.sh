#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_updater.sh
# Description:  Source script for updating Vidcoderr & host OS
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Get 'VIDCODERR_WATCHDIR_TYPE' arg
VIDCODERR_WATCHDIR_TYPE=$(pct exec $CTID -- awk -F "=" '/VIDCODERR_WATCHDIR_TYPE/ {print $2}' /usr/local/bin/vidcoderr/vidcoderr.ini)

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
# Copy vidcoderr_watchdir.sh script
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_watchdir.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
# Copy vidcoderr_watchdir_list.sh script
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_watchdir_list.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir_list.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir_list.sh
# Copy vidcoderr_watchdir_process.sh script
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_watchdir_process.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir_process.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir_process.sh
# Copy vidcoderr_watchdir_prune.sh script
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_watchdir_prune.sh /usr/local/bin/vidcoderr/vidcoderr_watchdir_prune.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_watchdir_prune.sh
# Copy vidcoderr_encoder.sh script
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_encoder.sh /usr/local/bin/vidcoderr/vidcoderr_encoder.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_encoder.sh

# Copy inotify script
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_inotify_rsync.sh /usr/local/bin/vidcoderr/vidcoderr_inotify_rsync.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/vidcoderr_inotify_rsync.sh

# Copy SimpleHTTPServerWithUpload scripts
pct push $CTID ${SRC_DIR}/vidcoderr/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.sh /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.sh
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.sh

pct push $CTID ${DIR}/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.py /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.py
pct exec $CTID -- chmod a+rx /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.py

# Copy filters
pct push $CTID ${SRC_DIR}/vidcoderr/video_format_filter.txt /usr/local/bin/vidcoderr/video_format_filter.txt
pct push $CTID ${SRC_DIR}/vidcoderr/other_format_filter.txt /usr/local/bin/vidcoderr/other_format_filter.txt
pct push $CTID ${SRC_DIR}/vidcoderr/rsync_exclude_filter.txt /usr/local/bin/vidcoderr/rsync_exclude_filter.txt

# Copy Systemd services
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_watchdir_rsync.service /etc/systemd/system/vidcoderr_watchdir_rsync.service
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_watchdir_rsync.timer /etc/systemd/system/vidcoderr_watchdir_rsync.timer
pct push $CTID ${SRC_DIR}/vidcoderr/SimpleHTTPServerWithUpload/SimpleHTTPServerWithUpload.service /etc/systemd/system/SimpleHTTPServerWithUpload.service
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_inotify_rsync.service /etc/systemd/system/vidcoderr_inotify_rsync.service
pct push $CTID ${SRC_DIR}/vidcoderr/vidcoderr_inotify.service /etc/systemd/system/vidcoderr_inotify.service

# Chown media:medialab all txt files
pct exec $CTID -- bash -c 'chown media:medialab /usr/local/bin/vidcoderr/*.txt'

#---- Upgrade Don Meltons Other Video Transcode
section "Don Meltons packages"
msg "Upgrading Other-Video package..."
pct exec $CTID -- bash -c "gem update other_video_transcoding"

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
section "Update Status."

msg "Success. Vidcoderr upgrade has finished."
#-----------------------------------------------------------------------------------