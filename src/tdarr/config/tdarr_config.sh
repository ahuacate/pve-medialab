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
pct_restart_systemctl tdarr-server.service
pct_restart_systemctl tdarr-node.service

# Wait for Tdarr config files to be created
while ! [ -e "/opt/tdarr/configs/Tdarr_Server_Config.json" ] && [ -e "/opt/tdarr/configs/Tdarr_Node_Config.json" ]; do
    sleep 1  # wait until files exist
done

# Stop services to perform settings edits
pct_stop_systemctl tdarr-server.service
pct_stop_systemctl tdarr-node.service

# Edit Tdarr app paths
if [ "$(which HandBrakeCLI)" = '/bin/HandBrakeCLI' ]; then
    jq -r '.handbrakePath = "/bin/HandBrakeCLI"' /opt/tdarr/configs/Tdarr_Node_Config.json > tmp.json && mv tmp.json /opt/tdarr/configs/Tdarr_Node_Config.json  # Node Handbrake
    jq -r '.handbrakePath = "/bin/HandBrakeCLI"' /opt/tdarr/configs/Tdarr_Server_Config.json > tmp.json && mv tmp.json /opt/tdarr/configs/Tdarr_Server_Config.json  # Server Handbrake
fi
if [ "$(which ffmpeg)" = '/bin/ffmpeg' ]; then
    jq -r '.ffmpegPath = "/bin/ffmpeg"' /opt/tdarr/configs/Tdarr_Node_Config.json > tmp.json && mv tmp.json /opt/tdarr/configs/Tdarr_Node_Config.json  # Node Handbrake
    jq -r '.ffmpegPath = "/bin/ffmpeg"' /opt/tdarr/configs/Tdarr_Server_Config.json > tmp.json && mv tmp.json /opt/tdarr/configs/Tdarr_Server_Config.json  # Server Handbrake
fi

# Copy Tdarr custom plugins
if ls "$DIR"/plugins/Tdarr_Plugin_ahuacate_*.js 1> /dev/null 2>&1; then
    cp "$DIR"/plugins/Tdarr_Plugin_ahuacate_*.js "/opt/tdarr/server/Tdarr/Plugins/Local/"  # Copy files matching the pattern
    chown $app_uid:$app_guid /opt/tdarr/server/Tdarr/Plugins/Local/*  # Set ownership & rights
    chmod 666 /opt/tdarr/server/Tdarr/Plugins/Local/*
fi

# Restart services - to build tdarr config/settings files
pct_start_systemctl tdarr-server.service
pct_start_systemctl tdarr-node.service
#-----------------------------------------------------------------------------------