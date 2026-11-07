# 2. Install PXVIRT (Proxmox VE for arm64)

Reference: <https://docs.pxvirt.lierfang.com/en/installfromdebian.html>

All commands run **as root on the board**.

## Check the board first

```bash
cat /etc/os-release | head -3   # must be trixie (Debian 13) for PXVIRT 9
ls -l /dev/kvm                  # must exist
dmesg | grep -i kvm             # expect "VHE mode initialized successfully"
```

## Add the repository

```bash
curl -fsSL https://mirrors.lierfang.com/pxcloud/lierfang.gpg -o /usr/share/keyrings/lierfang.gpg

cat > /etc/apt/sources.list.d/pxvirt.sources <<'EOF'
Types: deb
URIs: https://mirrors.lierfang.com/pxcloud/pxvirt
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/lierfang.gpg
EOF
```

## Map the hostname to the real IP

Proxmox requires the hostname to resolve to the LAN address, not to `127.0.1.1` or `::1`.
Edit `/etc/hosts` as follows:

```
127.0.0.1       localhost
192.168.x.y     pvrk3588.lan pvrk3588
::1             localhost ip6-localhost ip6-loopback
```

(Remove the hostname from the `::1` line.) Check that both of these print the expected values:

```bash
hostname -f     # pvrk3588.lan
hostname -i     # 192.168.x.y only
```

If you're doing this before renaming, use the current hostname here. See [step 4](04-rename-node.md).

## Install

```bash
echo "postfix postfix/main_mailer_type select Local only" | debconf-set-selections
echo "postfix postfix/mailname string $(hostname -f)"     | debconf-set-selections

apt update
DEBIAN_FRONTEND=noninteractive apt install -y proxmox-ve pve-manager qemu-server pve-cluster
```

- About 430 packages. Nothing is removed, and **no kernel is installed**, so the Armbian kernel stays in use.
- These warnings during install are harmless: postfix `default_transport: error`, the pveam template update failing, and `ifupdown2.postinst: Warning: Reloading failed`.

Check:

```bash
pveversion
systemctl is-active pve-cluster pvedaemon pveproxy pvestatd
```

**Do not reboot yet.** The network is still on netplan, and ifupdown2 has left
an `interfaces.new` behind. Go to [step 3](03-network-bridge.md).
