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

### Step 1: Search Makefiles for the Flag
echo "Searching for $flag in Makefiles..."
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)
    if [[ "$content" =~ ^obj-\$\($flag\)[[:space:]]*\+=[[:space:]]*([^ ]+)\.o ]]; then
        module="${BASH_REMATCH[1]}"
        type="Module flag"
    elif [[ "$content" =~ ^([a-z0-9_-]+)-\$\($flag\)[[:space:]]*\+=[[:space:]]* ]]; then
        module="${BASH_REMATCH[1]}"
        type="Feature flag"
    fi
    if [ -n "$module" ]; then
        rel_dir=$(dirname "$file" | sed "s|^$KERNEL_URI/||")
        echo "$type: $flag"
        echo "Module name: $module"
        echo "Module path: $rel_dir/$module.ko"
        break
    fi
done < <(grep -r --include=Makefile "\$($flag)" "$KERNEL_URI" 2>/dev/null)

# If no module found, report an error and exit
if [ -z "$module" ]; then
    echo "Error: No module found for $flag in $KERNEL_URI"
    exit 1
fi

### Step 2: Find and Parse Kconfig File
kconfig_file=$(find_kconfig_file "$flag")
if [ -z "$kconfig_file" ]; then
    echo "Warning: Kconfig file for $flag not found"
else
    # Extract config block
    block=$(extract_config_block "$kconfig_file" "$flag")
    if [ -z "$block" ]; then
        echo "Warning: Config block for $flag not found in $kconfig_file"
    else
        # Determine possible modes from type
        type=$(get_type "$block")
        case "$type" in
            bool) modes="y or n" ;;
            tristate) modes="y, m, or n" ;;
            *) modes="unknown" ;;
        esac
        echo "Possible modes: $modes"

        # Extract and display dependencies
        deps=$(get_dependencies "$block")
        if [ -n "$deps" ]; then
            echo "Dependencies:"
            unique_deps=$(get_unique_deps "$deps")
            for dep in $unique_deps; do
                dep_flag="CONFIG_$dep"
                status=$(get_config_status "$KERNEL_URI/.config" "$dep_flag")
                echo "  $dep_flag: $status"
            done
        else
            echo "No dependencies"
        fi
    fi
fi

### Step 3: Check Flag Status in .config
echo "In .config:"
if [ -f "$KERNEL_URI/.config" ]; then
    line=$(grep "$flag" "$KERNEL_URI/.config" | head -n 1)
    [ -n "$line" ] && echo "$line" || echo "$flag cannot be found"
else
    echo "Warning: .config file not found in $KERNEL_URI; cannot determine if $flag or its dependencies are enabled"
fi
