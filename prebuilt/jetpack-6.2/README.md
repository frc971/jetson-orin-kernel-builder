# Prebuilt Modules
This directory contains pre-built modules for JetsonLinux 36.4.3 (JetPack 6.2).
These are typically sourced from the mainstream kernel, and are provided as convenience binaries.
The vermagic number is 5.15.148-tegra

Each tar file for the module contains:
* A license file (if it's a Linux in-tree, it is GPL v2).
* A README.md describing the module with installation instructions
* The module itself
* A script to install the module

There is a SHA256SUM for each tar file.

Modules are typically named after their module flag. Modules include:

* USB_SERIAL_CH341 - A driver for CH341 based USB to serial adapters.
* IP_NF_RAW - Part of Netfilter framework, manipulates packets before they enter the iptables processing chain.


