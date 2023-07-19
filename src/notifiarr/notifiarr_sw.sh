#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     notifiarr_sw.sh
# Description:  Setup for Notifiarr CT
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"        # App name
app_uid="$APP_USERNAME"     # App UID
app_guid="$APP_GRPNAME"     # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Install notifiarr
curl -s https://golift.io/repo.sh | bash -s - notifiarr

#-----------------------------------------------------------------------------------