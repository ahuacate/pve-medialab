#!/bin/ash

#### Proxmox LXC VPN-GATEWAY build script ####

# Command to run script on CentOS7 lxc node
# yum install -y wget && wget -O - https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/build-vpn-gateway-expressvpn.sh | bash

# To install the EPEL release package
yum -y install epel-release
yum -y update

# Install Software
yum install -y openvpn openssh-server nano

# Copy the OpenVPN config files from Github
cd /etc/openvpn
wget -N https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/auth-vpn-gateway.txt -P /etc/openvpn
wget -N https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/iptables-vpn-gateway-expressvpn.sh -P /etc/openvpn
wget -N https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/vpn-gateway-expressvpn.conf -P /etc/openvpn

# Enable kernel IP forwarding
echo -e "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
#sysctl -w net.ipv4.ip_forward=1
systemctl restart network.service

# Start OpenVPN on Boot
systemctl start openvpn@vpn-gateway-expressvpn.service
systemctl enable --now openvpn@vpn-gateway-expressvpn.service

# Install and configure Iptables
yum install -y iptables-services
bash /etc/openvpn/iptables-vpn-gateway-expressvpn.sh
systemctl enable iptables
systemctl start iptables
#reboot
