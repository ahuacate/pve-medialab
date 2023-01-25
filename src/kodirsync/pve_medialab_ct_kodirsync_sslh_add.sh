#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# File_name:    pve_medialab_ct_kodirsync_sslh_add.sh
# Description:  This script is for setting up remote access
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

# Check for existing files
get_config_value "/usr/local/bin/kodirsync/kodirsync.conf" "sslh_enable" 
sslh_enable="$get_var"
echo "sslh_enable status: $sslh_enable"
if [ -f "/root/.ssh/sslh.crt" ] && [ -f "/root/.ssh/sslh-kodirsync.key" ] && [ "$sslh_enable" = 1 ]
then
  msg "Checking remote connection status..."
  info "Kodirsync is already configured for SSLH remote connections. To create new SSLH credentials you must first remove the current SSLH settings using our Kodirsync removal tool which is available in the Kodirsync Toolbox."
  echo
  return
fi

# Check for kodirsync hostname
if [[ ! "$HOSTNAME" =~ ^kodirsync[.-]?[0-9]+?[0-9]+?$ ]]
then
  echo -e "PVE CT hostname check: \033[0;31mThis is not a 'kodirsync' CT\033[0m\n\nPVE Kodirsync must have a hostname of 'kodirsync'. Fix the issue and try again..."
  exit 0
fi

#  Check for Xclip
if [[ ! $(dpkg -s xclip 2> /dev/null) ]]
then
  echo "Checking for xclip software..."
  apt-get install xclip -y > /dev/null
  echo "#pbcopy & pbpaste aliases" >> ~/.bash_aliases
  echo "alias pbcopy='xclip -selection clipboard'" >> ~/.bash_aliases
  echo "alias pbpaste='xclip -selection clipboard -o'"  >> ~/.bash_aliases
  source ~/.bashrc
  echo -e "Xclip status: \033[0;32mOK\033[0m"
fi

#---- Static Variables -------------------------------------------------------------

# SSLH port
sslh_port='443'
# SSLH key and certificate backup folder name
sslh_bak_dir="sslh_key_cert"
# SSLH cert
sslh_cert=sslh.crt
# SSLH key
sslh_key=sslh-kodirsync.key

#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='Kodirsync'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- Create Kodi client package
section "Add SSLH ACMI certificates & keys"

# Select a connection method
msg_box "#### PLEASE READ CAREFULLY - SSLH REMOTE CONNECTION ####\n
For remote internet connections you require HAProxy (pfSense) to manage inbound remote connections to this Kodirsync server. 

Pre-requisites to configure Kodirsync for SSLH connectivity are:
  --  A valid domain URL address forwarded to your HAProxy server
  --  HAProxy configured as per our pfSense HAProxy guide
  --  Kodirsync Certificate file: Acmi+SSLH+-+Kodirsync.crt (HAProxy Acmi SSLH)
  --  Kodirsync User key file: Acmi+SSLH+-+Kodirsync.key (HAProxy Acmi SSLH)

HAProxy must be configured to use Acmi SSLH certificates and keys.

Kodirsync clients configured for remote access can also be installed on your LAN network. The Kodirsync client by default first checks for a local LAN Kodirsync server before switching to remote access protocols to connect over the internet WAN."
echo

#---- Set Remote connection SSLH URL
url_regex='[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'


while true
do
  msg "For remote SSLH connectivity you require a working URL address which connects to your HAProxy server from the internet (WAN). If you followed our HAProxy instructions it will be something like 'sslh-site.domain.com'. The URL address must be reachable by ping."
  read -p "Enter your HTTPS URL address: " url_var
  # url=$(echo "$url_var" | sed -E 's/[^.]*\.([[:alpha:].]+).*/\1/')
  url=$(echo "$url_var" | sed 's/ //g')

  # Check SSLH URL
  if [[ $(ping -c1 "$url" 2>/dev/null) ]] && [[ "$url" =~ $url_regex ]]
  then
    info "Remote SSLH address is set: ${YELLOW}$url${NC}"
    sslh_address_url="$url"
    echo
    break  
  else
    warn "There are problems with your input:\n\n1. HTTPS URL '$url' is not reachable.\n2.Do not prefix your input with 'www' or 'http/https'.3. A valid URL resembles: sslh-site1.foo.bar\n\nCheck your URL address, remember to include any subdomain and try again..."
    echo
  fi
done

#---- Set Remote connection SSLH Port
msg "Confirm your remote SSLH connection port number. Port $sslh_port is our default."
read -p "Enter your SSLH port number: " -e -i $sslh_port sslh_port_var
sslh_port="$sslh_port_var"
info "Remote SSLH port is set: ${YELLOW}$sslh_port${NC}"


#---- Copy and Paste your existing cert & key into the terminal window
if [ -f "/mnt/backup/kodirsync/$sslh_bak_dir/$sslh_cert" ] && [ -f "/mnt/backup/kodirsync/$sslh_bak_dir/$sslh_key" ]
then
  # Copy sslh cert and key from backup
  cp "/mnt/backup/kodirsync/$sslh_bak_dir/$sslh_cert" /root/.ssh/
  cp "/mnt/backup/kodirsync/$sslh_bak_dir/$sslh_key" /root/.ssh/
  info "Acmi SSLH - Kodirsync Certificate File is restored from backup: ${GREEN}ok${NC}"
  info "Acmi SSLH - Kodirsync Key File is restored from backup: ${GREEN}ok${NC}"
  echo
else
  msg_box "#### PLEASE READ CAREFULLY - UPLOAD CERTS & KEYS ####\n\nWe require your 'Acmi SSLH - Kodirsync Certificate File' and 'Acmi SSLH - Kodirsync Key File'. Both these files can be exported from pfSense or HAProxy Certificate Manager. If you followed our pfSense HAProxy the exported filenames are as follows.\n\n  --  Acmi+SSLH+-+Kodirsync.crt\n  --  Acmi+SSLH+-+Kodirsync.key\n\nThese two files must be accessible by this computer. In the next steps you will be prompted to copy each file contents into this computers clipboard. If you are using a Windows OS use Notepad++ not the inbuilt TextPad application for content copying.\n\nPlease strictly follow our instructions to avoid any errors."
  echo

  # Paste list
  haproxy_LIST=( "crt,$sslh_cert,Kodirsync Certificate File" "key,$sslh_key,Kodirsync Key File" )

  # Upload Certificate & Key files
  while IFS=',' read -r -u 3 file_type file_name desc
  do
    while true
    do
      msg_box "#### PLEASE READ CAREFULLY - UPLOAD ${desc^^} ####\n\n  --  Copy Acmi+SSLH+-+Kodirsync.${file_type} file contents\n      1. Open your CA file Acmi+SSLH+-+Kodirsync.${file_type} in a text editor\n      2. Highlight the key contents (Ctrl + A)\n      3. Copy the highlighted contents to your computer clipboard (Ctrl + C)\n  --  Paste computer clipboard contents into the terminal when prompted\n      1. Mouse 'Right-Click' at the terminal prompt to paste"
      echo
      read -p "Have you copied your '${desc}' into your computers clipboard [y/n]? " -n 1 -r YN
      echo
      echo
      case $YN in
        [Yy]*)
          msg "Now '${WHITE}Right-Click${NC}' your mouse button at the terminal prompt. Your ${desc} should paste into this terminal window. We require a blank or empty line at the end of the ${desc} paste. If no blank line (empty line) appears you must press '${WHITE}Enter${NC}' to complete the task."
          echo
          inputline=$(sed '/^$/q')
          while true; do
            read -p "Accept your input [y/n]? " -n 1 -r YN
            echo
            case $YN in
              [Yy]*)
                echo
                echo ${inputline} |
                awk 'match($0,/- .* -/){
                  val=substr($0,RSTART,RLENGTH)
                  gsub(/- | -/,"",val)
                  gsub(OFS,ORS,val)
                  print substr($0,1,RSTART) ORS val ORS substr($0,RSTART+RLENGTH-1)
                }' > /root/.ssh/$file_name
                info "Acmi SSLH - ${desc} is set: ${GREEN}ok${NC}"
                # Create sslh backup of crt and key
                if [ -d "/mnt/backup" ]
                then
                  # Create Kodirsync server backup folder
                  mkdir -p "/mnt/backup/kodirsync"
                  mkdir -p "/mnt/backup/kodirsync/$sslh_bak_dir"
                  chmod 0750 "/mnt/backup/kodirsync/$sslh_bak_dir"
                  # Copy ssh crt and key to backup folder
                  cp /root/.ssh/$file_name "/mnt/backup/kodirsync/$sslh_bak_dir/"
                fi
                echo
                break 2
                ;;
              [Nn]*)
                msg "No problem. Try again..."
                echo
                break 1
                ;;
              *)
                warn "Error! Entry must be 'y' or 'n'. Try again..."
                echo
                ;;
            esac
          done
          ;;
        [Nn]*)
          msg "You must first copy your Acmi+SSLH+-+Kodirsync.${file_type} file into your computers clipboard. Follow the instructions. Try again..."
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  done 3<<< $(printf '%s\n' "${haproxy_LIST[@]}")
fi


#---- Edit Kodirsync server conf file
# Uses Func 'edit_config_value'
config_file='/usr/local/bin/kodirsync/kodirsync.conf'

# SSLH access
key=sslh_enable
value=1
edit_config_value "$config_file" "$key" "$value"

key=sslh_address_url
value="$sslh_address_url"
edit_config_value "$config_file" "$key" "$value"

key=sslh_port
value="$sslh_port"
edit_config_value "$config_file" "$key" "$value"

# PF access
key=pf_enable
value=0
edit_config_value "$config_file" "$key" "$value"

# Local LAN
local_ip_address="$(hostname -I | sed 's/\s//g')"
localdomain_address_url="$(hostname).$(hostname -d)"

key=local_ip_address
value="$local_ip_address"
edit_config_value "$config_file" "$key" "$value"

key=localdomain_address_url
value="$localdomain_address_url"
edit_config_value "$config_file" "$key" "$value"
#-----------------------------------------------------------------------------------