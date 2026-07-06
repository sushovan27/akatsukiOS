#!/bin/bash
# Akatsuki Linux - ISO Build Script
# Builds the Live ISO using Debian live-build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIVE_CONFIG_DIR="$PROJECT_DIR/live-config"
BUILD_DIR="$PROJECT_DIR/build"
ISO_DIR="$BUILD_DIR/iso"
REPREPRO_DIR="${REPREPRO_DIR:-$BUILD_DIR/apt-repo}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"

export SOURCE_DATE_EPOCH
export DEBIAN_FRONTEND=noninteractive

echo "============================================"
echo "  Akatsuki Linux - ISO Build"
echo "============================================"
echo "Source Date Epoch: $SOURCE_DATE_EPOCH"
echo ""

# Check dependencies
for cmd in lb debootstrap; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Please install live-build, debootstrap."
        exit 1
    fi
done

# Step 1: Build packages
echo "[1/4] Building Akatsuki packages..."
if [ -x "$SCRIPT_DIR/build-packages.sh" ]; then
    "$SCRIPT_DIR/build-packages.sh"
else
    echo "WARNING: build-packages.sh not found. Assuming packages are pre-built."
fi

# Step 2: Copy packages to live-build chroot package pool
echo "[2/4] Setting up local package repository..."
if [ -d "$REPREPRO_DIR" ]; then
    mkdir -p "$LIVE_CONFIG_DIR/config/packages.chroot"
    find "$REPREPRO_DIR/pool" -name "*.deb" -exec cp {} "$LIVE_CONFIG_DIR/config/packages.chroot/" \; 2>/dev/null || true
    echo "Copied $(ls -1 "$LIVE_CONFIG_DIR/config/packages.chroot/"*.deb 2>/dev/null | wc -l) packages to local pool."
fi

# Step 3: Clean previous build
echo "[3/4] Cleaning previous build..."
cd "$LIVE_CONFIG_DIR"
if [ -x auto/clean ]; then
    ./auto/clean
fi

# Step 4: Run live-build
echo "[4/4] Running live-build ISO generation..."
echo "This may take a while (20-60 minutes)..."

# Default lb build with our config
if [ -x auto/build ]; then
    ./auto/build
fi

# Run the actual build
lb build 2>&1 | tee "$BUILD_DIR/build.log" || {
    echo "ERROR: live-build failed. Check $BUILD_DIR/build.log for details."
    exit 1
}

# Create ISO output directory
mkdir -p "$ISO_DIR"

# Find and copy the generated ISO
GENERATED_ISO=$(ls -1 *.iso 2>/dev/null | head -1 || true)
if [ -n "$GENERATED_ISO" ]; then
    cp "$GENERATED_ISO" "$ISO_DIR/"
    echo ""
    echo "============================================"
    echo "  ISO Build Complete!"
    echo "============================================"
    echo "ISO: $ISO_DIR/$GENERATED_ISO"
    echo "Size: $(du -h "$ISO_DIR/$GENERATED_ISO" | cut -f1)"
    echo "SHA256: $(sha256sum "$ISO_DIR/$GENERATED_ISO" | cut -d' ' -f1)"
else
    echo "WARNING: No ISO file found. Check build output above."
fi

# Clean up packages.chroot
rm -rf "$LIVE_CONFIG_DIR/config/packages.chroot" 2>/dev/null || true

echo ""
echo "Done. Output in $ISO_DIR"
