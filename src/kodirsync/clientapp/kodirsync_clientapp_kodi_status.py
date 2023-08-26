#!/usr/bin/env python
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_kodi_status.py
# Description:  Checks Kodi Kodirsync status
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

import time
import subprocess
import os

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

# Kodi func - 'idle'
def kodimsg_idle():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,Apps are idle... ,{display_time_short},{icon_orange})'])

# Kodi func - 'running'
def kodimsg_running():
    subprocess.run(['/usr/bin/kodi-send', '-a', f'Notification(Kodirsync,Active - current DL speed: {download_speed_display},{display_time_short},{icon_green})'])

#---- Network interface speed
def get_active_network_interface():
    try:
        interface_names = os.listdir('/sys/class/net/')
        
        for interface_name in interface_names:
            with open(os.path.join('/sys/class/net', interface_name, 'operstate'), 'r') as f:
                operstate = f.read().strip()
                if operstate == 'up':
                    with open(os.path.join('/sys/class/net', interface_name, 'type'), 'r') as type_file:
                        network_type = int(type_file.read().strip())
                        if network_type == 1:
                            active_network_interface = interface_name  # LAN
                            return active_network_interface
                        elif network_type == 802:
                            active_network_interface = interface_name  # Wi-Fi
                            return active_network_interface
        
        return None
    
    except Exception as e:
        print("An error occurred:", e)
        return None

def get_rx_bytes(interface):
    with open(f"/sys/class/net/{interface}/statistics/rx_bytes", "r") as file:
        return int(file.read())

def convert_speed(speed_bps):
    if speed_bps < 1e6:  # Less than 1 Mbps
        speed_kbps = speed_bps / 1e3
        return f"{speed_kbps:.2f} kbps"
    else:
        speed_mbps = speed_bps / 1e6
        return f"{speed_mbps:.2f} Mbps"

def speed(interface, duration):
    initial_rx_bytes = get_rx_bytes(interface)
    start_time = time.time()

    time.sleep(duration)

    updated_rx_bytes = get_rx_bytes(interface)
    end_time = time.time()

    downloaded_bytes = updated_rx_bytes - initial_rx_bytes
    elapsed_time = end_time - start_time

    download_speed_bps = downloaded_bytes * 8 / elapsed_time  # Convert to bits per second

    download_speed_display = convert_speed(download_speed_bps)
    
    return download_speed_display

#---- Body -------------------------------------------------------------------------

if __name__ == "__main__":
    # Get active interface
    active_network_interface = get_active_network_interface()

    # Calculate download speed
    if active_network_interface:
        duration = 1  # Duration in seconds
        download_speed_display = speed(active_network_interface, duration)
    else:
        download_speed_display = 'unknown speed'

    # Command to list all processes (ps aux)
    ps_command = ["ps", "aux"]

    # Execute the ps aux command and capture the output
    ps_output = subprocess.run(ps_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout

    # List of processes to check for (script names without path)
    processes_to_check = [
        "kodirsync_clientapp_kodi_run.py",
        "kodirsync_clientapp_run.sh",
        "kodirsync_clientapp_kodi_gitupdater.py",
        "kodirsync_clientapp_gitupdater.sh" 
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
    else:
        kodimsg_idle()
#-----------------------------------------------------------------------------------