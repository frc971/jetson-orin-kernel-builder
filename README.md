# jetson-orin-kernel-builder
Tools to build the Linux kernel and modules on board the **Jetson AGX Orin, Orin Nano, or Orin NX**. This tool is designed for **beginning to intermediate users**. Please **read this entire document before proceeding**.

This is for **JetPack 6**.

## Overview
This repository contains **convenience scripts** to simplify the process of:
- **Downloading Kernel and Module Sources** (Board Support Package Sources - BSP)
- **Editing Kernel Configuration** (Both **GUI** and **CLI** options available)
- **Building the Kernel Image**
- **Building Kernel Modules (in-tree (tested) and out of tree (untested) )**

These scripts help automate common tasks involved in kernel modification and module development on **Jetson Linux 36.X**.

---

## Prerequisites
Before using these scripts, ensure:
- You have a **Jetson Orin** device running **JetPack 6.X**.
- Your system is **up to date**:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```

---

## Scripts

### **1. Get Kernel and Module Sources**
#### [`get_kernel_sources.sh`](scripts/get_kernel_sources.sh)
**Downloads, extracts, and configures** the kernel source for **Jetson Linux 36.X**.
- Automatically detects **L4T version**.
- Supports **backing up or replacing** existing kernel sources.
- Extracts **kernel, out-of-tree modules, and display driver sources**.
- Copies the **current kernel config** as basis for modification.

Usage:
```bash
./scripts/get_kernel_sources.sh [--force-replace] [--force-backup]
```
Options:
- `--force-replace` → Delete existing kernel sources and downloads fresh sources.
- `--force-backup` → Backup existing kernel sources before downloading new ones.

---

### **2. Edit Kernel Configuration**
#### GUI Mode: [`edit_config_gui.sh`](scripts/edit_config_gui.sh)
Launches `make xconfig`, a **graphical interface** for kernel configuration.
- Checks for required **Qt5 libraries** and installs them if missing.
- Runs `make xconfig` with appropriate permissions.

Usage:
```bash
./scripts/edit_config_gui.sh [kernel_source_directory]
```
_Defaults to `/usr/src/kernel/kernel-jammy-src`._

---

#### CLI Mode: [`edit_config_cli.sh`](scripts/edit_config_cli.sh)
Launches `make menuconfig`, a **text-based interface** for kernel configuration.
- Checks for **ncurses** dependency (`libncurses5-dev`).
- Runs 'make menuconfig' with appropriate permissions

Usage:
```bash
./scripts/edit_config_cli.sh [[-d directory] | [-h]]
```
Options:
- `-d | --directory <path>` → Specify kernel source directory.
- `-h | --help` → Display help message.

---

### **3. Build the Kernel**
#### [`buildKernel.sh`](scripts/buildKernel.sh)
Compiles the Linux kernel for the **Jetson Orin** series.
- **Checks kernel source path**.
- **Removes old kernel images** to ensure a clean build.
- Uses **multiple CPU cores** to optimize compilation.
- **Retries with a single-threaded build** if necessary.

Usage:
```bash
./scripts/buildKernel.sh [[-d directory] | [-h]]
```
Options:
- `-d | --directory <path>` → Specify kernel source directory.
- `-h | --help` → Display help message.

---

### **4. Build Kernel Modules**
#### [`make_kernel_modules.sh`](scripts/make_kernel_modules.sh)
Builds and **optionally installs** kernel modules.
- Uses **optimized CPU allocation** for faster compilation.
- Automatically **updates module dependencies** after installation.
- If installation is skipped, **provides manual install instructions**.

Usage:
```bash
./scripts/make_kernel_modules.sh [[-d directory] | [-h]]
```
Options:
- `-d | --directory <path>` → Specify kernel source directory.
- `-h | --help` → Display help message.

---

## Release History

### **March 2025**
- **Initial Release**
- Tested on **JetPack 6.2**
- Tested on the following devices:
  - **Jetson Orin Nano**
  - **Jetson AGX Orin**

---

## Notes
- **Ensure that all kernel changes are backed up** before installing a new kernel or modules.
- Running kernel modifications **requires root privileges**.
- If you face issues, check the **log files** generated in the `logs/` directory.


