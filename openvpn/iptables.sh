#!/bin/ash

# Flush
iptables --flush

# Block All
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP


# allow Localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT


# Make sure you can communicate with any DHCP server
iptables -A OUTPUT -d 255.255.255.255 -j ACCEPT
iptables -A INPUT -s 255.255.255.255 -j ACCEPT


# Make sure that you can communicate within your own network
#iptables -A INPUT -s 192.168.0.0/24 -d 192.168.0.0/24 -j ACCEPT
#iptables -A OUTPUT -s 192.168.0.0/24 -d 192.168.0.0/24 -j ACCEPT
iptables -A INPUT -s 192.168.0.0/24 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/24 -j ACCEPT


# Allow established sessions to receive traffic:
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT


# Allow DNS resolution and limited HTTP/S on eth0.
# Necessary for updating the server and keeping time.
iptables -A INPUT -i eth0 -p udp -m state --state ESTABLISHED --sport 53 -j ACCEPT
iptables -A OUTPUT -o eth0 -p udp -m state --state NEW,ESTABLISHED --dport 53 -j ACCEPT
iptables -A INPUT -i eth0 -p tcp -m state --state ESTABLISHED --sport 53 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp -m state --state NEW,ESTABLISHED --dport 53 -j ACCEPT

iptables -A INPUT -i eth0 -p tcp -m state --state ESTABLISHED --sport 80 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp -m state --state NEW,ESTABLISHED --dport 80 -j ACCEPT
iptables -A INPUT -i eth0 -p tcp -m state --state ESTABLISHED --sport 443 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp -m state --state NEW,ESTABLISHED --dport 443 -j ACCEPT


# Allow TUN
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -o tun+ -j ACCEPT
iptables -t nat -A POSTROUTING -o tun+ -j MASQUERADE
iptables -A OUTPUT -o tun+ -j ACCEPT


# allow VPN connection
iptables -I OUTPUT 1 -p udp --destination-port 1195 -m comment --comment "Allow VPN connection" -j ACCEPT


# Block All
iptables -A OUTPUT -j DROP
iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP


# Save
service iptables save
