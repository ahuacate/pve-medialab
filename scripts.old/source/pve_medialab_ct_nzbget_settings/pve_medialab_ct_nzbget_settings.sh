#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_nzbget_settings.sh
# Description:  Source script for applying ES Auto NZBGet settings
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Create Download folders
pct exec $CTID -- runuser media -c 'mkdir -p {/mnt/public/autoadd/usenet/{lazy,series,movies,music,pron,documentary,flexget-series,flexget-movies,unsorted},/mnt/downloads/usenet/{queue,tmp,intermediate,complete,nzb},/mnt/downloads/usenet/complete/{lazy,series,movies,music,pron,documentary,flexget-series,flexget-movies,unsorted}}'

# Set Download folder
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^MainDir=.*#MainDir=/mnt/downloads/usenet#' /opt/nzbget/nzbget.conf; fi'
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^DestDir=.*#DestDir=\${MainDir}/complete#' /opt/nzbget/nzbget.conf; fi'

# Set control port
pct exec $CTID -- sed -i '/^ControlPort=.*/c\ControlPort=6789' /opt/nzbget/nzbget.conf

# Restricted user access (connect to NZBGet from other programs)
pct exec $CTID -- sed -i '/^RestrictedUsername=.*/c\RestrictedUsername=appconnect' /opt/nzbget/nzbget.conf
pct exec $CTID -- sed -i '/^RestrictedPassword=.*/c\RestrictedPassword=ahuacate' /opt/nzbget/nzbget.conf

# Add username and password for RPC Access
pct exec $CTID -- sed -i "/AddUsername=/c\AddUsername=appconnect" /opt/nzbget/nzbget.conf
pct exec $CTID -- sed -i "/AddPassword=/c\AddPassword=ahuacate" /opt/nzbget/nzbget.conf

# Set User Daemon
pct exec $CTID -- sed -i '/^DaemonUsername=.*/c\DaemonUsername=media' /opt/nzbget/nzbget.conf

# Clean default Categorys
pct exec $CTID -- sed -i 's/^Category2.Name=.*/# Category2 Details/' /opt/nzbget/nzbget.conf
pct exec $CTID -- sed -i 's/^Category3.Name=.*//' /opt/nzbget/nzbget.conf
pct exec $CTID -- sed -i 's/^Category4.Name=.*//' /opt/nzbget/nzbget.conf
pct exec $CTID -- sed -i '/^# Category2 Details/a \\n# Category3 Details\n\n# Category4 Details\n\n# Category5 Details\n\n# Category6 Details\n\n# Category7 Details\n\n# Category8 Details\n\n# Category9 Details\n\n# Category10 Details' /opt/nzbget/nzbget.conf

# Setup Movie Category
pct exec $CTID -- sed -i 's/^Category1.Name=.*/Category1.Name=radarr-movies/' /opt/nzbget/nzbget.conf
pct exec $CTID -- sed -i 's/^Category1.Aliases=.*/Category1.Aliases=Movies*, *Movies/' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category1.DestDir=.*#Category1.DestDir=/mnt/downloads/usenet/complete/movies#' /opt/nzbget/nzbget.conf; fi'

# Setup Series (TV) Category
pct exec $CTID -- sed -i '/^# Category2 Details/a Category2.Name=sonarr-series\nCategory2.DestDir=\nCategory2.Aliases=TV*\nCategory2.Extensions=' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category2.DestDir=.*#Category2.DestDir=/mnt/downloads/usenet/complete/series#' /opt/nzbget/nzbget.conf; fi'

# Setup Music Category
pct exec $CTID -- sed -i '/^# Category3 Details/a Category3.Name=lidarr-music\nCategory3.DestDir=\nCategory3.Aliases=Music, Audio, Audio-mp3, Audio-Lossless, Audio-Other\nCategory3.Extensions=' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category3.DestDir=.*#Category3.DestDir=/mnt/downloads/usenet/complete/music#' /opt/nzbget/nzbget.conf; fi'

# Setup LazyLibrarian Category
pct exec $CTID -- sed -i '/^# Category4 Details/a Category4.Name=lazy\nCategory4.DestDir=\nCategory4.Aliases=Books*, Audio-Audiobook\nCategory4.Extensions=' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category4.DestDir=.*#Category4.DestDir=/mnt/downloads/usenet/complete/lazy#' /opt/nzbget/nzbget.conf; fi'

# Setup Pron Category
pct exec $CTID -- sed -i '/^# Category5 Details/a Category5.Name=pron\nCategory5.DestDir=\nCategory5.Aliases=XXX, XXX*, adult*, porn\nCategory5.Extensions=' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category5.DestDir=.*#Category5.DestDir=/mnt/downloads/usenet/complete/pron#' /opt/nzbget/nzbget.conf; fi'

# Setup Documentary Category
pct exec $CTID -- sed -i '/^# Category6 Details/a Category6.Name=documentary\nCategory6.DestDir=\nCategory6.Aliases=TV-Documentary, TV-Other\nCategory6.Extensions=' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category6.DestDir=.*#Category6.DestDir=/mnt/downloads/usenet/complete/documentary#' /opt/nzbget/nzbget.conf; fi'

# Setup Flexget-series Category
pct exec $CTID -- sed -i '/^# Category7 Details/a Category7.Name=flexget-series\nCategory7.DestDir=\nCategory7.Aliases=Flexget-series*\nCategory7.Extensions=' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category7.DestDir=.*#Category7.DestDir=/mnt/downloads/usenet/complete/flexget-series#' /opt/nzbget/nzbget.conf; fi'

# Setup Flexget-movies Category
pct exec $CTID -- sed -i '/^# Category8 Details/a Category8.Name=flexget-movies\nCategory8.DestDir=\nCategory8.Aliases=Flexget-movies*\nCategory8.Extensions=' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category8.DestDir=.*#Category8.DestDir=/mnt/downloads/usenet/complete/flexget-movies#' /opt/nzbget/nzbget.conf; fi'

# Setup Unsorted Category
pct exec $CTID -- sed -i '/^# Category9 Details/a Category9.Name=unsorted\nCategory9.DestDir=\nCategory9.Aliases=Unsorted*\nCategory9.Extensions=' /opt/nzbget/nzbget.conf
pct exec $CTID -- bash -c 'if [ -d "/mnt/downloads" ]; then sed -i 's#^Category8.DestDir=.*#Category9.DestDir=/mnt/downloads/usenet/complete/unsorted#' /opt/nzbget/nzbget.conf; fi'

# Setup Watch Folder
wget https://raw.githubusercontent.com/caronc/nzbget-dirwatch/master/DirWatch.py -P $TEMP_DIR
pct push $CTID $TEMP_DIR/DirWatch.py /opt/nzbget/scripts/DirWatch.py --group 65605 --user 1605
# # pct exec $CTID -- runuser media -c 'wget https://raw.githubusercontent.com/caronc/nzbget-dirwatch/master/DirWatch.py -P /opt/nzbget/scripts'
pct exec $CTID -- chmod +x /opt/nzbget/scripts/DirWatch.py
pct exec $CTID -- sed -i 's|^#WatchPaths=.*|WatchPaths=/mnt/public/autoadd/usenet/lazy?c=lazy, /mnt/public/autoadd/usenet/series?c=sonarr-series, /mnt/public/autoadd/usenet/movies?c=radarr-movies, /mnt/public/autoadd/usenet/music?c=lidarr-music, /mnt/public/autoadd/usenet/pron?c=pron, /mnt/public/autoadd/usenet/documentary?c=documentary, /mnt/public/autoadd/usenet/flexget-series?c=flexget-series, /mnt/public/autoadd/usenet/flexget-movies?c=flexget-movies, /mnt/public/autoadd/usenet/unsorted?c=unsorted|' /opt/nzbget/scripts/DirWatch.py
# pct exec $CTID -- bash -c 'echo -e "Task1.Time=*:05,*:15,*:25,*:35,*:45,*:55\nTask1.WeekDays=1-7\nTask1.Command=Script\nTask1.Param=DirWatch.py\nDirWatch.py:WatchPaths=/mnt/public/autoadd/usenet/lazy?c=lazy, /mnt/public/autoadd/usenet/series?c=sonarr-series, /mnt/public/autoadd/usenet/movies?c=radarr-movies, /mnt/public/autoadd/usenet/music?c=lidarr-music, /mnt/public/autoadd/usenet/pron?c=pron, /mnt/public/autoadd/usenet/documentary?c=documentary, /mnt/public/autoadd/usenet/flexget-series?c=flexget-series, /mnt/public/autoadd/usenet/flexget-movies?c=flexget-movies, /mnt/public/autoadd/usenet/unsorted?c=unsorted\nDirWatch.py:MaxArchiveSizeKB=150\nDirWatch.py:PollTimeSec=60\nDirWatch.py:AutoCleanup=no\nDirWatch.py:Debug=no\n" >> /opt/nzbget/nzbget.conf'