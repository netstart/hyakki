# Instala os hooks git versionados do Hyakki (tools/githooks) neste clone.
# Uso: powershell -ExecutionPolicy Bypass -File tools\install_hooks.ps1
$repo = Split-Path -Parent $PSScriptRoot
& git -C $repo config core.hooksPath tools/githooks
if ($LASTEXITCODE -ne 0) { Write-Host 'ERRO não foi possível configurar core.hooksPath' -ForegroundColor Red; exit 1 }
Write-Host 'OK hooks instalados: core.hooksPath = tools/githooks (pre-commit protege os arquivos do site e sincroniza o app-ads.txt)' -ForegroundColor Green
