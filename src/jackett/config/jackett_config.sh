#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     jackett_config.sh
# Description:  Source script for configuring SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $DIR/basic_bash_utility.sh

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"       # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Configure App
# Stop Jackett service
pct_stop_systemctl "jackett.service"

# Edit Jacket json config settings
edit_json_value /home/media/.config/Jackett/ServerConfig.json APIKey "ahuacate"
edit_json_value /home/media/.config/Jackett/ServerConfig.json BlackholeDir "/mnt/public/autoadd/torrent/unsorted"
chown "$app_uid":"$app_guid" /home/media/.config/Jackett/ServerConfig.json

# Downloading and Installing preconfigured Indexers
svn checkout https://github.com/ahuacate/pve-medialab/src/jackett/config/Indexers /home/media/.config/Jackett/Indexers
chown "$app_uid":"$app_guid" {/home/media/.config/Jackett/Indexers/*.json,/home/media/.config/Jackett/Indexers/*.bak}

# Start Jackett service
pct_start_systemctl "jackett.service"
#-----------------------------------------------------------------------------------