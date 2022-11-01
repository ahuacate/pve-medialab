#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nzbget_sw.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"       # App name
app_uid=${APP_USERNAME}        # App UID
app_guid=${APP_GRPNAME}        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Installing NZBGet
# Downloading latest SW
wget --show-progress https://nzbget.net/download/nzbget-latest-bin-linux.run -P /tmp

# Install SW
sh /tmp/nzbget-latest-bin-linux.run
chown -R ${app_uid}:${app_guid} /opt/nzbget


msg "Creating nzbget.service system.d file..."
cat <<EOF | tee /etc/systemd/system/$app.service >/dev/null
[Unit]
Description=NZBGet Daemon
Documentation=http://nzbget.net/Documentation
After=network.target

[Service]
User=$app_uid
Group=$app_guid
ExecStart=/opt/nzbget/nzbget -D
ExecStop=/opt/nzbget/nzbget -Q
ExecReload=/opt/nzbget/nzbget -O
Type=forking
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Start the App
systemctl -q daemon-reload
systemctl enable --now -q "$app"
#-----------------------------------------------------------------------------------