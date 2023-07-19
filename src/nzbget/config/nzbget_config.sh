#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nzbget_config.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"       # App name
app_uid="$APP_USERNAME"        # App UID
app_guid="$APP_GRPNAME"        # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Create 'dl_client_catergory_LIST'
dl_type='usenet'
unset dlclient_category_LIST
unset dirwatch_LIST
while IFS=':' read -r category destdir watchdir aliases ext
do
  [[ "$category" =~ ^\#.*$ ]] && continue
    # Create 'dl_client_catergory_LIST'
    dlclient_category_LIST+=( "$category:$(eval echo "$destdir"):$(eval echo "$watchdir"):$(echo "$aliases" | sed 's/,/, /g'):$ext" )
    # Create dirwatch_LIST
    if ! [ -z "$watchdir" ]
    then
      dirwatch_LIST+=( "$(eval echo "$watchdir")?c=$category" )
    fi
done < /tmp/dlclient_category_list.txt

#---- Body -------------------------------------------------------------------------

# Create Download folders
runuser $app_uid -c 'mkdir -p /mnt/downloads/usenet/{queue,tmp,intermediate,complete,nzb}'
while IFS=':' read -r category destdir watchdir aliases ext
do
  # Create destination dir
  if ! [ -z "$destdir" ]
  then
    runuser $app_uid -c "mkdir -p $destdir"
  fi
  # Create watch dir
  if ! [ -z "$watchdir" ]
  then
    runuser $app_uid -c "mkdir -p $watchdir"
  fi
done <<< $(printf '%s\n' "${dlclient_category_LIST[@]}")

# Set Download folder
if [ -d "/mnt/downloads" ]; then sed -i 's#^MainDir=.*#MainDir=/mnt/downloads/usenet#' /opt/nzbget/nzbget.conf; fi
if [ -d "/mnt/downloads" ]; then sed -i 's#^DestDir=.*#DestDir=\${MainDir}/complete#' /opt/nzbget/nzbget.conf; fi

# Set control port
sed -i '/^ControlPort=.*/c\ControlPort=6789' /opt/nzbget/nzbget.conf

# Restricted user access (connect to NZBGet from other programs)
sed -i '/^RestrictedUsername=.*/c\RestrictedUsername=appconnect' /opt/nzbget/nzbget.conf
sed -i '/^RestrictedPassword=.*/c\RestrictedPassword=ahuacate' /opt/nzbget/nzbget.conf

# Add username and password for RPC Access
sed -i "/AddUsername=/c\AddUsername=appconnect" /opt/nzbget/nzbget.conf
sed -i "/AddPassword=/c\AddPassword=ahuacate" /opt/nzbget/nzbget.conf

# Set User Daemon
sed -i "/^DaemonUsername=.*/c\DaemonUsername=$app_uid" /opt/nzbget/nzbget.conf

# Clean old default category's
sed -i "/\<Category.*\>/s/^/#/" /opt/nzbget/nzbget.conf

# Create category list
cnt=1
while IFS=':' read -r category destdir watchdir aliases ext
do
  [[ "$category" =~ ^\#.*$ ]] && continue
    # Create category
    echo -e "\n# Category${cnt} Details"
    echo -e "Category${cnt}.Name=${category}\nCategory${cnt}.DestDir=${destdir}\nCategory${cnt}.Aliases=${aliases}\nCategory${cnt}.Extensions=${ext}\n"
    # add to cnt
    cnt=$(($cnt+1))
done < <( printf '%s\n' "${dlclient_category_LIST[@]}" )


# Setup Watch Folder
wget https://raw.githubusercontent.com/caronc/nzbget-dirwatch/master/DirWatch.py -P /opt/nzbget/scripts
chown "$app_uid":"$app_guid" /opt/nzbget/scripts/DirWatch.py
chmod +x /opt/nzbget/scripts/DirWatch.py
sed -i "s|^#WatchPaths=.*|WatchPaths=$(printf '%s\n' "${dirwatch_LIST[@]}" | xargs |  sed -e 's/ /, /g')|" /opt/nzbget/scripts/DirWatch.py
#-----------------------------------------------------------------------------------