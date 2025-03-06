#!/bin/bash
set -e  # Exit on error

# Define log directory and file
LOG_DIR="$(dirname "$0")/logs"
LOG_FILE="$LOG_DIR/get_kernel_sources.log"

# Define kernel source directory (native Jetson builds use /usr/src/)
KERNEL_SRC_DIR="/usr/src/kernel"

# Ensure the logs directory exists
mkdir -p "$LOG_DIR"

# Default behavior (interactive mode)
FORCE_REPLACE=0
FORCE_BACKUP=0

# Check if user has sudo privileges
if [[ $EUID -ne 0 ]]; then
  if ! sudo -v; then
    echo "[ERROR] This script requires sudo privileges. Please run with sudo access."
    exit 1
  fi
fi

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --force-replace) FORCE_REPLACE=1 ;;
    --force-backup) FORCE_BACKUP=1 ;;
    *) echo "[ERROR] Invalid option: $1" && exit 1 ;;
  esac
  shift
done

# Logging function
log() {
  echo "[INFO] $(date +"%Y-%m-%d %H:%M:%S") - ${1}" | tee -a "$LOG_FILE"
}

# Extract L4T major version and revision number using sed
L4T_MAJOR=$(sed -n 's/^.*R\([0-9]\+\).*/\1/p' /etc/nv_tegra_release)
L4T_MINOR=$(sed -n 's/^.*REVISION: \([0-9]\+\(\.[0-9]\+\)*\).*/\1/p' /etc/nv_tegra_release)

log "Detected L4T version: ${L4T_MAJOR} (${L4T_MINOR})"
log "Kernel sources directory: $KERNEL_SRC_DIR"

# Construct the kernel source URL
SOURCE_URL="https://developer.nvidia.com/embedded/l4t/r${L4T_MAJOR}_release_v${L4T_MINOR}/sources/public_sources.tbz2"

# Check if kernel sources already exist
if [[ -d "$KERNEL_SRC_DIR" ]]; then
  if [[ "$FORCE_REPLACE" -eq 1 ]]; then
    log "Forcing deletion of existing kernel sources..."
    sudo rm -rf "$KERNEL_SRC_DIR"

  elif [[ "$FORCE_BACKUP" -eq 1 ]]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="${KERNEL_SRC_DIR}_backup_${TIMESTAMP}"
    log "Forcing backup of existing kernel sources to $BACKUP_DIR..."
    sudo mv "$KERNEL_SRC_DIR" "$BACKUP_DIR"

  else
    echo "Kernel sources already exist at $KERNEL_SRC_DIR."
    echo "What would you like to do?"
    echo "[K]eep existing sources (default)"
    echo "[R]eplace (delete and re-download)"
    echo "[B]ackup and download fresh sources"

    read -rp "Enter your choice (K/R/B): " USER_CHOICE

    case "$USER_CHOICE" in
      [Rr]* ) 
        log "Deleting existing kernel sources..."
        sudo rm -rf "$KERNEL_SRC_DIR"
        ;;
      [Bb]* ) 
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        BACKUP_DIR="${KERNEL_SRC_DIR}_backup_${TIMESTAMP}"
        log "Backing up existing kernel sources to $BACKUP_DIR..."
        sudo mv "$KERNEL_SRC_DIR" "$BACKUP_DIR"
        ;;
      * ) 
        log "Keeping existing kernel sources. Skipping download."
        exit 0
        ;;
    esac
  fi
fi

log "Downloading kernel sources from: $SOURCE_URL"

# Download the kernel source tarball (No sudo needed for downloading)
if ! wget -N "$SOURCE_URL" -O public_sources.tbz2; then
  log "[ERROR] Download failed! Check NVIDIA repository or internet connection."
  exit 1
fi

log "Download successful. Extracting sources..."

# Extract public_sources.tbz2 to find kernel_src.tbz2
sudo tar -xvf public_sources.tbz2 Linux_for_Tegra/source/public/kernel_src.tbz2 --strip-components=3

# Extract the inner kernel source archive
sudo tar -xvf kernel_src.tbz2 -C "$KERNEL_SRC_DIR"
rm kernel_src.tbz2 public_sources.tbz2

log "Kernel sources extracted to $KERNEL_SRC_DIR"

# Copy the current kernel config (requires sudo)
log "Copying current kernel config..."
sudo zcat /proc/config.gz > "$KERNEL_SRC_DIR/.config"

log "Kernel source setup complete!"
