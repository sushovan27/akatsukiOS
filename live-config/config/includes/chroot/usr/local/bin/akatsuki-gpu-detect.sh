#!/bin/bash
set -e

# Akatsuki Linux GPU Detection Script
# Detects GPU hardware and recommends/probes drivers

LOG_FILE="/var/log/akatsuki-gpu-detect.log"
OUTPUT_FILE="/var/log/akatsuki-gpu-info.txt"

exec 2>&1 >> "$LOG_FILE"

echo "=== Akatsuki GPU Detection ==="
echo "Date: $(date)"

# Collect hardware info
echo "=== PCI GPU Devices ===" > "$OUTPUT_FILE"
lspci -nn | grep -E "VGA|3D|Display" >> "$OUTPUT_FILE" 2>/dev/null || echo "No GPU found via lspci" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "=== OpenGL Renderer ===" >> "$OUTPUT_FILE"
glxinfo 2>/dev/null | grep "OpenGL renderer string" >> "$OUTPUT_FILE" || echo "glxinfo not available" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "=== Vulkan Devices ===" >> "$OUTPUT_FILE"
if command -v vulkaninfo &>/dev/null; then
    vulkaninfo 2>/dev/null | grep "deviceName" | head -5 >> "$OUTPUT_FILE"
else
    echo "vulkaninfo not available" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "=== NVIDIA SMI ===" >> "$OUTPUT_FILE"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=driver_version,name,temperature.gpu --format=csv,noheader 2>/dev/null >> "$OUTPUT_FILE" || echo "nvidia-smi failed" >> "$OUTPUT_FILE"
else
    echo "nvidia-smi not available" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "=== Kernel Modules ===" >> "$OUTPUT_FILE"
lsmod | grep -E "nvidia|nouveau|amdgpu|i915|radeon" >> "$OUTPUT_FILE" 2>/dev/null || echo "No GPU modules loaded" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "=== CPU Info ===" >> "$OUTPUT_FILE"
lscpu | grep "Model name" >> "$OUTPUT_FILE" 2>/dev/null || true
echo "RAM: $(free -h | grep Mem | awk '{print $2}')" >> "$OUTPUT_FILE"

# Detect GPU vendor and suggest driver
echo "" >> "$OUTPUT_FILE"
echo "=== Driver Recommendation ===" >> "$OUTPUT_FILE"

if lspci -nn | grep -qi "nvidia"; then
    echo "NVIDIA GPU detected." >> "$OUTPUT_FILE"
    echo "RECOMMENDATION: Install nvidia-driver (proprietary)" >> "$OUTPUT_FILE"
    echo "  sudo apt install nvidia-driver nvidia-settings nvidia-prime" >> "$OUTPUT_FILE"
    echo "  For CUDA: sudo apt install nvidia-cuda-toolkit" >> "$OUTPUT_FILE"
    echo "  After install reboot for the driver to load." >> "$OUTPUT_FILE"
elif lspci -nn | grep -qi "amd"; then
    echo "AMD GPU detected." >> "$OUTPUT_FILE"
    echo "RECOMMENDATION: Use open-source Mesa drivers (already installed)" >> "$OUTPUT_FILE"
    echo "  Ensure firmware-amd-graphics is installed." >> "$OUTPUT_FILE"
elif lspci -nn | grep -qi "intel"; then
    echo "Intel GPU detected." >> "$OUTPUT_FILE"
    echo "RECOMMENDATION: Use open-source Mesa drivers (already installed)" >> "$OUTPUT_FILE"
    echo "  Ensure intel-media-va-driver is installed for hardware acceleration." >> "$OUTPUT_FILE"
else
    echo "Unknown or virtual GPU." >> "$OUTPUT_FILE"
    echo "RECOMMENDATION: Default open-source drivers should work." >> "$OUTPUT_FILE"
fi

# Check if NVIDIA is present and show dialog
if lspci -nn | grep -qi "nvidia" && [ -z "$DISPLAY" ] && command -v zenity &>/dev/null; then
    if zenity --question \
        --title="Akatsuki Linux - NVIDIA GPU Detected" \
        --text="An NVIDIA GPU was detected in your system.\n\nWould you like to install the proprietary NVIDIA driver for better performance?" \
        --ok-label="Install NVIDIA Driver" \
        --cancel-label="Skip" \
        --width=400 2>/dev/null; then
        pkexec apt install -y nvidia-driver nvidia-settings nvidia-prime nvidia-cuda-toolkit 2>/dev/null || true
        if command -v nvidia-smi &>/dev/null; then
            zenity --info --title="NVIDIA Driver Installed" \
                --text="NVIDIA driver has been installed successfully.\nPlease reboot for changes to take effect." \
                --width=300 2>/dev/null || true
        fi
    fi
fi

echo "GPU detection complete. Report saved to $OUTPUT_FILE"
cat "$OUTPUT_FILE"

exit 0
