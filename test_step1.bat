@echo off
setlocal enabledelayedexpansion
set "ADB=C:\android-sdk\platform-tools\adb.exe"
"%ADB%" devices | findstr "emulator-5554" >nul
if errorlevel 1 (
    echo Emulador nao esta rodando.
) else (
    echo Emulador ja esta rodando.
)
echo FIM step1
