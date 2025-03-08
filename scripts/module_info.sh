#!/bin/bash

# Script to find information about kernel module flags
# Default kernel source path, can be overridden by environment variable
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <module_flag>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 CONFIG_LOGITECH_FF"
    exit 1
fi

# Sanitize and standardize input
input_flag="${1//[^[:alnum:]_]/}"  # Basic sanitization
if [[ "$input_flag" != CONFIG_* ]]; then
    config_flag="CONFIG_${input_flag}"
else
    config_flag="$input_flag"
fi

# Ensure kernel directory exists
if [ ! -d "$KERNEL_URI" ]; then
    echo "Error: Kernel source directory $KERNEL_URI not found"
    exit 1
fi

found=false

# Search Makefiles efficiently using find and grep
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # Module flag pattern (e.g., obj-$(CONFIG_HID_LOGITECH) += hid-logitech.o)
    if [[ "$content" =~ ^obj-\$\("$config_flag"\)[[:space:]]*\+=[[:space:]]*([^[:space:]]+)\.o ]]; then
        module_name="${BASH_REMATCH[1]}"
        directory="$(dirname "$file")"
        rel_dir="${directory#"$KERNEL_URI"/}"
        echo "Module flag: $config_flag"
        echo "Module name: $module_name"
        echo "Module path: $rel_dir/$module_name.ko"
        found=true
        break

    # Feature flag pattern (e.g., hid-logitech-$(CONFIG_LOGITECH_FF) += hid-lgff.o)
    elif [[ "$content" =~ ^([a-z0-9_-]+)-\$\("$config_flag"\)[[:space:]]*\+=[[:space:]]* ]]; then
        module_name="${BASH_REMATCH[1]}"
        directory="$(dirname "$file")"
        rel_dir="${directory#"$KERNEL_URI"/}"
        echo "Feature flag: $config_flag"
        echo "Part of module: $module_name"
        echo "Module path: $rel_dir/$module_name.ko"
        found=true
        break
    fi
done < <(find "$KERNEL_URI" -name Makefile -exec grep -H "\$($config_flag)" {} + 2>/dev/null)

if [ "$found" = true ]; then
    config_file="$KERNEL_URI/.config"
    if [ ! -f "$config_file" ]; then
        echo "Error: .config file not found in $KERNEL_URI"
        exit 1
    fi
    echo "In .config:"
    if grep -q "$config_flag" "$config_file"; then
        grep "$config_flag" "$config_file" | head -n 1
    else
        echo "$config_flag cannot be found"
    fi
elif [ -z "$input_flag" ]; then
    echo "Error: Empty input provided"
    exit 1
else
    echo "Error: No module found for $config_flag in $KERNEL_URI"
    exit 1
fi
