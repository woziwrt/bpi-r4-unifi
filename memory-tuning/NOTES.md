# UniFi Stack Memory Tuning — BPI-R4 (4GB RAM)

## Problem

After ~2 days of uptime, the UniFi stack (Network + Protect) caused complete
system freeze due to memory exhaustion. Load average reached 14+, only 35MB RAM
free, Docker daemon unresponsive.

Root cause: MongoDB WiredTiger cache growing to 1.44GB (50% of RAM by default),
Java heap growth in UniFi Network application, UniFi Protect video buffers.

## Changes Applied (2026-04-26)

### 1. MongoDB WiredTiger cache limit

Added `--wiredTigerCacheSizeGB 0.25` to mongod command in docker-compose.yml.

Default: ~1.44GB (50% of system RAM)
After: 256MB

### 2. Docker memory limits

Added `mem_limit: 1g` to both unifi-network and unifi-db containers.

This prevents any single container from consuming more than 1GB RAM.
Total budget for network stack: 2GB
Remaining for UniFi Protect: ~2GB

### 3. Swap file on NVMe

Created 2GB swap file on NVMe p3 partition as safety net.

```bash
dd if=/dev/zero of=/mnt/nvme0n1p3/swapfile bs=1M count=2048
chmod 600 /mnt/nvme0n1p3/swapfile
mkswap /mnt/nvme0n1p3/swapfile
swapon /mnt/nvme0n1p3/swapfile
```

Added to /etc/rc.local for persistence after reboot:
```
swapon /mnt/nvme0n1p3/swapfile
```

Note: kernel warning "does not support swap limit capabilities" is cosmetic —
RAM limit is enforced, swap limit is not. Requires CONFIG_MEMCG_SWAP=y in kernel
config to fix (TODO: add to next OpenWrt build).

## Kernel Config TODO

Add to next OpenWrt build config:
```
CONFIG_MEMCG_SWAP=y
```

This enables swap limit support in cgroups, which eliminates the Docker warning
and allows proper swap accounting per container.

## Status

Deployed 2026-04-26. Monitoring in progress — results expected after several days
of uptime. If stable, integrate swapfile setup into install script.
