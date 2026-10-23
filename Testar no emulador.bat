@echo off
rem Dois cliques: compila o APK de debug, liga o emulador Android, instala e abre o Hyakki.
rem Opcoes extras sao repassadas ao script, ex.: "Testar no emulador.bat" -Scenario chest
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\run_emulator.ps1" %*
echo.
pause
