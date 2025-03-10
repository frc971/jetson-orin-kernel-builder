#!/bin/bash
# Kernel Module Installation Script Generator
# This script generates an installation script for a specified kernel module.
# The generated script will check the module's compatibility with the running kernel,
# copy the module to the correct location, update dependencies, and load the module.
#
# Usage:
#   ./install_module_author.sh <module_name> <install_path>
#
# Options:
#   <module_name>   Name of the kernel module (without .ko extension)
#   <install_path>  Path where the module should be installed under /lib/modules/$(uname -r)/kernel/
#
# Example:
#   ./install_module_author.sh ch341 drivers/usb/serial
#
# Output:
# - Generates a script named install_module_<module_name>.sh
# - The generated script:
#   1. Checks if the module file exists in the current directory.
#   2. Verifies that the module was built for the running kernel.
#   3. Copies the module to the correct kernel directory.
#   4. Runs 'depmod -a' to update module dependencies.
#   5. Loads the module using 'modprobe'.
#
# Notes:
# - The generated script requires root privileges to install the module.
# - If the module was built for a different kernel version, installation will be aborted.
#
# Copyright (c) 2016-25 JetsonHacks
# MIT License

# Check if exactly two arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <module_name> <install_path>"
    echo "Example: $0 ch341 drivers/usb/serial"
    exit 1
fi

module_name="$1"
install_path="$2"

# Name of the generated script
result_script="install_module_${module_name}.sh"

# Create the result script with a here-document
cat > "$result_script" << EOF
#!/bin/bash

# Define the module file name and expected location
module_file="${module_name}.ko"
install_dir="/lib/modules/\$(uname -r)/kernel/${install_path}/"

# Check if the module file exists in the current directory
if [ ! -f "\$module_file" ]; then
    echo "Error: \$module_file not found in the current directory."
    exit 1
fi

# Extract vermagic from the module
module_vermagic=\$(modinfo -F vermagic "\$module_file")
if [ -z "\$module_vermagic" ]; then
    echo "Error: Could not extract vermagic from \$module_file."
    exit 1
fi

# Get the running kernel version
running_kernel=\$(uname -r)
module_kernel=\$(echo "\$module_vermagic" | awk '{print \$1}') # Extract version part

# Compare and handle mismatch
if [ "\$module_kernel" != "\$running_kernel" ]; then
    echo "Error: Module kernel version (\$module_kernel) does not match running kernel (\$running_kernel)."
    echo "Aborting installation to prevent potential system instability."
    exit 1
fi

# Inform the user in detail about the actions to be performed
echo "This script will perform the following actions:"
echo "1. Copy \$module_file to \$install_dir using 'sudo cp'"
echo "2. Update module dependencies with 'sudo depmod -a'"
echo "3. Load the module '${module_name}' with 'sudo modprobe ${module_name}'"
echo "These steps require root privileges, so you may be prompted for your password."

# Ask for confirmation
read -p "Do you want to proceed? (y/n): " confirm
if [ "\$confirm" != "y" ]; then
    echo "Aborting."
    exit 1
fi

# Step 1: Copy the .ko file to the installation directory
echo "Step 1: Copying \$module_file to \$install_dir using 'sudo cp'"
sudo cp "\$module_file" "\$install_dir"
if [ \$? -ne 0 ]; then
    echo "Error: Failed to copy \$module_file to \$install_dir."
    exit 1
fi

# Step 2: Update module dependencies
echo "Step 2: Updating module dependencies with 'sudo depmod -a'"
sudo depmod -a
if [ \$? -ne 0 ]; then
    echo "Error: Failed to run depmod."
    exit 1
fi

# Step 3: Load the module
echo "Step 3: Loading the module '${module_name}' with 'sudo modprobe ${module_name}'"
sudo modprobe "${module_name}"
if [ \$? -ne 0 ]; then
    echo "Error: Failed to load module ${module_name}."
    exit 1
fi

echo "Success: Module ${module_name} installed and loaded."
EOF

# Make the generated script executable
chmod +x "$result_script"

echo "Generated $result_script successfully."
