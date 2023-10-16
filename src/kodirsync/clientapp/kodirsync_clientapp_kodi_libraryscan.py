#! /usr/bin/python3

# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_kodi_libraryscan.py
# Description:  Runs Kodi Kodirsync library scanner
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

import os
import subprocess
import time
import sys

#---- Static Variables -------------------------------------------------------------

# Kodi msg display time duration (m/s)
display_time_long = '10000'
display_time_short = '3000'

# Notification icon
icon_green = '/storage/.kodi/addons/script.module.kodirsync/kodi_icon_start.png'
icon_red = '/storage/.kodi/addons/script.module.kodirsync/kodi_icon_stop.png'
icon_orange = '/storage/.kodi/addons/script.module.kodirsync/kodi_icon_idle.png'


#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Kodi func - 'running'
def kodimsg_running():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,Library scan already running... ,{display_time_short},{icon_green})'])

# Kodi func - 'library update'
def kodi_library_update():
    # Display kodi msg
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync, Starting library scan... ,{display_time_short},{icon_green})'], check=True)

    # Kodi library clean
    subprocess.run(['/usr/bin/kodi-send', '-a', f'CleanLibrary(video)'], check=True)
    subprocess.run(['/usr/bin/kodi-send', '-a', f'CleanLibrary(music)'], check=True)

    # Kodi library update
    subprocess.run(['/usr/bin/kodi-send', '-a', f'UpdateLibrary(video)'], check=True)
    subprocess.run(['/usr/bin/kodi-send', '-a', f'UpdateLibrary(music)'], check=True)

    # Display kodi msg
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync, Media libraries updated... ,{display_time_short},{icon_green})'], check=True)

# Check if the library update function is running
def is_library_update_running():
    # List of processes to check for
    process_name = "kodi_library_update"  # Adjust this as needed

    # Command to list all processes (ps aux)
    ps_command = ["ps", "aux"]

    # Execute the ps aux command and capture the output
    ps_output = subprocess.run(ps_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout

    # Check if the process is running
    return process_name in ps_output

# Main script func - 'main script'
def main():
    # Check if the library update function is already running
    if is_library_update_running():
        kodimsg_running()
        sys.exit(0)  # Exit the Python script without further execution

    # If the function is not running, proceed to execute the library update
    kodi_library_update()


#---- Body -------------------------------------------------------------------------

# Call the main function
if __name__ == "__main__":
    main()
#-----------------------------------------------------------------------------------