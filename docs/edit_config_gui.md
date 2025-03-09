# Kernel Configuration Script Documentation

## Overview

This script facilitates the use of `make xconfig`, which provides a graphical interface for configuring Linux kernel options. It ensures that the necessary Qt5 libraries are installed and then launches `make xconfig` in the specified kernel source directory.

## Requirements

- A valid Linux kernel source directory containing a `Makefile`. The default directory is `/usr/src/kernel/kernel-jammy-src`, but this can be overridden using the directory override flag.
- The Qt5 development libraries (`Qt5Core`, `Qt5Gui`, `Qt5Widgets`), which are required to run `make xconfig`.

## Usage
To invoke the script, run 

```bash
./scripts/edit_config_gui.sh
```

to use the default kernel source directory (`/usr/src/kernel/kernel-jammy-src`), or use the directory override flag by running:

```bash
./scripts/edit_config_gui.sh /path/to/kernel/source
```

to specify a different directory.
