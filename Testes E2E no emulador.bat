@echo off
rem Dois cliques: compila o APK de debug, liga o emulador e roda os testes de ponta a ponta (E2E).
rem ATENCAO: apaga o save do jogo no emulador. Opcoes extras sao repassadas, ex.: -NoBuild
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\run_e2e.ps1" %*
echo.
pause
