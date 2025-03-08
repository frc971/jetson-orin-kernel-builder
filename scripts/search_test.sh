#!/bin/bash

# CLI to search for 'winchiphead' in Kconfig files and identify the corresponding config block
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

    # Search Kconfig files
    echo "Matches in Kconfig files:"
    local found=false
    find "$KERNEL_URI" -name Kconfig -type f 2>/dev/null | while IFS= read -r file; do
        # Read the entire file into an array to parse blocks
        mapfile -t lines < "$file"
        local config_name=""
        for ((i = 0; i < ${#lines[@]}; i++)); do
            # Look for config lines to set the current block
            if [[ "${lines[$i]}" =~ ^[[:space:]]*config[[:space:]]+([A-Za-z0-9_]+) ]]; then
                config_name="${BASH_REMATCH[1]}"
            fi
            # Check for 'winchiphead' in the current line
            if [[ "${lines[$i]}" =~ [Ww][Ii][Nn][Cc][Hh][Ii][Pp][Hh][Ee][Aa][Dd] ]]; then
                # If we have a config name from earlier in the block, use it
                if [ -n "$config_name" ]; then
                    echo "  File: $file"
                    echo "  Line: ${lines[$i]}"
                    echo "  Config: CONFIG_$config_name"
                    echo
                    found=true
                fi
            fi
            # Reset config_name if we hit a new block (e.g., another config or end of block)
            if [[ "${lines[$i]}" =~ ^[[:space:]]*config[[:space:]]+ ]] && [ "$i" -gt 0 ]; then
                config_name=""
            fi
        done
    done
    if [ "$found" = false ]; then
        echo "  No matches found or error occurred (check permissions, path, or kernel version)"
    fi
}

# Run the search
search_kconfig
