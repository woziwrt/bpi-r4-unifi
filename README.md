# BPI-R4 UniFi Stack on OpenWrt

Run **UniFi Protect** and **UniFi Network Application** on a **Banana Pi R4** router — a cost-effective alternative to the Ubiquiti UNVR + Cloud Gateway combo.

This project provides a scripted installation chain — from a blank device to a working UniFi stack with live camera feed and managed WiFi. All required files are downloaded automatically from this repository's releases.

> **Tested hardware:** Banana Pi R4 rev 1.0 (MediaTek MT7988A) · UniFi G5 Flex camera · UniFi U7-LR WiFi 7 AP  
> **Minimum NVMe disk size:** 500 GB (1 TB recommended for Continuous Recording)

---

## What you need

- Banana Pi R4 (rev 1.2+ recommended — see [Hardware Notes](#hardware-notes))
- NVMe SSD, minimum 500 GB (installed in the BPI-R4 M.2 slot)
- microSD card (temporary, 1 GB or larger)
- Ethernet cable (internet access required during installation)
- A [Ubiquiti account](https://account.ui.com) (optional — required only for Remote Access)
- UniFi camera (G5 Flex tested)
- UniFi Access Point (U7-LR WiFi 7 tested)
- PoE switch or injector for the AP

---

## What you get

| Service | Address |
|---------|---------|
| UniFi Protect | `https://192.168.1.1` |
| UniFi Network Application | `https://192.168.1.2:8443` |
| LuCI | `http://192.168.1.1:8081` |

---

## Installation

### Step 1 — Flash SD card

1. Download `bpi-r4-rescue-sdcard.img.gz` from the [Releases](../../releases) page.
2. Flash it to a microSD card using [Balena Etcher](https://etcher.balena.io) or similar tool.
3. Insert the SD card into the BPI-R4.
4. Set the DIP switch to **SD boot**.
5. Power on the device.

### Step 2 — Install rescue system to NAND

1. Open a browser and go to `http://192.168.1.1` (LuCI).
2. Navigate to **Services → Terminal**.
3. Run:

```sh
cd /root/bpi-r4-install
sh install-nand.sh
```

4. Press **Enter** to confirm flashing.
5. Wait for the process to complete.
6. Power off the device.
7. Set the DIP switch to **NAND boot**.
8. Connect an ethernet cable with internet access.
9. Power on the device.

### Step 3 — Install OpenWrt + UniFi stack to NVMe

1. Open a browser and go to `http://192.168.1.1` (LuCI).
2. Navigate to **Services → Terminal**.
3. Run:

```sh
cd /root/bpi-r4-install
sh install-nvme.sh
```

4. Follow the on-screen prompts:
   - **File source:** select `1` (Download from GitHub)
   - **Release:** select `1` (Default woziwrt/bpi-r4-unifi)
   - **Ethernet connected?** type `yes`
   - **Type `YES`** to confirm NVMe erase and installation

5. The script downloads all files (~800 MB), installs OpenWrt to NVMe, and reboots automatically.

> After reboot, LuCI is available at `http://192.168.1.1:8080`

### Step 4 — Run UniFi Protect setup

1. Open a browser and go to `http://192.168.1.1:8080` (LuCI).
2. Navigate to **Services → Terminal**.
3. Run:

```sh
cd /mnt/nvme0n1p3
sh unifi-setup.sh
```

4. When prompted, **disconnect the internet cable** (required for first-time Protect setup), then press **Enter**.
5. Wait for setup to complete (~1–2 minutes).

### Step 5 — Run UniFi Network Application setup

1. In the same terminal, run:

```sh
cd /mnt/nvme0n1p3
sh unifi-network-setup.sh
```

2. The script will:
   - Move LuCI to port 8081 (freeing 8080 for Network Application)
   - Set up the `enp0s3` macvlan interface at `192.168.1.2`
   - Configure nftables firewall rules
   - Pull and start the Network Application containers

---

## First-time Protect configuration

1. Open `https://192.168.1.1` in your browser.
2. Accept the SSL warning (self-signed certificate — this is expected).
3. On the **No Internet Detected** screen, choose **Other Configuration Options → Local Network → Set Up Console Offline**.
4. Enter a name for your console (e.g. `BPI-R4-UniFi`) and click **Next**.
5. Set a password and click **Finish**.
6. Wait for **Setup Complete!** and click **Go to Dashboard**.

### Immediately after first login — disable auto-updates

Go to **Settings (gear icon) → General → Software Updates** and disable all auto-update options.

> Leaving auto-update enabled risks breaking your installation with an incompatible version.

---

## First-time Network Application configuration

1. Open `https://192.168.1.2:8443` in your browser.
2. Accept the SSL warning.
3. Complete the setup wizard.
4. Go to **Settings → System** and disable auto-updates.

---

## Adding a camera

1. Connect the camera via ethernet to a LAN port and power it on.
2. Perform a hardware reset (hold reset button until LED changes).
3. In the Protect dashboard → **Devices** — the camera should appear and can be adopted.
4. Camera status dot turns green — camera is online.

---

## Adopting an Access Point

After factory reset, the AP will not auto-discover the Network Application. Use SSH set-inform:

```sh
ssh ubnt@<AP_IP> "/usr/bin/syswrapper.sh set-inform http://192.168.1.2:8080/inform"
```

Default credentials after factory reset: `ubnt` / `ubnt`

Once adopted, the AP remembers the controller address and reconnects automatically after reboots.

> **Note:** DHCP option 43 is not required and is ignored by recent UniFi firmware.

---

## After reboot

Both UniFi Protect and UniFi Network Application start automatically on every boot.

> **Note:** After a cold boot, allow approximately 10 minutes for both services to fully initialize. UniFi Protect is available first (~3 minutes), followed by UniFi Network Application (~8–10 minutes).

---

## WAN Reconnect

When the WAN interface goes down and comes back up (ISP outage, cable reconnect), OpenWrt performs a `fw4 reload` which clears the custom nftables rules required by the Docker bridge network. This causes the **UniFi Network Application to lose connectivity** until the rules are restored — a reboot fixes it, but that is not always practical.

To restore the rules automatically on every WAN reconnect, install the provided hotplug hook:

1. Download `99-docker-nft` from the [Releases](../../releases) page.
2. Copy it to the router:

```sh
scp -P 2222 99-docker-nft root@192.168.1.1:/etc/hotplug.d/iface/99-docker-nft
chmod +x /etc/hotplug.d/iface/99-docker-nft
``

The hook fires on every WAN `ifup` event, waits 3 seconds for the bridge to stabilize, and re-runs `rc-network.sh`.

> **Note:** UniFi Protect is not affected — it runs with `--network host` and does not depend on bridge nftables rules.

---
## Hardware Notes

### BPI-R4 rev 1.0 known issues

| Issue | Details |
|-------|---------|
| NVMe + SFP conflict | Some NVMe disks pull down the I2C bus, disabling SFP ports and other I2C devices |
| Affected disks | Chinese OEM NVMe drives (e.g. generic 128 GB) |
| Not affected | Samsung EVO series — SFP ports remain functional |
| Fixed in | Rev 1.2+ — Sinovoip resolved the I2C/NVMe conflict in hardware |

### Recommended hardware for development

For new builds, the **BPI-R4 with 8 GB RAM** (rev 1.2+) is recommended:

- NVMe and SFP ports work simultaneously
- 8 GB RAM provides more headroom for Docker workloads

---

## Architecture

This project deliberately separates responsibilities:

- **BPI-R4** — routing, firewall, Docker runtime, NVMe storage
- **UniFi Protect** — camera management (via [dciancu](https://github.com/dciancu/unifi-protect-unvr-docker-arm64) Docker image)
- **UniFi Network Application** — WiFi management (via linuxserver Docker image)
- **UniFi AP** — professional WiFi (U7-LR WiFi 7 tested)

This avoids the known signal/noise issues of the BPI-R4's onboard BE14 WiFi module while delivering enterprise-grade WiFi through a proper UniFi AP.

---

## NVMe Partition Layout

| Partition | Size | Purpose |
|-----------|------|---------|
| p1 | 255 MB | Boot |
| p2 | 448 MB | Root filesystem |
| p3 | 30 GB (dev) / 15 GB (prod) | Docker data |
| p4 | remainder | Protect storage |

---

## Notes

- UniFi Protect web interface: `https://192.168.1.1`
- UniFi Network Application: `https://192.168.1.2:8443`
- LuCI web interface: `http://192.168.1.1:8081`
- Continuous Recording requires the Protect partition (p4) to be at least 100 GB

---

<img width="1264" height="1080" alt="Snímek obrazovky 2026-04-16 v 13 46 09" src="https://github.com/user-attachments/assets/1483d00f-839a-4ced-b899-6d688e0483a7" />

<img width="1264" height="1080" alt="Snímek obrazovky 2026-04-16 v 13 47 59" src="https://github.com/user-attachments/assets/f912c22e-a31c-42e6-8fc7-34e1632a8bc7" />

<img width="1264" height="1080" alt="Snímek obrazovky 2026-04-16 v 13 43 29" src="https://github.com/user-attachments/assets/ae709b45-ad2a-44ff-ab7b-73b9d5f1d6d9" />

<img width="1264" height="1080" alt="Snímek obrazovky 2026-04-16 v 14 08 39" src="https://github.com/user-attachments/assets/b6ce49af-bd91-4a67-87b2-c77ee121f051" />

<img width="1264" height="1080" alt="Snímek obrazovky 2026-04-16 v 13 45 12" src="https://github.com/user-attachments/assets/5c891a7c-017c-400d-8078-99850ccb86b8" />

<img width="660" height="1434" alt="IMG_7371" src="https://github.com/user-attachments/assets/aac7b973-ccdf-469f-b027-d8755032469c" />

<img width="660" height="1434" alt="IMG_7368 2" src="https://github.com/user-attachments/assets/a703787d-9e16-4195-b495-65b1b4334ca6" />

<img width="660" height="1434" alt="IMG_7372" src="https://github.com/user-attachments/assets/3cc43eb4-89cc-4f1d-be6c-9ded25f12f07" />

<img width="660" height="1434" alt="IMG_7375" src="https://github.com/user-attachments/assets/be266889-b238-4aba-b3b7-53dba31d7e86" />





*This project is not affiliated with Ubiquiti Inc. in any way.*

*🍌 TEAM WOZIWRT+CLAUDE*
