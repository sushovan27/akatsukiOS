#!/bin/bash
set -e

# Akatsuki Linux First Boot Script
# Runs once on first login via .desktop autostart

LOG_FILE="/var/log/akatsuki-firstboot.log"
LOCK_FILE="/var/lib/akatsuki/firstboot-done"

# Check if already run
if [ -f "$LOCK_FILE" ]; then
    exit 0
fi

exec 2>&1 >> "$LOG_FILE"

echo "=== Akatsuki Linux First Boot ==="
echo "Date: $(date)"
echo "User: $USER"
echo "Home: $HOME"

# Ensure directories exist
mkdir -p /var/lib/akatsuki

# Check for running in live environment
if grep -q "overlay" /etc/mtab 2>/dev/null; then
    echo "Live environment detected - skipping first-boot setup"
    touch "$LOCK_FILE"
    exit 0
fi

# Run GPU detection
if [ -x /usr/local/bin/akatsuki-gpu-detect.sh ]; then
    echo "Running GPU detection..."
    /usr/local/bin/akatsuki-gpu-detect.sh || true
fi

# Enable necessary services
systemctl enable fstrim.timer 2>/dev/null || true
systemctl enable zramsetup.service 2>/dev/null || true
systemctl enable earlyoom 2>/dev/null || true
systemctl enable apparmor 2>/dev/null || true

# Start UFW
ufw --force enable 2>/dev/null || true

# Configure unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades 2>/dev/null || true

# Set up zsh as default shell for new users
if command -v zsh &>/dev/null; then
    if [ "$SHELL" != "/usr/bin/zsh" ] && [ "$SHELL" != "/bin/zsh" ]; then
        chsh -s /usr/bin/zsh "$USER" 2>/dev/null || true
    fi
fi

# Configure Oh-My-Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ] && command -v zsh &>/dev/null; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
    if command -v git &>/dev/null; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" 2>/dev/null || true
        git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null || true
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true
    fi
fi

# Remove self from autostart after first run
rm -f /etc/xdg/autostart/akatsuki-welcome.desktop 2>/dev/null || true

# Mark as complete
touch "$LOCK_FILE"
echo "Akatsuki first boot setup complete."

exit 0
