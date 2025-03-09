# Kernel Source Setup Script Documentation

## Overview

This Bash script automates the process of downloading, extracting, and configuring the kernel source for NVIDIA Jetson devices running Linux for Tegra (L4T) version 36.X on Ubuntu 22.04 Jammy. It retrieves the kernel source, out-of-tree modules, and display driver source from NVIDIA's developer site, extracts them to `/usr/src/`, and configures them with the current kernel settings. The script also manages existing kernel sources based on user input or command-line flags, ensures necessary dependencies are installed, and logs all actions to a timestamped file for reference.

## Requirements

To run this script successfully, the following are required:

- **Operating System**: A Jetson device running Ubuntu 22.04 Jammy with Linux for Tegra (L4T) version 36.X.
- **Internet Access**: Required to download the kernel source files from NVIDIA's developer site.
- **Sudo Privileges**: Necessary for writing to `/usr/src/`, extracting files, and installing packages.
- **Utilities**: 
  - `wget`: For downloading the source file (typically pre-installed on Ubuntu).
  - `tar`: For extracting tarballs (typically pre-installed on Ubuntu).
- **Dependency**: 
  - `libssl-dev`: Required for kernel building; the script will install it if absent.
- **File Access**: Read access to `/etc/nv_tegra_release` for L4T version detection and `/proc/config.gz` for kernel configuration.

## Usage
```bash
./scripts/get_kernel_sources.sh [--force-replace | --force-backup]
```

### Options
--force-replace:
Deletes existing kernel sources in /usr/src/kernel without prompting and downloads fresh sources.

--force-backup:
Backs up existing kernel sources to a timestamped directory (e.g., /usr/src/kernel_backup_YYYYMMDD_HHMMSS) without prompting and downloads fresh sources.

If no options are provided and kernel sources already exist in /usr/src/kernel, the script will prompt you to choose an action:
[K]eep: Retain existing sources and exit (default).

[R]eplace: Delete existing sources and download new ones.

[B]ackup: Backup existing sources to a timestamped directory and download new ones.

## Notes
The script requires sudo privileges and will prompt for a password if necessary.

All actions are logged to a timestamped file in the ./logs directory (e.g., ./logs/get_kernel_sources_YYYYMMDD_HHMMSS.log).



