#!/bin/bash
set -e

# Akatsuki Linux zRAM Setup
# Allocates ~40% of RAM as compressed swap

TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
ZRAM_SIZE=$((TOTAL_RAM * 40 / 100))

modprobe zram
zramctl -f -s "${ZRAM_SIZE}K" -a zstd
ZRAM_DEV=$(zramctl | tail -1 | awk '{print $1}')

if [ -n "$ZRAM_DEV" ]; then
    mkswap "$ZRAM_DEV"
    swapon -p 100 "$ZRAM_DEV"
    echo "zRAM enabled: $ZRAM_DEV ($((ZRAM_SIZE / 1024)) MB)"
else
    echo "Failed to configure zRAM"
    exit 1
fi
