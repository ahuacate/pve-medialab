#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_geterr_toolbox.sh
# Description:  Toolbox script for Proxmox Geterr
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Run a Geterr Toolbox task"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Upgrade Geterr - Upgrade all Geterr SW, OS and apply patches" "None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  # Push files to CT
  msg "Running SW upgrade..."
  pct push $CTID $SRC_DIR/geterr/geterr_upgrade_sw.sh /tmp/geterr_upgrade_sw.sh 
  pct exec $CTID -- bash -c "chmod +x /tmp/geterr_upgrade_sw.sh && /tmp/geterr_upgrade_sw.sh"
  info "Upgrade complete"
elif [ "$RESULTS" = 'TYPE00' ]
then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi
#-----------------------------------------------------------------------------------