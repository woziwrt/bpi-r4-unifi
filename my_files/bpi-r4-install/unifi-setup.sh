#!/bin/sh
# unifi-setup.sh ó BPI-R4 UniFi setup (dciancu)
# Run after first NVMe boot

NVME_DATA="/mnt/nvme0n1p3"
NVME_PROTECT="/mnt/nvme0n1p4"
COMPOSE_DIR="$NVME_DATA/unifi-protect"
IMAGE_TAR="$NVME_DATA/unifi-protect-dciancu.tar.gz"
IMAGE_NAME="dciancu/unifi-protect-unvr-docker-arm64:stable"
GH_USER="woziwrt"
GH_REPO="bpi-r4-unifi"
GH_TAG="release-nvme-unifi"

ENP0S2_MAC="00:50:43:ba:d0:01"
ENP0S2_IP="192.168.1.1/24"
ENP0S2_GW="192.168.1.1"
LAN_BRIDGE="br-lan"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

printf "\n"
printf "=================================================\n"
printf "  BPI-R4 UniFi Setup (dciancu)\n"
printf "=================================================\n"
printf "\n"

# || 1. Docker |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 1/7 ] Configuring Docker...\n"

uci set dockerd.globals.data_root=$NVME_DATA/docker
uci set dockerd.globals.dns=8.8.8.8
uci commit dockerd
/etc/init.d/dockerd restart
sleep 5

# Remove duplicate docker zone that dockerd just created + any old leftovers
for SECTION in $(uci show firewall | grep "\.name='docker'" | cut -d'.' -f1-2); do
    echo "$SECTION" | grep -q '@' && uci delete "$SECTION" 2>/dev/null || true
done
uci commit firewall

printf "        OK\n\n"

# || 2. uhttpd ó free ports 80/443 for Protect nginx |||||||||||||||||||||||

printf "[ 2/7 ] Reconfiguring uhttpd (LuCI HTTP only -> 8080)...\n"

uci set uhttpd.main.listen_http='0.0.0.0:8080'
uci delete uhttpd.main.listen_https 2>/dev/null || true
uci commit uhttpd
/etc/init.d/uhttpd restart

printf "        OK\n\n"

# || 3. Firewall |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 3/7 ] Configuring firewall...\n"

# Remove all existing Protect rules to avoid duplicates
for RULE in $(uci show firewall | grep -E "Allow-Protect|Allow-Docker" | grep "\.name=" | cut -d'.' -f1-2); do
    uci delete "$RULE" 2>/dev/null || true
done

# Protect HTTPS
SECTION=$(uci add firewall rule)
uci set firewall.$SECTION.name='Allow-Protect-HTTPS'
uci set firewall.$SECTION.src='lan'
uci set firewall.$SECTION.dest_port='443'
uci set firewall.$SECTION.proto='tcp'
uci set firewall.$SECTION.target='ACCEPT'

# Protect Adoption
SECTION=$(uci add firewall rule)
uci set firewall.$SECTION.name='Allow-Protect-Adoption'
uci set firewall.$SECTION.src='lan'
uci set firewall.$SECTION.dest_port='7442 7444 7550'
uci set firewall.$SECTION.proto='tcp'
uci set firewall.$SECTION.target='ACCEPT'

uci commit firewall
fw4 reload

printf "        OK\n\n"

# || 4. Network interfaces ó enp0s2 (macvlan) + enp0s1 (dummy) ||||||||||||
#
# Real UNVR has 2 network interfaces: enp0s1 and enp0s2
# enp0s2: primary interface ó ubnt-tools reads its MAC to generate serialno
#         Must be macvlan over br-lan (not dummy) so it has carrier (UP state)
#         Dummy interface has no carrier õ Protect shows grayed interface õ
#         camera auto-discovery fails
# enp0s1: secondary interface ó required to fully mimic UNVR hardware
#
# CRITICAL: enp0s2 MAC must be globally administered (00:50:43:...)
#           br-lan has locally administered MAC (c2:...) which causes
#           ubnt-tools serialno generation to fail

printf "[ 4/7 ] Setting up network interfaces (enp0s2 macvlan + enp0s1 dummy)...\n"

modprobe dummy

# enp0s2 ó macvlan over br-lan
# macvlan inherits carrier from parent õ interface shows green in Protect UI
# mode bridge allows L2 communication with other devices on br-lan segment
# This enables camera auto-discovery (UDP port 10001)
if ip link show enp0s2 > /dev/null 2>&1; then
    ip link del enp0s2 2>/dev/null || true
fi

ip link add enp0s2 link $LAN_BRIDGE type macvlan mode bridge
ip link set enp0s2 address $ENP0S2_MAC
ip addr add $ENP0S2_IP dev enp0s2
ip link set enp0s2 up

# Default route via enp0s2 ó CRITICAL for ubnt-tools serialno generation
# ubnt-tools runs: ip route get 8.8.8.8 õ finds interface õ reads MAC õ serialno
# Without default route: ip route get returns empty õ serialno empty õ
# unifi-core fails with "Invalid MAC address"
ip route add default via $ENP0S2_GW dev enp0s2 2>/dev/null || true

# enp0s1 ó dummy secondary interface to mimic real UNVR hardware
if ip link show enp0s1 > /dev/null 2>&1; then
    ip link del enp0s1 2>/dev/null || true
fi
ip link add enp0s1 type dummy
ip link set enp0s1 up

# Download rc.local while internet is still available
# MUST be done here ó after step 7 WAN is disconnected for Protect first setup
RC_URL="https://github.com/${GH_USER}/${GH_REPO}/releases/download/${GH_TAG}/rc.local"
wget -O "$NVME_DATA/rc.local" "$RC_URL"
cp "$NVME_DATA/rc.local" /etc/rc.local
chmod +x /etc/rc.local

printf "        OK\n\n"

# || 5. Docker image ||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 5/7 ] Loading Docker image...\n"
printf "\n"

if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    printf "        Image already loaded, skipping.\n\n"
else
    printf "  [1] Download from GitHub release (default)\n"
    printf "  [2] Use local file ($IMAGE_TAR)\n"
    printf "\n"
    printf "  Select [1/2]: "
    read IMG_SOURCE

    case "$IMG_SOURCE" in
        2)
            if [ ! -f "$IMAGE_TAR" ]; then
                printf "${RED}ERROR: %s not found!${NC}\n" "$IMAGE_TAR"
                printf "       Copy tar.gz to $NVME_DATA first.\n\n"
                exit 1
            fi
            printf "        Loading from local file...\n"
            docker load < "$IMAGE_TAR"
            ;;
        *)
            TAR_URL="https://github.com/${GH_USER}/${GH_REPO}/releases/download/${GH_TAG}/unifi-protect-dciancu.tar.gz"
            printf "        Downloading from GitHub...\n"
            printf "        URL: %s\n" "$TAR_URL"
            wget -O "$IMAGE_TAR" "$TAR_URL"
            if [ $? -ne 0 ] || [ ! -s "$IMAGE_TAR" ]; then
                printf "${RED}ERROR: Download failed.${NC}\n\n"
                rm -f "$IMAGE_TAR"
                exit 1
            fi
            printf "        Loading image...\n"
            docker load < "$IMAGE_TAR"
            ;;
    esac

    if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
        printf "${RED}ERROR: Image load failed!${NC}\n\n"
        exit 1
    fi
    printf "        OK\n\n"
fi

# || 6. Storage structure ||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 6/7 ] Creating storage structure...\n"

mkdir -p $COMPOSE_DIR
mkdir -p $NVME_PROTECT/srv
mkdir -p $NVME_PROTECT/data
mkdir -p $NVME_PROTECT/persistent

cat > $COMPOSE_DIR/docker-compose.yml << 'EOF'
services:
  unifi-protect:
    image: dciancu/unifi-protect-unvr-docker-arm64:stable
    pull_policy: never
    tty: true
    hostname: UNVR
    extra_hosts:
      - "UNVR:127.0.1.1"
    container_name: unifi-protect
    stop_grace_period: 2m
    cgroup: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup
      - /mnt/nvme0n1p4/srv:/srv
      - /mnt/nvme0n1p4/data:/data
      - /mnt/nvme0n1p4/persistent:/persistent
    environment:
      - container=docker
      - STORAGE_DISK=/dev/nvme0n1p4
      - DEBUG=false
    restart: unless-stopped
    cap_add:
      - dac_read_search
      - sys_admin
    security_opt:
      - apparmor=unconfined
      - seccomp=unconfined
    tmpfs:
      - /run
      - /run/lock
      - /tmp
      - /var/run
      - /var/run/lock
    privileged: true
    network_mode: host
    devices:
      - /dev/nvme0n1p4:/dev/nvme0n1p4
EOF

printf "        OK\n\n"

# || 7. Start Protect ||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 7/7 ] Starting UniFi Protect...\n"
printf "\n"
printf "${YELLOW}  IMPORTANT: Internet should be disconnected during first setup!${NC}\n"
printf "  Disconnect WAN and press Enter to continue, or Ctrl+C to abort...\n"
read DUMMY

cd $COMPOSE_DIR && docker-compose up -d

# CRITICAL: default route must be added inside container AFTER it starts
# Container uses network_mode: host but routes added on host before container
# start are not visible inside. Must be injected via docker exec after startup.
# Without this, ubnt-tools inside container cannot find MAC õ serialno empty
# õ unifi-core fails with "Invalid MAC address"
printf "\n"
printf "  Waiting for container to start...\n"
sleep 30

docker exec unifi-protect ip route add default via $ENP0S2_GW dev enp0s2 2>/dev/null || true
docker exec unifi-protect systemctl restart unifi-core

# || Flag ó mark setup as complete |||||||||||||||||||||||||||||||||||||||||||
# rc.local checks for this flag ó without it, autostart is skipped on reboot

touch "$NVME_DATA/.unifi-setup-done"

printf "\n"

IP=$(uci get network.lan.ipaddr | cut -d'/' -f1)
printf "${GREEN}=================================================${NC}\n"
printf "${GREEN}  UniFi Setup complete!${NC}\n"
printf "${GREEN}=================================================${NC}\n"
printf "\n"
printf "  UniFi Protect : https://%s\n" "$IP"
printf "  LuCI          : http://%s:8080\n" "$IP"
printf "\n"
printf "${YELLOW}  After first login, immediately disable auto-update in:${NC}\n"
printf "  Console Settings -> General -> Auto Update\n"
printf "\n"