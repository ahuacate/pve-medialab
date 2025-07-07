#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     kodirsync_clientapp_install_format_disk_exfat.sh
# Description:  Script to format disk to exFAT format
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

# Partition ID
partition="${dev_path}1"

# Disk identifier (i.e "sdb", "nvme0n1")
disk_id=$(basename "$dev_path")

# Convert max_partition_size to bytes
max_partition_size_bytes=$(( $android_storage_cap * 1024 * 1024 * 1024 * 1024 ))

# Get the disk size in bytes
disk_size=$(cat "/sys/block/$disk_id/size")
disk_size=$((disk_size * 512))

# Unmount the disk if already mounted
umount "$dev_path" >/dev/null 2>&1
wait


#---- Format to exFAT

# Create a new partition table
parted "$dev_path" -a opt mklabel msdos -s
wait

# Create exFAT partition
# Android r/w only exFAT partitions. To make this work using busybox ELEC and
# parted cmd you must pre-formated to fat32 (not ext4 or other flavours)
# before formatting to exFAT for it work with Android
if [[ "$disk_size" -gt "$max_partition_size_bytes" ]] && [ ! "$android_storage_cap" = 0 ]
then
  # Create a new primary partition with specific size and alignment
  parted "$dev_path" -a opt mkpart primary fat32 0% ${max_partition_size_bytes}B -s
  wait

  # Format the partition as exFAT
  umount "$partition" >/dev/null 2>&1
  wait
  mkfs.exfat -L "$disk_volume_label" "$partition"
  wait
else
  # Create a new primary partition
  parted "$dev_path" -a opt mkpart primary fat32 0% 100% -s
  wait
  
  # Format the partition as exFAT
  umount "$partition" >/dev/null 2>&1
  wait
  mkfs.exfat -L "$disk_volume_label" "$partition"
  wait
fi

# Update $dev_path
dev_path="$partition"
#-----------------------------------------------------------------------------------