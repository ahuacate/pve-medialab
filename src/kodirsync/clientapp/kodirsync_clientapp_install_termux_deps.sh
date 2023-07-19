#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_termux_deps.sh
# Description:  Termux dependencies
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Dependencies

# Perform apt update
apt update -y

# Perform apt upgrade
apt upgrade -y

# List of packages to check and install
packages=( "tar" "blk-utils" "openssh" "openssl" "iproute2" "rsync" "curl" "e2fsprogs" "realpath" "termux-exec" "netcat-openbsd" "tmux" "cronie" )

# Package installer
for package in "${packages[@]}"; do
  if ! dpkg -s "$package" &> /dev/null; then
    echo "Installing $package..."
    pkg install "$package" -y 2> /dev/null
  fi
done

#---- Termux specific apps

# Install Termux-setup-storage
yes | termux-setup-storage

#-----------------------------------------------------------------------------------