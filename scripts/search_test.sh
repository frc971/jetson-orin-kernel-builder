#!/bin/bash

# CLI to search for 'winchiphead' in Kconfig files and debug config block parsing
# For debugging purposes

# Default kernel source path, can be overridden by environment variable
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Function to search for 'winchiphead' in Kconfig files and parse config blocks
search_kconfig() {
    echo "Searching for 'winchiphead' (case-insensitive) in Kconfig files under $KERNEL_URI..."
    echo

    # Check if KERNEL_URI exists
    if [ ! -d "$KERNEL_URI" ]; then
        echo "Error: Directory $KERNEL_URI does not exist or is inaccessible"
        exit 1
    fi

    # Gather all Kconfig files
    echo "Gathering Kconfig files..."
    local kconfig_files
    mapfile -t kconfig_files < <(find "$KERNEL_URI" -name Kconfig -type f 2>/dev/null)
    if [ ${#kconfig_files[@]} -eq 0 ]; then
        echo "  No Kconfig files found in $KERNEL_URI (check permissions or path)"
        exit 1
    else
        echo "  Found ${#kconfig_files[@]} Kconfig files"
    fi
    echo

    # Search and parse Kconfig files
    echo "Matches in Kconfig files:"
    local found=false
    for file in "${kconfig_files[@]}"; do
        # Check if 'winchiphead' exists in this file
        if grep -i "winchiphead" "$file" >/dev/null 2>&1; then
            echo "  File: $file"
            echo "  Parsing lines:"
            # Read the file into an array to parse config blocks
            mapfile -t lines < "$file"
            local config_name=""
            local last_config_line=-1
            for ((i = 0; i < ${#lines[@]}; i++)); do
                # Show every line with context
                echo "    Line $((i+1)): ${lines[$i]}"
                # Identify config lines
                if [[ "${lines[$i]}" =~ ^[[:space:]]*config[[:space:]]+([A-Za-z0-9_]+) ]]; then
                    # If we already had a config_name and this is a new config, reset it first
                    if [ -n "$config_name" ] && [ "$last_config_line" -ne "$i" ]; then
                        echo "    -> Reset config_name (new config block started)"
                        config_name=""
                    fi
                    config_name="${BASH_REMATCH[1]}"
                    echo "    -> Set config_name to: CONFIG_$config_name"
                    last_config_line="$i"
                fi
                # Case-insensitive match for 'winchiphead'
                if echo "${lines[$i]}" | grep -i "winchiphead" >/dev/null 2>&1; then
                    echo "    -> FOUND 'winchiphead' in this line"
                    if [ -n "$config_name" ]; then
                        echo "    Match: ${lines[$i]}"
                        echo "    Config: CONFIG_$config_name"
                        echo
                        found=true
                    else
                        echo "    -> No config_name set yet for this match"
                    fi
                fi
            done
            echo
        fi
    done
    if [ "$found" = false ]; then
        echo "  No configurations found for 'winchiphead' (check parsing logic or file content)"
    fi
}

# Run the search
search_kconfig
