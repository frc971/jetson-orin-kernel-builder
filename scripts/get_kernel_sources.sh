#!/bin/bash
set -e
KERNEL_VERSION=$(uname -r)
L4T_VERSION=$(head -n1 /etc/nv_tegra_release | awk '{print $2}')
SOURCE_URL="https://developer.nvidia.com/embedded/downloads/public_sources/l4t-${L4T_VERSION}-kernel-src.tbz2"

echo "Fetching kernel sources for L4T ${L4T_VERSION}..."
wget -O kernel_src.tbz2 "$SOURCE_URL"
tar -xjf kernel_src.tbz2 -C /usr/src/
rm kernel_src.tbz2

echo "Copying running config..."
cp /proc/config.gz /usr/src/kernel/.config
gunzip /usr/src/kernel/.config
echo "Kernel sources ready in /usr/src/kernel/"
