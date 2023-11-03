#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     tdarr_sw.sh
# Description:  Source script for App SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )
COMMON_DIR="$DIR/../../common"
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"
SHARED_DIR="$DIR/../../shared"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_DIR/bash/src/basic_bash_utility.sh

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"           # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Install sudo
apt-get install -y sudo

# Install unzip
apt-get install -y unzip

# Install jq
apt-get install -y jq

# Install curl and wget
apt-get install -y curl wget

# Install vainfo
apt-get install -y vainfo

# Make NAS media autoadd/tdarr source dirs
if [ -e "/mnt/public" ]; then
    su - $app_uid -c "if [ ! -e '/mnt/public/autoadd/.foo_protect' ]; then
        mkdir -p '/mnt/public/autoadd/tdarr/{in_homevideo,in_unsorted,out_unsorted}'
        chown -R $app_uid:$app_guid /mnt/public/autoadd/tdarr
    fi"
fi

# Make Tdarr transcode tmp dir
if [ -e "/mnt/transcode" ]; then
    su - $app_uid -c 'mkdir -p "/mnt/transcode/tdarr"'
    su - $app_uid -c "chown -R $app_uid:$app_guid /mnt/transcode/tdarr"
fi

# Make Tdarr backup dir
if [ -e "/mnt/backup" ]; then
    su - $app_uid -c 'mkdir -p "/mnt/backup/tdarr"'
    su - $app_uid -c "chown -R $app_uid:$app_guid /mnt/backup/tdarr"
fi


#---- Set up hardware acceleration

# Intel hardware - https://dgpu-docs.intel.com/driver/client/virtualized.html
if lscpu | grep -q "Vendor ID:\s*GenuineIntel"; then
    # Import the Intel GPG key without prompts
    apt-get install -y gpg-agent
    wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
    gpg --dearmor --yes --trust-model always --output /usr/share/keyrings/intel-graphics.gpg
    echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
    tee /etc/apt/sources.list.d/intel-gpu-jammy.list
    apt-get update -y

    # Install the Out-of-Tree Kernel Module
    apt-get install -y \
    intel-fw-gpu 

    #  Install Compute, Media, and Display runtimes
    apt-get install -y \
    intel-opencl-icd intel-level-zero-gpu level-zero \
    intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 \
    va-driver-all vainfo

    # Verify OpenCL
    apt-get install clinfo

    # Configure the Permissions to Access the GPU
    usermod -aG render $app_uid  # Add user (i.e media) to render group
    usermod -aG video $app_uid  # Add user (i.e media) to video group

    # Try to load the iHD driver, on fail use i965 driver
    if vainfo 2>&1 | grep -q '^.*iHD_drv_video\.so$'; then
        # If iHD fails, set the driver to i965
        if vainfo 2>&1 | grep -q '^.*dri/iHD_drv_video\.so.*failed$'; then
            # Permanently set the driver to iHD
            echo "export LIBVA_DRIVER_NAME=i965" >> ~/.bashrc
            echo "export LIBVA_DRIVER_NAME=i965" >> /home/$app_uid/.bashrc
            source ~/.bashrc
            su $app_uid -c "source ~/.bashrc"
        else
            # If pass, permanently set the driver to iHD
            echo "export LIBVA_DRIVER_NAME=iHD" >> ~/.bashrc
            echo "export LIBVA_DRIVER_NAME=iHD" >> /home/$app_uid/.bashrc
            source ~/.bashrc
            su $app_uid -c "source ~/.bashrc"
        fi 
    else
        # Permanently set the driver to i965
        echo "export LIBVA_DRIVER_NAME=i965" >> ~/.bashrc
        echo "export LIBVA_DRIVER_NAME=i965" >> /home/$app_uid/.bashrc
        source ~/.bashrc
        su $app_uid -c "source ~/.bashrc"
    fi
fi

# Check AMD hardware
if lscpu | grep -q "Vendor ID:\s*AuthenticAMD"; then
    # Install encoder kernels
    apt install build-essential dkms -y
    wget https://repo.radeon.com/amdgpu-install/22.40.3/ubuntu/jammy/amdgpu-install_5.4.50403-1_all.deb
    apt-get install ./amdgpu-install_5.3.50300-1_all.deb -y
    apt-get update
    amdgpu-install -y --accept-eula --opencl=legacy --headless --no-dkms --no-32 -y
    apt-get install libva-mesa-driver libva-dev -y
fi


#---- Tdarr prerequisites

# Required by CCExtractor to check files for closed captions
apt-get install -y libtesseract-dev

# Install MKVToolNix (for mkvpropedit)
wget -q --show-progress -O /usr/share/keyrings/gpg-pub-moritzbunkus.gpg https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg
apt-get -y update
apt-get install -y mkvtoolnix

# HandBrake CLI
apt-get install -y autoconf automake autopoint appstream build-essential cmake git libass-dev libbz2-dev libfontconfig1-dev libfreetype6-dev libfribidi-dev libharfbuzz-dev libjansson-dev liblzma-dev libmp3lame-dev libnuma-dev libogg-dev libopus-dev libsamplerate-dev libspeex-dev libtheora-dev libtool libtool-bin libturbojpeg0-dev libvorbis-dev libx264-dev libxml2-dev libvpx-dev m4 make meson nasm ninja-build patch pkg-config tar zlib1g-dev clang  # Dependencies
apt-get install -y libva-dev libdrm-dev  # Intel Quick Sync Video support, install the QSV dependencies
apt-get install -y handbrake-cli  # HandBrake app

# FFmpeg vers6
apt-get install -y software-properties-common
add-apt-repository --yes ppa:ubuntuhandbook1/ffmpeg6
apt-get update -y
apt-get install -y ffmpeg


# # # Install sudo
# # apt-get install sudo -y

# # # Install mc
# # apt-get install mc -y

# # # Install openCL
# # apt-get install ocl-icd-libopencl1 -y
# # apt-get install intel-opencl-icd -y
# exit 0
# sudo apt-get install -y curl sudo mc ocl-icd-libopencl1 intel-opencl-icd libmfx1 libmfxgen1 libvpl2 libegl-mesa0 libegl1-mesa libegl1-mesa-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri libglapi-mesa libgles2-mesa-dev libglx-mesa0 libigdgmm12 libxatracker2 mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers va-driver-all vainfo hwinfo clinfo


# /bin/HandBrakeCLI






#---- Install Tdarr

# Install Tdarr sw
mkdir -p /opt/tdarr/server  # Create CT tdarr dir
chown -R $app_uid:$app_guid /opt/tdarr  # Set permissions
chmod -R u+w /opt/tdarr
# Download Tdarr installer
attempts=3  # Set the number of retry attempts
for ((i=1; i<=attempts; i++)); do
    if wget --show-progress -P /opt/tdarr https://f000.backblazeb2.com/file/tdarrs/versions/2.00.15/linux_x64/Tdarr_Updater.zip; then
        echo "Download successful on attempt $i."
        break  # Exit the loop if the download is successful
    else
        echo "Download failed on attempt $i. Retrying..."
    fi

    if [ "$i" -eq "$attempts" ]; then
        echo "Download failed after $attempts attempts. Check for issues."
        return 1
    fi
done
unzip /opt/tdarr/Tdarr_Updater.zip -d /opt/tdarr
rm -rf /opt/tdarr/Tdarr_Updater.zip
chmod +x /opt/tdarr/Tdarr_Updater 
# Run installer
attempts=3  # Set the number of retry attempts
for ((i=1; i<=attempts; i++)); do
    if /opt/tdarr/Tdarr_Updater 2>/dev/null; then
        chown -R $app_uid:$app_guid /opt/tdarr  # Set ownership & rights
        echo "Updater ran successfully on attempt $i."
        break  # Exit the loop if the updater runs successfully
    else
        echo "Updater failed on attempt $i. Retrying..."
    fi

    if [ "$i" -eq "$attempts" ]; then
        echo "Updater failed after $attempts attempts. Check for issues."
        return 1
    fi
done


# Create services
service_path="/etc/systemd/system/tdarr-server.service"
echo "[Unit]
Description=Tdarr Server Daemon
After=network.target
# Enable if using ZFS, edit and enable if other FS mounting is required to access directory
#Requires=zfs-mount.service

[Service]
User=$app_uid
Group=$app_guid

Type=simple
WorkingDirectory=/opt/tdarr/Tdarr_Server
ExecStartPre=/opt/tdarr/Tdarr_Updater                  
ExecStart=/opt/tdarr/Tdarr_Server/Tdarr_Server
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" >$service_path

service_path="/etc/systemd/system/tdarr-node.service"
echo "[Unit]
Description=Tdarr Node Daemon
After=network.target
Requires=tdarr-server.service

[Service]
User=$app_uid
Group=$app_guid

Type=simple
WorkingDirectory=/opt/tdarr/Tdarr_Node
ExecStart=/opt/tdarr/Tdarr_Node/Tdarr_Node
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" >$service_path

# Enable services
systemctl enable -q tdarr-server.service
systemctl enable -q tdarr-node.service

# Restart services - to build tdarr config/settings files
pct_start_systemctl tdarr-server.service
pct_start_systemctl tdarr-node.service
#-----------------------------------------------------------------------------------