#!/bin/bash

# Default kernel source directory, override with KERNEL_URI environment variable if needed
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Check for correct number of arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <module_flag>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 CONFIG_LOGITECH_FF"
    exit 1
fi

# Standardize the flag by adding CONFIG_ prefix if missing
flag="$1"
[[ "$flag" =~ ^CONFIG_ ]] || flag="CONFIG_$flag"

# Global variables
declare -A processed_flags
config_file="$KERNEL_URI/.config"

# Function to find the Kconfig file defining the flag
find_kconfig_file() {
    local flag_name="${1#CONFIG_}"
    grep -rl "^config $flag_name$" "$KERNEL_URI" --include=Kconfig | head -n 1
}

# Function to extract the config block from Kconfig
extract_config_block() {
    local kconfig_file="$1"
    local flag_name="${2#CONFIG_}"
    sed -n "/^config $flag_name$/,/^config /p" "$kconfig_file" | sed '$d'
}

# Function to get the type from the config block
get_type() {
    local block="$1"
    echo "$block" | sed -n '2p' | awk '{print $1}'
}

# Function to get dependencies from the config block
get_dependencies() {
    local block="$1"
    echo "$block" | grep "^[[:space:]]*depends on" | sed 's/^[[:space:]]*depends on //'
}

# Function to get unique config flags from dependencies
get_unique_deps() {
    local deps="$1"
    echo "$deps" | grep -o '\b[A-Z0-9_]\+\b' | sort -u
}

# Function to get the status of a config flag from .config
get_config_status() {
    local config_file="$1"
    local dep_flag="$2"
    if [ -f "$config_file" ]; then
        if grep -q "^$dep_flag=" "$config_file"; then
            grep "^$dep_flag=" "$config_file"
        elif grep -q "^# $dep_flag is not set" "$config_file"; then
            echo "# $dep_flag is not set"
        else
            echo "$dep_flag not found"
        fi
    else
        echo "status unknown"
    fi
}

# Recursive function to process a flag and its dependencies
process_flag() {
    local flag="$1"

    # Skip if already processed to prevent cycles
    if [[ -n "${processed_flags[$flag]}" ]]; then
        return
    fi
    processed_flags[$flag]=1

    # Find Kconfig file
    kconfig_file=$(find_kconfig_file "$flag")
    if [ -z "$kconfig_file" ]; then
        echo "----- Flag: $flag -----"
        echo "Warning: Kconfig definition not found"
        return
    fi

    # Extract config block
    block=$(extract_config_block "$kconfig_file" "$flag")
    type=$(get_type "$block")
    deps=$(get_dependencies "$block")

    # Determine possible modes
    case "$type" in
        bool) modes="y or n" ;;
        tristate) modes="y, m, or n" ;;
        *) modes="unknown" ;;
    esac

    # Find module information
    module_info=$(grep -r --include=Makefile "\$($flag)" "$KERNEL_URI" 2>/dev/null)
    if echo "$module_info" | grep -q "obj-\$\($flag\)"; then
        module_line=$(echo "$module_info" | grep "obj-\$\($flag\)" | head -n 1)
        module=$(echo "$module_line" | sed -r 's/.*\+= ([^ ]+)\.o/\1/')
        rel_dir=$(dirname "$(echo "$module_line" | cut -d: -f1)" | sed "s|^$KERNEL_URI/||")
        module_type="Module"
    elif echo "$module_info" | grep -q "[a-z0-9_-]+-\$\($flag\)"; then
        feature_line=$(echo "$module_info" | grep "[a-z0-9_-]+-\$\($flag\)" | head -n 1)
        module=$(echo "$feature_line" | sed -r 's/([a-z0-9_-]+)-\$\('$flag'\).*/\1/')
        rel_dir=$(dirname "$(echo "$feature_line" | cut -d: -f1)" | sed "s|^$KERNEL_URI/||")
        module_type="Feature of $module"
    else
        module_type="Simple flag"
    fi

    # Display header and information
    echo "----- $module_type: $flag -----"
    if [ "$module_type" == "Module" ]; then
        echo "Module name: $module"
        echo "Module path: $rel_dir/$module.ko"
    elif [ "$module_type" == "Feature of $module" ]; then
        echo "Part of module: $module"
        echo "Module path: $rel_dir/$module.ko"
    fi
    echo "Type: $type"
    echo "Possible modes: $modes"

    # Display dependencies
    if [ -n "$deps" ]; then
        echo "Dependencies:"
        unique_deps=$(get_unique_deps "$deps")
        for dep in $unique_deps; do
            dep_flag="CONFIG_$dep"
            status=$(get_config_status "$config_file" "$dep_flag")
            echo "  $dep_flag: $status"
        done
    else
        echo "No dependencies"
    fi

    # Display flag status in .config
    echo "In .config:"
    if [ -f "$config_file" ]; then
        line=$(grep "$flag" "$config_file" | head -n 1)
        [ -n "$line" ] && echo "$line" || echo "$flag cannot be found"
    else
        echo "Warning: .config file not found; cannot determine status"
    fi

    # Recurse for all dependencies
    if [ -n "$unique_deps" ]; then
        for dep in $unique_deps; do
            process_flag "CONFIG_$dep"
        done
    fi
}

# Start processing the initial flag
process_flag "$flag"
