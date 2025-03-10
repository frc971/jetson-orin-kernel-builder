# Kernel Module Configuration Analysis Script

## Overview
This script helps users analyze **kernel module flags**, their dependencies, and configuration types in the **NVIDIA Jetson Developer Kit** kernel source. It provides detailed insights into **module flags**, their **status**, **types**, and **dependencies**. Additionally, it includes a search feature to find related configuration options within Makefiles, Kconfig files, and the `.config` file.

## Requirements and Dependencies
To successfully run this script, ensure the following:
- **Bash shell** (pre-installed on most Linux systems)
- **Kernel source code** located at `/usr/src/kernel/kernel-jammy-src` or specified via the `KERNEL_URI` environment variable
- **A valid `.config` file** in the kernel source directory

## Usage
Run the script using:
```bash
./scripts/module_info.sh [-h] [-s <search_string>] <module_flag>
```

### Options
- `-h` : Displays the help message.
- `-s <search_string>` : Searches for a string in Makefiles, Kconfig, and `.config` (case-insensitive).
- `<module_flag>` : Specifies a kernel module flag for analysis.

### Example Usage
To check an exact kernel module flag:
```bash
./scripts/module_info.sh CONFIG_LOGITECH_FF
```
To search for related configuration options:
```bash
./scripts/module_info.sh -s winchiphead
```
To display the help message:
```bash
./scripts/module_info.sh -h
```

## Workflow and Key Steps

1. **Parse Command-Line Arguments**
   - The script checks for the `-h` flag to display usage information.
   - If `-s <search_string>` is provided, it searches for the string in:
     - Makefiles
     - Kconfig files
     - `.config`
   - If a module flag is provided, the script looks up its details.

2. **Ensure Kernel Source Directory Exists**
   - Sets the default kernel source path to /usr/src/kernel/kernel-jammy-src
   - The script sets the path to `KERNEL_URI` if the environment variable is set.
   - If the kernel source files cannot be found, it exits with an error:
     ```
     Error: Kernel source directory /usr/src/kernel/kernel-jammy-src not found
     ```

4. **Search for Kernel Configurations**
   - If `-s` is used, the script searches for related configurations.
   - The results are grouped under:
     ```
     Matches in Makefiles:
     Matches in Kconfig files:
     Matches in .config:
     ```

5. **Analyze a Specific Kernel Flag**
   - The script checks if the flag exists in the kernel source.
   - It determines:
     - **Module flag type** (`bool`, `tristate`, `string`, `int`, `hex`)
     - **Possible values** (`y`, `m`, `n`, custom values)
     - **Default values** from Kconfig
     - **Dependencies** (`depends on` conditions)
     - **Selects** (related flags that enable other options)

6. **Search for the Module or Flag in Makefiles**
   - The script scans Makefiles to find where a module or flag is referenced.
   - If found, it outputs detailed information about the module or flag


7. **Analyze Dependencies**
   - The script looks for related dependencies and displays. For example:
     ```
     Dependencies:
       CONFIG_USB_HID
         Status: Built-in (y)
       CONFIG_HID
         Status: External module (m)
     ```

8. **Check `.config` File for Flag Status**
   - The script determines whether the a flag or module is enabled. For example:
     ```
     In .config:
     CONFIG_LOGITECH_FF=y
     ```

## Error Handling
- If the kernel source directory is missing, the script exits with an error.
- If an invalid search string is provided, an error message is displayed.
- If no configuration flag is found, the script exits with an appropriate error message.

## Output and Logs
- If searching, results are grouped into:
  ```
  Matches in Makefiles:
  Matches in Kconfig files:
  Matches in .config:
  ```
- If analyzing a specific flag, the script outputs:
  ```
  Module flag: CONFIG_...
  Module name: ...
  Module path: ...
  Dependencies:
  ```
  
