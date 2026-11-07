#!/usr/bin/env bash
# Step 3: write the Armbian image to the R6C's eMMC over USB (maskrom mode).
#
# How to enter maskrom mode on the NanoPi R6C:
#   1. Remove the microSD card and unplug power.
#   2. Press and HOLD the small button labelled "MASK" on the board
#      (not the "USER" button; check FriendlyELEC's R6C wiki if unsure).
#   3. Connect the R6C's USB-C port to your Mac (this port carries power + data).
#      Use a cable that supports data, not a charge-only cable.
#   4. Keep holding MASK ~3 seconds, then release.
#   Then run this script.
set -euo pipefail
source "$(dirname "$0")/config.sh"

IMG="$DOWNLOAD_DIR/armbian.img"
[[ -x "$RKDEV" ]]       || die "rkdeveloptool missing. Run ./1_install_tools.sh"
[[ -f "$LOADER_FILE" ]] || die "Loader missing. Run ./2_download.sh"
[[ -e "$IMG" ]]         || die "Image missing. Run ./2_download.sh"

log "Looking for a Rockchip device..."
DEVS="$("$RKDEV" ld 2>&1 || true)"
echo "$DEVS"
if ! grep -qi "Maskrom\|Loader" <<<"$DEVS"; then
  die "No device in Maskrom/Loader mode. Re-check cable and the MASK-button steps at the top of this script."
fi

if grep -qi "Maskrom" <<<"$DEVS"; then
  log "Device is in Maskrom mode. Loading USB loader into RAM..."
  "$RKDEV" db "$LOADER_FILE"
  sleep 2
fi

log "eMMC info:"
"$RKDEV" rfi || warn "Could not read flash info (continuing)."

echo
warn "This will OVERWRITE the entire eMMC on the connected R6C with:"
warn "  $(readlink "$IMG" || basename "$IMG")"
read -r -p "Type YES to continue: " ans
[[ "$ans" == "YES" ]] || die "Aborted."

log "Writing image to eMMC (takes a few minutes)..."
"$RKDEV" wl 0 "$IMG"

log "Rebooting the board..."
"$RKDEV" rd

log "Done. Plug the R6C into Ethernet and power. It boots Armbian from eMMC."
log "First login: ssh root@<ip>, password 1234 (Armbian asks you to change it)."
