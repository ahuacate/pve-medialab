<h1>PVE Medialab</h1>

This guide will help you create a suite of PVE CT's and applications for building a Home Media solution.

As with all our guides, we have an Easy Script to automate CT creation through to the installation of software.

But the first step is to check your network and hardware prerequisite requirements before running our Easy Script. It's important you first read and follow our prerequisite guide.

**Prerequisites**

Network Prerequisites:
- [ ] Layer 2/3 Network Switches

PVE Host Prerequisites:
- [x] PVE Host is configured to our [build](https://github.com/ahuacate/pve-host-setup)
- [x] PVE Host Backend Storage mounted to your NAS
	- nas-0X-backup
	- nas-0X-books
	- nas-0X-downloads
	- nas-0X-music
	- nas-0X-photo
	- nas-0X-transcode
	- nas-0X-video
	
	You must have a running network File Server (NAS) with ALL of the above NFS and/or CIFS backend share points configured on your PVE host pve-01.

Optional Prerequisites:
- [ ] pfSense with working OpenVPN Gateways VPNGATE-LOCAL (VLAN30) and VPNGATE-WORLD (VLAN40).

<h4>Easy Scripts</h4>
Easy Scripts are based on bash scripting. Simply `Cut & Paste` our Easy Script command into your terminal window, press `Enter` and follow the prompts and terminal instructions. But PLEASE first read our guide so you fully understand the input requirements.

Our Easy Scripts assumes your network is VLAN ready. If not, simply decline the Easy Script prompt to accept our default settings ( i.e Proceed with our Easy Script defaults (recommended) [y/n]? enter 'n' ). You can then set your own PVE container variables such as IP address.
<hr>

<h4>Table of Contents</h4>
<!-- TOC -->

- [1. About our MediaLab CT Applications](#1-about-our-medialab-ct-applications)
    - [1.1. Unprivileged CTs and File Permissions](#11-unprivileged-cts-and-file-permissions)
        - [1.1.1. Unprivileged Container Mapping - medialab GUID](#111-unprivileged-container-mapping---medialab-guid)
        - [1.1.2. Allow a CT to perform mapping on your PVE host](#112-allow-a-ct-to-perform-mapping-on-your-pve-host)
        - [1.1.3. MediaLab CTs use common UID and GUID](#113-medialab-cts-use-common-uid-and-guid)
- [2. Jellyfin CT](#2-jellyfin-ct)
    - [2.1. Installation](#21-installation)
    - [2.2. Setup Jellyfin](#22-setup-jellyfin)
- [3. NZBget LXC](#3-nzbget-lxc)
    - [3.1. Installation](#31-installation)
    - [3.2. Setup NZBget](#32-setup-nzbget)
- [4. Deluge LXC](#4-deluge-lxc)
    - [4.1. Installation](#41-installation)
    - [4.2. Setup Deluge](#42-setup-deluge)
- [5. Jackett LXC](#5-jackett-lxc)
    - [5.1. Installation](#51-installation)
    - [5.2. Setup Jackett](#52-setup-jackett)
- [6. Flexget LXC](#6-flexget-lxc)
    - [6.1. Easy Script installer](#61-easy-script-installer)
    - [6.2. Setup Flexget](#62-setup-flexget)
    - [6.3. FileBot Installation](#63-filebot-installation)
        - [6.3.1. Create FileBot `Home` Folder](#631-create-filebot-home-folder)
        - [6.3.2. Install FileBot](#632-install-filebot)
        - [6.3.3. Register and Activate FileBot](#633-register-and-activate-filebot)
        - [6.3.4. Setup FileBot](#634-setup-filebot)
- [7. Sonarr LXC](#7-sonarr-lxc)
    - [7.1. Installation](#71-installation)
    - [7.2. Setup Sonarr](#72-setup-sonarr)
    - [7.3. Radarr LXC](#73-radarr-lxc)
    - [7.4. Installation](#74-installation)
    - [7.5. Setup Radarr](#75-setup-radarr)
- [8. Lidarr LXC](#8-lidarr-lxc)
    - [8.1. Installation](#81-installation)
    - [8.2. Setup Lidarr](#82-setup-lidarr)
- [9. Ahuabooks LXC](#9-ahuabooks-lxc)
    - [9.1. Installation](#91-installation)
    - [9.2. Setup Ahuabooks](#92-setup-ahuabooks)

<!-- /TOC -->
<hr>

# 1. About our MediaLab CT Applications
All our MediaLab PVE CTs are built using the PVE Ubuntu 20.10 template.

Shared storage (NAS) is via CT bind mounts with your PVE host(s). All our MediaLab CT applications use our custom Linux User `media` and Group `medialab`.

For the Radarr, Sonarr, and Lidarr an out-of-the-box setting preset file is included. Go to the application WebGUI `System` > `Backup` and restore the backup filename:

> radarr_backup_v3.2.2.0000_0000.00.00_00.00.00.zip

Always test IP connectivity after installing all the Medialab Apps. The API should all be valid and working.

## 1.1. Unprivileged CTs and File Permissions
With unprivileged CT containers, you will have issues with UIDs (user id) and GUIDs (group id) permissions with bind-mounted shared data. In Proxmox UIDs and GUIDs are mapped to a different number range than on the host machine, usually, root (uid 0) became uid 100000, 1 will be 100001 and so on.

This means every CT file and directory will be mapped to "nobody" (uid 65534). This isn't acceptable for host mounted shared data resources. For shared data, we want to access the directory with the same, unprivileged, UID as is being used on all other CTs under the same user name.

Our default PVE Users (UID) and Groups (GUID) in all our MediaLab, HomeLab and PrivateLab CTs are common.

*  user `media` (uid 1605) and group `medialab` (gid 65605) accessible to unprivileged LXC containers (i.e JellyFin, NZBGet, Deluge, Sonarr, Radarr, LazyLibrarian, FlexGet);
*  user `home` (uid 1606) and group `homelab` (gid 65606) accessible to unprivileged LXC containers (i.e Syncthing, Nextcloud, Unifi);
*  user `private` (uid 1607) and group `privatelab` (gid 65606) accessible to unprivileged CT containers (i.e all things private).

> Because some people use Synology DiskStations where new Group ID's are in ranges above 65536, outside of Proxmox ID map range, we must pass through our `medialab` (GUID 65605), `homelab` (GUID 65606) and `privatelab` (GUID 65607) Group GUIDs mapped 1:1.

Our fix is done in three stages in our Easy Scripts when you create any new MediaLab application CT.

### 1.1.1. Unprivileged Container Mapping - medialab GUID
To change a PVE containers mapping we change the PVE container UID and GUID in the file `/etc/pve/lxc/container-id.conf` after our Easy Script creates a new MediaLab application CT.
```
# Our CT mapping in /etc/pve/lxc/container-id.conf

lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
# Below are our NAS Group GUIDs (i.e medialab,homelab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100
```
The above change is done automatically in our Easy Script.

### 1.1.2. Allow a CT to perform mapping on your PVE host
A PVE CT has to be allowed to perform mapping on a PVE host. Since CTs create new containers using root, we have to allow root to use these new UIDs in the new CT.

To achieve this we **add** lines to `/etc/subuid` (users) and `/etc/subgid` (groups). We define two ranges:

1.	One where the system IDs (i.e root uid 0) of the container can be mapped to an arbitrary range on the host for security reasons; and,
2.  Another where Synology GUIDs above 65536 of the container can be mapped to the same GUIDs on a PVE host. That's why we have the following lines in the /etc/subuid and /etc/subgid files.

```
# /etc/subuid
root:65604:100
root:1605:1

# /etc/subgid
root:65604:100
root:100:1
```

The above edits add an ID map range from 65604 > 65704 in the container to the same range on the PVE host. Next ID maps GUID 100 (default Linux users group) and UID 1605 (username media) on the container to the same range on the host.

The above edit is done automatically in our Easy Script.

### 1.1.3. MediaLab CTs use common UID and GUID
Our PVE User `media` and Group `medialab` are the defaults in all our MediaLab CTs. This means all new files created by our MediaLab CTs have a common UID and GUID so NAS file creation, ownership and access permissions are fully maintained within the Group `medialab`.

The Linux User and Group settings we use in all MediaLab CTs are:

(A) User media without a Home folder
```
groupadd -g 65605 medialab
useradd -u 1605 -g medialab -M media
usermod -s /bin/bash media
```
(B) User media with a Home folder
```
groupadd -g 65605 medialab
useradd -u 1605 -g medialab -m media
usermod -s /bin/bash media
```
The above change is done automatically in our Easy Script.

<hr>

# 2. Jellyfin CT

Jellyfin is a Free Software Media System that puts you in control of managing and streaming your media. Jellyfin is an alternative to the proprietary Emby and Plex to provide media from a dedicated server to end-user devices via multiple apps. 

Jellyfin is descended from Emby's 3.5.2 release and ported to the .NET Core framework to enable full cross-platform support. There are no strings attached, no premium licenses or features, and no hidden agendas: and at the time of writing this media server software seems like the best available solution (and is free).

## 2.1. Installation

Our Easy Script will create your Ubuntu Jellyfin CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_jellyfin_installer.sh)"
```

Follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.


## 2.2. Setup Jellyfin
In your web browser URL type `http://192.168.50.111:8096` and the applications configuration wizard page will appear. Detailed configuration instructions are available [here](https://github.com/ahuacate/jellyfin).

---

# 3. NZBget LXC
NZBGet is a binary downloader, which downloads files from Usenet based on the information given in nzb-files.

NZBGet is written in C++ and is known for its extraordinary performance and efficiency.

## 3.1. Installation
Our Easy Script will create your Ubuntu Jellyfin CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_nzbget_installer.sh)"
```

Follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.

## 3.2. Setup NZBget
In your web browser URL type, `http://192.168.30.112:6789` and the application's web frontend will appear. Detailed configuration instructions are available [here](https://github.com/ahuacate/nzbget).

---

# 4. Deluge LXC
Deluge is lightweight, free software, cross-platform BitTorrent client.

## 4.1. Installation
Our Easy Script will create your Ubuntu Deluge CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_deluge_installer.sh)"
```

Follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.

## 4.2. Setup Deluge
In your web browser URL type `http://192.168.30.113:8112` and the application's web frontend page will appear. Detailed configuration instructions are available [here](https://github.com/ahuacate/deluge).

---

# 5. Jackett LXC
Jackett works as a proxy server: it translates queries from apps (Sonarr, Radarr, Lidarr etc) into tracker-site-specific HTTP queries, parses the HTML response, then sends results back to the requesting software. This allows for getting recent uploads (like RSS) and performing searches. Jackett is a single repository of maintained indexer scraping & translation logic - removing the burden from other apps.

## 5.1. Installation
Our Easy Script will create your Ubuntu Jackett CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_jackett_installer.sh)"
```

Follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.

## 5.2. Setup Jackett
In your web browser URL type `http://192.168.50.120:9117` and the application's web frontend will appear. Detailed configuration instructions are available [here](https://github.com/ahuacate/jackett).

---

# 6. Flexget LXC
UNDER DEVELOPMENT
<!-- FlexGet is a multipurpose automation tool for all of your media. Support for torrents, nzbs, podcasts, comics, TV, movies, RSS, HTML, CSV, and more. 

Filebot is installed to rename all Flexget downloaded media. You will require a Filebot license.

## 6.1. Easy Script installer
Our Easy Script will create your Ubuntu Flexget CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_flexget_installer.sh)"
```

Simply follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.

## 6.2. Setup Flexget 
Instructions to setup Flexget are [here](https://github.com/ahuacate/flexget).

## 6.3. FileBot Installation
FileBot is a tool for organizing and renaming your Movies, TV Shows and Anime as well as fetching subtitles and artwork. It is the naming resolver for all Flexget downloaded media.

Filebot seems much better at resolving/guessing media which doesn't adhere to the TheTVdB or IMdB named convention. Its the best renaming solution for series like 60 Minutes and general documentaries.

Best to use the fully paid licensed version of this software - it's worth it.

Filebot is installed on the Deluge LXC container.

### 6.3.1. Create FileBot `Home` Folder
Filebot is installed on the Deluge LXC container. So using the Proxmox web interface go to `typhoon-01` > `113 (deluge)` > `>_ Shell` and type the following:

```
sudo mkdir /home/media/.filebot; sudo chown -R 1605:65605 /home/media/.filebot
```

### 6.3.2. Install FileBot
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

### 6.3.3. Register and Activate FileBot
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

### 6.3.4. Setup FileBot 
FileBot works inconjunction with Flexget. So instructions to setup FileBot are [HERE](https://github.com/ahuacate/flexget#flexget-build).  -->

---

# 7. Sonarr LXC
Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favourite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

## 7.1. Installation
Our Easy Script will create your Ubuntu Sonarr CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_sonarr_installer.sh)"
```

Follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.

## 7.2. Setup Sonarr
In your web browser URL type `http://192.168.50.115:8989`. The Sonarr WebGUI will appear.

An out-of-the-box Sonarr setting preset file is included. Go to Sonarr WebGUI `System` > `Backup` and restore the backup filename ( use the restore icon to the right of the backup file ):

*  *sonarr_backup_vX.X.X.0000_0000.00.00_00.00.00.zip*

---

## 7.3. Radarr LXC
Radarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favourite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

## 7.4. Installation
Our Easy Script will create your Ubuntu Radarr CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_radarr_installer.sh)"
```

Follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.

## 7.5. Setup Radarr
In your web browser URL type `http://192.168.50.116:7878 `. The Radarr WebGUI will appear.

An out-of-the-box Radarr setting preset file is included. Go to Radarr WebGUI `System` > `Backup` and restore the backup filename ( use the restore icon to the right of the backup file ):

*  *radarr_backup_vX.X.X.0000_0000.00.00_00.00.00.zip*

---

# 8. Lidarr LXC
Lidarr is a music collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new tracks from your favourite artists and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

## 8.1. Installation
Our Easy Script will create your Ubuntu Lidarr CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_lidarr_installer.sh)"
```

Follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.

## 8.2. Setup Lidarr
In your web browser URL type `http://192.168.50.117:8686`. The Lidarr WebGUI will appear.

An out-of-the-box Lidarr setting preset file is included. Go to Lidarr WebGUI `System` > `Backup` and restore the backup filename ( use the restore icon to the right of the backup file ):

*  *lidarr_backup_vX.X.X.0000_0000.00.00_00.00.00.zip*

---

# 9. Ahuabooks LXC
Ahuabooks is a suite of software for managing your ebook, audiobook, podcast and magazine requirements.

The software suite includes:
*  Lazylibrarian
*  Calibre
*  Calibre-web (frontend for Calibre)
*  Booksonic

## 9.1. Installation
Our Easy Script will create your Ubuntu Ahuabooks CT. Go to your Proxmox PVE host (i.e pve-01) management WebGUI CLI `>_ Shell` or SSH terminal and type the following (cut & paste):

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/master/pve_medialab_ct_ahuabooks_installer.sh)"
```

Follow our Easy Script installation prompts. We recommend you accept our defaults and application settings to create a fully compatible Medialab build suite.

## 9.2. Setup Ahuabooks
In your web browser URL type to connect and the applications web frontend will appear.
> **Lazylibrarian** `http://192.168.50.118:5299`
> **Calibre-web** `http://192.168.50.118:8083`
> **Booksonic** `http://192.168.50.118:4040`

Detailed configuration instructions are available [here](https://github.com/ahuacate/ahuabooks).

---