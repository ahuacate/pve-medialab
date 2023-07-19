#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_sannzbd_toolbox.sh
# Description:  Toolbox script for Proxmox SABnzbd
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Run a SABnzbd Toolbox task"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Preset Assistant - Ahuacate SABnzbd settings" "None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]
then
  # Push files to CT
  pct push $CTID /tmp/${GIT_REPO}.tar.gz /tmp/${GIT_REPO}.tar.gz
  pct exec $CTID -- tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp
  # Run Setup assistant
  msg "Running preset configuration tool..."
  pct exec $CTID -- bash -c "/tmp/$GIT_REPO/src/sabnzbd/config/sabnzbd_config.sh"
  info "Preset complete"
elif [ "$RESULTS" = 'TYPE00' ]
then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi
#-----------------------------------------------------------------------------------