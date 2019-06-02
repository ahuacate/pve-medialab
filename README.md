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
| `IPv4/CIDR` |192.168.1.254/24|
| `Gateway` |192.168.1.5|

You have two options to install and configure a OpenVPN Gateway. Use a automated script or manually.
#### 1. Automated Installation
Test
#### 2. Manual Installation
1.  We need to enable Tun for OpenvVPN on our proxmox host lxc configuration file, go to the path /etc/pve/lxc/253.conf on typhoon-01 and add the following to the last line. Note, this must be performed on all proxmox nodes (i.e typhoon-01, typhoon-02 etc).
In typhoon-01 instance web interface `typhoon-01` > `>_Shell` type the following:
```
cat >> /etc/pve/lxc/253.conf << EOL
lxc.cgroup.devices.allow: c 10:200 rwm
lxc.hook.autodev: sh -c "modprobe tun; cd ${LXC_ROOTFS_MOUNT}/dev; mkdir net; mknod net/tun c 10 200; chmod 0666 net/tun"
EOL
```
2.  Next on the vpn-gateway lxc instance type the following to install the epel-release repository and Open-VPN, openssh-server, wget and nano software. In the cli `>_console` type the following:
```
yum -y install epel-release && yum -y update && yum install -y openvpn openssh-server wget nano
```
3.  Next we are going to download from github 3 prebuilt files for your OpenVPN Gateway (preconfigured for a ExpressVPN service - so edit `vpn-gateway.ovpn` if you are using another service provider (i.e PIA)) and a CentOS7 tables script.
In the cli `>_console` type the following:
```
cd /etc/openvpn &&
wget -N https://raw.githubusercontent.com/ahuacate/proxmox/master/openvpn/auth-vpn-gateway.txt -P /etc/openvpn &&
wget -N https://raw.githubusercontent.com/ahuacate/proxmox/master/openvpn/iptables.sh -P /etc/openvpn &&
wget -N https://raw.githubusercontent.com/ahuacate/proxmox/master/openvpn/vpn-gateway.ovpn -P /etc/openvpn
```
4. You need to insert your VPN Provider access username and password into the `auth-vpn-gateway.txt`. Change `username` and `password` below accordingly (note: must be on two lines as shown).
In the cli `>_console` type the following:
```
echo -e "username
password" > /etc/openvpn/auth-vpn-gateway.txt
```
