#!/bin/bash

# Default kernel source directory, can be overridden with KERNEL_URI environment variable
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Check if a module flag was provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <module_flag>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 CONFIG_LOGITECH_FF"
    exit 1
fi

# Get the input flag
input_flag="$1"

# Standardize the flag by adding CONFIG_ if it’s not present
if [[ "$input_flag" != CONFIG_* ]]; then
    config_flag="CONFIG_$input_flag"
else
    config_flag="$input_flag"
fi

# Search for the Makefile containing obj-$(CONFIG_...) += ... for this flag
found=false
while IFS= read -r line; do
    # Match lines like: obj-$(CONFIG_LOGITECH_FF) += module_name.o
    if [[ "$line" =~ obj-\$\($config_flag\)[[:space:]]*\+=[[:space:]]*([^ ]+)\.o ]]; then
        module_name="${BASH_REMATCH[1]}"  # Extract module_name from module_name.o
        makefile=$(echo "$line" | cut -d: -f1)  # Get the Makefile path
        directory=$(dirname "$makefile")  # Get the directory of the Makefile
        rel_dir=${directory#$KERNEL_URI/}  # Relative path from kernel root
        echo "Found in Makefile: $makefile"
        echo "Module name: $module_name"
        echo "Module path: $rel_dir/$module_name.ko"
        found=true
        break  # Exit after the first match
    fi
done < <(grep -r "obj-\$($config_flag)" "$KERNEL_URI" 2>/dev/null)

# If no match was found, report an error
if [ "$found" = false ]; then
    echo "Error: No module found for $config_flag in $KERNEL_URI"
    exit 1
fi
