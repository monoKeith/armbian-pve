#!/usr/bin/env bash
# Step 2: download the Armbian image and the RK3588 USB loader, verify both,
# and decompress the image so it can be written raw to eMMC.
set -euo pipefail
source "$(dirname "$0")/config.sh"

command -v xz >/dev/null || die "xz not found. Run ./1_install_tools.sh first."
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

# --- Loader -----------------------------------------------------------------
if [[ ! -f "$LOADER_FILE" ]]; then
  log "Downloading RK3588 loader..."
  curl -fL --progress-bar -o "$LOADER_FILE" "$LOADER_URL"
fi
echo "$LOADER_SHA256  $LOADER_FILE" | shasum -a 256 -c - \
  || die "Loader checksum mismatch. Delete $LOADER_FILE and retry."

# --- Armbian image ----------------------------------------------------------
log "Resolving latest Armbian image for flavour: $ARMBIAN_FLAVOUR"
REAL_URL="$(curl -fsIL -o /dev/null -w '%{url_effective}' "$ARMBIAN_URL")" \
  || die "Could not resolve $ARMBIAN_URL (flavour may not exist)."
IMG_XZ="$(basename "$REAL_URL")"
[[ "$IMG_XZ" == *.img.xz ]] || die "Unexpected file from mirror: $IMG_XZ"
IMG="${IMG_XZ%.xz}"
log "Image: $IMG_XZ"

if [[ ! -f "$IMG_XZ" ]]; then
  curl -fL --progress-bar -C - -o "$IMG_XZ.part" "$REAL_URL"
  mv "$IMG_XZ.part" "$IMG_XZ"
fi

log "Verifying SHA-256..."
curl -fsL -o "$IMG_XZ.sha" "$REAL_URL.sha"
# Armbian's .sha uses a single space ("<hash> <file>"), which `shasum -c`
# rejects, so compare the hash field directly.
EXPECTED="$(awk '{print tolower($1); exit}' "$IMG_XZ.sha")"
[[ "$EXPECTED" =~ ^[0-9a-f]{64}$ ]] || die "Could not parse checksum from $IMG_XZ.sha"
ACTUAL="$(shasum -a 256 "$IMG_XZ" | awk '{print $1}')"
[[ "$ACTUAL" == "$EXPECTED" ]] || die "Image checksum mismatch. Delete $IMG_XZ and retry."
log "Checksum OK: $ACTUAL"

if [[ ! -f "$IMG" ]]; then
  log "Decompressing (keeps the .xz)..."
  xz -dkv "$IMG_XZ"
fi

ln -sf "$IMG" armbian.img
log "Ready: $DOWNLOAD_DIR/armbian.img -> $IMG"
log "Next: put the R6C in maskrom mode and run ./3_flash_emmc.sh"
