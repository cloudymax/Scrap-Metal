#!/bin/bash -
#===============================================================================
#
#          FILE: ip-tables.sh
#
#         USAGE: ./ip-tables.sh
#
#   DESCRIPTION: 
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 09/19/2022 01:41:13 PM
#      REVISION:  ---
#===============================================================================

set -o nounset                                  # Treat unset variables as an error

  # Enable forwarding
  sudo iptables -F FORWARD
  sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
