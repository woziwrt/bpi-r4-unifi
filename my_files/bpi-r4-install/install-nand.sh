#!/bin/sh
# BPI-R4 - Install rescue system to NAND
# Run from SD card: sh /root/bpi-r4-install/install-nand.sh

set -e

INSTALL_DIR="/root/bpi-r4-install"
NAND_IMG="${INSTALL_DIR}/snand-img.bin"

echo ""
echo "=================================================="
echo "  BPI-R4 - Install rescue system to NAND"
echo "=================================================="
echo ""

# Verify we are running from SD card
if ! grep -q "fitrw" /proc/mounts 2>/dev/null; then
    echo "ERROR: This script must be run from the SD card!"
    echo "       Make sure the DIP switch is set to SD boot."
    exit 1
fi

echo "OK: System is running from SD card."
echo ""

# Verify snand-img.bin exists
if [ ! -f "${NAND_IMG}" ]; then
    echo "ERROR: File ${NAND_IMG} not found!"
    echo "       Copy snand-img.bin to ${INSTALL_DIR}/"
    exit 1
fi

echo "OK: snand-img.bin found ($(du -h ${NAND_IMG} | cut -f1))."
echo ""

# Verify NAND device is available
if ! grep -q "spi0.0" /proc/mtd 2>/dev/null; then
    echo "ERROR: NAND device (spi0.0) not found in /proc/mtd!"
    exit 1
fi

echo "OK: NAND device found."
echo ""

# Final warning before flashing
echo "WARNING: The entire NAND flash will be overwritten!"
echo "         Press ENTER to continue or CTRL+C to cancel."
read _

echo ""
echo "Flashing snand-img.bin to NAND..."
mtd -e spi0.0 write "${NAND_IMG}" spi0.0

echo ""
echo "=================================================="
echo "  DONE! Rescue system installed to NAND."
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Power off the device"
echo "  2. Switch DIP to NAND boot"
echo "     (see BPI-R4 documentation for DIP switch position)"
echo "  3. Power on the device"
echo "  4. Login via SSH and run:"
echo "     sh /root/bpi-r4-install/install-nvme.sh"
echo ""