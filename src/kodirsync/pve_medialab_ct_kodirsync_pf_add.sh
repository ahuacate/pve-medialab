#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# File_name:    pve_medialab_ct_kodirsync_pf_add.sh
# Description:  This script is for setting up port forward remote access
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

# Check configuration setting
get_var "pf_enable" "/usr/local/bin/kodirsync/kodirsync.conf"
pf_enable="$get_var"
if [ "$pf_enable" = 1 ]
then
  msg "Checking remote connection status..."
  info "Kodirsync is already configured for remote port forward (PF) connections. To create new PF credentials you must first remove the current PF settings using our Kodirsync removal tool which is available in the Kodirsync Toolbox."
  echo
  return
fi

# Check for kodirsync hostname
if [[ ! "$HOSTNAME" =~ ^kodirsync[.-]?[0-9]+?[0-9]+?$ ]]
then
  echo -e "PVE CT hostname check: \033[0;31mThis is not a 'kodirsync' CT\033[0m\n\nPVE Kodirsync must have a hostname of 'kodirsync'. Fix the issue and try again..."
  exit 0
fi

#---- Static Variables -------------------------------------------------------------

# PF port
pf_port='2222'

#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='Kodirsync'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- Create Kodi client package
section "Add SSLH ACMI certificates & keys"

# Select a connection method
ct_ssh_port=$(egrep --color=no '^(#)?Port' /etc/ssh/sshd_config | sed '/^#/d' | awk '{ print $2 }')
msg_box "#### PLEASE READ CAREFULLY - PF REMOTE CONNECTION ####\n
For remote internet connections you require dynamic dns service to resolve your WAN IP inbound remote connections to this Kodirsync server. 

Pre-requisites to configure Kodirsync for PF connectivity are:
   --  Dynamic DNS provider
   --  WAN Gateway port forwarded to "$(hostname).$(hostname -d):$ct_ssh_port"

Kodirsync clients configured for remote access can also be installed on your LAN network. The Kodirsync client by default first checks for a local LAN Kodirsync server before switching to remote access protocols to connect over the internet WAN."
echo

#---- Set Remote connection SSLH URL

url_regex='[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'

while true
do
  msg "For remote PF connectivity you require a working Dynamic DNS URL address which connects to your Kodirsync server from the internet (WAN)."
  read -p "Enter your Dynamic DNS URL address: " url_var
  url=$(echo "$url_var" | sed -E 's/[^.]*\.([[:alpha:].]+).*/\1/')

  # Check SSLH URL
  if [[ $(ping -c1 "$url" &>/dev/null) ]] && [[ "$url" =~ "$url_regex" ]]
  then
    info "Remote SSLH address is set: ${YELLOW}"$url"${NC}"
    pf_address_url="$url"
    echo
    break  
  else
    warn "There are problems with your input:\n\n1. URL '$url' is not reachable.\n2.Do not prefix your input with 'www' or 'http/https'.3. A valid URL resembles: myddns-site1.foo.bar\n\nCheck your URL address, remember to include any subdomain and try again..."
    echo
  fi
done

#---- Set Remote connection SSLH Port

msg "Confirm your remote PF connection port number. Port $pf_port is our default."
read -p "Enter your PF port number: " -e -i $pf_port pf_port_var
pf_port="$pf_port_var"
info "Remote PF port is set: ${YELLOW}"$pf_port"${NC}"
echo


#---- Edit Kodirsync server conf file

# Uses Func 'edit_config_value'
config_file='/usr/local/bin/kodirsync/kodirsync.conf'

# SSLH access
key=sslh_enable
value=0
crudini --set "$config_file" "" "$key" "$value"

# PF access
key=pf_enable
value=1
crudini --set "$config_file" "" "$key" "$value"

key=pf_address_url
value="$pf_address_url"
crudini --set "$config_file" "" "$key" "$value"

key=pf_port
value="$pf_port"
crudini --set "$config_file" "" "$key" "$value"

# Local LAN
ip_address_url="$(hostname -I | sed 's/\s//g')"
localdomain_address_url="$(hostname).$(hostname -d)"

key=ip_address_url
value="$ip_address_url"
crudini --set "$config_file" "" "$key" "$value"

key=localdomain_address_url
value="$localdomain_address_url"
crudini --set "$config_file" "" "$key" "$value"

#-----------------------------------------------------------------------------------