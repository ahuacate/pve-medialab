#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     mono_22.04_sw.sh
# Description:  Source script for Mono SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Installing mono
# Adding mono key
gpg --no-default-keyring --keyring /usr/share/keyrings/mono_official-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &> /dev/null

# Adding mono repository list
echo "deb [arch=$( dpkg --print-architecture ) signed-by=/usr/share/keyrings/mono_official-archive-keyring.gpg] https://download.mono-project.com/repo/ubuntu stable-focal main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list > /dev/null

# Updating container OS
apt-get -y update > /dev/null

# Installing mono
apt-get install -y mono-devel
#-----------------------------------------------------------------------------------