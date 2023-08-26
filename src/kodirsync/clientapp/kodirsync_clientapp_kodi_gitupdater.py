#!/usr/bin/env python
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_kodi_gitupdater.py
# Description:  Runs Kodi Kodirsync GitHub Git updater
#               Parent to:
#                 'kodirsync_clientapp_kodi_gitupdater.sh'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

import os
import subprocess

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

#---- Kodi display func

# Kodi func - 'app not found'
def kodimsg_app_not_found():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,App not found! ,{display_time_long},{icon_red})'])

# Kodi func - 'disabled'
def kodimsg_disabled():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,Updater is disabled in your user settings... ,{display_time_long},{icon_orange})'])

# Kodi func - 'fail'
def kodimsg_fail():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,Update failed... ,{display_time_long},{icon_red})'])

# Kodi func - 'running'
def kodimsg_running():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,App already running... ,{display_time_short},{icon_green})'])

# Kodi func - 'start'
def kodimsg_start():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,Starting app updater... ,{display_time_short},{icon_green})'])

# Kodi func - 'finish'
def kodimsg_finish():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync, Update completed... ,{display_time_short},{icon_orange})'])

#---- Check func
# checks if script is already running
def check():
    # Command to list all processes (ps aux)
    ps_command = ["ps", "aux"]

    # Execute the ps aux command and capture the output
    ps_output = subprocess.run(ps_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout

    # List of processes to check for (script names without path)
    processes_to_check = [
        "kodirsync_clientapp_run.sh",
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


#---- Prerequisites func
def prerequisites():
    # Locate script, Set $app_dir, Exit if no script
    file_path = next((path for path in subprocess.run(['find', '/', '-not', '-path', '/tmp/*', '-path', '*/kodirsync_app/*', '-type', 'f', '-name', 'kodirsync_clientapp_gitupdater.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.split('\n') if path.strip()), None)
    if file_path:
        app_dir = os.path.dirname(file_path)
        return app_dir  # Return the app_dir value
    else:
        # Display kodi msg
        kodimsg_app_not_found()
        exit(0)

    # Path to the configuration file
    config_file_path = f"{app_dir}/kodirsync_clientapp_user.cfg"

    # Initialize github_updater variable
    github_updater = None

    # Read the configuration file
    with open(config_file_path, "r") as config_file:
        for line in config_file:
            if line.startswith("github_updater="):
                github_updater = line.split("=")[1].strip("'\"\n")
                break

    # Check the extracted value
    if github_updater is None or github_updater == "0":
        # Display kodi msg
        kodimsg_disabled()
        exit(0)


# Main func
def main():
    # Call the prerequisites function and store the app_dir value
    app_dir = prerequisites()
    
    # Display kodi msg
    kodimsg_start()

    # Path to the script
    bash_script_path = f"{app_dir}/kodirsync_clientapp_gitupdater.sh"

    # Argument to pass to the script
    script_args = ""

    # Read the content of the script
    with open(bash_script_path, "r") as script_file:
        script_content = script_file.read()

    # Run bash script
    process = subprocess.Popen(["bash", "-c", f"{script_content} {' '.join(script_args)}"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    stdout, stderr = process.communicate()

    print("Script Output:")
    print(stdout)  # Print the captured output for debugging

    # Capture dl_status from the last line of stdout
    dl_status_lines = stdout.strip().split('\n')
    dl_status = dl_status_lines[-1] if dl_status_lines else None

    if dl_status is None:
        # Handle case when dl_status is not captured
        pass
    elif dl_status == "0":
        kodimsg_fail()
    elif dl_status == "1":
        kodimsg_finish()
    else:
        # Handle other dl_status values if needed
        pass

#---- Body -------------------------------------------------------------------------

# Call the check function
check()

# Call the prerequisites function
prerequisites()

# Call the main function
if __name__ == "__main__":
    main()
#-----------------------------------------------------------------------------------