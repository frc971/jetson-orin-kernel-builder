#!/bin/bash

# Define the module file name and expected location
module_file="ch341.ko"
install_dir="/lib/modules/$(uname -r)/kernel/drivers/usb/serial/"

# Check if the module file exists in the current directory
if [ ! -f "$module_file" ]; then
    echo "Error: $module_file not found in the current directory."
    exit 1
fi

# Extract vermagic from the module
module_vermagic=$(modinfo -F vermagic "$module_file")
if [ -z "$module_vermagic" ]; then
    echo "Error: Could not extract vermagic from $module_file."
    exit 1
fi

# Get the running kernel version
running_kernel=$(uname -r)
module_kernel=$(echo "$module_vermagic" | awk '{print $1}') # Extract version part

# Compare and handle mismatch
if [ "$module_kernel" != "$running_kernel" ]; then
    echo "Error: Module kernel version ($module_kernel) does not match running kernel ($running_kernel)."
    echo "Aborting installation to prevent potential system instability."
    exit 1
fi

# Inform the user in detail
echo "This script will perform the following actions:"
echo "1. Copy $module_file to $install_dir using 'sudo cp'"
echo "2. Update module dependencies with 'sudo depmod -a'"
echo "3. Load the module 'ch341.ko' with 'sudo modprobe ch341.ko'"
echo "These steps require root privileges, so you may be prompted for your password."

# Ask for confirmation
read -p "Do you want to proceed? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Aborting."
    exit 1
fi

# Copy the .ko file to the installation directory
sudo cp "$module_file" "$install_dir"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy $module_file to $install_dir."
    exit 1
fi

# Update module dependencies
sudo depmod -a
if [ $? -ne 0 ]; then
    echo "Error: Failed to run depmod."
    exit 1
fi

# Load the module
sudo modprobe "ch341.ko"
if [ $? -ne 0 ]; then
    echo "Error: Failed to load module ch341.ko."
    exit 1
fi

echo "Success: Module ch341.ko installed and loaded."
