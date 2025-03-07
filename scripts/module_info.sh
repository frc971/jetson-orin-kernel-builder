#!/bin/bash

# Default kernel source path (can be overridden with environment variable)
KERNEL_URI="${KERNEL_URI:-/usr/src/linux}"

# Check if kernel source exists
if [ ! -d "$KERNEL_URI" ]; then
    echo "Error: Kernel source not found at $KERNEL_URI. Set KERNEL_URI environment variable."
    exit 1
fi

# Function to get Kconfig info (type and dependencies) for a config option
get_kconfig_info() {
    local config_name="$1"
    local kconfig_file
    kconfig_file=$(grep -rl "^config $config_name$" "$KERNEL_URI" 2>/dev/null | head -n 1)
    if [ -z "$kconfig_file" ]; then
        echo "Error: Config option CONFIG_$config_name not found in Kconfig files."
        exit 1
    fi

    # Extract the config block
    local block
    block=$(sed -n "/^config $config_name$/,/^config /p" "$kconfig_file" | sed '$d')
    
    # Determine type
    local type="unknown"
    if echo "$block" | grep -q "tristate"; then
        type="tristate"
    elif echo "$block" | grep -q "bool"; then
        type="bool"
    fi

    # Extract dependencies
    local dependencies=()
    while read -r line; do
        if [[ "$line" =~ ^[[:space:]]*depends[[:space:]]+on[[:space:]]+(.+)$ ]]; then
            local deps="${BASH_REMATCH[1]}"
            # Extract config names (simplified, ignoring operators like &&, ||)
            while read -r dep; do
                if [[ "$dep" =~ ^[A-Z0-9_]+$ ]]; then
                    dependencies+=("$dep")
                fi
            done < <(echo "$deps" | tr ' ' '\n')
        fi
    done < <(echo "$block")

    echo "$type"
    printf '%s\n' "${dependencies[@]}"
    echo "$kconfig_file"
}

# Function to find module name and path from a config option
find_module_from_config() {
    local config_option="$1"
    local pattern="obj-\$(CONFIG_${config_option})[[:space:]]*\+=[[:space:]]*([^ ]+)\.o"
    local makefile
    local match
    while IFS= read -r makefile; do
        match=$(grep -E "$pattern" "$makefile")
        if [ -n "$match" ]; then
            if [[ "$match" =~ $pattern ]]; then
                local module_name="${BASH_REMATCH[1]}"
                local directory
                directory=$(dirname "$makefile" | sed "s|$KERNEL_URI/||")
                echo "$module_name"
                echo "$directory/$module_name.ko"
                return
            fi
        fi
    done < <(find "$KERNEL_URI" -name Makefile)
    echo "Error: No module found for CONFIG_$config_option in Makefiles."
    exit 1
}

# Function to find config option from module path
find_config_from_module() {
    local module_path="$1"
    local directory
    directory=$(dirname "$module_path")
    local module_name
    module_name=$(basename "$module_path" .ko)
    local makefile="$KERNEL_URI/$directory/Makefile"
    if [ ! -f "$makefile" ]; then
        echo "Error: Makefile not found at $makefile"
        exit 1
    fi
    local pattern="obj-\$\(CONFIG_([A-Z0-9_]+)\)[[:space:]]*\+=[[:space:]]*$module_name\.o"
    local match
    match=$(grep -E "$pattern" "$makefile")
    if [[ "$match" =~ $pattern ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "Error: Config option not found for $module_name in $makefile"
        exit 1
    fi
}

# Function to find controlling tristate option for a bool config
find_controlling_option() {
    local config_name="$1"
    read type deps _ < <(get_kconfig_info "$config_name")
    local dep
    while read -r dep; do
        if [ -n "$dep" ]; then
            read dep_type _ < <(get_kconfig_info "$dep")
            if [ "$dep_type" = "tristate" ]; then
                echo "$dep"
                return
            fi
        fi
    done < <(echo "$deps" | tr ' ' '\n')
    echo "Error: No tristate controlling option found for CONFIG_$config_name"
    exit 1
}

# Main script
if [ $# -ne 1 ]; then
    echo "Usage: $0 <module_flag_or_path>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 drivers/hid/hid-logitech.ko"
    exit 1
fi

input="$1"

if [[ "$input" =~ / ]]; then
    # Input is a module path
    module_path="$input"
    config_option=$(find_config_from_module "$module_path")
    read type dependencies _ < <(get_kconfig_info "$config_option")

    echo "Module Information:"
    echo "-------------------"
    echo "Module path: $module_path"
    echo "Controlling config option: CONFIG_$config_option"
    echo "Dependencies: ${dependencies[*]}"
    echo
    echo "To build this module, set CONFIG_$config_option=m in your kernel .config"
    echo "and ensure all dependencies are enabled (e.g., CONFIG_<dep>=y or m)."
else
    # Input is a config flag
    config_name="$input"
    read type dependencies kconfig_file < <(get_kconfig_info "$config_name")

    if [ "$type" = "tristate" ]; then
        controlling_option="$config_name"
        feature_option=""
    elif [ "$type" = "bool" ]; then
        feature_option="$config_name"
        controlling_option=$(find_controlling_option "$config_name")
        read _ dependencies _ < <(get_kconfig_info "$controlling_option")
    else
        echo "Error: CONFIG_$config_name has an unknown type in $kconfig_file"
        exit 1
    fi

    read module_name module_path < <(find_module_from_config "$controlling_option")

    echo "Module Information:"
    echo "-------------------"
    if [ -n "$feature_option" ]; then
        echo "Feature: CONFIG_$feature_option"
        echo "Part of module: $module_name.ko"
    else
        echo "Module: $module_name.ko"
    fi
    echo "Module path: $module_path"
    echo "Controlling config option: CONFIG_$controlling_option"
    echo "Dependencies: ${dependencies[*]}"
    echo
    if [ -n "$feature_option" ]; then
        echo "To enable this feature, set CONFIG_$feature_option=y and CONFIG_$controlling_option=m"
        echo "in your kernel .config, and ensure all dependencies are enabled."
    else
        echo "To build this module, set CONFIG_$controlling_option=m in your kernel .config"
        echo "and ensure all dependencies are enabled (e.g., CONFIG_<dep>=y or m)."
    fi
fi
