#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_ahuabooks_settings.sh
# Description:  Source script for applying ES Auto Ahuabooks settings
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Create Download folders
pct exec $CTID -- runuser media -c 'mkdir -p /mnt/books/{ebooks,comics,magazines}'
pct exec $CTID -- runuser media -c 'mkdir -p /mnt/audio/{audiobooks,podcasts}'
pct exec $CTID -- runuser media -c 'mkdir -p /mnt/public/autoadd/direct_import/lazylibrarian'

#---- Apply LazyLibrarian ES settings
# Stopping Lazylibrarian service
if [ $(pct exec $CTID -- systemctl is-active lazy.service) == "active" ]; then
  pct exec $CTID -- systemctl stop lazy.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active lazy.service) != "active" ]; then
    break
  fi
  sleep 5
  done
fi

# Setting Easy Script settings
pct exec $CTID -- rm /home/media/lazylibrarian/.config/lazylibrarian.ini
pct push $CTID ${DIR}/source/pve_medialab_ct_ahuabooks_settings/esauto_lazylibrarian.ini /home/media/lazylibrarian/.config/lazylibrarian.ini --group 65605 --user 1605

# Starting Lazylibrarian service 
if [ $(pct exec $CTID -- systemctl is-active lazy.service) != "active" ]; then
  pct exec $CTID -- systemctl start lazy.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active lazy.service) == "active" ]; then
    break
  fi
  sleep 5
  done
fi

#---- Apply Booksonic ES settings
# Stopping Lazylibrarian service
if [ $(pct exec $CTID -- systemctl is-active booksonic.service) == "active" ]; then
  pct exec $CTID -- systemctl stop booksonic.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active booksonic.service) != "active" ]; then
    break
  fi
  sleep 5
  done
fi

# Setting Easy Script settings
pct exec $CTID -- bash -c 'echo "FastCacheEnabled=true" >> /home/media/booksonic/airsonic.properties'
pct exec $CTID -- bash -c 'echo "IgnoreSymLinks=true" >> /home/media/booksonic/airsonic.properties'
pct exec $CTID -- bash -c 'echo "WelcomeTitle=Welcome to Booksonic!" >> /home/media/booksonic/airsonic.properties'
pct exec $CTID -- bash -c 'echo "WelcomeMessage2=" >> /home/media/booksonic/airsonic.properties'

# Stopping Booksonic service
if [ $(pct exec $CTID -- systemctl is-active booksonic.service) != "active" ]; then
  pct exec $CTID -- systemctl start booksonic.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active booksonic.service) == "active" ]; then
    break
  fi
  sleep 5
  done
fi