# Proxmox-LXC
The following is for creating LXC containers.

Network Prerequisites are:
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5` (Note: set DNS server: primary DNS `1.1.1.1` ; secondary DNS `192.168.1.254`)
- [x] Network DHCP server is `192.168.1.5`

Other Prerequisites are:
- [x] Synology NAS, including NFS, is fully configured as per [synobuild](https://github.com/ahuacate/synobuild)
- [x] Proxmox node fully configured as per [proxmox-node](https://github.com/ahuacate/proxmox-node)

Tasks to be performed are:
- [ ] Install PiHole LXC
- [ ] Install OpenVPN Gateway LXC

## LXC Installations
I use CentosOS7 as my preferred linux distribution for VMs and LXC containers. Proxmox itself ships a set of basic templates and to download the prebuilt CentosOS7 LXC use the graphical interface `typhoon-01` > `local` > `content` > `templates` and select the `centos-7-default` template for downloading.

### 1. PiHole LXC Container - CentOS7
Deploy an LXC container using the CentOS7 proxmox lxc template image:

| Option | Node 1 Value |
| :---  | :---: |
| `CT ID` |100|
| `Hostname` |pihole|
| `Unprivileged container` | ☑ |
| `Template` |centos-7-default_****_amd|
| `Storage` |typhoon-share-01|
| `Disk Size` |8 GiB|
| `CPU Cores` |2|
| `Memory (MiB)` |1024|
| `Swap (MiB)` |512|
| `IPv4/CIDR` |192.168.1.254/24|
| `Gateway` |192.168.1.5|

Using the proxmox LXC `pihole` instance web interface cli install pihole:
`curl -sSL https://install.pi-hole.net | bash`
Follow the generic prompts making sure to set server IP to `192.168.1.254` (same as LXC host) and Gateway to `192.168.1.5`.

### 2. OpenVPN Gateway LXC - CentOS7
Deploy an LXC container using the CentOS7 proxmox lxc template image:

| Option | Node 1 Value |
| :---  | :---: |
| `CT ID` |253|
| `Hostname` |vpn-gateway|
| `Unprivileged container` | ☐  (must be be privileged)|
| `Template` |centos-7-default_****_amd|
| `Storage` |typhoon-share-01|
| `Disk Size` |8 GiB|
| `CPU Cores` |1|
| `Memory (MiB)` |2048|
| `Swap (MiB)` |512|
| `IPv4/CIDR` |192.168.1.253/24|
| `Gateway` |192.168.1.5|

Using the proxmox LXC `vpn-gateway` instance web interface cli install openvpn and configure:
1.  First step is to mod the host (typhoon-01) proxmox lxc container config file for CT ID 253.
`typhoon-01` > `>_Shell` and using cli type:
`cat >> /etc/pve/lxc/253.conf << EOL
lxc.cgroup.devices.allow: c 10:200 rwm
lxc.hook.autodev: sh -c "modprobe tun; cd ${LXC_ROOTFS_MOUNT}/dev; mkdir net; mknod net/tun c 10 200; chmod 0666 net/tun"
EOL`
