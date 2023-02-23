#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_deluge_settings.sh
# Description:  Source script for applying ES Auto Deluge settings
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Create Download folders
pct exec $CTID -- runuser media -c 'mkdir -p {/mnt/downloads/deluge/complete/flexget/{series,movies},/mnt/video/documentary/{movies,series,unsorted}}'
pct exec $CTID -- bash -c 'chown -hR {/mnt/downloads/deluge/complete/flexget,/mnt/video/documentary}'




# Download Deluge plugins 
pct exec $CTID -- runuser media -c 'wget --content-disposition https://forum.deluge-torrent.org/download/file.php?id=6306 -P /home/media/.config/deluge/plugins/' # Autoremove Plus
pct exec $CTID -- bash -c 'chown 1605:65605 /home/media/.config/deluge/plugins/*.egg'

# Configure Deluge plugins
pct exec $CTID -- bash -c 'mkdir -p /home/media/.config/deluge'
pct push $CTID ${DIR}/source/pve_medialab_ct_deluge_settings/label.conf /home/media/.config/deluge/label.conf --group 65605 --user 1605
pct push $CTID ${DIR}/source/pve_medialab_ct_deluge_settings/execute.conf /home/media/.config/deluge/execute.conf --group 65605 --user 1605
pct push $CTID ${DIR}/source/pve_medialab_ct_deluge_settings/autoremoveplus.conf /home/media/.config/deluge/autoremoveplus.conf --group 65605 --user 1605
pct push $CTID ${DIR}/source/pve_medialab_ct_deluge_settings/autoadd.conf /home/media/.config/deluge/autoadd.conf --group 65605 --user 1605

# Configure Deluge Auth
pct exec $CTID -- bash -c 'echo -e "flexget:9c67cf728b8c079c2e0065ee11cb3a9a6771420a:10\nlazylibrarian:9c67cf728b8c079c2e0065ee11cb3a9a6771421a:10" >> /home/media/.config/deluge/auth'

# Install Post Processing scripts
pct push $CTID ${DIR}/source/pve_medialab_ct_deluge_settings/deluge-postprocess.sh /home/media/.config/deluge/deluge-postprocess.sh --group 65605 --user 1605 --perms 0775

# Set Deluge preferences
if [ $(pct exec $CTID -- systemctl is-active deluged.service) != "active" ]; then
  pct exec $CTID -- systemctl start deluged.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active deluged.service) == "active" ]; then
    break
  fi
  sleep 1
  done
fi
pct exec $CTID -- su -c 'deluge-console "config -s allow_remote True"' media
pct exec $CTID -- su -c 'deluge-console "config -s max_active_downloading 20"' media
pct exec $CTID -- su -c 'deluge-console "config -s max_active_limit 20"' media
pct exec $CTID -- su -c 'deluge-console "config -s max_active_seeding 20"' media
pct exec $CTID -- su -c 'deluge-console "config -s max_connections_global 200"' media
pct exec $CTID -- su -c 'deluge-console "config -s remove_seed_at_ratio true"' media
pct exec $CTID -- su -c 'deluge-console "config -s stop_seed_at_ratio true"' media
pct exec $CTID -- su -c 'deluge-console "config -s stop_seed_ratio 1.5"' media
pct exec $CTID -- su -c 'deluge-console "plugin -e autoremoveplus"' media
pct exec $CTID -- su -c 'deluge-console "plugin -e label"' media
pct exec $CTID -- su -c 'deluge-console "plugin -e execute"' media
pct exec $CTID -- su -c 'deluge-console "plugin -e autoadd"' media

# Set Deluge download folder
if [ $(pct exec $CTID -- systemctl is-active deluged.service) == "active" ]; then
  pct exec $CTID -- systemctl stop deluged.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active deluged.service) == "inactive" ]; then
    break
  fi
  sleep 1
  done
fi
pct exec $CTID -- sed -i 's/"download_location":.*/"download_location": "\/mnt\/downloads\/deluge\/incomplete",/g' /home/media/.config/deluge/core.conf
if [ $(pct exec $CTID -- systemctl is-active deluged.service) != "active" ]; then
  pct exec $CTID -- systemctl start deluged.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active deluged.service) == "active" ]; then
    break
  fi
  sleep 1
  done
fi