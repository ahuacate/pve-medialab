#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_kodirsync_toolbox.sh
# Description:  Installer script for Kodirsync administration toolbox & Add-Ons
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Run SMTP Func check
check_smtp_status
if [ ! "$SMTP_STATUS" = 1 ]
then
  warn "Kodirsync requires a working SMTP server.\nRun our 'PVE Host Toolbox' on your primary PVE host and select option 'SMTP Email Setup'. Bye..."
  echo
  return
fi

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Start container
msg "Starting CT..."
pct_start_waitloop

# Pushing variables to CT
msg "Pushing variables and conf to CT..."
printf "%b\n" '#!/usr/bin/env bash' \
"HOSTNAME='${HOSTNAME}'" \
"SECTION_HEAD='${SECTION_HEAD}'" \
"SSH_PORT='${SSH_PORT}'" \
"GIT_REPO='${GIT_REPO}'" \
"APP_NAME='${APP_NAME}'" \
"PVE_HOSTNAME='${PVE_HOSTNAME}'" > ${TEMP_DIR}/pve_ct_variables.sh
pct push $CTID ${TEMP_DIR}/pve_ct_variables.sh /tmp/pve_ct_variables.sh -perms 755

# Pushing setup scripts to CT
msg "Pushing configuration scripts to CT..."
pct push $CTID /tmp/${GIT_REPO}.tar.gz /tmp/${GIT_REPO}.tar.gz
pct exec $CTID -- tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp
echo

#---- Check remote access status
ct_ssh_port=$(pct exec $CTID -- egrep --color=no '^(#)?Port' /etc/ssh/sshd_config | sed '/^#/d' | awk '{ print $2 }' | sed 's/\s//g')
sslh_enable_status=$(pct exec $CTID -- egrep --color=no '^sslh_enable' /usr/local/bin/kodirsync/kodirsync.conf | awk -F'=' '{ print $2 }' | sed 's/\s//g')
pf_enable_status=$(pct exec $CTID -- egrep --color=no '^pf_enable' /usr/local/bin/kodirsync/kodirsync.conf | awk -F'=' '{ print $2 }' | sed 's/\s//g')

if [ "$sslh_enable_status" = 0 ] && [ "$pf_enable_status" = 0 ]; then
section "Kodirsync client connectivity options"
# Select a connection method
msg_box "#### PLEASE READ CAREFULLY - KODIRSYNC CLIENT CONNECTIVITY ####\n
Your Kodirsync client global connectivity options are set for Local LAN connectivity only. Remote access is currently not available.

We recommend you configure pfSense HAProxy to manage in-bound remote WAN connections to this Kodirsync server. Or you could configure a SSH 'Port Forward' on your WAN gateway device which is the less secure method (potential security risks). 

1) SSLH Connection - Internet access using HTTPS SSL 443
   --  A valid domain URL address forwarded to your HAProxy server
   --  HAProxy configured as per our pfSense HAProxy guide
   --  Kodirsync Certificate file: Acmi+SSLH+-+Kodirsync.crt (HAProxy Acmi SSLH)
   --  Kodirsync User key file: Acmi+SSLH+-+Kodirsync.key (HAProxy Acmi SSLH)

2) SSH Port Forward (PF) Connection
   --  Dynamic DNS service provider
   --  Dynamic DNS client updater (ddclient PVE CT)
   --  WAN Gateway port forwarded to "$(hostname).$(hostname -d):${ct_ssh_port}"

2) Local LAN Connection
   --  Connect to: $(hostname -I | sed 's/\s//g') or $(hostname).$(hostname -d)
   --  Local LAN connection only

All Kodirsync clients automatically switch to use a Local LAN connection when connected to your local LAN network."
fi


#---- Run Installer
section "Select a Kodirsync toolbox option"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Kodirsync User Manager - create, delete & modify user accounts" \
"Configure remote SSLH access - requires SSLH certificates and keys $(if [ "${sslh_enable_status}" == '1' ]; then echo "( active )"; fi)" \
"Disable SSLH access - resets to LAN only access" \
"Configure remote Port Forward access - requires a Dynamic DNS service $(if [ "${pf_enable_status}" == '1' ]; then echo "( active )"; fi)" \
"Disable Port Forward access - resets to LAN only access" \
"Update Kodirsync OS and software" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = 'TYPE01' ]; then
  #---- Run Kodirsync client/user account manager
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/kodirsync/pve_medialab_ct_kodirsync_user_manager.sh"
elif [ "$RESULTS" = 'TYPE02' ]; then
  #---- Configure remote SSLH access
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/kodirsync/pve_medialab_ct_kodirsync_sslh_add.sh"
elif [ "$RESULTS" = 'TYPE03' ]; then
  #---- Disable SSLH access
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/kodirsync/pve_medialab_ct_kodirsync_sslh_disable.sh"
elif [ "$RESULTS" = 'TYPE04' ]; then
  #---- Configure Port Forward access
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/kodirsync/pve_medialab_ct_kodirsync_pf_add.sh"
elif [ "$RESULTS" = 'TYPE05' ]; then
  #---- Disable Port Forward access
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/kodirsync/pve_medialab_ct_kodirsync_pf_disable.sh"
elif [ "$RESULTS" = 'TYPE06' ]; then
  #---- Update & upgrade Kodirsync OS and software
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/kodirsync/update-ct.sh"
elif [ "$RESULTS" = 'TYPE00' ]; then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi

#---- Finish Line ------------------------------------------------------------------

section "Completion Status"

msg "Success. Task complete."
echo

#---- Cleanup
# Clean up CT tmp files
pct exec $CTID -- bash -c "rm -R /tmp/${GIT_REPO} &> /dev/null; rm /tmp/${GIT_REPO}.tar.gz &> /dev/null"
#-----------------------------------------------------------------------------------