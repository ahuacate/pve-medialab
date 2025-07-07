#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_common_cfg_update.sh
# Description:  Update Kodirsync users configuration file
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Iterate over the array and update the values in the user configuration file

# Set '$control_list_src' location
control_list_src="$app_dir/kodirsync_control_list.txt"

# Set '$node_ssh_private_key_path' location
node_ssh_private_key_path="$app_dir/id_rsa_nodesync.ppk"

# Args for writing to Kodirsync user config files
user_config_arg_LIST=(
  "storage_type"
  "hdr_enable"
  "control_list_src"
  "node_ssh_private_key_path"
)
for name in "${user_config_arg_LIST[@]}"
do
  # Use the eval command to retrieve the value of the variable with the same name as the current option
  value=$(eval "echo \$$name")
  sed -i "s#^${name}\=.*#${name}\=${value}#g" $app_dir/kodirsync_clientapp_user.cfg
done
#-----------------------------------------------------------------------------------