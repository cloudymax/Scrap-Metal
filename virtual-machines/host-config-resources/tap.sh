#!/bin/bash -
#===============================================================================
#
#          FILE: tap.sh
#
#         USAGE: ./tap.sh
#
#   DESCRIPTION: 
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 09/19/2022 01:48:34 PM
#      REVISION:  ---
#===============================================================================

set -o nounset                                  # Treat unset variables as an error

NUMBER=$1

# add a tap device for the user
sudo ip tuntap add dev "tap$NUMBER" mode tap user root
sudo ip link set dev "tap$NUMBER" up

# attach the tap device tot he bridge.
sudo ip link set "tap$NUMBER" master br0
