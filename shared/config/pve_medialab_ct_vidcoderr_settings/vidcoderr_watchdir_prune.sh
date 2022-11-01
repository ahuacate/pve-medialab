#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchdir_prune.sh
# Description:  Source script for pruning Vidcoderr media and logs
# Usage:  All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Check 'DST_STREAM_AGE' is not equal to 'RSYNC_CUTOFF_END'
if [ ${DST_STREAM_AGE} -le ${RSYNC_CUTOFF_END} ]; then
  DST_STREAM_AGE=$(( ${RSYNC_CUTOFF_END} + 1 ))
fi

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Prune DST stream media, delete orphaned folders & README-source_file_type.error.log error files
if ! [ ${DST_STREAM_AGE} = 0 ]; then
  while IFS=',' read -r label media_type src dst encode_str; do
    # Delete source log warnings after 1day
    find "${src}" -type f \( ! -iname ".foo_protect" \) -name README-source_file_type.error.log -mtime +1 -delete

    # Prune aged stream media
    if [ ${label} == 'in_stream' ]; then
      # Whitelist (exclude dirs)
      findargs=()
      for i in "${rsync_white_LIST[@]}"; do
        findargs+=('!' '-path' "*/$i/*")
      done
      find "${dst}" -mindepth 1 -depth -type f \( ! -iname ".foo_protect" \) "${findargs[@]}" -mtime +${DST_STREAM_AGE} -delete
      find "${dst}" -mindepth 1 -depth -type d -empty -delete

      # Black list (delete dir name)
      for i in "${rsync_black_LIST[@]}"; do
        find "${dst}" -mindepth 1 -depth -name "$i" -type d -exec rm -rf {} +
      done

      # Remove small folders (folders without video media)
      while read -r dir_size dir_path; do
        [[ ${dir_size} -lt ${DST_STREAM_DIR_MINSIZE} ]] && rm -rf "${dir_path}" 2> /dev/null
      done < <(find ${dst} -mindepth 1 -depth -type d -exec du -ks {} \;)
    fi
  done < <(printf '%s\n' "${input_dir_LIST[@]}")

  # Return to working dir
  cd ${TRANSCODE_DIR}
fi