#!/bin/bash

# Default kernel source directory, can be overridden with KERNEL_URI environment variable
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Check for correct number of arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <module_flag_or_path>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 drivers/hid/hid-logitech.ko"
    exit 1
fi

input="$1"

# Function to find the Kconfig file defining a config option
find_kconfig_file() {
    local config_option="$1"
    grep -rl "^config $config_option$" "$KERNEL_URI" 2>/dev/null | head -n 1
}

# Function to parse a Kconfig block for type and dependencies
parse_kconfig_block() {
    local file="$1"
    local config_option="$2"
    # Extract block from "config $config_option" to next "config " or end
    block=$(sed -n "/^config $config_option$/,/^config /p" "$file" | sed '$d')
    # Determine type
    if echo "$block" | grep -q "tristate"; then
        type="tristate"
    elif echo "$block" | grep -q "bool"; then
        type="bool"
    else
        type="unknown"
    fi
    # Extract dependencies from "depends on" lines
    dependencies=()
    while read -r line; do
        if [[ "$line" =~ ^[[:space:]]*depends[[:space:]]+on[[:space:]]+(.+)$ ]]; then
            deps="${BASH_REMATCH[1]}"
            # Split and collect uppercase config options
            while read -r word; do
                if [[ "$word" =~ ^[A-Z0-9_]+$ ]]; then
                    dependencies+=("$word")
                fi
            done < <(echo "$deps" | tr ' ' '\n')
        fi
    done < <(echo "$block")
    echo "$type"
    printf '%s\n' "${dependencies[@]}"
}

# Function to find module name and path for a given config flag
find_module_for_flag() {
    local config_option="$1"
    while IFS= read -r line; do
        if [[ "$line" =~ obj-\$\(CONFIG_$config_option\)[[:space:]]*\+=[[:space:]]*([^ ]+)\.o ]]; then
            module_name="${BASH_REMATCH[1]}"
            makefile=$(echo "$line" | cut -d: -f1)
            directory=$(dirname "$makefile")
            rel_dir=${directory#$KERNEL_URI/}
            echo "$module_name"
            echo "$rel_dir/$module_name.ko"
            return
        fi
    done < <(grep -r "obj-\$(CONFIG_$config_option)" "$KERNEL_URI" 2>/dev/null)
    echo "Error: No module found for CONFIG_$config_option" >&2
    exit 1
}

# Function to find the controlling flag for a module path
find_flag_for_module() {
    local module_path="$1"
    directory=$(dirname "$module_path")
    module_name=$(basename "$module_path" .ko)
    makefile="$KERNEL_URI/$directory/Makefile"
    if [ ! -f "$makefile" ]; then
        echo "Error: Makefile not found at $makefile" >&2
        exit 1
    fi
    while read -r line; do
        if [[ "$line" =~ obj-\$\(CONFIG_([A-Z0-9_]+)\)[[:space:]]*\+=[[:space:]]*$module_name\.o ]]; then
            echo "CONFIG_${BASH_REMATCH[1]}"
            return
        fi
    done < "$makefile"
    echo "Error: No flag found for $module_name in $makefile" >&2
    exit 1
}

# Function to get module information given a config flag
get_module_info() {
    local input_flag="$1"
    local config_option=${input_flag#CONFIG_}
    local kconfig_file=$(find_kconfig_file "$config_option")
    if [ -z "$kconfig_file" ]; then
        echo "Error: Config option $input_flag not found" >&2
        exit 1
    fi
    # Parse type and dependencies
    mapfile -t kconfig_output < <(parse_kconfig_block "$kconfig_file" "$config_option")
    type="${kconfig_output[0]}"
    dependencies=("${kconfig_output[@]:1}")
    if [ "$type" = "tristate" ]; then
        controlling_flag="$input_flag"
        mapfile -t module_output < <(find_module_for_flag "$config_option")
        module_name="${module_output[0]}"
        module_path="${module_output[1]}"
    elif [ "$type" = "bool" ]; then
        # Find the first tristate dependency
        for dep in "${dependencies[@]}"; do
            dep_kconfig_file=$(find_kconfig_file "$dep")
            if [ -n "$dep_kconfig_file" ]; then
                mapfile -t dep_output < <(parse_kconfig_block "$dep_kconfig_file" "$dep")
                dep_type="${dep_output[0]}"
                if [ "$dep_type" = "tristate" ]; then
                    controlling_flag="CONFIG_$dep"
                    break
                fi
            fi
        done
        if [ -z "$controlling_flag" ]; then
            echo "Error: No tristate dependency found for $input_flag" >&2
            exit 1
        fi
        mapfile -t module_output < <(find_module_for_flag "${controlling_flag#CONFIG_}")
        module_name="${module_output[0]}"
        module_path="${module_output[1]}"
    else
        echo "Error: Unknown type for $input_flag" >&2
        exit 1
    fi
    # Get dependencies of the controlling flag
    controlling_config=${controlling_flag#CONFIG_}
    controlling_kconfig_file=$(find_kconfig_file "$controlling_config")
    mapfile -t controlling_output < <(parse_kconfig_block "$controlling_kconfig_file" "$controlling_config")
    controlling_dependencies=("${controlling_output[@]:1}")
    echo "$type"
    echo "$controlling_flag"
    echo "$module_name"
    echo "$module_path"
    printf '%s\n' "${controlling_dependencies[@]}"
}

# Main logic
if [[ "$input" =~ / ]]; then
    # Input is a module path
    module_path="$input"
    flag=$(find_flag_for_module "$module_path")
    mapfile -t info < <(get_module_info "$flag")
    type="${info[0]}"
    controlling_flag="${info[1]}"
    module_name="${info[2]}"
    module_path="${info[3]}"
    dependencies=("${info[@]:4}")
    echo "Module Information:"
    echo "-------------------"
    echo "Module path: $module_path"
    echo "Controlling config option: $controlling_flag"
    echo "Dependencies: ${dependencies[*]}"
    echo
    echo "To build this module, set $controlling_flag=m in your kernel .config"
    echo "and ensure all dependencies are enabled (e.g., CONFIG_<dep>=y or m)."
else
    # Input is a config flag
    if [[ "$input" != CONFIG_* ]]; then
        flag="CONFIG_$input"
    else
        flag="$input"
    fi
    mapfile -t info < <(get_module_info "$flag")
    type="${info[0]}"
    controlling_flag="${info[1]}"
    module_name="${info[2]}"
    module_path="${info[3]}"
    dependencies=("${info[@]:4}")
    echo "Module Information:"
    echo "-------------------"
    if [ "$type" = "bool" ]; then
        echo "Feature: $flag"
        echo "Part of module: $module_name.ko"
    else
        echo "Module: $module_name.ko"
    fi
    echo "Module path: $module_path"
    echo "Controlling config option: $controlling_flag"
    echo "Dependencies: ${dependencies[*]}"
    echo
    if [ "$type" = "bool" ]; then
        echo "To enable this feature, set $flag=y and $controlling_flag=m"
        echo "in your kernel .config, and ensure all dependencies are enabled."
    else
        echo "To build this module, set $controlling_flag=m in your kernel .config"
        echo "and ensure all dependencies are enabled (e.g., CONFIG_<dep>=y or m)."
    fi
fi
