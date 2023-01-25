#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_script.sh
# Description:  Kodirsync script for Linux & Kodi (CoreELEC/LibreELEC) hosts
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

#---- Log files
mkdir -p $DIR/logs
now=$(date +"%F")
logfile="$DIR/logs/kodirsync-${now}.log"

#---- Check destination storage status (type - '1' for disk, '2' for dir)
if [ "$storage_type" = 1 ]
then
  # Check disk storage mnt status
  storage_type_status=$(mountpoint -q "$dst_dir" && echo "0" || echo "1")
elif [ "$storage_type" = 2 ]
then
  # Set destination dir status
  storage_type_status=$([ -d "$dst_dir" ] && echo "0" || echo "1")
fi
if [ "$storage_type_status" = 1 ]
then
# Log Job fail & exit
  echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile
  echo -e "#---- WARNING - DESTINATION STORAGE FAIL\nFail Time : $(date)\n" >> $logfile
  echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
  exit 1
fi

#---- Static Variables -------------------------------------------------------------

#---- Mktemp file
tempfile=$(mktemp)

#---- Kodirsync temp work dir
work_dir=$(mktemp -d -t kodirsync-XXXXX -p /tmp)

#---- Rsync re-try on fail vars
# Sleep period between attempts
rsync_sleep_time=120
# Total number of Rsync re-connection attempts
rsync_cnt_timeout=10

#---- Regex string check & fixes
escape_string_regex='[][()\.^$?+/'\'' ]/\\&'
# escape_string_regex='[][()\.^$?+ ]/\\&'
control_list_filter_regex='^(?!^video\||(.*)\|$|^video\/(.*)\|\*$|^(.*)\|\s+$)[A-Za-z]+(\/)?(documentary|movies|musicvideos|pron|series)?\|((b|B|w|W)\|[A-Za-z0-9 \._]+(\([0-9]{4}\)|\*)?$)?((w|W)\|[*]$)?$'

#---- Other Variables --------------------------------------------------------------

# Destination storage maximum capacity limit (for both disk and folder storage in bytes)
# dst_max_cap=$(df -Pk "$dst_dir" \
# | awk -v storage_prov_factor="${storage_prov_factor}" '(NR>1) {OFMT="%0.f"; sum = ($2 * storage_prov_factor/100) * 1024; print sum }')
dst_max_cap=$(df -Pk "$dst_dir" \
| awk -v storage_prov_factor="$storage_prov_factor" '(NR==2) {OFMT="%0.f"; sum = (($3 + $4) * (storage_prov_factor/100)) * 1024; print sum }')

# Set storage capacity (bytes)
if [ "$dst_max_limit" = 0 ]
then
  # Set storage capacity to disk maximum
  storage_cap=$dst_max_cap
elif [ ! "$dst_max_limit" = 0 ]
then
  # Check dst_max_cap does not exceed limits
  if (( $(($dst_max_limit * 1073741824)) > $dst_max_cap ))
  then
    storage_cap=$dst_max_cap
  else
    storage_cap=$(($dst_max_limit * 1073741824))
  fi
fi


# Internet access check (Checking multiple urls incase one is blocked)
url_check_LIST=( "google.com|443" \
"github.com|443" )
while IFS='|' read -r url port
do
  # Check url
  nc -zw1 $url $port 2> /dev/null
  if [[ $? == '1' ]]
  then
    # Set access status (1 is UP, other is down)
    internet_access_status=0
    continue
  else
    # Set access status (1 is UP, other is down)
    internet_access_status=1
    break
  fi
done< <( printf '%s\n' "${url_check_LIST[@]}" )


#---- Other Files ------------------------------------------------------------------

# Block key file list (add any file keyword to exclude from rsync downloads)
# Use escape \ with special characters (\#)
block_keyfile_LIST=( @eaDir
installer.run
Thumbs.db
.DS_Store
\#recycle
metadata
.stfolder
.stignore
.partial~
.foo_protect
SYNOINDEX_MEDIA_INFO )
# Block key dir/folder list (add any dir keyword to exclude from rsync downloads)
# Use escape \ with special characters (\#)
block_keydir_LIST=( cache
\#recycle
@eaDir
lost+found
ssh )

# Other safe Linux OS native dir/folders
# (add any dir to exclude from dst removal)
# Use escape \ with special characters (\#)
os_safe_dstdir_LIST=( "lost+found" 
"images" 
"\#recycle" )

# Video file format (.ext) types
video_filter_regex=$(cat $DIR/video_format_filter.txt \
| sed '/^#/d;/^$/d' \
| sed '/^#/d;/^$/d' \
| sed "s/${escape_string_regex}/g" \
| awk '{print}' ORS=' ' \
| sed 's/ *$//' \
| sed 's/ /\|/g')
video_sub_filter_regex=$(cat $DIR/video_sub_format_filter.txt \
| sed '/^#/d;/^$/d' \
| sed '/^#/d;/^$/d' \
| sed "s/${escape_string_regex}/g" \
| awk '{print}' ORS=' ' \
| sed 's/ *$//' \
| sed 's/ /\|/g')
# Image file format (.ext) types
image_filter_regex=$(cat $DIR/image_format_filter.txt \
| sed '/^#/d;/^$/d' \
| sed "s/${escape_string_regex}/g" \
| awk '{print}' ORS=' ' \
| sed 's/ *$//' \
| sed 's/ /\|/g')
# Audio file format (.ext) types
audio_filter_regex=$(cat $DIR/audio_format_filter.txt \
| sed '/^#/d;/^$/d' \
| sed "s/${escape_string_regex}/g" \
| awk '{print}' ORS=' ' \
| sed 's/ *$//' \
| sed 's/ /\|/g')
# Audiobook file format (.ext) types
audiobook_filter_regex=$(cat $DIR/audiobook_format_filter.txt \
| sed '/^#/d;/^$/d' \
| sed "s/${escape_string_regex}/g" \
| awk '{print}' ORS=' ' \
| sed 's/ *$//' \
| sed 's/ /\|/g')
# Audiobook file format (.ext) types
other_filter_regex=$(cat $DIR/other_format_filter.txt \
| sed '/^#/d;/^$/d' \
| sed "s/${escape_string_regex}/g" \
| awk '{print}' ORS=' ' \
| sed 's/ *$//' \
| sed 's/ /\|/g')
# ISO language codes label
iso_lang_codes_sed_regex=$(cat $DIR/iso_language_codes.txt \
| sed '/^#/d;/^$/d' \
| sed "s/${escape_string_regex}/g" \
| awk '{print}' ORS=' ' \
| sed 's/\s$//' \
| sed 's/ /\|/g')
iso_lang_codes_sed_regex=$(cat $DIR/iso_language_codes.txt \
| sed '/^#/d;/^$/d' \
| sed "s/${escape_string_regex}/g" \
| awk '{print}' ORS=' ' \
| sed 's/\s$//' \
| sed 's/ /\\|/g')

#---- Functions --------------------------------------------------------------------

# Create B/W control list
function rsync_getcontrollist() {
  # creates array of blacklist and whitelist entries
  # output control list file name: "${rsync_control_LIST[@]}"

  # Set source
  source='~/'
  # Get rsync control lists from source
  i=0 check_code=1
  while [ "$check_code" != 0 ] && [ "$i" -le "$rsync_retrycount" ]
  do
	i=$(($i+1))
	# Run rsync cmd
  rsync -avI \
  --no-relative \
  --include='rsync_control_list.txt' --include='rsync_control_list_*.txt' \
  --include="/*/" \
  --exclude '*/#*' --exclude '*' \
  -e "$ssh_cmd" \
	$rsync_username@$rsync_address:$source \
	$work_dir
	# Process logs
	check_code=$?
	if [ "$check_code" != 0 ] && [ "$i" = "$rsync_retrycount" ]
  then
	  echo -e "#---- WARNING - RSYNC CONTROL FILES\nError Code ("$check_code") : $(date)\nFunction : sync_getcontrollist\nRetry count : "$rsync_retrycount"x failed attempts\n" >> $logfile
	  exit 1
	elif [ $check_code != 0 ] && [ "$i" -lt "$rsync_retrycount" ]
  then
	  sleep $rsync_retrysleep
	elif [ "$check_code" = 0 ]
  then
	  echo -e "#---- SUCCESS - RSYNC CONTROL FILES\nTime : $(date)\nFunction : sync_getcontrollist\n" >> $logfile
	fi
  done
  # Create lists/arrays
  black_exclude_LIST=() # rsync cmd '--exclude='
  white_include_LIST=() # rsync cmd '--include='
  black_dir_LIST=() # basic dir name
  black_name_LIST=() # basic name name
  white_dir_LIST=() # basic dir name
  basic_bw_rsync_control_LIST=() # destination black/white dir control list
  while IFS='|' read -r path type dir
  do
    if [[ "$type" =~ ^(b|B)$ ]]
    then
      # Create destination dir delete list
      basic_bw_rsync_control_LIST+=( "$path|$type|$dir" )
      # Create black exclude list
      [[ $(printf '%s\n' "${black_exclude_LIST[@]}" | egrep "^--exclude=$path\*/$dir/\*$") ]] && continue
        black_exclude_LIST+=( "--exclude=$path*/$dir/*" )
        black_dir_LIST+=( "$path*/$dir" )
    elif [[ "$type" =~ ^(w|W)$ ]]
    then
      # Create destination dir delete list
      basic_bw_rsync_control_LIST+=( "$path|$type|$dir" )
      # Create white include list
      [[ $(printf '%s\n' "${white_include_LIST[@]}" | egrep "^--exclude=$path\*/$dir/\*$") ]] && continue
        white_include_LIST+=( "--include=$path*/$dir/*" )
        white_dir_LIST+=( "$path*/$dir" )
      # white_regex_LIST+=( "$(echo "${dir}" | sed "s/${escape_string_regex}/g")" )
    fi
  done < <( find $work_dir -type f -name "rsync_control_list*.txt" -exec cat {} + \
  | iconv -f iso-8859-1 -t utf-8 \
  | sed '/^[# ]/d' \
  | sed 's/ *$//' \
  | sed '/^$/d' \
  | grep -vi 'sample' \
  | grep -P --color=never "${control_list_filter_regex}" \
  | uniq -u )
  # Block key dir/folder list
  while read -r dir
  do
    # Create black include list
    [[ $(printf '%s\n' "${black_exclude_LIST[@]}" | egrep "^--exclude=\*/$dir/\*$") ]] && continue
    black_exclude_LIST+=( "--exclude=*/$dir/*" )
    black_exclude_LIST+=( "--exclude=$dir/*" )
    black_dir_LIST+=( "$dir" )
    # black_regex_LIST+=( "$(echo "*/${dir}/*" | sed "s/${escape_string_regex}/g")" )
    # black_regex_LIST+=( "$(echo "${dir}/*" | sed "s/${escape_string_regex}/g")" )
  done < <( printf '%s\n' "${block_keydir_LIST[@]}" )
  # Block key file name list
  while read -r name
  do
    # Create black exclude list
    [[ $(printf '%s\n' "${black_exclude_LIST[@]}" | egrep "^--exclude=\*/$name$") ]] && continue
    black_exclude_LIST+=( "--exclude=*/$name" )
    black_name_LIST+=( "$name" )
    # black_regex_LIST+=( "$(echo "*/${name}" | sed "s/${escape_string_regex}/g")" )
  done < <( printf '%s\n' "${block_keyfile_LIST[@]}" )
  # Regex lists
  black_dir_filter_regex=$(printf '%s\n' "${black_dir_LIST[@]}" | sed '/^#/d;/^$/d' | sed "s/${escape_string_regex}/g" | sed 's#*\|\\\*#\(\^\/\*\)\?#g' | awk '{print}' ORS='|' | sed 's/|$/\n/')
  white_dir_filter_regex=$(printf '%s\n' "${white_dir_LIST[@]}" | sed '/^#/d;/^$/d' | sed "s/${escape_string_regex}/g" | sed 's/^/^/;s/$/\//' | sed 's#*\|\\\*#\(\^\/\*\)\?#g' | awk '{print}' ORS='|' | sed 's/|$/\n/')
  black_name_filter_regex=$(printf '%s\n' "${black_name_LIST[@]}" | sed '/^#/d;/^$/d' | sed "s/${escape_string_regex}/g" | awk '{print}' ORS='|' | sed 's/|$/\n/')
}

# Create rsync file list
function rsync_filelist() {
  # Set source
  source='~/'
  # Create rsync list
  i=0 check_code=1
  while [ "$check_code" != 0 ] && [ "$i" -le "$rsync_retrycount" ]
  do
	i=$(($i+1))
	rsync -r -t \
	--no-links \
	--list-only \
	--min-size='1' \
	"${black_exclude_LIST[@]}" \
  --exclude="rsync_control_list_*.txt" \
	--prune-empty-dirs \
	-e "$ssh_cmd" \
	$rsync_username@$rsync_address:$source > $tempfile
	check_code=$?
	if [ "$check_code" != 0 ] && [ "$i" = "$rsync_retrycount" ]
  then
	  echo -e "#---- WARNING - RSYNC FILE LIST\nError Code ($check_code) : $(date)\nFunction : rsync_filelist\nRetry count : "$rsync_retrycount"x failed attempts\n" >> $logfile
	  exit 1
	elif [ "$check_code" != 0 ] && [ "$i" -lt "$rsync_retrycount" ]
  then
	  sleep $rsync_retrysleep
	elif [ "$check_code" = 0 ]
  then
	  cat $tempfile \
	  | cut -d' ' -f2- \
	  | sed 's/^ *//' \
    | sed '/^$/d' \
	  | awk '{OFS=FS} {gsub(/\//,"-",$2)gsub(/\,/,"",$1); print}' \
	  | sed 's/ /|/1;s/ /|/2' \
	  | awk -F '|' '{ OFS = FS;command="date -d " "\"" $2 "\""  " +%s";command | getline $2;close(command);print $3, $2, $1 }' \
    | sed '/^\./d;/^$/d;/^\#/d;/^ /d' > $work_dir/rsync_filelist.txt
	  echo -e "#---- SUCCESS - RSYNC FILE LIST\nTime : $(date)\nFunction : rsync_filelist\n" >> $logfile
	fi
  done
}

# Create server share list
function rsync_sharelist() {
  # creates array of available kodirsync server shared folders
  # output share list file name: "${rsync_share_LIST[@]}"

  # Set source
  source='~/'
  # Create rsync dir list
  i=0 check_code=1
  while [ "$check_code" != 0 ] && [ "$i" -le "$rsync_retrycount" ]
  do
	rsync_share_LIST=()
	rsync_share_LIST+=( $(rsync -r -t \
	--no-links \
	--list-only \
	--min-size='1' \
	--include="/video/*/" --include="/video/*stream/*/" \
	--exclude="/*/*/"  --exclude '*/*' --exclude '*.*' --exclude '*/*.*' --exclude '#*' \
	-e "$ssh_cmd" \
	$rsync_username@$rsync_address:$source \
  | sed '/^$/d' \
	| awk '{ $1=$2=$3=$4=""; print substr($0,5); }' | sed '/^.$/d' | sed '/^video$/d') )
	check_code=$?
	if [ "$check_code" != 0 ] && [ "$i" = "$rsync_retrycount" ]
  then
	  echo -e "#---- WARNING - RSYNC SHARE LIST\nError Code ("$check_code") : $(date)\nFunction : rsync_sharelist\nRetry count : "$rsync_retrycount"x failed attempts\n" >> $logfile
	  exit 1
	elif [ "$check_code" != 0 ] && [ "$i" -lt "$rsync_retrycount" ]
  then
	  sleep $rsync_retrysleep
	elif [ "$check_code" = 0 ]
  then
	  echo -e "#---- SUCCESS - RSYNC SHARE LIST\nTime : $(date)\nFunction : rsync_sharelist\n" >> $logfile
	fi
  done
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- Start Job
echo -e "#---- JOB START --------------------------------------------------------------------\nStart Time : $(date)\n" >> $logfile

#---- Check & Set LAN connection status & type
# rsync_connection_type: '1' for SSLH, '2' for PF, '3' for LAN connection
# Check LAN domain address availability
ssh -q -i ~/.ssh/"$rsync_username"_kodirsync_id_ed25519 \
-o "BatchMode yes" \
-o "StrictHostKeyChecking no" \
-o "ConnectTimeout 5" \
-p $ssh_port \
$rsync_username@$localdomain_address_url echo OK
lan_server_domain_status=$?
# Check LAN IP address availability
ssh -q -i ~/.ssh/"$rsync_username"_kodirsync_id_ed25519 \
-o "BatchMode yes" \
-o "StrictHostKeyChecking no" \
-o "ConnectTimeout 5" \
-p $ssh_port \
$rsync_username@$local_ip_address echo OK
lan_server_ip_status=$?


# Set LAN server connection status & url
if [ "$lan_server_domain_status" = 0 ]
then
  # Set LAN active
  lan_address="$localdomain_address_url"
  lan_server_status=1
  # Set 'rsync_connection_type' temporary override
  rsync_connection_type=3
  # Create log entry
  echo -e "#---- SUCCESS - CHECKING LAN AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 3 [LAN connection $lan_address:$ssh_port]\n" >> $logfile
elif [ ! "$lan_server_domain_status" = 0 ] && [ "$lan_server_ip_status" = 0 ]
then
  # Set LAN active
  lan_address="$local_ip_address"
  lan_server_status=1
  # Set 'rsync_connection_type' temporary override
  rsync_connection_type=3
  # Create log entry
  echo -e "#---- SUCCESS - LAN NETWORK AND RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC redirected to use Type 3 [LAN connection $lan_address:$ssh_port]\n" >> $logfile
elif [ ! "$lan_server_domain_status" = 0 ] && [ ! "$lan_server_ip_status" = 0 ]
then
  # Set LAN inactive
  lan_server_status=0
  # If LAN inactive & no internet access then exit
  if [ "$internet_access_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- WARNING - LAN & WAN RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [WAN and LAN]\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    exit 1
  fi
fi

#---- Check & Set remote WAN connection status & type
# rsync_connection_type: '1' for SSLH, '2' for PF, '3' for LAN connection
# Only sets if 'lan_server_status=0' (disabled)

if [ "$rsync_connection_type" = 1 ] && [ "$lan_server_status" = 0 ]
then
  #---- SSLH WAN access
  # Check SSLH server status
  ssh -q -i ~/.ssh/"$rsync_username"_kodirsync_id_ed25519 \
  -o "BatchMode yes" \
  -o "StrictHostKeyChecking no" \
  -o "ConnectTimeout 5" \
  -o ProxyCommand="openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername $sslh_address_url -cert ~/.ssh/sslh.crt -key ~/.ssh/sslh-kodirsync.key" \
  $rsync_username@$localdomain_address_url echo OK
  sslh_server_status=$?

  if [ "$sslh_server_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- SUCCESS - RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC set to use Type 1 [SSLH connection $sslh_address_url:$sslh_port]\n" >> $logfile
  elif [ ! "$sslh_server_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- WARNING - RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [SSLH and LAN]\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    # Exit on fail
    exit 1
  fi
elif [ "$rsync_connection_type" = 2 ] && [ "$lan_server_status" = 0 ]
then
  #---- PF WAN access
  # Check PF SSH server status
  ssh -q -i ~/.ssh/"$rsync_username"_kodirsync_id_ed25519 \
  -o "BatchMode yes" \
  -o "StrictHostKeyChecking no" \
  -o "ConnectTimeout 5" \
  -p  $pf_port \
  $rsync_username@$localdomain_address_url echo OK
  pf_server_status=$?

  if [ "$pf_server_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- SUCCESS - RSYNC CONNECTION STATUS\nTime : $(date)\nFunction : RSYNC set to use Type 2 [PF connection $pf_address_url:$pf_port]\n" >> $logfile
  elif [ ! "$pf_server_status" = 0 ]
  then
    # Create log entry
    echo -e "#---- WARNING - RSYNC CONNECTION FAIL\nFail date : $(date)\nFunction : RSYNC connection fail. [PF and LAN]\n" >> $logfile
    echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
    # Exit on fail
    exit 1
  fi
fi

#---- Set SSH connection cmd script
# rsync_connection_type: '1' for SSLH, '2' for PF, '3' for LAN connection

if [ "$rsync_connection_type" = 1 ]
then
  # Set SSLH WAN ssh cmd script
  ssh_cmd="ssh -i ~/.ssh/${rsync_username}_kodirsync_id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval ProxyCommand="openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert ~/.ssh/sslh.crt -key ~/.ssh/sslh-kodirsync.key""
  rsync_address="$sslh_address_url"
elif [ "$rsync_connection_type" = 2 ]
then
  # Set PF WAN ssh cmd script
  ssh_cmd="ssh -i ~/.ssh/${rsync_username}_kodirsync_id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -p $pf_port"
  rsync_address="$pf_address_url"
elif [ "$rsync_connection_type" = 3 ]
then
  # Set LAN ssh cmd script
  ssh_cmd="ssh -i ~/.ssh/${rsync_username}_kodirsync_id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -p $ssh_port"
  rsync_address="$lan_address"
fi

#---- Rsync Kodirsync server and create rsync list arrays

# Get & create rsync share list
rsync_sharelist
# Get & create rsync control lists
rsync_getcontrollist
# Get & create rsync file lists
rsync_filelist

#---- Create destination dir
while read -r line
do
	mkdir -p "$dst_dir/$line"
done < <( printf '%s\n' "${rsync_share_LIST[@]}" )

#---- Reserved whitelisted storage space (size)

# Reserved 'other' non-video whitelist storage space (size)
if [ "${#white_dir_LIST[@]}" -gt '0' ] && [[ ! $(printf '%s\n' "${rsync_share_LIST[@]}" | egrep '^video\/') ]]
then
  other_white_storage_cap=$(cat $work_dir/rsync_filelist.txt \
  | sed -e '/^video\(\/\)\?/d' \
  | egrep -i --color=never "${white_dir_filter_regex}" \
  | awk -F'|' \
    '{if ( $1 ~ /\.('"${video_filter_regex}|${video_sub_filter_regex}|${image_filter_regex}|${audio_filter_regex}|${audiobook_filter_regex}|${other_filter_regex}"')$/ ) print $0 }' \
  | awk -F'|' \
    -v hdr_enable="$hdr_enable" \
    '{ if ( hdr_enable == 1 && $1 ~ /^(video\/|homevideo\/)/ && $1 ~ /(HDR|hdr)/ || $1 !~ /(HDR|hdr)/) print $0
    else if ( hdr_enable == 0 && $1 ~ /^(video\/|homevideo\/)/ && $1 !~ /(HDR|hdr)/ ) print $0
    else print $0
    }' \
  | sort -t '|' -k2 -n -r \
  | awk -F'|' \
    -v max_video_size="$(($max_video_size * 1073741824))" \
    -v max_other_size="$(($max_other_size * 1073741824))" \
    '{ if ( $3 < max_video_size && $1 ~ /^(video\/|homevideo\/)/ ) print $0
    else if ( $3 < max_other_size && $1 !~ /^(video\/|homevideo\/)/ ) print $0
    }' \
  | awk -F'|' -v storage_cap_var="$storage_cap" '{ i+=$3; if ( i < storage_cap_var ) print $0}' \
  | awk -F'|' '{sum += $3} END { if ( sum > 0 ) printf "%.0f\n", sum
    else if ( sum == 0 ) print "0"}')
else
  other_white_storage_cap=0
fi

# Reserved video whitelist storage space (size)
if [ "${#white_dir_LIST[@]}" -gt '0' ] && [[ $(printf '%s\n' "${rsync_share_LIST[@]}" | egrep '^video\/') ]]
then
  video_white_storage_cap=$(cat $work_dir/rsync_filelist.txt \
  | sed -n '/^video\//p' \
  | egrep -i --color=never "${white_dir_filter_regex}" \
  | awk -F'|' \
    '{if ( $1 ~ /\.('"${video_filter_regex}|${video_sub_filter_regex}|${image_filter_regex}|${audio_filter_regex}|${audiobook_filter_regex}|${other_filter_regex}"')$/ ) print $0 }' \
  | awk -F'|' \
    -v hdr_enable="$hdr_enable" \
    '{ if ( hdr_enable == 1 && $1 ~ /^(video\/|homevideo\/)/ && $1 ~ /(HDR|hdr)/ || $1 !~ /(HDR|hdr)/ ) print $0
    else if ( hdr_enable == 0 && $1 ~ /^(video\/|homevideo\/)/ && $1 !~ /(HDR|hdr)/ ) print $0
    else print $0
    }' \
  | sort -t '|' -k2 -n -r \
  | awk -F'|' \
    -v max_video_size="$(($max_video_size * 1073741824))" \
    -v max_other_size="$(($max_other_size * 1073741824))" \
    '{ if ( $3 < max_video_size && $1 ~ /^(video\/|homevideo\/)/ ) print $0
    else if ( $3 < max_other_size && $1 !~ /^(video\/|homevideo\/)/ ) print $0
    }' \
  | awk -F'|' -v storage_cap_var="$(( $storage_cap - $other_white_storage_cap ))" '{ i+=$3; if ( i < storage_cap_var ) print $0}' \
  | awk -F'|' '{sum += $3} END { if ( sum > 0 ) printf "%.0f\n", sum
    else if ( sum == 0 ) print "0"}')
else
  video_white_storage_cap=0
fi

#---- Create Rsync input lists
# These are the input rsync file lists.
# 1. 'Other whitelisted input list' are all whitelisted non-video (excluding homevideo)
# files in your audio, homevideo, music or photo categories.
# 2. 'Video whitelisted input list' are all whitelisted video files such as
# documentary, movies, musicvideo, pron, series.
# 3. 'Video all remaining input list' are non-whitelisted but all the remaining
# video files in ascending age order up to total disk capacity.

# Create input whitelist file
rm $work_dir/input_list.txt 2> /dev/null
touch $work_dir/input_list.txt

# Create other whitelisted input list (non-video dir)
if [ "${#white_dir_LIST[@]}" -gt '0' ] && [[ ! $(printf '%s\n' "${rsync_share_LIST[@]}" | egrep '^video\/') ]]
then
  cat $work_dir/rsync_filelist.txt \
  | sed -e '/^video\(\/\)\?/d' \
  | egrep -i --color=never "${white_dir_filter_regex}" \
  | awk -F'|' \
  '{if ( $1 ~ /\.('"${video_filter_regex}|${video_sub_filter_regex}|${image_filter_regex}|${audio_filter_regex}|${audiobook_filter_regex}|${other_filter_regex}"')$/ ) print $0 }' \
  | awk -F'|' \
    -v hdr_enable="$hdr_enable" \
    '{ if ( hdr_enable == 1 && $1 ~ /^(video\/|homevideo\/)/ && $1 ~ /(HDR|hdr)/ || $1 !~ /(HDR|hdr)/) print $0
    else if ( hdr_enable == 0 && $1 ~ /^(video\/|homevideo\/)/ && $1 !~ /HDR|hdr/ ) print $0
    else print $0
    }' \
  | sort -t '|' -k2 -n -r \
  | awk -F'|' \
    -v max_video_size="$(($max_video_size * 1073741824))" \
    -v max_other_size="$(($max_other_size * 1073741824))" \
    '{ if ( $3 < max_video_size && $1 ~ /^(video\/|homevideo\/)/ ) print $0
    else if ( $3 < max_other_size && $1 !~ /^(video\/|homevideo\/)/ ) print $0
    }' \
  | awk -F'|' -v storage_cap_var="$storage_cap" '{ i+=$3; if ( i < storage_cap_var ) print $0}' \
  >> $work_dir/input_list.txt
fi

# Create video whitelisted input list
if [ "${#white_dir_LIST[@]}" -gt '0' ] && [[ $(printf '%s\n' "${rsync_share_LIST[@]}" | egrep '^video\/') ]]
then
  # Create video file only array
  video_only_white_LIST=()
  while IFS= read -r line
  do
    video_only_white_LIST+=( "$(echo $line)" )
  done < <( cat $work_dir/rsync_filelist.txt \
  | sed -n '/^video\//p' \
  | egrep -i --color=never "${white_dir_filter_regex}" \
  | awk -F'|' \
  '{if ( $1 ~ /\.('"${video_filter_regex}"')$/ ) print $0 }' \
  | awk -F'|' \
    -v hdr_enable="$hdr_enable" \
    '{ if ( hdr_enable == 1 && $1 ~ /^(video\/|homevideo\/)/ && $1 ~ /(HDR|hdr)/ || $1 !~ /(HDR|hdr)/) print $0
    else if ( hdr_enable == 0 && $1 ~ /^(video\/|homevideo\/)/ && $1 !~ /HDR|hdr/ ) print $0
    else print $0
    }' \
  | sort -t '|' -k2 -n -r \
  | awk -F'|' \
    -v max_video_size="$(($max_video_size * 1073741824))" \
    -v max_other_size="$(($max_other_size * 1073741824))" \
    '{ if ( $3 < max_video_size && $1 ~ /^(video\/|homevideo\/)/ ) print $0
    else if ( $3 < max_other_size && $1 !~ /^(video\/|homevideo\/)/ ) print $0
    }' \
  | awk -F'|' -v storage_cap_var="$(( $storage_cap - $other_white_storage_cap ))" '{ i+=$3; if ( i < storage_cap_var ) print $1}' \
  | sed 's/\.[^.]*$//' )

  # Match allowed file types to video file name
  while IFS='|' read -r path date size
  do
    # Create path match regex
    path_regex=$(echo $path \
      | sed -e "/\.\(${iso_lang_codes_sed_regex}\)\.\($(echo ${video_sub_filter_regex} | sed 's/|/\\|/g')\)$/s/\.\(${iso_lang_codes_sed_regex}\)//" \
      | sed -e 's/\.[^./]*$//' \
      | sed "s/${escape_string_regex}/g" \
      | sed 's#*\|\\\*#\(\^\/\*\)\?#g' \
      | sed 's/^/^/;s/$/\\.\*/') 
    # Perform file match
    for i in "${video_only_white_LIST[@]}"
    do
      if [[ "$i" =~ "$path_regex" ]]; then
        # Add file match to input list
        echo "$path|$date|$size" >> $work_dir/input_list.txt
      fi
    done
  done < <( cat $work_dir/rsync_filelist.txt \
    | sed -n '/^video\//p' \
    | egrep -i --color=never "${white_dir_filter_regex}" \
    | awk -F'|' \
    '{if ( $1 ~ /\.('"${video_filter_regex}|${video_sub_filter_regex}|${image_filter_regex}|${other_filter_regex}"')$/ ) print $0 }' )
else
  video_only_white_LIST=()
fi


# Process remaining video list dir to disk full capacity (by age)
if [[ $(printf '%s\n' "${rsync_share_LIST[@]}" | egrep '^video\/') ]]
then
  # Create video all remaining input list
  video_only_LIST=()
  while IFS= read -r line
  do
    video_only_LIST+=( "$line" )
  done < <( cat $work_dir/rsync_filelist.txt \
  | sed -n '/^video\//p' \
  | egrep -i -v --color=never "${white_dir_filter_regex}" \
  | awk -F'|' \
  '{if ( $1 ~ /\.('"${video_filter_regex}"')$/ ) print $0 }' \
  | awk -F'|' \
    -v hdr_enable="$hdr_enable" \
    '{ if ( hdr_enable == 1 && $1 ~ /^(video\/|homevideo\/)/ && $1 ~ /(HDR|hdr)/ || $1 !~ /(HDR|hdr)/) print $0
    else if ( hdr_enable == 0 && $1 ~ /^(video\/|homevideo\/)/ && $1 !~ /HDR|hdr/ ) print $0
    else print $0
    }' \
  | sort -t '|' -k2 -n -r \
  | awk -F'|' \
    -v max_video_size="$(($max_video_size * 1073741824))" \
    -v max_other_size="$(($max_other_size * 1073741824))" \
    '{ if ( $3 < max_video_size && $1 ~ /^(video\/|homevideo\/)/ ) print $0
    else if ( $3 < max_other_size && $1 !~ /^(video\/|homevideo\/)/ ) print $0
    }' \
  | awk -F'|' -v storage_cap_var="$(( $storage_cap - $video_white_storage_cap - $other_white_storage_cap ))" '{ i+=$3; if ( i < storage_cap_var ) print $1}' \
  | sed 's/\.[^.]*$//' )

  # Match allowed file types to video file name
  while IFS='|' read -r path date size
  do
    # Create path match regex
    path_regex=$(echo $path \
      | sed -e "/\.\(${iso_lang_codes_sed_regex}\)\.\($(echo ${video_sub_filter_regex} | sed 's/|/\\|/g')\)$/s/\.\(${iso_lang_codes_sed_regex}\)//" \
      | sed -e 's/\.[^./]*$//' \
      | sed "s/${escape_string_regex}/g" \
      | sed 's#*\|\\\*#\(\^\/\*\)\?#g' \
      | sed 's/^/^/;s/$/\\.\*/') 
    # Perform file match
    for i in "${video_only_LIST[@]}"
    do
      if [[ "$i" =~ ${path_regex} ]]
      then
        # Add file match to input list
        echo "$path|$date|$size" >> $work_dir/input_list.txt
      fi
    done
  done < <( cat $work_dir/rsync_filelist.txt \
    | sed -n '/^video\//p' \
    | egrep -i -v --color=never "${white_dir_filter_regex}" \
    | awk -F'|' \
    '{if ( $1 ~ /\.('"${video_filter_regex}|${video_sub_filter_regex}|${image_filter_regex}|${other_filter_regex}"')$/ ) print $0 }' )
fi


#---- Remove depreciated, blacklisted & orphaned dirs/files

# Create protect base dir list args
find_not_basedir_regex1=()
find_not_basedir_regex2=()
for i in "${rsync_share_LIST[@]}"
do
	if [[ "$i" =~ ^video\/.* ]] \
  && [[ ! $(printf '%s\n' "${find_not_basedir_regex1[@]}" | egrep ".*\/video\\\$$") ]]; then
		find_not_basedir_regex1+=('!' '-regex' "^$(echo ""$dst_dir"/$(dirname "$i")" | sed "s/${escape_string_regex}/g")$")
	fi
	# find_not_basedir_regex1+=('!' '-regex' "^"$dst_dir"/$i\(/.*\)?")
  find_not_basedir_regex1+=('!' '-regex' "^$(echo ""$dst_dir"/${i}" | sed "s/${escape_string_regex}/g")/?.*")
  find_not_basedir_regex2+=('!' '-regex' "^$(echo ""$dst_dir"/${i}" | sed "s/${escape_string_regex}/g")")
done
for i in "${os_safe_dstdir_LIST[@]}"
do
  find_not_basedir_regex1+=('!' '-regex' "^$(echo ""$dst_dir"/${i}" | sed "s/${escape_string_regex}/g")/?.*")
  find_not_basedir_regex2+=('!' '-regex' "^$(echo ""$dst_dir"/${i}" | sed "s/${escape_string_regex}/g")")
done

# Remove depreciated destination main share dirs
find "$dst_dir" -mindepth 1 -maxdepth 2 -type d "${find_not_basedir_regex1[@]}" 2> >(grep -v 'Permission denied' >&2) -exec du {} + | xargs rm -Rf 2> /dev/null

# Remove blacklisted destination dirs
while IFS='|' read -r path type dir
do
  if [[ "$type" =~ ^(b|B)$ ]]; then
    find "$dst_dir/$path" -type d -name "$dir" "${find_not_basedir_regex2[@]}" 2> >(grep -v 'Permission denied' >&2) -exec du {} + | xargs rm -Rf 2> /dev/null
  fi
done < <( printf '%s\n' "${basic_bw_rsync_control_LIST[@]}" )

# Create list of current existing dst files
touch $work_dir/dst_list.txt
for i in "${rsync_share_LIST[@]}"
do
  if [ -d "$dst_dir"/${i} ]; then
    find "$dst_dir"/${i} -type f "${find_not_basedir_regex2[@]}" 2> >(grep -v 'Permission denied' >&2) -exec ls -l {} + \
    | sed -E 's/ +/ /g' \
    | cut -d' ' -f5,9- \
    | sed -r 's/\s+/\|/' \
    | awk -F'|' '{OFS = FS} { print $2, $1 }' \
    | sed -e "s#^"$dst_dir"/#${i}\|#g" \
    | awk -F'|' '{OFS = FS} {if ( $2 ~ /\.('"${video_filter_regex}|${video_sub_filter_regex}|${image_filter_regex}|${audio_filter_regex}|${audiobook_filter_regex}|${other_filter_regex}"')$/ ) print $0 }' >> $work_dir/dst_list.txt
  fi
done

# Remove depreciated dst files/dir
# Input line checks file name and file size:
#   awk -F'|' 'NR==FNR{a[$1,$3];next} !(($2,$3) in a)' ${work_dir}/input_list.txt ${work_dir}/dst_list.txt 
# Input line checks file name only:
#   awk -F'|' 'NR==FNR{a[$1];next} !($2 in a)' ${work_dir}/input_list.txt ${work_dir}/dst_list.txt 
while IFS='|' read -r share dstfile size
do
  if [[ "$share" =~ ^video\/movies$ ]] && [[ "$dstfile" =~ \.(${video_filter_regex})$ ]]; then
    i="$(dirname "$dstfile" | sed "s/${escape_string_regex}/g")"
    if [[ "video/movies" =~ ^${i}$ ]]
    then
      # Remove movie file only
      rm -f "$dst_dir/$dstfile" 2> /dev/null
    else
      # Remove movie dir
      rm -Rf "$dst_dir/$(dirname "$dstfile")" 2> /dev/null 
    fi
  else
    # Remove file only
    rm -f "$dst_dir/$dstfile" 2> /dev/null
  fi
done < <( awk -F'|' 'NR==FNR{a[$1];next} !($2 in a)' $work_dir/input_list.txt $work_dir/dst_list.txt )

# Remove dst empty and orphaned dirs
for i in "${rsync_share_LIST[@]}"
do
  if [[ "$i" =~ ^(video\/([a-z])+|homevideo)$ ]]
  then
    # Remove empty or orphaned video dirs
    find "$dst_dir/$i" -mindepth 1 -type d "${find_not_basedir_regex2[@]}" 2> >(grep -v 'Permission denied' >&2) -exec du {} + \
    | awk -v dst_dir_minsize="$dst_video_dir_minsize" '$1 <= dst_dir_minsize' \
    | cut -f 2- | sed 's/^/"/;s/$/"/' \
    | xargs rm -Rf 2> /dev/null
  else
    # Remove empty or orphaned dirs (non-video)
    find "$dst_dir/$i" -mindepth 1 -type d "${find_not_basedir_regex2[@]}" 2> >(grep -v 'Permission denied' >&2) -exec du {} + \
    | awk -v dst_dir_minsize="$dst_other_dir_minsize" '$1 <= dst_dir_minsize' \
    | cut -f 2- | sed 's/^/"/;s/$/"/' \
    | xargs rm -Rf 2> /dev/null
  fi
done

#---- Perform rsync task

# Create rsync input file list to dl
awk -F'|' '{ print $1 }' $work_dir/input_list.txt > $work_dir/input_final_list

# Create log entry
echo -e "#---- ACTION - RSYNC TASK ONLY\nTime : $(date)\nRsync list : input_final_list\n" >> $logfile

# Run Rsync task
while [ 1 ]
do
  # Rsync cmd
  rsync -av -e "$ssh_cmd" \
  --progress \
  --timeout=60 \
  --human-readable \
  --partial \
  --append \
  --delete \
  --inplace \
  --exclude '*.partial~' \
  --log-file=$logfile \
  --files-from=$work_dir/input_final_list \
  --relative $rsync_username@$rsync_address:~/ "$dst_dir"

  # Run re-connect cnt with delay
  c=0
  if [ "$?" = "0" ] ; then
      # Create log entry
    echo -e "#---- SUCCESS - RSYNC COMPLETION\nTime : $(date)\nFunction : Task completed successfully.\n" >> $logfile
      break
  else
      # Create log entry
      echo -e "#---- WARNING - RSYNC FAIL\nFail date : $(date)\nTrying again in $rsync_sleep_time seconds (Attempt: $(($c + 1)) of $rsync_cnt_timeout)\n" >> $logfile
      ((c++)) && ((c==$rsync_cnt_timeout)) && break
      sleep $rsync_sleep_time
  fi
done


#---- Finish Line ------------------------------------------------------------------------------------------------------

# Prune log files older than 14 days
find $DIR/logs -name "*.log" -type f -mtime +14 -delete

# Create log entry
echo -e "\nFinish Time : $(date)\n#---- JOB FINISHED -----------------------------------------------------------------\n" >> $logfile
#-----------------------------------------------------------------------------------------------------------------------