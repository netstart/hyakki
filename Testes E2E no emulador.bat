@echo off
rem Dois cliques: compila o APK de debug e roda os testes de ponta a ponta (E2E) nos quatro aparelhos-alvo,
rem um depois do outro: Redmi Note 14 Pro+ 5G, Samsung Galaxy M55 5G, Google Pixel 7 e Samsung Galaxy A15.
rem Cria os emuladores que faltarem (tools\create_test_avds.ps1).
rem ATENCAO: apaga o save do jogo nos emuladores. Opcoes extras sao repassadas, ex.: -NoBuild
rem ou -Avd Pixel_7 (so um aparelho).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\create_test_avds.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\run_e2e.ps1" %*
echo.
pause
