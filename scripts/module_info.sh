#!/bin/bash

# Default kernel source directory, override with KERNEL_URI environment variable if needed
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Check for correct number of arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 [-v] <module_flag>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 -v CONFIG_LOGITECH_FF"
    exit 1
fi

# Check for verbose flag
verbose=0
if [ "$1" == "-v" ]; then
    verbose=1
    initial_flag="$2"
else
    initial_flag="$1"
fi

# Standardize the flag by adding CONFIG_ prefix if missing
[[ "$initial_flag" =~ ^CONFIG_ ]] || initial_flag="CONFIG_$initial_flag"

# Global variables
declare -A processed_flags
config_file="$KERNEL_URI/.config"
unmet_deps=()
initial_type=""
initial_module=""
initial_rel_dir=""
initial_status=""

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

# Function to process a flag and its dependencies
process_flag() {
    local flag="$1"
    local is_initial="$2"

    # Skip if already processed
    if [[ -n "${processed_flags[$flag]}" ]]; then
        return
    fi
    processed_flags[$flag]=1

    # Find Kconfig file
    kconfig_file=$(find_kconfig_file "$flag")
    if [ -z "$kconfig_file" ]; then
        if [ "$is_initial" -eq 1 ]; then
            echo "Warning: Kconfig definition not found for $flag"
        fi
        return
    fi

    # Extract config block and type
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

    # Store info for initial flag
    if [ "$is_initial" -eq 1 ]; then
        initial_type="$type"
        initial_module="$module"
        initial_rel_dir="$rel_dir"
        initial_status=$(get_config_status "$config_file" "$flag")
    fi

    # Display dependencies only in verbose mode
    if [ "$verbose" -eq 1 ]; then
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

        if [ -n "$deps" ]; then
            echo "Dependencies:"
            unique_deps=$(get_unique_deps "$deps")
            for dep in $unique_deps; do
                dep_flag="CONFIG_$dep"
                status=$(get_config_status "$config_file" "$dep_flag")
                echo "  $dep_flag: $status"
                if [[ "$status" == *"not set"* || "$status" == *"not found"* ]]; then
                    unmet_deps+=("$dep_flag")
                fi
            done
        else
            echo "No dependencies"
        fi
        echo "In .config: $initial_status"
    fi

    # Recurse for dependencies (but don’t display unless verbose)
    if [ -n "$deps" ]; then
        unique_deps=$(get_unique_deps "$deps")
        for dep in $unique_deps; do
            process_flag "CONFIG_$dep" 0
        done
    fi
}

# Process the initial flag
process_flag "$initial_flag" 1

# Summary section
echo
echo "===== Summary for $initial_flag ====="
echo "**Flag**: $initial_flag"
if [ -n "$initial_module" ]; then
    echo "**Module name**: $initial_module"
    echo "**Module path**: $initial_rel_dir/$initial_module.ko"
fi
echo "**Type**: $initial_type"
echo "**Status**: $initial_status"

if [ ${#unmet_deps[@]} -gt 0 ]; then
    echo "**Unmet Dependencies**:"
    for dep in "${unmet_deps[@]}"; do
        echo "- $dep"
    done
    echo "Enable these in 'make menuconfig' to use $initial_flag successfully."
fi
