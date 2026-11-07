# 2. Install Proxmox VE (official arm64 packages, Armbian kernel)

Proxmox now publishes **arm64** packages in its normal `pve-no-subscription`
repository. They are installed **without the Proxmox kernel**: the Armbian
kernel (which already has KVM) stays in use. This follows Armbian's own
module: [docs](https://docs.armbian.com/software/proxmox-ve/),
[`module_proxmox.sh`](https://github.com/armbian/configng/blob/main/tools/modules/software/module_proxmox.sh).

All commands run **as root on the board**.

## Check the board first

```bash
cat /etc/os-release | head -3   # must be trixie (Debian 13)
ls -l /dev/kvm                  # must exist
dmesg | grep -i kvm             # expect "VHE mode initialized successfully"
```

## Map the hostname to the real IP

Proxmox requires the hostname to resolve to the LAN address, not to `127.0.1.1` or `::1`.
Edit `/etc/hosts` as follows:

```
127.0.0.1       localhost
192.168.x.y     pvr6c.lan pvr6c
::1             localhost ip6-localhost ip6-loopback
```

(Remove the hostname from the `::1` line.) Check that both of these print the expected values:

```bash
hostname -f     # pvr6c.lan
hostname -i     # 192.168.x.y only
```

If you're doing this before renaming, use the current hostname here. See [step 4](04-rename-node.md).

## Add the repository and keep the Proxmox kernel out

```bash
curl -fsSL https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg \
  -o /usr/share/keyrings/proxmox-archive-keyring.gpg

cat > /etc/apt/sources.list.d/proxmox.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

# proxmox-ve would pull in proxmox-default-kernel. Block it and all Proxmox kernels.
cat > /etc/apt/preferences.d/armbian-proxmox-no-kernel.pref <<'EOF'
Package: proxmox-ve proxmox-default-kernel proxmox-kernel-* proxmox-headers-*
Pin: release *
Pin-Priority: -1
EOF
```

## Install

```bash
echo "postfix postfix/main_mailer_type select Local only" | debconf-set-selections
echo "postfix postfix/mailname string $(hostname -f)"     | debconf-set-selections

apt update && apt full-upgrade -y
DEBIAN_FRONTEND=noninteractive apt install -y pve-manager postfix open-iscsi chrony
```

Install `pve-manager`, **not** `proxmox-ve`. It brings the whole Proxmox userspace (qemu-server,
pve-cluster, pve-container, ifupdown2, …) but doesn't depend on a kernel.
Confirm that no `proxmox-kernel-*` or `linux-image-*` package is pulled in.

## Disable the enterprise repo

`pve-manager` installs `pve-enterprise.sources`. Without a subscription it returns 401, which breaks `apt update`:

```bash
F=/etc/apt/sources.list.d/pve-enterprise.sources
grep -q '^Enabled:' $F && sed -i 's/^Enabled:.*/Enabled: false/' $F || echo 'Enabled: false' >> $F
apt update
```

## Check

```bash
pveversion                      # pve-manager/9.2.x, running kernel: 6.18.x-current-rockchip64
systemctl is-active pve-cluster pvedaemon pveproxy pvestatd pvescheduler
```

**Don't reboot yet.** The network is still on netplan, and ifupdown2 may have left an
`interfaces.new` behind. Go to [step 3](03-network-bridge.md).

## No ZFS (for now)

Armbian's module adds ZFS with `zfs-dkms`, which needs `linux-headers-*` that
**exactly match** the running kernel. The flashed image ran 6.18.55 (Armbian
26.8.10), but apt.armbian.com only had headers up to 6.18.44 (26.8.3), so DKMS
couldn't build. Check with
`apt-cache madison linux-headers-current-rockchip64` against `uname -r`. Until
they match, use ext4 or LVM-thin storage.

---

## Appendix: migrating from PXVIRT

The first install used [PXVIRT](https://github.com/jiangcuo/pxvirt) (a
third-party arm64 fork, Lierfang branding, older versions). Switching an existing
PXVIRT 9 node to the official packages worked in place with no guests:

1. Remove `/etc/apt/sources.list.d/pxvirt.sources` **and** `pxvirt-sources.list`.
   PXVIRT's `pve-manager` ships the second one, and it points at a *bookworm* repo.
2. Add the official repo and the no-kernel pin as above, then `apt update && apt full-upgrade`.
   That's about 107 upgrades and no removals.
3. Disable `pve-enterprise.sources`.
4. Remove PXVIRT's kernel bits. Purge, don't just remove, so its hooks in
   `/etc/kernel/*.d` and `/etc/initramfs/post-update.d` go away. If they stay,
   later Armbian kernel updates fail with `proxmox-boot-tool: not found`:
   ```bash
   touch /please-remove-proxmox-ve
   apt purge -y proxmox-ve proxmox-kernel-helper
   rm /please-remove-proxmox-ve
   dpkg --configure -a
   ```
5. Delete the obsolete `/etc/apt/trusted.gpg.d/lierfang.gpg`.
6. Check `interfaces.new` is absent, then reboot.
