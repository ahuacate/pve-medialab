#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     recipe.sh
# Description:  This script is executed by parent 'cookbook.sh'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# FlexGet config.yml path
config_path="$DIR/config.yml"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Parse a yml variables to bash
function parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Unset all variables starting with "path_"
for var in $(compgen -v | egrep '^(path_|storage_|prune_)')
do
  unset "$var"
done

# Create bash variables from FlexGet yml variables file
eval $(parse_yaml $DIR/variables_default.yml)

#---- Run FlexGet

# FlexGet run cmd
~/flexget/bin/flexget -c $config_path execute &

# Save the PID of the program
pid=$!

# Wait for the program to finish
wait $pid


#---- Run Prune
source $DIR/prune.sh

#---- Run FileBot
source $DIR/filebot_run.sh
#-----------------------------------------------------------------------------------