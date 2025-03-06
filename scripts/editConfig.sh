#!/bin/bash
# Edit the kernel configuration for NVIDIA Jetson Developer Kit 
# Copyright (c) 2016-25 JetsonHacks 
# MIT License

SOURCE_TARGET="/usr/src"
KERNEL_RELEASE=$(uname -r | cut -d. -f1-2) # e.g. 4.9

function usage {
    echo "usage: ./editConfig.sh [[-d directory ] | [-h]]"
    echo "-d | --directory Directory path to parent of kernel"
    echo "-h | --help  This message"
}

# Parse command-line options
while [ "$1" != "" ]; do
    case $1 in
        -d | --directory ) shift
                           SOURCE_TARGET=$1
                           ;;
        -h | --help )      usage
                           exit 0
                           ;;
        * )                usage
                           exit 1
    esac
    shift
done

# Ensure directory path has a trailing slash
if [[ "${SOURCE_TARGET: -1}" != "/" ]]; then
   SOURCE_TARGET="${SOURCE_TARGET}/"
fi

# Check for libncurses5-dev
if ! dpkg -s libncurses5-dev &> /dev/null; then
    echo "[WARNING] 'libncurses5-dev' is not installed. It is required for 'menuconfig'."
    read -rp "Would you like to install it now? (Y/N): " INSTALL_CHOICE
    case "$INSTALL_CHOICE" in
        [Yy]* )
            echo "Installing 'libncurses5-dev'..."
            sudo apt-get update && sudo apt-get install -y libncurses5-dev
            ;;
        [Nn]* )
            echo "[ERROR] 'libncurses5-dev' is required. Exiting."
            exit 1
            ;;
        * )
            echo "[ERROR] Invalid choice. Please enter Y or N."
            exit 1
            ;;
    esac
fi

# Verify that kernel source exists
PROPOSED_SRC_PATH="${SOURCE_TARGET}kernel/kernel-jammy-src"
echo "Proposed source path: ${PROPOSED_SRC_PATH}"

if [[ ! -d "$PROPOSED_SRC_PATH" ]]; then
  tput setaf 1
  echo "==== Cannot find kernel source! =============== "
  tput sgr0
  echo "The kernel source does not appear to be installed at: "
  echo "   ${PROPOSED_SRC_PATH}"
  echo "Unable to edit kernel configuration."
  exit 1
fi

# Enter kernel source directory and launch menuconfig
cd "$PROPOSED_SRC_PATH"
sudo make menuconfig
