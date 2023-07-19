#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_format_disk_ext4.sh
# Description:  Script to format disk to ext4 format
#               Disk must be unmounted
#               Disk must be wiped/empty
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Get disk rota type (i.e ssd or rust)
rota=$(udevadm info --attribute-walk --name="$dev_path" 2> /dev/null \
| grep -F 'ATTR{queue/rotational}' \
| cut -d\" -f2 \
| awk -v def="not avail" '{print} END { if(NR==0) {print def} }') # '1' is for ssd, '0' for rotational disk

# Partition ID
partition="${dev_path}1"

# Unmount the disk if already mounted
umount "$dev_path" >/dev/null 2>&1
wait


#---- Format to ext4

# Create a new partition table
parted "$dev_path" -a opt mklabel gpt -s
wait

# Create a new primary partition
parted "$dev_path" -a opt mkpart primary 0% 100% -s
wait

# FS ext4 formatting
mkfs.ext4 -F -q -L "$disk_label_name" "$partition"
wait

# Disk Over-Provisioning (ext4 only)
if [ "$rota" = 1 ]
then
  tune2fs -m "$over_prov_ssd" "$partition"
elif [ "$rota" = 2 ]
then
  tune2fs -m "$over_prov_rot" "$partition"
fi
wait

# Update $dev_path
dev_path="$partition"
#-----------------------------------------------------------------------------------