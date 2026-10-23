@echo off
setlocal EnableExtensions

:: Duplo-clique: executa tools\run_emulator.ps1 a partir da raiz do projeto
:: (funciona independente da pasta de onde o .bat for aberto).
cd /d "%~dp0.."

:: Chama o script do PowerShell, repassando qualquer argumento extra
:: (ex.: run_emulator.bat -NoBuild -Scenario chest).
powershell -ExecutionPolicy Bypass -NoProfile -File "tools\run_emulator.ps1" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo O script terminou com erro (codigo %ERRORLEVEL%).
) else (
    echo.
    echo Script finalizado.
)
pause
