#!/bin/bash
# make_kernel_modules.sh
# Description: Builds and optionally installs kernel modules in the specified source directory.

# Color functions for consistent output
red=$(tput setaf 1)
reset=$(tput sgr0)

echo_error() {
    echo "${red}Error: $1${reset}" >&2
}

echo_info() {
    echo "$1"
}

# Usage function for help message
function usage {
    echo "usage: ./make_kernel_modules.sh [[-d directory ]  | [-h]]"
    echo "-d | --directory  Directory path to parent of kernel source (default: /usr/src)"
    echo "-h | --help       Show this help message"
}

# Default source directory
SOURCE_TARGET="/usr/src"

# Parse command-line arguments
while [ "$1" != "" ]; do
    case $1 in
        -d | --directory ) shift
            SOURCE_TARGET=$1
            ;;
        -h | --help )
            usage
            exit 0
            ;;
        * )
            usage
            exit 1
    esac
    shift
done

# Ensure SOURCE_TARGET ends with a slash
[[ "${SOURCE_TARGET}" != */ ]] && SOURCE_TARGET+="/"

# Set kernel source directory
KERNEL_SRC="${SOURCE_TARGET}kernel/kernel-jammy-src"

# Check for kernel source directory
if [ ! -d "$KERNEL_SRC" ]; then
    echo_error "Kernel source not found at $KERNEL_SRC"
    exit 1
fi

# Check for .config
if [ ! -f "$KERNEL_SRC/.config" ]; then
    echo_error "No .config found in $KERNEL_SRC"
    exit 1
fi

# Capture the original directory
ORIGINAL_DIR=$(pwd)

# Set up logging
LOGS_DIR="$ORIGINAL_DIR/logs"
mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/modules_build.log"

# Refresh sudo timestamp
sudo -v

# Change to kernel source directory
cd "$KERNEL_SRC" || {
    echo_error "Failed to change to $KERNEL_SRC"
    exit 1
}

# Determine number of jobs for parallel building
NUM_CPU=$(nproc)
JOBS=$((NUM_CPU > 1 ? NUM_CPU - 1 : 1))

# Build modules with logging
echo_info "Building modules in $KERNEL_SRC"
echo "Building modules..." | tee -a "$LOG_FILE"
time sudo make -j$JOBS modules 2>&1 | tee -a "$LOG_FILE"
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Parallel build failed. Retrying with single-threaded build..." | tee -a "$LOG_FILE"
    time sudo make modules 2>&1 | tee -a "$LOG_FILE"
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo_error "Build failed again. Check $LOG_FILE for details"
        exit 1
    fi
fi
echo_info "Modules built successfully"

# Prompt for installation
read -p "Do you want to install the modules? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    echo "Installing modules..." | tee -a "$LOG_FILE"
    sudo make modules_install 2>&1 | tee -a "$LOG_FILE"
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo_error "Installation failed. Check $LOG_FILE for details"
        exit 1
    fi
    echo_info "Modules installed successfully"
else
    # Get current kernel version
    kernel_version=$(uname -r)
    
    # Define README file
    readme_file="${ORIGINAL_DIR}/README_modules_install_${kernel_version}.txt"
    
    # Define README content
    readme_content="
Kernel Modules Installation Instructions
========================================

To install the kernel modules later, run:
  sudo make -C $KERNEL_SRC modules_install

This will:
- Install modules to /lib/modules/${kernel_version}/
- Update module dependencies.

Note: Install the modules before updating the kernel to ensure compatibility.
"
    
    # Display and save instructions
    echo_info "Modules built but not installed. Installation instructions:"
    echo "$readme_content"
    echo "$readme_content" > "$readme_file"
    echo_info "Instructions saved to $readme_file"
fi

# Final log file notification
echo_info "Logs are saved in: $LOG_FILE"

exit 0
