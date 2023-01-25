#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# File_name:    pve_medialab_ct_kodirsync_sslh_disable.sh
# Description:  This script is for removing all SSLH settings
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

# Check for kodirsync hostname
if [[ ! "$HOSTNAME" =~ ^kodirsync[.-]?[0-9]+?[0-9]+?$ ]]
then
  echo -e "PVE CT hostname check: \033[0;31mThis is not a 'kodirsync' CT\033[0m\n\nPVE Kodirsync must have a hostname of 'kodirsync'. Fix the issue and try again..."
  exit 0
fi

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='Kodirsync'

#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- SSLH Clean up
section "SSLH disable"

msg_box "#### PLEASE READ CAREFULLY - SSLH DISABLE ####\n
This toolbox application will disable and remove all SSLH server configuration files including ACME certificates and keys. 

Files to be removed are:
  --  Kodirsync Certificate file: /root/.ssh/sslh.crt
  --  Kodirsync User key file: /root/.ssh/sslh-kodirsync.key

A backup of these files will be stored in folder:
  --  /usr/local/bin/kodirsync/kodirsync_sslh_backup_<date>.tar.gz"
echo

msg "Select an option"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Disable SSLH access" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == 'TYPE01' ]
then
  #---- Kodirsync settings removal
  msg "Backing up and removing files..."
  mkdir -p /usr/local/bin/kodirsync
  backup_LIST=( "/root/.ssh,sslh.crt" "/root/.ssh,sslh-kodirsync.key" )
  date=$(date +%Y-%m-%d-%H%M%S)
  name="kodirsync_sslh_backup_${date}.tar.gz"
  while IFS=',' read -r dir file
  do
    if [[ -f $dir/$file ]]
    then
      # Add to tar
      tar -rf /usr/local/bin/kodirsync/"$name" -C $dir $file
      # Remove
      rm $dir/$file
    fi
  done <<< $(printf '%s\n' "${backup_LIST[@]}")

  # Restart SSHd
  systemctl restart ssh 2>/dev/null
  
  # Edit Kodirsync server conf file
  # Uses Func 'edit_config_value'
  config_file='/usr/local/bin/kodirsync/kodirsync.conf'

  # SSLH access
  key=sslh_enable
  value=0
  edit_config_value "$config_file" "$key" "$value"

  info "Kodirsync SSLH status: ${YELLOW}inactive${NC} (LAN only)"
  echo
elif [ ${RESULTS} == 'TYPE00' ]
then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi
#-----------------------------------------------------------------------------------