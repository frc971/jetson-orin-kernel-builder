#!/bin/bash
# Graphical Kernel Configuration Script for NVIDIA Jetson Developer Kit
# This script enables the use of 'make xconfig', a graphical interface for configuring 
# Linux kernel options. It checks for required Qt5 libraries and, if missing, offers 
# to install either qtbase5-dev or qtbase5-gles-dev based on user preference.
# Once dependencies are met, it navigates to the specified kernel source directory 
# (default: /usr/src/kernel/kernel-jammy-src) and launches 'make xconfig' with 
# appropriate permissions.
#
# Usage:
#   ./edit_config_gui.sh [kernel_source_directory]
#
# Options:
#   kernel_source_directory  (Optional) Path to the kernel source directory 
#                            (default: /usr/src/kernel/kernel-jammy-src)
#
# Example:
#   ./edit_config_gui.sh                   # Use default kernel source directory
#   ./edit_config_gui.sh /custom/kernel/src # Specify a custom kernel source path
#
# Notes:
# - If required Qt5 libraries (Qt5Core, Qt5Gui, Qt5Widgets) are missing, the script 
#   prompts the user to install either qtbase5-dev or qtbase5-gles-dev.
# - If the kernel source directory is not writable, the script attempts to run 
#   'make xconfig' with sudo.
#
# Copyright (c) 2016-25 JetsonHacks
# MIT License

# Function to check for Qt5 libraries
check_qt_libraries() {
    pkg-config --exists Qt5Core Qt5Gui Qt5Widgets
}

# Function to install Qt libraries based on user choice
install_qt_libraries() {
    echo "The required Qt5 development libraries (Qt5Core, Qt5Gui, Qt5Widgets) are not installed."
    echo "These libraries are necessary to run the graphical kernel configuration editor (make xconfig)."
    echo
    echo "You have two installation options:"
    echo "1. qtbase5-dev: The standard Qt5 development package, suitable for most systems with full OpenGL support."
    echo "2. qtbase5-gles-dev: The Qt5 development package optimized for systems with OpenGL ES (e.g., embedded devices)."
    echo
    echo "Please select an option:"
    echo "1) Install qtbase5-dev (default)"
    echo "2) Install qtbase5-gles-dev"
    echo "3) Skip installation and exit"
    read -p "Enter your choice (1-3): " choice

    case $choice in
        1)
            echo "Installing qtbase5-dev and pkg-config..."
            sudo apt-get update
            sudo apt-get install -y qtbase5-dev pkg-config
            ;;
        2)
            echo "Installing qtbase5-gles-dev and pkg-config..."
            sudo apt-get update
            sudo apt-get install -y qtbase5-gles-dev pkg-config
            ;;
        3)
            echo "Skipping installation. Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Defaulting to installing qtbase5-dev."
            sudo apt-get update
            sudo apt-get install -y qtbase5-dev pkg-config
            ;;
    esac

    # Verify the libraries are now available
    if ! check_qt_libraries; then
        echo "Error: Qt5 libraries still not found after installation."
        echo "Please check your package manager or install the libraries manually."
        exit 1
    fi
}

# Default kernel source directory, override with command-line argument if provided
KERNEL_SRC=${1:-/usr/src/kernel/kernel-jammy-src}

# Check if the kernel source directory exists and contains a Makefile
if [ ! -d "$KERNEL_SRC" ] || [ ! -f "$KERNEL_SRC/Makefile" ]; then
    echo "Error: $KERNEL_SRC is not a valid kernel source directory (missing or no Makefile found)."
    exit 1
fi

# Check for Qt libraries and prompt to install if missing
if ! check_qt_libraries; then
    install_qt_libraries
fi

# Switch to the kernel source directory
cd "$KERNEL_SRC" || {
    echo "Error: Failed to change to directory $KERNEL_SRC."
    exit 1
}

# Check if the current directory is writable and run make xconfig accordingly
if [ -w . ]; then
    echo "Launching make xconfig..."
    make xconfig
elif [ "$(id -u)" -ne 0 ]; then
    echo "Insufficient permissions to write to $KERNEL_SRC. Attempting to run make xconfig with sudo."
    sudo -E make xconfig
else
    echo "Error: Directory $KERNEL_SRC is not writable even as root. Please check permissions."
    exit 1
fi
