#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_nzbget_toolbox.sh
# Description:  Toolbox script for Proxmox NZBGet
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Run a NZBGet Toolbox task"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Setup - Configure NZBGet" "None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  # Setup Assistant
  source $SRC_DIR/nzbget/config/nzbget_config.sh
elif [ "$RESULTS" = 'TYPE00' ]
then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi
#-----------------------------------------------------------------------------------