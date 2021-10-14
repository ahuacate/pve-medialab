#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_medialab_ct_ahuabooks.sh
# Description:  This script is for creating a Ahuabooks suite CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/scripts/pve_medialab_ct_ahuabooks.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}/../../common/pve/source"

#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your PVE hosts internet connection and try again..."
  echo
  exit 0
fi

# Run Bash Header
source ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------

# Set Max CT Host CPU Cores 
HOST_CPU_CORES=$(( $(lscpu | grep -oP '^Socket.*:\s*\K.+') * ($(lscpu | grep -oP '^Core.*:\s*\K.+') * $(lscpu | grep -oP '^Thread.*:\s*\K.+')) ))
if [ ${HOST_CPU_CORES} -gt 4 ]; then 
  CT_CPU_CORES_VAR=$(( ${HOST_CPU_CORES} / 2 ))
elif [ ${HOST_CPU_CORES} -le 4 ]; then
  CT_CPU_CORES_VAR=2
fi

# CT SSH Port
SSH_PORT_VAR='22'

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=0

# Developer enable git mounts inside CT (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=0

#---- Other Variables --------------------------------------------------------------

# Container Hostname
CT_HOSTNAME_VAR='ahuabooks'
# Container IP Address (192.168.50.118)
CT_IP_VAR='192.168.50.118'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.50.5'
# DNS Server
CT_DNS_SERVER_VAR='192.168.50.5'
# Container Number
CTID_VAR='118'
# Container VLAN
CT_TAG_VAR='50'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='8'
# Container allocated RAM
CT_RAM_VAR='1024'
# Easy Script Section Header Body Text
SECTION_HEAD='MediaLab Ahuabooks'
#---- Do Not Edit
# Container Swap
CT_SWAP="$(( $CT_RAM_VAR / 2 ))"
# CT CPU Cores
CT_CPU_CORES="$CT_CPU_CORES_VAR"
# CT unprivileged status
CT_UNPRIVILEGED='1'
# Features (0 means none)
CT_FUSE='0'
CT_KEYCTL='0'
CT_MOUNT='0'
CT_NESTING='0'
# Startup Order
CT_STARTUP='2'
# Container Root Password ( 0 means none )
CT_PASSWORD='0'
# PVE Container OS
OSTYPE='ubuntu'
OSVERSION='21.04'


#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for CT
cat << 'EOF' > pvesm_required_list
audio|Audiobooks and podcasts
backup|CT settings backup storage
books|Ebooks and Magazines
downloads|General downloads storage
public|General public storage
EOF

#---- Body -------------------------------------------------------------------------

#---- Introduction
source ${COMMON_PVE_SOURCE}/pvesource_ct_intro.sh

#---- Setup PVE CT Variables
source ${COMMON_PVE_SOURCE}/pvesource_ct_setvmvars.sh

#---- Create OS CT
source ${COMMON_PVE_SOURCE}/pvesource_ct_createvm.sh

#---- Pre-Configuring PVE CT
section "Pre-Configure ${OSTYPE^} CT"

# MediaLab CT unprivileged mapping
if [ $CT_UNPRIVILEGED = 1 ]; then
  source ${COMMON_PVE_SOURCE}/pvesource_ct_medialab_ctidmapping.sh
fi

# Create CT Bind Mounts
source ${COMMON_PVE_SOURCE}/pvesource_ct_createbindmounts.sh

# #---- Configure New CT OS
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntubasics.sh

# #---- Create MediaLab Group and User
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_addmedialabuser.sh

#---- Ahuabooks --------------------------------------------------------------------

section "Install ${CT_HOSTNAME_VAR^} software"

#---- Prerequisites
msg "Creating Application settings, logs folder..."
pct exec $CTID -- mkdir -p /home/media/lazylibrarian/{Logs,.config}
pct exec $CTID -- mkdir -p /home/media/calibre/{logs,.config}
pct exec $CTID -- mkdir -p /home/media/calibre-web/{logs,.config}
pct exec $CTID -- mkdir -p /home/media/booksonic/transcode
pct exec $CTID -- mkdir -p /home/media/podgrab
pct exec $CTID -- chown -hR 1605:65605 /home/media

msg "Creating storage folders..."
pct exec $CTID -- runuser media -c 'mkdir -p /mnt/books/{ebooks,comics,magazines}'
pct exec $CTID -- runuser media -c 'mkdir -p /mnt/audio/{audiobooks,podcasts}'
pct exec $CTID -- runuser media -c 'mkdir -p /mnt/public/autoadd/direct_import/lazylibrarian'

msg "Installing prerequisites (be patient, might take a while)..."
pct exec $CTID -- apt-get install git xdg-utils xvfb python3-pip libnss3 python3-openssl python3-oauth libffi-dev imagemagick rename id3v2 id3tool unzip ffmpeg libgl1-mesa-glx unrar -y
pct exec $CTID -- pip install --no-warn-script-location apprise urllib3 Pillow python-Levenshtein
# Prerequisite - Installing Go for Podgrab
GO_URL="$(curl -s https://golang.org/dl/ | grep -oP 'go1.1.([0-9\.]+)\.linux-amd64\.tar\.gz' | sort -V | tail -n 1)"
pct exec $CTID -- wget https://golang.org/dl/${GO_URL} -P /tmp
pct exec $CTID -- rm -rf /usr/local/go
pct exec $CTID -- tar -C /usr/local -xzf /tmp/${GO_URL}
pct exec $CTID -- rm /tmp/${GO_URL}
pct exec $CTID -- bash -c 'echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile'
pct exec $CTID -- bash -c 'source /etc/profile'
pct exec $CTID -- bash -c 'echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc'
if [ $(pct exec $CTID -- bash -c 'command -v go version > /dev/null; echo $?') = 0 ]; then
  echo -e "Go installation status: \033[0;31mFail\033[0m\n\nCannot proceed without Go software - problem unknown.\nUser intervention required. Exiting installation script in 3 second..."
  sleep 3
  exit 0
fi

#---- Installing Lazylibrarian
msg "Installing LazyLibrarian software (be patient, might take a while)..."
pct exec $CTID -- git clone https://gitlab.com/LazyLibrarian/LazyLibrarian.git /opt/LazyLibrarian
pct exec $CTID -- chown -R 1605:65605 /opt/LazyLibrarian
pct exec $CTID -- bash -c 'mkdir -p /home/media/lazylibrarian/.config'
pct exec $CTID -- chown -R 1605:65605 /home/media/lazylibrarian/.config
pct push $CTID ${DIR}/source/pve_medialab_ct_ahuabooks_settings/default_lazylibrarian.ini /home/media/lazylibrarian/.config/lazylibrarian.ini --group 65605 --user 1605

msg "Creating LazyLibrarian system.d file..."
cat << 'EOF' > $TEMP_DIR/lazy.service
[Unit]
Description=Lazylibrarian

[Service]
ExecStart=/usr/bin/python3 /opt/LazyLibrarian/LazyLibrarian.py --daemon --config /home/media/lazylibrarian/.config/lazylibrarian.ini --datadir /home/media/lazylibrarian --nolaunch --quiet --update
GuessMainPID=no
Type=forking
User=media
Group=medialab
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID $TEMP_DIR/lazy.service /etc/systemd/system/lazy.service

#---- Installing Calibre
msg "Installing Calibre software (be patient, might take a while)..."
set +Eeuo pipefail
pct exec $CTID -- bash -c 'wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin > /dev/null'
set -Eeuo pipefail
pct exec $CTID -- chown -hR 1605:65605 /opt/calibre

msg "Creating the Calibre database (by adding a dummy book)...."
pct exec $CTID -- wget http://www.gutenberg.org/ebooks/219.epub.noimages -O /mnt/public/autoadd/direct_import/lazylibrarian/heart.epub
pct exec $CTID -- runuser media -c 'xvfb-run calibredb add /mnt/public/autoadd/direct_import/lazylibrarian/heart.epub --library-path /mnt/books/ebooks'
pct exec $CTID -- rm /mnt/public/autoadd/direct_import/lazylibrarian/heart.epub

msg "Creating a Calibre log file...."
pct exec $CTID -- touch /home/media/calibre/logs/calibre.log
pct exec $CTID -- chown -hR 1605:65605 /home/media/calibre/logs/calibre.log

msg "Creating Calibre-server system.d file..."
cat << 'EOF' > $TEMP_DIR/calibre-server.service
[Unit]
Description=calibre content server
After=network.target calibre-web.service
[Service]
Type=simple
User=media
Group=medialab
ExecStart="/usr/bin/calibre-server" "/mnt/books/ebooks/" --enable-local-write --listen-on=:: --log="/home/media/calibre/logs/calibre.log" --max-log-size 2
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID $TEMP_DIR/calibre-server.service /etc/systemd/system/calibre-server.service

#---- Installing Calibre-web
msg "Installing Calibre-web software (be patient, might take a while)..."
pct exec $CTID -- wget https://github.com/janeczku/calibre-web/archive/master.zip -O /tmp/master.zip
pct exec $CTID -- unzip -q /tmp/master.zip -d /tmp
pct exec $CTID -- mv /tmp/calibre-web-master /opt/calibre-web
pct exec $CTID -- chown -hR 1605:65605 /opt/calibre-web
pct exec $CTID -- bash -c 'cd /opt/calibre-web && python3 -m pip install --system --target vendor -r requirements.txt'

msg "Creating Calibre-web system.d file..."
cat << 'EOF' > $TEMP_DIR/calibre-web.service
[Unit]
Description=Calibre-Web
After=network.target

[Service]
Type=simple
User=media
Group=medialab
ExecStart=/usr/bin/python3 /opt/calibre-web/cps.py
WorkingDirectory=/home/media/calibre-web/

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID $TEMP_DIR/calibre-web.service /etc/systemd/system/calibre-web.service

#---- Installing Booksonic
msg "Installing Booksonic software (be patient, might take a while)..."
pct exec $CTID -- apt-get install openjdk-8-jre -y
pct exec $CTID -- mkdir -p /opt/booksonic
pct exec $CTID -- wget https://github.com/popeen/Booksonic-Air/releases/download/v2009.1.0/booksonic.war -P /opt/booksonic
pct exec $CTID -- chown -hR 1605:65605 /opt/booksonic

msg "Creating Booksonic system.d file..."
cat << 'EOF' > $TEMP_DIR/booksonic.service
[Unit]
Description=Booksonic Media Server
After=remote-fs.target network.target
AssertPathExists=/home/media/booksonic

[Service]
Type=simple
Environment="JAVA_JAR=/opt/booksonic/booksonic.war"
Environment="JAVA_OPTS=-Xmx512m"
Environment="BOOKSONIC_HOME=/home/media/booksonic"
Environment="PORT=4040"
Environment="CONTEXT_PATH=/booksonic"
Environment="JAVA_ARGS="
EnvironmentFile=-/etc/default/booksonic
ExecStart=/usr/bin/java \
          $JAVA_OPTS \
          -Dairsonic.home=${BOOKSONIC_HOME} \
          -Dairsonic.defaultMusicFolder=/mnt/audio/audiobooks \
          -Dairsonic.defaultPodcastFolder=/mnt/audio/podcasts \
          -Dairsonic.defaultPlaylistFolder=/home/media/booksonic/playlists \
          -Dserver.servlet.contextPath=${CONTEXT_PATH} \
          -Dserver.port=${PORT} \
          -jar ${JAVA_JAR} $JAVA_ARGS
User=media
#Group=medialab

DevicePolicy=closed
DeviceAllow=char-alsa rw
NoNewPrivileges=yes
PrivateTmp=yes
PrivateUsers=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
RestrictRealtime=yes
SystemCallFilter=~@clock @debug @module @mount @obsolete @privileged @reboot @setuid @swap
ReadWritePaths=/home/media/booksonic

# You can uncomment the following line if you're not using the jukebox
# This will prevent airsonic from accessing any real (physical) devices
#PrivateDevices=yes

# You can change the following line to `strict` instead of `full`
# if you don't want airsonic to be able to
# write anything on your filesystem outside of AIRSONIC_HOME.
ProtectSystem=full

# You can uncomment the following line if you don't have any media
# in /home/…. This will prevent airsonic from ever reading/writing anything there.
#ProtectHome=true

# You can uncomment the following line if you're not using the OpenJDK.
# This will prevent processes from having a memory zone that is both writeable
# and executable, making hacker's lives a bit harder.
#MemoryDenyWriteExecute=yes

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID $TEMP_DIR/booksonic.service /etc/systemd/system/booksonic.service

# Create directory symlink to ffmpeg
pct exec $CTID -- ln -s /usr/bin/ffmpeg /home/media/booksonic/transcode
pct exec $CTID -- chown -h media:medialab /home/media/booksonic/transcode/ffmpeg


#---- Installing Podgrab
msg "Installing Podgrab software (be patient, might take a while)..."
pct exec $CTID -- apt-get install -y git ca-certificates ufw gcc > /dev/null
pct exec $CTID -- git clone --depth 1 https://github.com/akhilrex/podgrab /tmp/podgrab
pct exec $CTID -- bash -c 'cd /tmp/podgrab && /usr/local/go/bin/go mod tidy'
pct exec $CTID -- mkdir -p /tmp/podgrab/dist
pct exec $CTID -- bash -c 'cp -r /tmp/podgrab/client /tmp/podgrab/dist'
pct exec $CTID -- bash -c 'cp -r /tmp/podgrab/webassets /tmp/podgrab/dist'
pct exec $CTID -- bash -c 'cp /tmp/podgrab/.env /tmp/podgrab/dist'
pct exec $CTID -- bash -c 'cd /tmp/podgrab && /usr/local/go/bin/go build -o ./dist/podgrab ./main.go'
pct exec $CTID -- mkdir -p /usr/local/bin/podgrab
pct exec $CTID -- bash -c 'mv -v /tmp/podgrab/dist/* /usr/local/bin/podgrab &> /dev/null'
pct exec $CTID -- bash -c 'mv -v /tmp/podgrab/dist/.env /usr/local/bin/podgrab'
pct exec $CTID -- rm -R /tmp/podgrab


# Set environment file
cat << 'EOF' > $TEMP_DIR/.env
CONFIG=/home/media/podgrab
DATA=/mnt/audio/podcasts
CHECK_FREQUENCY = 360
PASSWORD=
PORT = 4041
# test
EOF
pct push $CTID $TEMP_DIR/.env /usr/local/bin/podgrab/.env

msg "Creating Podgrab system.d file..."
cat << 'EOF' > $TEMP_DIR/podgrab.service
[Unit]
Description=Podgrab
After=remote-fs.target network.target

[Service]
ExecStart=/usr/local/bin/podgrab/podgrab
WorkingDirectory=/usr/local/bin/podgrab/
User=media
Group=medialab

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID $TEMP_DIR/podgrab.service /etc/systemd/system/podgrab.service

#---- Starting Servers
msg "Starting Lazylibrarian..."
if [ $(pct exec $CTID -- systemctl is-active lazy.service) != "active" ]; then
  pct exec $CTID -- systemctl start lazy.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active lazy.service) == "active" ]; then
    break
  fi
  sleep 5
  done
fi
msg "Starting Calibre-web..."
if [ $(pct exec $CTID -- systemctl is-active calibre-web.service) != "active" ]; then
  pct exec $CTID -- systemctl start calibre-web.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active calibre-web.service) == "active" ]; then
    break
  fi
  sleep 5
  done
fi
msg "Starting Calibre-server..."
if [ $(pct exec $CTID -- systemctl is-active calibre-server.service) != "active" ]; then
  pct exec $CTID -- systemctl start calibre-server.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active calibre-server.service) == "active" ]; then
    break
  fi
  sleep 5
  done
fi
msg "Starting Booksonic..."
if [ $(pct exec $CTID -- systemctl is-active booksonic.service) != "active" ]; then
  pct exec $CTID -- systemctl start booksonic.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active booksonic.service) == "active" ]; then
    break
  fi
  sleep 5
  done
fi
msg "Starting Podgrab..."
if [ $(pct exec $CTID -- systemctl is-active podgrab.service) != "active" ]; then
  pct exec $CTID -- systemctl start podgrab.service
  while true; do
  if [ $(pct exec $CTID -- systemctl is-active podgrab.service) == "active" ]; then
    break
  fi
  sleep 5
  done
fi
pct exec $CTID -- systemctl enable lazy.service
pct exec $CTID -- systemctl enable calibre-web.service
pct exec $CTID -- systemctl enable calibre-server.service
pct exec $CTID -- systemctl enable booksonic.service
pct exec $CTID -- systemctl enable podgrab.service

#---- Installing default Calibre plugins
msg "Installing Calibre plugins..."
pct exec $CTID -- wget --content-disposition $( curl -s https://api.github.com/repos/apprenticeharper/DeDRM_tools/releases/latest | grep "browser_download_url.*zip" | cut -d : -f 2,3 | tr -d \" ) -P /tmp/
pct exec $CTID -- unzip -q /tmp/$( curl -s https://api.github.com/repos/apprenticeharper/DeDRM_tools/releases/latest | grep "browser_download_url.*zip" | cut -d : -f 2,3 | tr -d \" | sed 's/.*\///' ) -d /tmp
pct exec $CTID -- calibre-customize --add /tmp/DeDRM_plugin.zip
pct exec $CTID -- calibre-customize --enable DeDRM_plugin


#---- Apply Ahuabooks settings
section "Apply ${CT_HOSTNAME_VAR^} Easy Script application settings"
if [ $ES_AUTO = 0 ]; then
  msg "Applying ${CT_HOSTNAME_VAR^} Easy Script application settings..."
  source ${DIR}/source/pve_medialab_ct_ahuabooks_settings/pve_medialab_ct_ahuabooks_settings.sh
  echo
elif [ $(pct exec $CTID -- bash -c '[ -d "/mnt/downloads" ]'; echo $?) = 0 ]; then
  msg_box "#### PLEASE READ CAREFULLY ####\n
  You have the option to configure ${CT_HOSTNAME_VAR^} with our Easy Script application settings. Your ${CT_HOSTNAME_VAR^} software will then be fully configured to work with our suite of PVE Medialab CT's and applications."
  sleep 2
  echo
  while true; do
    read -p "Proceed to apply our ${CT_HOSTNAME_VAR^} application settings (Recommended) [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        msg "Applying ${CT_HOSTNAME_VAR^} Easy Script application settings..."
        source ${DIR}/source/pve_medialab_ct_ahuabooks_settings/pve_medialab_ct_ahuabooks_settings.sh
        echo
        break
        ;;
      [Nn]*)
        info "You have chosen to skip this step. Your ${CT_HOSTNAME_VAR^} application settings are software defaults."
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
fi


#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "Success. LazyLibrarian, Calibre, Calibre-web, Booksonic and Podgrab are fully installed. Web-interfaces are available at:

LazyLibrarian
  --  ${WHITE}http://$CT_IP:5299${NC} ( password:none set )\n
  --  ${WHITE}http://${CT_HOSTNAME}:5299${NC}

Calibre-Web
  --  ${WHITE}http://$CT_IP:8083${NC} ( user:admin | password:admin123 )\n
  --  ${WHITE}http://${CT_HOSTNAME}:8083${NC}

Booksonic
  --  ${WHITE}http://$CT_IP:4040/booksonic${NC} ( user:admin | password:admin )\n
  --  ${WHITE}http://${CT_HOSTNAME}:4040${NC}

Podgrab
  --  ${WHITE}http://$CT_IP:4041${NC} ( password:none set )\n
  --  ${WHITE}http://${CT_HOSTNAME}:4041${NC}

For configuring all Ahuabooks applications we have instructions: ${WHITE}https://github.com/ahuacate/ahuabooks${NC}"
echo

# Cleanup
trap cleanup EXIT