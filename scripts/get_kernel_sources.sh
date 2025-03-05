#!/bin/bash
set -e  # Exit on error

# Enable logging
LOG_FILE="/var/log/jetson_kernel_sources.log"
VERBOSE=0

# Parse command-line options
while getopts "v" opt; do
  case ${opt} in
    v) VERBOSE=1 ;;
    *) echo "[ERROR] Invalid option" && exit 1 ;;
  esac
done

log() {
  local msg="$1"
  echo "[INFO] $(date +"%Y-%m-%d %H:%M:%S") - ${msg}" | tee -a "$LOG_FILE"
}

verbose_log() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "[DEBUG] $(date +"%Y-%m-%d %H:%M:%S") - ${1}" | tee -a "$LOG_FILE"
  fi
}

# Extract L4T version details from /etc/nv_tegra_release
L4T_INFO=$(head -n1 /etc/nv_tegra_release)
L4T_MAJOR=$(echo "$L4T_INFO" | awk '{print $2}' | tr -d '()')  # Extract "R36"
L4T_MINOR=$(echo "$L4T_INFO" | awk '{print $4}')               # Extract "4.3"

# Construct download URL
SOURCE_URL="https://developer.nvidia.com/downloads/embedded/l4t/r${L4T_MAJOR}_release_v${L4T_MINOR}/sources/public_sources.tbz2"
KERNEL_SRC_DIR="/usr/src/kernel"

log "Detected L4T version: ${L4T_MAJOR} (${L4T_MINOR})"
log "Fetching kernel sources from: $SOURCE_URL"

# Download the kernel source tarball
if ! wget -O kernel_src.tbz2 "$SOURCE_URL"; then
  echo "[ERROR] $(date +"%Y-%m-%d %H:%M:%S") - Download failed! Check internet or NVIDIA repository." | tee -a "$LOG_FILE" >&2
  exit 1
fi

# Extract kernel sources
mkdir -p "$KERNEL_SRC_DIR"
tar -xjf kernel_src.tbz2 -C "$KERNEL_SRC_DIR" --strip-components=3 Linux_for_Tegra/source/public/kernel_src.tbz2
rm kernel_src.tbz2

log "Kernel sources extracted to: $KERNEL_SRC_DIR"

# Copy the running kernel configuration
log "Copying current kernel config..."
if ! zcat /proc/config.gz > "$KERNEL_SRC_DIR/.config"; then
  echo "[WARNING] $(date +"%Y-%m-%d %H:%M:%S") - Unable to copy kernel config! Proceeding without it." | tee -a "$LOG_FILE"
fi

# Summary report
echo "---------------------------------------"
echo " Kernel Source Download Summary"
echo "---------------------------------------"
echo " L4T Version   : ${L4T_MAJOR} (${L4T_MINOR})"
echo " Download URL  : ${SOURCE_URL}"
echo " Extracted To  : ${KERNEL_SRC_DIR}"
echo " Kernel Config : Copied from /proc/config.gz"
echo "---------------------------------------"
log "Kernel source setup complete!"
