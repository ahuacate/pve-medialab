<h1>PVE Medialab</h1>

Medialab focuses on everything related to Home Media, providing a range of PVE CT-based applications such as Sonarr, Radarr, Jellyfin, and more. In addition, it offers an Easy Script Installer and Toolbox that automates many of the tasks, accompanied by step-by-step instructions.

However, before you begin using Medialab, it's crucial to ensure that your network, hardware, and NAS setup meet the prerequisites outlined in our guide. It's essential to read and follow this guide before proceeding.

<h2>Prerequisites</h2>

**Network Prerequisites**
- [ ] Layer 2/3 Network Switches

**PVE Host Prerequisites**
- [x] PVE Host is configured to our [build](https://github.com/ahuacate/pve-host)
- [x] PVE Host Backend Storage mounted to your NAS:
	- nas-0X-backup
	- nas-0X-books
	- nas-0X-downloads
	- nas-0X-music
	- nas-0X-photo
    - nas-0X-public
	- nas-0X-transcode
	- nas-0X-video
	
	You must have a running network File Server (NAS) with ALL of the above NFS and/or CIFS backend share points configured on your PVE host pve-01.

**Optional Prerequisites**
- [ ] pfSense with working OpenVPN Gateways VPNGATE-LOCAL (VLAN30) and VPNGATE-WORLD (VLAN40).

<h2>Local DNS Records</h2>

Before proceeding, we <span style="color:red">strongly advise</span> that you familiarize yourself with network Local DNS and the importance of having a PiHole server. To learn more, click <a href="https://github.com/ahuacate/common/tree/main/pve/src/local_dns_records.md" target="_blank">here</a>.

It is essential to set your network's Local Domain or Search domain. For residential and small networks, we recommend using only top-level domain (spTLD) names because they cannot be resolved across the internet. Routers and DNS servers understand that ARPA requests they do not recognize should not be forwarded onto the public internet. It is best to select one of the following names: local, home.arpa, localdomain, or lan only. We strongly advise against using made-up names.

<h2>Easy Scripts</h2>

Easy Scripts simplify the process of installing and configuring preset configurations. To use them, all you have to do is copy and paste the Easy Script command into your terminal window, hit Enter, and follow the prompts and terminal instructions.

Please note that all Easy Scripts assume that your network is VLAN and DHCP IPv4 ready. If this is not the case, you can decline the Easy Script prompt to accept our default settings. Simply enter 'n' to proceed without the default settings. After declining the default settings, you can configure all your PVE container variables.

However, before proceeding, we highly recommend that you read our guide to fully understand the input requirements.

<h4><b>Easy Script Installer</b></h4>

Select any Medialab product using our Easy Script installer.

SSH login to your PVE host `ssh root@IP_address`. Then run the following command.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/main/pve_medialab_installer.sh)"
```

<h4><b>Easy Script Toolbox</b></h4>

Select any Medialab application toolbox from our Easy Script Toolbox. 

SSH login to your PVE host `ssh root@IP_address`. Then run the following command.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-medialab/main/pve_medialab_toolbox.sh)"
```

<h4>Table of Contents</h4>
<!-- TOC -->

- [1. About our MediaLab CT Applications](#1-about-our-medialab-ct-applications)
- [2. Preparing you network](#2-preparing-you-network)
    - [2.1. Storage Folder Structure](#21-storage-folder-structure)
    - [2.2. Unprivileged CTs and File Permissions](#22-unprivileged-cts-and-file-permissions)
        - [2.2.1. Unprivileged Container Mapping - medialab GUID](#221-unprivileged-container-mapping---medialab-guid)
        - [2.2.2. Allow a CT to perform mapping on your PVE host](#222-allow-a-ct-to-perform-mapping-on-your-pve-host)
        - [2.2.3. MediaLab CTs use common UID and GUID](#223-medialab-cts-use-common-uid-and-guid)
- [3. Notifiarr (recommended)](#3-notifiarr-recommended)
- [4. Jellyfin LXC](#4-jellyfin-lxc)
    - [4.1. Setup Jellyfin](#41-setup-jellyfin)
- [5. Prowlarr LXC](#5-prowlarr-lxc)
    - [5.1. Setup Prowlarr](#51-setup-prowlarr)
- [6. SABnzbd LXC](#6-sabnzbd-lxc)
    - [6.1. Setup SABnzbd](#61-setup-sabnzbd)
- [7. NZBGet LXC](#7-nzbget-lxc)
    - [7.1. Setup NZBget](#71-setup-nzbget)
- [8. Deluge LXC](#8-deluge-lxc)
    - [8.1. Setup Deluge](#81-setup-deluge)
- [9. Jackett LXC (optional)](#9-jackett-lxc-optional)
    - [9.1. Setup Jackett](#91-setup-jackett)
- [10. Sonarr LXC](#10-sonarr-lxc)
    - [10.1. Setup Sonarr](#101-setup-sonarr)
    - [10.2. Radarr LXC](#102-radarr-lxc)
    - [10.3. Setup Radarr](#103-setup-radarr)
- [11. Lidarr LXC](#11-lidarr-lxc)
    - [11.1. Setup Lidarr](#111-setup-lidarr)
- [12. Readarr LXC](#12-readarr-lxc)
    - [12.1. Setup Readarr](#121-setup-readarr)
- [13. Geterr LXC](#13-geterr-lxc)
    - [13.1. Easy Script installer](#131-easy-script-installer)
    - [13.2. Install Geterr](#132-install-geterr)
    - [13.3. CLI Tasks](#133-cli-tasks)
        - [13.3.1. Activate FileBot](#1331-activate-filebot)
    - [13.4. FlexGet recipes](#134-flexget-recipes)
    - [13.5. Documentary & News downloader - "recipe_00"](#135-documentary--news-downloader---recipe_00)
        - [13.5.1. File Permissions](#1351-file-permissions)
        - [13.5.2. Setup 'recipe_00'](#1352-setup-recipe_00)
        - [13.5.3. Input credentials - variable_default.yml](#1353-input-credentials---variable_defaultyml)
    - [13.6. Geterr FAQ](#136-geterr-faq)
        - [13.6.1. How is Geterr FlexGet and FileBot run?](#1361-how-is-geterr-flexget-and-filebot-run)
        - [13.6.2. How to check the status of FlexGet?](#1362-how-to-check-the-status-of-flexget)
        - [13.6.3. Is the "recipe_00" package frequently updated?](#1363-is-the-recipe_00-package-frequently-updated)
        - [13.6.4. Can I add my own csv list to improve FileBOt identification?](#1364-can-i-add-my-own-csv-list-to-improve-filebot-identification)
        - [13.6.5. Can I customize "recipe_00"?](#1365-can-i-customize-recipe_00)
        - [13.6.6. Can I copy "recipe_00" to another recipe name.](#1366-can-i-copy-recipe_00-to-another-recipe-name)
        - [13.6.7. Does "recipe_00" auto prune documentary media?](#1367-does-recipe_00-auto-prune-documentary-media)
- [14. Kodirsync LXC](#14-kodirsync-lxc)
    - [14.1. Features](#141-features)
    - [14.2. Kodirsync management](#142-kodirsync-management)
    - [14.3. Android-Termux](#143-android-termux)
    - [14.4. Kodirsync FAQ](#144-kodirsync-faq)
        - [14.4.1. How do I create a new user?](#1441-how-do-i-create-a-new-user)
        - [14.4.2. Can I connect my USB storage disk to my Android phone?](#1442-can-i-connect-my-usb-storage-disk-to-my-android-phone)
        - [14.4.3. Can I connect my USB storage disk to my Apple phone?](#1443-can-i-connect-my-usb-storage-disk-to-my-apple-phone)
        - [14.4.4. How do I change a user's media share access?](#1444-how-do-i-change-a-users-media-share-access)
        - [14.4.5. Can I delete a user account?](#1445-can-i-delete-a-user-account)
        - [14.4.6. How do I change Kodirsync remote connection access service type?](#1446-how-do-i-change-kodirsync-remote-connection-access-service-type)
        - [14.4.7. Why are the dates and times of my downloaded files different from the originals?](#1447-why-are-the-dates-and-times-of-my-downloaded-files-different-from-the-originals)
        - [14.4.8. Node sync. What is it?](#1448-node-sync-what-is-it)
- [15. Vidcoderr LXC](#15-vidcoderr-lxc)
    - [15.1. Setup Vidcoderr](#151-setup-vidcoderr)
    - [15.2. Vidcoderr FAQ](#152-vidcoderr-faq)
        - [15.2.1. Uploading hangs the web uploader page.](#1521-uploading-hangs-the-web-uploader-page)
        - [15.2.2. How do I check if Vidcoderr is encoding?](#1522-how-do-i-check-if-vidcoderr-is-encoding)
        - [15.2.3. What's the best setting to get the smallest file size and quality balance?](#1523-whats-the-best-setting-to-get-the-smallest-file-size-and-quality-balance)
        - [15.2.4. Can I change the time between processing for new content?](#1524-can-i-change-the-time-between-processing-for-new-content)

<!-- /TOC -->
<hr>

# 1. About our MediaLab CT Applications
The base operating system for Medialab LXC is Ubuntu. To successfully build any application, you need to have bind mounts with your PVE hosts. It is advisable to configure your NAS and PVE host before installing any Medialab CT application. Additionally, it's worth noting that all of our CTs make use of our custom Linux user, named media, and our custom Linux group, named medialab.

The majority of LXCs come equipped with a pre-set configuration file. To access this file, navigate to the "System" section of the application's WebGUI and select "Backup." From there, you can restore the configuration file by specifying the backup filename.

> application_name_backup_v3.2.2.0000_0000.00.00_00.00.00.zip

# 2. Preparing you network
To ensure a successful installation of the LXC application, Medialab requires that you have completed the following prerequisites at some point:
1. Preparation of your NAS using either [PVE NAS](https://github.com/ahuacate/pve-nas) or [NAS Hardmetal](https://github.com/ahuacate/nas-hardmetal)
2. Setting up your PVE storage on your PVE Host, as outlined in [PVE storage](https://github.com/ahuacate/pve-host)

The above GitHub repositories contain Easy Scripts to perform the required tasks. But here is an outline of what is required.


## 2.1. Storage Folder Structure
To ensure the optimal performance of our Medialab Apps, it is important to have a standard NAS folder or directory structure in place. Before creating any Medialab CT, it is recommended to confirm that your PVE Host Backend Storage mounts, also known as NAS shares, include the necessary folder structure outlined below. Additionally, it is crucial to ensure that the file permissions of these folders are compatible with the Medialab Apps you plan to use. Be sure to check the documentation for each application to determine the required file permission settings.

Furthermore, our CTs use specific Linux user and group configurations, including "media" (UID 1605) and group "medialab" (GID 65605), "home" (UID 1606) and group "homelab" (GID 65606), and "private" (UID 1607) and group "privatelab" (GID 65606). These configurations are critical to ensure that the Medialab CTs run smoothly and efficiently. Please ensure that these NAS users and groups are properly configured before using any of our applications.

```
/mnt/pve/
├── nas-0X-audio
│   ├── audiobooks
│   └── podcasts
├── nas-0X-backup
├── nas-0X-books
│   ├── comics
│   ├── ebooks
│   └── magazines
├── nas-0X-cloudstorage
├── nas-0X-docker
├── nas-0X-downloads
├── nas-0X-music
├── nas-0X-photo
├── nas-0X-public
│   └── autoadd
│       ├── torrent
│       │   ├── lidarr-music
│       │   ├── manual-documentary-movies
│       │   ├── manual-documentary-series
│       │   ├── manual-movies
│       │   ├── manual-series
│       │   ├── manual-unsorted
│       │   ├── radarr-movies
│       │   ├── readarr-books
│       │   ├── sonarr-series
│       │   └── whisparr-pron
│       ├── usenet
│       │   ├── lidarr-music
│       │   ├── manual-documentary-movies
│       │   ├── manual-documentary-series
│       │   ├── manual-movies
│       │   ├── manual-series
│       │   ├── manual-unsorted
│       │   ├── radarr-movies
│       │   ├── readarr-books
│       │   ├── sonarr-series
│       │   └── whisparr-pron
│       └── vidcoderr
│           ├── in_homevideo
│           ├── in_unsorted
│           └── out_unsorted
├── nas-0X-transcode
└── nas-0X-video
    ├── cctv
    ├── documentary
    ├── homevideo
    ├── images
    ├── movies
    ├── musicvideo
    ├── pron
    ├── series
    ├── stream
    │   ├── documentary
    │   ├── movies
    │   ├── musicvideo
    │   ├── pron
    │   └── series
    └── transcode
```


## 2.2. Unprivileged CTs and File Permissions
When using unprivileged CT containers, it's important to be aware of issues that can arise with UIDs (user ID) and GIDs (group ID) permissions when bind-mounting shared data. In Proxmox, UIDs and GIDs are mapped to a different number range than on the host machine, with root (UID 0) being mapped to UID 100000, and subsequent UIDs being incremented by 1. This means that files and directories within a CT will be mapped to "nobody" (UID 65534), which is not acceptable for host-mounted shared data resources.

To address this issue, we have set up default PVE Users and Groups in all of our MediaLab, HomeLab, and PrivateLab CTs, which are accessible to unprivileged LXC and CT containers. These include the user "media" (UID 1605) and group "medialab" (GID 65605), the user "home" (UID 1606) and group "homelab" (GID 65606), and the user "private" (UID 1607) and group "privatelab" (GID 65606).

However, because some users may have Synology DiskStations with GIDs outside of the Proxmox ID map range, we also pass through our "medialab" (GID 65605), "homelab" (GID 65606), and "privatelab" (GID 65607) Group GIDs mapped 1:1.

To ensure that these settings are applied correctly, our Easy Scripts perform three stages of fixes when creating a new MediaLab application CT.

### 2.2.1. Unprivileged Container Mapping - medialab GUID
The PVE container UID and GUID is changed by modifying the /etc/pve/lxc/container-id.conf file after creating a new MediaLab application CT with the Easy Script. 
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

This change is automatically done in the Easy Script provided.

### 2.2.2. Allow a CT to perform mapping on your PVE host
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

This change is automatically done in the Easy Script provided.

### 2.2.3. MediaLab CTs use common UID and GUID
The default Linux user and group settings in all MediaLab CTs are configured to use the PVE User `media` and Group `medialab`. This ensures that all new files created by the MediaLab CTs have the same UID and GUID, allowing for easy maintenance of NAS file creation, ownership, and access permissions within the medialab group.

We offer two options for configuring the media user in MediaLab CTs:

(A) User media without a Home folder:
```
groupadd -g 65605 medialab
useradd -u 1605 -g medialab -M media
usermod -s /bin/bash media
```
(B) User media with a Home folder:
```
groupadd -g 65605 medialab
useradd -u 1605 -g medialab -m media
usermod -s /bin/bash media
```

These changes are applied automatically by our Easy Script.

---

# 3. Notifiarr (recommended)

This is the Notifiarr client in an LXC. While Notifiarr is optional we recommend you install and configure a Notifiarr client. Because it integrates with [Trash Guides](https://trash-guides.info) your Radarr and Sonarr downloads will be fully optimized. It's definitely worth the effort and Notifiarr patron cost is nominal. 

Read more about [Notifiarr](https://notifiarr.com). Also, their [wiki](https://notifiarr.wiki/en/home) and this [guide](https://www.reddit.com/r/unRAID/comments/uyed93/idiots_guide_to_notifiarr/).

> Notifiarr integrated with Sonarr and Radarr Trash Guides is a no brainer. A little complex to setup but worth it in the longrun.

---

# 4. Jellyfin LXC

Jellyfin is a Free Software Media System that puts you in control of managing and streaming your media. Jellyfin is an alternative to the proprietary Emby and Plex to provide media from a dedicated server to end-user devices via multiple apps.

Jellyfin is descended from Emby's 3.5.2 release and ported to the .NET Core framework to enable full cross-platform support. There are no strings attached, no premium licenses or features, and no hidden agendas: and at the time of writing this media server software seems like the best available solution (and is free).


## 4.1. Setup Jellyfin
In your web browser URL type `http://jellyfin.local:8096` or `http://ct_ip_address:8096` and the applications configuration wizard page will appear. Detailed configuration instructions are available [here](https://github.com/ahuacate/jellyfin).

---

# 5. Prowlarr LXC

> This package should be installed before Lidarr, Mylar3, Radarr, Readarr, and Sonarr. 

Prowlarr is a powerful indexer manager and proxy that is built on the popular arr.net/reactjs base stack. It is designed to seamlessly integrate with your Servarr apps and offers support for both Torrent Trackers and Usenet Indexers. With Prowlarr, you can easily manage all your indexers in one place without needing to set up each app's indexer separately. Prowlarr integrates smoothly with popular apps such as Lidarr, Mylar3, Radarr, Readarr, and Sonarr, offering complete management of your indexers.

## 5.1. Setup Prowlarr
In your web browser URL type `http://prowlarr.local:8989` or `http://ct_ip_address:8989`. The Prowlarr WebGUI will appear.

An out-of-the-box setting preset file could be included. Go to the Prowlarr WebGUI `System` > `Backup` and restore the backup filename ( use the restore icon to the right of the backup file ):

*  *prowlarr_backup_vX.X.X.0000_0000.00.00_00.00.00.zip*

> The out-of-the-box setting preset file may or may not exist. If it doesn't exist then you must configure the application manually.

Also, check out [Trash Guides](https://trash-guides.info/) - guides for the Servarr range of apps.

---

# 6. SABnzbd LXC

SABnzbd is an Open Source Binary Newsreader written in Python. It's free, easy to use, and works practically everywhere.

## 6.1. Setup SABnzbd
In your web browser URL type, `http://sabnzbd.local:8080` or `http://ct_ip_address:8080` and the application's web frontend will appear. Your SABnzbd is ready-to-go, just add your Usenet server credentials.


---

# 7. NZBGet LXC

Sadly NZBGet has reached its end of life. Best use SABnzbd.

NZBGet is a binary downloader, which downloads files from Usenet based on the information given in nzb-files.

NZBGet is written in C++ and is known for its extraordinary performance and efficiency.

## 7.1. Setup NZBget
In your web browser URL type, `http://nzbget.local:6789` or `http://ct_ip_address:6789` and the application's web frontend will appear. Your NZBGet is ready-to-go.

Also, check out [Trash Guides](https://trash-guides.info/) - guides for the Servarr range of apps.

---

# 8. Deluge LXC

Deluge is a lightweight, free software, cross-platform BitTorrent client.

## 8.1. Setup Deluge
In your web browser URL type `http://deluge.local:8112` or `http://ct_ip_address:8112` and the application's web frontend page will appear. Detailed configuration instructions are available [here](https://github.com/ahuacate/deluge).

---

# 9. Jackett LXC (optional)

We recommend you install Prowlarr.

Jackett works as a proxy server: it translates queries from apps (Sonarr, Radarr, Lidarr etc) into tracker-site-specific HTTP queries, parses the HTML response, then sends results back to the requesting software. This allows for getting recent uploads (like RSS) and performing searches. Jackett is a single repository of maintained indexer scraping & translation logic - removing the burden from other apps.


## 9.1. Setup Jackett
In your web browser URL type `http://jackett.local:9117` or `http://ct_ip_address:9117` and the application's web frontend will appear. Detailed configuration instructions are available [here](https://github.com/ahuacate/jackett).

---

# 10. Sonarr LXC
We recommend you install the Sonarr V4 beta version. V4 is supported by Trash Guides.

Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better-quality format becomes available.

## 10.1. Setup Sonarr
In your web browser URL type `http://sonarr.local:8989` or `http://ct_ip_address:8989`. The Sonarr WebGUI will appear.

An out-of-the-box setting preset file could be included. Go to the Sonarr WebGUI `System` > `Backup` and restore the backup filename ( use the restore icon to the right of the backup file ):

*  *sonarr_backup_vX.X.X.0000_0000.00.00_00.00.00.zip*

> The out-of-the-box setting preset file may or may not exist. If it doesn't exist then you must configure the application manually.

Also, check out [Trash Guides](https://trash-guides.info/) - guides for the Servarr range of apps.

---

## 10.2. Radarr LXC
Radarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favourite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

## 10.3. Setup Radarr
In your web browser URL type `http://radarr.local:7878` or `http://ct_ip_address:7878`. The Radarr WebGUI will appear.

An out-of-the-box setting preset file could be included. Go to the Radarr WebGUI `System` > `Backup` and restore the backup filename ( use the restore icon to the right of the backup file ):

*  *radarr_backup_vX.X.X.0000_0000.00.00_00.00.00.zip*

> The out-of-the-box setting preset file may or may not exist. If it doesn't exist then you must configure the application manually.

Also, check out [Trash Guides](https://trash-guides.info/) - guides for the Servarr range of apps.

---

# 11. Lidarr LXC
Lidarr is a music collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new tracks from your favorite artists and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

## 11.1. Setup Lidarr
In your web browser URL type `http://lidarr.local:8686` or `http://ct_ip_address:8686`. The Lidarr WebGUI will appear.

An out-of-the-box setting preset file could be included. Go to the Lidarr WebGUI `System` > `Backup` and restore the backup filename ( use the restore icon to the right of the backup file ):

*  *lidarr_backup_vX.X.X.0000_0000.00.00_00.00.00.zip*

> The out-of-the-box setting preset file may or may not exist. If it doesn't exist then you must configure the application manually.

---

# 12. Readarr LXC
Readarr is an eBook and audiobook collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new books and will interface with clients and indexers to grab, sort, and rename them. It can also be configured to automatically upgrade the quality of existing files in the library when a better quality format becomes available. It does not manage comics or magazines.

## 12.1. Setup Readarr
In your web browser URL type `http://readarr.local:8686` or `http://ct_ip_address:8686`. The Readarr WebGUI will appear.

An out-of-the-box setting preset file could be included. Go to the Readarr WebGUI `System` > `Backup` and restore the backup filename ( use the restore icon to the right of the backup file ):

*  *readarr_backup_vX.X.X.0000_0000.00.00_00.00.00.zip*

> The out-of-the-box setting preset file may or may not exist. If it doesn't exist then you must configure the application manually.

---


# 13. Geterr LXC
Geterr is our FlexGet and FileBot package. Created for the downloading of RSS feeds and genres like Documentary or News using Trakt.

Geterr is an addition to Radarr and Sonarr, not a replacement.

FlexGet supports torrents, nzbs, podcasts, comics, TV, movies, RSS, HTML, CSV, and more. FileBot is an outstanding media renaming tool for media.

You will require a [Filebot license](https://www.filebot.net/). For only $6.00 USD per year, it's a no-brainer.

Included is our MVGroup documentary RSS recipe named `recipe_00`. It is enabled by default.

## 13.1. Easy Script installer
There is none for Geterr. FlexGet requires CLI knowledge.

## 13.2. Install Geterr

1. Open a PVE host SSH shell.
2. Install our `Deluge LXC` (must be our Deluge build).
3. Install `Geterr`.

Use our Medialab Easy Script Installer for both tasks.

## 13.3. CLI Tasks
The user must have Linux CLI skills and knowledge about using nano or vi editors. For this tutorial we nano. 

1. Open a PVE host SSH shell.
2. Type the following:
-- `pct list` (Make a note of Geterr CTID)
-- `pct enter CTID`
-- `su - media` (Changes your shell to media user)
3. Nano commands.
-- `nano /path/to/filename`
-- `ctrl o` to save
-- `ctrl x` to exit

### 13.3.1. Activate FileBot

Read about FileBot activation [here](https://www.filebot.net/forums/viewtopic.php?t=6121). Use the CLI method and paste your key into your Geterr shell window. Make sure you use notepad++ to copy your license key into memory if you're using MS Windows.
1. Open a PVE host SSH shell.
2. Type the following:
-- `pct list` (Make a note of Geterr CTID)
-- `pct enter CTID`
-- `su - media` (Changes your shell to media user)
-- `filebot --license`
Follow the screen prompts. To paste use right mouse button to paste FileBot license key from memory.

Check your activation with this command:
-- `su - media` (only if your are not user media)
-- `sh -c "filebot -script fn:sysinfo"`

````
### Results ....

FileBot 5.0.1 (r9665)
JNA Native: 6.1.4
MediaInfo: 22.12
Tools: NONE
Extended Attributes: OK
Unicode Filesystem: OK
Script Bundle: 2023-03-28 (r895)
Groovy: 4.0.9
JRE: OpenJDK Runtime Environment 18.0.2-ea
JVM: OpenJDK 64-Bit Server VM
CPU/MEM: 1 Core / 4.0 GB Max Memory / 28 MB Used Memory
OS: Linux (amd64)
HW: Linux geterr 5.15.102-1-pve #1 SMP PVE 5.15.102-1 (2023-03-14T13:48Z) x86_64 x86_64 x86_64 GNU/Linux
CPU/MEM: Intel(R) Core(TM) i3-3225 CPU @ 3.30GHz [MemTotal: 536 MB | MemFree: 186 MB | MemAvailable: 351 MB | SwapTotal: 536 MB | SwapFree: 536 MB]
STORAGE: ext4 [/] @ 3.4 GB | nfs4 [/mnt/downloads] @ 168 GB | nfs4 [/mnt/public] @ 168 GB | nfs4 [/mnt/video] @ 168 GB
UID/GID: uid=1605(media) gid=65605(medialab) groups=65605(medialab)
DATA: /home/media/filebot/data/1605
Package: TAR
License: FileBot License PXXXXXX (Valid-Until: 2024-03-19)
Done ヾ(＠⌒ー⌒＠)ノ
````

## 13.4. FlexGet recipes

Geterr relies on a straightforward folder structure that contains FlexGet recipes. Each recipe is considered an individual FlexGet deployment.

The default Documentary and News build is referred to as "recipe_00". If you want to set up "recipe_00", read on to learn how.

To store the necessary FlexGet and FileBot scripts, as well as the config.yml file for FlexGet, create a recipe folder using our naming convention (i.e recipe_XX).

You can activate a recipe by editing the `/home/media/.flexget/cookbook/cookbook.ini` file.

```
/home/media/.flexget
└── cookbook
    ├── recipe_00
    ├── recipe_01
    └── recipe_02
```

## 13.5. Documentary & News downloader - "recipe_00"

Our Documentary and News downloader is called "recipe_00", and it is designed to download the latest torrent content from MVGroup and use your own Trakt lists.

MVGroup offers a vast collection of documentaries, news, science, and history viewing. However, their torrent file naming conventions can be quite peculiar, which poses challenges when trying to identify the content with popular databases such as TMDB, TVDB, TV Maze or IMDB. To address this issue, our "recipe_00" package was created out of frustration. It employs preprocessing regex renaming and post-production by FileBot to attempt to rename the downloaded files, making them easier to identify and manage in Jellyfin, Emby or Plex.

In addition, `recipe_00` uses Trakt lists. With your own Trakt lists, you can manage your favorite documentary, news, history or science-related series or movies.

### 13.5.1. File Permissions
Always perform all edits under user 'media' to avoid problems.

```
su - media
```

### 13.5.2. Setup 'recipe_00'

`recipe_00` configuration file is: `~/.flexget/cookbook/recipe_00/variables_default.yml`.

You must have the following credentials ready.

<h5><b>Trakt credentials</b></h5>

Log into your Trakt account and create two Trakt lists named (all lowercase, naming must be identical):

* `documentary-series`
* `documentary-movie`


Make the above lists public in your Trakt account website settings.

Use these two lists for documentary, news, science, history and alike genre content only. FlexGet will retrieve any series or movie added to these two lists daily. It's important to note your Trakt lists will be in addition to whatever is available at MVGroup, and no duplicates will occur.

<h5><b>Trakt FlexGet authorization</b></h5>

Follow these instructions to complete Trakt Authentication for your Geterr LXC: [here](https://flexget.com/Trakt_Authentication).



1. In a Geterr shell type the following as user 'media'. Follow the onscreen terminal instructions.

```
# Su to user media
su - media

# CD to to your recipe dir
cd ~/.flexget/cookbook/recipe_00

# Run the Trakt cmd
~/flexget/bin/flexget trakt auth <insert your trakt account name here>
```

2. Example of success

```
Please visit https://trakt.tv/activate and authorize Flexget.
Your user code is 374634673. Your code expires in 10.0 minutes.
Waiting............Successfully authorized Flexget app on Trakt.tv. Enjoy!
```

<h5><b>MVGroup credentials</b></h5>
Create a valid MVGroup user account.
Your MVGroup user account has a custom RSS url which is available here:

```https://forums.mvgroup.org/rss.php?listfeeds=1```

Your MVGroup username and password looks like this:
```https://username:4d17d02aai8665cs8220a1e98e1e8d@forums.mvgroup.org/rss.php?torrentsonly=1```

### 13.5.3. Input credentials - variable_default.yml
All "recipe_00" settings for FlexGet and FileBot are contained in `~/.flexget/cookbook/recipe_00/variables_default.yml`.
1. Open a PVE host SSH shell.
2. Type the following:
-- `pct list` (Make a note of Geterr CTID)
-- `pct enter CTID`
-- `su - media` (Changes your shell to media user)
3. Edit "recipe_00" configuration file.
Type the following:
-- `nano ~/.flexget/cookbook/recipe_00/variables_default.yml`
Edit Deluge settings if required
Edit Trakt credentials:
-- trakt.account
-- trackt.username
Edit MVGroup url:
-- mvgroup.url
Save & exit:
-- `ctrl o`
-- `ctrl x`

Restart your Geterr LXC.

## 13.6. Geterr FAQ

### 13.6.1. How is Geterr FlexGet and FileBot run?
Geterr utilizes both systemd and bash scripts to operate. It relies on two systemd units:

* flexget.timer
* flexget.service

The systemd unit "flexget.timer" is scheduled to run every 6 hours. On the other hand, the systemd unit "flexget.service" runs the `/home/media/.flexget/cookbook/cookbook.sh` script and uses the `/home/media/.flexget/cookbook/cookbook.ini` configuration file.

### 13.6.2. How to check the status of FlexGet?
To check the status of FlexGet, the simplest method is to use the systemd status report. You can achieve this by executing the command:

```
systemctl status flexget.service
```

### 13.6.3. Is the "recipe_00" package frequently updated?
This package will automatically update once per week. The update does not overwrite your credentials.

### 13.6.4. Can I add my own csv list to improve FileBOt identification?
The "recipe_00" package comes with a user csv file located at `~/.flexget/cookbook/recipe_00/my_filter_lookup_list.txt` specifically for this task. You can input the name of a TV series or movie and its corresponding database ID number (tmdbid, tvdbid, imdbid, tvmazeid, or anidbid) into this file.

The instructions for adding your entries can be found within the file itself. Please note that '~/.flexget/cookbook/recipe_00/filter_lookup_master_list.txt' should NOT be edited.

### 13.6.5. Can I customize "recipe_00"?
Certainly! However, if you wish to make modifications to "recipe_00," you must first disable our automatic update service located in the variables_default.yml file at ~/.flexget/cookbook/recipe_00/. If you do not disable this service, any customizations you make will be overwritten. Alternatively, you can duplicate the entire "recipe_00" to a new build recipe.

### 13.6.6. Can I copy "recipe_00" to another recipe name.
Yes. Follow these prompts.
1. Open a PVE host SSH shell.
2. Type the following:
-- `pct list` (Make a note of Geterr CTID)
-- `pct enter CTID`
-- `su - media` (Changes your shell to media user)
3. Copy "recipe_00" to "recipe_01"
Type the following:
-- `cp -rf ~/.flexget/cookbook/recipe_00 ~/.flexget/cookbook/recipe_01`
4. Edit cookbook ini
-- `nano ~/.flexget/cookbook/cookbook.ini`
Edit recipe_dir to be:
-- `recipe_dir="recipe_01"`
Save & exit:
-- `ctrl o`
-- `ctrl x`

Your Geterr is now configured to use recipe "recipe_01".

### 13.6.7. Does "recipe_00" auto prune documentary media?
Absolutely. "Recipe_00" is capable of automatically pruning documentary media. By default, the age limit for media files is pre-configured in the `variables_default.yml` file located at` ~/.flexget/cookbook/recipe_00/`.

```

# Prune is a action to delete video content after a set number of days.
# Prune is applied to '.../video/documentary/{series,movies}' and
# '/mnt/downloads/unsorted' only.
# Example:
#      'documentary_series_days: 14' will delete all content aged 14 days or more.
# Set '0' to disable.
prune:
  # Documentary series (days)
  age_documentary_series: 14
  # Documentary movies (days)
  age_documentary_movies: 21
  # Unsorted media (days) (i.e /mnt/downloads/unsorted)
  age_unsorted: 7
```

---

# 14. Kodirsync LXC
Kodirsync is a media synchronization application for local and remote Kodi players and Linux devices. It uses the Linux Rsync utility to securely transfer media files to your CoreELEC, LibreELEC, Linux or Android device.

Remote connectivity options over the internet include:

1. SSLH Connection
    * Internet access using HTTPS SSL 443
    * A valid domain URL address forwarded to your HAProxy server
    * HAProxy configured as per our pfSense HAProxy guide
    * Kodirsync Certificate file: Acmi+SSLH+-+Kodirsync.crt (HAProxy Acmi SSLH)
    * Kodirsync User key file: Acmi+SSLH+-+Kodirsync.key (HAProxy Acmi SSLH)

2. SSH Port Forward (PF) Connection
    * Dynamic DNS service provider
    * Dynamic DNS client updater (ddclient PVE CT)
    * WAN Gateway port forwarded to Kodirsync server"

## 14.1. Features
1. USB Disk Portability: Easily connect your USB Kodirsync disk to CoreELEC, LibreELEC, Linux, and Android devices to perform media updates on LAN, WiFi or even cellular networks.
2. Storage Disk Options: Choose between ext4 or exFAT formats for compatibility with Android devices.
3. Storage Options: Use internal SATA folders or portable USB disk storage for flexible storage management.
4. Autodetect LAN Server: Kodirsync automatically detects LAN servers for fast media synchronization.
5. Selective Media Synchronization: Users can choose specific media categories for synchronization, whether stored internally or on external drives.
6. Daily Synchronization: Set up daily synchronization using a cron schedule (supported on CoreELEC, LibreELEC, and Linux devices).
7. Auto-Prune Remote Media: Kodirsync intelligently removes the oldest remote media files to create space for new media.
8. Data Limit Control: Define a data limit, and the remote device's disk will be filled up to that limit (in percentage or GB).
9. HDR Content Download: Users can enable or disable the downloading of HDR content.
10. Whitelist and Blacklist: Customize media series or movies by specifying full or partial names for whitelisting or blacklisting.
11. Throttled Daylight Downloading: Schedule downloads to avoid internet congestion during peak daylight hours.
12. Configuration File Customization: Users have the flexibility to customize the configuration file according to their preferences.
13. Setup a storage node mirror: Mirror your primary Kodirsync media to another machine disk or folder over your LAN.


## 14.2. Kodirsync management
Medialab Easy Script Toolbox enables you to efficiently manage new user accounts and configure your Kodirsync server. It serves as a user-friendly front-end interface, providing easy access to various tasks and functionalities.

When a new user account is created, an installer package is automatically generated and sent via email. This installer package contains all the necessary instructions and resources to facilitate the seamless setup of their remote device.

## 14.3. Android-Termux
If you configure your CoreELEC, LibreELEC or Linux device to use a USB storage disk then you can connect that same disk to a Android mobile to perform media updates.

The USB storage disk filesystem must be exFAT.

Follow the installation instructions in your installer email.

## 14.4. Kodirsync FAQ
Always read the [installer email](https://github.com/ahuacate/pve-medialab/blob/main/src/kodirsync/email_tml/kodirsync_instructions.pdf) which contains detailed installation instructions and more.

### 14.4.1. How do I create a new user?
Use Medialab Easy Script Toolbox on your server and select the `Kodirsync User Manager` option. Then select `Create a new user account` and follow the prompts to create a new user account. An installer package will be emailed to the new user and Proxmox administrator.

### 14.4.2. Can I connect my USB storage disk to my Android phone?
Yes, you can connect your USB storage disk to your Android phone, but there are a few considerations to keep in mind. Firstly, you need to ensure that you have selected the disk portability option during the installation process. Additionally, Android requires the use of the exFAT filesystem for compatibility with external storage devices. To connect your USB storage disk, charger, and phone simultaneously, you will need a USB 'Y-cable'. It's worth noting that using a solid-state drive (SSD) disk may work without the need for charging, albeit with potential severe battery drain. However, rotational disks, are unlikely to function properly without an additional power source.

### 14.4.3. Can I connect my USB storage disk to my Apple phone?
No, connecting a USB storage disk directly to an Apple phone is not supported. However, there might be a possibility of making it work if you can run Linux bash/shell scripts on your Apple phone and possess the necessary knowledge to do so.

### 14.4.4. How do I change a user's media share access?
Use the Medialab Easy Script Toolbox on your server and select the `Kodirsync User Manager` option. Then select `Modify an existing user rsync shares` to modify a user's access. The Kodirsync client, such as your Kodi player, will automatically update when it is next scheduled to perform its synchronization. All unshared content will automatically be deleted from the client's storage on the next synchronization.

### 14.4.5. Can I delete a user account?
Use the Medialab Easy Script Toolbox on your server and select the `Kodirsync User Manager` option. Then select `Delete a user account` to delete the user account. The user will no longer have access.

### 14.4.6. How do I change Kodirsync remote connection access service type?
If you have an existing remote SSLH or Port Forward connection service first disable the existing remote access service. Use the Kodirsync Toolbox on your server and select `Disable SSLH access` or `Disable Port Forward access` option. Then select the remote connection service type you want to set up from the menu. Then delete all the users and create the users again. All clients will need to uninstall Kodirsync and run the new installer.

### 14.4.7. Why are the dates and times of my downloaded files different from the originals?
The discrepancy in file dates and times is due to the exFAT filesystem used on your disk, which is commonly employed for external USB disks to ensure portability across different devices. However, when using Rsync with exFAT file systems, certain issues arise, leading to inconsistencies in file dates. To address this problem, you can switch to the ext4 filesystem, which resolves the file date issues. It's important to note, though, that by transitioning to ext4, you may sacrifice the portability feature offered by exFAT.

### 14.4.8. Node sync. What is it?
Node Sync is designed to facilitate the synchronization of your local Kodirsync media library with another Linux machine (referred to as a "node") on your LAN network. This synchronization process is automatically initiated following each instance of Kodirsync.

To set up the node machine, you will need to prepare a USB or internal storage disk, or alternatively, select a specific folder. This can be achieved by executing our installer package on the node. For detailed guidance on the installation procedure, please refer to the instructions provided in the installer email you received.

---

# 15. Vidcoderr LXC

Vidcoderr is a tool designed to transcode video files, including home videos, movies, and TV series, into smaller HEVC or H264 video files, utilizing the encoding engine developed by [Don Melton](https://github.com/donmelton/other_video_transcoding).

These smaller video files are ideal for streaming over the internet while keeping your main library of 4K, 4K HDR and large files intact.

You can set a preferred video bitrate, codec and audio stream quality. Additionally, Vidcoderr can process subtitle files, making it easier to create complete video files.

Vidcoderr outputs Matroska (MKV) container format, with the exception being MKV input files, which are outputted in the MP4 container format.

**Manual Encodes**
Vidcoderr supports the encoding of individual video files.

For home video content always upload to the input folder `/public/autoadd/vidcoderr/in_homevideo`. The encoded HEVC 10-bit output file will be stored in the main home video library folder on your NAS. Home video encodes always use an optimum bitrate which overrides your presets, so there is no noticeable quality difference from the input original file.

Alternatively, you can upload to the input folder `/public/autoadd/vidcoderr/in_unsorted`, and the encoded output file will be saved in `/public/autoadd/vidcoderr/out_unsorted`. Vidcoderr will use the same encoding presets you selected at configuration.

To manually upload encodes, use the HTTP file upload frontend at `http://vidcoderr.local:8000/`. The processing occurs either every 6 hours (default setting) or sooner if InotifyWait works with your NAS shares.

> It is recommended to always use the "copy" command when working with Vidcoderr, as this will ensure that your input file is not deleted automatically (with the exception of main library videos).

**Auto Encodes** ( Optional )
Automatic encoding feature is for users who want to enable a streaming capability to remote external clients beyond your local area network (LAN).

By utilizing this feature, you can optimize your video files for seamless streaming. It is important to note that this feature is applicable only to newly added video files in your library. The newly encoded files will be saved in specific video stream folders, namely /video/stream/series, /video/stream/movies, /video/stream/pron, and /video/stream/documentary.

The Vidcoderr platform comes equipped with a useful file pruning feature that applies to all video files located within the /video/stream folder. By default, the platform will prune (delete) any files that are older than 30 days. This helps to ensure that your video stream library stays organized and up-to-date, without accumulating unnecessary or outdated content.

## 15.1. Setup Vidcoderr
A Vidcoderr toolbox is available. Tasks include:
* Run our Vidcoderr `Setup Assistant`
* Update Vidcoderr (includes Vidcoderr software updates, host LXC updates and any patches)

The User can modify, tweak or change any Vidcoderr settings within the configuration file: `/usr/local/bin/vidcoderr/vidcoderr.ini` ( Vidcoderr requires a restart after editing ).

## 15.2. Vidcoderr FAQ
### 15.2.1. Uploading hangs the web uploader page.
If you are uploading a video file using the frontend interface at `http://vidcoderr.local:8000/`, your browser's loading icon will continue to spin until the upload task has been completed. The speed at which the upload is completed will depend on a number of factors, including your computer's network connection speed to the Vidcoderr LXC and the size of the video file being uploaded.

### 15.2.2. How do I check if Vidcoderr is encoding?
To check whether Vidcoderr is currently encoding a video file, the easiest method is to monitor the CPU usage in Proxmox. Start by selecting the Vidcoderr LXC, and then navigate to the summary tab. If the CPU usage meter displays a value of 0.00%, then Vidcoderr is currently idle and not processing any video files. However, if the CPU usage meter displays a value above 0.00%, then it's likely that Vidcoderr is currently in the process of encoding a video file.

### 15.2.3. What's the best setting to get the smallest file size and quality balance?
Use HEVC 10-bit.

### 15.2.4. Can I change the time between processing for new content?
Yes. Vidcoderr runs its scripts using a system.d timer. The default setting is 6 hourly. Use a Linux CLI editor like Nano to edit the value in '/etc/systemd/system/vidcoderr_watchdir_std.timer'. The steps in a Vidcoderr CLI are:

```
# Stop vidcoderr_watchdir_std.timer
systemctl stop vidcoderr_watchdir_std.timer

# Edit '/etc/systemd/system/vidcoderr_watchdir_std.timer'
nano /etc/systemd/system/vidcoderr_watchdir_std.timer

# Edit param 'OnUnitActiveSec'

# Reload and start daemon
systemctl daemon-reload
systemctl restart vidcoderr_watchdir_std.timer
```

---