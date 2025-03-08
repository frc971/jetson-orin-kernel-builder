#!/bin/bash

# Ultra-simple CLI to search for 'winchiphead' in Kconfig files
# For debugging purposes

# Default kernel source path, can be overridden by environment variable
KERNEL_URI="${KERNEL_URI:-/usr/src/kernel/kernel-jammy-src}"

# Function to search for 'winchiphead' in Kconfig files
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
        if grep -i "winchiphead" "$file" >/dev/null 2>&1; then
            grep -iH "winchiphead" "$file" | while IFS=: read -r filepath content; do
                echo "  File: $filepath"
                echo "  Line: $content"
                if [[ "$content" =~ ^[[:space:]]*config[[:space:]]+([A-Za-z0-9_]+) ]]; then
                    echo "  Config: CONFIG_${BASH_REMATCH[1]}"
                fi
                echo
                found=true
            done
        fi
    done
    if [ "$found" = false ]; then
        echo "  No matches found or error occurred (check permissions or path)"
    fi
}

# Run the search
search_kconfig
