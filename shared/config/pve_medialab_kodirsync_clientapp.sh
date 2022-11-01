#!/bin/ash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_kodirsync_clientapp.sh
# Description:  Kodirsync script for Linux Kodi hosts
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# SSH account details
RSYNC_Username='ahuacate_kodirsync'

# SSH connection type
# 1 for HTTPS URL, 2 for LAN connection
SSH_ConnectType='1'
RSYNC_AddressIP='192.168.50.121'
RSYNC_AddressURL='ssh-site1.foo.bar'
RSYNC_SshPort='22'
SSLH_Port='443'
SSLH_Cert='sslh.crt'
SSLH_Key='sslh-kodirsync.key'

# SSH settings
SSH_ConnectTimeout='140'
SSH_ServerAliveInterval='15'
RSYNC_RetryCount='4'
RSYNC_RetrySleep='60'

# Storage settings
# 1 for disk based, 2 for folder based
DESTINATION_STORAGE_TYPE='1'
# Total allowed capacity for folder based storage only
STORAGE_FOLDER_CAP='100'
# % over-provisioning factor applied to storage capacity
STORAGE_PROV_FACTOR='95'
DESTINATION_DIR='/var/media/kodirsync'

# Empty or Orphaned Folders
# Movie, series, pron, documentary, musicvideo folder min size
DESTINATION_VIDEO_MINSIZE_DIR='5000'
# Photo, homevideo, music folder min size
DESTINATION_OTHER_MINSIZE_DIR='1000'

# File vars
TEMPFILE="${DESTINATION_DIR}/.rsync_lists/tempfile"
APP_DIR='/storage/kodirsync'
RSYNC_LISTS="${DESTINATION_DIR}/.rsync_lists"
mkdir -p ${RSYNC_LISTS}

#---- Other Variables --------------------------------------------------------------

# ENABLE: 0 for enabled, 1 for disabled
# MAX_SIZE : 0 for unlimited Gb, 1-99 for limit size in Gb
# Audio settings (audio books, podcasts etc)
AUDIO_ENABLED=1
AUDIO_DEST="$DESTINATION_DIR/audio"
AUDIO_SRC='~/audio'

# Documentary settings
DOCUMENTARY_ENABLED=0
DOCUMENTARY_HDR_ENABLED=0
DOCUMENTARY_MAX_SIZE=0
DOCUMENTARY_DEST="$DESTINATION_DIR/video/documentary"
DOCUMENTARY_SRC='~/video/documentary'

# Homevideo settings
HOMEVIDEO_ENABLED=1
HOMEVIDEO_HDR_ENABLED=0
HOMEVIDEO_MAX_SIZE=0
HOMEVIDEO_DEST="$DESTINATION_DIR/video/homevideo"
HOMEVIDEO_SRC='~/video/homevideo'

# Movies settings
MOVIES_ENABLED=0
MOVIES_HDR_ENABLED=1
MOVIES_MAX_SIZE=20 # (Gb)
MOVIES_DEST="$DESTINATION_DIR/video/movies"
MOVIES_SRC='~/video/movies'

# Music settings
MUSIC_ENABLED=0
MUSIC_DEST="$DESTINATION_DIR/music"
MUSIC_SRC='~/music'

# Music video settings
MUSICVIDEO_ENABLED=1
MUSICVIDEO_HDR_ENABLED=0
MUSICVIDEO_MAX_SIZE=0
MUSICVIDEO_DEST="$DESTINATION_DIR/video/musicvideo"
MUSICVIDEO_SRC='~/video/musicvideo'

# Photo settings
PHOTO_ENABLED=1
PHOTO_DEST="$DESTINATION_DIR/photo"
PHOTO_SRC='~/photo'

# Pron settings
PRON_ENABLED=1
PRON_HDR_ENABLED=0
PRON_MAX_SIZE=0
PRON_DEST="$DESTINATION_DIR/video/pron"
PRON_SRC='~/video/pron'

# Series settings (TV)
SERIES_ENABLED=0
SERIES_HDR_ENABLED=1
SERIES_MAX_SIZE=10
SERIES_DEST="$DESTINATION_DIR/video/series"
SERIES_SRC='~/video/series'

#---- Other Files ------------------------------------------------------------------

# Block keyword list (add any keyword to exclude from rsync downloads)
cat << 'EOF' > ${RSYNC_LISTS}/block_keyword_list
@eaDir
Thumbs.db
.DS_Store
#recycle
metadata
.stfolder
.stignore
EOF

# Log files
mkdir -p ${APP_DIR}/logs
NOW=$(date +"%F")
LOGFILE="$APP_DIR/logs/kodirsync-${NOW}.log"

#---- Dependencies -----------------------------------------------------------------

# Network check (1 is UP, other is down)
NETWORK_STATUS=$(ip route | grep "linkdown" > /dev/null; echo $?)

# Check destination storage
if [ ${DESTINATION_STORAGE_TYPE} = 1 ]; then 
  DESTINATION_FOLDER_STATUS=$(df | grep -q $DESTINATION_DIR > /dev/null; echo $?)
elif [ ${DESTINATION_STORAGE_TYPE} = 2 ]; then 
  DESTINATION_FOLDER_STATUS=$([ -d $DESTINATION_DIR ] && echo "0" || echo "1")
fi

# Disk or Folder storage capacity
if [ ${DESTINATION_STORAGE_TYPE} = 1 ]; then
 STORAGE_CAP=$(( (( $(df -P ${DESTINATION_DIR} | awk 'NR==2 {print $4}') + $(df -P ${DESTINATION_DIR} | awk 'NR==2 {print $3}') )) * 1024 * ${STORAGE_PROV_FACTOR}/100 ))
elif [ ${DESTINATION_STORAGE_TYPE} = 2 ] && [ ${STORAGE_FOLDER_CAP} -gt $(( (( $(df -P ${DESTINATION_DIR} | awk 'NR==2 {print $4}') + $(df -P ${DESTINATION_DIR} | awk 'NR==2 {print $3}') )) * 1024 * ${STORAGE_PROV_FACTOR}/100 )) ]; then
  STORAGE_CAP=$(( (( $(df -P ${DESTINATION_DIR} | awk 'NR==2 {print $4}') + $(df -P ${DESTINATION_DIR} | awk 'NR==2 {print $3}') )) * 1024 * ${STORAGE_PROV_FACTOR}/100 ))
elif [ ${DESTINATION_STORAGE_TYPE} = 2 ] && [ ${STORAGE_FOLDER_CAP} -lt $(( (( $(df -P ${DESTINATION_DIR} | awk 'NR==2 {print $4}') + $(df -P ${DESTINATION_DIR} | awk 'NR==2 {print $3}') )) * 1024 * ${STORAGE_PROV_FACTOR}/100 )) ]; then
  STORAGE_CAP=${DESTINATION_FOLDER_CAP}
fi

# Create Blacklist and Whitelist of files
function rsync_getcontrollist() {
  # Set source
  eval SOURCE=\$$(echo $MEDIA_TYPE | awk '{print toupper($0)}')_SRC
  # Get Global control list file from source
  i=0 CHECK_CODE=1
  while [ ${CHECK_CODE} != 0 ] && [ $i -le ${RSYNC_RetryCount} ]
  do
    i=$(($i+1))
    rsync -avz -e "${SSH_CMD}" ${RSYNC_Username}@${RSYNC_Address}:${SOURCE}/rsync_control_list_global-${MEDIA_TYPE}.txt ${RSYNC_LISTS}/rsync_control_list_global-${MEDIA_TYPE}.txt
    CHECK_CODE=$?
    if [ ${CHECK_CODE} != 0 ] && [ $i = ${RSYNC_RetryCount} ]; then
      echo -e "#---- WARNING - GET $(echo $MEDIA_TYPE | awk '{print toupper($0)}') GLOBAL CONTROL FILE\nError Code (${CHECK_CODE}) : $(date)\nFunction : ${SOURCE}/rsync_control_list_global-${MEDIA_TYPE}.txt\nRetry count : ${RSYNC_RetryCount}x failed attempts\n" >> ${LOGFILE}
      exit 1
    elif [ ${CHECK_CODE} != 0 ] && [ $i -lt ${RSYNC_RetryCount} ]; then
      sleep ${RSYNC_RetrySleep}
    elif [ ${CHECK_CODE} = 0 ]; then
      echo -e "#---- SUCCESS - GET $(echo $MEDIA_TYPE | awk '{print toupper($0)}') GLOBAL CONTROL FILE\nTime : $(date)\nFunction : ${RSYNC_LISTS}/rsync_control_list_global-${MEDIA_TYPE}.txt\n" >> ${LOGFILE}
    fi
  done
  # Get User control list file from source
  i=0 CHECK_CODE=1
  while [ ${CHECK_CODE} != 0 ] && [ $i -le ${RSYNC_RetryCount} ]
  do
    i=$(($i+1))
    rsync -avz -e "${SSH_CMD}" ${RSYNC_Username}@${RSYNC_Address}:~/rsync_control_list_user-${MEDIA_TYPE}.txt ${RSYNC_LISTS}/rsync_control_list_user-${MEDIA_TYPE}.txt
    CHECK_CODE=$?
    if [ ${CHECK_CODE} != 0 ] && [ $i = ${RSYNC_RetryCount} ]; then
      echo -e "#---- WARNING - GET $(echo $MEDIA_TYPE | awk '{print toupper($0)}') USER CONTROL FILE\nError Code (${CHECK_CODE}) : $(date)\nFunction : ~/rsync_control_list_user-${MEDIA_TYPE}.txt\nRetry count : ${RSYNC_RetryCount}x failed attempts\n" >> ${LOGFILE}
      exit 1
    elif [ ${CHECK_CODE} != 0 ] && [ $i -lt ${RSYNC_RetryCount} ]; then
      sleep ${RSYNC_RetrySleep}
    elif [ ${CHECK_CODE} = 0 ]; then
      echo -e "#---- SUCCESS - GET $(echo $MEDIA_TYPE | awk '{print toupper($0)}') USER CONTROL FILE\nTime : $(date)\nFunction : ${RSYNC_LISTS}/rsync_control_list_user-${MEDIA_TYPE}.txt\n" >> ${LOGFILE}
    fi
  done
  # Create Whitelist and Blacklist
  cat ${RSYNC_LISTS}/rsync_control_list_user-${MEDIA_TYPE}.txt ${RSYNC_LISTS}/rsync_control_list_global-${MEDIA_TYPE}.txt ${RSYNC_LISTS}/block_keyword_list | awk -v var1="$MEDIA_TYPE" -F'|' '($1 == "b" || $1 == "B") { print var1"/"$2 }' > ${RSYNC_LISTS}/blacklist_${MEDIA_TYPE}
  cat ${RSYNC_LISTS}/rsync_control_list_user-${MEDIA_TYPE}.txt ${RSYNC_LISTS}/rsync_control_list_global-${MEDIA_TYPE}.txt | awk -v var1="$MEDIA_TYPE" -F'|' '($1 == "w" || $1 == "W") { print var1"/"$2 }' > ${RSYNC_LISTS}/whitelist_${MEDIA_TYPE}
  # Create enabled category list
  echo "${MEDIA_TYPE}" >> ${RSYNC_LISTS}/enabled_category_list
}


# Rsync to create list of dir files
function rsync_filelist() {
  # Set source
  eval SOURCE=\$$(echo $MEDIA_TYPE | awk '{print toupper($0)}')_SRC
  # Create rsync list
  i=0 CHECK_CODE=1
  while [ ${CHECK_CODE} != 0 ] && [ $i -le ${RSYNC_RetryCount} ]
  do
    i=$(($i+1))
    rsync -r -t --no-links --list-only --min-size='1' --exclude '*.partial~' --exclude '#recycle' --exclude-from ${RSYNC_LISTS}/blacklist_${MEDIA_TYPE} --prune-empty-dirs -e "${SSH_CMD}" ${RSYNC_Username}@${RSYNC_Address}:${SOURCE} > $TEMPFILE
    CHECK_CODE=$?
    if [ ${CHECK_CODE} != 0 ] && [ $i = ${RSYNC_RetryCount} ]; then
      echo -e "#---- WARNING - RSYNC LIST ONLY\nError Code (${CHECK_CODE}) : $(date)\nFunction : ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01\nRetry count : ${RSYNC_RetryCount}x failed attempts\n" >> ${LOGFILE}
      exit 1
    elif [ ${CHECK_CODE} != 0 ] && [ $i -lt ${RSYNC_RetryCount} ]; then
      sleep ${RSYNC_RetrySleep}
    elif [ ${CHECK_CODE} = 0 ]; then
      cat ${TEMPFILE} | grep -vi "rsync_control_list_global-${MEDIA_TYPE}.txt" | grep -vi -f "${RSYNC_LISTS}/block_keyword_list" | cut -d' ' -f2- | sed 's/^ *//' | awk -F' ' '{OFS=FS}{gsub(/\//,"-",$2); print}' | sed 's/ /|/;s/ /#/;s/ /|/' | sed 's/#/ /' | awk -F '|' '{printf $1 "|" $3 "|";system("date +\x27%s\x27 -d \x27"$2"\x27")}' | awk -F '|' '{OFS = FS;print $2, $3, $1}' | awk -F'|' '{OFS = FS;gsub(/\,|\;/,"",$3)}1' | sed "/^${MEDIA_TYPE}|\.*/d;/^${MEDIA_TYPE}s|\.*/d" | sed "s#^${MEDIA_TYPE}#$(echo $SOURCE | sed "s#^~/##g")#g" > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01
      echo -e "#---- SUCCESS - RSYNC LIST ONLY\nTime : $(date)\nFunction : ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01\n" >> ${LOGFILE}
    fi
  done
}

#---- Body -------------------------------------------------------------------------

# Start Job
echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $LOGFILE

# Check Client & Server status
# Check LAN status
RSYNC_SERVER_STATUS_IP=$(ssh -q -i ~/.ssh/${RSYNC_Username}_id_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p ${RSYNC_SshPort} ${RSYNC_Username}@${RSYNC_AddressIP} "echo $? 2>&1")
# Check SSH server status
if [ ${SSH_ConnectType} = 1 ] && [ ${NETWORK_STATUS} = 1 ] && [ ${DESTINATION_FOLDER_STATUS} = 0 ]; then
  # Check SSLH status
  RSYNC_SERVER_STATUS_URL=$(ssh -q -i ~/.ssh/${RSYNC_Username}_id_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ProxyCommand="openssl s_client -quiet -connect ${RSYNC_AddressURL}:${SSLH_Port} -servername kodirsync.${RSYNC_AddressURL} -cert ~/.ssh/sslh.crt -key ~/.ssh/sslh-kodirsync.key" ${RSYNC_Username}@kodirsync.localdomain "echo $? 2>&1")
  if [ ${RSYNC_SERVER_STATUS_IP} = 0 ]; then
    SSH_ConnectTypeSet=2
    echo -e "#---- SUCCESS - CHECKING NETWORK AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 2 [LAN connection ${RSYNC_AddressIP}:${RSYNC_SshPort}]\n" >> ${LOGFILE}
  elif [ ${RSYNC_SERVER_STATUS_URL} = 0 ] && [ ${RSYNC_SERVER_STATUS_IP} != 0 ]; then
    SSH_ConnectTypeSet=1
    echo -e "#---- SUCCESS - CHECKING NETWORK AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC set to use Type 1 [HTTPS connection ${RSYNC_AddressURL}:${SSLH_Port}]\n" >> ${LOGFILE}
  elif [ ${RSYNC_SERVER_STATUS_URL} != 0 ] && [ ${RSYNC_SERVER_STATUS_IP} != 0 ]; then
    SSH_ConnectTypeSet=0
    echo -e "#---- WARNING - RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connections fail. [HTTPS and LAN]\n" >> ${LOGFILE}
  fi
elif [ ${SSH_ConnectType} = 2 ] && [ ${NETWORK_STATUS} = 1 ] && [ ${DESTINATION_FOLDER_STATUS} = 0 ]; then
  if [ ${RSYNC_SERVER_STATUS_IP} = 0 ]; then
    SSH_ConnectTypeSet=2
    echo -e "#---- SUCCESS - CHECKING NETWORK AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC set to use Type 2 [LAN connection ${RSYNC_AddressIP}:${RSYNC_SshPort}]\n" >> ${LOGFILE}
  elif [ ${RSYNC_SERVER_STATUS_IP} != 0 ]; then
    SSH_ConnectTypeSet=0
    echo -e "#---- WARNING - RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC LAN connections fail. [LAN connection ${RSYNC_AddressIP}:${RSYNC_SshPort}]\n" >> ${LOGFILE}
  fi
fi
# Check Destination folder
if [ ${DESTINATION_FOLDER_STATUS} != 0 ]; then
  echo -e "#---- WARNING - DESTINATION STORAGE FAILURE\nFail date : $(date)\n" >> ${LOGFILE}
fi
# Fail exit
if [ ${NETWORK_STATUS} != 1 ]; then
  echo -e "#---- WARNING - NETWORK FAIL\nFail date : $(date)\n" >> ${LOGFILE}
  echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $LOGFILE
  exit 1
elif [ ${NETWORK_STATUS} = 1 ] && [ ${SSH_ConnectTypeSet} = 0 ] || [ ${DESTINATION_FOLDER_STATUS} != 0 ]; then
  echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $LOGFILE
  exit 1
else
  echo -e "Good to Go. Proceeding...\n"
fi

# Set SSH connection script
if [ ${SSH_ConnectTypeSet} = 1 ]; then
  SSH_CMD="ssh -i ~/.ssh/${RSYNC_Username}_id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=${SSH_ConnectTimeout} -o ServerAliveInterval=${SSH_ServerAliveInterval} ProxyCommand="openssl s_client -quiet -connect ${RSYNC_AddressURL}:${SSLH_Port} -servername kodirsync.${RSYNC_AddressURL} -cert ~/.ssh/sslh.crt -key ~/.ssh/sslh-kodirsync.key""
  RSYNC_Address='kodirsync.localdomain'
elif [ ${SSH_ConnectTypeSet} = 2 ]; then
  SSH_CMD="ssh -i ~/.ssh/${RSYNC_Username}_id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=${SSH_ConnectTimeout} -o ServerAliveInterval=${SSH_ServerAliveInterval} -p ${RSYNC_SshPort}"
  RSYNC_Address=${RSYNC_AddressIP}
fi

# Cleanup old list files
find ${RSYNC_LISTS}/ ! -name 'block_keyword_list' -type f -exec rm -f {} +

#---- Input List - Audio
if [ ${AUDIO_ENABLED} = 0 ]; then
  MEDIA_TYPE=audio # Must be lowercase
  # Check destination folder
  mkdir -p ${AUDIO_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create list of media files
  rsync_filelist
  cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
fi

#---- Input List - Documentary
if [ ${DOCUMENTARY_ENABLED} = 0 ]; then
  MEDIA_TYPE=documentary # Must be lowercase
  # Check destination folder
  mkdir -p ${DOCUMENTARY_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create list of media files
  rsync_filelist

  # Check for oversized media
  if [ ${DOCUMENTARY_MAX_SIZE} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | awk -F'|' -v max="$((${DOCUMENTARY_MAX_SIZE} * 1073741824))" '$3 >= max' | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Check for HDR media
  if [ ${DOCUMENTARY_HDR_ENABLED} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | grep -i "hdr" | awk '!seen[$0]++' >> ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Prune oversized and/or HDR media, remove duplicates & file extensions
  if [ ${DOCUMENTARY_HDR_ENABLED} != 0 ] || [ ${DOCUMENTARY_MAX_SIZE} != 0 ]; then
    # Remove duplicates & file extensions
    awk -F'|' '{OFS = FS} {gsub(/\.[a-z]+$/,"",$1)}1 {print $1}' ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp
    mv ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
    # Prune oversized and/or HDR media
    grep -Fwisv -f ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 > ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  else
    cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  fi
fi

#---- Input List - Homevideo
if [ ${HOMEVIDEO_ENABLED} = 0 ]; then
  MEDIA_TYPE=homevideo # Must be lowercase
  # Check destination folder
  mkdir -p ${HOMEVIDEO_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create file list from server
  rsync_filelist

  # Check for oversized media
  if [ ${HOMEVIDEO_MAX_SIZE} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | awk -F'|' -v max="$((${HOMEVIDEO_MAX_SIZE} * 1073741824))" '$3 >= max' | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Check for HDR media
  if [ ${HOMEVIDEO_HDR_ENABLED} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | grep -i "hdr" | awk '!seen[$0]++' >> ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Prune oversized and/or HDR media, remove duplicates & file extensions
  if [ ${HOMEVIDEO_HDR_ENABLED} != 0 ] || [ ${HOMEVIDEO_MAX_SIZE} != 0 ]; then
    # Remove duplicates & file extensions
    awk -F'|' '{OFS = FS} {gsub(/\.[a-z]+$/,"",$1)}1 {print $1}' ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp
    mv ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
    # Prune oversized and/or HDR media
    grep -Fwisv -f ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 > ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  else
    cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  fi
fi

#---- Input List - Movies
if [ ${MOVIES_ENABLED} = 0 ]; then
  MEDIA_TYPE=movies # Must be lowercase
  # Check destination folder
  mkdir -p ${MOVIES_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create list of media files
  rsync_filelist

  # Check for oversized media
  if [ ${MOVIES_MAX_SIZE} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | awk -v max="$((${MOVIES_MAX_SIZE} * 1073741824))" -F'|' '$3 >= max' | sed 's|\(.*\)/.*|\1|' | awk '!seen[$0]++' >> ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Check for HDR media
  if [ ${MOVIES_HDR_ENABLED} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | grep -i "hdr" | sed 's|\(.*\)/.*|\1|' | awk '!seen[$0]++' >> ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
    # Remove duplicates
    awk '!seen[$0]++' ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp
    mv ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Prune oversized and/or HDR media
  if [ ${MOVIES_HDR_ENABLED} != 0 ] || [ ${MOVIES_MAX_SIZE} != 0 ]; then
    grep -Fwisv -f ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 > ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  else
    cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  fi
fi

#---- Input List - Music
if [ ${MUSIC_ENABLED} = 0 ]; then
  MEDIA_TYPE=music # Must be lowercase
  # Check destination folder
  mkdir -p ${MUSIC_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create list of media files
  rsync_filelist
  cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
fi

#---- Input List - Musicvideo
if [ ${MUSICVIDEO_ENABLED} = 0 ]; then
  MEDIA_TYPE=musicvideo # Must be lowercase
  # Check destination folder
  mkdir -p ${MUSICVIDEO_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create list of media files
  rsync_filelist

  # Check for oversized media
  if [ ${MUSICVIDEO_MAX_SIZE} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | awk -F'|' -v max="$((${MUSICVIDEO_MAX_SIZE} * 1073741824))" '$3 >= max' | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Check for HDR media
  if [ ${MUSICVIDEO_HDR_ENABLED} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | grep -i "hdr" | awk '!seen[$0]++' >> ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Prune oversized and/or HDR media, remove duplicates & file extensions
  if [ ${MUSICVIDEO_HDR_ENABLED} != 0 ] || [ ${MUSICVIDEO_MAX_SIZE} != 0 ]; then
    # Remove duplicates & file extensions
    awk -F'|' '{OFS = FS} {gsub(/\.[a-z]+$/,"",$1)}1 {print $1}' ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp
    mv ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
    # Prune oversized and/or HDR media
    grep -Fwisv -f ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 > ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  else
    cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  fi
fi

#---- Input List - Photo
if [ ${PHOTO_ENABLED} = 0 ]; then
  MEDIA_TYPE=photo # Must be lowercase
  # Check destination folder
  mkdir -p ${PHOTO_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create list of media files
  rsync_filelist
  cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
fi

#---- Input List - Pron
if [ ${PRON_ENABLED} = 0 ]; then
  MEDIA_TYPE=pron # Must be lowercase
  # Check destination folder
  mkdir -p ${PRON_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create list of media files
  rsync_filelist

  # Check for oversized media
  if [ ${PRON_MAX_SIZE} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | awk -F'|' -v max="$((${PRON_MAX_SIZE} * 1073741824))" '$3 >= max' | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Check for HDR media
  if [ ${PRON_HDR_ENABLED} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | grep -i "hdr" | awk '!seen[$0]++' >> ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Prune oversized and/or HDR media, remove duplicates & file extensions
  if [ ${PRON_HDR_ENABLED} != 0 ] || [ ${PRON_MAX_SIZE} != 0 ]; then
    # Remove duplicates & file extensions
    awk -F'|' '{OFS = FS} {gsub(/\.[a-z]+$/,"",$1)}1 {print $1}' ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp
    mv ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
    # Prune oversized and/or HDR media
    grep -Fwisv -f ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 > ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  else
    cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  fi
fi

#---- Input List - Series
if [ ${SERIES_ENABLED} = 0 ]; then
  MEDIA_TYPE=series # Must be lowercase
  # Check destination folder
  mkdir -p ${SERIES_DEST}

  # Create Blacklist and Whitelist of files
  rsync_getcontrollist

  # Create list of media files
  rsync_filelist

  # Check for oversized media
  if [ ${SERIES_MAX_SIZE} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | awk -F'|' -v max="$((${SERIES_MAX_SIZE} * 1073741824))" '$3 >= max' | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Check for HDR media
  if [ ${SERIES_HDR_ENABLED} != 0 ]; then
    cat ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 | grep -i "hdr" | awk '!seen[$0]++' >> ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
  fi

  # Prune oversized and/or HDR media, remove duplicates & file extensions
  if [ ${SERIES_HDR_ENABLED} != 0 ] || [ ${SERIES_MAX_SIZE} != 0 ]; then
    # Remove duplicates & file extensions
    awk -F'|' '{OFS = FS} {gsub(/\.[a-z]+$/,"",$1)}1 {print $1}' ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist | awk '!seen[$0]++' > ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp
    mv ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist.tmp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist
    # Prune oversized and/or HDR media
    grep -Fwisv -f ${RSYNC_LISTS}/input_${MEDIA_TYPE}_prunelist ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 > ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  else
    cp ${RSYNC_LISTS}/input_${MEDIA_TYPE}_var01 ${RSYNC_LISTS}/input_${MEDIA_TYPE}
  fi
fi

#---- Processing and assembly of input lists
if [ "${NETWORK_STATUS}" == 1 ] && [ "${DESTINATION_FOLDER_STATUS}" == 0 ]; then
while read F1; do
  cat ${RSYNC_LISTS}/input_${F1} >> ${RSYNC_LISTS}/input_all_var01
  cat ${RSYNC_LISTS}/input_${F1} | grep -i -f "${RSYNC_LISTS}/whitelist_${F1}" >> ${RSYNC_LISTS}/whitelist_all_var01
done < ${RSYNC_LISTS}/enabled_category_list
fi

# Remove blacklisted folders and files from destination
while read F1; do
  if [ ${F1} == 'documentary' ] || [ ${F1} == 'homevideo' ] || [ ${F1} == 'movies' ] || [ ${F1} == 'musicvideo' ] || [ ${F1} == 'pron' ] || [ ${F1} == 'series' ]; then
    find "${DESTINATION_DIR}/video/${F1}" -type d | grep -Fx -v "${DESTINATION_DIR}/video/${F1}" | fgrep -i -f "${RSYNC_LISTS}/blacklist_${F1}" >> ${RSYNC_LISTS}/blacklist_remove_dirlist
    find "${DESTINATION_DIR}/video/${F1}" -type f | grep -Fx -v "${DESTINATION_DIR}/video/${F1}" | fgrep -i -f "${RSYNC_LISTS}/blacklist_${F1}" >> ${RSYNC_LISTS}/blacklist_remove_filelist
  elif [ ${F1} == 'audio' ] || [ ${F1} == 'music' ] || [ ${F1} == 'photo' ]; then
    find "${DESTINATION_DIR}/${F1}" -type d | grep -Fx -v "${DESTINATION_DIR}/${F1}" | grep -i -f "${RSYNC_LISTS}/blacklist_${F1}" >> ${RSYNC_LISTS}/blacklist_remove_dirlist
    find "${DESTINATION_DIR}/${F1}" -type f | grep -Fx -v "${DESTINATION_DIR}/${F1}" | grep -i -f "${RSYNC_LISTS}/blacklist_${F1}" >> ${RSYNC_LISTS}/blacklist_remove_filelist
  fi
done < ${RSYNC_LISTS}/enabled_category_list
# Delete blacklisted files from destination
if [ $(cat ${RSYNC_LISTS}/blacklist_remove_filelist | wc -l) -gt 0 ]; then
  while read F1; do
    rm -f "${F1}" 2> /dev/null
  done < ${RSYNC_LISTS}/blacklist_remove_filelist
fi
# Delete blacklisted folders from destination
if [ $(cat ${RSYNC_LISTS}/blacklist_remove_dirlist | wc -l) -gt 0 ]; then
  while read F1; do
    rm -R "${F1}" 2> /dev/null
  done < ${RSYNC_LISTS}/blacklist_remove_dirlist
fi

# Update rsync download file lists
if [ "$(cat ${RSYNC_LISTS}/whitelist_all_var01 | wc -l)" = 0 ]; then
  cat ${RSYNC_LISTS}/input_all_var01 | fgrep -i -v -f "${RSYNC_LISTS}/whitelist_all_var01" | sort -t '|' -k2 -n -r | awk -v storage_cap="$(( ${STORAGE_CAP} - 0 ))" -F'|' '{ i+=$3; if ( i < storage_cap ) { print $1 }}' > ${RSYNC_LISTS}/input_all
else
  cat ${RSYNC_LISTS}/input_all_var01 | fgrep -i -v -f "${RSYNC_LISTS}/whitelist_all_var01" | sort -t '|' -k2 -n -r | awk -v storage_cap="$(( ${STORAGE_CAP} - $(awk -F'|' '{sum+=$3;} END{print sum;}' ${RSYNC_LISTS}/whitelist_all_var01) ))" -F'|' '{ i+=$3; if ( i < storage_cap ) { print $1 }}' > ${RSYNC_LISTS}/input_all
fi
if [ "$(cat ${RSYNC_LISTS}/whitelist_all_var01 | wc -l)" = 0 ]; then
  cat ${RSYNC_LISTS}/whitelist_all_var01 | awk -v storage_cap="$(( ${STORAGE_CAP} - 0 ))" -F'|' '{ i+=$3; if ( i < storage_cap ) { print $1 }}' >> ${RSYNC_LISTS}/input_all
elif [ $(( ${STORAGE_CAP} - $(awk -F'|' '{sum+=$3;} END{print sum;}' ${RSYNC_LISTS}/whitelist_all_var01) )) -gt 0 ]; then
  cat ${RSYNC_LISTS}/whitelist_all_var01 | awk -v storage_cap="$(( ${STORAGE_CAP} - $(awk -F'|' '{sum+=$3;} END{print sum;}' ${RSYNC_LISTS}/whitelist_all_var01) ))" -F'|' '{ i+=$3; if ( i < storage_cap ) { print $1 }}' >> ${RSYNC_LISTS}/input_all
elif [ $(( ${STORAGE_CAP} - $(awk -F'|' '{sum+=$3;} END{print sum;}' ${RSYNC_LISTS}/whitelist_all_var01) )) -lt 0 ]; then
  cat ${RSYNC_LISTS}/whitelist_all_var01 | awk -v storage_cap="${STORAGE_CAP}" -F'|' '{ i+=$3; if ( i < storage_cap ) { print $1 }}' >> ${RSYNC_LISTS}/input_all
fi

# Delete non-current files
while read F1; do
  if [ ${F1} == 'documentary' ] || [ ${F1} == 'homevideo' ] || [ ${F1} == 'movies' ] || [ ${F1} == 'musicvideo' ] || [ ${F1} == 'pron' ]; then
    find "${DESTINATION_DIR}/video/${F1}" -type f | grep -Fx -v "${DESTINATION_DIR}/video/${F1}" | fgrep -i -v -f "${RSYNC_LISTS}/input_all" >> ${RSYNC_LISTS}/excluded_remove_filelist
    echo ${F1}
  elif [ ${F1} == 'audio' ] || [ ${F1} == 'music' ] || [ ${F1} == 'photo' ]; then
    find "${DESTINATION_DIR}/${F1}" -type f | grep -Fx -v "${DESTINATION_DIR}/${F1}" | fgrep -i -v -f "${RSYNC_LISTS}/input_all" >> ${RSYNC_LISTS}/excluded_remove_filelist
    echo ${F1}
  fi
done < ${RSYNC_LISTS}/enabled_category_list


if [ $(cat ${RSYNC_LISTS}/excluded_remove_filelist | wc -l) -gt 0 ]; then
  while read F1; do
    rm "${F1}" 2> /dev/null
  done < ${RSYNC_LISTS}/excluded_remove_filelist
fi


#---- Perform rsync task
# Run rsync task on 'input_all' list
# if [ ${SSH_ConnectType} = 1 ]; then

# elif [ ${SSH_ConnectType} = 2 ]; then
echo -e "#---- ACTION - RSYNC TASK ONLY\nTime : $(date)\nRsync list : ${RSYNC_LISTS}/input_all\n" >> ${LOGFILE}
rsync -av -e "${SSH_CMD}" --progress  --human-readable --partial --delete --inplace --exclude '*.partial~' --delete-excluded --log-file=$LOGFILE --files-from=${RSYNC_LISTS}/input_all --relative ${RSYNC_Username}@${RSYNC_Address}:~/ ${DESTINATION_DIR} 2>> ${LOGFILE}
# fi

#---- Clean up
# Remove destination empty and orphaned folders
while read F1; do
  if [ ${F1} == 'documentary' ] || [ ${F1} == 'movies' ] || [ ${F1} == 'musicvideo' ] || [ ${F1} == 'pron' ] || [ ${F1} == 'series' ]; then
    find "${DESTINATION_DIR}/video/${F1}" -mindepth 1 -type d -exec du {} + | awk -v destination_video_minsize_dir="${DESTINATION_VIDEO_MINSIZE_DIR}" '$1 <= destination_video_minsize_dir' | cut -f 2- | sed 's/^/"/;s/$/"/' | xargs rm -Rf 2> /dev/null
  elif [ ${F1} == 'audio' ] || [ ${F1} == 'music' ] || [ ${F1} == 'photo' ] || [ ${F1} == 'homevideo' ]; then
    find "${DESTINATION_DIR}/${F1}" -mindepth 1 -type d -exec du {} + | awk -v destination_other_minsize_dir="${DESTINATION_OTHER_MINSIZE_DIR}" '$1 <= destination_other_minsize_dir' | cut -f 2- | sed 's/^/"/;s/$/"/' | xargs rm -Rf 2> /dev/null
  elif [ ${F1} == 'homevideo' ]; then
    find "${DESTINATION_DIR}/video/${F1}" -mindepth 1 -type d -exec du {} + | awk -v destination_other_minsize_dir="${DESTINATION_OTHER_MINSIZE_DIR}" '$1 <= destination_other_minsize_dir' | cut -f 2- | sed 's/^/"/;s/$/"/' | xargs rm -Rf 2> /dev/null
  fi
done < ${RSYNC_LISTS}/enabled_category_list

# Prune log files older than 14 days
find ${APP_DIR}/logs -name "*.log" -type f -mtime +14 -delete

#---- Finish Line
echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $LOGFILE