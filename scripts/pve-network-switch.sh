#!/bin/bash
# Run ON THE BOARD as root, after installing PXVIRT (docs/02).
# Switches Armbian networking from netplan/systemd-networkd/resolved to
# ifupdown2 with a Proxmox bridge vmbr0 and a static address.
#
# Auto-rollback: if /root/net-ok is not created within $TIMEOUT seconds,
# the previous netplan setup is restored. Start it detached so an SSH drop
# doesn't kill it:
#   IFACE=lan1 ADDR=192.168.x.y/24 GW=192.168.x.1 DNS=192.168.x.1 \
#     systemd-run --unit=net-switch /root/pve-network-switch.sh
# then, from a new SSH session: touch /root/net-ok
set -u

IFACE="${IFACE:-lan1}"                 # bridge port (physical NIC)
OTHER_IFACES="${OTHER_IFACES:-wan1}"   # other NICs, declared as manual
ADDR="${ADDR:?set ADDR, e.g. 192.168.x.y/24}"
GW="${GW:?set GW, e.g. 192.168.x.1}"
DNS="${DNS:-$GW}"
SEARCH="${SEARCH:-lan}"
TIMEOUT="${TIMEOUT:-180}"

LOG=/root/net-switch.log
exec >>"$LOG" 2>&1
echo "=== $(date) start: $IFACE -> vmbr0 $ADDR gw $GW"

B=/root/pre-pxvirt-backup
mkdir -p "$B"
[ -e "$B/interfaces" ] || cp -a /etc/network/interfaces "$B/interfaces" 2>/dev/null
[ -e "$B/resolv.conf.link" ] || readlink /etc/resolv.conf > "$B/resolv.conf.link"
rm -f /root/net-ok

MAC="$(cat /sys/class/net/$IFACE/address)"

{
  printf 'auto lo\niface lo inet loopback\n\n'
  printf 'iface %s inet manual\n\n' "$IFACE"
  printf 'auto vmbr0\niface vmbr0 inet static\n'
  printf '\taddress %s\n\tgateway %s\n' "$ADDR" "$GW"
  printf '\tbridge-ports %s\n\tbridge-stp off\n\tbridge-fd 0\n' "$IFACE"
  printf '\thwaddress %s\n\n' "$MAC"
  for i in $OTHER_IFACES; do printf 'iface %s inet manual\n\n' "$i"; done
  printf 'source /etc/network/interfaces.d/*\n'
} > /etc/network/interfaces
mkdir -p /etc/network/interfaces.d

# ifupdown2's postinst leaves this behind; pvenetcommit.service would move it
# over our config at the next boot.
rm -f /etc/network/interfaces.new

# Retire netplan + networkd + resolved
mkdir -p /etc/netplan.disabled
mv /etc/netplan/*.yaml /etc/netplan.disabled/ 2>/dev/null
rm -f /run/systemd/network/10-netplan-*
systemctl disable --now systemd-networkd.socket systemd-networkd systemd-networkd-wait-online 2>/dev/null
systemctl disable --now systemd-resolved
rm -f /etc/resolv.conf
printf 'search %s\nnameserver %s\n' "$SEARCH" "$DNS" > /etc/resolv.conf

ip addr flush dev "$IFACE"
systemctl enable networking
# ifupdown2 keeps its lock in /run/network; networking.service creates it at
# boot, but for a live switch it may not exist yet.
mkdir -p /run/network
ifreload -a || echo "ifreload rc=$?"
echo "applied:"; ip -br a

for _ in $(seq "$TIMEOUT"); do
  [ -e /root/net-ok ] && { echo "=== $(date) confirmed, keeping new config"; exit 0; }
  sleep 1
done

echo "=== $(date) NOT confirmed, rolling back"
ifdown vmbr0 2>/dev/null; ip link del vmbr0 2>/dev/null
printf 'auto lo\niface lo inet loopback\n' > /etc/network/interfaces
mv /etc/netplan.disabled/*.yaml /etc/netplan/
rm -f /etc/resolv.conf
ln -s "$(cat "$B/resolv.conf.link")" /etc/resolv.conf
systemctl enable --now systemd-resolved
systemctl enable systemd-networkd.socket systemd-networkd systemd-networkd-wait-online
netplan generate
systemctl restart systemd-networkd
echo "rolled back:"; ip -br a
