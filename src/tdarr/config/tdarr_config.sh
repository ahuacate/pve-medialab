#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     tdarr_config.sh
# Description:  Source script for Tdarr config
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )
COMMON_DIR="$DIR/../../../common"
COMMON_PVE_SRC_DIR="$DIR/../../../common/pve/src"
SHARED_DIR="$DIR/../../../shared"

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

# Enable services
systemctl restart tdarr-server.service
systemctl restart tdarr-node.service

# Waiting to hear from services
while ! [[ "$(systemctl is-active tdarr-server.service)" == 'active' ]]; do
    echo -n .
done
while ! [[ "$(systemctl is-active tdarr-node.service)" == 'active' ]]; do
    echo -n .
done

# Wait for Tdarr config files to be created
while ! [ -e "/opt/tdarr/configs/Tdarr_Server_Config.json" ] && [ -e "/opt/tdarr/configs/Tdarr_Node_Config.json" ]; do
    echo -n .
    sleep 5
done

# Stop services to perform settings edits
pct_stop_systemctl tdarr-server.service
pct_stop_systemctl tdarr-node.service

# Edit Tdarr app paths
jq '.handbrakePath = "/bin/HandBrakeCLI"' /opt/tdarr/configs/Tdarr_Node_Config.json > tmp.json && mv tmp.json /opt/tdarr/configs/Tdarr_Node_Config.json  # Node Handbrake
jq '.handbrakePath = "/bin/HandBrakeCLI"' /opt/tdarr/configs/Tdarr_Server_Config.json > tmp.json && mv tmp.json /opt/tdarr/configs/Tdarr_Server_Config.json  # Server Handbrake
jq '.ffmpegPath = "/bin/ffmpeg"' /opt/tdarr/configs/Tdarr_Node_Config.json > tmp.json && mv tmp.json /opt/tdarr/configs/Tdarr_Node_Config.json  # Node Handbrake
jq '.ffmpegPath = "/bin/ffmpeg"' /opt/tdarr/configs/Tdarr_Server_Config.json > tmp.json && mv tmp.json /opt/tdarr/configs/Tdarr_Server_Config.json  # Server Handbrake

# DL plugin
plugin_name="Tdarr_Plugin_Ahuacate_FFMPEG_QSV_HEVC.js"
cp -f "$DIR/$plugin_name" "/opt/tdarr/server/Tdarr/Plugins/Local/"
chown $app_uid:$app_guid /opt/tdarr/server/Tdarr/Plugins/Local/$plugin_name  # Set ownership & rights
chmod 666 /opt/tdarr/server/Tdarr/Plugins/Local/$plugin_name

# Restart services - to build tdarr config/settings files
pct_start_systemctl tdarr-server.service
pct_start_systemctl tdarr-node.service
#-----------------------------------------------------------------------------------