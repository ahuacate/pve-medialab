# Proxmox-LXC
The following is for creating LXC containers.

Network Prerequisites are:
- [x] Layer 2 Network Switches
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5` (Note: your Gateway hardware should enable you to a configure DNS server(s), like a UniFi USG Gateway, so set the following: primary DNS `192.168.1.254` which will be your PiHole server IP address; and, secondary DNS `1.1.1.1` which is a backup Cloudfare DNS server in the event your PiHole server 192.168.1.254 fails or os down)
- [x] Network DHCP server is `192.168.1.5`
- [x] A DDNS service is fully configured and enabled (I recommend you use the free Synology DDNS service)
- [x] A ExpressVPN account (or any preferred VPN provider) is valid and its smart DNS feature is working (public IP registration is working with your DDNS provider)

Other Prerequisites are:
- [x] Synology NAS, or linux variant of a NAS, is fully configured as per [SYNOBUILD](https://github.com/ahuacate/synobuild#synobuild)
- [x] Proxmox node fully configured as per [PROXMOX-NODE BUILDING](https://github.com/ahuacate/proxmox-node/blob/master/README.md#proxmox-node-building)

Tasks to be performed are:
- [ ] Install PiHole LXC
- [ ] Install OpenVPN Gateway LXC

**About LXC Installations**
I use CentosOS7 as my preferred linux distribution for VMs and LXC containers. Proxmox itself ships a set of basic templates and to download the prebuilt CentosOS7 LXC use the graphical interface `typhoon-01` > `local` > `content` > `templates` and select the `centos-7-default` template for downloading.

## 1.0 PiHole LXC - CentOS7
Here we are going install PiHole which is a internet tracker blocking application which acts as a DNS sinkhole. Basically its charter is to block advertisments, tracking domains, tracking cookies and all those personal data mining collection companies.

### 1.1 Deploy an LXC container using the CentOS7 LXC
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| `Node` | typhoon-01 |
| `CT ID` |254|
| `Hostname` |pihole|
| `Unprivileged container` | ☑ |
| `Resource Pool` | Leave Blank
| `Password` | Enter your pasword
| `Password` | Enter your pasword
| `SSH Public key` | Add one if you want to
| **Template**
| `Storage` | local |
| `Template` |centos-7-default_****_amd|
| **Root Disk**
| `Storage` |typhoon-share|
| `Disk Size` |8 GiB|
| **CPU**
| `Cores` |1|
| `CPU limit` | Leave Blank
| `CPU Units` | 1024
| **Memory**
| `Memory (MiB)` |256|
| `Swap (MiB)` |256|
| **Network**
| `Name` | eth0
| `Mac Address` | auto
| `Bridge` | vmbr0
| `VLAN Tag` | Leave Blank
| `Rate limit (MN/s)` | Leave Default (unlimited)
| `Firewall` | [x]
| `IPv4` | [x] Static
| `IPv4/CIDR` |192.168.1.254/24|
| `Gateway (IPv4)` |192.168.1.5|
| `IPv6` | Leave Blank
| `IPv4/CIDR` | Leave Blank |
| `Gateway (IPv6)` | Leave Blank |
| **DNS**
| `DNS domain` | Leave Default (use host settings)
| `DNS servers` | Leave Default (use host settings)
| **Confirm**
| `Start after Created` | [x]

And Click `Finish` to create your PiHole LXC.

Or if you prefer you can simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following to achieve the same thing:
```
pct create 254 local:vztmpl/centos-7-default_20171212_amd64.tar.xz --arch amd64 --cores 1 --hostname pihole --cpulimit 1 --cpuunits 1024 --memory 256 --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.1.5,ip=192.168.1.254/24,type=veth --ostype centos --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=1 --password
```

qm create 253 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso,media=cdrom --memory 2048 --name pfsense --net0 virtio,bridge=vmbr0,firewall=1 --net1 virtio,bridge=vmbr1,firewall=1 --net2 virtio,bridge=vmbr2,firewall=1 --net3 virtio,bridge=vmbr3,firewall=1 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --sockets 1 --virtio0 local-lvm:32 --startup order=1

### 1.2 Install PiHole

In the pihole lxc instance use the cli `>_console` and type the following:
```
curl -sSL https://install.pi-hole.net | bash
```
Follow the generic prompts making sure to set server IP to `192.168.1.254` (same as LXC host) and Gateway to `192.168.1.5`.

### 2. OpenVPN Gateway LXC - CentOS7
This service will only allow VPN traffic to leave your network. If the VPN connection drops, so will your client device.
Kick off the installation by deploying a LXC container using the CentOS7 proxmox lxc template image:

| Option | Node 1 Value |
| :---  | :---: |
| `CT ID` |253 (must be 253!)|
| `Hostname` |vpn-gateway|
| `Unprivileged container` | ☐  (must be privileged!)|
| `Template` |centos-7-default_****_amd|
| `Storage` |typhoon-share-01|
| `Disk Size` |8 GiB|
| `CPU Cores` |1|
| `Memory (MiB)` |2048|
| `Swap (MiB)` |512|
| `IPv4/CIDR` |192.168.1.253/24|
| `Gateway` |192.168.1.5|

You have two options to install and configure a OpenVPN Gateway. Use a automated script or manually.
#### 1. Automated Installation - 3 steps
1.  We need to enable Tun for OpenvVPN on our proxmox host lxc configuration file, go to the path /etc/pve/lxc/253.conf on typhoon-01 and add the following to the last line. Note, this must be performed on all proxmox nodes (i.e typhoon-01, typhoon-02 etc).
In typhoon-01 instance web interface `typhoon-01` > `>_Shell` type the following:
```
cat >> /etc/pve/lxc/253.conf << EOL
lxc.cgroup.devices.allow = c 10:200 rwm
lxc.hook.autodev = sh -c "modprobe tun; cd ${LXC_ROOTFS_MOUNT}/dev; mkdir net; mknod net/tun c 10 200; chmod 0666 net/tun"
EOL
```
2.  To fast track the process there is script for a automated installation. In the vpn-gateway lxc instance use the cli `>_console` and type the following:
```
curl https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/build-vpn-gateway-expressvpn.sh | bash
```
3. Last you need to insert your VPN Provider access username and password into `auth-vpn-gateway.txt`. Replace `username` and `password` below accordingly (note: must be on two lines as shown).
In the cli `>_console` type the following:
```
echo -e "username
password" > /etc/openvpn/auth-vpn-gateway.txt &&
reboot
```

#### 2. Manual Installation
1.  We need to enable Tun for OpenvVPN on our proxmox host lxc configuration file, go to the path /etc/pve/lxc/253.conf on typhoon-01 and add the following to the last line. Note, this must be performed on all proxmox nodes (i.e typhoon-01, typhoon-02 etc).
In typhoon-01 instance web interface `typhoon-01` > `>_Shell` type the following:
```
cat >> /etc/pve/lxc/253.conf << EOL
lxc.cgroup.devices.allow = c 10:200 rwm
lxc.hook.autodev = sh -c "modprobe tun; cd ${LXC_ROOTFS_MOUNT}/dev; mkdir net; mknod net/tun c 10 200; chmod 0666 net/tun"
EOL
```
2.  Next on the vpn-gateway lxc instance type the following to install the epel-release repository and Open-VPN, openssh-server, wget and nano software. In the cli `>_console` type the following:
```
yum -y install epel-release && yum -y update && yum install -y openvpn openssh-server nano wget
```
3.  Next we are going to download from github 3 prebuilt files for your OpenVPN Gateway (preconfigured for a ExpressVPN service - so edit `vpn-gateway.ovpn` if you are using another service provider (i.e PIA)) and a CentOS7 tables script. Also the scripts use port 1195 and if your vpn service uses another port, for example port 1194, you must edit the port number in two files: a) vpn-gateway.ovpn, and; b) iptables.sh before executing step 6.
In the cli `>_console` type the following:
```
cd /etc/openvpn &&
wget -N https://raw.githubusercontent.com/ahuacate/proxmox/master/openvpn/auth-vpn-gateway.txt -P /etc/openvpn &&
wget -N https://raw.githubusercontent.com/ahuacate/proxmox/master/openvpn/iptables-vpn-gateway-expressvpn.sh -P /etc/openvpn &&
wget -N https://raw.githubusercontent.com/ahuacate/proxmox/master/openvpn/vpn-gateway-expressvpn.conf -P /etc/openvpn
```
4. You need to insert your VPN Provider access username and password into `auth-vpn-gateway.txt`. Change `username` and `password` below accordingly (note: must be on two lines as shown).
In the cli `>_console` type the following:
```
echo -e "username
password" > /etc/openvpn/auth-vpn-gateway.txt
```
5. We need to enable kernel IP forwarding on a permananent basis. In the cli `>_console` type the following:
```
echo -e "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf &&
systemctl restart network.service
```
6. Next we need to install and configure your Iptables by using the `iptables.sh` script your previously downloaded. At this stage will will reboot the lxc container. In the cli `>_console` type the following:
```
yum install -y iptables-services &&
bash /etc/openvpn/iptables-vpn-gateway-expressvpn.sh &&
systemctl enable iptables &&
reboot
```
If you want to check your iptables have been updated by the `iptables.sh` script type the following:
```
cat /etc/sysconfig/iptables

--- Results---
[root@vpn-gateway ~]# cat /etc/sysconfig/iptables
# Generated by iptables-save v1.4.21 on Thu May 30 14:51:20 2019
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT DROP [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -s 255.255.255.255/32 -j ACCEPT
-A INPUT -s 192.168.0.0/24 -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i eth0 -p udp -m state --state ESTABLISHED -m udp --sport 53 -j ACCEPT
-A INPUT -i eth0 -p tcp -m state --state ESTABLISHED -m tcp --sport 53 -j ACCEPT
-A INPUT -i eth0 -p tcp -m state --state ESTABLISHED -m tcp --sport 80 -j ACCEPT
-A INPUT -i eth0 -p tcp -m state --state ESTABLISHED -m tcp --sport 443 -j ACCEPT
-A INPUT -i tun+ -j ACCEPT
-A INPUT -j DROP
-A FORWARD -i tun+ -j ACCEPT
-A FORWARD -o tun+ -j ACCEPT
-A FORWARD -j DROP
-A OUTPUT -p udp -m udp --dport 1195 -m comment --comment "Allow VPN connection" -j ACCEPT
-A OUTPUT -o lo -j ACCEPT
-A OUTPUT -d 255.255.255.255/32 -j ACCEPT
-A OUTPUT -d 192.168.0.0/24 -j ACCEPT
-A OUTPUT -o eth0 -p udp -m state --state NEW,ESTABLISHED -m udp --dport 53 -j ACCEPT
-A OUTPUT -o eth0 -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 53 -j ACCEPT
-A OUTPUT -o eth0 -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 80 -j ACCEPT
-A OUTPUT -o eth0 -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 443 -j ACCEPT
-A OUTPUT -o tun+ -j ACCEPT
-A OUTPUT -j DROP
COMMIT
# Completed on Thu May 30 14:51:20 2019
# Generated by iptables-save v1.4.21 on Thu May 30 14:51:20 2019
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o tun+ -j MASQUERADE
COMMIT
# Completed on Thu May 30 14:51:20 2019
```
7. You are finished. After the reboot check to see if your OpenVPN-Gateway is working. The key word in the results is "Initialization Sequence Completed". In the cli `>_console` type the following:
```
systemctl status openvpn@vpn-gateway-expressvpn.service

--- Results ---
[root@vpn-gateway ~]# systemctl status openvpn@vpn-gateway-expressvpn.service
● openvpn@vpn-gateway.service - OpenVPN Robust And Highly Flexible Tunneling Application On vpn/gateway
   Loaded: loaded (/usr/lib/systemd/system/openvpn@.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2019-06-02 05:58:23 UTC; 3min 37s ago
 Main PID: 273 (openvpn)
   Status: "Initialization Sequence Completed"
   CGroup: /system.slice/system-openvpn.slice/openvpn@vpn-gateway-expressvpn.service
           └─273 /usr/sbin/openvpn --cd /etc/openvpn/ --config vpn-gateway-expressvpn.conf

Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 ROUTE_GATEWAY 192.168.1.5/255.255.255.0 IFACE=eth0 HWADDR=xx:xx:xx:xx:xx:xx
Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 TUN/TAP device tun0 opened
Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 TUN/TAP TX queue length set to 100
Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 /sbin/ip link set dev tun0 up mtu 1500
Jun 02 05:58:25 vpn-gateway openvpn[287]: Sun Jun  2 05:58:25 2019 /sbin/ip addr add dev tun0 local xxx.xxx.xxx.xx peer xxx.xxx.xxx.xx
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 /sbin/ip route add xxx.xxx.xxx.xxx/32 via 192.168.1.5
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 /sbin/ip route add 0.0.0.0/1 via xxx.xxx.xxx.xx
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 /sbin/ip route add 128.0.0.0/1 via xxx.xxx.xxx.xx
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 /sbin/ip route add xxx.xxx.xxx.xxx/32 via xxx.xxx.xxx.xx
Jun 02 05:58:27 vpn-gateway openvpn[287]: Sun Jun  2 05:58:27 2019 **Initialization Sequence Completed**
```
#### 3.  Some helpful commands.
In the vpn-gateway lxc instance use the cli `>_console` and type the following:

Stop the OpenVPN connection:
```
systemctl stop openvpn@vpn-gateway-expressvpn.service
```
Start the OpenVPN connection:
```
systemctl start openvpn@vpn-gateway-expressvpn.service
```
Get the status of OpenVPN connection:
```
systemctl status openvpn@vpn-gateway-expressvpn.service
```
See your linux Iptables:
```
cat /etc/sysconfig/iptables
```
