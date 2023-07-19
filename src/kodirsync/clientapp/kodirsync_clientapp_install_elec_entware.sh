#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_elec_entware.sh
# Description:  Kodirsync client Entware install script (for CoreELEC/LibreELEC)
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Find cmd 'installentware'
filename=$(find / -type f -name 'installentware')
install_entware_cmd=$(grep 'http://bin.entware.net/\(.*\)/installer/generic.sh' $filename | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [ -z "$filename" ]
then
  warn "Error: 'installentware' file not found. Try manually installing Entware and run the Kodirsync installer again."
  exit 1
fi

# Set export path
export PATH=/opt/bin:/opt/sbin:$PATH

#---- Install Entware

# Check for Entware opt dir
[ ! -d /storage/.opt ] && mkdir -p /storage/.opt

if [ ! -f /opt/bin/opkg ]
then
  # Entware is required
  while true
  do
    msg "Entware is required by Kodirsync and needs to be installed before proceeding. If you agree, a reboot is required. After the reboot, you will need to reconnect via SSH and run the Kodirsync installer again."
    read -p "Install Entware and reboot (recommended) [y/N]? " choice
    case "$choice" in
      [yY]*)
        # Run the command
        sh -c "$install_entware_cmd"
        wait
        msg "Rebooting..."
        reboot && wait
        sleep 5  # Wait for the reboot process to start
        ;;
      [nN]*)
        msg "You have chosen not to install Entware. Exiting Kodirsync installation. Bye..."
        exit 0
        ;;
      *)
        msg "Invalid choice. Please enter 'y' or 'n'."
        ;;
    esac
  done
else
  msg "Entware is already installed. Updating..."
  opkg update
  opkg upgrade
fi
#-----------------------------------------------------------------------------------