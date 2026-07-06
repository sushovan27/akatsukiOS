# Building Akatsuki Linux

This document explains how to build Akatsuki Linux from source.

## Prerequisites

### Debian/Ubuntu System
```bash
sudo apt update
sudo apt install -y \
    build-essential debhelper lintian \
    live-build debootstrap \
    reprepro dpkg-dev devscripts \
    git curl wget \
    qemu-system-x86 ovmf \
    genisoimage xorriso \
    isolinux syslinux-efi
```

### Required Tools
- **live-build**: Debian tool for building Live ISO images
- **debootstrap**: Bootstrap a basic Debian system
- **dpkg-dev**: Debian package development tools
- **reprepro**: APT repository management (optional, for local repo)
- **lintian**: Debian package checker

## Quick Build

### 1. Clone the Repository
```bash
git clone https://gitlab.com/akatsuki-linux/akatsuki-linux.git
cd akatsuki-linux
```

### 2. Build All Packages
```bash
# Build all .deb packages
./ci/build-packages.sh

# Output: build/debs/*.deb, build/apt-repo/
```

### 3. Build the ISO
```bash
# Build the complete Live ISO
./ci/build-iso.sh

# Output: build/iso/akatsuki-linux-*.iso
```

## Manual Step-by-Step Build

### Build Individual Packages
```bash
# Navigate to a package directory
cd packages/akatsuki-base

# Build the package
dpkg-buildpackage -us -uc -b

# The .deb will be in the parent directory
ls ../*.deb
```

### Build with live-build (Detailed)
```bash
cd live-config

# Clean previous builds
sudo lb clean --purge

# Configure the build
sudo lb config \
    --distribution trixie \
    --binary-images iso-hybrid \
    --archive-areas "main contrib non-free non-free-firmware" \
    --architectures amd64 \
    --linux-flavours amd64 \
    --bootappend-live "boot=live components splash quiet loglevel=3" \
    --debian-installer live \
    --debian-installer-gui true \
    --iso-application "Akatsuki Linux 1.0" \
    --iso-publisher "Akatsuki Linux" \
    --firmware-binary true \
    --firmware-chroot true

# Copy custom .deb packages into the build
mkdir -p config/packages.chroot
cp ../build/debs/*.deb config/packages.chroot/

# Build the ISO
sudo lb build

# Find the generated ISO
ls -lh *.iso
```

## Testing the ISO

### Using QEMU
```bash
# UEFI boot
qemu-system-x86_64 -enable-kvm -m 4096 -cpu host \
    -cdrom build/iso/akatsuki-linux-*.iso \
    -bios /usr/share/ovmf/OVMF.fd

# BIOS/Legacy boot
qemu-system-x86_64 -enable-kvm -m 4096 -cpu host \
    -cdrom build/iso/akatsuki-linux-*.iso
```

### Using VirtualBox
1. Create a new VM (64-bit Linux, 4096 MB RAM)
2. Attach the ISO as a virtual optical disk
3. Boot and test the live environment

### Writing to USB
```bash
# Identify your USB device (be careful!)
lsblk

# Write the ISO
sudo dd if=build/iso/akatsuki-linux-*.iso of=/dev/sdX bs=4M status=progress

# Or use balenaEtcher / Rufus on Windows
```

## CI/CD Pipeline

The project includes a `.gitlab-ci.yml` for automated builds:

1. **build-packages**: Builds all .deb packages
2. **lint-packages**: Runs lintian on built packages
3. **build-iso**: Generates the Live ISO
4. **test-iso**: Quick QEMU boot test
5. **release**: Creates release artifacts (tagged only)

### Running Locally with GitLab Runner
```bash
gitlab-runner exec docker build-packages
gitlab-runner exec docker build-iso
```

## Reproducible Builds

Builds are reproducible when using the same `SOURCE_DATE_EPOCH`:

```bash
export SOURCE_DATE_EPOCH=1720291200
./ci/build-iso.sh
```

## Build Output

After a successful build, you'll have:

```
build/
├── debs/                          # Individual .deb packages
│   ├── akatsuki-base_1.0.0-1_all.deb
│   ├── akatsuki-theme_1.0.0-1_all.deb
│   ├── akatsuki-terminal_1.0.0-1_all.deb
│   ├── akatsuki-drivers_1.0.0-1_all.deb
│   ├── akatsuki-security_1.0.0-1_all.deb
│   └── akatsuki-ai_1.0.0-1_all.deb
├── apt-repo/                      # APT repository structure
│   ├── conf/distributions
│   ├── dists/trixie/...
│   └── pool/main/...
└── iso/                           # Generated ISO images
    └── akatsuki-linux-1.0-amd64.hybrid.iso
```

## Troubleshooting

### live-build fails with "No package 'grub-efi-amd64-signed'"
Install the required EFI packages:
```bash
sudo apt install grub-efi-amd64-signed shim-signed
```

### "deboostrap" fails
Ensure you have proper internet access and valid Debian mirror:
```bash
sudo lb config --mirror-bootstrap "http://deb.debian.org/debian/"
```

### Package build fails with missing dependencies
Install build dependencies:
```bash
sudo apt install -y devscripts debhelper lintian
```

## Environment Variables

| Variable          | Default | Description                       |
|-------------------|---------|-----------------------------------|
| OUTPUT_DIR        | build/debs | Directory for built .deb files  |
| REPREPRO_DIR      | build/apt-repo | APT repository directory    |
| SOURCE_DATE_EPOCH | (current time) | Timestamp for reproducibility |

## Support

- Issue Tracker: https://gitlab.com/akatsuki-linux/akatsuki-linux/-/issues
- Documentation: https://docs.akatsukilinux.org
- Community: https://discord.gg/akatsuki-linux
