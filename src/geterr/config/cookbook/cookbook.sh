#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     cookbook.sh
# Description:  Executes a recipe.
#               This file is executed by a systemd unit.
#               '/etc/systemd/system/flexget.service'
#               To edit FlexGet run frequency edit systemd unit flexget.timer.
#               '/etc/systemd/system/flexget.timer'
#               Nothing to configure here (do not edit).
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Read flexget.ini file
# Reads all the common & general variables/args (not secrets file)
source ~/.flexget/cookbook/cookbook.ini

# Read bash utility
# Sets bash, script functions, checks internet connectivity
source ~/.flexget/cookbook/flexget_bash_utility.sh

# Check for Geterr script updates
# Set the variable in the media user's shell
# Run the script as root and pass the variable as an argument
sudo /bin/bash -c "source /home/media/.flexget/cookbook/recipe_updater.sh "$app_uid" "$app_gid" "$config_home" "$upgrade_recipe" "$recipe_src_dir_path""

# Switch back to media user
#su - media

#---- Set recipe script

# Set recipe source
recipe_src=$(find ~/.flexget/cookbook/ -type d -iname "${recipe_dir}")

# Run recipe
$recipe_src/recipe.sh
#-----------------------------------------------------------------------------------