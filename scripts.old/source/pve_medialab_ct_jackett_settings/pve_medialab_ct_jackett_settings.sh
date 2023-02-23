#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_jackett_settings.sh
# Description:  Source script for applying ES Auto Jackett settings
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Stop Jackett system.d
if [ $(pct exec $CTID -- systemctl is-active jackett.service) == "active" ]; then
  pct exec $CTID -- systemctl stop jackett.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active jackett.service) == "inactive" ]; then
    break
  fi
  sleep 1
  done
fi

# Set API key
# pct exec $CTID -- sed -i 's/"APIKey":.*/"APIKey": "s9tcqkddvjpkmis824pp6ucgpwcd2xnc",/g' /home/media/.config/Jackett/ServerConfig.json
pct exec $CTID -- sed -i 's/"APIKey":.*/"APIKey": "ahuacate",/g' /home/media/.config/Jackett/ServerConfig.json

# Create & set download blackhole folder
pct exec $CTID -- runuser media -c 'mkdir -p /mnt/public/autoadd/torrent/unsorted'
pct exec $CTID -- sed -i 's/"BlackholeDir":.*/"BlackholeDir": "\/mnt\/public\/autoadd\/torrent\/unsorted",/g' /home/media/.config/Jackett/ServerConfig.json

# Start Jackett system.d
if [ $(pct exec $CTID -- systemctl is-active jackett.service) != "active" ]; then
  pct exec $CTID -- systemctl start jackett.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active jackett.service) == "active" ]; then
    break
  fi
  sleep 1
  done
fi