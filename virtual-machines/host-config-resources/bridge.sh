#!/bin/bash -
#===============================================================================
#
#          FILE: bridge.sh
#
#         USAGE: ./bridge.sh
#
#   DESCRIPTION: 
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 09/16/2022 09:42:07 AM
#      REVISION:  ---
#===============================================================================

set -o nounset                                  # Treat unset variables as an error

# create a bridge
#sudo ip link add br0 type bridge
#sudo ip link set br0 up
#sudo ip link set enp4s0 up

########################################################################
# network will drop here unless next bit are automated in same session #
########################################################################

# add the real ethernet interface to the bridge
#sudo ip link set enp4s0 master br0

# remove all ip assignments from real interface
#sudo ip addr flush dev enp4s0

# give the bridge the real interface's old IP
#sudo ip addr add 192.168.50.100/24 brd + dev br0

# add the default GW
#sudo ip route add default via 192.168.50.1 dev br0

# add a tap device for the user
sudo ip tuntap add dev tap0 mode tap user root
sudo ip link set dev tap0 up

# attach the tap device tot he bridge.
sudo ip link set tap0 master br0

# Enable forwarding 
iptables -F FORWARD
iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT

##########################
# troubleshooting tips   #
##########################

# Show bridge status
# brctl show

# Show verbose of single item
# an active process must be attached to a device for it to not be "disabled"
# brctl showstp br0

# sysctl -w net.ipv4.ip_forward=1

