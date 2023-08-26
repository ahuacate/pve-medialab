#! /usr/bin/python3

# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_kodi_run.py
# Description:  Runs Kodi Kodirsync via favourites
#               Parent to:
#                 'kodirsync_clientapp_run.sh'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

import os
import subprocess
import time
os.system("xfce4-terminal")

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

# Kodi func - 'app not found'
def kodimsg_app_not_found():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,App not found! ,{display_time_long},{icon_red})'])

# Kodi func - 'running'
def kodimsg_running():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,App already running... ,{display_time_short},{icon_green})'])

# Kodi func - 'start'
def kodimsg_start():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,Starting synchronization... ,{display_time_short},{icon_green})'])

# Kodi func - 'finish'
def kodimsg_finish():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync, Synchronization completed... ,{display_time_short},{icon_orange})'])

# Kodi func - 'library update'
def kodi_library_update():
    # Kodi library update
    subprocess.run(['/usr/bin/kodi-send', '-a', f'UpdateLibrary(video)'])
    subprocess.run(['/usr/bin/kodi-send', '-a', f'UpdateLibrary(music)'])

    # Display kodi msg
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync, Media libraries updated... ,{display_time_short},{icon_green})'])

# Check func - 'checks if script is already running'
def check():
  # Command to list all processes (ps aux)
  ps_command = ["ps", "aux"]

  # Execute the ps aux command and capture the output
  ps_output = subprocess.run(ps_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout

  # List of processes to check for (script names without path)
  processes_to_check = [
      "kodirsync_clientapp_run.sh",
      "kodirsync_clientapp_kodi_gitupdater.py",
      "kodirsync_clientapp_kodi_gitupdater.sh" 
  ]

  # Initialize a variable to track if any process is running
  any_process_running = False

  # Check if each process is running
  for process in processes_to_check:
      if process in ps_output:
          any_process_running = True
          break

  # Send Kodi message based on the result
  if any_process_running:
      kodimsg_running()
      exit(0)

# Main script func - 'main script'
def main():
    #---- Prerequisites

    # Locate script, Set $app_dir, Exit if no script
    file_path = next((path for path in subprocess.run(['find', '/', '-not', '-path', '/tmp/*', '-path', '*/kodirsync_app/*', '-type', 'f', '-name', 'kodirsync_clientapp_run.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.split('\n') if path.strip()), None)
    if file_path:
        app_dir = os.path.dirname(file_path)
    else:
        kodimsg_app_not_found()
        exit(0)

    #---- Run Bash script
    
    # Display kodi msg
    kodimsg_start()
    
    # Path to the bash script
    bash_script_path = f"{app_dir}/kodirsync_clientapp_run.sh"

    # Execute the shell script in a new shell using subprocess.Popen
    process = subprocess.Popen(["bash", bash_script_path])

    # Wait for the process to finish
    process.wait()
    
    # Display kodi msg
    kodimsg_finish()

    #---- Update Kodi library

    # Call the function - library update
    kodi_library_update()

#---- Body -------------------------------------------------------------------------

# Call the check function
check()

# Call the main function
if __name__ == "__main__":
    main()
#-----------------------------------------------------------------------------------