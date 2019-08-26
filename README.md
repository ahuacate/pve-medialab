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
- [x] pfSense is fully configured on typhoon-01 including both OpenVPN Gateways VPNGATE-LOCAL and VPNGATE-WORLD.

Tasks to be performed are:
- [ ] 1.0 PiHole LXC - CentOS7
- [ ] 2.0 UniFi Controller - CentOS7
- [ ] 3.0 Jellyfin LXC - CentOS (*Not working*)
- [ ] 4.0 Jellyfin LXC - Ubuntu 18.04

>  **About LXC Installations:**
CentosOS7 is my preferred linux distribution but for media apps its easier to use Ubuntu 18.04 for your LXC containers. Jellyfin, Sonarr and Radarr and alike seem easier to install and configure on Ubuntu 18.04.
Proxmox itself ships a set of basic templates and to download a prebuilt distribution use the graphical interface `typhoon-01` > `local` > `content` > `templates` and select and download `centos-7-default` and `ubuntu-18.04-standard` templates.

## 1.0 PiHole LXC - CentOS7
Here we are going install PiHole which is a internet tracker blocking application which acts as a DNS sinkhole. Basically its charter is to block advertisments, tracking domains, tracking cookies and all those personal data mining collection companies.

### 1.1 Create a CentOS7 LXC for PiHole
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`254`|
| Hostname |`pihole`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template |`centos-7-default_xxxx_amd`|
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`8 GiB`|
| **CPU**
| Cores |`1`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`256`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | Leave Blank
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.1.254/24`|
| Gateway (IPv4) |`192.168.1.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | Leave Default (use host settings)
| DNS servers | Leave Default (use host settings)
| **Confirm**
| Start after Created | `☑`

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
| PiHole automated installer | `<OK>` | *Just hit your ENTER key*
| Free and open source | `<OK>` | *Just hit your ENTER key*
| Static IP Needed | `<OK>` | *Just hit your ENTER key*
| Select UPstream DNS Provider | `Cloudfare` | *And tab key to highlight <OK> and hit your ENTER key*
| Pihole relies on third party .... | Leave Default, all selected | *And tab key to highlight <OK> and hit your ENTER key*
| Select Protocols | Leave default, all selected | *And tab key to highlight <OK> and hit your ENTER key*
| Static IP Address | Leave Default | *It should show IP Address: 192.168.1.254/24, and Gateway: 192.168.1.5. And tab key to highlight <Yes> and hit your ENTER key*
| FYI: IP Conflict | Nothing to do here | *And tab key to highlight <OK> and hit your ENTER key*
| Do you wish to install the web admin interface | `☑` On (Recommended) | *And tab key to highlight <OK> and hit your ENTER key*
| Do you wish to install the web server |  `☑` On (Recommended) | *And tab key to highlight <OK> and hit your ENTER key*
| Do you want to log queries? |  `☑` On (Recommended) | *And tab key to highlight <OK> and hit your ENTER key*
| Select a privacy mode for FTL |  `☑` 0 Show Everything  | *And tab key to highlight <OK> and hit your ENTER key*
| **And the installation script will commence ...**
| Installation Complete | `<OK>` | *Just hit your ENTER key*

Your installation should be complete.

### 1.3 Reset your PiHole webadmin password
Now reset the web admin password using the web interface `Datacenter` > `254 (pihole)` > `>_ Console` run the following command:
```
pihole -a -p
```
You can now login to your PiHole server using your preferred web browser with the following URL http://192.168.1.254/admin/index.php

### 1.4 Enable DNSSEC
You can enable DNSSEC when using Cloudfare which support DNSSEC. Using the PiHole webadmin URL http://192.168.1.254/admin/index.php go to `Settings` > `DNS Tab` and enable `USE DNSSEC` under Advanced DNS Settings. Click `Save`.

---

## 2.0 UniFi Controller - CentOS7
Rather than buy a UniFi Cloud Key to securely run a instance of the UniFi Controller software you can use Proxmox LXC container to host your UniFi Controller software.

For this we will use a CentOS LXC container.

### 2.1 Create a CentOS7 LXC for UniFi Controller
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`251`|
| Hostname |`unifi`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template |`centos-7-default_xxxx_amd`|
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`8 GiB`|
| **CPU**
| Cores |`1`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`1024`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | Leave Blank
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.1.251/24`|
| Gateway (IPv4) |`192.168.1.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | Leave Default (use host settings)
| DNS servers | Leave Default (use host settings)
| **Confirm**
| Start after Created | `☑`

And Click `Finish` to create your UniFi LXC.

Or if you prefer you can simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following to achieve the same thing (note, you will need to create a password for UniFi LXC):
```
pct create 251 local:vztmpl/centos-7-default_20171212_amd64.tar.xz --arch amd64 --cores 1 --hostname unifi --cpulimit 1 --cpuunits 1024 --memory 1024 --net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.1.5,ip=192.168.1.251/24,type=veth --ostype centos --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=1 --password
```

**Note:** test CentOS UniFi package listing is available [HERE](https://community.ui.com/questions/Unofficial-RHEL-CentOS-UniFi-Controller-rpm-packages/a5db143e-e659-4137-af8d-735dfa53e36d).

### 2.2 Install UniFi
First Start your `251 (unifi)` LXC container using the web interface `Datacenter` > `251 (unifi)` > `Start`. Then login into your `251 (unifi)` LXC by going to  `Datacenter` > `251 (unifi)` > `>_ Console and logging in with username `root` and the password you created in the previous step 2.1.

Now using the web interface `Datacenter` > `251 (unifi)` > `>_ Console` run the following command:

```
yum install epel-release -y &&
yum install http://dl.marmotte.net/rpms/redhat/el7/x86_64/unifi-controller-5.8.24-1.el7/unifi-controller-5.8.24-1.el7.x86_64.rpm -y &&
systemctl enable unifi.service &&
systemctl start unifi.service
```

### 2.3 Move the UniFi Controller to your LXC Instance
You can backup the current configuration and move it to a different computer.

Take a backup of the existing controller using the UniFi WebGUI interface and go to `Settings` > `Maintenance` > `Backup` > `Download Backup`. This will create a `xxx.unf` file format to be saved at your selected destination on your PC (i.e Downloads).

Now on your Proxmox UniFi LXC, https://192.168.1.251:8443/ , you must restore the downloaded backup unf file to the new machine by going to `Settings` > `Maintenance` > `Restore` > `Choose File` and selecting the unf file saved on your local PC.

But make sure when you are restoring the backup you Have closed the previous UniFi Controller server and software because you cannot manage the APs by two controller at a time.

---

## 3.0 Jellyfin LXC - Ubuntu 18.04
>  This 100% works. 

Jellyfin is an alternative to the proprietary Emby and Plex, to provide media from a dedicated server to end-user devices via multiple apps. 

Jellyfin is descended from Emby's 3.5.2 release and ported to the .NET Core framework to enable full cross-platform support. There are no strings attached, no premium licenses or features, and no hidden agendas: and at the time of writing this media server software seems like the best available solution (and is free).

### 3.1 Download the Ubuntu LXC template - Ubuntu 18.04
First you need to add Ubuntu 18.04 LXC to your Proxmox templates. Now using the Proxmox web interface `Datacenter` > `typhoon-01` >`Local (typhoon-01)` > `Content` > `Templates`  select `ubuntu-18.04-standard` LXC and click `Download`.

Or use a Proxmox typhoon-01 CLI `>_ Shell` and type the following:
```
wget  http://download.proxmox.com/images/system/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz -P /var/lib/vz/template/cache && gzip -d /var/lib/vz/template/cache/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz
```

### 3.2 Create a Ubuntu 18.04 LXC for Jellyfin - Ubuntu 18.04
Now using the Proxmox web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`111`|
| Hostname |`jellyfin`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template |`ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz`|
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`20 GiB`|
| **CPU**
| Cores |`2`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`4096`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | `50`
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.50.111/24`|
| Gateway (IPv4) |`192.168.50.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | Leave Default (use host settings)
| DNS servers | Leave Default (use host settings)
| **Confirm**
| Start after Created | `☐`

And Click `Finish` to create your JellyFin LXC. The above will create the Jellyfin LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Jellyfin LXC):

**Script (A):** Including LXC Mount Points
```
pct create 111 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname jellyfin --cpulimit 1 --cpuunits 1024 --memory 4096 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.111/24,type=veth --ostype centos --rootfs typhoon-share:20 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music --mp1 /mnt/pve/cyclone-01-photo,mp=/mnt/photo --mp2 /mnt/pve/cyclone-01-transcode,mp=/mnt/transcode --mp3 /mnt/pve/cyclone-01-video,mp=/mnt/video
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 111 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname jellyfin --cpulimit 1 --cpuunits 1024 --memory 4096 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.111/24,type=veth --ostype centos --rootfs typhoon-share:20 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 3.3 Configure and Install VAAPI - Ubuntu 18.04
> This section only applies to Proxmox nodes typhoon-01 and typhoon-02. **DO NOT USE ON TYPHOON-03** or any Synology/NAS Virtual Machine installed node.

Jellyfin supports hardware acceleration of video encoding/decoding/transcoding using FFMpeg. Because we are using Linux we will use Intel/AMD VAAPI.

But first you must configure VAAPI for your host system. VAAPI is configured for typhoon-01 and tyhoon-02 only because the machine hardware supports video encoding.

Your Jellyfin LXC **MUST BE** in the shutdown state before proceeding.

First verify that `render` device is present in `/dev/dri`, and note the permissions and group available to write to it, in this case `render`. Simply use Proxmox CLI `Datacenter` > `typhoon-01/02` >  `>_ Shell` and type the following first line only:

```
ls -l /dev/dri

# Results ...
total 0
crw-rw---- 1 root video 226,   0 Jul 26 14:24 card0
crw-rw---- 1 root video 226, 128 Jul 26 14:24 renderD128
```
**Note:** On some releases, the group may be `video` instead of `render`.

Now you want to install VAINFO on Proxmox nodes typhoon-01 and typhoon-02. Go to Proxmox CLI `Datacenter` > `typhoon-01/02` >  `>_ Shell` and type the following:
```
apt install vainfo -y &&
chmod 666 /dev/dri/renderD128
```

To validate your installation go to Proxmox CLI `Datacenter` > `typhoon-01/02` >  `>_ Shell` and type `vainfo` and the results should be similiar to whats shown below:
```
@typhoon-01:~# vainfo
error: XDG_RUNTIME_DIR not set in the environment.
error: can't connect to X server!
libva info: VA-API version 0.39.4
libva info: va_getDriverName() returns 0
libva info: Trying to open /usr/lib/x86_64-linux-gnu/dri/i965_drv_video.so
libva info: Found init function __vaDriverInit_0_39
libva info: va_openDriver() returns 0
vainfo: VA-API version: 0.39 (libva 1.7.3)
vainfo: Driver version: Intel i965 driver for Intel(R) Kabylake - 1.7.3
vainfo: Supported profile and entrypoints
      VAProfileMPEG2Simple            : VAEntrypointVLD
      VAProfileMPEG2Simple            : VAEntrypointEncSlice
      VAProfileMPEG2Main              : VAEntrypointVLD
      VAProfileMPEG2Main              : VAEntrypointEncSlice
      VAProfileH264ConstrainedBaseline: VAEntrypointVLD
      VAProfileH264ConstrainedBaseline: VAEntrypointEncSlice
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointEncSlice
      VAProfileH264High               : VAEntrypointVLD
      VAProfileH264High               : VAEntrypointEncSlice
      VAProfileH264MultiviewHigh      : VAEntrypointVLD
      VAProfileH264MultiviewHigh      : VAEntrypointEncSlice
      VAProfileH264StereoHigh         : VAEntrypointVLD
      VAProfileH264StereoHigh         : VAEntrypointEncSlice
      VAProfileVC1Simple              : VAEntrypointVLD
      VAProfileVC1Main                : VAEntrypointVLD
      VAProfileVC1Advanced            : VAEntrypointVLD
      VAProfileNone                   : VAEntrypointVideoProc
      VAProfileJPEGBaseline           : VAEntrypointVLD
      VAProfileJPEGBaseline           : VAEntrypointEncPicture
      VAProfileVP8Version0_3          : VAEntrypointVLD
      VAProfileVP8Version0_3          : VAEntrypointEncSlice
      VAProfileHEVCMain               : VAEntrypointVLD
      VAProfileHEVCMain               : VAEntrypointEncSlice
      VAProfileHEVCMain10             : VAEntrypointVLD
      VAProfileHEVCMain10             : VAEntrypointEncSlice
      VAProfileVP9Profile0            : VAEntrypointVLD
      VAProfileVP9Profile0            : VAEntrypointEncSlice
      VAProfileVP9Profile2            : VAEntrypointVLD
```
### 3.4 Create a rc.local
For FFMPEG to work we must create a script to `chmod 666 /dev/dri/renderD128` everytime the Proxmox host reboots. Now using the web interface go to Proxmox CLI `Datacenter` > `typhoon-01/02` >  `>_ Shell` and type the following:
```
echo '#!/bin/sh -e
/bin/chmod 666 /dev/dri/renderD128
exit 0' > /etc/rc.local &&
chmod +x /etc/rc.local &&
bash /etc/rc.local
```

### 3.5 Grant Jellyfin LXC Container access to the Proxmox host video device - Ubuntu 18.04
> This section only applies to Proxmox nodes typhoon-01 and typhoon-02. **DO NOT USE ON TYPHOON-03** or any Synology/NAS Virtual Machine installed node.

Here we edit the LXC configuration file with the line `lxc.cgroup.devices.allow` to declare your hardmetal GPU device to your Jellyfin LXC container so it can access your hosts GPU.

The command `lxc.cgroup.devices.allow: c 226:128 rwm` means its allowing Jellyfin LXC container to rwm (read/write/mount) your GPU device (Proxmox host) which has the major number of 226 and minor number of 128.

Granting the permission alone is not enough if the device is not present in Jellyfins LXC container's /dev directory. The second step is create corresponding mount points in the LXC container to your hosts /dev/dri/renderD128 folder.

Please note your Proxmox Jellyfin LXC **MUST BE** in the shutdown state before proceeding.

Now using the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` >  `>_ Shell` and type the following:

```
echo -e "lxc.cgroup.devices.allow = c 226:128 rwm
lxc.cgroup.devices.allow = c 226:0 rwm
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file" >> /etc/pve/lxc/111.conf
```

### 3.6 Install Jellyfin - Ubuntu 18.04
This is easy. First start LXC 111 (jellyfin) with the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `>_ Shell` and type the following:

```
sudo apt update -y &&
sudo apt install apt-transport-https &&
sudo apt install gnupg gnupg2 gnupg1 -y &&
wget -O - https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | sudo apt-key add - &&
echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/ubuntu $( lsb_release -c -s ) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list &&
sudo apt update -y &&
sudo apt install jellyfin -y &&
sudo systemctl restart jellyfin
```

### 3.7 Setup Jellyfin Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 3.2 then you have no Moint Points.

Please note your Proxmox Jellyfin LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 111 -mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music &&
pct set 111 -mp1 /mnt/pve/cyclone-01-photo,mp=/mnt/photo &&
pct set 111 -mp2 /mnt/pve/cyclone-01-transcode,mp=/mnt/transcode &&
pct set 111 -mp3 /mnt/pve/cyclone-01-video,mp=/mnt/video
```

### 3.8 Check your Jellyfin Installation
In your web browser type `http://192.168.50.111:8096` and you should see a Jellyfin configuration wizard page.

---

## 4.0 NZBget LXC - Ubuntu 18.04
NZBGet is a binary downloader, which downloads files from Usenet based on information given in nzb-files.

NZBGet is written in C++ and is known for its extraordinary performance and efficiency.

### 4.1 Download the Ubuntu LXC template - Ubuntu 18.04
First you need to add Ubuntu 18.04 LXC to your Proxmox templates if you have'nt already done so. Now using the Proxmox web interface `Datacenter` > `typhoon-01` >`Local (typhoon-01)` > `Content` > `Templates`  select `ubuntu-18.04-standard` LXC and click `Download`.

Or use a Proxmox typhoon-01 CLI `>_ Shell` and type the following:
```
wget  http://download.proxmox.com/images/system/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz -P /var/lib/vz/template/cache && gzip -d /var/lib/vz/template/cache/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz
```

### 4.2 Create a Ubuntu 18.04 LXC for NZBget - Ubuntu 18.04
Now using the Proxmox web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`112`|
| Hostname |`nzbget`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template |`ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz`|
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`8 GiB`|
| **CPU**
| Cores |`2`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`2048`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | `30`
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.30.112/24`|
| Gateway (IPv4) |`192.168.30.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | `192.168.30.5`
| DNS servers | `192.168.30.5`
| **Confirm**
| Start after Created | `☐`

And Click `Finish` to create your NZBget LXC. The above will create the NZBget LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Jellyfin LXC):

**Script (A):** Including LXC Mount Points
```
pct create 112 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname nzbget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.112/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /typhoon-share/downloads,mp=/mnt/downloads
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 112 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname nzbget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.112/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 4.3 Setup NZBget Mount Points - Ubuntu 18.04

If you used Script (B) in Section 4.2 then you have no Moint Points.

Please note your Proxmox NZBget LXC MUST BE in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
pct set 112 -mp0 /typhoon-share/downloads,mp=/mnt/downloads
```

### 4.4 Install NZBget - Ubuntu 18.04
This is easy. First start LXC 112 (nzbget) with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:

```
sudo mkdir /mnt/downloads/nzbget /mnt/downloads/nzbget/nzb /mnt/downloads/nzbget/queue /mnt/downloads/nzbget/tmp /mnt/downloads/nzbget/intermediate /mnt/downloads/nzbget/completed &&
wget https://nzbget.net/download/nzbget-latest-bin-linux.run -P /tmp &&
sh /tmp/nzbget-latest-bin-linux.run --destdir /opt/nzbget &&
rm /tmp/nzbget-latest-bin-linux.run
```

### 4.5 Edit NZBget confifuration file - Ubuntu 18.04
The NZBGET configuration file needs to have its default download location changed to your ZFS typhoon-share downloads folder. NZBGET default variable on the nzbget.conf file is set to `MainDir=${AppDir}/downloads` which we need to change to `MainDir=/mnt/downloads/nzbget`.

Then with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:

```
sed -i 's|MainDir=${AppDir}/downloads|MainDir=/mnt/downloads/nzbget|g' /opt/nzbget/nzbget.conf
```

### 4.6 Create NZBget Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=NZBGet Daemon
Documentation=http://nzbget.net/Documentation
After=network.target

[Service]
User=root
Group=root
Type=forking
ExecStart=/opt/nzbget/nzbget -D
ExecStop=/opt/nzbget/nzbget -Q
ExecReload=/opt/nzbget/nzbget -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/nzbget.service &&
sudo systemctl enable nzbget &&
sudo systemctl start nzbget
```

### 4.7 Setup NZBget 
Browse to http://192.168.50.112:6789 to start using NZBget. Your NZBget default login details are (login:nzbget, password:tegbzn6789). Instructions to setup NZBget are [HERE]

---

## 5.0 Deluge LXC - Ubuntu 18.04
Deluge is a lightweight, Free Software, cross-platform BitTorrent client. I also install Jacket in this LXC container.

### 5.1 Download the Ubuntu LXC template - Ubuntu 18.04
First you need to add Ubuntu 18.04 LXC to your Proxmox templates if you have'nt already done so. Now using the Proxmox web interface `Datacenter` > `typhoon-01` >`Local (typhoon-01)` > `Content` > `Templates`  select `ubuntu-18.04-standard` LXC and click `Download`.

Or use a Proxmox typhoon-01 CLI `>_ Shell` and type the following:
```
wget  http://download.proxmox.com/images/system/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz -P /var/lib/vz/template/cache && gzip -d /var/lib/vz/template/cache/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz
```

### 5.2 Create a Ubuntu 18.04 LXC for Deluge - Ubuntu 18.04
Now using the Proxmox web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`113`|
| Hostname |`deluge`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template |`ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz`|
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`8 GiB`|
| **CPU**
| Cores |`2`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`2048`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | `30`
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.30.113/24`|
| Gateway (IPv4) |`192.168.30.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | `192.168.30.5`
| DNS servers | `192.168.30.5`
| **Confirm**
| Start after Created | `☐`

And Click `Finish` to create your Deluge LXC. The above will create the Deluge LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Deluge LXC):

**Script (A):** Including LXC Mount Points
```
pct create 113 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname deluge --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.113/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /typhoon-share/downloads,mp=/mnt/downloads
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 113 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname deluge --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.113/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 5.3 Setup Deluge & Jacket Mount Points - Ubuntu 18.04

If you used Script (B) in Section 5.2 then you have no Moint Points.

Please note your Proxmox Deluge LXC MUST BE in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
pct set 113 -mp0 /typhoon-share/downloads,mp=/mnt/downloads
```

### 5.4 Install Deluge - Ubuntu 18.04
This is easy. First start LXC 113 (deluge) with the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
mkdir -m777 -p {/mnt/downloads/deluge/incomplete,/mnt/downloads/deluge/complete}  &&
sudo chown -R root:root /mnt/downloads/deluge/incomplete /mnt/downloads/deluge/complete &&
sudo apt-get update &&
sudo apt install software-properties-common -y &&
sudo add-apt-repository ppa:deluge-team/stable -y &&
sudo apt-get update &&
sudo apt-get install deluged deluge-webui -y
```
At the prompt `Configuring libssl1.1:amd64` select `<Yes>`.

Then create the deluge user and group so that deluge can run as an unprivileged user, which will increase your server’s security.
```
sudo adduser --system --group deluge
```
The --system flag means we are creating a system user instead of normal user. A system user doesn’t have password and can’t login, which is what you would want for Deluge. A home directory /home/deluge/ will be created for this user. You may want to add your user account to the deluge group with the following command so that the user account has access to the files downloaded by Deluge BitTorrent. Files are downloaded to /home/deluge/Downloads by default. Note that you need to re-login for the groups change to take effect.

```
sudo gpasswd -a root deluge &&
sudo gpasswd -a deluge root
```

### 5.5 Create Deluge Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Deluge Client Daemon
Documentation=https://dev.deluge-torrent.org/
After=network-online.target

[Service]
User=deluge
Group=deluge
Type=simple
Umask=007
ExecStart=/usr/bin/deluged -d
KillMode=process
Restart=on-failure

# Configures the time to wait before service is stopped forcefully.
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/deluge.service &&
sudo systemctl enable deluge &&
sudo systemctl start deluge
```

### 5.6 Create Deluge WebGUI Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Deluge Bittorrent Client Web Interface
Documentation=https://dev.deluge-torrent.org/
After=network-online.target deluge.service
Wants=deluge.service


[Service]
User=deluge
Group=deluge

Type=simple
Umask=027
ExecStart=/usr/bin/deluge-web -d
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/deluge-web.service &&
sudo systemctl enable deluge-web &&
sudo systemctl restart deluge-web
```

### 5.6 Setup Deluge 
Browse to http://192.168.30.113:8112 to start using NZBget. Your Deluge default login details are password:deluge. Instructions to setup Deluge are [HERE]

---

## 6.0 Jackett LXC - Ubuntu 18.04
Jackett works as a proxy server: it translates queries from apps (Sonarr, Radarr, Lidarr etc) into tracker-site-specific http queries, parses the html response, then sends results back to the requesting software. This allows for getting recent uploads (like RSS) and performing searches. Jackett is a single repository of maintained indexer scraping & translation logic - removing the burden from other apps.

This is installed on the Deluge LXC container.

### 6.1 Install Jackett - Ubuntu 18.04
This is easy. First start LXC 113 (deluge) with the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
sudo apt install python-urllib3 python3-openssl -y &&
sudo apt install curl -y &&
cd /opt &&
sudo curl -L -O $( curl -s https://api.github.com/repos/Jackett/Jackett/releases | grep Jackett.Binaries.LinuxAMDx64.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) &&
tar zxvf /opt/Jackett.Binaries.LinuxAMDx64.tar.gz &&
sudo rm /opt/Jackett.Binaries.LinuxAMDx64.tar.gz
```

### 6.2 Create Jackett Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Jackett Daemon
After=network.target

[Service]
SyslogIdentifier=jackett
Restart=always
RestartSec=5
Type=simple
User=deluge
Group=deluge
WorkingDirectory=/opt/Jackett
ExecStart=/opt/Jackett/jackett --NoRestart
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/jackett.service &&
sudo systemctl enable jackett &&
sudo systemctl start jackett
```

### 6.3 Setup Jackett 
Browse to http://192.168.30.113:9117 to start using Jackett.

---

## 7.0 Flexget LXC - Ubuntu 18.04
Under Development.

---

## 8.0 Sonarr LXC - Ubuntu 18.04
Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

### 8.1 Create a Ubuntu 18.04 LXC for Sonarr
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`115`|
| Hostname |`sonarr`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template | `ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz` |
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`10 GiB`|
| **CPU**
| Cores |`1`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`2048`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | `50`
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.50.115/24`|
| Gateway (IPv4) |`192.168.50.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | Leave Default (use host settings)
| DNS servers | Leave Default (use host settings)
| **Confirm**
| Start after Created | `☐`

And Click `Finish` to create your Sonarr LXC. The above will create the Sonarr LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Sonarr LXC):

**Script (A):** Including LXC Mount Points
```
pct create 115 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname sonarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.115/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp1 /typhoon-share/downloads,mp=/mnt/downloads --mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 115 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname sonarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.115/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 8.2 Setup Sonarr Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 8.1 then you have no Moint Points.

Please note your Proxmox Sonarr LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 115 -mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video &&
pct set 115 -mp1 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 115 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

### 8.3 Install Sonarr
Th following Sonarr installation recipe is from the official Sonarr website [HERE](https://sonarr.tv/#downloads-v3-linux-ubuntu). Please refer for the latest updates.

During the installation, you will be asked which user and group Sonarr must run as. It's important to choose these correctly to avoid permission issues with your media files. I suggest you keep at least the group named `homelab` and username `storm` identical between your download client(s) and Sonarr. 

First start your Sonarr LXC and login. Then go to the Proxmox web interface `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:

```
sudo apt-get update -y &&
sudo apt install gnupg ca-certificates -y &&
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &&
sudo echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list &&
sudo apt update -y &&
sudo apt install mono-devel -y &&
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0xA236C58F409091A18ACA53CBEBFF6B99D9B78493 &&
echo "deb http://apt.sonarr.tv/ master main" | sudo tee /etc/apt/sources.list.d/sonarr.list &&
sudo apt update -y &&
sudo apt install nzbdrone -y &&
sudo chown -R root:root /opt/NzbDrone
```

### 8.4 Create Sonarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:
```
sudo echo -e "[Unit]
Description=Sonarr Daemon
After=network.target

[Service]
User=root
Group=root

Type=simple

# Change the path to Radarr or mono here if it is in a different location for you.
ExecStart=/usr/bin/mono --debug /opt/NzbDrone/NzbDrone.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/sonarr.service &&
sudo systemctl enable sonarr.service &&
sudo systemctl start sonarr.service &&
sudo reboot
```
### 8.5 Setup Sonarr
Browse to http://192.168.50.115:8989 to start using Sonarr.

---

## 9.0 Radarr LXC - Ubuntu 18.04
Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

### 9.1 Create a Ubuntu 18.04 LXC for Radarr
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`116`|
| Hostname |`radarr`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template | `ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz` |
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`10 GiB`|
| **CPU**
| Cores |`1`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`2048`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | `50`
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.50.116/24`|
| Gateway (IPv4) |`192.168.50.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | Leave Default (use host settings)
| DNS servers | Leave Default (use host settings)
| **Confirm**
| Start after Created | `☐`

And Click `Finish` to create your Radarr LXC. The above will create the Radarr LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Radarr LXC):

**Script (A):** Including LXC Mount Points
```
pct create 116 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname radarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.116/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp1 /typhoon-share/downloads,mp=/mnt/downloads --mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 116 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname radarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.116/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 9.2 Setup Radarr Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 9.1 then you have no Moint Points.

Please note your Proxmox Radarr LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 116 -mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video &&
pct set 116 -mp1 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 116 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

### 9.3 Install Radarr
First start your Radarr LXC and login. Then go to the Proxmox web interface `typhoon-01` > `116 (radarr)` > `>_ Shell` and insert by cut & pasting the following:

```
sudo apt-get update -y &&
sudo apt install gnupg ca-certificates -y &&
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &&
echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list &&
sudo apt update -y &&
sudo apt install mono-devel curl -y &&
cd /opt &&
sudo curl -L -O $( curl -s https://api.github.com/repos/Radarr/Radarr/releases | grep linux.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) &&
sudo tar -xvzf Radarr.develop.*.linux.tar.gz &&
sudo rm *.linux.tar.gz &&
sudo chown -R root:root /opt/Radarr
```
### 9.4 Create Radarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
# Change the user and group variables here.
User=root
Group=root

Type=simple

# Change the path to Radarr or mono here if it is in a different location for you.
ExecStart=/usr/bin/mono --debug /opt/Radarr/Radarr.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/radarr.service &&
sudo systemctl enable radarr.service &&
sudo systemctl start radarr.service &&
sudo reboot
```

### 9.5 Setup Radarr
Browse to http://192.168.50.116:7878 to start using Radarr.

---

## 10.0 Lidarr LXC - Ubuntu 18.04
Lidarr is a music collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new tracks from your favorite artists and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

### 10.1 Create a Ubuntu 18.04 LXC for Lidarr
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`117`|
| Hostname |`lidarr`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template | `ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz` |
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`10 GiB`|
| **CPU**
| Cores |`1`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`2048`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | `50`
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.50.117/24`|
| Gateway (IPv4) |`192.168.50.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | Leave Default (use host settings)
| DNS servers | Leave Default (use host settings)
| **Confirm**
| Start after Created | `☐`

And Click `Finish` to create your Lidarr LXC. The above will create the Lidarr LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Lidarr LXC):

**Script (A):** Including LXC Mount Points
```
pct create 117 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname lidarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.117/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music --mp1 /typhoon-share/downloads,mp=/mnt/downloads --mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 117 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname lidarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.117/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 10.2 Setup Lidarr Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 10.1 then you have no Moint Points.

Please note your Proxmox Radarr LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 117 -mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music &&
pct set 117 -mp1 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 117 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

### 10.3 Install Lidarr
First start your Lidarr LXC and login. Then go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and insert by cut & pasting the following:

```
sudo apt-get update -y &&
sudo apt install gnupg ca-certificates -y &&
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &&
echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list &&
sudo apt update -y &&
sudo apt install mono-devel curl -y &&
cd /opt &&
sudo curl -L -O $( curl -s https://api.github.com/repos/lidarr/Lidarr/releases | grep linux.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) &&
sudo tar -xvzf Lidarr.develop.*.linux.tar.gz &&
sudo rm *.linux.tar.gz &&
sudo chown -R root:root /opt/Lidarr
```
### 10.4 Create Lidarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Lidarr Daemon
After=network.target

[Service]
# Change the user and group variables here.
User=root
Group=root

Type=simple

# Change the path to Radarr or mono here if it is in a different location for you.
ExecStart=/usr/bin/mono --debug /opt/Lidarr/Lidarr.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/lidarr.service &&
sudo systemctl enable lidarr.service &&
sudo systemctl start lidarr.service &&
sudo reboot
```

### 10.5 Setup Lidarr
Browse to http://192.168.50.117:8686 to start using Lidarr.

---

## 11.0 Lazylibrarian LXC - Ubuntu 18.04
LazyLibrarian is a program available for Linux that is used to follow authors and grab metadata for all your digital reading needs. It uses a combination of Goodreads Librarything and optionally GoogleBooks as sources for author info and book info. It’s nice to be able to have all of our book in digital form since books are extremely heavy and take up a lot of space, which we are already lacking in the bus.

### 11.1 Create a Ubuntu 18.04 LXC for Lazylibrarian
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`1178`|
| Hostname |`lazy`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template | `ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz` |
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`10 GiB`|
| **CPU**
| Cores |`1`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`1024`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | `50`
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.50.118/24`|
| Gateway (IPv4) |`192.168.50.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | Leave Default (use host settings)
| DNS servers | Leave Default (use host settings)
| **Confirm**
| Start after Created | `☐`

And Click `Finish` to create your Lazylibrarian LXC. The above will create the Lazylibrarian LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Lazylibrarian LXC):

**Script (A):** Including LXC Mount Points
```
pct create 118 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname lazy --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.118/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-audio,mp=/mnt/audio --mp1 /mnt/pve/cyclone-01-books,mp=/mnt/books --mp2 /typhoon-share/downloads,mp=/mnt/downloads --mp3 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 118 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname lazy --cpulimit 1 --cpuunits 1024 --memory 1024 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.118/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 11.2 Setup Lazylibrarian Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 11.1 then you have no Moint Points.

Please note your Proxmox Lazylibrarian (lazy) LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 118 -mp0 /mnt/pve/cyclone-01-audio,mp=/mnt/audio &&
pct set 118 -mp1 /mnt/pve/cyclone-01-books,mp=/mnt/books
pct set 118 -mp2 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 118 -mp3 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

### 11.3 Install Lazylibrarian
First start your Lazylibrarian LXC and login. Then go to the Proxmox web interface `typhoon-01` > `118 (lazy)` > `>_ Shell` and insert by cut & pasting the following:

```
sudo apt-get update -y &&
sudo apt-get install git-core python3 -y &&
cd /opt &&
sudo git clone https://gitlab.com/LazyLibrarian/LazyLibrarian.git
```
### 11.4 Create Lazylibrarian Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `118 (lazy)` > `>_ Shell` and type the following:
```
sudo echo -e "[Unit]
Description=LazyLibrarian

[Service]
ExecStart=/usr/bin/python3 /opt/LazyLibrarian/LazyLibrarian.py --daemon --config /opt/LazyLibrarian/lazylibrarian.ini --datadir /opt/LazyLibrarian/.lazylibrarian --nolaunch --quiet
GuessMainPID=no
Type=forking
User=root
Group=root
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/lazy.service &&
sudo systemctl enable lazy.service
sudo systemctl restart lazy.service &&
sudo reboot
```

### 11.5 Setup Lazylibrarian
Browse to http://192.168.50.118:5299 to start using Lazylibrarian (aka lazy).

