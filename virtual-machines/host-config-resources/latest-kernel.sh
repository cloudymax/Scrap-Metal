#!/bin/bash -
#===============================================================================
#
#          FILE: latest-kernel.sh
#
#         USAGE: ./latest-kernel.sh
#
#   DESCRIPTION: 
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 09/19/2022 11:21:13 AM
#      REVISION:  ---
#===============================================================================

set -o nounset                                  # Treat unset variables as an error

echo "lets get the latest kernel version :3"

BASE_URL="https://kernel.ubuntu.com/~kernel-ppa/mainline/"

# Steps
# 1. get the whole web page as text
# 2. get the 5th column of each row - thats where the url is
# 3. remove trailing text that directly follows version number
# 4. remove any lines that arent a kernel version number
# 5. get the last entry at bottom of page - thats the latest


KERNEL_VERSION=$(curl -s $BASE_URL |awk '{print $5}' | sed -e 's/href="//g' | cut -f1 -d"/" |grep v |tail -1)

VALID_VERSION="False"
COUNTER=1

while [ "$VALID_VERSION" == "False" ]; do
    echo "Checking for a passing build with $KERNEL_VERSION..."    
    CHECK_PASSING=$(curl -s $BASE_URL/$KERNEL_VERSION/ |grep -o "Test amd64/build succeeded")
    
    if [ "$CHECK_PASSING" == "Test amd64/build succeeded" ]; then
        VALID_VERSION="True"
        echo "Success!"
    else
        echo "Nope."
        let "COUNTER=COUNTER+1"
        KERNEL_VERSION=$(curl -s $BASE_URL |awk '{print $5}' | sed -e 's/href="//g' | cut -f1 -d"/" |grep   v |tail -$COUNTER |head -1)
    fi
done

echo "Getting package names..."

GENERIC_HEADERS_NAME=$(curl -s $BASE_URL$KERNEL_VERSION/ |grep amd64/linux-headers.*.deb |cut -f2 -d"/" |cut -f1 -d"\"" |grep generic)
echo "$GENERIC_HEADERS_NAME"

ALL_HEADERS_NAME=$(curl -s $BASE_URL$KERNEL_VERSION/ |grep amd64/linux-headers.*.deb |cut -f2 -d"/" |cut -f1 -d"\"" |grep all)
echo "$ALL_HEADERS_NAME"

LINUX_IMAGE_NAME=$(curl -s $BASE_URL$KERNEL_VERSION/ |grep amd64/linux-image.*.deb |cut -f2 -d"/" |cut -f1 -d"\"")
echo "$LINUX_IMAGE_NAME"

LINUX_MODULES_NAME=$(curl -s $BASE_URL$KERNEL_VERSION/ |grep amd64/linux-modules.*.deb |cut -f2 -d"/" |cut -f1 -d"\"")
echo "$LINUX_MODULES_NAME"


echo "Downloading packages into /tmp/latest-kernel..."
[ -e /tmp/latest-kernel ] && rm -rf /tmp/latest-kernel
mkdir -p /tmp/latest-kernel

wget -O /tmp/latest-kernel/$GENERIC_HEADERS_NAME "https://kernel.ubuntu.com/~kernel-ppa/mainline/$KERNEL_VERSION/amd64/$GENERIC_HEADERS_NAME" -q --show-progress
wget -O /tmp/latest-kernel/$ALL_HEADERS_NAME "https://kernel.ubuntu.com/~kernel-ppa/mainline/$KERNEL_VERSION/amd64/$ALL_HEADERS_NAME" -q --show-progress
wget -O /tmp/latest-kernel/$LINUX_IMAGE_NAME "https://kernel.ubuntu.com/~kernel-ppa/mainline/$KERNEL_VERSION/amd64/$LINUX_IMAGE_NAME" -q --show-progress
wget -O /tmp/latest-kernel/$LINUX_MODULES_NAME "https://kernel.ubuntu.com/~kernel-ppa/mainline/$KERNEL_VERSION/amd64/$LINUX_MODULES_NAME" -q --show-progress

