#!/bin/bash
# Script to compile loadable kernel modules for NVIDIA Jetson Developer Kit
# Supports internal (loadable) and external modules; built-in modules excluded
# Usage: ./build_modules.sh [-f module_file] [module_path1 module_path2 ...]
# Copyright (c) 2025, MIT License

# Store the original working directory
ORIGINAL_DIR=$(pwd)
# Get the absolute path of the script's directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# Set STAGING_DIR as an absolute path based on the script's directory
STAGING_DIR="$SCRIPT_DIR/staging"
# Default kernel source location
SOURCE_TARGET="/usr/src/kernel/kernel-jammy-src"
KERNEL_URI="${SOURCE_TARGET}"
INSTALL_DIRECTORY="/lib/modules/$(uname -r)/kernel"

# Function to display usage
usage() {
    echo "Usage: $0 [-f module_file] [module_path1 module_path2 ...]"
    echo "  -f: Specify a file listing modules (format: module_path config_option value)"
    echo "  Example file content:"
    echo "    drivers/hid/ LOGITECH_FF m    # Directory hint + config option (loadable)"
    echo "    drivers/hid/hid-logitech.ko   # Exact path (no config needed)"
    echo "    /path/to/external/ MY_MODULE m  # External module"
    echo "  If no file, pass module paths as arguments."
    echo "  Note: Only loadable modules (CONFIG_XXX=m) are supported."
    exit 1
}

# Check if kernel source exists
check_kernel_source() {
    if [ ! -d "$KERNEL_URI" ]; then
        echo "Error: Cannot find kernel source in $KERNEL_URI."
        echo "Please install the kernel source (e.g., sudo apt-get install linux-source-${KERNEL_RELEASE})."
        exit 1
    fi
}

# Prepare kernel source for module compilation
prepare_kernel() {
    cd "$KERNEL_URI" || exit 1
    sudo make modules_prepare || {
        echo "Error: Failed to prepare kernel source."
        exit 1
    }
}

# Build a loadable module and detect the .ko file
build_module() {
    local module_path="$1"  # Directory hint or exact path
    local config_option="$2"
    local config_value="$3"
    local is_external=0

    # Check if the module is external
    if [[ ! "$module_path" =~ ^drivers/|^sound/|^net/|^$ ]]; then
        is_external=1
        if [ "${module_path:0:1}" != "/" ]; then
            module_path="$ORIGINAL_DIR/$module_path"
        fi
        local module_dir="$module_path"
        echo "Detected external module directory: $module_dir"
    else
        local module_dir="${KERNEL_URI}/${module_path}"
    fi

    # Validate config value (must be 'm' or empty)
    if [ -n "$config_value" ] && [ "$config_value" != "m" ]; then
        echo "Error: Config value '$config_value' not supported. Only loadable modules (m) are allowed."
        echo "For built-in modules (y), use a full kernel build process instead."
        exit 1
    fi

    # Create staging directory using absolute path
    mkdir -p "$STAGING_DIR"

    if [ $is_external -eq 0 ]; then
        # Internal loadable module
        cd "$KERNEL_URI" || exit 1

        if [ -z "$module_path" ] && [ -n "$config_option" ]; then
            echo "Error: Directory hint required when using config option $config_option."
            echo "Please specify a directory (e.g., drivers/hid/) in the input."
            exit 1
        fi

        if [ -n "$config_option" ]; then
            sudo bash scripts/config --file .config --set-val "$config_option" "m"
        fi

        # Build the module (corrected line)
        sudo make M="$module_path" modules || {
            echo "Error: Failed to build in $module_path."
            exit 1
        }

        # Detect the .ko file
        local ko_file
        if [[ "$module_path" =~ \.ko$ ]]; then
            ko_file="${KERNEL_URI}/${module_path}"
        else
            ko_file=$(find "$module_dir" -name "*.ko" -newer "$KERNEL_URI/.config" | head -n 1)
        fi

        if [ -n "$ko_file" ] && [ -f "$ko_file" ]; then
            local module_file=$(basename "$ko_file")
            cp "$ko_file" "$STAGING_DIR/$module_file"
            echo "Staged: ${STAGING_DIR}/${module_file}"
            local rel_ko_file="${ko_file#${KERNEL_URI}/}"
            local module_dir_rel=$(dirname "$rel_ko_file")
            MODULES_DICT["$module_file"]="$module_dir_rel"
        else
            echo "Warning: No .ko file found for $config_option in $module_path."
            echo "Ensure $config_option is set to 'm' in .config and produces a loadable module."
        fi
    else
        # External loadable module
        cd "$module_dir" || {
            echo "Error: Cannot access external module directory $module_dir."
            exit 1
        }
        sudo make -C "$KERNEL_URI" M="$(pwd)" modules || {
            echo "Error: Failed to build external module in $module_dir."
            exit 1
        }
        find . -name "*.ko" -exec cp {} "$STAGING_DIR/" \;
        for ko_file in "$STAGING_DIR"/*.ko; do
            if [ -f "$ko_file" ]; then
                local module_file=$(basename "$ko_file")
                MODULES_DICT["$module_file"]="extra/"
                echo "Staged external module: $STAGING_DIR/$module_file"
            fi
        done
    fi
}

# Install staged modules
install_modules() {
    for module_file in "$STAGING_DIR"/*.ko; do
        if [ -f "$module_file" ]; then
            local module_name=$(basename "$module_file")
            local target_dir="${INSTALL_DIRECTORY}/${MODULES_DICT[$module_name]}"
            sudo mkdir -p "$target_dir"
            sudo cp -v "$module_file" "$target_dir"
            echo "Installed: $module_file to $target_dir"
        fi
    done
    sudo depmod -a
    echo "Module dependencies updated."
}

# Prompt user for installation
prompt_install() {
    echo "Modules have been staged in: $STAGING_DIR"
    echo "Would you like to install them now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        install_modules
        echo "Installation complete. You may need to reboot for changes to take effect."
    else
        echo "Modules remain in $STAGING_DIR. To install manually later:"
        for module_file in "$STAGING_DIR"/*.ko; do
            if [ -f "$module_file" ]; then
                local module_name=$(basename "$module_file")
                local target_dir="${INSTALL_DIRECTORY}/${MODULES_DICT[$module_name]}"
                echo "  sudo mkdir -p '$target_dir'"
                echo "  sudo cp -v '$module_file' '$target_dir'"
            fi
        done
        echo "  sudo depmod -a"
        echo "You may need to reboot after installation."
    fi
}

# Main logic
MODULE_FILE=""
MODULES=()
declare -A MODULES_DICT # Associative array to store module paths

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
            MODULE_FILE="$2"
            if [ "${MODULE_FILE:0:1}" != "/" ]; then
                MODULE_FILE="$ORIGINAL_DIR/$MODULE_FILE"
            fi
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            MODULES+=("$1")
            shift
            ;;
    esac
done

# Check for module input
if [ -n "$MODULE_FILE" ] && [ ${#MODULES[@]} -gt 0 ]; then
    echo "Error: Use either -f <file> or module arguments, not both."
    usage
elif [ -z "$MODULE_FILE" ] && [ ${#MODULES[@]} -eq 0 ]; then
    echo "Error: No modules specified."
    usage
fi

check_kernel_source
prepare_kernel

# Process modules from file
if [ -n "$MODULE_FILE" ]; then
    if [ ! -f "$MODULE_FILE" ]; then
        echo "Error: Module file $MODULE_FILE not found."
        exit 1
    fi
    while read -r module_path config_option config_value; do
        [[ -z "$module_path" || "$module_path" =~ ^# ]] && continue # Skip empty or commented lines
        build_module "$module_path" "$config_option" "$config_value"
    done < "$MODULE_FILE"
else
    # Process modules from command-line arguments
    for module_path in "${MODULES[@]}"; do
        build_module "$module_path" "" "" # No config options via CLI
    done
fi

echo "Build complete."
prompt_install
