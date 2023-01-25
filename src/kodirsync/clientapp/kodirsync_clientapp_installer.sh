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
# Define a list of URLs to test
url_check_LIST=( 
  "google.com|443"
  "github.com|443"
)
# Initialize a counter for the number of reachable URLs
reachable=0
# Iterate over the list of URLs
echo -e "\e[36m[INFO]\e[39m Testing internet connectivity...\n"
while IFS='|' read -r url port
do
  # Test connectivity to the URL
  nc -zw1 $url $port 2> /dev/null
  if [[ $? == '0' ]]
  then
    # If the command is successful, increment the counter and continue to the next URL
    ((reachable++))
  fi
done< <( printf '%s\n' "${url_check_LIST[@]}" )
# Check the number of reachable URLs
if ((reachable == 0))
then
  # If no URLs were reachable, print an error message and exit the script
  echo -e "\e[93m[WARNING]\e[39m \e[97mCould not connect to any URLs.\nYour internet connection has failed. Exiting script. Bye...\n\e[39m"
  exit 1
else
  # If URLs were reachable, print a success message
  echo -e "Success. Internet connection is working.\n"
fi


# #---- Kill running Kodirsync pids
# # Script kill list
# kill_pid_LIST=(
#   "kodirsync_clientapp_run.sh"
#   "kodirsync_clientapp_gitupdater.sh"
#   "kodirsync_clientapp_script.sh"
# )
# # Check for running pid
# while read -r line
# do
#   # Get pid
#   pid=$(pgrep -f "$line")
#   # Filter non-existent pids
#   pid=$(<<<"$pid" xargs -n1 sh -c 'kill -0 "$1" 2>/dev/null && echo "$1"' --)
#   # Kill the pid if running
#   if [ -n "$pid" ]; then
#     echo "Other script is running with pid $pid"
#     echo "Killing him!"
#     kill -9 "$pid"
#     sleep 1
#   fi
# done< <( printf '%s\n' "${kill_pid_LIST[@]}" )


#---- Static Variables -------------------------------------------------------------

#---- Terminal settings
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'
UNDERLINE=$'\033[4m'
printf '\033[8;40;120t'

#---- Selftar
selftar_dir="/tmp/selftar"

#---- Temporay files
# Mktemp file
tempfile=$(mktemp)
# Kodirsync temp work dir
temp_dir=$(mktemp -d -t kodirsync_installer-XXXXX -p /tmp)

#---- Regex string check & fixes
escape_string_regex='[][()\.^$?+/'\'' ]/\\&'

#---- Disk settings
# Disk fs type
disk_fs='ext4'
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
# Default recommended setting is 1am daily
cron_run_time='0 1 * * *'

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
  cd ~
  rm -rf $temp_dir &> /dev/null
  rm -rf $selftar_dir &> /dev/null
  rm $(mktemp) &> /dev/null
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

# Iterate over the device and wake up each disk
while IFS= read -r line
do
  dd if=$line of=/dev/null count=512 status=none
done< <( blkid -o device | egrep '^\/dev\/sd[a-z]([1-9])?$' 2> /dev/null )

# Set kodirsync app dirs & Username
# Set hosts OS Type
ostype=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
if [[ "$ostype" =~ ^.*(\")?(coreelec|libreelec)(\")?.*$ ]]
then
  # Host OS Type ('1' for coreelec/libreelec, '2' for other linux)
  os_type=1
  # User details
  user='root'
  user_grp='root'
  # Set 'dir' variables
  app_dir='/storage/kodirsync'
  ssh_dir="$HOME/.ssh"
  mnt_point='/var/media/kodirsync'
  mnt_point_regex=$(echo "$mnt_point" | sed "s/${escape_string_regex}/g")
else
  # Host OS Type ('1' for coreelec/libreelec, '2' for other linux)
  os_type=2
  # User name
  user="$linux_user"
  user_grp="$linux_grp"
  # Set ssh dir if exists
  if id -u $user >/dev/null 2>&1
  then
    # Get home dir of the new user
    ssh_dir="$(awk -F: "/^$user:/ {print \$6}" /etc/passwd)/.ssh"
  fi
  # Set 'dir' variables
  app_dir='/usr/local/bin/kodirsync'
  mnt_point='/mnt/kodirsync'
  mnt_point_regex=$(echo "$mnt_point" | sed "s/${escape_string_regex}/g")
fi


#---- Select installer menu option (existing installations only)

# Only for existing kodirsync installations
if [[ $(crontab -u $user -l | egrep '^.*kodirsync_clientapp_run\.sh$') ]]
then
  while true
  do
    # Display installer menu options
    msg "A Kodirsync installation already exists. Your menu options:\n"
    menu_display=(
      "1) Re-install -- Complete reinstall of Kodirsync"
      "2) Uninstall -- Remove Kodirsync from your hardware"
      "3) Manual run -- Manually run kodirsync now"
      "4) Quit -- Exit this installation"
    )
    printf '%s\n' "${menu_display[@]}" | indent

    # Prompt user to enter their choice
    read -p "Enter your choice: " choice

    # Determine action based on user's choice
    case $choice in
      1)
        # Action for option 1
        info "You have chosen to perform : ${YELLOW}Re-install Kodirsync${NC}"
        menu_action=1
        echo
        break
        ;;
      2)
        # Action for option 2
        info "You have chosen to perform : ${YELLOW}Uninstall Kodirsync${NC}"
        menu_action=2
        echo
        break
        ;;
      3)
        # Action for option 3
        info "You have chosen to perform : ${YELLOW}Run Kodirsync now${NC}"
        menu_action=3
        echo
        break
        ;;
      4)
        # Action for quitting
        warn "You have chosen to skip this installer and quit. Bye..."
        sleep 1
        exit 0
        ;;
      *)
        # Invalid choice
        warn "Invalid choice. Try again..."
        ;;
    esac
  done
else
  # New install
  menu_action=0
fi

#---- Menu 1 & 2

# Remove all old configuration and settings
if [ "$menu_action" = 1 ] || [ "$menu_action" = 2 ]
then
  # Kill any running Kodirsync processes
  kill_script "kodirsync_clientapp_run.sh" "kodirsync_clientapp_gitupdater.sh" "kodirsync_clientapp_script.sh"

  # Perform action according to host os type
  if [ "$os_type" = 1 ]
  then
    # CoreElec/LibreElec uninstall
    source $DIR/kodirsync_clientapp_elec_uninstall.sh
  elif [ "$os_type" = 2 ]
  then
    # Linux uninstall
    source $DIR/kodirsync_clientapp_linux_uninstall.sh
  fi

  # Uninstall - Remove Kodirsync from your hardware
  if [ "$menu_action" = 2 ]
  then
    msg "Kodirsync has been uninstalled and removed from this machine.\nTo re-install Kodirsync run this script again. Bye..."
    echo
    exit 0
  fi
fi

#---- Menu 3

# Manual run Kodirsync
if [ "$menu_action" = 3 ]
then
  if [ "$os_type" = 1 ]
  then
    # Run CoreELEC/LibreELEC Kodirsync
    sh "$app_dir/kodirsync_clientapp_run.sh"
    exit 0
  elif [ "$os_type" = 2 ]
  then
    # Run Linux Kodirsync
    su - $user -c "$app_dir/kodirsync_clientapp_run.sh"
    exit 0
  fi
fi

#---- Menu 0 (new install)

# Install Kodirsync
if [ "$menu_action" = 0 ] && [ "$os_type" = 1 ]
then
  # Kill any running Kodirsync processes
  kill_script "kodirsync_clientapp_run.sh" "kodirsync_clientapp_gitupdater.sh" "kodirsync_clientapp_script.sh"

  # Install for CoreELEC/LibreELEC
  source $DIR/kodirsync_clientapp_elec_install.sh

  # Run common installer
  source $DIR/kodirsync_clientapp_common_install.sh
elif [ "$menu_action" = 0 ] && [ "$os_type" = 2 ]
then
  # Kill any running Kodirsync processes
  kill_script "kodirsync_clientapp_run.sh" "kodirsync_clientapp_gitupdater.sh" "kodirsync_clientapp_script.sh"

  # Install for Linux
  source $DIR/kodirsync_clientapp_linux_install.sh

  # Run common installer
  source $DIR/kodirsync_clientapp_common_install.sh
fi

#---- Finish Line ------------------------------------------------------------------

#---- Get the Kodirsync cron job start time

# Get the cron job entry
cron_job=$(crontab -u $user -l | egrep '^.*kodirsync_clientapp_run\.sh$')
# Extract the hour and minute settings from the cron job
hour=$(echo "$cron_job" | head -n 1 | awk '{print $2}')
minute=$(echo "$cron_job" | head -n 1 | awk '{print $1}')
# Convert the hour and minute settings to normal clock time
clock_time=$(date -d "$hour:$minute" +"%I:%M %p")

#---- Message

msg "Success. Kodirsync installation has completed. Kodirsync is set to run
at ${clock_time}. You can change this setting by editing the 'kodirsync' crontab.
Your Kodirsync file locations are:\n\n
  App Folder
  --  ${WHITE}$app_dir${NC} (scripts folder)
  SSH Keys
  --  ${WHITE}$ssh_dir${NC}
  Log files
  --  ${WHITE}$app_dir/logs${NC}
  Storage Destination Folder
  --  ${WHITE}$dst_dir${NC}\n"

#---- First Rsync ------------------------------------------------------------------

# Run Kodirsync now
while true
do
  read -p "Run 'Kodirsync' now (perform a full rsync) [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      if [ "$os_type" = 1 ]
      then
        # Run CoreELEC/LibreELEC Kodirsync
        sh "$app_dir/kodirsync_clientapp_run.sh"
        exit 0
      elif [ "$os_type" = 2 ]
      then
        # Run Linux Kodirsync
        su - $user -c "$app_dir/kodirsync_clientapp_run.sh"
        exit 0
      fi
      msg "The Kodirsync process has started. The terminal should display the rsync events.\nYou can close this terminal at any time."
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
#-----------------------------------------------------------------------------------