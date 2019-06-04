#!/bin/ash

#### Proxmox LXC VPN-GATEWAY build script ####

# Command to run script on CentOS7 lxc node
# wget -O - https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/build-vpn-gateway-expressvpn.sh | ash

# To install the EPEL release package
yum -y install epel-release
yum -y update

# Install Software
yum install -y openvpn openssh-server wget nano

# Copy the OpenVPN config files from Github
cd /etc/openvpn
wget -N https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/auth-vpn-gateway.txt -P /etc/openvpn
wget -N https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/iptables-vpn-gateway-expressvpn.sh -P /etc/openvpn
wget -N https://raw.githubusercontent.com/ahuacate/proxmox-lxc/master/openvpn/vpn-gateway-expressvpn.conf -P /etc/openvpn

# Enable kernel IP forwarding
echo -e "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
#sysctl -w net.ipv4.ip_forward=1
systemctl restart network.service

# Install and configure Iptables
yum install -y iptables-services
systemctl enable iptables
bash /etc/openvpn/iptables-vpn-gateway-expressvpn.sh
systemctl start iptables

# Start OpenVPN on Boot
systemctl enable --now openvpn@vpn-gateway-expressvpn.service
