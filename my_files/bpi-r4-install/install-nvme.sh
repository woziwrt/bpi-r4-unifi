#!/bin/sh
# install-nvme.sh - BPI-R4 UniFi NVMe installer launcher
# Located in NAND rescue root, downloads and runs install-nvme-unifi.sh from GitHub
# Usage: ./install-nvme.sh [test]

GH_USER="woziwrt"
GH_REPO="bpi-r4-unifi"
GH_TAG="release-nvme-unifi"

wget -O install-nvme-unifi.sh \
    "https://github.com/${GH_USER}/${GH_REPO}/releases/download/${GH_TAG}/install-nvme-unifi.sh"

chmod +x install-nvme-unifi.sh
./install-nvme-unifi.sh $@