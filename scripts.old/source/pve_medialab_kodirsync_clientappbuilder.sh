#!/bin/ash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_kodirsync_clientappbuilder.sh
# Description:  Installer script for configuring Kodirsync client
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_kodirsync_clientappbuilder.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your devices internet connection and try again..."
  echo
  exit 0
fi

# Terminal
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'
printf '\033[8;40;120t'

# Bash Messaging Functions
function warn() {
  local REASON="\e[97m$1\e[39m"
  local FLAG="\e[93m[WARNING]\e[39m"
  msg "$FLAG $REASON"
}
function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg "$FLAG $REASON"
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function indent() {
  sed 's/^/  /';
}
# Cleanup
function cleanup() {
  cd ..
  rm -rf $TEMP_DIR
  cd ~
  unset TEMP_DIR
}

# Set Temp Folder
if [ -z "${TEMP_DIR+x}" ]; then
  TEMP_DIR=$(mktemp -d)
  cd $TEMP_DIR >/dev/null
else
  if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR >/dev/null
  fi
fi

#---- Static Variables -------------------------------------------------------------

# OS Type
OSTYPE=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)

# Mount Point
if [ ${OSTYPE} = '"coreelec"' ] || [ ${OSTYPE} = '"libreelec"' ]; then
  MOUNT_POINT='/var/media/kodirsync'
  APP_DIR='/storage/kodirsync'
else
  MOUNT_POINT='/mnt/kodirsync'
  APP_DIR='/usr/local/bin/kodirsync'
fi

# Disk format type
DISK_FORMAT_TYPE='ext4'

#---- Other Variables --------------------------------------------------------------

# SSH account details
RSYNC_Username='renmark_kodirsync'

# Disk Over-Provisioning
DISK_OP_SSD=15
DISK_OP_ROT=0

#---- Other Files ------------------------------------------------------------------

# Required Kodirsync Media Folders
cat << 'EOF' > kodi_sync_folder_list
audio|audio
documentary|video/documentary
homevideo|video/homevideo
movies|video/movies
music|music
musicvideo|video/musicvideo
photo|photo
pron|video/pron
series|video/series
EOF

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Wake USB disk
blkid -o device | grep '^/dev/sd*' | sed 's/[0-9]*//g' | awk '!seen[$0]++' > wake_usb_list
while IFS= read -r line; do
  dd if=${line} of=/dev/null count=512 status=none
done < wake_usb_list

# Check for base folders
if ! [ -d ${APP_DIR} ] && [ ${OSTYPE} = '"coreelec"' ] || [ ${OSTYPE} = '"libreelec"' ]; then
  msg "Creating default script folder..."
  info "Default Kodirsync script folder : ${WHITE}${APP_DIR}${NC}"
  mkdir -p ${APP_DIR}
  chmod 775 ${APP_DIR}
  echo
elif ! [ -d ${APP_DIR} ] && [ ${OSTYPE} != '"coreelec"' ] || [ ${OSTYPE} != '"libreelec"' ]; then
  msg "Creating default script folder..."
  info "Default Kodirsync script folder : ${WHITE}${APP_DIR}${NC}"
  mkdir -p ${APP_DIR}
  echo
fi

# Check for existing Installations 
if [ $(crontab -l | grep -q 'sh ${APP_DIR}/pve_medialab_kodirsync_clientappbuilder.sh' > /dev/null; echo $?) = 0 ]; then
  msg "A Kodirsync installation already exists. Your options are:"
  echo -e "Re-install : Complete reinstall of Kodirsync.\nUninstall : Remove Kodirsync from your hardware.\nAbort : Exit this installation." > proceed_menu
  LINE_CNT=$(cat proceed_menu | wc -l)
  echo
  i=1
  while IFS=':' read -r f1 f2; do
    printf "%-2s  %-s %-s\n" ${i}')'   "${YELLOW}$f1${NC}" "- $f2"
    i=$(($i + 1))
  done < proceed_menu
  unset i
  echo
  msg "Identify the procedure you want to use..."
  while true; do
    read -p "Select your choice by entering a line number (entering numeric) : " -n 1 -r check
    echo
    if [ "$check" -le "${LINE_CNT}" ] && [ "$check" -ne 0 ]; then
      BUILD_TYPE=$check
      if [ ${BUILD_TYPE} = 1 ]; then
        info "You have chosen to perform a : ${YELLOW}Re-install Kodirsync${NC}"
        echo
      elif [ ${BUILD_TYPE}= 2 ]; then
        info "You have chosen to : ${YELLOW}Uninstall Kodirsync${NC}"
        echo
      elif [ ${BUILD_TYPE} = 3 ]; then
        warn "You have chosen to skip this installation. Aborting in 2 seconds..."
        sleep 2
        exit 1
      fi
      break
    elif [ -z "${check##*[!0-9]*}" ] || [ -z "${check2##*[!0-9]*}" ]; then
      warn "There are issues with your entry:\n1. Your entry is invalid. Numerics only.\n   Please try again..."
    elif [ "$check" -gt "${LINE_CNT}" ] || [ "$check" = 0 ] && [ -z "${check##*[0-9]*}" ]; then
      warn "There are issues with your entry:\n1. Your entry line number does not match a option line number.\n   Please try again..."
    fi
  done
else
  BUILD_TYPE=0
fi

# Removing old installation files
if [ ${BUILD_TYPE} = 1 ] || [ ${BUILD_TYPE} = 2 ]; then
  msg "Modifying existing Kodirsync installation..."
  rm -R ${APP_DIR} > /dev/null
  crontab -u root -l | grep -v 'sh ${APP_DIR}/pve_medialab_kodirsync_clientapp.sh' | crontab -u root - 2> /dev/null # Remove Kodirsync cron tasks
  info "Kodirsync crontab status : ${YELLOW}deleted${NC}"
  rm ~/.ssh/*_kodirsync_id_ed25519 > dev/null
  rm ~/.ssh/sslh* > dev/null
  if [ $(df -h 2> /dev/null | awk 'NR > 1 { print $6}' | grep ${MOUNT_POINT} > /dev/null; echo $?) = 0 ] && [ ${OSTYPE} = '"coreelec"' ] || [ ${OSTYPE} = '"libreelec"' ]; then
    umount -l ${MOUNT_POINT}
    info "Kodirsync disk mount ${MOUNT_POINT} : ${YELLOW}umounted${NC}"
  elif [ $(df -h 2> /dev/null | awk 'NR > 1 { print $6}' | grep ${MOUNT_POINT} > /dev/null; echo $?) = 0 ] && [ ${OSTYPE} != '"coreelec"' ] || [ ${OSTYPE} != '"libreelec"' ]; then
    umount ${MOUNT_POINT}
    sed -i "\@${MOUNT_POINT}@d" /etc/fstab 2> /dev/null
    info "Kodirsync disk mount ${MOUNT_POINT} : ${YELLOW}umounted${NC} (modified /etc/fstab)"
  fi
  echo
fi
# Uninstall exit
if [ ${BUILD_TYPE} = 2 ]; then
  msg "Kodirsync has been uninstalled and removed from this machine.\nTo re-install simply run this script again. Exiting in 2 seconds..."
  sleep 2
  exit 1
fi

#---- Select a new installation type - Disk or Folder based
msg "You must select your Kodirsync destination storage type.\n\n1)  Disk Based - Select a storage device, either SATA, eSATA or USB connected, for\nuse as a dedicated media storage device. Our  will destroy all existing\ndata on this device and reformat the disk to Linux ext4. The whole disk is used as\ndedicated media storage. (Recommended)\n\n2)  Folder Based - Select a storage folder on your machine to be used by .\nThis folder should be located on a storage disk with adequate capacity for your\nmedia requirements. You will be prompted to enter a full directory path expressed\nin the Linux format. For example, '/storage' or '/mnt/media'."
echo
echo -e "Disk Based: Dedicate a whole disk for media storage.\nFolder Based: Select a folder location for media storage.\nAbort: Exit this installation." > proceed_menu
LINE_CNT=$(cat proceed_menu | wc -l)
echo
i=1
while IFS=':' read -r f1 f2; do
  printf "%-2s  %-s %-s\n" ${i}')'   "${YELLOW}$f1${NC}" "- $f2"
  i=$(($i + 1))
done < proceed_menu
unset i
echo
msg "Identify the type of storage you want to use..."
while true; do
  read -p "Select your choice by entering a line number (entering numeric) : " -n 1 -r check
  echo
  if [ "$check" -le "${LINE_CNT}" ] && [ "$check" -ne 0 ]; then
    STORAGE_TYPE=$check
    if [ ${STORAGE_TYPE} = 1 ]; then
      info "Your selected Kodirsync storage type is : ${YELLOW}Disk based${NC}"
      echo
    elif [ ${STORAGE_TYPE} = 2 ]; then
      info "Your selected Kodirsync storage type is : ${YELLOW}Folder based${NC}"
      echo
    elif [ ${STORAGE_TYPE} = 3 ]; then
      warn "You have chosen to skip this installation. Aborting in 2 seconds..."
      sleep 2
      exit 1
    fi
    break
  elif [ -z "${check##*[!0-9]*}" ]; then
    warn "There are issues with your entry:\n1. Your entry is invalid. Numerics only.\n   Please try again..."
  elif [ "$check" -gt "${STORAGE_CNT}" ] || [ "$check" = 0 ] && [ -z "${check##*[0-9]*}" ]; then
    warn "There are issues with your entry:\n1. Your entry line number does not match a option line number.\n   Please try again..."
  fi
done

# Select storage - Disk based
if [ ${STORAGE_TYPE} = 1 ]; then
  blkid -o device | grep '^/dev/sd*' | sed 's/[0-9]*//g' | awk '!seen[$0]++' > dev_list_all
  while read -r dev; do
    echo "$dev:$(hdparm -I $dev 2> /dev/null | grep 'Model Number:' | sed 's/Model Number://' | sed -e 's/^[ \t]*//' | sed 's/ *$//'):$(hdparm -I $dev 2> /dev/null | awk -F"[()]" '/device size with M \= 1000\*1000:/ { print $2 }' | sed 's/ //g'):$(blkid -s UUID -o value $dev 2> /dev/null):$(df -h $dev 2> /dev/null | awk 'NR > 1 { print $6}')" >> dev_list_var01
  done < dev_list_all
  # Prune System disks
  cat dev_list_var01 | awk -F':' '($5 != "/" && $5 != "/dev" && $5 != "/flash" && $5 != "/storage" && $5 != "/dev/shm" && $5 != "/var" && $5 !~ "^/etc" && $5 !~ "^/rpool") {print $0}' > dev_list_var02
  # Select from disk list
  msg "Detecting available disk storage devices..."
  echo
  STORAGE_CNT="$(cat dev_list_var02 | wc -l)"
  if [ ${STORAGE_CNT} -eq 0 ]; then
    warn "Cannot detect any available storage disks. Check your SATA, PCIe or\nUSB device is connected and re-run this script. Or add a 'Folder Based'\nstorage location. Exiting this installation script..."
    sleep 2
    exit 1
  elif [ ${STORAGE_CNT} -ge 1 ]; then
    # Select new disk UUID
    LEN2=$(awk -F':' 'BEGIN{mn=0;} {n=length($2);mn=mn>n?mn:n;}END{print mn}' dev_list_var02)
    LEN3=$(awk -F':' 'BEGIN{mn=0;} {n=length($3);mn=mn>n?mn:n;}END{print mn}' dev_list_var02)
    printf "%-2s %-"${LEN2}"s  %-"${LEN3}"s  %-s\n" '   '  'DISK ID' 'SIZE' 'DEVICE ID'
    i=1
    while IFS=':' read -r F1 F2 F3 F4 F5; do
      printf "%-2s  %-"${LEN2}"s  %-"${LEN3}"s  %s\n" ${YELLOW}${i}${NC}')'  $F2  $F3  $F1
      i=$(($i + 1))
    done < dev_list_var02
    unset i
    echo
    msg "Identify the hard disk which you want to use..."
    while true; do
      read -p "Select a disk by entering a line number (entering numeric) : " -n 1 -r check
      echo
      read -p "Retype the same line number (enter numeric again) : " -n 1 -r check2
      echo
      if [ "$check" = "$check2" ] && [ "$check" -le "${STORAGE_CNT}" ] && [ "$check" -ne 0 ]; then
        break
        echo hello
      elif [ "$check" != "$check2" ] && [ -z "${check##*[0-9]*}" ] && [ -z "${check2##*[0-9]*}" ]; then
        warn "There are issues with your entry:\n1. Numeric entries do not match.\n   Please try again..."
      elif [ -z "${check##*[!0-9]*}" ] || [ -z "${check2##*[!0-9]*}" ]; then
        warn "There are issues with your entry:\n1. Your entry is invalid. Numerics only.\n   Please try again..."
      elif [ "$check" = "$check2" ] && [ "$check" -gt "${STORAGE_CNT}" ] || [ "$check" = 0 ] && [ -z "${check##*[0-9]*}" ] && [ -z "${check2##*[0-9]*}" ]; then
        warn "There are issues with your entry:\n1. Your entry line number does not match a storage disk line number.\n   Please try again..."
      fi
    done
    DISK_UUID=$(cat dev_list_var02 | awk -F':' -v "var=$check" 'FNR==var {print $4}')
    DISK_ID=$(cat dev_list_var02 | awk -F':' -v "var=$check" 'FNR==var {print $1}')
  fi

  # Format storage disk
  msg "Checking the selected disks file system for compatibility (i.e ext4)..."
  DISK_FS=$(blkid -o value -s TYPE ${DISK_ID})
  if [ ${DISK_FS} == ${DISK_FORMAT_TYPE} ]; then
    info "Selected disk format is okay: ${DISK_FORMAT_TYPE}"
    echo
    DISK_FORMAT=1
    systemctl stop nmbd smbd
    sleep 2
    msg "Checking for existing partition mounts on disk..."
    blkid ${DISK_ID}* | awk '{ print $1 }' | sed 's/://' > disk_partition_list
    while read line <&3; do
      umount -l $line 2> /dev/null
      info "Checking and performing umount on : ${YELLOW}$line${NC}"
    done 3< disk_partition_list
    echo
  elif [ ${DISK_FS} != 'ext4' ]; then
  msg "Your selected disk $(cat dev_list_var02 | grep ${DISK_UUID} | awk -F':' '{ print "\""$2, $3"\"", "("$1")" }') requires formatting\nto the Linux ext4 filesystem. All existing $(blkid ${DISK_ID}* | awk '{ print $1 }' | sed 's/://' | wc -l)x partitions will be\ndestroyed and all data will be ${RED}permanently erased${NC}."
    while true; do
      read -p "Proceed to format the selected disk to ext4 [y/n]?: " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          systemctl stop nmbd smbd
          msg "Checking for existing partition mounts on disk..."
          blkid ${DISK_ID}* | awk '{ print $1 }' | sed 's/://' > disk_partition_list
          while read line <&3; do
            umount -l $line 2> /dev/null
            info "Checking and performing umount on : ${YELLOW}$line${NC}"
          done 3< disk_partition_list
          echo
          # Erasing disk
          msg "Erasing the selected disk..."
          dd if=/dev/zero of=${DISK_ID} bs=512 count=1 conv=notrunc >/dev/null
          # Formatting disk
          msg "Formatting the selected disk to ext4..."
          mkfs.ext4 -F -q -L $(echo ${MOUNT_POINT} | awk -F" +|/" '{print $NF}') ${DISK_ID}
          echo
          # Disk Over-Provisioning
          msg "Applying over-provisioning factor % to disk..."
          if [ $(hdparm -I ${DISK_ID} 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g') == "SolidStateDevice" ]; then
            tune2fs -m ${DISK_OP_SSD} ${DISK_ID}
            info "SSD Disk reserved block percentage : ${YELLOW}${DISK_OP_SSD}%${NC}"
            echo
          else
            tune2fs -m ${DISK_OP_ROT} ${DISK_ID}
            info "Rotational Disk reserved block percentage : ${YELLOW}${DISK_OP_ROT} %${NC}"
            echo
          fi
          break
          ;;
        [Nn]*)
          msg "You have chosen not to format your selected disk. To choose another option run\nthis script again and start again. Exiting in 2 seconds..."
          sleep 2
          exit 1
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  fi
  
  # Disk Mount
  mkdir -p ${MOUNT_POINT}
  DISK_UUID=$(blkid -s UUID -o value ${DISK_ID} 2> /dev/null)
  if [ ${OSTYPE} = '"coreelec"' ] || [ ${OSTYPE} = '"libreelec"' ]; then
    if [ $(hdparm -I ${DISK_ID} 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g') == "SolidStateDevice" ]; then
      mount -t ext4 -o discard /dev/disk/by-uuid/${DISK_UUID} ${MOUNT_POINT} 2> /dev/null # for trim
    else
      mount -t ext4 /dev/disk/by-uuid/${DISK_UUID} ${MOUNT_POINT} 2> /dev/null # no trim
    fi
  else
    echo -e "UUID=${DISK_UUID} ${MOUNT_POINT} ext4 defaults 0 0" > /etc/fstab
    mount ${MOUNT_POINT}
  fi

  # Create Kodi-Sync library folders
  while IFS='|' read -r F1 F2; do
    mkdir -p ${MOUNT_POINT}/$F2
  done < kodi_sync_folder_list
  
  # Restart nmbd smbd
  systemctl restart nmbd smbd
fi

# Select storage - Folder based
if [ ${STORAGE_TYPE} = 2 ]; then
  # Default folder check
  while IFS='|' read -r F1 F2; do
    if [ $(find / -ipath "*/kodirsync/$F2" > /dev/null; echo $?) = 0 ]; then
      EXISTING_DIR_CHECK=0
    else
      EXISTING_DIR_CHECK=1
    fi
  done < kodi_sync_folder_list
  # Existing folder validation
  if [ ${EXISTING_DIR_CHECK} = 0 ]; then
    msg "The default folders already exist on your machine:"
    echo
    i=1
    while IFS='|' read -r F1 F2; do
      echo "$F1|$(find / -ipath "*/kodirsync/$F2")" >> existing_folder_list
      echo "${YELLOW}${i}${NC}) ${WHITE}$F1${NC} - ${MOUNT_POINT}/$F2" | indent
      i=$(($i + 1))
    done < kodi_sync_folder_list
    echo
    while true; do
      read -p "Do you want to synchronise to the above folders [y/n]? " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          info "Your Kodirsync destination is set : ${YELLOW}$(cat existing_folder_list | grep 'series' | awk -F'|' '{ print $2}' | sed 's#kodirsync.*##')${NC}"
          DESTINATION_FOLDER="$(cat existing_folder_list | grep 'series' | awk -F'|' '{ print $2}' | sed 's#.*##')"
          echo
          break
          ;;
        [Nn]*)
          EXISTING_DIR_CHECK=1
          echo
          break
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  fi
 
  # Manual folder entry
  if [ ${EXISTING_DIR_CHECK} = 1 ]; then
    msg "You have chosen to manually entry a destination folder. Type in a full absolute\npath at the next prompt (Linux standard i.e /volume1/users/media)."
    while true; do
      read -p "Enter a full absolute folder destination path:" -r man_dir_path
      if [ -d $man_dir_path ]; then
        while true; do
          read -p "Do you want to synchronise to ${WHITE}$man_dir_path${NC} [y/n]? " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              mkdir -p $man_dir_path/
              # Create Kodi-Sync library folders
              while IFS='|' read -r F1 F2; do
                mkdir -p $man_dir_path//$F2
              done < kodi_sync_folder_list
              info "Your Kodirsync destination is set : ${YELLOW}$man_dir_path/${NC}"
              DESTINATION_FOLDER="$man_dir_path/"
              echo
              break 2
              ;;
            [Nn]*)
              msg "Please try again..."
              echo
              break
              ;;
            *)
              warn "Error! Entry must be 'y' or 'n'. Try again..."
              echo
              ;;
          esac
        done
      elif [ ! -d $man_dir_path ]; then
        warn "There are issues with your entry:\n1. Folder does not exist.\n   Please try again..."
      fi
    done
  fi
fi

#---- Set options
# Enable HDR 
msg "${WHITE}#### PLEASE READ CAREFULLY - DISABLE HDR CONTENT ####${NC}\nYou have the option to disable HDR video content. Disable when:\n\n--  your media player cannot play 4K HDR formatted video media\n--  your TV cannot display 4K HDR formatted video media\n\nDisabling 4K HDR stops your Kodirsync client downloading any 4K HDR video content."
echo
msg "Available options:"
echo -e "${YELLOW}Enable HDR${NC}\n${YELLOW}Disable HDR${NC}" > proceed_menu
LINE_CNT=$(cat proceed_menu | wc -l)
echo
i=1
while IFS=':' read -r f1; do
  printf "%-2s  %-s\n" ${i}')'   "${YELLOW}$f1${NC}"
  i=$(($i + 1))
done < proceed_menu
unset i
echo
while true; do
  read -p "Select your HDR option (entering numeric) : " check
  echo
  if [ "$check" -le "${LINE_CNT}" ] && [ "$check" -ne 0 ] && [ -z "${check##*[0-9]}" ]; then
    if [ "$check" = 1 ]; then
      info "HDR status is set: ${YELLOW}enabled${NC}"
      HDR_ENABLED=0
      echo
    elif [ "$check" = 2 ]; then
      info "HDR status is set: ${YELLOW}disabled${NC}"
      HDR_ENABLED=1
      echo
    fi
    break
  elif [ -z "${check##*[!0-9]}" ]; then
    warn "There are issues with your entry:\n1. Your entry is invalid. Numerics only.\n   Please try again..."
  elif [ "$check" -gt "${LINE_CNT}" ] || [ "$check" = 0 ] && [ -z "${check##*[0-9]}" ]; then
    warn "There are issues with your entry:\n1. Your entry line number does not match a option line number.\n   Please try again..."
  fi
done

# Set video size limit
msg "${WHITE}#### PLEASE READ CAREFULLY - SET VIDEO SIZE LIMIT ####${NC}\nYou have the option to limit the video file size you download. The limit applies to\nall video content (i.e movies, series, home video). Limit units are gigabytes (Gb).\n\n--  type '5' - '99' Gigabytes to set a video file size limit (Gb)\n--  minimum allowed file size limit is 5 (Gb)\n--  type 0 for unlimited file size\n"
read -p "Do you want to set a video file size limit [y/n]? " -n 1 -r
echo
if [[ "$REPLY" == "y" || "$REPLY" == "Y" || "$REPLY" == "yes" || "$REPLY" == "Yes" ]]; then
  while true; do
    read -p "Enter a video file size limit Gb (entering numeric) : " num
    echo
    if [[ $num -ge 5 ]] && [[ $num -le 99 ]]; then
      MAX_SIZE=${num}
      info "Video file size limit is set: ${YELLOW}${num}${NC} (Gb)"
      echo
      break
    elif [ "$num" = 0 ]; then
      MAX_SIZE=0
      info "Video file size limit is set: ${YELLOW}unlimited${NC}"
      echo
      break
    elif [ $(echo $num | grep -q "^[0-9]*$"; echo $?) != 0 ]; then
      warn "There are issues with your entry:\n1. Your entry is invalid. Numerics only.\n   Please try again..."
    elif [[ $num -lt 5 ]] && [[ $num -gt 99 ]]; then
      warn "There are issues with your entry:\n1. Your entry is invalid. Its outside our value range.\n   Please try again..."
    fi
  done
else
  MAX_SIZE=0
  info "Video file size limit is set: ${YELLOW}unlimited${NC} (Gb)"
  echo
fi

#---- Set  script variables
# HDR status
sed -i "s#^DOCUMENTARY_HDR_ENABLED=.*#DOCUMENTARY_HDR_ENABLED='${HDR_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^HOMEVIDEO_HDR_ENABLED=.*#HOMEVIDEO_HDR_ENABLED='${HDR_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^MOVIES_HDR_ENABLED=.*#MOVIES_HDR_ENABLED='${HDR_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^MUSICVIDEO_HDR_ENABLED=.*#MUSICVIDEO_HDR_ENABLED='${HDR_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^PRON_HDR_ENABLED=.*#PRON_HDR_ENABLED='${HDR_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^SERIES_HDR_ENABLED=.*#SERIES_HDR_ENABLED='${HDR_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh

# Video file size limit
sed -i "s#^DOCUMENTARY_MAX_SIZE=.*#DOCUMENTARY_MAX_SIZE='${MAX_SIZE}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^HOMEVIDEO_MAX_SIZE=.*#HOMEVIDEO_MAX_SIZE='${MAX_SIZE}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^MOVIES_MAX_SIZE=.*#MOVIES_MAX_SIZE='${MAX_SIZE}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^MUSICVIDEO_MAX_SIZE=.*#MUSICVIDEO_MAX_SIZE='${MAX_SIZE}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^PRON_MAX_SIZE=.*#PRON_MAX_SIZE='${MAX_SIZE}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i "s#^SERIES_MAX_SIZE=.*#SERIES_MAX_SIZE='${MAX_SIZE}'#g" pve_medialab_kodirsync_clientapp.sh

# Destination settings
sed -i "s#^DESTINATION_STORAGE_TYPE=.*#DESTINATION_STORAGE_TYPE='${STORAGE_TYPE}'#g" pve_medialab_kodirsync_clientapp.sh
if [ ${STORAGE_TYPE} = 1 ]; then
  # Disk Based
  sed -i "s#^DESTINATION_DIR=.*#DESTINATION_DIR='${MOUNT_POINT}'#g" pve_medialab_kodirsync_clientapp.sh
  sed -i "s#^APP_DIR=.*#APP_DIR='${APP_DIR}'#g" pve_medialab_kodirsync_clientapp.sh
elif [ ${STORAGE_TYPE} = 2 ]; then
  # Folder Based
  sed -i "s#^DESTINATION_DIR=.*#DESTINATION_DIR='${DESTINATION_FOLDER}'#g" pve_medialab_kodirsync_clientapp.sh
  sed -i "s#^APP_DIR=.*#APP_DIR='${APP_DIR}'#g" pve_medialab_kodirsync_clientapp.sh
fi

#---- Install and configure files for 
# Copy private ssh key to host
cp ${RSYNC_Username}_id_ed25519 ~/.ssh
chmod 600 ~/.ssh/${RSYNC_Username}_id_ed25519
cat ~/.ssh/${RSYNC_Username}_id_ed25519 >> ~/.ssh/known_hosts

# Copy sslh certificate to host
if [[ -f 'sslh.crt' ]]; then
  cp sslh.crt ~/.ssh
  chmod 600 ~/.ssh/sslh.crt
fi

# Copy sslh key to host
if [[ -f 'sslh-kodirsync.key' ]]; then
  cp sslh-kodirsync.key ~/.ssh
  chmod 600 ~/.ssh/sslh-kodirsync.key
fi

# Copy Kodirsync script to host
cp pve_medialab_kodirsync_clientapp.sh ${APP_DIR}
chmod +x ${APP_DIR}/pve_medialab_kodirsync_clientapp.sh

# Set Scheduled Cron Tasks
crontab -u root -l | grep -v "sh ${APP_DIR}/pve_medialab_kodirsync_clientapp.sh" | crontab -u root - # Remove any previous kodirsync_script cron tasks
crontab -l > kodirsync # write out crontab
echo "0 1 * * * sh  ${APP_DIR}/pve_medialab_kodirsync_clientapp.sh" >> kodirsync # echo new cron into cron file
crontab kodirsync # install new cron file
rm kodirsync # delete temp echo file

# Create a new  user profile
if [ ${OSTYPE} = '"coreelec"' ] || [ ${OSTYPE} = '"libreelec"' ]; then
  msg "You can create a new Kodi local user profile called 'Kodirsync' on this device to for\nyour new rsync media library."
  while true; do
    read -p "Do you want to create a 'Kodirsync' user profile [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        echo "Coming soon..."
        break
        ;;
      [Nn]*)
        info "You have chosen not set up a 'Kodirsync' profile. You can always manually create\na local profile at your Kodi player station."
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
fi


#---- Finish Line ------------------------------------------------------------------
msg "Success. Kodirsync installation has completed. Kodirsync is set to run everyday\nat 01:00hr. You can change this setting by editing the 'kodirsync' crontab.\nYour Kodirsync file locations are:\n\n
  App Folder
  --  $(echo ${WHITE}${APP_DIR}${NC}) ( script)
  SSH Key
  --  ${WHITE}~/.ssh${NC}
  Log files
  --  ${WHITE}${APP_DIR}/logs${NC}
  Media Storage Location"
if [ ${STORAGE_TYPE} = 1 ]; then
  msg "  --  ${WHITE}${MOUNT_POINT}${NC}"
  echo
elif [ ${STORAGE_TYPE} = 2 ]; then
  msg "  --  ${WHITE}${DESTINATION_FOLDER}${NC}"
  echo
fi

# Run Kodirsync now
while true; do
  read -p "Do you want to run 'Kodirsync' now (perform a rsync) [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      if [ ${OSTYPE} = '"coreelec"' ] || [ ${OSTYPE} = '"libreelec"' ]; then
        sh ${APP_DIR}/pve_medialab_kodirsync_clientapp.sh
      else
        ${APP_DIR}/$(echo $PWD)/pve_medialab_Kodirsync_clientapp.sh
      fi
      msg "The Kodirsync process has started. Your terminal should display the rsync events.\nYou can close this terminal at any time."
      echo
      break
      ;;
    [Nn]*)
      info "Bye..."
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

# Cleanup
cleanup