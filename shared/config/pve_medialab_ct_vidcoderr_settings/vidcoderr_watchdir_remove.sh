#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_watchdir_remove.sh
# Description:  Source script for removing Vidcoderr autoadd input and make logs
# Usage:  All variables/args set in /usr/local/bin/vidcoderr/vidcoderr.ini
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Action on incompatible SRC file
# Remove files from 'autoadd' dirs and make logs
if [ "${media_type}" == "autoadd" ]; then
  # Set 'src_mid_dir' var
  if [[ "${dir}" == "${src}" ]]; then
    src_mid_dir=""
  else
    src_mid_dir="$(echo "$dir" | sed "s|${src}||g" | sed 's/[^/]$/&\//')"
  fi

  # Set SRC/DST filename short ( for alias searches )
  FILENAME_SHORT="$(echo "${filename}" | sed -e 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed -e 's/ \.\([a-z0-9]*\)$/\.\1/' | sed -e 's/\(.[a-z0-9]*$\)//')"

  # Delete files
  find "${dir}" -mindepth 1 -depth -type f \( ! -name ".foo_protect" ! -name "EXCLUDE_LIST" $(printf ' -a ! -name *.%s\n' ${all_format_filter_LIST[@]}) \) -exec rm {} \;
  find "${src}" -mindepth 1 -depth -type f -iname "${FILENAME_SHORT}*" -delete 2> /dev/null
  find "${dst}" -mindepth 1 -depth -type d -empty -delete

  # Write log
  if [[ ! "${filename}" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
    sourcefile_error_log
  elif [ ! ${src_size} -gt ${SRC_STREAM_MIN_SIZE} ]; then
    make_error_log "Input file size ( ${src_size}Kb ) less than Vidcoderr minimum ( ${SRC_STREAM_MIN_SIZE}Kb )."
  elif [[ "${existing_file_LIST[@]}" =~ (^|[[:space:]])"${dir}"($|[[:space:]]) ]]; then
    make_error_log "Input file '${filename}' already exists."
  fi
elif [ ! "${media_type}" == "autoadd" ]; then
  # Write log
  if [[ ! "${filename}" =~ ^.*\.(${VIDEO_FORMAT_FILTER})$ ]]; then
    sourcefile_error_log
  elif [ ! ${src_size} -gt ${SRC_STREAM_MIN_SIZE} ]; then
    make_error_log "Input file size ( ${src_size}Kb ) less than Vidcoderr minimum ( ${SRC_STREAM_MIN_SIZE}Kb )."
  elif [[ "${existing_file_LIST[@]}" =~ (^|[[:space:]])"${dir}"($|[[:space:]]) ]]; then
    make_error_log "Input file '${filename}' already exists."
  fi
fi