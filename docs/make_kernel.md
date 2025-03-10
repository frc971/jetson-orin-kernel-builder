# NVIDIA Jetson Kernel Build Script

## Overview
This script automates the process of **building the Linux kernel** for an **NVIDIA Jetson Developer Kit**. It verifies the kernel source directory, sets up logging, removes old build artifacts, and compiles the kernel using optimal CPU core allocation.

## Requirements and Dependencies
To successfully run this script, ensure the following:
- **Bash shell** (pre-installed on most Linux systems)
- **Kernel source code** located in `/usr/src/` or a user-specified directory
- **Required build tools** installed. Retrieving the source code user get_kernel_sources.sh will install libssl-dev:
  ```bash
  sudo apt-get install -y libssl-dev
  ```
- **Sufficient disk space and memory** for compilation

## Usage
Run the script using:
```bash
./buildKernel.sh [[-d directory ] | [-h]]
```

### Options
- `-d, --directory <path>` : Specifies the directory where the kernel source is located (default: `/usr/src/`).
- `-h, --help` : Displays the usage information and exits.

### Example Usage
To build the kernel using the default kernel source path:
```bash
./scripts/make_kernel.sh
```
To specify a custom kernel source directory:
```bash
./scripts/make_kernel.sh -d /path/to/kernel/source
```
To display the help message:
```bash
./scripts/make_kernel.sh -h
```

## Workflow and Key Steps

1. **Parse Command-Line Arguments**  
   - The script checks for the `-d` flag to override the default kernel source directory.
   - If the `-h` flag is provided, the script displays the usage message and exits.

2. **Ensure Directory Path Format**  
   - The script ensures the provided directory path ends with a trailing slash (`/`).

3. **Verify Kernel Source Directory**  
   - The kernel source path can be overriden. The default kernel source path is:  
     ```
     /usr/src/kernel/kernel-jammy-src
     ```
   - If the directory does not exist, an error message is displayed, and the script exits.

4. **Set Up Logs Directory**  
   - A `logs/` directory is created in the current working directory if it does not already exist.
   - The log file is named `kernel_build.log`.

5. **Navigate to Kernel Source Directory**  
   - The script changes into the kernel source directory before proceeding with the build.

6. **Remove Old Kernel Image**  
   - If an old kernel `Image` file exists at:  
     ```
     arch/arm64/boot/Image
     ```
     it is deleted to ensure a clean build.

7. **Determine Optimal Number of Parallel Jobs**  
   - The script detects the number of available CPU cores using:
     ```bash
     nproc
     ```
   - If more than one core is available, it uses `N-1` cores for building to improve system responsiveness.

8. **Build the Kernel**  
   - The script compiles the kernel using:
     ```bash
     make -j$(nproc - 1) Image
     ```
   - If the build fails, it retries with a single-threaded approach.

9. **Verify Kernel Image Creation**  
   - If the kernel image file exists at:
     ```
     arch/arm64/boot/Image
     ```
     the build is considered successful.
   - Otherwise, an error message is displayed, and the script exits.

## Error Handling
- If an invalid option is provided, the script displays a usage message and exits.
- If the kernel source directory does not exist, the script exits with an error.
- If the initial multi-threaded build fails, the script attempts a single-threaded build.
- If no `Image` file is generated after compilation, the script exits with an error and provides troubleshooting hints.

## Output and Logs
- The final compiled kernel image is saved at:
  ```
  arch/arm64/boot/Image
  ```
- Build logs are stored in:
  ```
  logs/kernel_build.log
  ```

