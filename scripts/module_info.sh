#!/bin/bash

# Kernel source directory
KERNEL_URI="/usr/src/kernel/kernel-jammy-src"

# Helper Functions

# Find the Kconfig file defining the config option
find_kconfig_file() {
    local option="${1#CONFIG_}"
    grep -rl "^config $option$" "$KERNEL_URI" --include=Kconfig | head -n 1
}

# Extract the config block from Kconfig
extract_kconfig_block() {
    local kconfig_file="$1"
    local option="${2#CONFIG_}"
    sed -n "/^config $option$/,/^config /p" "$kconfig_file" | sed '$d'
}

# Get the type (bool, tristate, etc.)
get_type() {
    local block="$1"
    echo "$block" | sed -n '2p' | awk '{print $1}'
}

# Get dependencies and their expression
get_dependencies() {
    local block="$1"
    deps=$(echo "$block" | grep "^[[:space:]]*depends on" | sed 's/^[[:space:]]*depends on //' | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$deps" ]; then
        echo "Expression: $deps"
        echo "$deps" | grep -o '[A-Z0-9_]\+' | sort -u
    fi
}

# Check a config option's status in .config
get_config_status() {
    local config_file="$1"
    local dep="$2"
    if [ -f "$config_file" ]; then
        line=$(grep "^$dep=" "$config_file")
        if [ -n "$line" ]; then
            echo "$line"
        elif grep -q "^# $dep is not set" "$config_file"; then
            echo "# $dep is not set"
        else
            echo "$dep not found"
        fi
    else
        echo "status unknown"
    fi
}

# Main Logic

# Validate input
[ $# -ne 1 ] && {
    echo "Usage: $0 <module_flag>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 CONFIG_LOGITECH_FF"
    exit 1
}

flag="$1"
[[ "$flag" =~ ^CONFIG_ ]] || flag="CONFIG_$flag"

# Search for the flag in Makefiles
echo "Searching for $flag in Makefiles..."
while IFS= read -r line; do
    module=$(echo "$line" | grep -oP '(?<=obj-\$\('"${flag}"'\))[+=]+\s+\K[^[:space:]]+\.o' | sed 's/\.o$//')
    rel_dir=$(dirname "$(echo "$line" | cut -d: -f1)")
    [ -n "$module" ] && break
done < <(grep -r --include=Makefile "\$($flag)" "$KERNEL_URI" 2>/dev/null)

if [ -z "$module" ]; then
    echo "Error: No module found for $flag in $KERNEL_URI"
else
    echo "Module: $module"
    echo "Path: $rel_dir/$module.ko"

    # Define .config file path
    config_file="$KERNEL_URI/.config"

    # Find and parse Kconfig
    kconfig_file=$(find_kconfig_file "$flag")
    if [ -z "$kconfig_file" ]; then
        echo "Warning: Kconfig file for $flag not found"
    else
        block=$(extract_kconfig_block "$kconfig_file" "$flag")
        type=$(get_type "$block")
        
        # Report possible modes
        case "$type" in
            bool) modes="y or n" ;;
            tristate) modes="y, m, or n" ;;
            *) modes="unknown" ;;
        esac
        echo "Possible modes: $modes"

        # Report dependencies
        mapfile -t dep_info < <(get_dependencies "$block")
        if [ ${#dep_info[@]} -gt 0 ]; then
            expression="${dep_info[0]}"
            expression=$(echo "$expression" | sed 's/Expression: //; s/ / && /g')
            config_list=("${dep_info[@]:1}")
            echo "Dependencies: $expression"
            for dep in "${config_list[@]}"; do
                status=$(get_config_status "$config_file" "CONFIG_$dep")
                echo "  CONFIG_$dep: $status"
            done
        else
            echo "No dependencies"
        fi
    fi

    # Check flag status in .config
    echo "In .config:"
    if [ -f "$config_file" ]; then
        line=$(grep "$flag" "$config_file" | head -n 1)
        [ -n "$line" ] && echo "$line" || echo "$flag cannot be found"
    else
        echo "Warning: .config file not found in $KERNEL_URI; cannot determine if $flag is enabled"
    fi
fi
