# Regenera toda a arte da Google Play (docs/store/graphics) a partir do jogo atual:
#   1. tools/store_capture.tscn abre o jogo de verdade e captura as telas em 640x360 (pt_BR e en);
#   2. tools/make_store_art.tscn monta ícones, gráfico de recursos e capturas (com e sem legenda);
#   3. tools/check_store_graphics.py confere tamanhos, alfa e limites da Play Console.
# Precisa de janela (não roda --headless). Leva uns 8 minutos.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\make_store_art.ps1
#       -Only icons,feature        só essas partes da arte (sem recapturar)
#       -SkipCapture               reaproveita build\store_capture

param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [string]$Only = '',
    [switch]$SkipCapture
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$captures = Join-Path $project 'build\store_capture'

function Invoke-Godot([string[]]$GodotArgs) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Godot --path $project @GodotArgs 2>&1 | ForEach-Object { "$_" } |
        Where-Object { $_ -match '^(SHOT|ART|STORE|SCRIPT ERROR)' } | Write-Host
    $ErrorActionPreference = $previous
}

if (-not $SkipCapture -and -not $Only) {
    foreach ($lang in @('pt_BR', 'en')) {
        Write-Host "== Capturas ($lang)" -ForegroundColor Cyan
        Invoke-Godot @('res://tools/store_capture.tscn', '--', "--out=$captures\$lang", "--lang=$lang", '--ads-off')
    }
}

Write-Host '== Arte da loja' -ForegroundColor Cyan
$artArgs = @('res://tools/make_store_art.tscn', '--', "--captures=$captures")
if ($Only) { $artArgs += "--only=$Only" }
Invoke-Godot $artArgs

Write-Host '== Conferência' -ForegroundColor Cyan
& python -I (Join-Path $PSScriptRoot 'check_store_graphics.py')
if ($LASTEXITCODE -ne 0) { exit 1 }
& python -I (Join-Path $PSScriptRoot 'check_licenses.py')
if ($LASTEXITCODE -ne 0) { exit 1 }
