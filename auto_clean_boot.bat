@echo off
setlocal EnableDelayedExpansion

:: Script to suppress bootloader warning on Samsung Galaxy A32 (SM-A325F, MT6768)
:: Automates backup, extraction, deletion of booting_warning.jpg/svb_orange.jpg, repack, and flash
:: Handles pre-existing files in /sdcard/up_param_extract and missing files (booting_warning.jpg, svb_orange.jpg, logo.jpg)
:: All operations on-device using Android's tar (Toybox, confirmed present)
:: Every command runs with root (su -c)
:: Backups in current working directory (PC: %CD%, device: /sdcard)
:: 30-second timeouts for stability
:: Logs to clean_boot_log.txt with tar output
:: Author: Grok (assisted), based on user log and samsung-mt6833-devs/mtk_clean_boot
:: Date: April 12, 2025

:: Set ADB path and log file
set ADB=adb.exe
set ADB_SHELL=%ADB% shell
set DEVICE_FOUND=0
set LOG_FILE=%CD%\clean_boot_log.txt
echo [%DATE% %TIME%] Starting Samsung A32 Clean Boot Script > %LOG_FILE%

:: Title
title Samsung A32 Clean Boot Script

echo === Samsung A32 Clean Boot Script ===
echo This script will:
echo - Detect device and root status
echo - Back up up_param to /sdcard and %CD%
echo - Handle pre-existing files in /sdcard/up_param_extract
echo - Extract up_param, delete booting_warning.jpg/svb_orange.jpg if present
echo - Repack and flash modified up_param (~2.7MB)
echo - Preserve logo.jpg if present (warn if missing)
echo - Use 30-second pauses for stability
echo.
echo WARNING: Ensure device is rooted and USB debugging is enabled.
echo Backups will be in: %CD% (PC) and /sdcard (device).
echo Log saved to: %LOG_FILE%
echo Press Ctrl+C to cancel if unsure.
pause

:: Step 1: Check ADB and device connection
echo.
echo === Step 1: Checking device connection ===
echo [%DATE% %TIME%] Checking device connection >> %LOG_FILE%
%ADB% devices | findstr /R "device$" >nul
if %ERRORLEVEL% equ 0 (
    echo Device detected!
    echo [%DATE% %TIME%] Device detected >> %LOG_FILE%
    set DEVICE_FOUND=1
) else (
    echo ERROR: No device found. Plug in your A32, enable USB debugging, and retry.
    echo [%DATE% %TIME%] ERROR: No device found >> %LOG_FILE%
    pause
    exit /b 1
)

:: Step 2: Verify root access
echo.
echo === Step 2: Verifying root access ===
echo [%DATE% %TIME%] Verifying root access >> %LOG_FILE%
for /f "delims=" %%i in ('%ADB_SHELL% "su -c whoami"') do set ROOT_CHECK=%%i
if "%ROOT_CHECK%"=="root" (
    echo Root access confirmed!
    echo [%DATE% %TIME%] Root access confirmed >> %LOG_FILE%
) else (
    echo ERROR: Root not detected. Ensure Magisk is installed and grant root access.
    echo [%DATE% %TIME%] ERROR: Root not detected >> %LOG_FILE%
    pause
    exit /b 1
)

:: Step 3: Find up_param partition
echo.
echo === Step 3: Locating up_param partition ===
echo [%DATE% %TIME%] Locating up_param partition >> %LOG_FILE%
set UP_PARAM_PATH=
for /f "delims=" %%i in ('%ADB_SHELL% "su -c find /dev/block -name up_param"') do set UP_PARAM_PATH=%%i
if "!UP_PARAM_PATH!"=="" (
    echo ERROR: up_param partition not found. Expected /dev/block/mmcblk0p35.
    echo [%DATE% %TIME%] ERROR: up_param not found >> %LOG_FILE%
    pause
    exit /b 1
)
echo Found up_param at: !UP_PARAM_PATH!
echo [%DATE% %TIME%] Found up_param at: !UP_PARAM_PATH! >> %LOG_FILE%

:: Step 4: Back up up_param
echo.
echo === Step 4: Backing up up_param ===
echo [%DATE% %TIME%] Backing up up_param >> %LOG_FILE%
%ADB_SHELL% "su -c dd if=!UP_PARAM_PATH! of=/sdcard/up_param_backup.img"
%ADB_SHELL% "su -c ls -l /sdcard/up_param_backup.img" | findstr "up_param_backup.img" >nul
if %ERRORLEVEL% equ 0 (
    echo Backup created at /sdcard/up_param_backup.img
    echo [%DATE% %TIME%] Backup created at /sdcard/up_param_backup.img >> %LOG_FILE%
) else (
    echo ERROR: Backup failed. Check storage space or permissions.
    echo [%DATE% %TIME%] ERROR: Backup failed >> %LOG_FILE%
    pause
    exit /b 1
)

:: Copy and verify backup to PC
%ADB% pull /sdcard/up_param_backup.img up_param_backup.img
if exist up_param_backup.img (
    for %%F in (up_param_backup.img) do (
        if %%~zF LSS 4000000 (
            echo ERROR: Backup file too small (%CD%\up_param_backup.img). Retry backup.
            echo [%DATE% %TIME%] ERROR: PC backup too small >> %LOG_FILE%
            pause
            exit /b 1
        )
    )
    echo Backup copied to %CD%\up_param_backup.img
    echo [%DATE% %TIME%] Backup copied to %CD%\up_param_backup.img >> %LOG_FILE%
) else (
    echo WARNING: Failed to copy backup to PC. Continuing with on-device backup.
    echo [%DATE% %TIME%] WARNING: PC backup failed >> %LOG_FILE%
)

:: Pause for stability
echo Waiting 30 seconds to ensure backup stability...
echo [%DATE% %TIME%] Waiting 30 seconds after backup >> %LOG_FILE%
timeout /t 30 /nobreak >nul

:: Step 5: Prepare extraction directory
echo.
echo === Step 5: Preparing extraction directory ===
echo [%DATE% %TIME%] Preparing extraction directory >> %LOG_FILE%
%ADB_SHELL% "su -c ls -l /sdcard/up_param_extract" | findstr "." >nul
if %ERRORLEVEL% equ 0 (
    echo WARNING: Pre-existing files found in /sdcard/up_param_extract:
    %ADB_SHELL% "su -c ls -l /sdcard/up_param_extract"
    echo Clearing them now...
    echo [%DATE% %TIME%] WARNING: Pre-existing files found, clearing >> %LOG_FILE%
)
%ADB_SHELL% "su -c rm -rf /sdcard/up_param_extract"
%ADB_SHELL% "su -c mkdir -p /sdcard/up_param_extract"
%ADB_SHELL% "su -c chmod 777 /sdcard/up_param_extract"
echo Extraction directory set at /sdcard/up_param_extract.
echo [%DATE% %TIME%] Extraction directory set >> %LOG_FILE%

:: Step 6: Extract up_param (with retry)
echo.
echo === Step 6: Extracting up_param ===
echo [%DATE% %TIME%] Extracting up_param >> %LOG_FILE%
set EXTRACT_OK=0
set RETRY_COUNT=0
:extract_retry
%ADB_SHELL% "su -c tar xvf /sdcard/up_param_backup.img -C /sdcard/up_param_extract > /sdcard/tar_extract.log 2>&1"
%ADB_SHELL% "su -c ls -l /sdcard/up_param_extract" | findstr ".jpg" >nul
if %ERRORLEVEL% equ 0 (
    set EXTRACT_OK=1
    echo up_param extracted, JPEG files found.
    echo [%DATE% %TIME%] Extraction succeeded, JPEGs found >> %LOG_FILE%
    %ADB_SHELL% "su -c cat /sdcard/tar_extract.log" >> %LOG_FILE%
) else (
    if !RETRY_COUNT! LSS 2 (
        set /a RETRY_COUNT+=1
        echo WARNING: Extraction failed, retrying (%RETRY_COUNT%/2)...
        echo [%DATE% %TIME%] Extraction retry %RETRY_COUNT% >> %LOG_FILE%
        %ADB_SHELL% "su -c rm -rf /sdcard/up_param_extract"
        %ADB_SHELL% "su -c mkdir -p /sdcard/up_param_extract"
        %ADB_SHELL% "su -c chmod 777 /sdcard/up_param_extract"
        %ADB_SHELL% "su -c rm /sdcard/tar_extract.log"
        goto extract_retry
    )
    echo ERROR: Extraction failed after retries. Checking files...
    echo [%DATE% %TIME%] ERROR: Extraction failed >> %LOG_FILE%
    %ADB_SHELL% "su -c ls -l /sdcard/up_param_extract"
    %ADB_SHELL% "su -c cat /sdcard/tar_extract.log" >> %LOG_FILE%
    echo If no files, up_param dump may be corrupted.
    echo Backup is safe at /sdcard/up_param_backup.img
    pause
    exit /b 1
)

:: Check logo.jpg and warning files
%ADB_SHELL% "su -c ls -l /sdcard/up_param_extract/logo.jpg" | findstr "logo.jpg" >nul
if %ERRORLEVEL% equ 0 (
    echo logo.jpg found, will preserve it.
    echo [%DATE% %TIME%] logo.jpg found >> %LOG_FILE%
) else (
    echo WARNING: logo.jpg missing. Boot logo may not display.
    echo [%DATE% %TIME%] WARNING: logo.jpg missing >> %LOG_FILE%
)
set WARNING_FILES_FOUND=0
%ADB_SHELL% "su -c ls -l /sdcard/up_param_extract/booting_warning.jpg" | findstr "booting_warning.jpg" >nul
if %ERRORLEVEL% equ 0 set WARNING_FILES_FOUND=1
%ADB_SHELL% "su -c ls -l /sdcard/up_param_extract/svb_orange.jpg" | findstr "svb_orange.jpg" >nul
if %ERRORLEVEL% equ 0 set WARNING_FILES_FOUND=1

:: Step 7: Delete warning files
echo.
echo === Step 7: Deleting booting_warning.jpg and svb_orange.jpg ===
echo [%DATE% %TIME%] Deleting warning files >> %LOG_FILE%
set DELETE_OK=0
if !WARNING_FILES_FOUND! equ 0 (
    echo No warning files found (already removed). Proceeding.
    echo [%DATE% %TIME%] No warning files found >> %LOG_FILE%
) else (
    %ADB_SHELL% "su -c ls -l /sdcard/up_param_extract/booting_warning.jpg" | findstr "booting_warning.jpg" >nul
    if %ERRORLEVEL% equ 0 (
        %ADB_SHELL% "su -c rm /sdcard/up_param_extract/booting_warning.jpg"
        echo booting_warning.jpg deleted.
        echo [%DATE% %TIME%] booting_warning.jpg deleted >> %LOG_FILE%
        set DELETE_OK=1
    ) else (
        echo booting_warning.jpg already removed.
        echo [%DATE% %TIME%] booting_warning.jpg already removed >> %LOG_FILE%
    )
    %ADB_SHELL% "su -c ls -l /sdcard/up_param_extract/svb_orange.jpg" | findstr "svb_orange.jpg" >nul
    if %ERRORLEVEL% equ 0 (
        %ADB_SHELL% "su -c rm /sdcard/up_param_extract/svb_orange.jpg"
        echo svb_orange.jpg deleted.
        echo [%DATE% %TIME%] svb_orange.jpg deleted >> %LOG_FILE%
        set DELETE_OK=1
    ) else (
        echo svb_orange.jpg already removed.
        echo [%DATE% %TIME%] svb_orange.jpg already removed >> %LOG_FILE%
    )
)

:: Step 8: Repack up_param
echo.
echo === Step 8: Repacking up_param ===
echo [%DATE% %TIME%] Repacking up_param >> %LOG_FILE%
%ADB_SHELL% "su -c tar -cvf /sdcard/up_param_new.img -C /sdcard/up_param_extract ."
%ADB_SHELL% "su -c ls -l /sdcard/up_param_new.img" | findstr "up_param_new.img" >nul
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%i in ('%ADB_SHELL% "su -c ls -l /sdcard/up_param_new.img"') do (
        echo %%i | findstr "up_param_new.img" >nul
        if !ERRORLEVEL! equ 0 (
            for /f "tokens=5" %%j in ("%%i") do (
                if %%j LSS 2000000 (
                    echo ERROR: Repacked file too small (/sdcard/up_param_new.img). Retry repack.
                    echo [%DATE% %TIME%] ERROR: Repack too small >> %LOG_FILE%
                    pause
                    exit /b 1
                )
            )
        )
    )
    echo Repacked as /sdcard/up_param_new.img (~2.7MB expected).
    echo [%DATE% %TIME%] Repacked up_param_new.img >> %LOG_FILE%
) else (
    echo ERROR: Repack failed. Check space or permissions.
    echo [%DATE% %TIME%] ERROR: Repack failed >> %LOG_FILE%
    pause
    exit /b 1
)

:: Verify logo and warning files
%ADB_SHELL% "su -c tar -tvf /sdcard/up_param_new.img" | findstr "logo.jpg" >nul
if %ERRORLEVEL% equ 0 (
    echo Confirmed: logo.jpg included in new image.
    echo [%DATE% %TIME%] logo.jpg in repacked image >> %LOG_FILE%
) else (
    echo WARNING: logo.jpg missing in new image. Boot logo may not display.
    echo [%DATE% %TIME%] WARNING: logo.jpg missing in repack >> %LOG_FILE%
)
%ADB_SHELL% "su -c tar -tvf /sdcard/up_param_new.img" | findstr "booting_warning.jpg" >nul
if %ERRORLEVEL% neq 0 (
    echo Confirmed: booting_warning.jpg not in new image.
    echo [%DATE% %TIME%] booting_warning.jpg not in repack >> %LOG_FILE%
) else (
    echo ERROR: booting_warning.jpg still present. Repack failed.
    echo [%DATE% %TIME%] ERROR: booting_warning.jpg in repack >> %LOG_FILE%
    pause
    exit /b 1
)
%ADB_SHELL% "su -c tar -tvf /sdcard/up_param_new.img" | findstr "svb_orange.jpg" >nul
if %ERRORLEVEL% neq 0 (
    echo Confirmed: svb_orange.jpg not in new image.
    echo [%DATE% %TIME%] svb_orange.jpg not in repack >> %LOG_FILE%
) else (
    echo ERROR: svb_orange.jpg still present. Repack failed.
    echo [%DATE% %TIME%] ERROR: svb_orange.jpg in repack >> %LOG_FILE%
    pause
    exit /b 1
)

:: Step 9: Flash modified up_param
echo.
echo === Step 9: Flashing modified up_param ===
echo [%DATE% %TIME%] Flashing up_param >> %LOG_FILE%
echo This will overwrite !UP_PARAM_PATH!. Double-check:
echo - Backup exists at %CD%\up_param_backup.img
echo - Device is stable
echo Press any key to flash, or Ctrl+C to cancel.
pause
%ADB_SHELL% "su -c dd if=/sdcard/up_param_new.img of=!UP_PARAM_PATH!"
%ADB_SHELL% "su -c sync"
echo Flash complete.
echo [%DATE% %TIME%] Flash complete >> %LOG_FILE%

:: Pause for stability
echo Waiting 30 seconds to ensure flash stability...
echo [%DATE% %TIME%] Waiting 30 seconds after flash >> %LOG_FILE%
timeout /t 30 /nobreak >nul

:: Step 10: Verify flash
echo.
echo === Step 10: Verifying flash ===
echo [%DATE% %TIME%] Verifying flash >> %LOG_FILE%
%ADB_SHELL% "su -c dd if=!UP_PARAM_PATH! of=/sdcard/up_param_verify.img"
%ADB_SHELL% "su -c cmp /sdcard/up_param_new.img /sdcard/up_param_verify.img" >nul
if %ERRORLEVEL% equ 0 (
    echo Flash verified: up_param matches new image.
    echo [%DATE% %TIME%] Flash verified >> %LOG_FILE%
) else (
    echo ERROR: Flash verification failed. DO NOT REBOOT. Restore backup:
    echo adb shell
    echo su
    echo dd if=/sdcard/up_param_backup.img of=!UP_PARAM_PATH!
    echo sync
    echo [%DATE% %TIME%] ERROR: Flash verification failed >> %LOG_FILE%
    pause
    exit /b 1
)

:: Step 11: Clean up
echo.
echo === Step 11: Cleaning up ===
echo [%DATE% %TIME%] Cleaning up >> %LOG_FILE%
%ADB_SHELL% "su -c rm -rf /sdcard/up_param_extract"
%ADB_SHELL% "su -c rm /sdcard/up_param_new.img /sdcard/up_param_verify.img /sdcard/tar_extract.log"
echo Temporary files removed. Backup kept at /sdcard/up_param_backup.img
echo [%DATE% %TIME%] Cleanup complete >> %LOG_FILE%

:: Step 12: Reboot
echo.
echo === Step 12: Rebooting ===
echo [%DATE% %TIME%] Preparing to reboot >> %LOG_FILE%
echo Watch the boot in 30 seconds:
echo - No orange/yellow warning = success
echo - Samsung logo should appear (if logo.jpg present)
echo - Should boot to lock screen
echo Press any key to start 30-second countdown, or Ctrl+C to cancel.
pause
echo Waiting 30 seconds before reboot...
echo [%DATE% %TIME%] Waiting 30 seconds before reboot >> %LOG_FILE%
timeout /t 30 /nobreak >nul
%ADB% reboot
echo Reboot initiated.
echo [%DATE% %TIME%] Reboot initiated >> %LOG_FILE%

:: Done
echo.
echo === Done ===
echo If no warning appears and logo shows (if present), you’re set!
echo Backup is at %CD%\up_param_backup.img and /sdcard/up_param_backup.img
echo Log saved to: %LOG_FILE%
echo If issues (e.g., no logo, bootloop), run:
echo adb shell
echo su
echo dd if=/sdcard/up_param_backup.img of=!UP_PARAM_PATH!
echo sync
echo reboot
echo Report results to Grok with %LOG_FILE%.
echo [%DATE% %TIME%] Script completed >> %LOG_FILE%
pause
exit /b 0