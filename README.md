# Proxmox-LXC-Media
The following is for creating our Media family of LXC containers.

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

## About LXC Media Installations
CentosOS7 is my preferred linux distribution but for media software Ubuntu seems to be the most supported linux distribution. I have used Ubuntu 18.04 for all media LXC's.

Proxmox itself ships with a set of basic templates and to download a prebuilt OS distribution use the graphical interface `typhoon-01` > `local` > `content` > `templates` and select and download `centos-7-default` and `ubuntu-18.04-standard` templates.

## 1.00 Unprivileged LXC Containers and file permissions
With unprivileged LXC containers you will have issues with UIDs (user id) and GIDs (group id) permissions with bind mounted shared data. All of the UIDs and GIDs are mapped to a different number range than on the host machine, usually root (uid 0) became uid 100000, 1 will be 100001 and so on.

However you will soon realise that every file and directory will be mapped to "nobody" (uid 65534). This isn't acceptable for host mounted shared data resources. For shared data you want to access the directory with the same - unprivileged - uid as it's using on other LXC machines.

The fix is to change the UID and GID mapping.

So in our build we will create a new user/group called `media` and make uid 1005 and gid 1005 accessible to unprivileged LXC containers used by user/group media (i.e NZBGet, Deluge, Sonarr, Radarr, LazyLibrarian, Flexget). This is achieved in three parts during the course of creating your new media LXC's.

### 1.01 Unprivileged container mapping
To change a container mapping we change the container UID and GID in the file `/etc/pve/lxc/container-id.conf` after you create a new container. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:
```
echo -e "lxc.idmap: u 0 100000 1005
lxc.idmap: g 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: g 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 1006 101006 64530" >> /etc/pve/lxc/container-id.conf
```
### 1.02 Allow a LXC to perform mapping on the Proxmox host
Next we have to allow LXC to actually do the mapping on the host. Since LXC creates the container using root, we have to allow root to use these new uids in the container.
To achieve this we need to **add** the line `root:1005:1` to the files `/etc/subuid` and `/etc/subgid`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following (NOTE: Only needs to be performed ONCE on each host (i.e typhoon-01/02/03)):
```
echo -e "root:1005:1" >> /etc/subuid
```
Then we need to also **add** the line `root:1005:1` to the file `/etc/subuid`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:
```
echo -e "root:1005:1" >> /etc/subgid
```
Note, we **add** these lines not replace any default lines. My /etc/subuid and /etc/subgid both look identical:
```
root:100000:65536
root:1005:1
```

### 1.03 Create a newuser `media` in a LXC
We need to create a newuser in all LXC's which require access to shared data (ZFS share typhoon-share/downloads). After logging into the LXC container type the following:

(A) To create a user without a Home folder
```
groupadd -g 1005 media &&
useradd -u 1005 -g media -M media
```
(B) To create a user with a Home folder
```
groupadd -g 1005 media &&
useradd -u 1005 -g media -m media
```

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
pct create 111 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname jellyfin --cpulimit 1 --cpuunits 1024 --memory 4096 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.111/24,type=veth --ostype centos --rootfs typhoon-share:20 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music --mp1 /mnt/pve/cyclone-01-photo,mp=/mnt/photo --mp2 /mnt/pve/cyclone-01-transcode,mp=/mnt/transcode --mp3 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp4 /mnt/pve/cyclone-01-audio,mp=/mnt/audio --mp5 /mnt/pve/cyclone-01-books,mp=/mnt/books
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 111 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname jellyfin --cpulimit 1 --cpuunits 1024 --memory 4096 --net0 name=eth0,bridge=vmbr0,tag=50,firewall=1,gw=192.168.50.5,ip=192.168.50.111/24,type=veth --ostype centos --rootfs typhoon-share:20 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
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
```

### 2.03 Configure and Install VAAPI - Ubuntu 18.04
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
### 2.04 Create a rc.local
For FFMPEG to work we must create a script to `chmod 666 /dev/dri/renderD128` everytime the Proxmox host reboots. Now using the web interface go to Proxmox CLI `Datacenter` > `typhoon-01/02` >  `>_ Shell` and type the following:
```
echo '#!/bin/sh -e
/bin/chmod 666 /dev/dri/renderD128
exit 0' > /etc/rc.local &&
chmod +x /etc/rc.local &&
bash /etc/rc.local
```

### 2.05 Grant Jellyfin LXC Container access to the Proxmox host video device - Ubuntu 18.04
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

### 2.06 Install Jellyfin - Ubuntu 18.04
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

### 2.08 Check your Jellyfin Installation
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
pct create 112 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname nzbget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.112/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /typhoon-share/downloads,mp=/mnt/downloads --mp1 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
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
pct set 112 -mp0 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 112 -mp1 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

### 3.04 Unprivileged container mapping - Ubuntu 18.04
To change the NZBGet container mapping we change the container UID and GID in the file `/etc/pve/lxc/112.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
echo -e "lxc.idmap: u 0 100000 1005
lxc.idmap: g 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: g 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 1006 101006 64530" >> /etc/pve/lxc/112.conf
```

### 3.05 Create NZBGet download folders on your ZFS typhoon-share - Ubuntu 18.04
To create the NZBGet download folders use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
mkdir -p {/typhoon-share/downloads/nzbget/nzb,/typhoon-share/downloads/nzbget/queue,/typhoon-share/downloads/nzbget/tmp,/typhoon-share/downloads/nzbget/intermediate,/typhoon-share/downloads/nzbget/completed,/typhoon-share/downloads/nzbget/completed/lazy,/typhoon-share/downloads/nzbget/completed/series,/typhoon-share/downloads/nzbget/completed/movies,/typhoon-share/downloads/nzbget/completed/music} &&
chown 1005:1005 {/typhoon-share/downloads/nzbget/nzb,/typhoon-share/downloads/nzbget/queue,/typhoon-share/downloads/nzbget/tmp,/typhoon-share/downloads/nzbget/intermediate,/typhoon-share/downloads/nzbget/completed,/typhoon-share/downloads/nzbget/completed/lazy,/typhoon-share/downloads/nzbget/completed/series,/typhoon-share/downloads/nzbget/completed/movies,/typhoon-share/downloads/nzbget/completed/music}
```

### 3.06 Create new "media" user - Ubuntu 18.04
First start LXC 112 (nzbget) with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:
```
groupadd -g 1005 media &&
useradd -u 1005 -g media -M media
```

### 3.07 Install NZBget - Ubuntu 18.04
This is easy. First start LXC 112 (nzbget) with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `112 (nzbget)` > `>_ Shell` and type the following:

```
wget https://nzbget.net/download/nzbget-latest-bin-linux.run -P /tmp &&
sh /tmp/nzbget-latest-bin-linux.run --destdir /opt/nzbget &&
rm /tmp/nzbget-latest-bin-linux.run &&
sudo chown -R media:media /opt/nzbget
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
chown 1005:1005 /opt/nzbget/nzbget.conf
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
Group=media
Type=forking
ExecStart=/opt/nzbget/nzbget -D
ExecStop=/opt/nzbget/nzbget -Q
ExecReload=/opt/nzbget/nzbget -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/nzbget.service &&
sudo systemctl enable nzbget &&
sudo systemctl start nzbget &&
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
pct create 113 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 2 --hostname deluge --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.113/24,type=veth --ostype ubuntu --rootfs typhoon-share:8 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password --mp0 /typhoon-share/downloads,mp=/mnt/downloads --mp1 /mnt/pve/cyclone-01-video,mp=/mnt/video
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
pct set 113 -mp0 /typhoon-share/downloads,mp=/mnt/downloads
pct set 113 -mp1 /mnt/pve/cyclone-01-video,mp=/mnt/video
```

### 4.04 Unprivileged container mapping - Ubuntu 18.04
To change the Deluge container mapping we change the container UID and GID in the file /etc/pve/lxc/113.conf. Simply use Proxmox CLI typhoon-01 > >_ Shell and type the following:
```
echo -e "lxc.idmap: u 0 100000 1005
lxc.idmap: g 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: g 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 1006 101006 64530" >> /etc/pve/lxc/113.conf
```

### 4.05 Create Deluge download folders on your ZFS typhoon-share - Ubuntu 18.04
To create the Deluge download folders use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
mkdir -m 775 -p {/typhoon-share/downloads/deluge/incomplete,/typhoon-share/downloads/deluge/complete,/typhoon-share/downloads/deluge/complete/lazy,typhoon-share/downloads/deluge/complete/movies,typhoon-share/downloads/deluge/complete/series,typhoon-share/downloads/deluge/complete/music,/typhoon-share/downloads/deluge/autoadd} &&
chown 1005:1005 {/typhoon-share/downloads/deluge/incomplete,/typhoon-share/downloads/deluge/complete,/typhoon-share/downloads/deluge/complete/lazy,typhoon-share/downloads/deluge/complete/movies,typhoon-share/downloads/deluge/complete/series,typhoon-share/downloads/deluge/complete/music,/typhoon-share/downloads/deluge/autoadd}
```

### 4.06 Create new "media" user - Ubuntu 18.04

First start LXC 113 (deluge) with the Proxmox web interface go to typhoon-01 > 113 (deluge) > START.

Then with the Proxmox web interface go to typhoon-01 > 113 (deluge) > >_ Shell and type the following:

```
groupadd -g 1005 media &&
useradd -u 1005 -g media -m media
```
Note: This time we create a home folder for user media - required by Deluge.


### 4.07 Configuring host machine locales - Ubuntu 18.04
The default locale for the system environment must be: en_US.UTF-8. To set the default locale on your machine go to the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
echo -e "LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8" > /etc/default/locale &&
sudo locale-gen en_US.UTF-8 &&
sudo reboot
```
Your `113 (deluge)`container will reboot. So you will have to re-login into machine `113 (deluge)` to continue.

### 4.08 Install Deluge - Ubuntu 18.04
This is easy. First start LXC 113 (deluge) with the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
sudo apt-get update &&
sudo apt install subversion -y &&
sudo apt install software-properties-common -y &&
sudo add-apt-repository ppa:deluge-team/ppa -y &&
sudo apt-get update &&
sudo apt-get install deluged deluge-webui deluge-console -y
```
At the prompt `Configuring libssl1.1:amd64` select `<Yes>`.

### 4.09 Download Deluge Plugins and settings files - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
systemctl daemon-reload &&
su -c 'deluged' media &&
sleep 5 &&
pkill -9 deluged &&
wget --content-disposition https://forum.deluge-torrent.org/download/file.php?id=6306 -P /home/media/.config/deluge/plugins/ &&
wget  https://raw.githubusercontent.com/ahuacate/deluge/master/deluge-postprocess.sh -P /home/media/.config/deluge &&
chmod +rx /home/media/.config/deluge/deluge-postprocess.sh &&
chown 1005:1005 /home/media/.config/deluge/deluge-postprocess.sh &&
echo -e "flexget:9c67cf728b8c079c2e0065ee11cb3a9a6771420a:10
lazylibrarian:9c67cf728b8c079c2e0065ee11cb3a9a6771421a:10" >> /home/media/.config/deluge/auth &&
wget  https://raw.githubusercontent.com/ahuacate/deluge/master/label.conf -P /home/media/.config/deluge &&
wget  https://raw.githubusercontent.com/ahuacate/deluge/master/execute.conf -P /home/media/.config/deluge &&
wget  https://raw.githubusercontent.com/ahuacate/deluge/master/autoremoveplus.conf -P /home/media/.config/deluge &&
chown 1005:1005 {/home/media/.config/deluge/label.conf,/home/media/.config/deluge/execute.conf,/home/media/.config/deluge/autoremoveplus.conf,/home/media/.config/deluge/plugins/*.egg}
```

### 4.10 Create Deluge Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Deluge Client Daemon
Documentation=https://dev.deluge-torrent.org/
After=network-online.target

[Service]
User=media
Group=media
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

### 4.11 Final Configuring of Deluge - Ubuntu 18.04
Here we are going to use the deluge-console commands to configure Deluge Preferences and enable some Deluge Plugins.

Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
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

### 4.12 Create Deluge WebGUI Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Deluge Bittorrent Client Web Interface
Documentation=https://dev.deluge-torrent.org/
After=network-online.target deluge.service
Wants=deluge.service


[Service]
User=media
Group=media

Type=simple
Umask=027
ExecStart=/usr/bin/deluge-web
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/deluge-web.service &&
sudo systemctl enable deluge-web &&
sudo systemctl start deluge-web
```

### 4.13 Setup Deluge 
Browse to http://192.168.30.113:8112 to start using Deluge. Your Deluge default login details are password:deluge. Instructions to complete the setup of Deluge is [HERE]

---

## 5.00 Jackett LXC - Ubuntu 18.04
Jackett works as a proxy server: it translates queries from apps (Sonarr, Radarr, Lidarr etc) into tracker-site-specific http queries, parses the html response, then sends results back to the requesting software. This allows for getting recent uploads (like RSS) and performing searches. Jackett is a single repository of maintained indexer scraping & translation logic - removing the burden from other apps.

This is installed on the Deluge LXC container.

### 5.01 Install Jackett - Ubuntu 18.04
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

### 5.02 Create Jackett Service file - Ubuntu 18.04
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
User=media
Group=media
WorkingDirectory=/opt/Jackett
ExecStart=/opt/Jackett/jackett --NoRestart
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/jackett.service &&
sudo systemctl enable jackett &&
sudo systemctl start jackett
```
### 5.03 Download the latest Jackett Server configuration file & Indexers
With the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:
```
# Here we update the Jackett Server configuration file
sudo systemctl stop jackett &&
sleep 5 &&
wget -q https://raw.githubusercontent.com/ahuacate/jackett/master/ServerConfig.json -O /home/media/.config/Jackett/ServerConfig.json &&
chown 1005:1005 /home/media/.config/Jackett/ServerConfig.json &&
# Here we update the jacket indexers
mkdir -m 775 -p /home/media/.config/Jackett/Indexers &&
chown 1005:1005 /home/media/.config/Jackett/Indexers &&
svn checkout https://github.com/ahuacate/jackett/trunk/Indexers /home/media/.config/Jackett/Indexers &&
chown 1005:1005 {/home/media/.config/Jackett/Indexers/*.json,/home/media/.config/Jackett/Indexers/*.bak} &&
sudo systemctl restart jackett
```

### 5.04 Setup Jackett 
Browse to http://192.168.30.113:9117 to start using Jackett.

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
| CT ID |`115`|
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
pct create 114 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname flexget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.114/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=3 --password --mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video --mp1 /typhoon-share/downloads,mp=/mnt/downloads --mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp3 /mnt/pve/cyclone-01-audio,mp=/mnt/audio
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 114 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname flexget --cpulimit 1 --cpuunits 1024 --memory 2048 --nameserver 192.168.30.5 --searchdomain 192.168.30.5 --net0 name=eth0,bridge=vmbr0,tag=30,firewall=1,gw=192.168.30.5,ip=192.168.30.114/24,type=veth --ostype centos --rootfs typhoon-share:10 --swap 256 --unprivileged 1 --onboot 1 --startup order=2 --password
```


### 6.02 Setup Flexget Mount Points - Ubuntu 18.04

If you used Script (B) in Section 4.2 then you have no Moint Points.

Please note your Proxmox Flexget LXC MUST BE in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
pct set 114 -mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video &&
pct set 114 -mp1 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 114 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
pct set 114 -mp3 /mnt/pve/cyclone-01-audio,mp=/mnt/audio
```

### 6.03 Unprivileged container mapping - Ubuntu 18.04
To change the Flexget container mapping we change the container UID and GID in the file `/etc/pve/lxc/114.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
echo -e "lxc.idmap: u 0 100000 1005
lxc.idmap: g 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: g 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 1006 101006 64530" >> /etc/pve/lxc/114.conf
```

### 6.04 Create Flexget download folders on your ZFS typhoon-share - Ubuntu 18.04
To create Flexget download folders use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
mkdir -p {/typhoon-share/downloads/deluge/complete/flexget/series,/typhoon-share/downloads/deluge/complete/flexget/movies} &&
chown 1005:1005 {/typhoon-share/downloads/deluge/complete/flexget/series,/typhoon-share/downloads/deluge/complete/flexget/movies}
```

### 6.05 Create Flexget content folders on your NAS
To create Flexget content folders on your NAS use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
mkdir -p {/mnt/pve/cyclone-01-video/documentary/series,/mnt/pve/cyclone-01-video/documentary/movies,/mnt/pve/cyclone-01-video/documentary/unsorted}
```

### 6.06 Create new "media" user - Ubuntu 18.04
First start LXC 114 (nzbget) with the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
groupadd -g 1005 media &&
useradd -u 1005 -g media -m media
```

### 6.07 Configuring Flexget machine locales - Ubuntu 18.04
The default locale for the system environment must be: en_US.UTF-8. To set the default locale on your machine go to the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:

```
echo -e "LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8" > /etc/default/locale &&
sudo locale-gen en_US.UTF-8 &&
sudo reboot
```

### 6.08 Create Flexget `Home` Folder - Ubuntu 18.04
With the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
mkdir -m 775 -p /home/media/flexget &&
sudo chown -R media:media /home/media/flexget
```

### 6.09 Install Flexget - Ubuntu 18.04
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

Now we need libtorrent for our config.yml to work. Until I figure out which libtorrent package & dependencies are required the workaround is to install Deluge (but, not starting/running Deluge - no services). So with the Proxmox web interface go to `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:

```
sudo apt-get update &&
sudo apt install software-properties-common -y &&
sudo add-apt-repository ppa:deluge-team/stable -y &&
sudo apt-get update &&
sudo apt-get install deluged deluge-webui -y
```
### 6.10 Download the Flexget YAML Configuration Files
Your Flexget configuration files are pre-built and working. There are x files to download.

Download the Flexget YAML configuration file from GitHub. Go to the Proxmox web interface `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
wget https://raw.githubusercontent.com/ahuacate/flexget/master/config.yml -P /home/media/flexget &&
wget https://raw.githubusercontent.com/ahuacate/flexget/master/list-showrss.yml.yml -P /home/media/flexget &&
wget https://raw.githubusercontent.com/ahuacate/flexget/master/list-mvgroup.yml -P /home/media/flexget &&
wget https://raw.githubusercontent.com/ahuacate/flexget/master/list-documentarytorrents.yml -P /home/media/flexget &&
wget https://raw.githubusercontent.com/ahuacate/flexget/master/secrets.yml -P /home/media/flexget &&
```
The `secrets.yml` file requires you to enter your private user credentials and instructions are [HERE](https://github.com/ahuacate/flexget).

### 6.11 Create Flexget Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `114 (flexget)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Flexget Daemon
After=network.target

[Service]
Type=simple
User=media
Group=media
UMask=000
WorkingDirectory=/home/media/flexget
ExecStart=/usr/local/bin/flexget daemon start
ExecStop=/usr/local/bin/flexget daemon stop
ExecReload=/usr/local/bin/flexget daemon reload

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/flexget.service &&
sudo systemctl enable flexget &&
sudo systemctl start flexget
```

### 6.12 Setup Flexget 
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
sudo mkdir /home/media/.filebot; sudo chown -R media:media /home/media/.filebot
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

## 8.0 Sonarr LXC - Ubuntu 18.04
Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

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

### 8.3 Unprivileged container mapping - Ubuntu 18.04
To change the Sonarr container mapping we change the container UID and GID in the file `/etc/pve/lxc/115.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
echo -e "lxc.idmap: u 0 100000 1005
lxc.idmap: g 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: g 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 1006 101006 64530" >> /etc/pve/lxc/115.conf
```

### 8.4 Create new "media" user - Ubuntu 18.04
First start LXC 115 (sonarr) with the Proxmox web interface go to `typhoon-01` > `115 (sonarr)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:
```
groupadd -g 1005 media &&
useradd -u 1005 -g media -m media
```
Note: This time we create a home folder for user media - required by Sonarr.

### 8.5 Install Sonarr
Th following Sonarr installation recipe is from the official Sonarr website [HERE](https://sonarr.tv/#downloads-v3-linux-ubuntu). Please refer for the latest updates.

During the installation, you will be asked which user and group Sonarr must run as. It's important to choose these correctly to avoid permission issues with your media files. I suggest you keep the group named `media` and username `media` identical between your download client(s) and Sonarr. 

First start your Sonarr LXC and login. Then go to the Proxmox web interface `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:

```
sudo apt-get update -y &&
sudo apt install unzip -y &&
sudo apt install gnupg ca-certificates -y &&
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &&
sudo echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list &&
sudo apt update -y &&
sudo apt install mono-devel -y &&
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0xA236C58F409091A18ACA53CBEBFF6B99D9B78493 &&
echo "deb http://apt.sonarr.tv/ master main" | sudo tee /etc/apt/sources.list.d/sonarr.list &&
sudo apt update -y &&
sudo apt install nzbdrone -y &&
sudo chown -R media:media /opt/NzbDrone
```

### 8.6 Create Sonarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `115 (sonarr)` > `>_ Shell` and type the following:
```
sudo echo -e "[Unit]
Description=Sonarr Daemon
After=network.target

[Service]
User=media
Group=media

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

### 8.7 Update the Sonarr configuration base file
```
sudo systemctl stop sonarr.service &&
wget -q https://raw.githubusercontent.com/ahuacate/sonarr/master/config.xml -O /home/media/.config/NzbDrone/config.xml &&
sudo systemctl start sonarr.service
```

### 8.7 Install sonarr-episode-trimmer
A script for use with Sonarr that allows you to set the number of episodes of a show that you would like to keep.
Useful for shows that air daily. The script sorts the episodes you have for a show by the season and episode number, and then deletes the oldest episodes past the threshold you set.
```
mkdir 775 -p /home/media/.config/NzbDrone/custom-scripts &&
chown 1005:1005 /home/media/.config/NzbDrone/custom-scripts &&
wget https://gitlab.com/spoatacus/sonarr-episode-trimmer/raw/master/sonarr-episode-trimmer.py -P /home/media/.config/NzbDrone/custom-scripts &&
wget https://raw.githubusercontent.com/ahuacate/sonarr/master/sonarr-episode-trimmer/config -P /home/media/.config/NzbDrone/custom-scripts &&
chmod +rx /home/media/.config/NzbDrone/custom-scripts/sonarr-episode-trimmer.py &&
chown 1005:1005 /home/media/.config/NzbDrone/custom-scripts/*
```

### 8.7 Setup Sonarr
Browse to http://192.168.50.115:8989 to start using Sonarr.

---

## 8.0 Radarr LXC - Ubuntu 18.04
Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

### 8.1 Create a Ubuntu 18.04 LXC for Radarr
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

### 8.2 Setup Radarr Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 9.1 then you have no Moint Points.

Please note your Proxmox Radarr LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 116 -mp0 /mnt/pve/cyclone-01-video,mp=/mnt/video &&
pct set 116 -mp1 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 116 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

### 8.3 Unprivileged container mapping - Ubuntu 18.04
To change the Radarr container mapping we change the container UID and GID in the file `/etc/pve/lxc/116.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
echo -e "lxc.idmap: u 0 100000 1005
lxc.idmap: g 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: g 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 1006 101006 64530" >> /etc/pve/lxc/116.conf
```

### 8.4 Create new "media" user - Ubuntu 18.04
First start LXC 116 (radarr) with the Proxmox web interface go to `typhoon-01` > `116 (radarr)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:
```
groupadd -g 1005 media &&
useradd -u 1005 -g media -m media
```
Note: This time we create a home folder for user media - required by Radarr.

### 8.5 Install Radarr
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
sudo chown -R media:media /opt/Radarr
```
### 8.6 Create Radarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `116 (radarr)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
# Change the user and group variables here.
User=media
Group=media

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

### 8.7 Setup Radarr
Browse to http://192.168.50.116:7878 to start using Radarr.

---

## 8.0 Lidarr LXC - Ubuntu 18.04
Lidarr is a music collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new tracks from your favorite artists and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

Prerequisites are:
- [x] Allow a LXC to perform mapping on the Proxmox host as shown [HERE](https://github.com/ahuacate/proxmox-lxc/blob/master/README.md#12-allow-a-lxc-to-perform-mapping-on-the-proxmox-host)

### 8.1 Create a Ubuntu 18.04 LXC for Lidarr
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

### 8.2 Setup Lidarr Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 10.1 then you have no Moint Points.

Please note your Proxmox Radarr LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 117 -mp0 /mnt/pve/cyclone-01-music,mp=/mnt/music &&
pct set 117 -mp1 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 117 -mp2 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

### 8.3 Unprivileged container mapping - Ubuntu 18.04
To change the Lidarr container mapping we change the container UID and GID in the file `/etc/pve/lxc/117.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
echo -e "lxc.idmap: u 0 100000 1005
lxc.idmap: g 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: g 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 1006 101006 64530" >> /etc/pve/lxc/117.conf
```

### 8.5 Create new "media" user - Ubuntu 18.04
First start LXC 117 (lidarr) with the Proxmox web interface go to `typhoon-01` > `117 (lidarr)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
groupadd -g 1005 media &&
useradd -u 1005 -g media -m media
```
Note: This time we create a home folder for user media - required by Lidarr.

### 8.3 Install Lidarr
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
sudo chown -R media:media /opt/Lidarr
```
### 8.4 Create Lidarr Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `117 (lidarr)` > `>_ Shell` and type the following:
```
echo -e "[Unit]
Description=Lidarr Daemon
After=network.target

[Service]
# Change the user and group variables here.
User=media
Group=media

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

### 8.5 Setup Lidarr
Browse to http://192.168.50.117:8686 to start using Lidarr.

---

## 9.0 Lazylibrarian LXC - Ubuntu 18.04
LazyLibrarian is a program available for Linux that is used to follow authors and grab metadata for all your digital reading needs. It uses a combination of Goodreads Librarything and optionally GoogleBooks as sources for author info and book info. It’s nice to be able to have all of our book in digital form since books are extremely heavy and take up a lot of space, which we are already lacking in the bus.

### 9.1 Create a Ubuntu 18.04 LXC for Lazylibrarian
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

### 9.2 Setup Lazylibrarian Mount Points - Ubuntu 18.04
If you used **Script (B)** in Section 11.1 then you have no Moint Points.

Please note your Proxmox Lazylibrarian (lazy) LXC **MUST BE** in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
pct set 118 -mp0 /mnt/pve/cyclone-01-audio,mp=/mnt/audio &&
pct set 118 -mp1 /mnt/pve/cyclone-01-books,mp=/mnt/books
pct set 118 -mp2 /typhoon-share/downloads,mp=/mnt/downloads &&
pct set 118 -mp3 /mnt/pve/cyclone-01-backup,mp=/mnt/backup
```

### 9.4 Unprivileged container mapping - Ubuntu 18.04
To change the LazyLibrarian container mapping we change the container UID and GID in the file `/etc/pve/lxc/118.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
echo -e "lxc.idmap: u 0 100000 1005
lxc.idmap: g 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: g 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 1006 101006 64530" >> /etc/pve/lxc/118.conf
```

### 9.5 Create new "media" user - Ubuntu 18.04

First start LXC 112 (lazy) with the Proxmox web interface go to typhoon-01 > 118 (lazy) > START.

Then with the Proxmox web interface go to typhoon-01 > 118 (lazy) > >_ Shell and type the following:
```
groupadd -g 1005 media &&
useradd -u 1005 -g media -M media
```

### 9.6 Install Lazylibrarian
First start your Lazylibrarian LXC and login. Then go to the Proxmox web interface `typhoon-01` > `118 (lazy)` > `>_ Shell` and insert by cut & pasting the following:

```
sudo apt-get update -y &&
sudo apt-get install git-core python3 -y &&
sudo apt install python3-pip -y &&
sudo apt-get install libffi-dev -y &&
pip3 install pyopenssl &&
pip3 install urllib3 &&
cd /opt &&
sudo git clone https://gitlab.com/LazyLibrarian/LazyLibrarian.git &&
sudo chown -R 1005:1005 /opt/LazyLibrarian
```
### 9.4 Create Lazylibrarian Service file - Ubuntu 18.04
Go to the Proxmox web interface `typhoon-01` > `118 (lazy)` > `>_ Shell` and type the following:
```
sudo echo -e "[Unit]
Description=LazyLibrarian

[Service]
ExecStart=/usr/bin/python3 /opt/LazyLibrarian/LazyLibrarian.py --daemon --config /opt/LazyLibrarian/lazylibrarian.ini --datadir /opt/LazyLibrarian/.lazylibrarian --nolaunch --quiet
GuessMainPID=no
Type=forking
User=media
Group=media
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/lazy.service &&
sudo systemctl enable lazy.service &&
sudo systemctl restart lazy.service &&
sudo reboot
```

### 9.5 Setup Lazylibrarian
Browse to http://192.168.50.118:5299 to start using Lazylibrarian (aka lazy).

