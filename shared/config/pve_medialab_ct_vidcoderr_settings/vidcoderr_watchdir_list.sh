#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchdir_list.sh
# Description:  Source script for creating Vidcoderr lists (whitelists etc)
# Usage:  Requires vidcoderr_watchdir.sh
# Usage:  All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Create check lists
unset rsync_control_TMPLIST
unset rsync_white_TMPLIST
unset rsync_black_TMPLIST
unset existing_file_LIST
while IFS=',' read -r label media_type src dst encode_str; do
  # Create whitelist and blacklist list tmp
  if [[ ${media_type} =~ ^(documentary|musicvideo|movies|pron|series|)$ ]] && [[ -f ${src}/rsync_control_list_global-${media_type}.txt ]]; then
    rsync -az ${src}/rsync_control_list_global-${media_type}.txt  ${APP_HOME}/
    # rsync_control_LIST
    mapfile -t -O "${#rsync_control_TMPLIST[@]}" rsync_control_TMPLIST < <(cat ${APP_HOME}/rsync_control_list_global-${media_type}.txt | sed '/^#/d;/^$/d'| sed 's/ *$//' | sed "s/$/|${media_type}/")
    # rsync_white_LIST
    mapfile -t -O "${#rsync_white_TMPLIST[@]}" rsync_white_TMPLIST < <(cat ${APP_HOME}/rsync_control_list_global-${media_type}.txt | sed '/^#/d;/^$/d'| sed 's/ *$//' | sed "s/$/|${media_type}/" | awk -F'|' 'BEGIN{OFS=FS} {if($1 == "w" || $1 == "W") print $2}')
    # rsync_black_LIST
    mapfile -t -O "${#rsync_black_TMPLIST[@]}" rsync_black_TMPLIST < <(cat ${APP_HOME}/rsync_control_list_global-${media_type}.txt | sed '/^#/d;/^$/d'| sed 's/ *$//' | sed "s/$/|${media_type}/" | awk -F'|' 'BEGIN{OFS=FS} {if($1 == "b" || $1 == "B") print $2}')
  fi

  # Create existing file list
  while IFS='|' read -r src_size epochtime datetime dir filename; do
    if [ ! ${media_type} == "autoadd" ] && [[ "$filename" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]] && [ ${src_size} -gt ${SRC_STREAM_MIN_SIZE} ]; then
      existing_file_LIST+=( "${dir}/${filename}" )
    fi
  done < <(rsync -nr -t --no-links --relative --list-only --out-format='%n' --min-size='1' --include-from=${APP_HOME}/rsync_video_format_filter.txt  --prune-empty-dirs "${dst}" | \
  cut -d' ' -f2- | sed 's/^ *//' | \
  awk -F' ' '{OFS=FS; gsub(/,/,"",$1); command="date -d\""$2" "$3"\" +%s"; $3=$2"#"$3; command | getline $2; close(command); print $0}' | \
  sed 's/ /|/;s/ /|/;s/ /|\//' | sed 's/\(.*\)\/\(.*\)\.\(.*\)$/\1|\2.\3/' | sed 's/#/ /' | sed '/^$/d')
done< <(printf '%s\n' "${input_dir_LIST[@]}")

# Create whitelist and blacklist (remove duplicates)
unset rsync_control_LIST
unset rsync_white_LIST
unset rsync_black_LIST
# rsync_control_LIST
while IFS= read -r -d '' x
do
  rsync_control_LIST+=("$x")
done < <(printf "%s\0" "${rsync_control_TMPLIST[@]}" | sort -uz)
printf '%s\n' "${rsync_control_LIST[@]}" > ${APP_HOME}/rsync_control_LIST.txt

# rsync_white_LIST
while IFS= read -r -d '' x
do
  rsync_white_LIST+=("$x")
done < <(printf "%s\0" "${rsync_white_TMPLIST[@]}" | sort -uz)
printf '%s\n' "${rsync_white_LIST[@]}" > ${APP_HOME}/rsync_white_LIST.txt

# rsync_black_LIST
while IFS= read -r -d '' x
do
  rsync_black_LIST+=("$x")
done < <(printf "%s\0" "${rsync_black_TMPLIST[@]}" | sort -uz)
printf '%s\n' "${rsync_black_LIST[@]}" > ${APP_HOME}/rsync_black_LIST.txt
#-----------------------------------------------------------------------------------