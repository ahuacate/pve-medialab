#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_inotify_rsync.sh
# Description:  Source script for inotify watch of autoadd inputs
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Action on autoadd SRC file
inotifywait -m -r -e close_write,moved_to --exclude '/mnt/public/autoadd/vidcoderr/out_unsorted' --exclude '/*.log'  /mnt/public/autoadd/vidcoderr/ \
    --timefmt '%Y-%m-%dT%H:%M:%S' \
    --format '%T;%w;%f;%e' | \
    while IFS=';' read datetime dir filename event; do
      # Wait for 'vidcoderr_watchdir.sh' to be inactive
      while pgrep -fl "vidcoderr_watchdir.sh" </dev/null; do
        sleep 2
      done
      # Start 'vidcoderr_watchdir.sh'
      if ! [[ $(pgrep -fl "vidcoderr_watchdir.sh") ]]; then
        /usr/local/bin/vidcoderr/vidcoderr_watchdir.sh
      fi
    done