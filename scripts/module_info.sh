#!/bin/bash

# Set default KERNEL_URI, override with environment variable if set
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <module_flag>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 CONFIG_LOGITECH_FF"
    exit 1
fi

# Standardize the input flag by adding CONFIG_ prefix if missing
input_flag="$1"
if [[ "$input_flag" != CONFIG_* ]]; then
    config_flag="CONFIG_$input_flag"
else
    config_flag="$input_flag"
fi

# Flag to track if a match is found
found=false

# Search Makefiles for lines containing $(config_flag)
while IFS= read -r line; do
    # Extract file path and content
    file=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # Case 1: Module flag, e.g., obj-$(CONFIG_HID_LOGITECH) += hid-logitech.o
    if [[ "$content" =~ ^obj-\$\($config_flag\)[[:space:]]*\+=[[:space:]]*([^ ]+)\.o ]]; then
        module_name="${BASH_REMATCH[1]}"
        directory=$(dirname "$file")
        rel_dir=${directory#$KERNEL_URI/}
        echo "Module flag: $config_flag"
        echo "Module name: $module_name"
        echo "Module path: $rel_dir/$module_name.ko"
        found=true
        break

    # Case 2: Feature flag, e.g., hid-logitech-$(CONFIG_LOGITECH_FF) += hid-lgff.o
    elif [[ "$content" =~ ^([a-z0-9_-]+)-\$\($config_flag\)[[:space:]]*\+=[[:space:]]* ]]; then
        module_name="${BASH_REMATCH[1]}"
        directory=$(dirname "$file")
        rel_dir=${directory#$KERNEL_URI/}
        echo "Feature flag: $config_flag"
        echo "Part of module: $module_name"
        echo "Module path: $rel_dir/$module_name.ko"
        found=true
        break
    fi
done < <(grep -r --include=Makefile "\$($config_flag)" "$KERNEL_URI" 2>/dev/null)

# If no match is found, report an error
if [ "$found" = false ]; then
    echo "Error: No module found for $config_flag in $KERNEL_URI"
    exit 1
fi
