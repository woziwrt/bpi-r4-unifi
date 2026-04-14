# BPI-R4 UniFi Protect on OpenWrt

Run UniFi Protect (UNVR replacement) on Banana Pi BPI-R4 with OpenWrt and NVMe storage.

---

> ## ⚠️ WARNING — WORK IN PROGRESS
>
> **THIS PROJECT IS UNDER ACTIVE DEVELOPMENT AND IS NOT COMPLETE.**
>
> - Documentation is incomplete
> - Some features may not work as expected
> - Breaking changes may occur without notice
> - **DO NOT USE IN PRODUCTION**
>
> This README documents the current state of development.
> Proceed only if you know what you are doing.

---

## Overview

This project enables running [UniFi Protect](https://ui.com/camera-security) on a [Banana Pi BPI-R4](https://wiki.banana-pi.org/Banana_Pi_BPI-R4) router running a custom OpenWrt build, using Docker and NVMe storage. It uses the excellent [dciancu/unifi-protect-unvr-docker-arm64](https://github.com/dciancu/unifi-protect-unvr-docker-arm64) container image.

The result is a cost-effective alternative to the Ubiquiti UNVR hardware, running on a compact ARM64 router with Wi-Fi 7 support.

**Key capabilities:**
- Full UniFi Protect stack in Docker on NVMe
- Camera auto-discovery and adoption
- Continuous and event-based recording
- Remote access via Ubiquiti cloud
- Self-installing from a single script

---

## Hardware Requirements

- **Banana Pi BPI-R4** (4GB RAM variant — mandatory, 2GB is not enough)
- **NVMe SSD** — minimum 128GB recommended
  - For Continuous recording: p4 partition must be >= 100GB
  - Patriot P300 128GB tested (p4 = 109GB with test profile)
- **MicroSD card** — temporary, only needed for initial install (>= 1GB)
- **UniFi camera** — tested with G5 Flex
- Custom OpenWrt build from [woziwrt/bpi-r4-openwrt-builder](https://github.com/woziwrt/bpi-r4-openwrt-builder) with Docker and NVMe support

---

## How It Works

The installation is fully automated in two stages:

1. **`install-nvme-unifi.sh`** — runs from NAND rescue, partitions NVMe, installs OpenWrt, downloads `unifi-setup.sh` to p3, reboots into NVMe
2. **`unifi-setup.sh`** — runs once after first NVMe boot, configures Docker, network interfaces, firewall, loads the Protect image, starts the container

After setup, `rc.local` handles autostart on every subsequent reboot.

---

## Installation

### Step 1 — Prerequisites

You need a custom BPI-R4 OpenWrt build with:
- Docker support (`dockerd`)
- NVMe support
- `kmod-dummy` kernel module

Use [woziwrt/bpi-r4-openwrt-builder](https://github.com/woziwrt/bpi-r4-openwrt-builder) to build or download a compatible image.

### Step 2 — Flash SD rescue

Flash the SD rescue image to a microSD card and boot from it:

```
DIP switches: SD boot
```

Run from SD rescue:
```bash
./install-nand.sh
```

This installs the NAND rescue system. Power off, remove SD card.

### Step 3 — Boot from NAND rescue

```
DIP switches: NAND boot
```

Download and run the NVMe installer:
```bash
wget https://github.com/woziwrt/bpi-r4-unifi/releases/download/release-nvme-unifi/install-nvme-unifi.sh
chmod +x install-nvme-unifi.sh
./install-nvme-unifi.sh        # production profile (p4 = full disk)
# or
./install-nvme-unifi.sh test   # test profile (smaller p4, faster testing)
```

This will:
- Download OpenWrt NVMe image and boot files from GitHub release
- Partition and flash NVMe
- Download `unifi-setup.sh` to `/mnt/nvme0n1p3/`
- Reboot into NVMe

### Step 4 — First boot setup

After booting from NVMe, run:
```bash
/mnt/nvme0n1p3/unifi-setup.sh
```

**Important:** Disconnect WAN/internet before proceeding through the Protect setup wizard. You will be prompted.

The script will:
1. Configure Docker data root on NVMe
2. Reconfigure uhttpd to port 8080 (frees ports 80/443 for Protect)
3. Configure firewall rules for Protect
4. Set up `enp0s2` (macvlan) and `enp0s1` (dummy) network interfaces
5. Load the Protect Docker image
6. Create storage structure on NVMe p4
7. Start UniFi Protect container

### Step 5 — Install rc.local for autostart

Copy `rc.local` from this repository to `/etc/rc.local` and make it executable:
```bash
cp /mnt/nvme0n1p3/rc.local /etc/rc.local
chmod +x /etc/rc.local
```

This ensures Protect starts automatically after every reboot.

### Step 6 — Protect first-run wizard

Navigate to `https://192.168.1.1` and complete the setup:

1. Select **Offline setup** (internet must be disconnected)
2. Set console name
3. Set admin password
4. **Immediately disable auto-update** in Console Settings -> General
5. Connect internet
6. Enable Remote Access (optional)

### Step 7 — Add camera

After setup, cameras on the same LAN segment are discovered automatically via UDP port 10001. The camera should appear in Protect UI within ~30 seconds. Click **Adopt**.

If auto-discovery does not work, you can manually set the controller address in the camera's web UI: `https://<camera-ip>` -> Settings -> set controller to `192.168.1.1`.

---

## Network Architecture

This setup uses a non-standard network topology to satisfy UniFi Protect requirements while running on OpenWrt.

### The problem

UniFi Protect (`unifi-core`) uses `ubnt-tools` to generate a `serialno` at startup:
```
ip route get 8.8.8.8 -> finds default interface -> reads MAC -> generates serialno
```

The interface MAC must be **globally administered** (standard OUI prefix). OpenWrt's `br-lan` uses a **locally administered MAC** (`c2:...`) which causes `unifi-core` to fail with `Invalid MAC address`.

Additionally, Protect requires the primary interface to be named `enp0s2` (mimicking real UNVR hardware) and the interface must show as **UP with carrier** (green in Protect UI) for camera auto-discovery to work.

### The solution

**`enp0s2`** — macvlan interface over `br-lan`:
- Inherits carrier from `br-lan` -> shows green in Protect UI
- Has globally administered MAC `00:50:43:ba:d0:01`
- IP `192.168.1.1/24` with default route
- Enables camera auto-discovery (UDP broadcast on port 10001 reaches LAN)

**`enp0s1`** — dummy interface:
- Required to mimic real UNVR hardware (which has 2 network interfaces)
- No IP, no carrier — just needs to exist

**Default route inside container:**
- `network_mode: host` shares the network namespace but routes added on host before container start are not visible inside
- Must be injected via `docker exec` after container startup

### Why not a simple dummy interface?

A dummy interface (`ip link add enp0s2 type dummy`) has no carrier -> Protect shows the interface as grayed out -> camera UDP discovery packets are not processed -> cameras cannot be auto-discovered.

---

## Files in This Repository

| File | Description |
|------|-------------|
| `install-nvme-unifi.sh` | NVMe installer, runs from NAND rescue |
| `unifi-setup.sh` | First-boot setup script, runs once after NVMe boot |
| `rc.local` | Autostart script for subsequent reboots |

### Release Assets

Available at [release-nvme-unifi](https://github.com/woziwrt/bpi-r4-unifi/releases/tag/release-nvme-unifi):

| File | Size | Description |
|------|------|-------------|
| `openwrt-mediatek-filogic-bananapi_bpi-r4-nvme-img.bin` | 624MB | OpenWrt NVMe image |
| `openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb` | 112MB | OpenWrt boot files |
| `unifi-protect-dciancu.tar.gz` | 658MB | Pre-built Protect Docker image (ARM64) |
| `install-nvme-unifi.sh` | — | NVMe installer script |
| `unifi-setup.sh` | — | First-boot setup script |

> **Note:** `unifi-protect-dciancu.tar.gz` is built locally from [dciancu/unifi-protect-unvr-docker-arm64](https://github.com/dciancu/unifi-protect-unvr-docker-arm64) and is not available on Docker Hub (Ubiquiti IP reasons).

---

## Known Issues and Limitations

### Storage Manager shows "No Drives Found"
Since UniFi OS 4.1.11+, storage management moved to gRPC `ustate`. The Storage Manager UI may show no drives. This is a known upstream issue — recording still works correctly. See [dciancu/unifi-protect-unvr-docker-arm64#23](https://github.com/dciancu/unifi-protect-unvr-docker-arm64/issues/23).

### Minimum storage for Continuous recording
Protect requires at least ~100GB on the storage partition (p4) for Continuous recording. Below this threshold, only Events recording is available. Use production profile (not test) for full functionality.

### Auto-update must be disabled
After first setup, immediately disable auto-update in Console Settings. Auto-update will break the container.

### rc.local must be installed manually
Currently `rc.local` must be copied manually after first setup. This will be automated in a future version of `unifi-setup.sh`.

### Network Controller port conflict
Running UniFi Network Controller alongside Protect will cause a port conflict on UDP 10001. This has not been resolved yet.

---

## TODO

- [ ] Automate `rc.local` installation in `unifi-setup.sh`
- [ ] Network Controller integration (port 10001 conflict resolution)
- [ ] UniFi AP support (waiting for hardware)
- [ ] IPv6 verification

---

## Credits

- [dciancu/unifi-protect-unvr-docker-arm64](https://github.com/dciancu/unifi-protect-unvr-docker-arm64) — the Docker image that makes this possible
- [frank-w/BPI-R4](https://github.com/frank-w/BPI-R4) — OpenWrt kernel patches and support
- [woziwrt/bpi-r4-openwrt-builder](https://github.com/woziwrt/bpi-r4-openwrt-builder) — custom OpenWrt build system

---

*This project is not affiliated with Ubiquiti Inc. in any way.*
