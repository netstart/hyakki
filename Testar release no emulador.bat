@echo off
rem Dois cliques: compila o APK de release (otimizado), liga o emulador Android, instala e abre o Hyakki.
rem Opcoes extras sao repassadas ao script, ex.: "Testar release no emulador.bat" -NoBuild
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\run_emulator_release.ps1" %*
echo.
pause
