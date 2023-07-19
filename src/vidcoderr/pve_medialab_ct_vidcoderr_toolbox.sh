#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_vidcoderr_toolbox.sh
# Description:  Toolbox script for Proxmox Vidcoderr
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Run a Vidcoderr Toolbox task"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Setup Assistant - Change Vidcoderr settings" "Upgrade Vidcoderr - Upgrade Vidcoderr SW, OS and apply patches" "None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  # Setup Assistant
  source $SRC_DIR/vidcoderr/config/vidcoderr_configbuilder.sh
elif [ "$RESULTS" = 'TYPE02' ]
then
  # Push files to CT
  pct push $CTID /tmp/${GIT_REPO}.tar.gz /tmp/${GIT_REPO}.tar.gz
  pct exec $CTID -- tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp
  # Run SW upgrade
  msg "Running SW upgrade..."
  pct exec $CTID -- bash -c "/tmp/$GIT_REPO/src/vidcoderr/config/vidcoderr_updater.sh"
  info "Upgrade complete"
elif [ "$RESULTS" = 'TYPE00' ]
then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi
#-----------------------------------------------------------------------------------