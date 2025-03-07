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
initial_flag="$1"
[[ "$initial_flag" =~ ^CONFIG_ ]] || initial_flag="CONFIG_$initial_flag"

# Global variables
declare -A processed_flags
config_file="$KERNEL_URI/.config"
unmet_deps=()
initial_type=""
initial_module=""
initial_rel_dir=""
initial_status=""
immediate_dep_flag=""
immediate_dep_status=""

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
    local is_initial="$2"

    # Skip if already processed
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
            if [[ "$status" == *"not set"* || "$status" == *"not found"* ]]; then
                unmet_deps+=("$dep_flag")
            fi
        done
    else
        echo "No dependencies"
    fi

    # Display flag status in .config
    echo "In .config:"
    if [ -f "$config_file" ]; then
        line=$(grep "$flag" "$config_file" | head -n 1)
        [ -n "$line" ] && echo "$line" || {
            echo "$flag not set"
            unmet_deps+=("$flag")
        }
    else
        echo "Warning: .config file not found; cannot determine status"
    fi

    # Recurse for dependencies
    if [ -n "$unique_deps" ]; then
        for dep in $unique_deps; do
            process_flag "CONFIG_$dep" 0
        done
    fi

    # Store info for initial flag
    if [ "$is_initial" -eq 1 ]; then
        initial_type="$type"
        initial_module="$module"
        initial_rel_dir="$rel_dir"
        initial_status=$(get_config_status "$config_file" "$flag")
        if [ "$type" == "bool" ] && [ -n "$unique_deps" ]; then
            immediate_dep=$(echo "$unique_deps" | head -n 1)
            immediate_dep_flag="CONFIG_$immediate_dep"
            immediate_dep_status=$(get_config_status "$config_file" "$immediate_dep_flag")
        fi
    fi
}

# Process the initial flag
process_flag "$initial_flag" 1

# Summary section with explanation
echo
echo "===== Summary for $initial_flag ====="
echo "**Flag**: $initial_flag"
if [ "$initial_type" == "tristate" ] || ([ "$initial_type" == "bool" ] && [ -n "$initial_module" ]); then
    echo "**Expected .ko file**: $initial_rel_dir/$initial_module.ko"
fi
echo
echo "**Explanation and Instructions**:"

if [ -f "$config_file" ]; then
    if [ "$initial_type" == "tristate" ]; then
        echo "- **Type**: This is a tristate flag, meaning it can be built into the kernel ('y'), built as a loadable module ('m'), or disabled ('n')."
        if [[ "$initial_status" == *=m ]]; then
            echo "- **Status**: The flag is set to 'm', so it will be built as a loadable module."
            echo "- **Instructions**: After building the kernel with 'make modules', load the module using:"
            echo "  \`\`\`bash"
            echo "  sudo insmod $initial_rel_dir/$initial_module.ko"
            echo "  \`\`\`"
        elif [[ "$initial_status" == *=y ]]; then
            echo "- **Status**: The flag is set to 'y', so it’s built into the kernel."
            echo "- **Instructions**: To use it as a module instead, edit the .config file to set $initial_flag=m, then run:"
            echo "  \`\`\`bash"
            echo "  make modules && sudo insmod $initial_rel_dir/$initial_module.ko"
            echo "  \`\`\`"
        else
            echo "- **Status**: The flag is not set."
            echo "- **Instructions**: To enable it, use 'make menuconfig' to set $initial_flag to 'm' or 'y', then build with:"
            echo "  \`\`\`bash"
            echo "  make && make modules"
            echo "  \`\`\`"
            echo "  If set to 'm', load it with 'sudo insmod $initial_rel_dir/$initial_module.ko'."
        fi
    elif [ "$initial_type" == "bool" ]; then
        echo "- **Type**: This is a boolean flag, meaning it can be enabled ('y') or disabled ('n') within the kernel or a module."
        if [ -n "$immediate_dep_flag" ]; then
            if [[ "$immediate_dep_status" == *=m ]]; then
                echo "- **Dependency Status**: Depends on $immediate_dep_flag, which is set to 'm' (a module)."
                if [[ "$initial_status" == *=y ]]; then
                    echo "- **Status**: The feature is enabled and included in $initial_module.ko."
                    echo "- **Instructions**: Build the module with 'make modules' and load it with:"
                    echo "  \`\`\`bash"
                    echo "  sudo insmod $initial_rel_dir/$initial_module.ko"
                    echo "  \`\`\`"
                else
                    echo "- **Status**: The feature is not enabled."
                    echo "- **Instructions**: Set $initial_flag to 'y' in 'make menuconfig', then build and load the module:"
                    echo "  \`\`\`bash"
                    echo "  make modules && sudo insmod $initial_rel_dir/$initial_module.ko"
                    echo "  \`\`\`"
                fi
            elif [[ "$immediate_dep_status" == *=y ]]; then
                echo "- **Dependency Status**: Depends on $immediate_dep_flag, which is set to 'y' (built-in)."
                if [[ "$initial_status" == *=y ]]; then
                    echo "- **Status**: The feature is enabled and built into the kernel."
                    echo "- **Instructions**: No further action needed unless you want it as a module (requires changing $immediate_dep_flag)."
                else
                    echo "- **Status**: The feature is not enabled."
                    echo "- **Instructions**: Set $initial_flag to 'y' in 'make menuconfig' and recompile the kernel with:"
                    echo "  \`\`\`bash"
                    echo "  make"
                    echo "  \`\`\`"
                fi
            else
                echo "- **Dependency Status**: Depends on $immediate_dep_flag, which is not set."
                echo "- **Instructions**: First enable $immediate_dep_flag to 'm' or 'y', then set $initial_flag to 'y' in 'make menuconfig'. Build with:"
                echo "  \`\`\`bash"
                echo "  make && make modules"
                echo "  \`\`\`"
            fi
        else
            echo "- **Status**: This flag has no dependencies."
            if [[ "$initial_status" == *=y ]]; then
                echo "- **Instructions**: The feature is enabled and built into the kernel; no further action needed."
            else
                echo "- **Instructions**: Set $initial_flag to 'y' in 'make menuconfig' and build with 'make'."
            fi
        fi
    fi
else
    echo "- **Warning**: The .config file is missing, so the current status is unknown."
    if [ "$initial_type" == "tristate" ]; then
        echo "- **Type**: This is a tristate flag (y, m, or n)."
        echo "- **Instructions**: Set $initial_flag to 'm' in 'make menuconfig' to build it as a module at $initial_rel_dir/$initial_module.ko, then use:"
        echo "  \`\`\`bash"
        echo "  make modules && sudo insmod $initial_rel_dir/$initial_module.ko"
        echo "  \`\`\`"
    elif [ "$initial_type" == "bool" ]; then
        echo "- **Type**: This is a boolean flag (y or n)."
        echo "- **Instructions**: Set $initial_flag to 'y' in 'make menuconfig' and build with 'make'."
    fi
fi

# List unmet dependencies
if [ ${#unmet_deps[@]} -gt 0 ]; then
    echo
    echo "**Unmet Dependencies**:"
    for dep in "${unmet_deps[@]}"; do
        echo "- $dep"
    done
    echo "Enable these in 'make menuconfig' to use $initial_flag successfully."
fi
