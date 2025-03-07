#!/bin/bash
# make_kernel_modules.sh
# Description: Builds and optionally installs kernel modules in the default source directory.

# Color functions for output
red=$(tput setaf 1)
reset=$(tput sgr0)

echo_error() {
    echo "${red}Error: $1${reset}" >&2
}

echo_info() {
    echo "$1"
}

# Default source directory
SOURCE_TARGET="/usr/src"
KERNEL_SRC="${SOURCE_TARGET}/kernel/kernel-jammy-src"

# Check if kernel source exists
if [ ! -d "$KERNEL_SRC" ]; then
    echo_error "Kernel source not found at $KERNEL_SRC"
    exit 1
fi

# Check for .config
if [ ! -f "$KERNEL_SRC/.config" ]; then
    echo_error "No .config found in $KERNEL_SRC"
    exit 1
fi

# Change to kernel source directory
cd "$KERNEL_SRC" || {
    echo_error "Failed to change to $KERNEL_SRC"
    exit 1
}

# Build modules with sudo
echo_info "Building modules in $KERNEL_SRC"
time sudo make modules || {
    echo_error "Build failed"
    exit 1
}
echo_info "Modules built successfully"

# Prompt for installation
read -p "Do you want to install the modules? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    sudo -v  # Refresh sudo timestamp
    echo_info "Installing modules..."
    sudo make modules_install || {
        echo_error "Installation failed"
        exit 1
    }
    echo_info "Modules installed successfully"
else
    echo_info "Modules built but not installed"
fi

exit 0
