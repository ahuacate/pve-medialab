#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_linux.sh
# Description:  Default Kodirsync client run script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Create new Linux user

# Create new user group
if ! getent group $user_grp >/dev/null
then
  sudo groupadd -g $linux_guid $user_grp > /dev/null
fi

# Create new user
if ! id -u $user >/dev/null 2>&1
then
  # Add new user
  useradd -u $linux_uid -g $user_grp -s /bin/bash -m $user >/dev/null

  # Add user 'media' to sudo group
  sudo usermod -aG sudo $user 2> /dev/null
fi

# Set ssh_dir
ssh_dir="$(awk -F: "/^$user:/ {print \$6}" /etc/passwd)/.ssh"

# Create user '.ssh' folder
sudo mkdir -p $ssh_dir 2> /dev/null
sudo chmod 700 $ssh_dir

# Create user ssh 'authorized_keys' file
if [ ! -f "$ssh_dir/authorized_keys" ]
then
  sudo touch $ssh_dir/authorized_keys 2> /dev/null
  sudo chmod 600 $ssh_dir/authorized_keys
fi

# Chown '.ssh' folder and contents
sudo chown -R "$user:$user_grp" "$ssh_dir"

# Specify the path to the known_hosts file
known_hosts_file="$ssh_dir/known_hosts"

# Create '$known_hosts_file' if missing
if [ ! -f "$known_hosts_file" ]
then
  # Create the known_hosts file
  touch "$known_hosts_file"

  # Set the appropriate ownership and permissions
  sudo chmod 600 "$known_hosts_file"
  sudo chown "$user:$user_grp" "$known_hosts_file"
fi
#-----------------------------------------------------------------------------------