#!/bin/bash

# Function to check for Qt5 libraries
check_qt_libraries() {
    pkg-config --exists Qt5Core Qt5Gui Qt5Widgets
}

# Check if Qt libraries are installed
if ! check_qt_libraries; then
    echo "The required Qt5 development libraries (Qt5Core, Qt5Gui, Qt5Widgets) are not installed."
    echo "These libraries are necessary to run the graphical kernel configuration editor (make xconfig)."
    echo
    echo "You have two installation options:"
    echo "1. qtbase5-dev: The standard Qt5 development package, suitable for most systems with full OpenGL support."
    echo "2. qtbase5-gles-dev: The Qt5 development package optimized for systems with OpenGL ES, such as embedded devices (e.g., NVIDIA Jetson Orin Nano)."
    echo
    echo "If you’re unsure which to choose, we recommend the standard version (qtbase5-dev)."
    echo
    echo "Please select an option:"
    echo "1) Install qtbase5-dev (default)"
    echo "2) Install qtbase5-gles-dev"
    echo "3) Skip installation and exit"
    read -p "Enter your choice (1-3): " choice

    case $choice in
        1)
            echo "Installing qtbase5-dev and pkg-config..."
            sudo apt-get update
            sudo apt-get install -y qtbase5-dev pkg-config
            ;;
        2)
            echo "Installing qtbase5-gles-dev and pkg-config..."
            sudo apt-get update
            sudo apt-get install -y qtbase5-gles-dev pkg-config
            ;;
        3)
            echo "Skipping installation. Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Defaulting to installing qtbase5-dev."
            sudo apt-get update
            sudo apt-get install -y qtbase5-dev pkg-config
            ;;
    esac

    # Verify the libraries are now available
    if ! check_qt_libraries; then
        echo "Error: Qt5 libraries still not found after installation."
        echo "Please check your package manager or install the libraries manually."
        exit 1
    fi
fi

# Proceed with the original task (e.g., running make xconfig)
echo "Qt libraries found. Proceeding with make xconfig..."
make xconfig
