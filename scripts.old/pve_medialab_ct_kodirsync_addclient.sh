#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_kodirsync_addclient.sh
# Description:  This script is for creating a Kodirsync client/user account
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_kodirsync_addclient.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="$DIR/../../common/pve/source"

#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your PVE hosts internet connection and try again..."
  echo
  exit 0
fi

# Check for kodirsync hostname
if [ "$HOSTNAME" != "kodirsync" ]; then
  echo -e "PVE CT hostname check: \033[0;31mThis is not CT 'kodirsync'\033[0m\n\nCheck your PVE Kodirsync CTID and try again..."
  exit 0
fi

#  Check for Xclip
if [ $(dpkg-query -W -f='${Status}' xclip 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
  echo "Checking for xclip software..."
  apt-get install xclip -y > /dev/null
  echo "#pbcopy & pbpaste aliases" >> ~/.bash_aliases
  echo "alias pbcopy='xclip -selection clipboard'" >> ~/.bash_aliases
  echo "alias pbpaste='xclip -selection clipboard -o'"  >> ~/.bash_aliases
  source ~/.bashrc
  echo -e "Xclip status: \033[0;32mOK\033[0m"
fi

# Run Bash Header
source ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------

# Chroot Home
CHROOT='/home/chrootjail'
HOME_BASE="$CHROOT/homes/"
GROUP="chrootjail"

#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Kodirsync Client Builder'

# Create a kodirsync username
function input_kodirsync_username_val() {
  while true
  do
    read -p "Enter a new user name : " USERNAME
    if [ ${#USERNAME} -gt 18 ];then
    msg "User name ${WHITE}'${USERNAME}'${NC} is not valid. A user name is considered valid when all of the following constraints are satisfied:\n\n  --  it contains only lowercase characters\n  --  it begins with 3 alphabet characters\n  --  it contains at least 5 characters and at most is 10 characters long\n  --  it may include numerics and underscores\n  --  it doesn't contain any hyphens, periods or special characters [!#$&%*+-]\n  --  it doesn't contain any white space\n  --  note, your user name will be appended with '_kodirsync'\n      ( i.e jasper_kodirsync )\n\nTry again...\n"
    elif [[ ${USERNAME} =~ ^([a-z]{3})([_]?[a-z\d]){2,7}$ ]]; then
      USERNAME=$(echo ${USERNAME} | sed 's/$/_kodirsync/')
      info "Your user name is set : ${YELLOW}${USERNAME}${NC}"
      echo
      break
    else
      msg "User name ${WHITE}'${USERNAME}'${NC} is not valid. A user name is considered valid when all of the following constraints are satisfied:\n\n  --  it contains only lowercase characters\n  --  it begins with 3 alphabet characters\n  --  it contains at least 5 characters and at most is 10 characters long\n  --  it may include numerics and underscores\n  --  it doesn't contain any hyphens, periods or special characters [!#$&%*+-]\n  --  it doesn't contain any white space\n  --  note, your user name will be appended with '_kodirsync'\n      ( i.e jasper_kodirsync )\n\nTry again...\n"
    fi
  done
}

# Delete a kodirsync username (permanent action)
function delete_kodirsync_username() {
  while true
  do
    read -p "Enter the user name you want to delete : " USERNAME
    if [ $(egrep "^${USERNAME}:" /etc/passwd > /dev/null; echo $?) -eq 0 ]; then
      msg "User name ${WHITE}'${USERNAME}'${NC} exists."
      while true; do
        read -p "Are you sure your want delete user ${WHITE}'${USERNAME}'${NC} [y/n]?" -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            msg "Proceeding to delete ${WHITE}'${USERNAME}'${NC} from Kodirsync."
            # Umount existing user bind mounts
            if [ $(grep "${HOME_BASE}${USERNAME}" /etc/fstab | awk '{print $2}' | wc -l) -gt 0 ]; then
              grep "${HOME_BASE}${USERNAME}" /etc/fstab | awk '{print $2}' > kodirsync_umountlist
              while read dir; do
                if mount | grep $dir > /dev/null; then
                  msg "Umounting bind mount: ${WHITE}$dir${NC}"
                  umount $dir 2>/dev/null
                  info "Bind mount status: ${YELLOW}Disabled.${NC}"
                else
                  msg "Umounting bind mount: ${WHITE}$dir${NC}"
                  info "Bind mount status: ${YELLOW}Already Disabled.${NC}"
                fi
              done < kodirsync_umountlist # listing of bind mounts
              echo
            fi
            # Deleting existing user name
            msg "Deleting existing user '${USERNAME}' (including home folder)..."
            userdel -r ${USERNAME} 2>/dev/null
            rm -R ${HOME_BASE}${USERNAME} 2>/dev/null
            sed -i "/^${USERNAME}/d" $CHROOT/etc/passwd
            info "${USERNAME} has been deleted."
            echo
            break 2
            ;;
          [Nn]*)
            while true; do
              read -p "Do you want to try another user name [y/n]?: "  -n 1 -r YN
              echo
              case $YN in
                [Yy]*)
                  echo
                  break 2
                  ;;
                [Nn]*)
                  msg "You have chosen not to proceed. Bye..."
                  echo
                  break 3
                  ;;
                *)
                  warn "Error! Entry must be 'y' or 'n'. Try again..."
                  echo
                  ;;
              esac
            done
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done
    else
      msg "User name ${WHITE}'${USERNAME}'${NC} does not exist. All usernames include the suffix '_kodirsync' such as 'foobar_kodirsync'. Try again...\n"
    fi
  done
}


#---- Other Files ------------------------------------------------------------------


# wget -qL ${DIR}/source/pve_medialab_ct_kodirsync_clientappbuilder.sh
# wget -qL ${DIR}/source/pve_medialab_kodirsync_clientapp.sh

#---- Body -------------------------------------------------------------------------

#---- Create a Kodirsync user
section "Add a Kodirsync user account"
echo
msg_box "#### PLEASE READ CAREFULLY ####\n
Kodirsync Client Builder creates all the files required by a Linux based device (Kodi media player) to securely connect to your Kodirsync PVE CT. Our build script works with any CoreELEC or LibreELEC Kodi player. This Easy Script will create the necessary files and installation scripts so you can:

  --  Rsync mirror selected NAS media categories to your remote Kodi player
      (internal or external drives)
  --  Perform daily Rsync tasks to synchronise new media
  --  Auto remove the oldest remote media files to fit newer media
  --  Fill your client device disk to a data limit (% GB) set by you
  
The install procedure involves two parts. The first part involves creating a new Kodirsync PVE CT user account, selecting which NAS media libraries are allowed to be accessed by the new user account, setting a remote connection address (URL or IPv4), creation of a private ssh ed25519 Rsync access key and packaging a Kodirsync Device Easy Script package which will be emailed to the new user account owner.

The second part is running our Kodirsync device installer Easy Script on your Linux based Kodi hardware."
echo
TYPE01="${YELLOW}Create a New User Account${NC} - add a new Kodirsync user to the system."
TYPE02="${YELLOW}Delete a Existing User Account${NC} - delete a user (permanent)."
TYPE03="${YELLOW}Abort${NC} - exit this installation."
PS3="Select the action type you want to do (entering numeric) : "
msg "Your choices are:"
options=("$TYPE01" "$TYPE02" "$TYPE03")
select menu in "${options[@]}"; do
  case $menu in
    "$TYPE01")
      echo
      break
      ;;
    "$TYPE02")
      echo
      delete_kodirsync_username
      exit 0
      ;;
    "$TYPE03")
      echo
      msg "You have chosen not to proceed. Aborting. Bye..."
      sleep 1
      echo
      exit 0
      # done
      ;;
    *) warn "Invalid entry. Try again.." >&2
  esac
done

# Create a new user
while true; do
  while true; do
    read -p "Create a new Kodirsync user account [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        msg "Creating a new Kodirsync user account..."
        input_kodirsync_username_val
        break 1
        ;;
      [Nn]*)
        info "You have chosen to abort creating a new user account.\nExiting in 2 seconds..."
        sleep 2
        cleanup
        exit 0
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done

# Modify existing Kodi Rsync user
  if [ $(egrep "^${USERNAME}" /etc/passwd > /dev/null; echo $?) -eq 0 ]; then
    EXISTING_USER=0
    section "Modify a existing Kodirsync user"
    msg_box "#### PLEASE READ CAREFULLY ####\n
    The user '${USERNAME}' already exists. Your choices are:
    
      --  Delete, destroy and erase the existing user '${USERNAME}'
          (The existing SSH keys will be replaced)
      --  Modify the existing user '${USERNAME}' keeping the current SSH keys
      --  Abort and try a different user name."
    echo
    TYPE01="${YELLOW}Delete & Re-create${NC} - destroy, erase and create a new '${USERNAME}' (new SSH keys)."
    TYPE02="${YELLOW}Modify Only${NC} - modify '${USERNAME}' Rsync shares only (same SSH keys)."
    TYPE03="${YELLOW}Abort. Try again${NC} - try another Kodi Rsync user name."
    PS3="Select the action type you want to do (entering numeric) : "
    msg "Your choices are:"
    options=("$TYPE01" "$TYPE02" "$TYPE03")
    select menu in "${options[@]}"; do
      case $menu in
        "$TYPE01")
          echo
          msg "You have chosen to delete and re-create user '${USERNAME}'. This action will result in permanent loss of the existing users SSH keys. New SSH keys will be generated."
          while true; do
            read -p "Are you sure your want to proceed [y/n]?" -n 1 -r YN
            echo
            case $YN in
              [Yy]*)
                echo
                SSH_KEY_GEN=0
                info "You have chosen to re-create '${USERNAME}' including new SSH keys."
                echo
                break 2
                ;;
              [Nn]*)
                msg "You have chosen not to proceed. Try again..."
                echo
                break 1
                ;;
              *)
                warn "Error! Entry must be 'y' or 'n'. Try again..."
                echo
                ;;
            esac
          done
          ;;
        "$TYPE02")
          echo
          SSH_KEY_GEN=1
          info "You have chosen to modify user '${USERNAME}' Rsync shares only.\nYour existing private SSH keys are maintained and still valid."
          echo
          break
          ;;
        "$TYPE03")
          echo
          msg "Try again..."
          echo
          break
          # done
          ;;
        *) warn "Invalid entry. Try again.." >&2
      esac
    done
    if ! [ -z "${SSH_KEY_GEN+x}" ]; then
      break
    fi
  else
    SSH_KEY_GEN=0
    EXISTING_USER=1
    break
  fi
done

# Backing up existing SSH Keys
if [ $SSH_KEY_GEN = 1 ] && [ $EXISTING_USER = 0 ] && [ -f ${HOME_BASE}${USERNAME}/.ssh/authorized_keys ]; then
  msg "Backing up existing '${USERNAME}' SSH keys..."
  mkdir -p $TEMP_DIR/${USERNAME}_$(date +%Y%m%d)_old
  cp ${HOME_BASE}${USERNAME}/.ssh/authorized_keys $TEMP_DIR/${USERNAME,,}_$(date +%Y%m%d)_old/ 2>/dev/null
  info "Existing '${USERNAME}' SSH keys temporary backup complete."
  echo
fi

# Backing up existing rsync control list files (white & black lists)
if [ $EXISTING_USER = 0 ] && [ -f ${HOME_BASE}${USERNAME}/rsync_control_list_user-movies.txt ] && [ -f ${HOME_BASE}${USERNAME}/rsync_control_list_user-series.txt ]; then
  msg "Backing up existing '${USERNAME}' rsync control list files..."
  mkdir -p $TEMP_DIR/${USERNAME}_$(date +%Y%m%d)_rsyncfiles
  cp ${HOME_BASE}${USERNAME}/rsync_control_list_user-*.txt $TEMP_DIR/${USERNAME,,}_$(date +%Y%m%d)_rsyncfiles/ 2>/dev/null
  info "Existing '${USERNAME}' rsync control list files temporary backup complete."
  echo
fi

# Deleting existing user data
if [ $EXISTING_USER = 0 ] && [ $(grep "${HOME_BASE}${USERNAME}" /etc/fstab > /dev/null; echo $?) -eq 0 ]; then
  # Umount existing user bind mounts
  grep "${HOME_BASE}${USERNAME}" /etc/fstab | awk '{print $2}' > kodirsync_umountlist
  while read dir; do
    if mount | grep $dir > /dev/null; then
      msg "Umounting bind mount: ${WHITE}$dir${NC}"
      umount $dir 2>/dev/null
      info "Bind mount status: ${YELLOW}Disabled.${NC}"
    else
      msg "Umounting bind mount: ${WHITE}$dir${NC}"
      info "Bind mount status: ${YELLOW}Already Disabled.${NC}"
    fi
  done < kodirsync_umountlist # listing of bind mounts
  echo
fi
# Deleting existing user name
if [ $EXISTING_USER = 0 ]; then
  msg "Deleting existing user '${USERNAME}' (including home folder)..."
  userdel -r ${USERNAME} 2>/dev/null
  rm -R ${HOME_BASE}${USERNAME} 2>/dev/null
  sed "/${USERNAME}/d" $CHROOT/etc/passwd
  info "{$USERNAME} has been deleted."
  echo
fi


#---- Create new user account 
section "Create new user account"
msg "Creating new user name '${USERNAME}'..."
useradd -g ${GROUP} -m -d ${HOME_BASE}${USERNAME} -s /bin/bash ${USERNAME}
msg "Fixing '${USERNAME}' home folder location to '${GROUP}' setup..."
usermod -d /homes/${USERNAME} ${USERNAME}
awk -v user="${USERNAME}" -v path="/homes/${USERNAME}" 'BEGIN{FS=OFS=":"}$1==USERNAME{$6=path}1' /etc/passwd > temp_file
mv temp_file /etc/passwd
msg "Copy '${USERNAME}' password to chrooted /etc/passwd..."
cat /etc/passwd | grep ${USERNAME} >> $CHROOT/etc/passwd
cat /etc/group | grep chrootjail > $CHROOT/etc/group
msg "Add '${USERNAME}' to medialab group..."
usermod -a -G 65605 ${USERNAME}
msg "Creating authorised keys folders and settings for user '${USERNAME}'..."
mkdir -p ${HOME_BASE}${USERNAME}/.ssh
touch ${HOME_BASE}${USERNAME}/.ssh/authorized_keys
chmod -R 0700 ${HOME_BASE}${USERNAME}
chmod 600 ${HOME_BASE}${USERNAME}/.ssh/authorized_keys
chown -R ${USERNAME}:${GROUP} ${HOME_BASE}${USERNAME}
info "User created: ${YELLOW}${USERNAME}${NC} of group ${GROUP}"
echo
if [ $SSH_KEY_GEN = 1 ] && [ $EXISTING_USER = 0 ]; then
  # Using existing SSH keys
  msg "Copying existing (former) user SSH keys to your new '${USERNAME}'..."
  cat $TEMP_DIR/${USERNAME}_$(date +%Y%m%d)_old/authorized_keys >> ${HOME_BASE}${USERNAME}/.ssh/authorized_keys
  #cp $TEMP_DIR/${USERNAME}_$(date +%Y%m%d)_old/* ${HOME_BASE}${USERNAME}/.ssh/ 2>/dev/null
  chown -R ${USERNAME}:${GROUP} ${HOME_BASE}${USERNAME}
  rm -R $TEMP_DIR/${USERNAME}_$(date +%Y%m%d)_old 2>/dev/null
  info "Existing '${USERNAME}' SSH keys have been re-added to the system."
  echo
elif [ $SSH_KEY_GEN = 0 ]; then
  # Generating new SSH keys
  msg "Creating new SSH keys for '${USERNAME}'..." 
  ssh-keygen -o -q -t ed25519 -a 100 -f ${HOME_BASE}${USERNAME}/.ssh/${USERNAME}_id_ed25519 -N ""
  cat ${HOME_BASE}${USERNAME}/.ssh/${USERNAME}_id_ed25519.pub >> ${HOME_BASE}${USERNAME}/.ssh/authorized_keys
  # Create ppk key for Putty or Filezilla
  msg "Creating a private PPK key (Putty or Filezilla)..."
  puttygen ${HOME_BASE}${USERNAME}/.ssh/${USERNAME}_id_ed25519 -o ${HOME_BASE}${USERNAME}/.ssh/${USERNAME}_id_ed25519.ppk
  # chown -R ${USERNAME}:${GROUP} ${HOME_BASE}${USERNAME}
  msg "Backing up '${USERNAME}' latest SSH Rsync keys..."
  mkdir -p /mnt/backup/kodirsync/sshkey/${USERNAME}_$(date +%Y%m%d)
  chmod 0750 /mnt/backup/kodirsync/sshkey/${USERNAME}_$(date +%Y%m%d)
  cp ${HOME_BASE}${USERNAME}/.ssh/${USERNAME}_id_ed25519* /mnt/backup/kodirsync/sshkey/${USERNAME}_$(date +%Y%m%d)/
  info "User '${USERNAME}' SSH keys have been added to the system."
  echo
fi
if [ $EXISTING_USER = 0 ]; then
  msg "Restoring former Rsync control list file (white & black lists)..."
  cp $TEMP_DIR/${USERNAME}_$(date +%Y%m%d)_rsyncfiles/* ${HOME_BASE}${USERNAME}/ 2>/dev/null
  info "User '${USERNAME}' Rsync control list files have been restored."
  echo
fi

#---- Create User Media Folders
section "Create User Media Folders"

# Set Series bind mount inputs
MEDIA_CATEGORY=series
ls -d /mnt/video/* | grep -v 'movies\|pron\|cctv\|transcode\|images\|homevideo\|musicvideo\|documentary' | if [ -f bindmount_list_input ]; then grep -v "$(cat bindmount_list_input | awk '{print $1}')"; else cat; fi > source_folder_list_var01
msg "Creating ${MEDIA_CATEGORY^^} folder access..."
if [ -d /mnt/video/${MEDIA_CATEGORY} ]; then
  SERIES_ENABLED=0
  echo "/mnt/video/${MEDIA_CATEGORY} ${HOME_BASE}${USERNAME}/video/${MEDIA_CATEGORY}" >> bindmount_list_input
  info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}/mnt/video/${MEDIA_CATEGORY}"${NC}
  echo
elif [ ! -d /mnt/video/${MEDIA_CATEGORY} ]; then
  # Select a source folder
  unset options i
  mapfile -t options < source_folder_list_var01
  PS3="Select a media folder which contains your ${MEDIA_CATEGORY^^} media (entering numeric) : "
  select i in "${options[@]}" "None - No matching folder"; do
    case $i in
      /mnt*)
        SERIES_ENABLED=0
        echo "${i} ${HOME_BASE}${USERNAME}/video/series" >> bindmount_list_input
        info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}$(echo ${i})"${NC}
        echo
        break
        ;;
      "None - No matching folder")
        msg "You have chosen to skip the ${MEDIA_CATEGORY^^} media category. ${MEDIA_CATEGORY^^} media will not be accessible or available to Rsync by '${USERNAME}'."
        read -p "Are you sure: [y/n]?: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          SERIES_ENABLED=1
          info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}None - skipping ${MEDIA_CATEGORY^^} media"${NC}
          echo
          break
        fi
        ;;
      *) warn "Invalid entry. Try again.." >&2
      echo
    esac
  done
fi

# Set Documentary bind mount inputs
MEDIA_CATEGORY=documentary
ls -d /mnt/video/* | grep -v 'movies\|pron\|cctv\|transcode\|images\|homevideo\|musicvideo\|series' | if [ -f bindmount_list_input ]; then grep -v "$(cat bindmount_list_input | awk '{print $1}')"; else cat; fi > source_folder_list_var01
msg "Creating ${MEDIA_CATEGORY^^} folder access..."
if [ -d /mnt/video/${MEDIA_CATEGORY} ]; then
  DOCUMENTARY_ENABLED=0
  echo "/mnt/video/${MEDIA_CATEGORY} ${HOME_BASE}${USERNAME}/video/${MEDIA_CATEGORY}" >> bindmount_list_input
  info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}/mnt/video/${MEDIA_CATEGORY}"${NC}
  echo
elif [ ! -d /mnt/video/${MEDIA_CATEGORY} ]; then
  # Select a source folder
  unset options i
  mapfile -t options < source_folder_list_var01
  PS3="Select a media folder which contains your ${MEDIA_CATEGORY^^} media (entering numeric) : "
  select i in "${options[@]}" "None - No matching folder"; do
    case $i in
      /mnt*)
        DOCUMENTARY_ENABLED=0
        echo "${i} ${HOME_BASE}${USERNAME}/video/series" >> bindmount_list_input
        info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}$(echo ${i})"${NC}
        echo
        break
        ;;
      "None - No matching folder")
        msg "You have chosen to skip the ${MEDIA_CATEGORY^^} media category. ${MEDIA_CATEGORY^^} media will not be accessible or available to Rsync by '${USERNAME}'."
        read -p "Are you sure: [y/n]?: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          DOCUMENTARY_ENABLED=1
          info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}None - skipping ${MEDIA_CATEGORY^^} media"${NC}
          echo
          break
        fi
        ;;
      *) warn "Invalid entry. Try again.." >&2
      echo
    esac
  done
fi

# Set Movie bind mount inputs
MEDIA_CATEGORY=movies
ls -d /mnt/video/* | grep -v 'pron\|cctv\|transcode\|images\|homevideo\|musicvideo\|series|documentary' | if [ -f bindmount_list_input ]; then grep -v "$(cat bindmount_list_input | awk '{print $1}')"; else cat; fi > source_folder_list_var01
msg "Creating ${MEDIA_CATEGORY^^} folder access..."
if [ -d /mnt/video/${MEDIA_CATEGORY} ]; then
  MOVIES_ENABLED=0
  echo "/mnt/video/${MEDIA_CATEGORY} ${HOME_BASE}${USERNAME}/video/${MEDIA_CATEGORY}" >> bindmount_list_input
  info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}/mnt/video/${MEDIA_CATEGORY}"${NC}
  echo
elif [ ! -d /mnt/video/${MEDIA_CATEGORY} ]; then
  # Select a source folder
  unset options i
  mapfile -t options < source_folder_list_var01
  PS3="Select a media folder which contains your ${MEDIA_CATEGORY^^} media (entering numeric) : "
  select i in "${options[@]}" "None - No matching folder"; do
    case $i in
      /mnt*)
        MOVIES_ENABLED=0
        echo "${i} ${HOME_BASE}${USERNAME}/video/movies" >> bindmount_list_input
        info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}$(echo ${i})"${NC}
        echo
        break
        ;;
      "None - No matching folder")
        msg "You have chosen to skip the ${MEDIA_CATEGORY^^} media category. ${MEDIA_CATEGORY^^} media will not be accessible or available to Rsync by '${USERNAME}'."
        read -p "Are you sure: [y/n]?: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          MOVIES_ENABLED=1
          info "${MEDIA_CATEGORY^^} media source is set as : ${YELLOW}None - skipping ${MEDIA_CATEGORY^^} media"${NC}
          echo
          break
        fi
        ;;
      *) warn "Invalid entry. Try again.." >&2
      echo
    esac
  done
fi


# Set Public Photo and Home video bind mount inputs
if [ -d /mnt/photo ] || [ -d /mnt/video/homevideo ]; then
  msg_box "#### PLEASE READ CAREFULLY - PRIVATE MEDIA LIBRARIES ####\n
  You have the option of allowing '${USERNAME}' read only access to your users public photo and home video libraries. '${USERNAME}' can only Rsync a users public library, not users private home folder libraries. You have two options for access:

  1) Full Access to Public Library Folders
    --  /mnt/photo and all sub folders
    --  /mnt/video/homevideo and all sub folders
  If you choose this method then all content in folders '/mnt/photo' and '/mnt/video/homevideo' will be accessible by '${USERNAME}'. This includes any folders added in the future!

  2) Selected Access to Public Library Folders
  Here you individually select library folders to be granted access by '${USERNAME}'. Any non-selected folders are excluded. You may grant access to any or none of the following existing sub folders:

  $(if [ $(find /mnt/photo/* -maxdepth 0 -type d | wc -l) -gt 0 ]; then echo "  Photo Libraries\n"; find /mnt/photo/* -maxdepth 0 -type d | sed 's#^#  --  #' | sed s'/$/\n/'; else echo "Photo Libraries"; echo "  --  no user photo libraries available"; fi)\n
  $(if [ $(find /mnt/video/homevideo/* -maxdepth 0 -type d | wc -l) -gt 0 ]; then echo "  Home Video Libraries\n"; find /mnt/video/homevideo/* -maxdepth 0 -type d | sed 's#^#  --  #' | sed s'/$/\n/'; else echo "Home Video Libraries"; echo "  --  no user home video libraries available"; fi)"
  echo
fi

# Select Photo Library Option
if [ -d /mnt/photo ]; then
  MEDIA_CATEGORY=photo
  TYPE01="${YELLOW}Full Access${NC} - full access to all public ${MEDIA_CATEGORY,,} library folders"
  TYPE02="${YELLOW}Selected Access${NC} - individually select your ${MEDIA_CATEGORY,,} library folders"
  TYPE03="${YELLOW}None${NC} - exclude all ${MEDIA_CATEGORY,,} library folders"
  PS3="Select your ${MEDIA_CATEGORY,,} library access method for '${USERNAME}' (entering numeric) : "
  msg "Available options:"
  options=("$TYPE01" "$TYPE02" "$TYPE03")
  select menu in "${options[@]}"; do
    case $menu in
      "$TYPE01")
        PHOTO_ENABLED=0
        echo "/mnt/photo ${HOME_BASE}${USERNAME}/photo" >> bindmount_list_input
        PHOTO_TYPE=01
        info "${MEDIA_CATEGORY^} library is set as: ${YELLOW}$(echo $menu | awk '{print $1}')${NC} ( /mnt/photo )"
        echo
        break
        ;;
      "$TYPE02")
        PHOTO_TYPE=02
        echo
        break
        ;;
      "$TYPE03")
        PHOTO_ENABLED=1
        info "${MEDIA_CATEGORY^} library is set as : ${YELLOW}None - Skipping ${MEDIA_CATEGORY^} Access${NC}"
        PHOTO_TYPE=03
        echo
        break
        ;;
      *) warn "Invalid entry. Try again.." >&2
    esac
  done

  if [ $PHOTO_TYPE = 02 ]; then
    msg "Select the ${MEDIA_CATEGORY,,} library folders you want to grant '${USERNAME}' read only access to..."
    set +Eeuo pipefail
    menu() {
      echo -e "Available options:"
      for i in "${!options[@]}"; do 
          printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
      done
      if [[ "$msg" ]]; then echo "$msg"; fi
    }
    mapfile -t options < <( find /mnt/photo/* -maxdepth 0 -type d )
    prompt=$(echo -e "\nCheck an option to select any number of ${MEDIA_CATEGORY^} libraries to grant\n'${USERNAME}' read only access (again to uncheck, ENTER when done):")
    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
      [[ "$num" != *[![:digit:]]* ]] &&
      (( num > 0 && num <= ${#options[@]} )) ||
      { msg="Invalid option: $num"; continue; }
      ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
      [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
    done
    echo
    printf "Your selected ${MEDIA_CATEGORY^} Libraries are:\n"; msg=" nothing"
    for i in ${!options[@]}; do
      [[ "${choices[i]}" ]] && { printf "\e[36m[INFO]\e[39m ${MEDIA_CATEGORY^} library is set as: %s\n" "${YELLOW}${options[i]}${NC}"; msg=""; } && PHOTO_ENABLED=0 && echo "$({ printf "%s" "${options[i]}"; msg=""; } | sed 's# #//040#g') $({ printf "%s" "${options[i]}"; msg=""; } | sed 's# #//040#g' | sed "s#^/mnt#${HOME_BASE}${USERNAME}#")" >> bindmount_list_input
    done
    if [ -z ${choices+x} ]; then
      PHOTO_ENABLED=1
      msg "No ${MEDIA_CATEGORY^} libraries have been selected."
      info "${MEDIA_CATEGORY^} library is set as : ${YELLOW}None - Skipping ${MEDIA_CATEGORY^} Access${NC}"
    fi
    unset choices
    set -Eeuo pipefail
    echo
  fi
else
  PHOTO_ENABLED=1
fi

# Select Home Video Library Option
if [ -d /mnt/video/homevideo ]; then
  MEDIA_CATEGORY=homevideo
  TYPE01="${YELLOW}Full Access${NC} - full access to all public ${MEDIA_CATEGORY,,} library folders"
  TYPE02="${YELLOW}Selected Access${NC} - individually select your ${MEDIA_CATEGORY,,} library folders"
  TYPE03="${YELLOW}None${NC} - exclude all ${MEDIA_CATEGORY,,} library folders"
  PS3="Select your ${MEDIA_CATEGORY,,} library access method for '${USERNAME}' (entering numeric) : "
  msg "Available options:"
  options=("$TYPE01" "$TYPE02" "$TYPE03")
  select menu in "${options[@]}"; do
    case $menu in
      "$TYPE01")
        HOMEVIDEO_ENABLED=0
        echo "/mnt/video/homevideo ${HOME_BASE}${USERNAME}/video/homevideo" >> bindmount_list_input
        HOMEVIDEO_TYPE=01
        info "${MEDIA_CATEGORY^} library is set as: ${YELLOW}$(echo $menu | awk '{print $1}')${NC} ( /mnt/video/homevideo )"
        echo
        break
        ;;
      "$TYPE02")
        HOMEVIDEO_TYPE=02
        echo
        break
        ;;
      "$TYPE03")
        HOMEVIDEO_ENABLED=1
        info "${MEDIA_CATEGORY^} library is set as : ${YELLOW}None - Skipping ${MEDIA_CATEGORY^} Access${NC}"
        HOMEVIDEO_TYPE=03
        echo
        break
        ;;
      *) warn "Invalid entry. Try again.." >&2
    esac
  done

  if [ $HOMEVIDEO_TYPE = 02 ]; then
    msg "Select the ${MEDIA_CATEGORY,,} library folders you want to grant '${USERNAME}' read only access to..."
    set +Eeuo pipefail
    menu() {
      echo -e "Available options:"
      for i in "${!options[@]}"; do 
          printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
      done
      if [[ "$msg" ]]; then echo "$msg"; fi
    }
    mapfile -t options < <( find /mnt/video/homevideo/* -maxdepth 0 -type d )
    prompt=$(echo -e "\nCheck an option to select any number of ${MEDIA_CATEGORY^} libraries to grant\n'${USERNAME}' read only access (again to uncheck, ENTER when done):")
    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
      [[ "$num" != *[![:digit:]]* ]] &&
      (( num > 0 && num <= ${#options[@]} )) ||
      { msg="Invalid option: $num"; continue; }
      ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
      [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
    done
    echo
    printf "Your selected ${MEDIA_CATEGORY^} Libraries are:\n"; msg=" nothing"
    for i in ${!options[@]}; do
      [[ "${choices[i]}" ]] && { printf "\e[36m[INFO]\e[39m ${MEDIA_CATEGORY^} library is set as: %s\n" "${YELLOW}${options[i]}${NC}"; msg=""; } && HOMEVIDEO_ENABLED=0 && echo "$({ printf "%s" "${options[i]}"; msg=""; } | sed 's# #//040#g') $({ printf "%s" "${options[i]}"; msg=""; } | sed 's# #//040#g' | sed "s#^/mnt#${HOME_BASE}${USERNAME}#")" >> bindmount_list_input
    done
    if [ -z ${choices+x} ]; then
      HOMEVIDEO_ENABLED=1
      msg "No ${MEDIA_CATEGORY^} libraries have been selected."
      info "${MEDIA_CATEGORY^} library is set as : ${YELLOW}None - Skipping ${MEDIA_CATEGORY^} Access${NC}"
    fi
    unset choices
    set -Eeuo pipefail
    echo
  fi
else
  HOMEVIDEO_ENABLED=1
fi

# Set music video media permissions
if [ -d /mnt/video/musicvideo ]; then
  msg_box "#### PLEASE READ CAREFULLY - PRON MEDIA ####\n
  You have the option of allowing '${USERNAME}' to access and Rsync your music video media library.

    --  /mnt/video/musicvideo

  If you want to deny '${USERNAME}' access to music video media library type 'n' in the next step to block '${USERNAME}' access."
  echo
  while true; do
    read -p "Grant '${USERNAME}' full read only access to your music video library [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        MUSICVIDEO_ENABLED=0
        echo "/mnt/video/musicvideo ${HOME_BASE}${USERNAME}/video/musicvideo" >> bindmount_list_input
        info "Music video media library is set as: ${YELLOW}Full Access${NC} ( /mnt/video/musicvideo )"
        echo
        break
        ;;
      [Nn]*)
        MUSICVIDEO_ENABLED=1
        info "Music video media library is set as: ${YELLOW}Access denied${NC}"
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  MUSICVIDEO_ENABLED=1
fi

# Set pron media permissions
if [ -d /mnt/video/pron ]; then
  msg_box "#### PLEASE READ CAREFULLY - PRON MEDIA ####\n
  You have the option of allowing '${USERNAME}' to access and Rsync your pron media library.

    --  /mnt/video/pron

  If you want to deny '${USERNAME}' access to pron media library type 'n' in the next step to block '${USERNAME}' access."
  echo
  while true; do
    read -p "Grant '${USERNAME}' full read only access to your pron library [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        PRON_ENABLED=0
        echo "/mnt/video/pron ${HOME_BASE}${USERNAME}/video/pron" >> bindmount_list_input
        info "Pron media library is set as: ${YELLOW}Full Access${NC} ( /mnt/video/pron )"
        echo
        break
        ;;
      [Nn]*)
        PRON_ENABLED=1
        info "Pron media library is set as: ${YELLOW}Access denied${NC}"
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  PRON_ENABLED=1
fi

# Set audio media permissions
if [ -d /mnt/audio ]; then
  msg_box "#### PLEASE READ CAREFULLY - AUDIO MEDIA ####\n
  You have the option of allowing '${USERNAME}' to access and Rsync your audio media library (i.e audiobooks, podcasts).

    --  /mnt/audio

  If you want to deny '${USERNAME}' access to audio media library type 'n' in the next step to block '${USERNAME}' access."
  echo
  while true; do
    read -p "Grant '${USERNAME}' full read only access to your audio library [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        AUDIO_ENABLED=0
        echo "/mnt/audio ${HOME_BASE}${USERNAME}/audio" >> bindmount_list_input
        info "Audio media library is set as: ${YELLOW}Full Access${NC} ( /mnt/audio )"
        echo
        break
        ;;
      [Nn]*)
        AUDIO_ENABLED=1
        info "Audio media library is set as: ${YELLOW}Access denied${NC}"
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  AUDIO_ENABLED=1
fi

# Set music media permissions
if [ -d /mnt/music ]; then
  msg_box "#### PLEASE READ CAREFULLY - MUSIC MEDIA ####\n
  You have the option of allowing '${USERNAME}' to access and Rsync your music media library.

    --  /mnt/music

  If you want to deny '${USERNAME}' access to music media library type 'n' in the next step to block '${USERNAME}' access."
  echo
  while true; do
    read -p "Grant '${USERNAME}' full read only access to your music library [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        MUSIC_ENABLED=0
        echo "/mnt/music ${HOME_BASE}${USERNAME}/music" >> bindmount_list_input
        info "Music media library is set as: ${YELLOW}Full Access${NC} ( /mnt/music )"
        echo
        break
        ;;
      [Nn]*)
        MUSIC_ENABLED=1
        info "Music media library is set as: ${YELLOW}Access denied${NC}"
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  MUSIC_ENABLED=1
fi

#---- Create Bind Mounts
section "Create Bind Mounts"

mapfile -t binary < <(cat bindmount_list_input)
msg "Creating '${USERNAME}' read only bind mounts..."
while read var1 var2; do
  mkdir -p "$(echo ${var2} | sed 's#\\040# #g')"
  chown -R ${USERNAME}:${GROUP} "$(echo ${var2} | sed 's#\\040# #g')"
  chmod -R 0700 "$(echo ${var2} | sed 's#\\040# #g')"
  # echo "\""${var1}"\" \""${var2}"\" none bind,ro,xattr,acl 0 0" >> /etc/fstab
  echo "${var1} ${var2} none bind,ro,xattr,acl 0 0" >> /etc/fstab
  mount "${var1}"
  info "Bind mount created: ${YELLOW}${var1}${NC}\n       (${var2})"
  echo
done < bindmount_list_input

#---- Create Rsync User Control lists (B&W lists)
section "Create Rsync user control lists"

mapfile -t binary < <(cat bindmount_list_input)
msg "Creating '${USERNAME}' Rsync user control lists (white & black lists)..."
while read var1 var2; do
  LIST_CATEGORY=$(echo ${var2} | grep -Eo '[^/]+/?$')
  echo -e "#---- BLACKLIST OR WHITELIST A FOLDER FROM KODI RSYNC ------------------------------\n#\n# Blacklist any media folder you want Kodi Rsync to exclude by entering the folder\n# name below and labelling with the letter 'b' followed by a '|' (pipe).\n#   For example:   b|foldername\n# Whitelist any media folder you want to permanently store on your Kodi Rsync client\n# by labelling the entry with the letter 'w' followed by a '|' (pipe). Kodi Rsync\n# will never delete a folder entry preceded with the letter 'w' from your client.\n# The folder will be deleted only when its deleted from the server.\n#   For example:   w|foldername\n#\n# Folder names are case sensitive. Use a wildcard * at the end of a partial folder\n# name entry if you want to.\n# Blacklist example:\n#   b|What We Did* matches 'b|What We Did on Our Holiday (2014)'\n# Whitelist example:\n#   w|Toy Story* matches 'w|Toy Story (2019)'\n#\n#-----------------------------------------------------------------------------------\n\nb|Sample (2021)\n" > ${HOME_BASE}${USERNAME}/rsync_control_list_user-${LIST_CATEGORY}.txt
  info "Rsync user control list created: ${YELLOW}${LIST_CATEGORY}${NC}\n       (${var2})"
  echo
done < bindmount_list_input

#---- Create Kodi client Rsync package
section "$SECTION_HEAD - Create Kodi Client Rsync package"

# Add server connection type
msg_box "#### PLEASE READ CAREFULLY - CLIENT RSYNC CONNECTION METHOD ####\n
Your connection options for Kodirsync client '${USERNAME}' are:

1) Remote internet HTTPS SSL 443 address
  --  connect using a HTTPS SSL 443 (from anywhere in the world)
  --  connect locally using $(hostname -i) IPv4 LAN address
  --  prerequisites:
      HAProxy configured as per our instructions
      Acmi SSLH - Kodirsync Certificate file: sslh.crt
      Acmi SSLH - Kodirsync User key file: sslh-kodirsync.key

2) Local LAN IP address
  --  connect using $(hostname -i) IPv4 address
  --  LAN connection only"

TYPE01="${YELLOW}Remote Address${NC} - connect remotely using a HTTPS SSL 443 address"
TYPE02="${YELLOW}Local LAN${NC} - connect using $(hostname -i) IP address"
PS3="Select your connection method (entering numeric) : "
msg "Available options:"
options=("$TYPE01" "$TYPE02")
select menu in "${options[@]}"; do
  case $menu in
    "$TYPE01")
      while true; do
        read -p "Enter a HTTPS URL address: " RSYNC_AddressURL_VAR
        RSYNC_AddressURL=${RSYNC_AddressURL_VAR,,}
#        if curl --output /dev/null --silent --head --fail "${RSYNC_AddressURL}"; then
        if ping -c1 "${RSYNC_AddressURL}" &>/dev/null; then
          info "Rsync connection address is set: ${YELLOW}${RSYNC_AddressURL}${NC}"
          RSYNC_AddressIP=$(hostname -i)
          SSLH_Port='443'
          SSH_CONNECT_TYPE=1
          echo
          break  
        else
          warn "There are problems with your input:
          
          1. HTTPS URL ${RSYNC_AddressURL} is not reachable.
          2. A valid URL resembles: sslh-site1.foo.bar
          
          Check your URL address, remember to include any subdomain and try again..."
          echo
        fi
      done
      echo
      break
      ;;
    "$TYPE02")
      RSYNC_AddressIP=$(hostname -i)
      info "Rsync connection address is set: ${YELLOW}${RSYNC_AddressIP}${NC}"
      SSH_CONNECT_TYPE=2
      echo
      break
      ;;
    *) warn "Invalid entry. Try again.." >&2
  esac
done

# Copy and Paste your existing key into the terminal window
if [ $SSH_CONNECT_TYPE = '1' ]; then
  msg "You have chosen to use a HTTPS SSL 443 connection. We require your ${WHITE}Acmi SSLH - Kodirsync Certificate${NC} and ${WHITE}Acmi SSLH - Kodirsync User key${NC} which you exported from pfSense Certificate Manager. You must have exported two files: 1) Acmi+SSLH+-+Kodirsync.crt and; 2) Acmi+SSLH+-+Kodirsync.key. These two files must be accessible by this computer.\nIn the next steps you will be prompted to copy each file into this computers clipboard. Please strictly follow our instructions to avoid any errors."
  echo
  # CA Certificate
  if [[ -f "/root/.ssh/sslh.crt" ]]; then
    while true; do
      msg "An existing Acmi SSLH - Kodirsync Certificate file is stored on this system: ${WHITE}/root/.ssh/sslh.crt${NC}"
      read -p "Use this existing certificate file (Recommended) [y/n]? " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          info "Acmi SSLH - Kodirsync Certificate is set : ${YELLOW}accepted${NC}"
          INPUT_SSLH=1
          echo
          break
          ;;
        [Nn]*)
          INPUT_SSLH=0
          break
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  else
    INPUT_SSLH=0
  fi
  if [ ${INPUT_SSLH} = 0 ]; then
    while true; do
      CERT_TYPE='crt'
      msg "${YELLOW}Acmi SSLH - Kodirsync Certificate File${NC}\n  ${WHITE}--${NC}  Copy Acmi+SSLH+-+Kodirsync.${CERT_TYPE} file\n      1. Open your CA file Acmi+SSLH+-+Kodirsync.${CERT_TYPE} in a text editor.\n      2. Highlight the key contents (Ctrl + A).\n      3. Copy the highlighted contents to your computer clipboard (Ctrl + C).\n  ${WHITE}--${NC}  Paste your clipboard contents into the terminal when prompted.\n      1. Mouse Right-Click at the terminal prompt to paste."
      read -p "Have you copied your certificate into your computers clipboard [y/n]? " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          msg "Good. Now Right-Click your mouse button at the terminal prompt. Your certificate should paste into this terminal window. We require a blank or empty line at the certificate paste. If no blank line (empty line) appears you must press ${WHITE}Enter${NC} to complete the task."
          echo
          INPUTLINE_CERT=$(sed '/^$/q')
          while true; do
            read -p "Accept your entry (pasted certificate ${CERT_TYPE}) [y/n]? " -n 1 -r YN
            echo
            case $YN in
              [Yy]*)
                echo ${INPUTLINE_CERT} |
                awk '
                match($0,/- .* -/){
                  val=substr($0,RSTART,RLENGTH)
                  gsub(/- | -/,"",val)
                  gsub(OFS,ORS,val)
                  print substr($0,1,RSTART) ORS val ORS substr($0,RSTART+RLENGTH-1)
                }' > /root/.ssh/sslh.crt
                # echo ${INPUTLINE_CERT} > /root/.ssh/sslh.crt
                info "Acmi SSLH - Kodirsync Certificate is set : ${YELLOW}accepted${NC}"
                echo
                break 2
                ;;
              [Nn]*)
                msg "No problem. Try again..."
                echo
                break 1
                ;;
              *)
                warn "Error! Entry must be 'y' or 'n'. Try again..."
                echo
                ;;
            esac
          done
          ;;
        [Nn]*)
          msg "You must first copy your Acmi+SSLH+-+Kodirsync.${CERT_TYPE} file into your computers clipboard. Follow the instructions. Try again..."
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  fi
  # User Key
  if [[ -f "/root/.ssh/sslh-kodirsync.key" ]]; then
    while true; do
      msg "An existing standard Kodirsync SSLH user key file is stored on this system: ${WHITE}/root/.ssh/sslh-kodirsync.key${NC}"
      read -p "Use the existing Kodirsync user key file (Recommended) [y/n]? " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          info "Acmi SSLH - Kodirsync User key is set : ${YELLOW}sslh-kodirsync.key${NC}"
          INPUT_SSLH_KEY=1
          echo
          break
          ;;
        [Nn]*)
          INPUT_SSLH_KEY=0
          break
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  else
    INPUT_SSLH_KEY=0
  fi
  if [ ${INPUT_SSLH_KEY} = 0 ]; then
    while true; do
      CERT_TYPE='key'
      msg "${YELLOW}Acmi SSLH - Kodirsync User key${NC}\n  ${WHITE}--${NC}  Copy Acmi+SSLH+-+Kodirsync.${CERT_TYPE} file\n      1. Open your CA file Acmi+SSLH+-+Kodirsync.${CERT_TYPE} in a text editor.\n      2. Highlight the key contents (Ctrl + A).\n      3. Copy the highlighted contents to your computer clipboard (Ctrl + C).\n  ${WHITE}--${NC}  Paste your clipboard contents into the terminal when prompted.\n      1. Mouse Right-Click at the terminal prompt to paste."
      read -p "Have you copied your Acmi+SSLH+-+Kodirsync.${CERT_TYPE} file into your computers clipboard [y/n]? " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          msg "Good. Now Right-Click your mouse button at the terminal prompt. Your certificate key should paste into this terminal window. We require a blank or empty line at the end of the certificate key paste. If no blank line (empty line) appears you must press ${WHITE}Enter${NC} to complete the task."
          echo
          INPUTLINE_KEY_CERT=$(sed '/^$/q')
          while true; do
            read -p "Accept your entry (pasted certificate ${CERT_TYPE}) [y/n]? " -n 1 -r YN
            echo
            case $YN in
              [Yy]*)
                echo ${INPUTLINE_KEY_CERT} |
                awk '
                match($0,/- .* -/){
                  val=substr($0,RSTART,RLENGTH)
                  gsub(/- | -/,"",val)
                  gsub(OFS,ORS,val)
                  print substr($0,1,RSTART) ORS val ORS substr($0,RSTART+RLENGTH-1)
                }' > /root/.ssh/sslh-kodirsync.key
                # echo ${INPUTLINE_KEY_CERT} > /root/.ssh/sslh-kodirsync.key
                info "Acmi SSLH - Kodirsync User key is set : ${YELLOW}sslh-kodirsync.key${NC}"
                echo
                break 2
                ;;
              [Nn]*)
                msg "No problem. Try again..."
                echo
                break 1
                ;;
              *)
                warn "Error! Entry must be 'y' or 'n'. Try again..."
                echo
                ;;
            esac
          done
          ;;
        [Nn]*)
          msg "You must first copy your Acmi+SSLH+-+Kodirsync.${CERT_TYPE} file into your computers clipboard. Follow the instructions. Try again..."
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  fi
fi


# Copy client files
cp ${DIR}/source/pve_medialab_kodirsync_clientappbuilder.sh . > /dev/null
cp ${DIR}/source/pve_medialab_kodirsync_clientapp.sh . > /dev/null

# Set Variables
# SSH account details
sed -i -r "s#^RSYNC_Username=.*#RSYNC_Username='${USERNAME}'#" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^RSYNC_Username=.*#RSYNC_Username='${USERNAME}'#" pve_medialab_kodirsync_clientappbuilder.sh

# SSH connection type
sed -i -r "s#^SSH_ConnectType=.*#SSH_ConnectType='${SSH_CONNECT_TYPE}'#" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^RSYNC_AddressIP=.*#RSYNC_AddressIP='${RSYNC_AddressIP}'#" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^RSYNC_AddressURL=.*#RSYNC_AddressURL='${RSYNC_AddressURL}'#" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^RSYNC_SshPort=.*#RSYNC_SshPort='$(grep ^Port /etc/ssh/sshd_config | awk '{print $2}')'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^SSLH_Port=.*#SSLH_Port='${SSLH_Port}'#" pve_medialab_kodirsync_clientapp.sh

# Enabled/disable media
sed -i -r "s#^AUDIO_ENABLED=.*#AUDIO_ENABLED='${AUDIO_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^DOCUMENTARY_ENABLED=.*#DOCUMENTARY_ENABLED='${DOCUMENTARY_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^HOMEVIDEO_ENABLED=.*#HOMEVIDEO_ENABLED='${HOMEVIDEO_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^MOVIES_ENABLED=.*#MOVIES_ENABLED='${MOVIES_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^MUSIC_ENABLED=.*#MUSIC_ENABLED='${MUSIC_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^MUSICVIDEO_ENABLED=.*#MUSICVIDEO_ENABLED='${MUSICVIDEO_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^PHOTO_ENABLED=.*#PHOTO_ENABLED='${PHOTO_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^PRON_ENABLED=.*#PRON_ENABLED='${PRON_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh
sed -i -r "s#^SERIES_ENABLED=.*#SERIES_ENABLED='${SERIES_ENABLED}'#g" pve_medialab_kodirsync_clientapp.sh

# Create package zip
if [ ${SSH_CONNECT_TYPE} = '1' ]; then
  tar czf ${HOME_BASE}${USERNAME}/kodirsync_installerpackage.tar.gz pve_medialab_kodirsync_clientappbuilder.sh pve_medialab_kodirsync_clientapp.sh -C ${HOME_BASE}${USERNAME}/.ssh ${USERNAME}_id_ed25519 -C /root/.ssh sslh-kodirsync.key -C /root/.ssh sslh.crt
elif [ ${SSH_CONNECT_TYPE} = '2' ]; then
  tar czf ${HOME_BASE}${USERNAME}/kodirsync_installerpackage.tar.gz pve_medialab_kodirsync_clientappbuilder.sh pve_medialab_kodirsync_clientapp.sh -C ${HOME_BASE}${USERNAME}/.ssh ${USERNAME}_id_ed25519
fi

#---- Email USERNAME SSH Keys
# Email body text
cat <<-EOF > email_body.html
To: $(grep -r "root=.*" /etc/ssmtp/ssmtp.conf | grep -v "#" | sed -e 's/root=//g')
From: donotreply@kodirsync_server.local
Subject: Kodirsync installation package for user: ${USERNAME}
Mime-Version: 1.0
Content-Type: multipart/mixed; boundary="ahuacate"

--ahuacate
Content-Type: text/html
<h3><strong>---- Kodirsync Installation Package</strong></h3>
<p><strong>Client Account Username</strong> : ${USERNAME}</p>
<p><strong>Client SSH User Key</strong> : ${USERNAME}_id_ed25519</p>
$(if [ ${SSH_CONNECT_TYPE} = 1 ]; then
echo "<p><strong>HTTPS SSL Connection Address</strong> : ${RSYNC_AddressURL}:${SSLH_Port}</p>"
echo "<p><strong>LAN Connection Address</strong> : ${RSYNC_AddressIP}:$(grep ^Port /etc/ssh/sshd_config | awk '{print $2}')</p>"
echo "<p><strong>Acmi SSLH - Kodirsync Certificate</strong> : sslh.crt</p>"
echo "<p><strong>Acmi SSLH - Kodirsync User key</strong> : sslh-kodirsync.key</p>"
echo "<p>Your Kodirsync account is configured for HTTPS SSL 443 (remote) and LAN based connectivity. This means you can connect to your Kodirsync server from anywhere in the world and locally using your LAN. LAN connectivity only works when your Kodirsync client is connected on the same LAN network as the Kodirsync server.</p>"
elif [ ${SSH_CONNECT_TYPE} = 2 ]; then
echo "<p><strong>LAN Connection Address</strong> : ${RSYNC_AddressIP}:$(grep ^Port /etc/ssh/sshd_config | awk '{print $2}')</p>"
echo "<p>You account is configured for LAN based connectivity only. You cannot connect remotely via the internet.</p>"
fi)

<p>Your Kodirsync account is configured to download the following media libraries:</p>
$(if [ ${AUDIO_ENABLED} = 0 ]; then echo "<li>Audio books and podcasts</li>"; fi)
$(if [ ${DOCUMENTARY_ENABLED} = 0 ]; then echo "<li>Documentaries</li>"; fi)
$(if [ ${HOMEVIDEO_ENABLED} = 0 ]; then echo "<li>Home Videos</li>"; fi)
$(if [ ${MOVIES_ENABLED} = 0 ]; then echo "<li>Movies</li>"; fi)
$(if [ ${MUSIC_ENABLED} = 0 ]; then echo "<li>Music</li>"; fi)
$(if [ ${MUSICVIDEO_ENABLED} = 0 ]; then echo "<li>Music Videos</li>"; fi)
$(if [ ${PHOTO_ENABLED} = 0 ]; then echo "<li>Photo collections</li>"; fi)
$(if [ ${PRON_ENABLED} = 0 ]; then echo "<li>Pron Videos</li>"; fi)
$(if [ ${SERIES_ENABLED} = 0 ]; then echo "<li>Series (TV)</li>"; fi)
<p>More information about Kodirsync and our Medialab collection of Proxmox software containers is available on our <a href="https://github.com/ahuacate" target="_blank">GitHub</a> page.</p>
<hr />
<h3><strong>Installation Instructions</strong></h3>
<h4><strong>STEP 1 : Copy 'kodirsync_installpackage.tar.gz' to your client device</strong></h4>
<p>Copy the email attachment file '<em>kodirsync_installerpackage.tar.gz</em>' to the following folder location on your client device.</p>
<ul>
<li>For CoreElec or LibreElec Hardware</li>
</ul>
<div style="padding-left: 40px;"> '~/backup'</div>
<ul>
<li>Other Linux Hardware</li>
</ul>
<div style="padding-left: 40px;">'/tmp'</div>
<h4><strong>STEP 2 : Install Kodirsync on your client device</strong></h4>
<p>SSH into your client device as root. Type the following command (or copy &amp; paste) in your SSH terminal:</p>
<div style="width:800px; border: 1px solid #000;">
<p style="padding-left: 40px;"><span style="color: #333333;">bash -c "\$(wget -qO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/source/pve_medialab_kodirsync_clientapp_installer.sh)"</span></p>
</div>
<p>The above command will run our Kodirsync device installer. Follow the prompts.</p>
<h3>---- Attachment Details</h3>
<p>Attached file 'kodirsync_installpackage.tar.gz' contains:</p>
<ol>
<li>Installation files: pve_medialab_ct_kodirsync_clientappbuilder.sh</li>
<li>Kodirsync App (script): pve_medialab_kodirsync_clientapp.sh</li>
<li>Private user Kodirsync key: ${USERNAME}_id_ed25519</li>
<li>Acmi SSLH - Kodirsync Certificate: sslh.crt</li>
<li>Acmi SSLH - Kodirsync User key: sslh-kodirsync.crt</li>
</ol>
<p>A backup copy of your '<em>kodirsync_installerpackage.tar.gz</em>' package is stored on the Kodirsync server at: ${HOME_BASE}${USERNAME}."</p>

--ahuacate
Content-Type: application/gzip
Content-Disposition: attachment; filename="kodirsync_installerpackage.tar.gz"
Content-Transfer-Encoding: base64

$(openssl base64 < ${HOME_BASE}${USERNAME}/kodirsync_installerpackage.tar.gz)
--ahuacate
EOF
if [ $(dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ] && [ $(grep -qs "^root:*" /etc/ssmtp/revaliases >/dev/null; echo $?) = 0 ]; then
  msg "You can email a pre-configured Kodirsync installation package to your system’s administrator (Recommended). Our installation package contains all files to build and configure a '${USERNAME}' Kodirsync client. The system administrator can then forward this installation package including our instructions to the end user."
  echo
  while true; do
    read -p "Email a Kodirsync installation package to your system’s administrator. [y/n]?: " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        msg "Sending '${USERNAME}' Kodirsync installation package to $(grep -r "root=.*" /etc/ssmtp/ssmtp.conf | grep -v "#" | sed -e 's/root=//g')..."
        sendmail -t < email_body.html
        info "Email sent. Check your system administrators inbox."
        echo
        break
        ;;
      [Nn]*)
        info "You have chosen to skip this step. Not sending any email."
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  msg "It appears no SSMTP email service is available to send a Kodirsync installation package to your system administrator. A backup copy of your 'kodirsync_installerpackage.tar.gz' package is stored on the Kodirsync server at: ${HOME_BASE}${USERNAME}"
  echo
fi

#### Finish ####
section "Completion Status."

msg "${WHITE}Success.${NC}"
sleep 3

# Cleanup
if [ -z ${PARENT_EXEC+x} ]; then
  # Cleanup
  trap cleanup EXIT
fi

