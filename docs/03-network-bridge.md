# 3. Switch networking to an ifupdown2 bridge

Armbian manages the network with netplan, systemd-networkd and systemd-resolved
(DHCP on all ports). Proxmox needs ifupdown2 with a `vmbr0` bridge and a static
address, like a normal x86 Proxmox host.

## Target `/etc/network/interfaces`

```
auto lo
iface lo inet loopback

iface lan1 inet manual

auto vmbr0
iface vmbr0 inet static
	address 192.168.x.y/24
	gateway 192.168.x.1
	bridge-ports lan1
	bridge-stp off
	bridge-fd 0
	hwaddress <lan1 MAC>

iface wan1 inet manual

source /etc/network/interfaces.d/*
```

- The physical ports (`lan1`, `wan1`) are `manual`. The IP goes on `vmbr0`.
- `hwaddress` is `lan1`'s MAC (`ip link show lan1`), so the router keeps seeing the same device.

## Option A: the script (works over SSH, rolls back on failure)

[`scripts/pve-network-switch.sh`](../scripts/pve-network-switch.sh) writes the
file above, deletes `interfaces.new`, disables netplan, networkd and resolved,
writes a static `/etc/resolv.conf`, and applies the change live. If
`/root/net-ok` hasn't been created within 180 s, it restores the old setup.

```bash
# from the Mac
scp scripts/pve-network-switch.sh root@192.168.x.y:/root/
ssh root@192.168.x.y 'IFACE=lan1 ADDR=192.168.x.y/24 GW=192.168.x.1 DNS=192.168.x.1 \
  systemd-run --unit=net-switch /root/pve-network-switch.sh'

# within 3 minutes, confirm it still answers:
ssh root@192.168.x.y 'touch /root/net-ok; ip -br a'
```

Log: `/root/net-switch.log` on the board.

## Option B: by hand (from a local console)

```bash
# write /etc/network/interfaces as above, then:
rm -f /etc/network/interfaces.new
mkdir -p /etc/netplan.disabled && mv /etc/netplan/*.yaml /etc/netplan.disabled/
systemctl disable systemd-networkd.socket systemd-networkd systemd-networkd-wait-online systemd-resolved
rm /etc/resolv.conf && printf 'search lan\nnameserver 192.168.x.1\n' > /etc/resolv.conf
systemctl enable networking
reboot
```

## Gotchas

- **`/etc/network/interfaces.new` must not exist** when you reboot.
  `pvenetcommit.service` moves it over `interfaces` at boot. The one ifupdown2
  left during install has only `manual` ports, so the board comes up with no IP.
  The same mechanism applies the web UI's Network panel changes: they wait in
  `interfaces.new` until you click "Apply Configuration" or reboot.
- **Live `ifreload -a` fails with "Another instance of this program is already running"**
  if `/run/network` doesn't exist yet. It's really a missing lock directory.
  Fix: `mkdir -p /run/network`. At boot, `networking.service` creates it.
- If the network is down after a reboot, use the console to fix the file, then run
  `mkdir -p /run/network && ifreload -a`.

## Verify

```bash
reboot
# then:
ip -br a | grep vmbr0                 # 192.168.x.y/24
ping -c1 192.168.x.1 && getent hosts deb.debian.org
```
