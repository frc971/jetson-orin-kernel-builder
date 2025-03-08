#!/bin/bash

# Script to find information about kernel module flags, their dependencies, and configuration types.
# Helps inexperienced users understand module/feature flags, their status, types, and dependencies.

# Default kernel source path, can be overridden by environment variable
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Display usage information
usage() {
    echo "Usage: $0 [-h] <module_flag>"
    echo "Example: $0 LOGITECH_FF"
    echo "         $0 CONFIG_LOGITECH_FF"
    echo "Options:"
    echo "  -h    Display this help message"
}

# Function to analyze type, possible values, description, and dependencies from Kconfig
analyze_kconfig() {
    local config_flag="$1"
    local directory="$2"
    local kconfig_file="$directory/Kconfig"

    if [ ! -f "$kconfig_file" ]; then
        echo "  Kconfig not found in $directory, type and dependency analysis skipped"
        return
    fi

    echo "Kconfig analysis from $kconfig_file:"

    # Extract the config block for the given flag
    local in_block=false
    local config_type=""
    local description=""
    local default_value=""
    local -a dep_lines=()  # Array to store full depends on lines
    local config_name="${config_flag#CONFIG_}"
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*config[[:space:]]+$config_name([[:space:]]|$) ]]; then
            in_block=true
        elif [[ "$in_block" = true && "$line" =~ ^[[:space:]]*config[[:space:]]+ ]]; then
            break
        elif [[ "$in_block" = true ]]; then
            if [[ "$line" =~ ^[[:space:]]*(bool|tristate|string|int|hex)[[:space:]]*\"([^\"]*)\" ]]; then
                config_type="${BASH_REMATCH[1]}"
                description="${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^[[:space:]]*(bool|tristate|string|int|hex)[[:space:]]*$ ]]; then
                config_type="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*default[[:space:]]+([^[:space:]]+) ]]; then
                default_value="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*depends[[:space:]]+on[[:space:]]+(.+) ]]; then
                dep_lines+=("$line")  # Store the full line including "depends on"
            fi
        fi
    done < "$kconfig_file"

    # Determine type and possible values
    if [[ -z "$config_type" ]]; then
        echo "  Type: Unknown (not explicitly defined in Kconfig)"
    else
        echo "  Type: $config_type${description:+ \"$description\"}"
        case "$config_type" in
            "bool")
                echo "  Possible values: y (enabled), n (disabled)"
                ;;
            "tristate")
                echo "  Possible values: y (built-in), m (module), n (disabled)"
                ;;
            "string")
                echo "  Possible values: Any string (default: ${default_value:-empty})"
                ;;
            "int")
                echo "  Possible values: Any integer (default: ${default_value:-0})"
                ;;
            "hex")
                echo "  Possible values: Any hexadecimal value (default: ${default_value:-0x0})"
                ;;
            *)
                echo "  Possible values: Unknown type-specific values"
                ;;
        esac
    fi

    # Show default value if found
    if [[ -n "$default_value" ]]; then
        echo "  Default value: $default_value"
    fi

    # Analyze dependencies
    if [ ${#dep_lines[@]} -eq 0 ]; then
        echo "  Dependencies: None explicitly defined"
    else
        echo "  Dependencies:"
        for dep_line in "${dep_lines[@]}"; do
            # Extract the expression after "depends on" to check if it's simple or complex
            if [[ "$dep_line" =~ ^[[:space:]]*depends[[:space:]]+on[[:space:]]+([A-Za-z0-9_]+)$ ]]; then
                local dep_flag="CONFIG_${BASH_REMATCH[1]}"
                echo "    $dep_flag"
                if grep -q "^$dep_flag=y" "$KERNEL_URI/.config"; then
                    echo "      Status: Built-in (y)"
                elif grep -q "^$dep_flag=m" "$KERNEL_URI/.config"; then
                    echo "      Status: External module (m)"
                elif grep -q "^#$dep_flag is not set" "$KERNEL_URI/.config"; then
                    echo "      Status: Not set (n)"
                else
                    echo "      Status: Unknown (not found in .config)"
                fi
            else
                # Complex expression, show the full line as is
                echo "    $dep_line"
            fi
        done
    fi
}

# Check for help flag or incorrect number of arguments
if [ "$#" -eq 1 ] && [ "$1" = "-h" ]; then
    usage
    exit 0
elif [ "$#" -ne 1 ]; then
    echo "Error: Exactly one argument required"
    usage
    exit 1
fi

# Sanitize and standardize input (strict alphanumeric + underscore check)
input_flag="${1//[^[:alnum:]_]/}"
if [[ -z "$input_flag" ]]; then
    echo "Error: Invalid input. Only alphanumeric characters and underscores are allowed."
    exit 1
fi

# Ensure it follows kernel config flag naming convention
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
# Looks for lines containing $(CONFIG_FLAG) in Makefiles under KERNEL_URI
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # Case 1: Module flag pattern
    # Matches: obj-$(CONFIG_HID_LOGITECH) += hid-logitech.o
    # Indicates a standalone kernel module controlled by the flag
    if [[ "$content" =~ ^obj-\$\("$config_flag"\)[[:space:]]*\+=[[:space:]]*([^[:space:]]+)\.o ]]; then
        module_name="${BASH_REMATCH[1]}"
        directory="$(dirname "$file")"
        rel_dir="${directory#"$KERNEL_URI"/}"
        echo "Module flag: $config_flag"
        echo "Module name: $module_name"
        echo "Module path: $rel_dir/$module_name.ko"
        found=true
        break

    # Case 2: Feature flag pattern
    # Matches: hid-logitech-$(CONFIG_LOGITECH_FF) += hid-lgff.o
    # Indicates a feature within a larger module controlled by the flag
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
    # Search for exact config flag assignment (e.g., CONFIG_FLAG=y)
    grep "^$config_flag=" "$config_file" || echo "$config_flag cannot be found"

    # Determine module type
    if [[ "$content" =~ ^obj-\$\("$config_flag"\) ]]; then
        echo "Module type: Standalone module"
    else
        echo "Module type: Feature flag within $module_name"
    fi

    # Analyze type, possible values, description, and dependencies
    analyze_kconfig "$config_flag" "$directory"
elif [ -z "$input_flag" ]; then
    echo "Error: Empty input provided"  # Redundant due to earlier check, kept for clarity
    exit 1
else
    echo "Error: No module found for $config_flag in $KERNEL_URI"
    exit 1
fi
