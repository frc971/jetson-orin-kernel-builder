#!/bin/bash

# Script to find information about kernel module flags, their dependencies, and configuration types.
# Helps inexperienced users understand module/feature flags, their status, types, and dependencies.
# Supports searching for related strings with -s flag.

# Default kernel source path, can be overridden by environment variable
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Display usage information
usage() {
    echo "Usage: $0 [-h] [-s <search_string>] <module_flag>"
    echo "Examples:"
    echo "  $0 LOGITECH_FF              # Exact config lookup"
    echo "  $0 CONFIG_LOGITECH_FF       # Exact config lookup with prefix"
    echo "  $0 -s winchiphead           # Search for related configs"
    echo "Options:"
    echo "  -h    Display this help message"
    echo "  -s    Search for a string in Makefiles, Kconfig, and .config (case-insensitive)"
}

# Function to analyze type, possible values, description, dependencies, and selects from Kconfig
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
    local -a select_lines=()  # Array to store full select lines
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
                dep_lines+=("$line")
            elif [[ "$line" =~ ^[[:space:]]*select[[:space:]]+(.+) ]]; then
                select_lines+=("$line")
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
                echo "    $dep_line"
            fi
        done
    fi

    # Analyze selects
    if [ ${#select_lines[@]} -eq 0 ]; then
        echo "  Selects: None explicitly defined"
    else
        echo "  Selects:"
        for select_line in "${select_lines[@]}"; do
            if [[ "$select_line" =~ ^[[:space:]]*select[[:space:]]+([A-Za-z0-9_]+)$ ]]; then
                local select_flag="CONFIG_${BASH_REMATCH[1]}"
                echo "    $select_flag"
                if grep -q "^$select_flag=y" "$KERNEL_URI/.config"; then
                    echo "      Status: Built-in (y)"
                elif grep -q "^$select_flag=m" "$KERNEL_URI/.config"; then
                    echo "      Status: External module (m)"
                elif grep -q "^#$select_flag is not set" "$KERNEL_URI/.config"; then
                    echo "      Status: Not set (n)"
                else
                    echo "      Status: Unknown (not found in .config)"
                fi
            else
                echo "    $select_line"
            fi
        done
    fi
}

# Function to search for a string in Makefiles, Kconfig, and .config
search_configs() {
    local search_string="$1"

    echo "Searching for '$search_string' (case-insensitive) in $KERNEL_URI..."
    echo

    # Search Makefiles
    echo "Matches in Makefiles:"
    local makefile_results=$(find "$KERNEL_URI" -name Makefile -exec grep -iH "$search_string" {} + 2>/dev/null)
    if [ -n "$makefile_results" ]; then
        while IFS= read -r line; do
            local file=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)
            # Extract CONFIG_ symbols if present
            if [[ "$content" =~ (CONFIG_[A-Za-z0-9_]+) ]]; then
                echo "  File: $file"
                echo "  Line: $content"
                echo "  Config: ${BASH_REMATCH[1]}"
                echo
            fi
        done <<< "$makefile_results"
    else
        echo "  No matches found"
    fi
    echo

    # Search Kconfig files
    echo "Matches in Kconfig files:"
    local kconfig_results=$(find "$KERNEL_URI" -name Kconfig -exec grep -iH "$search_string" {} + 2>/dev/null)
    if [ -n "$kconfig_results" ]; then
        while IFS= read -r line; do
            local file=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)
            # Extract CONFIG_ symbols or config names
            if [[ "$content" =~ (CONFIG_[A-Za-z0-9_]+) ]] || [[ "$content" =~ ^[[:space:]]*config[[:space:]]+([A-Za-z0-9_]+) ]]; then
                local config_name="${BASH_REMATCH[1]:-CONFIG_${BASH_REMATCH[1]}}"
                echo "  File: $file"
                echo "  Line: $content"
                echo "  Config: $config_name"
                echo
            fi
        done <<< "$kconfig_results"
    else
        echo "  No matches found"
    fi
    echo

    # Search .config
    echo "Matches in .config:"
    local config_file="$KERNEL_URI/.config"
    if [ -f "$config_file" ]; then
        local config_results=$(grep -i "$search_string" "$config_file" 2>/dev/null)
        if [ -n "$config_results" ]; then
            while IFS= read -r line; do
                if [[ "$line" =~ (CONFIG_[A-Za-z0-9_]+)= ]]; then
                    echo "  Line: $line"
                    echo "  Config: ${BASH_REMATCH[1]}"
                    echo
                fi
            done <<< "$config_results"
        else
            echo "  No matches found"
        fi
    else
        echo "  .config file not found in $KERNEL_URI"
    fi
}

# Parse command-line arguments
search_mode=false
search_string=""
config_flag=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h)
            usage
            exit 0
            ;;
        -s)
            if [ $# -lt 2 ]; then
                echo "Error: -s requires a search string"
                usage
                exit 1
            fi
            search_mode=true
            search_string="$2"
            shift 2
            ;;
        *)
            if [ -n "$config_flag" ]; then
                echo "Error: Only one config flag allowed without -s"
                usage
                exit 1
            fi
            config_flag="$1"
            shift
            ;;
    esac
done

# Ensure kernel directory exists
if [ ! -d "$KERNEL_URI" ]; then
    echo "Error: Kernel source directory $KERNEL_URI not found"
    exit 1
fi

if [ "$search_mode" = true ]; then
    # Search mode
    if [ -z "$search_string" ]; then
        echo "Error: Search string cannot be empty"
        usage
        exit 1
    fi
    search_configs "$search_string"
    exit 0
fi

# Exact match mode
if [ -z "$config_flag" ]; then
    echo "Error: No module flag provided"
    usage
    exit 1
fi

# Sanitize and standardize input (strict alphanumeric + underscore check)
input_flag="${config_flag//[^[:alnum:]_]/}"
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

found=false

# Search Makefiles efficiently using find and grep
# Looks for lines containing $(CONFIG_FLAG) in Makefiles under KERNEL_URI
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # Case 1: Module flag pattern
    # Matches: obj-$(CONFIG_HID_LOGITECH) += hid-logitech.o
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

    # Analyze type, possible values, description, dependencies, and selects
    analyze_kconfig "$config_flag" "$directory"
elif [ -z "$input_flag" ]; then
    echo "Error: Empty input provided"  # Redundant due to earlier check, kept for clarity
    exit 1
else
    echo "Error: No module found for $config_flag in $KERNEL_URI"
    exit 1
fi
