#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     Kodirsync_clientapp_installer.sh
# Description:  Installer script for a Kodirsync client
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/src/clientapp/kodirsync_clientapp_installer.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

#---- Internet access check (Checking multiple urls incase one is blocked)

# Check for Internet connectivity
# List of well-known websites to test connectivity (in case one is blocked)
websites=( "google.com 443" "github.com 443" "cloudflare.com 443" "apple.com 443" "amazon.com 443" )
# Loop through each website in the list
for website in "${websites[@]}"
do
  # Test internet connectivity
  nc -zw1 $website > /dev/null 2>&1
  # Check the exit status of the ping command
  if [ $? = 0 ]
  then
    # If URLs were reachable, print a success message
    echo -e "Success. Internet connection is working.\n"
    break
  else
    # If no URLs were reachable, print an error message and exit the script
    echo -e "\e[93m[WARNING]\e[39m \e[97mCould not connect to any URLs.\nYour internet connection has failed. Exiting script. Bye...\n\e[39m"
    exit 1
  fi
done


#---- Static Variables -------------------------------------------------------------

#---- Terminal settings

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'
UNDERLINE=$'\033[4m'

#---- Regex string check & fixes
escape_string_regex='[][()\.^$?+/'\'' ]/\\&'

#---- Disk settings

# Disk fs type
disk_fs='ext4|exfat'
# Disk Over-Provisioning(%)
over_prov_ssd=15
over_prov_rot=0

#---- New Linux User & Group names

# Set Linux User name
linux_user=media
linux_uid=1605

# Set Linux group name
linux_grp=medialab
linux_guid=65605

#---- Cron run time

# Kodirsync cron run schedule (min hour day month day)
# Default recommended setting is 23:00hr daily
cron_run_time='0 23 * * *'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

#---- Bash Messaging Functions

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


#---- Cleanup

function cleanup() {
  cd $HOME
  rm -rf $temp_dir &> /dev/null
  rm -rf $tempfile &> /dev/null
  rm -rf $selftar_dir &> /dev/null
  # rm $(mktemp) &> /dev/null
}


#---- Kill scripts

function kill_script {
  # Call the kill_process function and pass it a list of script names as arguments
  # Example: kill_script "script1" "script2" "script3"

  # Iterate over each script name passed as an argument
  for script in "$@"
  do
    # Get the PIDs of processes with names that match the provided script name
    pid=$(pgrep -f "$script")

    # Filter out any non-existent PIDs
    pid=$(<<<"$pid" xargs -n1 sh -c 'kill -0 "$1" 2>/dev/null && echo "$1"' --)

    # Use the pkill command to kill all processes with names that match the script name
    if [ -n "$pid" ]; then
      echo "Other script is running with pid $pid"
      echo "Killing him!"
      kill -9 "$pid"
      sleep 1
    fi
  done
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Run defaults SRC
source $DIR/kodirsync_clientapp_default.cfg

# Iterate over the device and wake up each disk
while IFS= read -r line
do
  dd if=$line of=/dev/null count=512 status=none
done< <( blkid -o device | grep -E '^\/dev\/sd[a-z]([1-9])?$' 2> /dev/null )


#---- Set kodirsync variables and args

# Check if client is Termux or Linux/CoreELEC/LibreELEC
if [ $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]
then
  # Set OS type to Termux
  ostype='termux'
elif [ "$(uname)" == "Linux" ] && [ ! $(command -v termux-info >/dev/null 2>&1; echo $?) = 0 ]
then
  # SetLinux OS type
  ostype=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)

  # Set terminal window size
  printf '\033[8;40;120t'

  # Check if root
  if [ "$EUID" -ne 0 ]
  then
    warn "This script requires root privileges. Please run it as root."
    exit 1
  fi
else
  warn "Kodirsync is supported on CoreELEC, LibreELEC, Linux and Termux only.\nBye..."
  exit 1
fi


# Vars & args set by client OS Type - Linux or CoreELEC/LibreELEC (ELEC)
if [[ "$ostype" =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]
then
  # Check ELEC version is suitable
  if [[ "$ostype" =~ ^.*(\")?coreelec(\")?.*$ ]]
  then
    # Check CoreELEC
    elec_ver_min="20.1"
    elec_ver=$(awk -F '=' '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)
    if [[ ! "$(printf '%s\n' "$elec_ver_min" "$elec_ver" | sort -V | head -n1)" == "$elec_ver_min" ]]
    then
      warn "CoreELEC version is not suitable.\n Minimum required version: $elec_ver_min\nBye..."
      exit 0
    fi

    # Check if root
    if [ "$EUID" -ne 0 ]
    then
      warn "This script requires root privileges. Please run it as root.nBye..."
      exit 1
    fi
  elif [[ "$ostype" =~ ^.*(\")?libreelec(\")?.*$ ]]
  then
    # Check LibreELEC
    elec_ver_min="10.0"
    elec_ver=$(awk -F '=' '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)
    if [[ ! "$(printf '%s\n' "$elec_ver_min" "$elec_ver" | sort -V | head -n1)" == "$elec_ver_min" ]]
    then
      warn "LibreELEC version is not suitable.\nMinimum required version: $elec_ver_min\nBye..."
      exit 1
    fi

    # Check if root
    if [ "$EUID" -ne 0 ]
    then
      warn "This script requires root privileges. Please run it as root."
      exit 1
    fi
  fi

  # Installer extraction location
  selftar_dir="/tmp/selftar"

  # Mktemp file
  tempfile=$(mktemp)
  # Kodirsync temp work dir
  temp_dir=$(mktemp -dt -p /tmp kodirsync-XXXXXX)

  # Install Entware - installentware
  # Entware is a software repository for network attached storage, routers and other embedded devices.
  source $DIR/kodirsync_clientapp_install_elec_entware.sh

  # Set client OS type - ELEC
  os_type=1

  # Set User
  user='root'
  user_grp='root'

  # Set 'dir' variables
  app_dir=''
  ssh_dir="$HOME/.ssh"
  mnt_point='/var/media/kodirsync'
  mnt_point_regex=$(echo "$mnt_point" | sed "s/${escape_string_regex}/g")
elif [ "$ostype" = 'termux' ]
then
  # Set client OS type - Termux
  os_type=3

  # Set User
  user="$(whoami)"
  user_grp="$(whoami)"

  # Set ssh dir if exists
  if id -u $user >/dev/null 2>&1
  then
    # Get home dir of the new user
    ssh_dir="$HOME/.ssh"
  fi

  # Installer extraction location
  selftar_dir="$HOME/downloads/selftar"

  # Mktemp file
  tempfile=$(mktemp)
  # Kodirsync temp work dir
  temp_dir=$(mktemp -dt -p /data/data/com.termux/files/usr/tmp kodirsync-XXXXXX)
  
  # Set 'dir' variables
  app_dir=""
  mnt_point=""
  mnt_point_regex=$(echo "$mnt_point" | sed "s/${escape_string_regex}/g")
else
  # Set client OS type - Linux
  os_type=2

  # Set User
  user="$linux_user"
  user_grp="$linux_grp"

  # Set ssh dir if exists
  if id -u $user >/dev/null 2>&1
  then
    # Get home dir of the new user
    ssh_dir="$(awk -F: "/^$user:/ {print \$6}" /etc/passwd)/.ssh"
  fi

  # Installer extraction location
  selftar_dir="/tmp/selftar"

  # Mktemp file
  tempfile=$(mktemp)
  # Kodirsync temp work dir
  temp_dir=$(mktemp -dt -p /tmp kodirsync-XXXXXX)
  
  # Set 'dir' variables
  app_dir='/usr/local/bin/kodirsync'
  mnt_point='/mnt/kodirsync'
  mnt_point_regex=$(echo "$mnt_point" | sed "s/${escape_string_regex}/g")
fi


#---- Select installer menu option (existing installations only)

# Check if a cron entry exists for Kodirsync. If present Kodirsync already exists.
# Function to check if kodirsync_clientapp_run.sh is present in the user's crontab
function is_kodirsync_in_crontab() {
  crontab -u "$user" -l | grep -E '^.*kodirsync_clientapp_run\.sh$' &> /dev/null
}

# Determine menu options based on the presence of kodirsync in crontab
if is_kodirsync_in_crontab; then
  menu_options=(
    "Re-install Kodirsync"   # Option 1 (menu_action 1)
    "Uninstall Kodirsync"    # Option 2 (menu_action 2)
    "Manual run Kodirsync"   # Option 3 (menu_action 3)
    "Quit"                   # Option 4 (menu 00) (menu_action 00)
  )
  menu_message="A Kodirsync installation already exists. Your menu options:"
else
  menu_options=(
    "Install Kodirsync"      # Option 1 (menu_action 0)
    "Prepare Kodirsync disk or folder storage only (for node)"  # Option 2 (menu_action 4)
    "Quit"                   # Option 3 (menu 00) (menu_action 00)
  )
  menu_message="Your menu options:"
fi

while true; do
  # Display installer menu options
  msg "$menu_message\n"
  for ((i = 0; i < ${#menu_options[@]}; i++)); do
    option_num=$((i + 1))
    printf "%d) %s\n" "$option_num" "${menu_options[i]}"
  done | indent

  # Prompt user to enter their choice
  read -p "Enter your choice: " choice

  # Determine action based on user's choice
  case $choice in
    1)
      if is_kodirsync_in_crontab; then
        # Kodirsync re-install - option 1
        info "You have chosen to perform: ${YELLOW}Re-install Kodirsync${NC}"
        menu_action=1
        echo
        break
      else
        # Kodirsync installation - option 1
        info "You have chosen to perform: ${YELLOW}Install Kodirsync${NC}"
        menu_action=0
        echo
        break
      fi
      ;;
    2)
      if is_kodirsync_in_crontab; then
        # Kodirsync un-install - option 2
        info "You have chosen to perform: ${YELLOW}Uninstall Kodirsync${NC}"
        menu_action=2
        echo
        break
      else
        # Prepare Kodirsync disk or folder storage only (for node) - option 2
        info "You have chosen to perform: ${YELLOW}Prepare storage only${NC}"
        menu_action=4
        echo
        break
      fi
      ;;
    3)
      if is_kodirsync_in_crontab; then
        # Kodirsync un-install - option 3
        info "You have chosen to perform: ${YELLOW}Run Kodirsync now${NC}"
        menu_action=3
        echo
        break
      else
        # Quit
        warn "You have chosen to skip this installer and quit. Bye..."
        menu_action=00
        sleep 1
        exit 0
      fi
      ;;
    4)
      if is_kodirsync_in_crontab; then
        # Quit - option 4
        warn "You have chosen to skip this installer and quit. Bye..."
        menu_action=00
        sleep 1
        exit 0
      else
        # Invalid choice
        warn "Invalid choice. Try again..."
      fi
      ;;
    *)
      # Invalid choice
      warn "Invalid choice. Try again..."
      ;;
  esac
done


#---- Run actions from menu selection

# Menu option - 1 and 2
# Remove all old configuration and settings
if [[ "$menu_action" =~ ^(1|2)$ ]]
then
  # Kill all running Kodirsync processes
  kill_script "kodirsync_clientapp_run.sh" "kodirsync_clientapp_gitupdater.sh" "kodirsync_clientapp_script.sh"

  # Perform action according to host OS type ( '1' is ELEC, '2' is generic Linux)
  if [ "$os_type" = 1 ]
  then
    # ELEC uninstall
    source $DIR/kodirsync_clientapp_uninstall_elec.sh
  elif [ "$os_type" = 2 ]
  then
    # Linux uninstall
    source $DIR/kodirsync_clientapp_uninstall_linux.sh
  fi

  # Uninstall - Remove Kodirsync from your hardware and exit
  if [ "$menu_action" = 2 ]
  then
    msg "Kodirsync has been uninstalled and removed from this machine.\nTo re-install Kodirsync run this script again. Bye..."
    echo
    exit 0
  fi
fi

# Menu option - 3
# Manual run Kodirsync
if [ "$menu_action" = 3 ]
then
  # Kill all running Kodirsync processes
  kill_script "kodirsync_clientapp_run.sh" "kodirsync_clientapp_gitupdater.sh" "kodirsync_clientapp_script.sh"
  
  # Perform action according to host OS type ( '1' is ELEC, '2' is generic Linux)
  if [ "$os_type" = 1 ]
  then
    # Run CoreELEC/LibreELEC Kodirsync
    msg "Kodirsync is starting. Be patient..."
    bash "$app_dir/kodirsync_clientapp_run.sh" &
    exit 0
  elif [ "$os_type" = 2 ]
  then
    # Run Linux Kodirsync
    su - $user -c "$app_dir/kodirsync_clientapp_run.sh"
    exit 0
  fi
fi

# Menu option - 4
# Prepare Kodirsync disk or folder storage only (for node)
if [ "$menu_action" = 4 ]
then
  # Perform action according to host OS type ( '1' is ELEC, '2' is generic Linux)
  if [[ "$os_type" =~ ^(1|2)$ ]]
  then
    # Linux setup disk/node storage
    source $DIR/kodirsync_node_install_storage.sh
  else
    # Display msg
    warn "Kodirsync node is supported on CoreELEC, LibreELEC and Termux only.\nBye..."
    exit 0
  fi
fi

# Menu option - 0 and 1
# Install Kodirsync
# Perform action according to host OS type ( '1' is ELEC, '2' is generic Linux, '3' is Termux/Android)
if [[ "$menu_action" =~ ^(0|1)$ ]] && [ "$os_type" = 1 ]
then
  # OS type - ELEC
  # Kill all running Kodirsync processes
  kill_script "kodirsync_clientapp_run.sh" "kodirsync_clientapp_gitupdater.sh" "kodirsync_clientapp_script.sh"

  # Setup storage
  source $DIR/kodirsync_clientapp_install_linux_storage.sh

  # Setup for CoreELEC/LibreELEC OS
  source $DIR/kodirsync_clientapp_install_elec.sh

  # Set Kodirsync common presets
  source $DIR/kodirsync_clientapp_install_common_presets.sh

  # Copy application/script files to client
  source $DIR/kodirsync_clientapp_install_common_copyfiles.sh

  # Update user configuration file
  source $DIR/kodirsync_clientapp_install_common_cfg_update.sh

  # Add Kodirsync cron entry to client
  source $DIR/kodirsync_clientapp_install_common_cron.sh

  # Configure Kodi favorites
  source $DIR/kodirsync_clientapp_kodi_install_favorites.sh
elif [[ "$menu_action" =~ ^(0|1)$ ]] && [ "$os_type" = 2 ]
then
  # OS type - Linux
  # Kill all running Kodirsync processes
  kill_script "kodirsync_clientapp_run.sh" "kodirsync_clientapp_gitupdater.sh" "kodirsync_clientapp_script.sh"

  # Setup Linux OS
  source $DIR/kodirsync_clientapp_install_linux.sh

  # Setup storage
  source $DIR/kodirsync_clientapp_install_linux_storage.sh

  # Set Kodirsync common presets
  source $DIR/kodirsync_clientapp_install_common_presets.sh

  # Copy application/script files to client
  source $DIR/kodirsync_clientapp_install_common_copyfiles.sh

  # Update user configuration file
  source $DIR/kodirsync_clientapp_install_common_cfg_update.sh

  # Add Kodirsync cron entry to client
  source $DIR/kodirsync_clientapp_install_common_cron.sh
elif [[ "$menu_action" =~ ^(0|1)$ ]] && [ "$os_type" = 3 ]
then
  # OS type - Termux

  # Check for USB drive
  usb_check=$(find /storage -path "*/????-????/Android/*" -type d 2>/dev/null)

  # Check for existing Kodirsync dirs
  dst_dir_check=$(find /storage \( -path "*/????-????/$android_path/$kodirsync_storage_dir" -o -path "*/????-????/*/$kodirsync_storage_dir" \) -type d -exec sh -c 'if [ -e "$1/.kodirsync_storage" ]; then echo "$1"; fi' sh {} \; 2> /dev/null | sed '/^$/d' | uniq -u)
  app_dir_check=$(find /storage \( -path "*/????-????/$android_path/$kodirsync_app_dir" -o -path "*/????-????/*/$kodirsync_app_dir" \) -type d 2> /dev/null)

  if [ -n "$dst_dir_check" ] && [ -n "$app_dir_check" ] || [ ! -n "$usb_check" ]
  then
    #---- Part install - Termux dep only
    # This checks for an existing USB Kodirsync disk, no USB disk and configures Termux only

    # Check and install deps
    source $DIR/kodirsync_clientapp_install_termux_deps.sh

    # Setup Termux OS
    source $DIR/kodirsync_clientapp_install_termux.sh
  elif [ ! -n "$dst_dir_check" ] && [ ! -n "$app_dir_check" ] && [ -n "$usb_check" ]
  then
    #---- Full install - App and USB disk

    # Check and install deps
    source $DIR/kodirsync_clientapp_install_termux_deps.sh

    # Setup storage
    source $DIR/kodirsync_clientapp_install_termux_storage.sh

    # Set Kodirsync common presets
    source $DIR/kodirsync_clientapp_install_common_presets.sh

    # Copy application/script files to client
    source $DIR/kodirsync_clientapp_install_common_copyfiles.sh

    # Setup Termux OS
    source $DIR/kodirsync_clientapp_install_termux.sh
  fi
fi


#---- Finish Line ------------------------------------------------------------------



if [[ "$os_type" =~ ^(1|2)$ ]] && [[ "$menu_action" =~ ^(0|1)$ ]]
then
  #---- Clean install or re-install - ELEC and Linux

  # Get the cron job entry
  cron_job=$(crontab -u $user -l | grep -E '^.*kodirsync_clientapp_run\.sh$')
  # Extract the hour and minute settings from the cron job
  hour=$(echo "$cron_job" | head -n 1 | awk '{print $2}')
  minute=$(echo "$cron_job" | head -n 1 | awk '{print $1}')
  # Convert the hour and minute settings to normal clock time
  clock_time=$(date -d "$hour:$minute" +"%I:%M %p")

  # Display msg
  display_msg1="Success. Kodirsync installation has completed. Kodirsync is set to run at ${clock_time}. You can change this setting by editing the 'kodirsync' crontab. See your installer email about how to perform your first sync manually."

  # Message
  msg "$(printf '%s\n' "${display_msg1[@]}")
  Your Kodirsync file locations are:\n
    App Folder (scripts folder)
    --  ${WHITE}$app_dir${NC}
    SSH Keys
    --  ${WHITE}$app_dir${NC}
    Log files
    --  ${WHITE}$app_dir/logs${NC}
    Storage Destination Folder
    --  ${WHITE}$dst_dir${NC}\n"
elif [ "$os_type" = 3 ] && [[ "$menu_action" =~ ^(0|1)$ ]]
then
  #---- Clean install or re-install - Android-Termux

  # Display msg
  display_msg1="Success. Kodirsync installation has completed. To start Kodirsync install Termux widgets using Android file manager '/downloads/com.termux.widget_13.apk' on your Android device."

  # Message
  msg "$(printf '%s\n' "${display_msg1[@]}")"
elif [[ "$os_type" =~ ^(1|2)$ ]] && [ "$menu_action" = 4 ]
then
  #---- Prepare Kodirsync disk or folder storage only (for node)

  # Node hostname
  node_localdomain_address_url="$(hostname -s).$(grep -E '^(domain|search)\s' /etc/resolv.conf | awk '{print $2}')"
  # Node IP
  node_local_ip_address=$(ip -o -4 addr show scope global | awk '{split($4,a,"/"); print a[1]}')
  # Node user
  node_user=$user
  # Node group
  node_grp=$user_grp
  # Node destination folder
  node_dst_dir="$dst_dir"

  # Display msg
  display_msg1="Success. Kodirsync node storage setup has completed. Now finish the setup by manually editing your user settings cfg file on your main Kodirsync machine. "

  # Message
  msg "$(printf '%s\n' "${display_msg1[@]}")
  Edit the following values in your user settings file:\n
    Settings filename (in kodirsync_app folder)
    --  ${WHITE}kodirsync_clientapp_user.cfg${NC}
    node_localdomain_address_url
    --  ${WHITE}$node_localdomain_address_url${NC}
    node_local_ip_address
    --  ${WHITE}$node_local_ip_address${NC}
    node_user
    --  ${WHITE}$node_user${NC}
    node_grp
    --  ${WHITE}$node_grp${NC}\n
    node_dst_dir
    --  ${WHITE}$node_dst_dir${NC}\n"
fi

# Cleanup
cleanup
#-----------------------------------------------------------------------------------