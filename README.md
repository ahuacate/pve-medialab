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
This service will only allow VPN traffic to leave your network. If the VPN connection drops, so will your client device.
Kick off the installation by deploying a LXC container using the CentOS7 proxmox lxc template image:

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
5. We need to enable kernel IP forwarding on a permananent basis. In the cli `>_console` type the following:
```
echo -e "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf &&
sysctl -w net.ipv4.ip_forward=1 &&
systemctl restart network.service
```
6. Next we need to install and configure your Iptables by using the `iptables.sh` script your previously downloaded. At this stage will will reboot the lxc container. In the cli `>_console` type the following:
```
yum install -y iptables-services &&
systemctl enable iptables &&
bash /etc/openvpn/iptables.sh &&
systemctl start iptables &&
reboot
```
7. You are finished. After the reboot check to see if your OpenVPN-Gateway is working. The key word in the results is "Initialization Sequence Completed". In the cli `>_console` type the following:
```diff
systemctl status openvpn@vpn-gateway.service

### Results Should be like ###
[root@vpn-gateway ~]# systemctl status openvpn@vpn-gateway.service
● openvpn@vpn-gateway.service - OpenVPN Robust And Highly Flexible Tunneling Application On vpn/gateway
   Loaded: loaded (/usr/lib/systemd/system/openvpn@.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2019-06-02 05:58:23 UTC; 3min 37s ago
 Main PID: 287 (openvpn)
   Status: "Initialization Sequence Completed"
   CGroup: /system.slice/system-openvpn.slice/openvpn@vpn-gateway.service
           └─287 /usr/sbin/openvpn --cd /etc/openvpn/ --config vpn-gateway.conf

Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 ROUTE_GATEWAY 192.168.1.5/255.255.255.0 IFACE=eth0 HWADDR=1e:b4:a3:6f:f8:91
Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 TUN/TAP device tun0 opened
Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 TUN/TAP TX queue length set to 100
Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 /sbin/ip link set dev tun0 up mtu 1500
Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 /sbin/ip addr add dev tun0 local 10.118.0.170 peer 10.118.0.169
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 /sbin/ip route add 178.162.199.91/32 via 192.168.1.5
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 /sbin/ip route add 0.0.0.0/1 via 10.118.0.169
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 /sbin/ip route add 128.0.0.0/1 via 10.118.0.169
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 /sbin/ip route add 10.118.0.1/32 via 10.118.0.169
+Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 Initialization Sequence Completed
```

