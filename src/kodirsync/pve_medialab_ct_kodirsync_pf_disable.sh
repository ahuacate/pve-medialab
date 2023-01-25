#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# File_name:    pve_medialab_ct_kodirsync_pf_disable.sh
# Description:  This script is for removing all PF settings
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
section "Port Forward (PF) disable"

msg_box "#### PLEASE READ CAREFULLY - PORT FORWARD (PF) DISABLE ####\n
This toolbox application will disable PF server remote access. "
echo

msg "Select an option"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Disable Port Forward access" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  #---- Kodirsync settings removal
  # Edit Kodirsync server conf file

  # Uses Func 'edit_config_value'
  config_file='/usr/local/bin/kodirsync/kodirsync.conf'

  # PF access
  key=pf_enable
  value=0
  edit_config_value "$config_file" "$key" "$value"

  info "Kodirsync PF status: ${YELLOW}inactive${NC} (LAN only)"
  echo
elif [ "$RESULTS" = 'TYPE00' ]
then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi
#-----------------------------------------------------------------------------------