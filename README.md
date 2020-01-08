# Proxmox-LXC-Media
The following is for creating our Media family of LXC containers.

Network Prerequisites are:
- [x] Layer 2 Network Switches
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5` (Note: your Gateway hardware should enable you to a configure DNS server(s), like a UniFi USG Gateway, so set the following: primary DNS `192.168.1.254` which will be your PiHole server IP address; and, secondary DNS `1.1.1.1` which is a backup Cloudfare DNS server in the event your PiHole server 192.168.1.254 fails or is down)
- [x] Network DHCP server is `192.168.1.5`
- [x] A DDNS service is fully configured and enabled (I recommend you use the free Synology DDNS service)
- [x] A ExpressVPN account (or any preferred VPN provider) is valid and its smart DNS feature is working (public IP registration is working with your DDNS provider)

Other Prerequisites are:
- [x] Synology NAS, or linux variant of a NAS, is fully configured as per [SYNOBUILD](https://github.com/ahuacate/synobuild#synobuild)
- [x] Proxmox node fully configured as per [PROXMOX-NODE BUILDING](https://github.com/ahuacate/proxmox-node/blob/master/README.md#proxmox-node-building)
- [x] pfSense is fully configured on typhoon-01 including both OpenVPN Gateways VPNGATE-LOCAL and VPNGATE-WORLD.

Tasks to be performed are:
- [About LXC Media Installations](#about-lxc-media-installations)
- [1.00 Unprivileged LXC Containers and file permissions](#100-unprivileged-lxc-containers-and-file-permissions)
	- [1.01 Unprivileged container mapping - medialab](#101-unprivileged-container-mapping---medialab)
	- [1.02 Allow a LXC to perform mapping on the Proxmox host - medialab](#102-allow-a-lxc-to-perform-mapping-on-the-proxmox-host---medialab)
	- [1.03 Create a newuser `media` in a LXC](#103-create-a-newuser-media-in-a-lxc)
- [2.00 Jellyfin LXC - Ubuntu 18.04](#200-jellyfin-lxc---ubuntu-1804)
	- [2.01 Download the Ubuntu LXC template - Ubuntu 18.04](#201-download-the-ubuntu-lxc-template---ubuntu-1804)
	- [2.02 Create a Ubuntu 18.04 LXC for Jellyfin - Ubuntu 18.04](#202-create-a-ubuntu-1804-lxc-for-jellyfin---ubuntu-1804)
	- [2.03 Setup Jellyfin Mount Points - Ubuntu 18.04](#203-setup-jellyfin-mount-points---ubuntu-1804)
	- [2.04 Unprivileged container mapping - Ubuntu 18.04](#204-unprivileged-container-mapping---ubuntu-1804)
	- [2.05 Configure and Install VAAPI - Ubuntu 18.04](#205-configure-and-install-vaapi---ubuntu-1804)
	- [2.06 Create a rc.local](#206-create-a-rclocal)
	- [2.07 Grant Jellyfin LXC Container access to the Proxmox host video device - Ubuntu 18.04](#207-grant-jellyfin-lxc-container-access-to-the-proxmox-host-video-device---ubuntu-1804)
	- [2.08 Ubuntu fix to avoid prompt to restart services during "apt apgrade"](#208-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade)
	- [2.09 Install Jellyfin - Ubuntu 18.04](#209-install-jellyfin---ubuntu-1804)
	- [2.10 Create and edit user groups- Ubuntu 18.04](#210-create-and-edit-user-groups--ubuntu-1804)
		- [2.10a Option A](#210a-option-a)
		- [2.10b Option B](#210b-option-b)
	- [2.11 Start Jellyfin - Ubuntu 18.04](#211-start-jellyfin---ubuntu-1804)
	- [2.12 Setup your Jellyfin Installation](#212-setup-your-jellyfin-installation)
- [3.00 NZBget LXC - Ubuntu 18.04](#300-nzbget-lxc---ubuntu-1804)
	- [3.01 Download the Ubuntu LXC template - Ubuntu 18.04](#301-download-the-ubuntu-lxc-template---ubuntu-1804)
	- [3.02 Create a Ubuntu 18.04 LXC for NZBget - Ubuntu 18.04](#302-create-a-ubuntu-1804-lxc-for-nzbget---ubuntu-1804)
	- [3.03 Setup NZBget Mount Points - Ubuntu 18.04](#303-setup-nzbget-mount-points---ubuntu-1804)
	- [3.04 Unprivileged container mapping - Ubuntu 18.04](#304-unprivileged-container-mapping---ubuntu-1804)
	- [3.05 Create NZBGet download folders on your ZFS typhoon-share - Ubuntu 18.04](#305-create-nzbget-download-folders-on-your-zfs-typhoon-share---ubuntu-1804)
	- [3.06 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04](#306-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade---ubuntu-1804)
	- [3.07 Container Update &  Upgrade - Ubuntu 18.04](#307-container-update---upgrade---ubuntu-1804)
	- [3.07 Create new "media" user - Ubuntu 18.04](#307-create-new-media-user---ubuntu-1804)
	- [3.07 Install NZBget - Ubuntu 18.04](#307-install-nzbget---ubuntu-1804)
	- [3.08 Edit NZBget configuration file - Ubuntu 18.04](#308-edit-nzbget-configuration-file---ubuntu-1804)
	- [3.09 Create NZBget Service file - Ubuntu 18.04](#309-create-nzbget-service-file---ubuntu-1804)
	- [3.10 Setup NZBget](#310-setup-nzbget)
- [4.00 Deluge LXC - Ubuntu 18.04](#400-deluge-lxc---ubuntu-1804)
	- [4.01 Download the Ubuntu LXC template - Ubuntu 18.04](#401-download-the-ubuntu-lxc-template---ubuntu-1804)
	- [4.02 Create a Ubuntu 18.04 LXC for Deluge - Ubuntu 18.04](#402-create-a-ubuntu-1804-lxc-for-deluge---ubuntu-1804)
	- [4.03 Setup Deluge & Jacket Mount Points - Ubuntu 18.04](#403-setup-deluge--jacket-mount-points---ubuntu-1804)
	- [4.04 Unprivileged container mapping - Ubuntu 18.04](#404-unprivileged-container-mapping---ubuntu-1804)
	- [4.05 Create Deluge download folders on your ZFS typhoon-share - Ubuntu 18.04](#405-create-deluge-download-folders-on-your-zfs-typhoon-share---ubuntu-1804)
	- [4.06 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04](#406-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade---ubuntu-1804)
	- [4.07 Container Update &  Upgrade - Ubuntu 18.04](#407-container-update---upgrade---ubuntu-1804)
	- [4.08 Create new "media" user - Ubuntu 18.04](#408-create-new-media-user---ubuntu-1804)
	- [4.09 Configuring host machine locales - Ubuntu 18.04](#409-configuring-host-machine-locales---ubuntu-1804)
	- [4.10 Install Deluge - Ubuntu 18.04](#410-install-deluge---ubuntu-1804)
	- [4.11 Download Deluge Plugins and settings files - Ubuntu 18.04](#411-download-deluge-plugins-and-settings-files---ubuntu-1804)
	- [4.12 Create Deluge Service file - Ubuntu 18.04](#412-create-deluge-service-file---ubuntu-1804)
	- [4.13 Final Configuring of Deluge - Ubuntu 18.04](#413-final-configuring-of-deluge---ubuntu-1804)
	- [4.14 Create Deluge WebGUI Service file - Ubuntu 18.04](#414-create-deluge-webgui-service-file---ubuntu-1804)
	- [4.15 Setup Deluge](#415-setup-deluge)
- [5.00 Jackett LXC - Ubuntu 18.04](#500-jackett-lxc---ubuntu-1804)
	- [5.01 Rapid Jackett Installation - Ubuntu 18.04](#501-rapid-jackett-installation---ubuntu-1804)
	- [5.02 Jackett default console login credentials - Ubuntu 18.04](#502-jackett-default-console-login-credentials---ubuntu-1804)
	- [5.03 Jackett WebGUI HTTP Access - Ubuntu 18.04](#503-jackett-webgui-http-access---ubuntu-1804)
- [6.00 Flexget LXC - Ubuntu 18.04](#600-flexget-lxc---ubuntu-1804)
	- [6.01 Create a Ubuntu 18.04 LXC for Flexget](#601-create-a-ubuntu-1804-lxc-for-flexget)
	- [6.02 Setup Flexget Mount Points - Ubuntu 18.04](#602-setup-flexget-mount-points---ubuntu-1804)
	- [6.03 Unprivileged container mapping - Ubuntu 18.04](#603-unprivileged-container-mapping---ubuntu-1804)
	- [6.04 Create Flexget download folders on your ZFS typhoon-share - Ubuntu 18.04](#604-create-flexget-download-folders-on-your-zfs-typhoon-share---ubuntu-1804)
	- [6.05 Create Flexget content folders on your NAS](#605-create-flexget-content-folders-on-your-nas)
	- [6.06 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04](#606-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade---ubuntu-1804)
	- [6.08 Container Update &  Upgrade - Ubuntu 18.04](#608-container-update---upgrade---ubuntu-1804)
	- [6.09 Create new "media" user - Ubuntu 18.04](#609-create-new-media-user---ubuntu-1804)
	- [6.10 Configuring Flexget machine locales - Ubuntu 18.04](#610-configuring-flexget-machine-locales---ubuntu-1804)
	- [6.11 Create Flexget `Home` Folder - Ubuntu 18.04](#611-create-flexget-home-folder---ubuntu-1804)
	- [6.12 Install Flexget - Ubuntu 18.04](#612-install-flexget---ubuntu-1804)
	- [6.13 Download the Flexget YAML Configuration Files](#613-download-the-flexget-yaml-configuration-files)
	- [6.14 Create Flexget Service file - Ubuntu 18.04](#614-create-flexget-service-file---ubuntu-1804)
	- [6.15 Setup Flexget](#615-setup-flexget)
- [7.00 FileBot Installation on Deluge LXC - Ubuntu 18.04](#700-filebot-installation-on-deluge-lxc---ubuntu-1804)
	- [7.11 Create FileBot `Home` Folder - Ubuntu 18.04](#711-create-filebot-home-folder---ubuntu-1804)
	- [7.12 Install FileBot - Ubuntu 18.04](#712-install-filebot---ubuntu-1804)
	- [7.13 Register and Activate FileBot](#713-register-and-activate-filebot)
	- [7.14 Setup FileBot](#714-setup-filebot)
- [8.00 Sonarr LXC - Ubuntu 18.04](#800-sonarr-lxc---ubuntu-1804)
	- [8.01 Create a Ubuntu 18.04 LXC for Sonarr](#801-create-a-ubuntu-1804-lxc-for-sonarr)
	- [8.02 Setup Sonarr Mount Points - Ubuntu 18.04](#802-setup-sonarr-mount-points---ubuntu-1804)
	- [8.03 Unprivileged container mapping - Ubuntu 18.04](#803-unprivileged-container-mapping---ubuntu-1804)
	- [8.04 Ubuntu fix to avoid prompt to restart services during "apt apgrade"](#804-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade)
	- [8.05 Update container OS](#805-update-container-os)
	- [8.06 Create new "media" user - Ubuntu 18.04](#806-create-new-media-user---ubuntu-1804)
	- [8.07 Install Sonarr](#807-install-sonarr)
	- [8.08 Create Sonarr Service file - Ubuntu 18.04](#808-create-sonarr-service-file---ubuntu-1804)
	- [8.09 Install sonarr-episode-trimmer](#809-install-sonarr-episode-trimmer)
	- [8.10 Update the Sonarr configuration base file](#810-update-the-sonarr-configuration-base-file)
	- [8.11 Setup Sonarr](#811-setup-sonarr)
- [9.00 Radarr LXC - Ubuntu 18.04](#900-radarr-lxc---ubuntu-1804)
	- [9.01 Create a Ubuntu 18.04 LXC for Radarr](#901-create-a-ubuntu-1804-lxc-for-radarr)
	- [9.02 Setup Radarr Mount Points - Ubuntu 18.04](#902-setup-radarr-mount-points---ubuntu-1804)
	- [9.03 Unprivileged container mapping - Ubuntu 18.04](#903-unprivileged-container-mapping---ubuntu-1804)
	- [9.04 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04](#904-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade---ubuntu-1804)
	- [9.05 Container Update &  Upgrade - Ubuntu 18.04](#905-container-update---upgrade---ubuntu-1804)
	- [9.06 Create new "media" user - Ubuntu 18.04](#906-create-new-media-user---ubuntu-1804)
	- [9.07 Install Radarr](#907-install-radarr)
	- [9.08 Create Radarr Service file - Ubuntu 18.04](#908-create-radarr-service-file---ubuntu-1804)
	- [9.09 Update the Radarr configuration base file](#909-update-the-radarr-configuration-base-file)
	- [9.10 Setup Radarr](#910-setup-radarr)
- [10.00 Lidarr LXC - Ubuntu 18.04](#1000-lidarr-lxc---ubuntu-1804)
	- [10.01 Create a Ubuntu 18.04 LXC for Lidarr](#1001-create-a-ubuntu-1804-lxc-for-lidarr)
	- [10.02 Setup Lidarr Mount Points - Ubuntu 18.04](#1002-setup-lidarr-mount-points---ubuntu-1804)
	- [10.03 Unprivileged container mapping - Ubuntu 18.04](#1003-unprivileged-container-mapping---ubuntu-1804)
	- [10.04 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04](#1004-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade---ubuntu-1804)
	- [10.05 Container Update &  Upgrade - Ubuntu 18.04](#1005-container-update---upgrade---ubuntu-1804)
	- [10.06 Create new "media" user - Ubuntu 18.04](#1006-create-new-media-user---ubuntu-1804)
	- [10.07 Install Lidarr](#1007-install-lidarr)
	- [10.08 Create Lidarr Service file - Ubuntu 18.04](#1008-create-lidarr-service-file---ubuntu-1804)
	- [10.09 Setup Lidarr](#1009-setup-lidarr)
- [11.00 Lazylibrarian LXC - Ubuntu 18.04](#1100-lazylibrarian-lxc---ubuntu-1804)
	- [11.01 Create a Ubuntu 18.04 LXC for Lazylibrarian](#1101-create-a-ubuntu-1804-lxc-for-lazylibrarian)
	- [11.02 Setup Lazylibrarian Mount Points - Ubuntu 18.04](#1102-setup-lazylibrarian-mount-points---ubuntu-1804)
	- [11.03 Unprivileged container mapping - Ubuntu 18.04](#1103-unprivileged-container-mapping---ubuntu-1804)
	- [11.04 Create Lazylibrarian content folders on your NAS](#1104-create-lazylibrarian-content-folders-on-your-nas)
	- [11.05 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04](#1105-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade---ubuntu-1804)
	- [11.06 Container Update &  Upgrade - Ubuntu 18.04](#1106-container-update---upgrade---ubuntu-1804)
	- [11.07 Create new "media" user - Ubuntu 18.04](#1107-create-new-media-user---ubuntu-1804)
	- [11.08 Install Lazylibrarian](#1108-install-lazylibrarian)
	- [11.09 Create Lazylibrarian Service file - Ubuntu 18.04](#1109-create-lazylibrarian-service-file---ubuntu-1804)
	- [11.10 Setup Lazylibrarian](#1110-setup-lazylibrarian)
- [12.00 Ombi LXC - Ubuntu 18.04](#1200-ombi-lxc---ubuntu-1804)
	- [12.01 Create a Ubuntu 18.04 LXC for Lazylibrarian](#1201-create-a-ubuntu-1804-lxc-for-lazylibrarian)
	- [12.02 Setup Ombi Mount Points - Ubuntu 18.04](#1202-setup-ombi-mount-points---ubuntu-1804)
	- [12.03 Unprivileged container mapping - Ubuntu 18.04](#1203-unprivileged-container-mapping---ubuntu-1804)
	- [12.04 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04](#1204-ubuntu-fix-to-avoid-prompt-to-restart-services-during-apt-apgrade---ubuntu-1804)
	- [12.05 Container Update &  Upgrade - Ubuntu 18.04](#1205-container-update---upgrade---ubuntu-1804)
	- [12.06 Create new "media" user - Ubuntu 18.04](#1206-create-new-media-user---ubuntu-1804)
	- [12.07 Create Ombi content folders on your NAS](#1207-create-ombi-content-folders-on-your-nas)
	- [12.08 Configuring Ombi machine locales - Ubuntu 18.04](#1208-configuring-ombi-machine-locales---ubuntu-1804)
	- [12.09 Install Ombi](#1209-install-ombi)
	- [12.10 Create Ombi Service file - Ubuntu 18.04](#1210-create-ombi-service-file---ubuntu-1804)
	- [12.11 Setup Ombi](#1211-setup-ombi)


## About LXC Media Installations
CentosOS7 is my preferred linux distribution but for media software Ubuntu seems to be the most supported linux distribution. I have used Ubuntu 18.04 for all media LXC's.

Proxmox itself ships with a set of basic templates and to download a prebuilt OS distribution use the graphical interface `typhoon-01` > `local` > `content` > `templates` and select and download `centos-7-default` and `ubuntu-18.04-standard` templates.

## 1.00 Unprivileged LXC Containers and file permissions
With unprivileged LXC containers you will have issues with UIDs (user id) and GIDs (group id) permissions with bind mounted shared data. All of the UIDs and GIDs are mapped to a different number range than on the host machine, usually root (uid 0) became uid 100000, 1 will be 100001 and so on.

However you will soon realise that every file and directory will be mapped to "nobody" (uid 65534). This isn't acceptable for host mounted shared data resources. For shared data you want to access the directory with the same - unprivileged - uid as it's using on other LXC machines.

The fix is to change the UID and GID mapping. So in our build we will create a new users/groups:

*  user `media` (uid 1605) and group `medialab` (gid 65605) accessible to unprivileged LXC containers (i.e Jellyfin, NZBGet, Deluge, Sonarr, Radarr, LazyLibrarian, Flexget);
*  user `storm` (uid 1606) and group `homelab` (gid 65606) accessible to unprivileged LXC containers (i.e Syncthing, Nextcloud, Unifi);
*  user `typhoon` (uid 1607) and group `privatelab` (gid 65606) accessible to unprivileged LXC containers (i.e all things private).

Also because Synology new Group ID's are in ranges above 65536, outside of Proxmox ID map range, we must pass through our Medialab (gid 65605), Homelab (gid 65606) and Privatelab (gid 65607) Group GID's mapped 1:1.

This is achieved in three parts during the course of creating your new media LXC's.

### 1.01 Unprivileged container mapping - medialab
To change a container mapping we change the container UID and GID in the file `/etc/pve/lxc/container-id.conf` after you create a new container. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:
```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab,homelab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/container-id.conf
```
### 1.02 Allow a LXC to perform mapping on the Proxmox host - medialab
Next we have to allow the LXC to actually do the mapping on the host. Since LXC creates the container using root, we have to allow root to use these new uids in the container.

To achieve this we need to **add** lines to `/etc/subuid` (users) and `/etc/subgid` (groups). So we need to define two ranges: one where the system IDs (i.e root uid 0) of the container can be mapped to an arbitrary range on the host for security reasons, and another where Synology GIDs above 65536 of the container can be mapped to the same GIDs on the host. That's why we have the following lines in the /etc/subuid and /etc/subgid files.

Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following (NOTE: Only needs to be performed ONCE on each host (i.e typhoon-01/02/03)):

```
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

The above code adds a ID map range from 65604 > 65704 on the container to the same range on the host. Next ID maps gid100 (default linux users group) and uid1605 (username media) on the container to the same range on the host.


### 1.03 Create a newuser `media` in a LXC
We need to create a `media` user in all media LXC's which require shared data (NFS NAS shares). After logging into the LXC container type the following:

(A) To create a user without a Home folder
```
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -M media &&
usermod -s /bin/bash media
```
(B) To create a user with a Home folder
```
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -m media &&
usermod -s /bin/bash media
```
Note: We do not need to create a new user group because `users` is a default linux group with GID value 100.

---

## 2.00 Jellyfin LXC - Ubuntu 18.04

Jellyfin is an alternative to the proprietary Emby and Plex, to provide media from a dedicated server to end-user devices via multiple apps. 

Jellyfin is descended from Emby's 3.5.2 release and ported to the .NET Core framework to enable full cross-platform support. There are no strings attached, no premium licenses or features, and no hidden agendas: and at the time of writing this media server software seems like the best available solution (and is free).

### 2.01 Download the Ubuntu LXC template - Ubuntu 18.04
First you need to add Ubuntu 18.04 LXC to your Proxmox templates. Now using the Proxmox web interface `Datacenter` > `typhoon-01` >`Local (typhoon-01)` > `Content` > `Templates`  select `ubuntu-18.04-standard` LXC and click `Download`.

Or use a Proxmox typhoon-01 CLI `>_ Shell` and type the following:
```
wget  http://download.proxmox.com/images/system/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz -P /var/lib/vz/template/cache && gzip -d /var/lib/vz/template/cache/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz
```

### 2.02 Create a Ubuntu 18.04 LXC for Jellyfin - Ubuntu 18.04
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
pct create 111 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname jellyfin --cpulimit 1 --cpuunits 1024 --memory 4096 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.111/24,type=veth --ostype ubuntu --rootfs typhoon-share:20 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music --mp1 /mnt/pve/cyclone-01-photo,mp=/mnt/photo --mp2 /mnt/pve/cyclone-01-transcode,mp=/mnt/transcode --mp3 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp4 /mnt/pve/cyclone-01-audio,mp=/mnt/audio --mp5 /mnt/pve/cyclone-01-books,mp=/mnt/books --mp6 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 111 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname jellyfin --cpulimit 1 --cpuunits 1024 --memory 4096 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.111/24,type=veth --ostype ubuntu --rootfs typhoon-share:20 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 2.03 Setup Jellyfin Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 2.02 then you have no Moint Points.

Please note your Proxmox Jellyfin LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 111 -mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music &&
pct set 111 -mp1 /mnt/pve/cyclone-01-photo,mp=/mnt/photo &&
pct set 111 -mp2 /mnt/pve/cyclone-01-transcode,mp=/mnt/transcode &&
pct set 111 -mp3 /mnt/pve/cyclone-01-video,mp=/mnt/video
pct set 111 -mp4 /mnt/pve/cyclone-01-audio,mp=/mnt/audio
pct set 111 -mp5 /mnt/pve/cyclone-01-books,mp=/mnt/books
pct set 111 -mp6 /mnt/pve/cyclone-01-public,mp=/mnt/public
```
### 2.04 Unprivileged container mapping - Ubuntu 18.04
To change the Jellyfin container mapping we change the container UID and GID in the file `/etc/pve/lxc/111.conf`. Simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following:

```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/111.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

### 2.05 Configure and Install VAAPI - Ubuntu 18.04
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
### 2.06 Create a rc.local
For FFMPEG to work we must create a script to `chmod 666 /dev/dri/renderD128` everytime the Proxmox host reboots. Now using the web interface go to Proxmox CLI `Datacenter` > `typhoon-01/02` >  `>_ Shell` and type the following:
```
echo '#!/bin/sh -e
/bin/chmod 666 /dev/dri/renderD128
exit 0' > /etc/rc.local &&
chmod +x /etc/rc.local &&
bash /etc/rc.local
```

### 2.07 Grant Jellyfin LXC Container access to the Proxmox host video device - Ubuntu 18.04
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

### 2.08 Ubuntu fix to avoid prompt to restart services during "apt apgrade"
First start LXC 111 (jellyfin) with the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `>_ Shell` and type the following:
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 2.09 Install Jellyfin - Ubuntu 18.04
This is easy. First start LXC 111 (jellyfin) with the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `>_ Shell` and type the following:

```
sudo apt update -y &&
sudo apt install apt-transport-https &&
sudo apt install gnupg gnupg2 gnupg1 -y &&
wget -O - https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | sudo apt-key add - &&
#echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/ubuntu $( lsb_release -c -s ) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list &&
echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list &&
sudo apt update -y &&
sudo apt install jellyfin -y
```

### 2.10 Create and edit user groups- Ubuntu 18.04
Jellyfin installation creates a new username and group: `jellyfin:jellyfin`. By default Jellyfin SW runs under username `jellyfin`. So Jellyfin has library access to our NAS we need to add the user `jellyfin` to the `medialab` group OR modify the UID and GID of `jellyfin:jellyfin`.

#### 2.10a Option A
My preference is to edit the UID and GID of `jellyfin:jellyfin` to match `media:medialab` > `1605:65605`. Obviously you do NOT create `media:medialab` user and group.

With the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `>_ Shell` and type the following:
```
systemctl stop jellyfin &&
sleep 5 &&
OLDUID=$(id -u jellyfin) &&
OLDGID=$(id -g jellyfin) &&
usermod -u 1605 jellyfin && 
groupmod -g 65605 jellyfin &&
usermod -s /bin/bash jellyfin &&
find / \( -path /mnt \) -prune -o -user "$OLDUID" -exec chown -h 1605 {} \; &&
find / \( -path /mnt \) -prune -o -group "$OLDGID" -exec chgrp -h 65605 {} \; &&
systemctl restart jellyfin
```

#### 2.10b Option B
With the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `>_ Shell` and type the following:

```
# Create username media and group medialab
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -M media &&
usermod -s /bin/bash media &&
# Add jellyfin to medialab
sudo usermod -a -G medialab jellyfin
```

### 2.11 Start Jellyfin - Ubuntu 18.04
With the Proxmox web interface go to `typhoon-01` > `111 (jellyfin)` > `>_ Shell` and type the following:

```
sudo systemctl restart jellyfin
```

### 2.12 Setup your Jellyfin Installation
In your web browser type `http://192.168.50.111:8096` and you should see a Jellyfin configuration wizard page.

---

## 3.00 NZBget LXC - Ubuntu 18.04
NZBGet is a binary downloader, which downloads files from Usenet based on information given in nzb-files.

NZBGet is written in C++ and is known for its extraordinary performance and efficiency.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

### 3.01 Download the Ubuntu LXC template - Ubuntu 18.04
First you need to add Ubuntu 18.04 LXC to your Proxmox templates if you have'nt already done so. Now using the Proxmox web interface `Datacenter` > `typhoon-01` >`Local (typhoon-01)` > `Content` > `Templates`  select `ubuntu-18.04-standard` LXC and click `Download`.

Or use a Proxmox typhoon-01 CLI `>_ Shell` and type the following:
```
wget  http://download.proxmox.com/images/system/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz -P /var/lib/vz/template/cache && gzip -d /var/lib/vz/template/cache/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz
```

### 3.02 Create a Ubuntu 18.04 LXC for NZBget - Ubuntu 18.04
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
pct create 112 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname nzbget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.112/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads --mp1 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp2 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 112 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname nzbget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.112/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 3.03 Setup NZBget Mount Points - Ubuntu 18.04

If you used Script (B) in Section 4.2 then you have no Moint Points.

Please note your Proxmox NZBget LXC MUST BE in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
pct set 112 -mp0 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads &&
pct set 112 -mp1 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
pct set 112 -mp2 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

### 3.04 Unprivileged container mapping - Ubuntu 18.04
To change the NZBGet container mapping we change the container UID and GID in the file `/etc/pve/lxc/112.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/112.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

### 3.05 Create NZBGet download folders on your ZFS typhoon-share - Ubuntu 18.04
To create the NZBGet download folders use the web interface go to Proxmox CLI Datacenter > `typhoon-01` > `>_ Shell` and type the following:
```
mkdir -p {/mnt/pve/cyclone-01-downloads/nzbget/nzb,/mnt/pve/cyclone-01-downloads/nzbget/queue,/mnt/pve/cyclone-01-downloads/nzbget/tmp,/mnt/pve/cyclone-01-downloads/nzbget/intermediate,/mnt/pve/cyclone-01-downloads/nzbget/completed,/mnt/pve/cyclone-01-downloads/nzbget/completed/lazy,/mnt/pve/cyclone-01-downloads/nzbget/completed/series,/mnt/pve/cyclone-01-downloads/nzbget/completed/movies,/mnt/pve/cyclone-01-downloads/nzbget/completed/music} &&
chown -R 1605:65605 {/mnt/pve/cyclone-01-downloads/nzbget,/mnt/pve/cyclone-01-downloads/nzbget/nzb,/mnt/pve/cyclone-01-downloads/nzbget/queue,/mnt/pve/cyclone-01-downloads/nzbget/tmp,/mnt/pve/cyclone-01-downloads/nzbget/intermediate,/mnt/pve/cyclone-01-downloads/nzbget/completed,/mnt/pve/cyclone-01-downloads/nzbget/completed/lazy,/mnt/pve/cyclone-01-downloads/nzbget/completed/series,/mnt/pve/cyclone-01-downloads/nzbget/completed/movies,/mnt/pve/cyclone-01-downloads/nzbget/completed/music}
```


### 3.06 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04
First start LXC 112 (nzbget) with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 3.07 Container Update &  Upgrade - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:
```
apt-get update &&
apt-get upgrade -y
```

### 3.07 Create new "media" user - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:
```
sudo apt-get update &&
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -M media &&
usermod -s /bin/bash media
```

### 3.07 Install NZBget - Ubuntu 18.04
This is easy. First start LXC 112 (nzbget) with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:

```
wget https://nzbget.net/download/nzbget-latest-bin-linux.run -P /tmp &&
sh /tmp/nzbget-latest-bin-linux.run --destdir /opt/nzbget &&
rm /tmp/nzbget-latest-bin-linux.run &&
sudo chown -R 1605:65605 /opt/nzbget
```

### 3.08 Edit NZBget configuration file - Ubuntu 18.04
The NZBGET configuration file needs to have its default settings changed. In this step we are going to change or add the following settings:
*  download location changed to your ZFS typhoon-share downloads folder /mnt/downloads/nzbget;
*  NZBGet daemon username changed to run under `media` not root;
*  create and add labels sonarr-series, radarr-movies, lidarr-music and lazylibrarian;
*  create a RPC username and password.

Using the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:

```
# Set the Download folder
sed -i 's|MainDir=${AppDir}/downloads|MainDir=/mnt/downloads/nzbget|g' /opt/nzbget/nzbget.conf &&
# Set the User Daemon
sed -i "/DaemonUsername=/c\DaemonUsername=media" /opt/nzbget/nzbget.conf &&
# Set all the category labels and destination settings
sed -i "/Category1.Name=Movies/c\Category1.Name=radarr-movies" /opt/nzbget/nzbget.conf &&
sed -i "/Category1.DestDir=/c\Category1.DestDir=/mnt/downloads/nzbget/completed/movies" /opt/nzbget/nzbget.conf &&
sed -i "/Category1.Aliases=movies*/c\Category1.Aliases=radarr-movies*" /opt/nzbget/nzbget.conf &&
sed -i 's/Category2.Name=Series/Category2.Name=sonarr-series\nCategory2.DestDir=\/mnt\/downloads\/nzbget\/completed\/series\nCategory2.Unpack=yes\nCategory2.Extensions=\nCategory2.Aliases=sonarr-series*/' /opt/nzbget/nzbget.conf &&
sed -i 's/Category3.Name=Music/Category3.Name=lidarr-music\nCategory3.DestDir=\/mnt\/downloads\/nzbget\/completed\/music\nCategory3.Unpack=yes\nCategory3.Extensions=\nCategory3.Aliases=lidarr-music*/' /opt/nzbget/nzbget.conf &&
sed -i 's/Category4.Name=Software/Category4.Name=lazy\nCategory4.DestDir=\/mnt\/downloads\/nzbget\/completed\/lazy\nCategory4.Unpack=yes\nCategory4.Extensions=\nCategory4.Aliases=lazy*/' /opt/nzbget/nzbget.conf &&
# Add username and password for RPC Access
sed -i "/AddUsername=/c\AddUsername=rpcaccess" /opt/nzbget/nzbget.conf &&
sed -i "/AddPassword=/c\AddPassword=Ut#)>3'o&RVmRj>]" /opt/nzbget/nzbget.conf &&
# Set the file permissions and ownership
sudo chmod 755 /opt/nzbget/nzbget.conf &&
chown 1605:65605 /opt/nzbget/nzbget.conf
```

### 3.09 Create NZBget Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=NZBGet Daemon
Documentation=http://nzbget.net/Documentation
After=network.target

[Service]
User=media
Group=medialab
Type=forking
ExecStart=/opt/nzbget/nzbget -D
ExecStop=/opt/nzbget/nzbget -Q
ExecReload=/opt/nzbget/nzbget -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/nzbget.service &&
sleep 2 &&
sudo systemctl enable nzbget &&
sleep 2 &&
sudo systemctl restart nzbget &&
sudo systemctl status nzbget

```

### 3.10 Setup NZBget 
Browse to http://192.168.30.112:6789 to start using NZBget. Your NZBget default login details are (login:nzbget, password:tegbzn6789). Instructions to setup NZBget are [HERE]

---

## 4.00 Deluge LXC - Ubuntu 18.04
Deluge is a lightweight, Free Software, cross-platform BitTorrent client. I also install Jacket in this LXC container.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

### 4.01 Download the Ubuntu LXC template - Ubuntu 18.04
First you need to add Ubuntu 18.04 LXC to your Proxmox templates if you have'nt already done so. Now using the Proxmox web interface `Datacenter` > `typhoon-01` >`Local (typhoon-01)` > `Content` > `Templates`  select `ubuntu-18.04-standard` LXC and click `Download`.

Or use a Proxmox typhoon-01 CLI `>_ Shell` and type the following:
```
wget  http://download.proxmox.com/images/system/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz -P /var/lib/vz/template/cache && gzip -d /var/lib/vz/template/cache/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz
```

### 4.02 Create a Ubuntu 18.04 LXC for Deluge - Ubuntu 18.04
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
pct create 113 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname deluge --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.113/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads --mp1 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp2 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 113 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname deluge --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.113/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 4.03 Setup Deluge & Jacket Mount Points - Ubuntu 18.04

If you used Script (B) in Section 5.2 then you have no Moint Points.

Please note your Proxmox Deluge LXC MUST BE in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
pct set 113 -mp0 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads
pct set 113 -mp1 /mnt/pve/cyclone-01-video,mp=/mnt/video
pct set 113 -mp2 /mnt/pve/cyclone-01-public,mp=/mnt/public

```

### 4.04 Unprivileged container mapping - Ubuntu 18.04
To change the Deluge container mapping we change the container UID and GID in the file /etc/pve/lxc/113.conf. Simply use Proxmox CLI typhoon-01 > >_ Shell and type the following:
```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/113.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

### 4.05 Create Deluge download folders on your ZFS typhoon-share - Ubuntu 18.04
To create the Deluge download folders use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
mkdir -m 775 -p {/mnt/pve/cyclone-01-downloads/deluge/incomplete,/mnt/pve/cyclone-01-downloads/deluge/complete,/mnt/pve/cyclone-01-downloads/deluge/complete/lazy,/mnt/pve/cyclone-01-downloads/deluge/complete/movies,/mnt/pve/cyclone-01-downloads/deluge/complete/series,/mnt/pve/cyclone-01-downloads/deluge/complete/music,/mnt/pve/cyclone-01-downloads/deluge/autoadd} &&
chown -R 1605:65605 {/mnt/pve/cyclone-01-downloads/deluge,/mnt/pve/cyclone-01-downloads/deluge/incomplete,/mnt/pve/cyclone-01-downloads/deluge/complete,/mnt/pve/cyclone-01-downloads/deluge/complete/lazy,/mnt/pve/cyclone-01-downloads/deluge/complete/movies,/mnt/pve/cyclone-01-downloads/deluge/complete/series,/mnt/pve/cyclone-01-downloads/deluge/complete/music,/mnt/pve/cyclone-01-downloads/deluge/autoadd}
```

### 4.06 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04
First start LXC 113 (deluge) with the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 4.07 Container Update &  Upgrade - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
apt-get update &&
apt-get upgrade -y
```

### 4.08 Create new "media" user - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
sudo apt-get update &&
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -m media &&
usermod -s /bin/bash media
```
Note: This time we create a home folder for user `media` - required by Deluge.


### 4.09 Configuring host machine locales - Ubuntu 18.04
The default locale for the system environment must be: en_US.UTF-8. To set the default locale on your machine go to the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
echo -e "LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8" > /etc/default/locale &&
sudo locale-gen en_US.UTF-8 &&
sudo reboot
```
Your `113 (deluge)`container will reboot. So you will have to re-login into machine `113 (deluge)` to continue.

### 4.10 Install Deluge - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
sudo apt-get update &&
sudo apt install subversion -y &&
sudo apt install software-properties-common -y &&
sudo add-apt-repository ppa:deluge-team/ppa -y &&
# sudo add-apt-repository ppa:deluge-team/stable && # Plugins dont work in v2
sudo apt-get update &&
sudo apt-get install deluged deluge-webui deluge-console -y
```
You will receive the following prompts:
~At the prompt `As the maintainer of this PPA, you can now support me on Patreon` press `[ENTER]`.~
At the prompt `Configuring libssl1.1:amd64` select `<Yes>`.

### 4.11 Download Deluge Plugins and settings files - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
systemctl daemon-reload &&
su -c 'deluged' media &&
sleep 5 &&
pkill -9 deluged &&
wget --content-disposition https://forum.deluge-torrent.org/download/file.php?id=6306 -P /home/media/.config/deluge/plugins/ &&
wget  https://raw.githubusercontent.com/ahuacate/deluge/master/deluge-postprocess.sh -P /home/media/.config/deluge &&
chmod +rx /home/media/.config/deluge/deluge-postprocess.sh &&
chown 1605:65605 /home/media/.config/deluge/deluge-postprocess.sh &&
echo -e "flexget:9c67cf728b8c079c2e0065ee11cb3a9a6771420a:10
lazylibrarian:9c67cf728b8c079c2e0065ee11cb3a9a6771421a:10" >> /home/media/.config/deluge/auth &&
wget  https://raw.githubusercontent.com/ahuacate/deluge/master/label.conf -P /home/media/.config/deluge &&
wget  https://raw.githubusercontent.com/ahuacate/deluge/master/execute.conf -P /home/media/.config/deluge &&
wget  https://raw.githubusercontent.com/ahuacate/deluge/master/autoremoveplus.conf -P /home/media/.config/deluge &&
chown 1605:65605 {/home/media/.config/deluge/label.conf,/home/media/.config/deluge/execute.conf,/home/media/.config/deluge/autoremoveplus.conf,/home/media/.config/deluge/plugins/*.egg}
```

### 4.12 Create Deluge Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Deluge Client Daemon
Documentation=https://dev.deluge-torrent.org/
After=network-online.target

[Service]
User=media
Group=medialab
Type=simple
Umask=007
ExecStart=/usr/bin/deluged -d
KillMode=process
Restart=on-failure

# Configures the time to wait before service is stopped forcefully.
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/deluge.service &&
sleep 2 &&
sudo systemctl enable deluge &&
sleep 2 &&
sudo systemctl start deluge
```

### 4.13 Final Configuring of Deluge - Ubuntu 18.04
Here we are going to use the deluge-console commands to configure Deluge Preferences and enable some Deluge Plugins. Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
su -c 'deluge-console "config -s allow_remote True"' media &&
su -c 'deluge-console "config -s download_location /mnt/downloads/deluge/incomplete"' media &&
su -c 'deluge-console "config -s max_active_downloading 20"' media &&
su -c 'deluge-console "config -s max_active_limit 20"' media &&
su -c 'deluge-console "config -s max_active_seeding 20"' media &&
su -c 'deluge-console "config -s max_connections_global 200"' media &&
su -c 'deluge-console "config -s remove_seed_at_ratio true"' media &&
su -c 'deluge-console "config -s stop_seed_at_ratio true"' media &&
su -c 'deluge-console "config -s stop_seed_ratio 1.5"' media &&
sleep 5 &&
su -c 'deluge-console "plugin -e autoremoveplus"' media &&
su -c 'deluge-console "plugin -e label"' media &&
su -c 'deluge-console "plugin -e execute"' media &&
sleep 2 &&
sudo systemctl restart deluge
````

### 4.14 Create Deluge WebGUI Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Deluge Bittorrent Client Web Interface
Documentation=https://dev.deluge-torrent.org/
After=network-online.target deluge.service
Wants=deluge.service


[Service]
User=media
Group=medialab

Type=simple
Umask=027
ExecStart=/usr/bin/deluge-web
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/deluge-web.service &&
sleep 2 &&
sudo systemctl enable deluge-web &&
sleep 2 &&
sudo systemctl start deluge-web
```

### 4.15 Setup Deluge 
Browse to http://192.168.30.113:8112 to start using Deluge. Your Deluge default login details are password:deluge. Instructions to complete the setup of Deluge is [HERE]

---

## 5.00 Jackett LXC - Ubuntu 18.04
Jackett works as a proxy server: it translates queries from apps (Sonarr, Radarr, Lidarr etc) into tracker-site-specific http queries, parses the html response, then sends results back to the requesting software. This allows for getting recent uploads (like RSS) and performing searches. Jackett is a single repository of maintained indexer scraping & translation logic - removing the burden from other apps.

### 5.01 Rapid Jackett Installation - Ubuntu 18.04

To create a new Ubuntu 18.04 LXC container on Proxmox and setup Jackett to run inside of it, run the following in a SSH connection or use the Proxmox WebGUI shell `Proxmox Datacenter` > `typhoon-01` > `>_ Shell` and type the following:

```
bash -c "$(wget -qLO - https://github.com/ahuacate/proxmox-lxc-media/raw/master/scripts/jackett_create_container_ubuntu_1804.sh)"
```

During the setup process you will be prompted for inputs to configure your new LXC (i.e IPv4 address, CTID, gateway, disk size, password - or you may choose to use our preset defaults).

### 5.02 Jackett default console login credentials - Ubuntu 18.04

Your default login password was set during the rapid installation process. If you did'nt change the default password here is your console login details.
```
Username: root
Password: ahuacate
```
To change your default root password use the CLI command `passwd`.

### 5.03 Jackett WebGUI HTTP Access - Ubuntu 18.04

Jackett will be available at http://192.168.50.120:9117

---

## 6.00 Flexget LXC - Ubuntu 18.04
FlexGet is a multipurpose automation tool for all of your media. Support for torrents, nzbs, podcasts, comics, TV, movies, RSS, HTML, CSV, and more. Filebot is used to rename all Flexget downloaded media.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

### 6.01 Create a Ubuntu 18.04 LXC for Flexget
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`114`|
| Hostname |`flexget`|
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
| IPv4/CIDR |`192.168.30.114/24`|
| Gateway (IPv4) |`192.168.30.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | `192.168.30.5`
| DNS servers | `192.168.30.5`
| **Confirm**
| Start after Created | `☐`

And Click `Finish` to create your Flexget LXC. The above will create the Flexget LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Flexget LXC):

**Script (A):** Including LXC Mount Points
```
pct create 114 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname flexget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.114/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp1 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads --mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp3 /mnt/pve/cyclone-01-audio,mp=/mnt/audio --mp4 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 114 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname flexget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.114/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```


### 6.02 Setup Flexget Mount Points - Ubuntu 18.04

If you used Script (B) in Section 4.2 then you have no Moint Points.

Please note your Proxmox Flexget LXC MUST BE in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
pct set 114 -mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video &&
pct set 114 -mp1 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads &&
pct set 114 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
pct set 114 -mp3 /mnt/pve/cyclone-01-audio,mp=/mnt/audio
pct set 113 -mp4 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

### 6.03 Unprivileged container mapping - Ubuntu 18.04
To change the Flexget container mapping we change the container UID and GID in the file `/etc/pve/lxc/114.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/114.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

### 6.04 Create Flexget download folders on your ZFS typhoon-share - Ubuntu 18.04
To create Flexget download folders use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
mkdir -p {/mnt/pve/cyclone-01-downloads/deluge/complete/flexget/series,/mnt/pve/cyclone-01-downloads/deluge/complete/flexget/movies} &&
chown 1605:65605 {/mnt/pve/cyclone-01-downloads/deluge/complete/flexget,/mnt/pve/cyclone-01-downloads/deluge/complete/flexget/series,/mnt/pve/cyclone-01-downloads/deluge/complete/flexget/movies}
```

### 6.05 Create Flexget content folders on your NAS
To create Flexget content folders on your NAS use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
mkdir -p {/mnt/pve/cyclone-01-video/documentary/series,/mnt/pve/cyclone-01-video/documentary/movies,/mnt/pve/cyclone-01-video/documentary/unsorted} &&
chown 1605:65605 {/mnt/pve/cyclone-01-video/documentary/series,/mnt/pve/cyclone-01-video/documentary/movies,/mnt/pve/cyclone-01-video/documentary/unsorted}
```

### 6.06 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04
First start LXC 114 (flexget) with the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 6.08 Container Update &  Upgrade - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
apt-get update &&
apt-get upgrade -y
```

### 6.09 Create new "media" user - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -M media &&
usermod -s /bin/bash media
```

### 6.10 Configuring Flexget machine locales - Ubuntu 18.04
The default locale for the system environment must be: en_US.UTF-8. To set the default locale on your machine go to the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:

```
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen &&
locale-gen

#echo -e "LANG=en_US.UTF-8
#LC_ALL=en_US.UTF-8" > /etc/default/locale &&
#sudo locale-gen en_US.UTF-8 &&
#sudo reboot
```

### 6.11 Create Flexget `Home` Folder - Ubuntu 18.04
With the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
mkdir -m 775 -p /home/media/flexget &&
sudo chown -R 1605:65605 /home/media/flexget
```

### 6.12 Install Flexget - Ubuntu 18.04
With the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:

```
sudo apt-get update -y &&
export LC_ALL="en_US.UTF8" &&
sudo apt-get install git-core python3 -y &&
sudo apt-get install python3-pip -y &&
pip3 install --upgrade setuptools &&
pip3 install pyopenssl ndg-httpsclient pyasn1 &&
pip3 install -U rarfile &&
pip3 install -U cloudscraper &&
pip3 install deluge-client &&
pip3 install flexget
```
At the prompt `Configuring libssl1.1:amd64` select `<Yes>`.

Now we need libtorrent for our config.yml to work. Until I figure out which libtorrent package & dependencies are required the workaround is to install Deluge dependencies (but, not Deluge).

So with the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:

```
sudo apt-get -y install python python-twisted python-openssl python-setuptools intltool python-xdg python-chardet geoip-database python-libtorrent python-notify python-pygame python-glade2 librsvg2-common xdg-utils python-mako 
```

### 6.13 Download the Flexget YAML Configuration Files
Your Flexget configuration files are pre-built and working. There are x files to download.

Download the Flexget YAML configuration file from GitHub. Go to the Proxmox web interface `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
wget https://raw.githubusercontent.com/ahuacate/flexget/master/config.yml -P /home/media/flexget &&
wget https://raw.githubusercontent.com/ahuacate/flexget/master/list-showrss.yml -P /home/media/flexget &&
wget https://raw.githubusercontent.com/ahuacate/flexget/master/list-mvgroup.yml -P /home/media/flexget &&
wget https://raw.githubusercontent.com/ahuacate/flexget/master/list-documentarytorrents.yml -P /home/media/flexget &&
wget https://raw.githubusercontent.com/ahuacate/flexget/master/secrets.yml -P /home/media/flexget &&
chown 1605:65605 /home/media/flexget/*.yml
```
The `secrets.yml` file requires you to enter your private user credentials and instructions are [HERE](https://github.com/ahuacate/flexget).

### 6.14 Create Flexget Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Flexget Daemon
After=network.target

[Service]
Type=simple
User=media
Group=medialab
UMask=000
WorkingDirectory=/home/media/flexget
ExecStart=/usr/local/bin/flexget daemon start
ExecStop=/usr/local/bin/flexget daemon stop
ExecReload=/usr/local/bin/flexget daemon reload

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/flexget.service &&
sleep 2 &&
sudo systemctl enable flexget &&
sudo systemctl start flexget
```

### 6.15 Setup Flexget 
Instructions to setup Flexget are [HERE](https://github.com/ahuacate/flexget#flexget-build) .

---

## 7.00 FileBot Installation on Deluge LXC - Ubuntu 18.04
FileBot is a tool for organizing and renaming your Movies, TV Shows and Anime as well as fetching subtitles and artwork. It is the naming resolver for all Flexget downloaded media.

Filebot seems much better at resolving/guessing media which doesn't adhere to the TheTVdB or IMdB named convention. Its the best renaming solution for series like 60 Minutes and general documentaries.

Best to use the fully paid licensed version of this software - it's worth it.

Filebot is installed on the Deluge LXC container.

### 7.11 Create FileBot `Home` Folder - Ubuntu 18.04
Filebot is installed on the Deluge LXC container. So using the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
sudo mkdir /home/media/.filebot; sudo chown -R 1605:65605 /home/media/.filebot
```

### 7.12 Install FileBot - Ubuntu 18.04
With the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
apt install curl -y &&
bash -xu <<< "$(curl -fsSL https://raw.githubusercontent.com/filebot/plugins/master/installer/deb.sh)"
```

To check your FileBot installation is without errors type the following:
```
sudo -u media -H sh -c "filebot -script fn:sysinfo"

### Results ....
FileBot 4.8.5 (r6224)
JNA Native: 5.2.0
MediaInfo: 17.12
p7zip: p7zip Version 16.02 (locale=en_US.UTF-8,Utf16=on,HugeFiles=on,64 bits,4 CPUs Intel(R) Core(TM) i5-7300U CPU @ 2.60GHz (806E9),ASM,AES-NI)
unrar: UNRAR 5.50 freeware
Chromaprint: fpcalc version 1.4.3
Extended Attributes: OK
Unicode Filesystem: OK
Script Bundle: 2019-05-15 (r565)
Groovy: 2.5.6
JRE: OpenJDK Runtime Environment 11.0.4
JVM: 64-bit OpenJDK 64-Bit Server VM
CPU/MEM: 2 Core / 3 GB Max Memory / 19 MB Used Memory
OS: Linux (amd64)
HW: Linux deluge 4.15.18-12-pve #1 SMP PVE 4.15.18-35 (Wed, 13 Mar 2019 08:24:42 +0100) x86_64 x86_64 x86_64 GNU/Linux
DATA: /root/.filebot
Package: DEB
License: UNREGISTERED
Done ヾ(＠⌒ー⌒＠)ノ
```
If you receive the following error, read on: `Unicode Filesystem` - **Unicode Filesystem: java.nio.file.InvalidPathException: Malformed input or input contains unmappable characters: /root/.filebot/龍飛鳳舞**. First check you've completed Step 7.12. Finally if the unicode error persists after performing Step 7.12 then manually set your machine locale to `en_US.UTF-8 UTF-8` using the command (spavebar to select / tab to move to <ok>):
```
sudo dpkg-reconfigure locales
```
This should resolve the unicode error issue.

### 7.13 Register and Activate FileBot
Go get yourself a license key for FileBot from [HERE](https://www.filebot.net/). You need it and its afforadable.

You will recieve your License Key via email and the activation instructions are available [HERE](https://www.filebot.net/forums/viewtopic.php?f=8&t=6121). Copy your FileBot_License_PXXXXXXX.psm License Key file to `/home/media/.filebot` folder. Or use nano and paste your key data into a new file. You **MUST** performed FileBot licensing under the 'media' user ID otherwise the software will not be licensed to run under the `media` user. 

With the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
nano /home/media/.filebot/FileBot_License.psm
```
Your FileBot license to Copy & Paste looks like this (extracted from the emailed received):
```
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512

Product: FileBot
Name: Funny Man
Email: funnyman@funnyman.com
Order: P72487328
Issue-Date: 2016-09-01
Valid-Until: 2017-09-01
-----BEGIN PGP SIGNATURE-----

7gDSg86bvBvnnasdjkhNBjkadasjkbdxasbxBghhjkvBhjkHVHJKGVVjbKHJVHVv
7gDSg86bvBvnnasdjkhNBjkadasjkbdxasbxBghhjkvBhjkHVHJKGVVjbKHJVHVv
7gDSg86bvBvnnasdjkhNBjkadasjkbdxasbxBghhjkvBhjkHVHJKGVVjbKHJVHVv
7gDSg86bvBvnnasdjkhNBjkadasjkbdxasbxBghhjkvBhjkHVHJKGVVjbKHJVHVv
7gDSg86bvBvnnasdjkhNBjkadasjkbdxasbxBghhjkvBhjkHVHJKGVVjbKHJVHVv
7gDSg86bvBvnnasdjkhNBjkadasjkbdxasbxBghhjkvBhjkHVHJKGVVjbKHJVHVv
7gDSg86bvBvnnasdjkhNBjkadasjkb==
=2maB
-----END PGP SIGNATURE-----
```
Note: After pasting your key (copy & paste the license key code with your mouse buttons) into the terminal, it's `CTRL O` (thats a capital letter O, not numerical 0) to prompt a save, `Enter` to save the file and `CTRL X` to exit nano.

The following command will execute Filebot licensing under user `media` for you. So type the following:
```
sudo -u media -H sh -c "filebot --license /home/media/.filebot/*.psm" 
```
Your terminal licensing output results should look like the following:
```
root@deluge:/home/media/.filebot# sudo -u media -H sh -c "filebot --license /home/media/.filebot/*.psm" 
Activate License XXXXXXX
Write [FileBot License XXXXXX (Valid-Until: 2020-09-01)] to [/home/media/.filebot/license.txt]
FileBot License P874348 (Valid-Until: 2020-09-01) has been activated successfully.
```

### 7.14 Setup FileBot 
FileBot works inconjunction with Flexget. So instructions to setup FileBot are [HERE](https://github.com/ahuacate/flexget#flexget-build). 

---

## 8.00 Sonarr LXC - Ubuntu 18.04
Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

### 8.01 Create a Ubuntu 18.04 LXC for Sonarr
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
pct create 115 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname sonarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.115/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp1 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads --mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp3 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 115 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname sonarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.115/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 8.02 Setup Sonarr Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 8.1 then you have no Moint Points.

Please note your Proxmox Sonarr LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 115 -mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video &&
pct set 115 -mp1 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads &&
pct set 115 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
pct set 115 -mp3 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

### 8.03 Unprivileged container mapping - Ubuntu 18.04
To change the Sonarr container mapping we change the container UID and GID in the file `/etc/pve/lxc/115.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/115.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```
### 8.04 Ubuntu fix to avoid prompt to restart services during "apt apgrade"
First start LXC 115 (sonarr) with the Proxmox web interface go to `typhoon-01` > `115 (sonarr)` > `START`.
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 8.05 Update container OS
Go to the Proxmox web interface `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:
```
apt update &&
apt upgrade -y
```

### 8.06 Create new "media" user - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:
```
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -m media &&
usermod -s /bin/bash media
```
Note: This time we create a home folder for user media - required by Sonarr.

### 8.07 Install Sonarr
Go to the Proxmox web interface `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:

```
sudo apt install unzip -y &&
sudo apt install gnupg ca-certificates -y &&
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &&
sudo echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list &&
sudo apt update -y &&
sudo apt install mono-devel -y &&
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8 &&
echo "deb https://apt.sonarr.tv/ubuntu bionic main" | sudo tee /etc/apt/sources.list.d/sonarr.list &&
sudo apt-get update -y &&
sudo apt install sonarr &&
sudo chown -R 1605:65605 /opt/NzbDrone
```
During the installation you will prompted for user input.
*  Do you want to continue? Answer "Y"
*  You will be asked which user and group Sonarr must run as. It's **important to set these correctly** to avoid permission issues with your media files. Set as follows:

| Sonarr Installation | Value |
| :---  | :---: |
| **User required inputs**
| Sonarr User | `media` |
| Sonarr Group | `medialab` |

### 8.08 Create Sonarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:
```
sudo echo -e "[Unit]
Description=Sonarr Daemon
After=network.target

[Service]
User=media
Group=medialab

Type=simple

# Change the path to Radarr or mono here if it is in a different location for you.
ExecStart=/usr/bin/mono --debug /opt/NzbDrone/NzbDrone.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/sonarr.service &&
sudo systemctl enable sonarr.service &&
sudo systemctl start sonarr.service
```

### 8.09 Install sonarr-episode-trimmer
A script for use with Sonarr that allows you to set the number of episodes of a show that you would like to keep.
Useful for aily shows. The script sorts the episodes you have for a show by the season and episode number, and then deletes the oldest episodes past the threshold you set.
```
mkdir 775 -p /home/media/.config/NzbDrone/custom-scripts &&
chown 1605:65605 /home/media/.config/NzbDrone/custom-scripts &&
wget https://gitlab.com/spoatacus/sonarr-episode-trimmer/raw/master/sonarr-episode-trimmer.py -P /home/media/.config/NzbDrone/custom-scripts &&
wget https://raw.githubusercontent.com/ahuacate/sonarr/master/sonarr-episode-trimmer/config -P /home/media/.config/NzbDrone/custom-scripts &&
chmod +rx /home/media/.config/NzbDrone/custom-scripts/sonarr-episode-trimmer.py &&
chown 1605:65605 /home/media/.config/NzbDrone/custom-scripts/*
```

### 8.10 Update the Sonarr configuration base file
This step near completes the Sonarr preferences settings by downloading a pre-built settings file from Github.

Begin with the Proxmox web interface and go to `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:
```
sudo systemctl stop sonarr.service &&
sleep 5 &&
rm -r /home/media/.config/NzbDrone/nzbdrone.db* &&
rm -r /home/media/.config/NzbDrone/config.xml &&
wget https://raw.githubusercontent.com/ahuacate/sonarr/master/backup/nzbdrone.db -O /home/media/.config/NzbDrone/nzbdrone.db &&
wget https://raw.githubusercontent.com/ahuacate/sonarr/master/backup/config.xml -O /home/media/.config/NzbDrone/config.xml &&
chown 1605:65605 /home/media/.config/NzbDrone/nzbdrone.db &&
chown 1605:65605 /home/media/.config/NzbDrone/config.xml &&
sudo systemctl restart sonarr.service
```

Thats it. Now go and complete Steps [2.05 Configure Download Clients](https://github.com/ahuacate/sonarr/blob/master/README.md#205-configure-download-clients) and [2.07 Configure General](https://github.com/ahuacate/sonarr/blob/master/README.md#207-configure-general).

### 8.11 Setup Sonarr
Browse to http://192.168.50.115:8989 to start using Sonarr.

---

## 9.00 Radarr LXC - Ubuntu 18.04
Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

### 9.01 Create a Ubuntu 18.04 LXC for Radarr
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
pct create 116 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname radarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.116/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp1 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads --mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp3 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 116 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname radarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.116/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 9.02 Setup Radarr Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 9.1 then you have no Moint Points.

Please note your Proxmox Radarr LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 116 -mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video &&
pct set 116 -mp1 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads &&
pct set 116 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
pct set 116 -mp3 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

### 9.03 Unprivileged container mapping - Ubuntu 18.04
To change the Radarr container mapping we change the container UID and GID in the file `/etc/pve/lxc/116.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/116.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

### 9.04 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04
First start LXC 116 (radarr) with the Proxmox web interface go to `typhoon-01` > `116 (radarr)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 9.05 Container Update &  Upgrade - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:
```
apt-get update &&
apt-get upgrade -y
```

### 9.06 Create new "media" user - Ubuntu 18.04
First start LXC 116 (radarr) with the Proxmox web interface go to `typhoon-01` > `116 (radarr)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:
```
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -m media &&
usermod -s /bin/bash media
```
Note: This time we create a home folder for user media - required by Radarr.

### 9.07 Install Radarr
Go to the Proxmox web interface `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:

```
sudo apt-get update -y &&
sudo apt-get install -y unzip &&
sudo apt install gnupg ca-certificates -y &&
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &&
echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list &&
sudo apt update -y &&
sudo apt install mono-devel curl -y &&
cd /opt &&
sudo curl -L -O $( curl -s https://api.github.com/repos/Radarr/Radarr/releases | grep linux.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) &&
sudo tar -xvzf Radarr.develop.*.linux.tar.gz &&
sudo rm *.linux.tar.gz &&
sudo chown -R 1605:65605 /opt/Radarr &&
sudo apt-get -y install libmediainfo-dev #Required to patch Mediainfo
```

### 9.08 Create Radarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
# Change the user and group variables here.
User=media
Group=medialab

Type=simple

# Change the path to Radarr or mono here if it is in a different location for you.
ExecStart=/usr/bin/mono --debug /opt/Radarr/Radarr.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure
# If Radarr does not restart after an update enable next line
ExecStop=-/usr/bin/mono /tmp/radarr_update/Radarr.Update.exe "ps aux | grep Radarr | grep -v grep | awk '{ print $2 }'" /tmp/radarr_update /opt/Radarr/Radarr.exe

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/radarr.service &&
sleep 2 &&
sudo systemctl enable radarr.service &&
sleep 2 &&
sudo systemctl restart radarr.service
```

### 9.09 Update the Radarr configuration base file
This step near completes the Sonarr preferences settings by downloading a pre-built settings file from Github.

Begin with the Proxmox web interface and go to `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:
```
sudo systemctl stop radarr.service &&
sleep 5 &&
rm -r /home/media/.config/Radarr/nzbdrone.db* &&
wget https://raw.githubusercontent.com/ahuacate/radarr/master/backup/nzbdrone.db -O /home/media/.config/Radarr/nzbdrone.db &&
wget https://raw.githubusercontent.com/ahuacate/radarr/master/backup/config.xml -O /home/media/.config/Radarr/config.xml
chown 1605:65605 /home/media/.config/Radarr/nzbdrone.db &&
chown 1605:65605 /home/media/.config/Radarr/config.xml &&
sudo systemctl restart radarr.service
```

### 9.10 Setup Radarr
Browse to http://192.168.50.116:7878 to start using Radarr.

Thats it. Now go and complete Steps [2.03 (B) Configure Indexers](https://github.com/ahuacate/radarr#203-configure-indexers), [2.04 (A) Configure Download Client](https://github.com/ahuacate/radarr#204-configure-download-clients) and [2.06 Configure General](https://github.com/ahuacate/radarr#206-configure-general).

---

## 10.00 Lidarr LXC - Ubuntu 18.04
Lidarr is a music collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new tracks from your favorite artists and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

### 10.01 Create a Ubuntu 18.04 LXC for Lidarr
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
pct create 117 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname lidarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.117/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music --mp1 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads --mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp3 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 117 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname lidarr --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.117/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 10.02 Setup Lidarr Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 10.1 then you have no Moint Points.

Please note your Proxmox Radarr LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 117 -mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music &&
pct set 117 -mp1 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads &&
pct set 117 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
pct set 117 -mp3 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

### 10.03 Unprivileged container mapping - Ubuntu 18.04
To change the Lidarr container mapping we change the container UID and GID in the file `/etc/pve/lxc/117.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/117.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

### 10.04 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04
First start LXC 117 (lidarr) with the Proxmox web interface go to `typhoon-01` > `117 (lidarr)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 10.05 Container Update &  Upgrade - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
apt-get update &&
apt-get upgrade -y
```

### 10.06 Create new "media" user - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -m media &&
usermod -s /bin/bash media
```
Note: This time we create a home folder for user media - required by Lidarr.

### 10.07 Install Lidarr
Go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following::

```
sudo apt-get update -y &&
sudo apt-get install -y unzip &&
sudo apt install gnupg ca-certificates -y &&
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &&
echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list &&
sudo apt update -y &&
sudo apt install mono-devel curl -y &&
cd /opt &&
sudo curl -L -O $( curl -s https://api.github.com/repos/lidarr/Lidarr/releases | grep linux.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) &&
sudo tar -xvzf Lidarr.*.*.linux.tar.gz &&
sudo rm *.linux.tar.gz &&
sudo chown -R 1605:65605 /opt/Lidarr &&
sudo apt-get install libchromaprint-tools -y
```

### 10.08 Create Lidarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Lidarr Daemon
After=network.target

[Service]
# Change the user and group variables here.
User=media
Group=medialab

Type=simple

# Change the path to Radarr or mono here if it is in a different location for you.
ExecStart=/usr/bin/mono --debug /opt/Lidarr/Lidarr.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/lidarr.service &&
sleep 2 &&
sudo systemctl enable lidarr.service &&
sleep 2 &&
sudo systemctl start lidarr.service
```

### 10.09 Setup Lidarr
Browse to http://192.168.50.117:8686 to start using Lidarr.

---

## 11.00 Lazylibrarian LXC - Ubuntu 18.04
LazyLibrarian is a program available for Linux that is used to follow authors and grab metadata for all your digital reading needs. It uses a combination of Goodreads Librarything and optionally GoogleBooks as sources for author info and book info. It’s nice to be able to have all of our book in digital form since books are extremely heavy and take up a lot of space, which we are already lacking in the bus.

### 11.01 Create a Ubuntu 18.04 LXC for Lazylibrarian
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`118`|
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
pct create 118 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname lazy --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.118/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-audio,mp=/mnt/audio --mp1 /mnt/pve/cyclone-01-books,mp=/mnt/books --mp2 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads --mp3 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp4 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 118 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname lazy --cpulimit 1 --cpuunits 1024 --memory 1024 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.118/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 11.02 Setup Lazylibrarian Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 11.1 then you have no Moint Points.

Please note your Proxmox Lazylibrarian (lazy) LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 118 -mp0 /mnt/pve/cyclone-01-audio,mp=/mnt/audio &&
pct set 118 -mp1 /mnt/pve/cyclone-01-books,mp=/mnt/books
pct set 118 -mp2 /mnt/pve/cyclone-01-downloads,mp=/mnt/downloads &&
pct set 118 -mp3 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
pct set 118 -mp4 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

### 11.03 Unprivileged container mapping - Ubuntu 18.04
To change the LazyLibrarian container mapping we change the container UID and GID in the file `/etc/pve/lxc/118.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/118.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

### 11.04 Create Lazylibrarian content folders on your NAS
To create Lazylibrarian content folders on your NAS use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
mkdir -p /mnt/pve/cyclone-01-audio/audiobooks &&
chown 1605:65605 /mnt/pve/cyclone-01-audio/audiobooks
```

### 11.05 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04
First start LXC 118 (lazy) with the Proxmox web interface go to `typhoon-01` > `118 (lazy)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `118 (lazy)` > `>_ Shell` and type the following:
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 11.06 Container Update &  Upgrade - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
apt-get update &&
apt-get upgrade -y
```

### 11.07 Create new "media" user - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -M media &&
usermod -s /bin/bash media
```

### 11.08 Install Lazylibrarian
Go to the Proxmox web interface `typhoon-01` > `118 (lazy)` > `>_ Shell` and type the following:

```
sudo apt-get update -y &&
sudo apt-get install git-core python3 -y &&
sudo apt install python3-pip -y &&
sudo apt-get install libffi-dev -y &&
pip3 install pyopenssl &&
pip3 install urllib3 &&
cd /opt &&
sudo git clone https://gitlab.com/LazyLibrarian/LazyLibrarian.git &&
sudo chown -R 1605:65605 /opt/LazyLibrarian
```

### 11.09 Create Lazylibrarian Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `118 (lazy)` > `>_ Shell` and type the following:
```
sudo echo -e "[Unit]
Description=LazyLibrarian

[Service]
ExecStart=/usr/bin/python3 /opt/LazyLibrarian/LazyLibrarian.py --daemon --config /opt/LazyLibrarian/lazylibrarian.ini --datadir /opt/LazyLibrarian/.lazylibrarian --nolaunch --quiet
GuessMainPID=no
Type=forking
User=media
Group=medialab
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/lazy.service &&
sleep 2 &&
sudo systemctl enable lazy.service &&
sleep 2 &&
sudo systemctl restart lazy.service
```

### 11.10 Setup Lazylibrarian
Browse to http://192.168.50.118:5299 to start using Lazylibrarian (aka lazy).

Thats it. Now go and complete [LazyLibrarian Build](https://github.com/ahuacate/lazylibrarian/blob/master/README.md#lazylibrarian-build) for your first time build **OR** use the restore instructions [3.00 Restore Lazylibrarian backup](https://github.com/ahuacate/lazylibrarian/blob/master/README.md#300-restore-lazylibrarian-backup).


## 12.00 Ombi LXC - Ubuntu 18.04
Ombi is a self-hosted web application that automatically gives your shared Jellyfin users the ability to request content by themselves! Ombi can be linked to multiple TV Show and Movie DVR tools to create a seamless end-to-end experience for your users. 

### 12.01 Create a Ubuntu 18.04 LXC for Lazylibrarian
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`119`|
| Hostname |`ombi`|
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
| IPv4/CIDR |`192.168.50.119/24`|
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
pct create 119 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname ombi --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.119/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp1 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 119 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname ombi --cpulimit 1 --cpuunits 1024 --memory 1024 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.119/24,type=veth --ostype ubuntu --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```

### 12.02 Setup Ombi Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 12.1 then you have no Moint Points.

Please note your Proxmox Ombi (lazy) LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 119 -mp0 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
pct set 119 -mp1 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

### 12.03 Unprivileged container mapping - Ubuntu 18.04
To change the Ombi container mapping we change the container UID and GID in the file `/etc/pve/lxc/119.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
# User media | Group medialab
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e medialab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/119.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
```

### 12.04 Ubuntu fix to avoid prompt to restart services during "apt apgrade" - Ubuntu 18.04
First start LXC 119 (ombi) with the Proxmox web interface go to `typhoon-01` > `119 (ombi)` > `START`. Then with the Proxmox web interface go to `typhoon-01` > `119 (ombi)` > `>_ Shell` and type the following:
```
sudo apt-get -y install debconf-utils &&
sudo debconf-get-selections | grep libssl1.0.0:amd64 &&
bash -c "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections"
```

### 12.05 Container Update &  Upgrade - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `119 (ombi)` > `>_ Shell` and type the following:
```
apt-get update &&
apt-get upgrade -y
```

### 12.06 Create new "media" user - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `119 (ombi)` > `>_ Shell` and type the following:
```
groupadd -g 65605 medialab &&
useradd -u 1605 -g medialab -M media &&
usermod -s /bin/bash media
```

### 12.07 Create Ombi content folders on your NAS
To create Ombi backup folders on your NAS use the web interface go to the Proxmox web interface `typhoon-01` > `119 (ombi)` > `>_ Shell` and type the following:
```
mkdir -p /mnt/backup/ombi &&
chown 1605:65605 /mnt/backup/ombi
```

### 12.08 Configuring Ombi machine locales - Ubuntu 18.04
The default locale for the system environment must be: en_US.UTF-8. To set the default locale on your machine go to the Proxmox web interface go to `typhoon-01` > `119 (ombi)` > `>_ Shell` and type the following:

```
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen &&
locale-gen

#echo -e "LANG=en_US.UTF-8
#LC_ALL=en_US.UTF-8" > /etc/default/locale &&
#sudo locale-gen en_US.UTF-8 &&
#sudo reboot
```

### 12.09 Install Ombi
Go to the Proxmox web interface `typhoon-01` > `119 (ombi)` > `>_ Shell` and type the following:

```
# Update
sudo apt update -y &&
# Install gnupg
sudo apt install gnupg -y &&
# Add the apt repository to the apt sources list
echo "deb [arch=amd64,armhf] http://repo.ombi.turd.me/stable/ jessie main" | sudo tee "/etc/apt/sources.list.d/ombi.list" &&
# Install Ombi keys
wget -qO - https://repo.ombi.turd.me/pubkey.txt | sudo apt-key add - &&
# Update and Install Ombi
sudo apt update -y && sudo apt install ombi -y &&
sudo chown -R 1605:65605 /opt/Ombi
```

### 12.10 Create Ombi Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `119 (ombi)` > `>_ Shell` and type the following:
```
sudo echo -e "[Unit]
Description=Ombi - PMS Requests System
After=network-online.target

[Service]
User=media
Group=medialab
WorkingDirectory=/opt/Ombi/
ExecStart=/opt/Ombi/Ombi
Type=simple
TimeoutStopSec=30
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/ombi.service &&
sleep 2 &&
sudo systemctl enable ombi.service &&
sleep 2 &&
sudo systemctl restart ombi.service
```

### 12.11 Setup Ombi
Browse to http://192.168.50.119:5000 to start using Ombi.
