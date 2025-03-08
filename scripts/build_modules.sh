#!/bin/bash
# Script to compile loadable kernel modules for NVIDIA Jetson Developer Kit
# Supports internal (loadable) and external modules; built-in modules excluded
# Usage: ./build_modules.sh [-f module_file] [module_path1 module_path2 ...]
# Copyright (c) 2025, MIT License

# Default kernel source location
SOURCE_TARGET="/usr/src/kernel/kernel-jammy-src"
KERNEL_URI="${SOURCE_TARGET}"
INSTALL_DIRECTORY="/lib/modules/$(uname -r)/kernel"
STAGING_DIR="$(dirname "$0")/staging"

# Function to display usage
usage() {
    echo "Usage: $0 [-f module_file] [module_path1 module_path2 ...]"
    echo "  -f: File listing modules (format: module_path config_option value)"
    echo "  Example file content:"
    echo "    drivers/usb/serial/ CONFIG_USB_SERIAL_CH341 m"
    exit 1
}

# Check if kernel source exists
check_kernel_source() {
    if [ ! -d "$KERNEL_URI" ]; then
        echo "Error: Kernel source not found at $KERNEL_URI."
        exit 1
    fi
}

# Prepare kernel source
prepare_kernel() {
    cd "$KERNEL_URI" || exit 1
    sudo make modules_prepare || { echo "Error: Failed to prepare kernel."; exit 1; }
}

# Build a module and stage it
build_module() {
    local module_path="$1"  # e.g., drivers/usb/serial/
    local config_option="$2" # e.g., CONFIG_USB_SERIAL_CH341
    local config_value="$3"  # e.g., m
    local is_external=0

    # Detect external module
    if [[ ! "$module_path" =~ ^drivers/|^sound/|^net/|^$ ]]; then
        is_external=1
        local module_dir="$module_path"
        echo "Building external module from: $module_dir"
    else
        local module_dir="${KERNEL_URI}/${module_path}"
    fi

    # Validate config value
    if [ -n "$config_value" ] && [ "$config_value" != "m" ]; then
        echo "Error: Only loadable modules (m) are supported."
        exit 1
    fi

    mkdir -p "$STAGING_DIR"

    if [ $is_external -eq 0 ]; then
        # Internal module
        cd "$KERNEL_URI" || exit 1
        if [ -n "$config_option" ]; then
            sudo bash scripts/config --file .config --set-val "$config_option" "m"
        fi
        sudo make "$module_path" || { echo "Error: Build failed."; exit 1; }

        local ko_file=$(find "$module_dir" -name "*.ko" -newer "$KERNEL_URI/.config" | head -n 1)
        if [ -n "$ko_file" ] && [ -f "$ko_file" ]; then
            local module_file=$(basename "$ko_file")
            cp "$ko_file" "$STAGING_DIR/$module_file"
            echo "Staged: $STAGING_DIR/$module_file"
            local rel_ko_file="${ko_file#${KERNEL_URI}/}"
            local module_dir=$(dirname "$rel_ko_file")
            MODULES_DICT["$module_file"]="$module_dir"
        else
            echo "Warning: No .ko file found for $module_path."
        fi
    else
        # External module
        cd "$module_dir" || { echo "Error: Directory $module_dir not found."; exit 1; }
        sudo make -C "$KERNEL_URI" M="$(pwd)" modules || { echo "Error: Build failed."; exit 1; }
        find . -name "*.ko" -exec cp {} "$STAGING_DIR/" \;
        for ko_file in "$STAGING_DIR"/*.ko; do
            if [ -f "$ko_file" ]; then
                local module_file=$(basename "$ko_file")
                MODULES_DICT["$module_file"]="extra/"
                echo "Staged: $STAGING_DIR/$module_file"
            fi
        done
    fi
}

# Install modules
install_modules() {
    for module_file in "$STAGING_DIR"/*.ko; do
        if [ -f "$module_file" ]; then
            local module_name=$(basename "$module_file")
            local target_dir="${INSTALL_DIRECTORY}/${MODULES_DICT[$module_name]}"
            sudo mkdir -p "$target_dir"
            sudo cp -v "$module_file" "$target_dir"
        fi
    done
    sudo depmod -a
    echo "Modules installed."
}

# Prompt for installation
prompt_install() {
    echo "Modules staged in: $STAGING_DIR"
    echo "Install now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        install_modules
    else
        echo "Modules remain in $STAGING_DIR. To install manually:"
        for module_file in "$STAGING_DIR"/*.ko; do
            if [ -f "$module_file" ]; then
                local module_name=$(basename "$module_file")
                local target_dir="${INSTALL_DIRECTORY}/${MODULES_DICT[$module_name]}"
                echo "  sudo mkdir -p \"$target_dir\""
                echo "  sudo cp -v \"$module_file\" \"$target_dir\""
            fi
        done
        echo "  sudo depmod -a"
    fi
}

# Main logic
MODULE_FILE=""
MODULES=()
declare -A MODULES_DICT

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f) MODULE_FILE="$2"; shift 2 ;;
        *) MODULES+=("$1"); shift ;;
    esac
done

if [ -n "$MODULE_FILE" ] && [ ${#MODULES[@]} -gt 0 ]; then
    echo "Error: Use -f or arguments, not both."
    usage
elif [ -z "$MODULE_FILE" ] && [ ${#MODULES[@]} -eq 0 ]; then
    echo "Error: No modules specified."
    usage
fi

check_kernel_source
prepare_kernel

if [ -n "$MODULE_FILE" ]; then
    if [ ! -f "$MODULE_FILE" ]; then
        echo "Error: File $MODULE_FILE not found."
        exit 1
    fi
    while read -r module_path config_option config_value; do
        [[ -z "$module_path" || "$module_path" =~ ^# ]] && continue
        build_module "$module_path" "$config_option" "$config_value"
    done < "$MODULE_FILE"
else
    for module_path in "${MODULES[@]}"; do
        build_module "$module_path" "" ""
    done
fi

prompt_install
