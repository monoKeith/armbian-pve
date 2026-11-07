# armbian-pve

How I installed Proxmox VE ([PXVIRT](https://github.com/jiangcuo/pxvirt), the arm64 Proxmox fork) on a **FriendlyElec NanoPi R6C** (RK3588S, 8 GB RAM, 64 GB eMMC) running **Armbian**, using only a Mac.

Written so that I or an AI coding agent can redo it from scratch.

## Result

| | |
|---|---|
| OS | Armbian 26.8.x, Debian 13 trixie, mainline kernel 6.18 (`current`) |
| Proxmox | PXVIRT 9 (`proxmox-ve 9.0.0`, `pve-manager 9.0.10`), keeps the Armbian kernel |
| Node name | `pvrk3588` (`pvrk3588.lan`) |
| Network | static `192.168.x.y/24` on bridge `vmbr0` (port `lan1`), gateway/DNS `192.168.x.1` |
| Web UI | `https://192.168.x.y:8006`, user `root`, realm "Linux PAM" |

## Steps

1. [Flash Armbian to eMMC from macOS](docs/01-flash-armbian-emmc.md) (maskrom + `rkdeveloptool`, scripts in this repo)
2. [Install PXVIRT](docs/02-install-pxvirt.md)
3. [Switch networking to an ifupdown2 bridge](docs/03-network-bridge.md)
4. [Rename the node](docs/04-rename-node.md)
5. [Rockchip: pin VMs to one type of CPU core](docs/05-rockchip-cpu-affinity.md) (not tried yet)

## Repo layout

```
config.sh             shared settings for the flashing scripts (image flavour, loader URL + sha256)
1_install_tools.sh    brew deps + build rkdeveloptool into ./tools
2_download.sh         download + verify Armbian image and RK3588 loader into ./downloads
3_flash_emmc.sh       write image to eMMC over USB in maskrom mode
scripts/pve-network-switch.sh   on the board: netplan/networkd -> ifupdown2 vmbr0, with auto-rollback
docs/                 step-by-step guide
```

`downloads/`, `tools/` and `log/` are generated and git-ignored.

## Things to know

- **Delete `/etc/network/interfaces.new` after installing PXVIRT.** The ifupdown2 package writes one, and `pvenetcommit.service` moves it over `/etc/network/interfaces` at the next boot. That wipes the bridge config and leaves the board with no network. See [step 3](docs/03-network-bridge.md).
- **Fast and slow CPU cores.** CPUs 0–3 are Cortex-A55 and CPUs 4–7 are Cortex-A76. Pin each multi-vCPU VM to one type of core. See [step 5](docs/05-rockchip-cpu-affinity.md).
- **No ZFS.** The Armbian kernel has no ZFS module. Use ext4/LVM-thin (e.g. on the NVMe) for VM storage.
- The address is static on the board. Add a matching DHCP reservation on the router.
- Keep a serial console or HDMI + keyboard nearby when changing the network.
