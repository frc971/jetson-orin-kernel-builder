#!/bin/bash

# Default kernel source path (can be overridden by environment variable)
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Function to search for 'winchiphead' and identify its config block
search_kconfig() {
    echo "Searching for 'winchiphead' in Kconfig files under $KERNEL_URI..."

    # Verify the directory exists
    if [ ! -d "$KERNEL_URI" ]; then
        echo "Error: Directory $KERNEL_URI does not exist or is inaccessible"
        exit 1
    fi

    # Find all Kconfig files
    echo "Gathering Kconfig files..."
    local kconfig_files
    mapfile -t kconfig_files < <(find "$KERNEL_URI" -name Kconfig -type f 2>/dev/null)
    if [ ${#kconfig_files[@]} -eq 0 ]; then
        echo "  No Kconfig files found in $KERNEL_URI"
        exit 1
    fi
    echo "  Found ${#kconfig_files[@]} Kconfig files"
    echo

    # Process each Kconfig file
    echo "Searching for matches:"
    local found=false
    for file in "${kconfig_files[@]}"; do
        # Skip files without 'winchiphead'
        if ! grep -i "winchiphead" "$file" >/dev/null 2>&1; then
            continue
        fi

        echo "  File: $file"
        # Read the file line by line
        local config_name=""
        while IFS= read -r line; do
            # Check for a new config block
            if [[ "$line" =~ ^[[:space:]]*config[[:space:]]+([A-Za-z0-9_]+) ]]; then
                config_name="${BASH_REMATCH[1]}"
                echo "    Started config block: CONFIG_$config_name"
            fi
            # Check for the search term
            if echo "$line" | grep -i "winchiphead" >/dev/null 2>&1; then
                if [ -n "$config_name" ]; then
                    echo "    Found 'winchiphead' in line: $line"
                    echo "    Associated config: CONFIG_$config_name"
                    echo
                    found=true
                else
                    echo "    Found 'winchiphead' in line: $line"
                    echo "    Warning: No config block active"
                fi
            fi
        done < "$file"
    done

    if [ "$found" = false ]; then
        echo "  No matches found for 'winchiphead' with an associated config"
    fi
}

# Execute the search
search_kconfig
