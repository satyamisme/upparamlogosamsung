# Samsung Galaxy A32 Clean Boot Script

This script (`auto_clean_boot.txt`) automates the process of suppressing bootloader warnings (specifically, removing `booting_warning.jpg` and `svb_orange.jpg`) on a Samsung Galaxy A32 (SM-A325F, MT6768). [cite: 1, 2]

**WARNING:** This script requires your device to be rooted and have USB debugging enabled. Proceed with caution and at your own risk.

## Features

* Detects device connection via ADB. [cite: 6, 7]
* Verifies root access. [cite: 8]
* Locates the `up_param` partition. [cite: 9, 10]
* Backs up the `up_param` partition to both the device (`/sdcard`) and the PC. [cite: 11, 12, 13, 14, 15]
* Handles pre-existing files in `/sdcard/up_param_extract` by clearing them. [cite: 16, 17, 18]
* Extracts the `up_param` archive. [cite: 19, 20, 21, 22]
* Deletes `booting_warning.jpg` and `svb_orange.jpg` if present. [cite: 23, 24, 25, 26, 27, 28, 29, 30]
* Repacks the modified `up_param`. [cite: 31, 32, 33, 34]
* Preserves `logo.jpg` if present (warns if missing). [cite: 22, 35]
* Flashes the modified `up_param` to the device. [cite: 38, 39, 40, 41]
* Verifies the flash by comparing the flashed partition with the new image. [cite: 42, 43]
* Cleans up temporary files. [cite: 44, 45]
* Reboots the device. [cite: 46, 47, 48]
* Logs all actions to `clean_boot_log.txt`. [cite: 1, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 26, 27, 28, 30, 31, 33, 34, 35, 36, 37, 38, 40, 41, 42, 44, 45, 46, 47, 48, 50, 51]
* Uses 30-second timeouts for stability during backup, flash, and reboot. [cite: 15, 41, 47]

## Prerequisites

* Samsung Galaxy A32 (SM-A325F, MT6768)
* Root access (e.g., Magisk)
* USB debugging enabled
* ADB (Android Debug Bridge) installed on your PC and added to your system's PATH.
* ADB recognizes your device

## Usage

1.  Ensure your device meets the prerequisites.
2.  Connect your device to your PC.
3.  Run `auto_clean_boot.txt`.
4.  Follow the on-screen prompts.
5.  Check the log file (`clean_boot_log.txt`) for details.

## Log File

The script logs its execution to `clean_boot_log.txt`. [cite: 1, 2] This file contains important information about the script's progress, including:

* Timestamps for each step. [cite: 1]
* Device connection status. [cite: 6, 7]
* Root access verification. [cite: 8]
* Partition details. [cite: 9, 10]
* Backup and flash results. [cite: 11, 12, 38, 40, 41, 42]
* Error messages. [cite: 7, 9, 12, 13, 21, 33, 34, 36, 37, 42, 43]

Example log entry:
