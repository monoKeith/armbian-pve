#!/usr/bin/env bash
# Step 1: install build dependencies with Homebrew and build rkdeveloptool
# (the open-source macOS/Linux replacement for Rockchip's Windows RKDevTool).
set -euo pipefail
source "$(dirname "$0")/config.sh"

[[ "$(uname)" == "Darwin" ]] || die "This script is for macOS."
command -v brew >/dev/null || die "Homebrew not found. Install it from https://brew.sh first."

log "Installing build dependencies (libusb, pkg-config, autoconf, automake, xz)..."
brew install libusb pkg-config autoconf automake xz

if [[ -x "$RKDEV" ]]; then
  log "rkdeveloptool already built at $RKDEV"
  "$RKDEV" -v || true
  exit 0
fi

BUILD_DIR="$TOOLS_DIR/rkdeveloptool-src"
mkdir -p "$TOOLS_DIR"
if [[ ! -d "$BUILD_DIR/.git" ]]; then
  log "Cloning rkdeveloptool..."
  git clone "$RKDEV_REPO" "$BUILD_DIR"
fi
cd "$BUILD_DIR"
git fetch --quiet origin
git checkout --quiet "$RKDEV_COMMIT"

log "Building rkdeveloptool..."
autoreconf -i
./configure
# Newer Apple clang turns some upstream warnings into errors; keep them as warnings.
make CXXFLAGS="-O2 -Wno-error -Wno-deprecated-declarations"

cp rkdeveloptool "$RKDEV"
log "Built: $RKDEV"
"$RKDEV" -v || true
log "Next: ./2_download.sh"
