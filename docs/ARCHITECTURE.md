# Akatsuki Linux Architecture

## Overview

Akatsuki Linux is a Debian 13 (Trixie)-based distribution optimized for developers,
cybersecurity professionals, and AI/ML enthusiasts. It features a custom anime/cyberpunk
theme across all system components.

## Repository Structure

```
akatsuki-linux/
├── .gitlab-ci.yml            # CI/CD pipeline definition
├── packages/                  # Debian package source trees
│   ├── akatsuki-base/         # Core metapackage (dependencies only)
│   ├── akatsuki-theme/        # Branding, themes, wallpapers, sounds
│   ├── akatsuki-terminal/     # Terminal emulator, shell, CLI tools
│   ├── akatsuki-ai/           # AI/ML framework metapackage
│   ├── akatsuki-security/     # Security/pentesting tool metapackage
│   └── akatsuki-drivers/      # Hardware driver metapackage
├── live-config/               # Debian live-build configuration
│   ├── auto/                  # lb config/clean automation scripts
│   └── config/
│       ├── hooks/             # Chroot hooks executed during build
│       ├── includes/          # Binary and chroot file overlays
│       └── package-lists/     # Package selection lists
├── ci/                        # CI build scripts
└── docs/                      # Documentation
```

## Build Pipeline

1. **Package Build** (`ci/build-packages.sh`):
   - Builds each package in `packages/` using `dpkg-buildpackage`
   - Runs `lintian` for quality checks
   - Populates an APT repository via `reprepro`

2. **ISO Build** (`ci/build-iso.sh`):
   - Uses Debian `live-build` (`lb config && lb build`)
   - Copies built `.deb` packages into the chroot package pool
   - Applies hooks for GRUB, dconf, and system configuration
   - Generates a hybrid ISO (UEFI + BIOS)

## Package Design

### Metapackage Pattern
All `akatsuki-*` packages are metapackages (Architecture: all) that:
- Depend on the actual software from Debian repositories
- Pull in Akatsuki-specific configuration files
- Have no build-time compilation (override_dh_auto_build empty)

### Dependency Chain
```
akatsuki-base
├── akatsuki-theme (branding, themes, wallpapers)
├── akatsuki-terminal (kitty, zsh, CLI tools)
├── akatsuki-drivers (Mesa, firmware, NVIDIA suggestions)
├── gnome-core (GNOME desktop environment)
├── Development tools (gcc, python, java, etc.)
├── System utilities (tlp, ufw, fail2ban, etc.)
└── Calamares installer

Optional (installed post-deployment via welcome app):
├── akatsuki-ai (PyTorch, CUDA, Jupyter, etc.)
├── akatsuki-security (nmap, wireshark, metasploit, etc.)
└── nvidia-driver (proprietary NVIDIA driver)
```

## System Configuration

### Performance Tuning
- **CPU Governor**: powersave on battery, performance on AC (via TLP)
- **zRAM**: 40% of RAM allocated as compressed swap (zstd)
- **Swappiness**: 10 (via sysctl)
- **BBR**: TCP congestion control enabled
- **SSD**: Weekly fstrim, noatime mount option
- **Early OOM**: earlyoom daemon active
- **journald**: 200MB max log size

### Security Hardening
- **UFW**: Enabled, deny incoming, allow outgoing
- **AppArmor**: Enforcing mode with profiles
- **Fail2Ban**: SSH protection
- **Unattended-upgrades**: Automatic security updates
- **Kernel params**: dmesg_restrict=1, ptrace_scope=1, kptr_restrict=2

### Power Management (TLP)
See `/etc/tlp.d/01-akatsuki-power.conf` for full configuration.

## Theming Stack

| Component     | Theme/Style                          |
|---------------|--------------------------------------|
| Boot Splash   | Plymouth - Akatsuki neon theme       |
| GRUB          | Custom dark theme with Neon accents  |
| GDM Login     | Animated dark wallpaper + blur       |
| GTK Theme     | Akatsuki-Dark (Sweet/Colloid based)  |
| Icons         | Colloid-Dark, Papirus                |
| Cursors       | Bibata-Modern-Ice                    |
| Fonts         | JetBrains Mono (UI + Monospace)      |
| Terminal      | Kitty - semi-transparent cyberpunk   |
| Shell         | Zsh + Powerlevel10k                  |
| Desktop       | GNOME + Dash-to-Dock + Blur My Shell |

## GPU Detection Flow

1. `akatsuki-gpu-detect.sh` runs lspci/glxinfo to identify GPUs
2. For NVIDIA: offers to install `nvidia-driver` via zenity dialog
3. For Intel/AMD: confirms Mesa drivers are active
4. All results logged to `/var/log/akatsuki-gpu-info.txt`

## First Boot Sequence

1. GNOME Initial Setup wizard (account creation)
2. `akatsuki-welcome.desktop` launches `akatsuki-firstboot.sh`
3. First-boot script:
   - Runs GPU detection
   - Enables services (fstrim, zram, earlyoom, apparmor)
   - Starts UFW firewall
   - Configures unattended-upgrades
   - Sets up Oh-My-Zsh for user
4. Removes itself from autostart after completion

## CI/CD Workflow

The GitLab CI pipeline has 5 stages:
1. **build-packages**: Compile all .deb packages
2. **lint-packages**: Run lintian quality checks
3. **build-iso**: Generate the Live ISO
4. **test-iso**: Quick boot test in QEMU
5. **release**: Tag-based release artifacts
