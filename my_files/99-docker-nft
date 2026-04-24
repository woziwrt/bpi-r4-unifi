#!/bin/sh
# Restore Docker bridge nftables rules after WAN reconnect.
# Place in /etc/hotplug.d/iface/99-docker-nft and make executable.
# OpenWrt fw4 reload (triggered by WAN ifup events) clears custom nft rules
# used by the Docker bridge network. This hook restores them automatically.

[ "$INTERFACE" = "wan" ] || exit 0
[ "$ACTION" = "ifup" ] || exit 0
sleep 3
/mnt/nvme0n1p3/rc-network.sh > /dev/null 2>&1
