#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_common_presets.sh
# Description:  Kodirsync client common application presets
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- Set other Kodirsync options

# Set HDR arg
msg "${WHITE}#### PLEASE READ CAREFULLY - DISABLE HDR CONTENT ####${NC}
You have the option to disable HDR video content if any of the following conditions apply:

  --  Your media player does not support playing 4K HDR formatted videos.
  --  Your TV is unable to display 4K HDR formatted video media.
  --  Your media player lacks support for HDR to SDR tone-mapping playback.

By disabling 4K HDR, your Kodirsync client will not download any 4K HDR video content. However, it's important to note that this may result in limited availability of video media content.\n"

while true
do
  read -p "Do you want to enable HDR downloading [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      # Set to HDR enabled ('1' for enabled, '0' for disabled)
      info "HDR status is set: ${YELLOW}enabled${NC}"
      hdr_enable=1
      echo
      break
      ;;
    [Nn]*)
      # Set to HDR disabled ('1' for enabled, '0' for disabled)
      info "HDR status is set: ${YELLOW}disabled${NC}"
      hdr_enable=0
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done
#-----------------------------------------------------------------------------------------------------------------------