#!/bin/bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_run.sh
# Description:  Default Kodirsync client run script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )


rsync_username=lloyd
sslh_port=443
sslh_address_url=sslh-burma.espeo.me
localdomain_address_url=kodirsync.local
ssh_connecttimeout='140'
ssh_serveraliveinterval='15'
connect_retrycount='4'
connect_retrysleep='60'

source='\$HOME/'
video_subfolder_dir_filter_regex='video(/|/stream/)?(documentary|movies|musicvideo|pron|series)?'
exclude_os_dir_filter_regex='lost+found|images|\#recycle'
exclude_dir_filter_regex='\..*|cache|\#recycle|@eaDir|\@eaDir|lost+found|ssh|\.ssh|images|kodirsync_app|rsync_tmp'
black_dir_filter_regex='hello|bye'

app_dir="$DIR"
ssh_dir="$HOME/.ssh"

ssh_cmd="ssh -i $ssh_dir/${rsync_username}_kodirsync_id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=$ssh_connecttimeout -o ServerAliveInterval=$ssh_serveraliveinterval -o ProxyCommand='openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert $app_dir/sslh.crt -key $app_dir/sslh-kodirsync.key'"

# Create server find cmd to create dir share
eval "expanded_cmd_1=\"find '"$source"' -mindepth 1 -maxdepth 2 -regextype posix-extended -not -iregex '(.*/)?($exclude_os_dir_filter_regex)(/.*)?|(.*/)?($exclude_dir_filter_regex)(/.*)?|(.*/)?($black_dir_filter_regex)(/.*)?|(.*/)?($video_subfolder_dir_filter_regex)(/.*)?' -type d -printf '%P\\n'\""
eval "expanded_cmd_2=\"find '"$source"' -mindepth 1 -maxdepth 2 -regextype posix-extended -not -iregex '(.*/)?($exclude_os_dir_filter_regex)(/.*)?|(.*/)?($exclude_dir_filter_regex)(/.*)?|(.*/)?($black_dir_filter_regex)(/.*)?' -regextype posix-extended -iregex '(.*/)?($video_subfolder_dir_filter_regex)(/.*)?' -type d -printf '%P\\n'\""
echo $expanded_cmd_1

# Run SSH cmd
$ssh_cmd $rsync_username@$rsync_address "bash -c \'$expanded_cmd_1\'"
check_code_1=$?
$ssh_cmd $rsync_username@$rsync_address "bash -c \'$expanded_cmd_2\'"
check_code_2=$?
echo "check_code_1: $check_code_1"
echo "check_code_2: $check_code_2"

# ssh -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
# -o "BatchMode yes" \
# -o "StrictHostKeyChecking no" \
# -o "ConnectTimeout 5" \
# -o ProxyCommand="openssl s_client -quiet -connect $sslh_address_url:$sslh_port -servername kodirsync.$sslh_address_url -cert $app_dir/sslh.crt -key $app_dir/sslh-kodirsync.key" \
# $rsync_username@$localdomain_address_url "bash -c \"$expanded_cmd_2\""
# check_code_1=$?
# echo "check_code_1: $check_code_1"


# localdomain_address_url1=kodirsync
# ssh -i $ssh_dir/"$rsync_username"_kodirsync_id_ed25519 \
# -o "BatchMode yes" \
# -o "StrictHostKeyChecking no" \
# -o "ConnectTimeout 5" \
# -p 22 \
# $rsync_username@$localdomain_address_url1 "bash -c \"$expanded_cmd_2\""


#-----------------------------------------------------------------------------------------------------------------------