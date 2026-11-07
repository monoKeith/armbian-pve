# Shared settings for the NanoPi R6C eMMC flashing scripts.
# Sourced by the other scripts; not meant to be run directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"
DOWNLOAD_DIR="$SCRIPT_DIR/downloads"
RKDEV="$TOOLS_DIR/rkdeveloptool"

# Armbian image. dl.armbian.com redirects to the newest build of this flavour.
# Other flavours that exist for the R6C:
#   Trixie_current_minimal  - Debian 13, mainline kernel (recommended)
#   Trixie_vendor_minimal   - Debian 13, Rockchip vendor 6.1 kernel
# Browse https://www.armbian.com/nanopi-r6c/ for the full list.
ARMBIAN_FLAVOUR="${ARMBIAN_FLAVOUR:-Trixie_current_minimal}"
ARMBIAN_URL="https://dl.armbian.com/nanopi-r6c/${ARMBIAN_FLAVOUR}"

# RK3588/RK3588S USB loader (DDR init + USB flashing stub), used only in RAM
# during maskrom flashing. Pinned by SHA-256.
LOADER_URL="https://dl.radxa.com/rock5/sw/images/loader/rk3588_spl_loader_v1.15.113.bin"
LOADER_FILE="$DOWNLOAD_DIR/rk3588_spl_loader_v1.15.113.bin"
LOADER_SHA256="26baab70e6b915364f7d73d88298366db1bfc346e34683e95d3d11b52492047f"

RKDEV_REPO="https://github.com/rockchip-linux/rkdeveloptool.git"
# Latest upstream commit as of 2025-03-07, pinned for reproducibility.
RKDEV_COMMIT="304f073752fd25c854e1bcf05d8e7f925b1f4e14"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
