#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_jellyfin.sh
# Description:  This script is for creating a Proxmox Jellyfin CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_jellyfin.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="$DIR/../../common/pve/source"
echo $COMMON_PVE_SOURCE

#########################################################################################
# This script is for creating your Proxmox Jellyfin CT - Ubuntu 18.04	      	          #
#                                                                 						          #
# Tested on Proxmox Version : pve-manager/6.1-3/37248ce6 (running kernel: 5.3.10-1-pve) #
#########################################################################################

# Command to run script
#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-lxc-media/master/scripts/jellyfin_create_ct_18.04.sh)"

