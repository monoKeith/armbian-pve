# 1. Flash Armbian to eMMC from macOS

Writes the Armbian image straight to the R6C's internal eMMC over USB, using
Rockchip maskrom mode and the open-source `rkdeveloptool`. No Windows
(RKDevTool) and no SD card needed.

## Prerequisites

- macOS with [Homebrew](https://brew.sh)
- A USB-C **data** cable (not charge-only)

## Steps

Run from the repo root on the Mac:

```bash
./1_install_tools.sh   # brew install libusb pkg-config autoconf automake xz; builds ./tools/rkdeveloptool
./2_download.sh        # downloads + checksums image and loader, decompresses to downloads/armbian.img
```

Image flavour is set in `config.sh` (`ARMBIAN_FLAVOUR`, default
`Trixie_current_minimal`). `https://dl.armbian.com/nanopi-r6c/<flavour>`
redirects to the latest build. Armbian now publishes one shared image for
FriendlyElec RK3588 boards (`Armbian_*_Friendlyelec-rk3588_*.img.xz`), which is
the correct image for the R6C.

The loader (`rk3588_spl_loader_v1.15.113.bin`, from Radxa) only runs in RAM
during flashing. Its sha256 is pinned in `config.sh`.

### Enter maskrom mode

1. Remove the microSD card and unplug power.
2. Hold the **MASK** button.
3. Connect the R6C's USB-C port to the Mac. That port carries both power and data.
4. Keep holding for about 3 seconds, then release.

### Flash

```bash
./3_flash_emmc.sh
```

The script runs `rkdeveloptool ld` (finds the board), then `db <loader>`, then
`wl 0 armbian.img`, then `rd` (reboot). It asks you to type `YES` before writing.

## First boot

Connect Ethernet to the **LAN** port and power the board. Find its IP on the
router, then:

```bash
ssh root@<ip>    # default password 1234; Armbian makes you set a new one on first login
```
