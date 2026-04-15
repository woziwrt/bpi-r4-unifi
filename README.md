
# BPI-R4 UniFi Protect on OpenWrt

Run **UniFi Protect** on a **Banana Pi R4** router as a cost-effective alternative to the Ubiquiti UNVR network video recorder.

This project provides a fully automated installation chain — from a blank device to a working UniFi Protect system with live camera feed — without any manual configuration. Everything is scripted and downloads automatically from this repository's releases.

> **Tested hardware:** Banana Pi R4 (MediaTek MT7988A) · UniFi G5 Flex camera  
> **Minimum NVMe disk size:** 500 GB (1 TB recommended for Continuous Recording)

---

## What you need

- Banana Pi R4
- NVMe SSD, minimum 500 GB (installed in the BPI-R4 M.2 slot)
- microSD card (temporary, 1 GB or larger)
- Ethernet cable (internet access required during installation)
- A free [Ubiquiti account](https://account.ui.com) (required for Remote Access and camera adoption)
- UniFi camera (G5 Flex tested)

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

### Step 3 — Install OpenWrt + UniFi Protect to NVMe

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

---

## First-time Protect configuration

1. Open `https://192.168.1.1` in your browser.
2. Accept the SSL warning (self-signed certificate — this is expected).
3. On the **No Internet Detected** screen, choose **Other Configuration Options → Local Network → Set Up Console Offline**.
4. Enter a name for your console (e.g. `BPI-R4-UniFi`) and click **Next**.
5. Set a password and click **Finish**.
6. Wait for **Setup Complete!** and click **Go to Dashboard**.
7. Accept the SSL warning again if prompted and log in with your password.

### Immediately after first login — disable auto-updates

Go to **Settings (gear icon) → General → Software Updates** and disable:
- **UNVR** auto-update
- **Protect** application auto-update
- **Device** auto-update

> Leaving auto-update enabled risks breaking your installation with an incompatible version.

### Enable Remote Access (optional)

1. Connect the internet cable.
2. Go to **Settings → Console → Remote Access** and enable it.
3. Log in with your Ubiquiti account and complete 2FA verification.

### Disable notifications (recommended)

Protect sends push notifications and emails for every action by default. To disable:

1. Go to **Settings → Control Plane → Push Notifications**.
2. Turn off all blue toggles.
3. Follow the link **"For Protect Application push notifications, go here"** and turn off all blue toggles there as well.

---

## Adding a camera

1. Connect the camera via ethernet and power it on.
2. Perform a hardware reset by pressing and holding the reset button on the camera.
3. In the Protect dashboard, click the **camera icon** in the left sidebar (**Devices**).
4. Wait for the camera to appear in the device list, then click **Adopt this Device**.
5. The camera status dot will turn from orange to green — camera is online.
6. Click the **Playback icon** in the left sidebar to view the live feed.

---

## After reboot

UniFi Protect starts automatically on every boot. No manual steps required.

---

## Notes

- LuCI web interface is available at `http://192.168.1.1:8080` (moved from port 80 to avoid conflict with Protect)
- UniFi Protect web interface: `https://192.168.1.1`
- Continuous Recording requires the NVMe protect partition (p4) to be at least 100 GB — guaranteed with a 500 GB+ disk
- This project is based on the Docker image by [dciancu](https://github.com/dciancu/unifi-protect-unvr-docker-arm64)---

*This project is not affiliated with Ubiquiti Inc. in any way.*
