#!/bin/bash
# Build the Linux Kernel on NVIDIA Jetson Developer Kit
# Copyright (c) 2016-25 Jetsonhacks 
# MIT License

SOURCE_TARGET="/usr/src"

function usage {
    echo "usage: ./buildKernel.sh [[-d directory ]  | [-h]]"
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

# Navigate to kernel source directory
cd "$MAKE_DIRECTORY" || exit 1

echo "Building kernel in: $MAKE_DIRECTORY"

# Create logs directory if it does not exist
LOGS_DIR="$MAKE_DIRECTORY/logs"
mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/kernel_build.log"

# Get the number of CPUs and determine job count
NUM_CPU=$(nproc)
JOBS=$((NUM_CPU > 1 ? NUM_CPU - 1 : 1))

if ! sudo time make -j$JOBS Image 2>&1 | tee "$LOG_FILE"; then
    echo "Make failed. Retrying with single-threaded build..."
    if ! sudo make Image 2>&1 | tee -a "$LOG_FILE"; then
        echo "Make failed again. Check $LOG_FILE for details." >&2
        echo "Possible causes: missing dependencies, out-of-memory errors, or incorrect kernel configuration."
        exit 1
    fi
fi

echo "Kernel Image is located at: $MAKE_DIRECTORY/arch/arm64/boot/Image"
echo "Build logs are saved in: $LOG_FILE"
