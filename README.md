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

Or if you prefer you can simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following to achieve the same thing (note, you will need to create a password for PiHole LXC):
```
pct create 254 local:vztmpl/centos-7-default_20171212_amd64.tar.xz --arch amd64 --cores 1 --hostname pihole --cpulimit 1 --cpuunits 1024 --memory 256 --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.1.5,ip=192.168.1.254/24,type=veth --ostype centos --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=1 --password
```

### 1.2 Install PiHole
First Start your `254 (pihole)` LXC container using the web interface `Datacenter` > `254 (pihole)` > `Start`. Then login into your `254 (pihole)` LXC by going to  `Datacenter` > `254 (pihole)` > `>_ Console and logging in with username `root` and the password you created in the previous step 1.1.

Now using the web interface `Datacenter` > `254 (pihole)` > `>_ Console` run the following command:
```
curl -sSL https://install.pi-hole.net | bash
```
The PiHole installation package will download and the installation will commence. Follow the prompts making sure to enter the prompts and field values as follows:

| PiHole Installation | Value | Notes
| :---  | :---: | :--- |
| `PiHole automated installer` | <OK> | *Just hit your ENTER key*
| `Free and open source` | <OK> | *Just hit your ENTER key*
| `Static IP Needed` | <OK> | *Just hit your ENTER key*
| `Select UPstream DNS Provider` | Cloudfare | *And tab key to highlight <OK> and hit your ENTER key*
| `Pihole relies on third party ....` | Leave Default, all selected | *And tab key to highlight <OK> and hit your ENTER key*
| `Select Protocols` | Leave default, all selected | *And tab key to highlight <OK> and hit your ENTER key*
| `Static IP Address` | Leave Default | *It should show IP Address: 192.168.1.254/24, and Gateway: 192.168.1.5. And tab key to highlight <Yes> and hit your ENTER key*
| `FYI: IP Conflict` | Nothing to do here | *And tab key to highlight <OK> and hit your ENTER key*
| `Do you wish to install the web admin interface` | [x] On (Recommended) | *And tab key to highlight <OK> and hit your ENTER key*
| `Do you wish to install the web server` |  [x] On (Recommended) | *And tab key to highlight <OK> and hit your ENTER key*
| `Do you want to log queries?` |  [x] On (Recommended) | *And tab key to highlight <OK> and hit your ENTER key*
| `Select a privacy mode for FTL` |  [x] 0 Show Everything  | *And tab key to highlight <OK> and hit your ENTER key*
| **And the installation script will commence ...**
| `Installation Complete` | <OK> | *Just hit your ENTER key*

Your installation should be complete.

### 1.3 Reset your PiHole webadmin password
Now reset the web admin password using the web interface `Datacenter` > `254 (pihole)` > `>_ Console` run the following command:
```
pihole -a -p
```
You can now login to your PiHole server using your preferred web browser with the following URL http://192.168.1.254/admin/index.php

### 1.4 Enable DNSSEC
You can enable DNSSEC when using Cloudfare which support DNSSEC. Using the PiHole webadmin URL http://192.168.1.254/admin/index.php go to `Settings` > `DNS Tab` and enable `USE DNSSEC` under Advanced DNS Settings. Click `Save`.

## 2.0 UniFi Controller - CentOS7

