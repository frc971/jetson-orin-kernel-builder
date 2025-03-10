#!/bin/bash
# Linux Kernel Build Script for NVIDIA Jetson Developer Kit
# This script automates the process of building the Linux kernel for the NVIDIA Jetson Developer Kit.
# It verifies the kernel source directory, removes old kernel images, compiles the kernel using 
# optimal CPU usage, and logs the build process. If the build fails, it retries with a single-threaded build.
#
# Usage:
#   ./make_kernel.sh [[-d directory ] | [-h]]
#
# Options:
#   -d | --directory  Specify the kernel source directory (default: /usr/src)
#   -h | --help       Display this help message
#
# Example:
#   ./make_kernel.sh                # Build kernel using the default source directory
#   ./make_kernel.sh -d /custom/path # Build kernel using a custom source path
#
# Logs are saved in a 'logs' directory within the script's execution path.
#
# Copyright (c) 2016-25 JetsonHacks
# MIT License

SOURCE_TARGET="/usr/src"

function usage {
    echo "usage: ./make_kernel.sh [[-d directory ]  | [-h]]"
    echo "-d | --directory  Directory path to parent of kernel source"
    echo "-h | --help       Show this help message"
}

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        -d | --directory ) shift
            SOURCE_TARGET=$1
            ;;
        -h | --help )
            usage
            exit
            ;;
        * )
            usage
            exit 1
    esac
    shift
done

# Ensure SOURCE_TARGET ends with a slash
[[ "${SOURCE_TARGET}" != */ ]] && SOURCE_TARGET+="/"

# Check for kernel source directory
MAKE_DIRECTORY="${SOURCE_TARGET}kernel/kernel-jammy-src"
echo "Proposed source path: $MAKE_DIRECTORY"

if [ ! -d "$MAKE_DIRECTORY" ]; then
    tput setaf 1
    echo "==== Cannot find kernel source! ===="
    tput sgr0
    echo "Expected at: $MAKE_DIRECTORY"
    echo "Please install the kernel source and retry."
    exit 1
fi

# Ensure logs directory exists with appropriate permissions
LOGS_DIR="$(pwd)/logs"
mkdir -p "$LOGS_DIR"

LOG_FILE="$LOGS_DIR/kernel_build.log"

# Navigate to kernel source directory
cd "$MAKE_DIRECTORY" || exit 1

echo "Building kernel in: $MAKE_DIRECTORY"

# Remove any existing Image file to ensure a fresh build
IMAGE_FILE="$MAKE_DIRECTORY/arch/arm64/boot/Image"
if [ -f "$IMAGE_FILE" ]; then
    echo "Removing old kernel Image file..."
    sudo rm -f "$IMAGE_FILE"
fi

# Get the number of CPUs and determine job count
NUM_CPU=$(nproc)
JOBS=$((NUM_CPU > 1 ? NUM_CPU - 1 : 1))

if ! sudo bash -c "time make -j$JOBS Image 2>&1 | tee $LOG_FILE"; then
    echo "Make failed. Retrying with single-threaded build..."
    if ! sudo bash -c "make Image 2>&1 | tee -a $LOG_FILE"; then
        echo "Make failed again. Check $LOG_FILE for details." >&2
        echo "Possible causes: missing dependencies, out-of-memory errors, or incorrect kernel configuration."
        exit 1
    fi
fi

if [ -f "$MAKE_DIRECTORY/arch/arm64/boot/Image" ]; then
    echo "Kernel Image is located at: $MAKE_DIRECTORY/arch/arm64/boot/Image"
else
    echo "Kernel Image was not generated. Check $LOG_FILE for details."
    exit 1
fi
echo "Build logs are saved in: $LOG_FILE"
