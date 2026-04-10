#!/bin/sh
NVME="/mnt/nvme0n1p3"

# Directory structure
mkdir -p $NVME/unifi-network/config/data
mkdir -p $NVME/unifi-network/db
mkdir -p $NVME/unifi-protect/{srv,data,persistent}

# Docker data-root na NVMe
uci set dockerd.globals.data_root=$NVME/docker
uci set dockerd.globals.dns=8.8.8.8
uci commit dockerd
/etc/init.d/dockerd restart
sleep 5

# Copy configs
cp /etc/unifi/init-mongo.js $NVME/unifi-network/init-mongo.js
cp /etc/unifi/system.properties $NVME/unifi-network/config/data/system.properties
cp /etc/unifi/docker-compose.yml $NVME/unifi-network/docker-compose.yml

# fw4 pravidla
uci add_list firewall.docker.device='br-+'
uci add firewall.protect_adoption=rule
uci set firewall.protect_adoption.name='Allow-Protect-Adoption'
uci set firewall.protect_adoption.src='lan'
uci set firewall.protect_adoption.dest_port='7442 7444 7550'
uci set firewall.protect_adoption.proto='tcp'
uci set firewall.protect_adoption.target='ACCEPT'
uci commit firewall && fw4 reload

# Start Network stack
cd $NVME/unifi-network && docker-compose up -d

# Start Protect
docker run -d \
--name unifi-protect \
--privileged \
--cgroupns host \
--tmpfs /run \
--tmpfs /run/lock \
--tmpfs /tmp \
--restart unless-stopped \
-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
-v $NVME/unifi-protect/srv:/srv \
-v $NVME/unifi-protect/data:/data \
-v $NVME/unifi-protect/persistent:/persistent \
--network host \
-e STORAGE_DISK=/dev/nvme0n1p3 \
markdegroot/unifi-protect-arm64

# Autostart
cat > /etc/rc.local << 'EOF'
#!/bin/sh
cd /mnt/nvme0n1p3/unifi-network && docker-compose up -d
exit 0
EOF
chmod +x /etc/rc.local

# Done
IP=$(uci get network.lan.ipaddr | cut -d'/' -f1)
echo ""
echo "? UniFi Network: https://$IP:8443"
echo "? UniFi Protect: https://$IP"
echo "? Camera IP:     cat /tmp/dhcp.leases"