# Verificações do protótipo (plano 14 e 15.1):
#   1. importa o projeto (valida a sintaxe de todos os scripts)
#   2. testes das regras puras
#   3. partida com o bot em 1x, 2x e 3x: o estado tem de ser idêntico (determinismo)
#   4. teste de estresse com 500 inimigos (custo da simulação neste PC)
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
#       (opcional) -Godot "C:\caminho\Godot_v4.7.2-stable_win64_console.exe"

param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' })
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$failed = $false

function Invoke-Godot([string[]]$GodotArgs) {
    # O Godot escreve avisos de saída no stderr; no PowerShell 5.1 isso não pode encerrar o script.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $Godot --headless --path $project @GodotArgs 2>&1 | ForEach-Object { "$_" }
    $ErrorActionPreference = $previous
    return $output
}

Write-Host '== 1. Importação' -ForegroundColor Cyan
$import = Invoke-Godot @('--import')
$importErrors = $import | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' }
if ($importErrors) { $importErrors | Write-Host -ForegroundColor Red; $failed = $true } else { Write-Host 'ok' }

Write-Host '== 2. Testes de regras' -ForegroundColor Cyan
$tests = Invoke-Godot @('--script', 'res://tests/run_tests.gd')
$tests | Where-Object { $_ -match 'verificações|FALHOU|ERROR' } | Write-Host
if ($LASTEXITCODE -ne 0 -or ($tests -match 'FALHOU|SCRIPT ERROR')) { $failed = $true }

Write-Host '== 1b. Lint (gdlint, regras em gdlintrc)' -ForegroundColor Cyan
if (Get-Command gdlint -ErrorAction SilentlyContinue) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $lint = & gdlint (Join-Path $project 'scripts') (Join-Path $project 'tests') 2>&1 | ForEach-Object { "$_" }
    $ErrorActionPreference = $previous
    $lint | Select-Object -Last 3 | Write-Host
    if ($LASTEXITCODE -ne 0) { $failed = $true }
} else { Write-Host 'gdlint não instalado (pip install "gdtoolkit==4.*"); pulando' -ForegroundColor Yellow }

Write-Host '== 2b. Textos (11 idiomas, marcadores) e licenças' -ForegroundColor Cyan
& python -I (Join-Path $PSScriptRoot 'build_i18n.py') --check
if ($LASTEXITCODE -ne 0) { $failed = $true }
& python -I (Join-Path $PSScriptRoot 'check_licenses.py')
if ($LASTEXITCODE -ne 0) { $failed = $true }
& python -I (Join-Path $PSScriptRoot 'check_store_listing.py')
if ($LASTEXITCODE -ne 0) { $failed = $true }

Write-Host '== 2c. Testes de integração (dados, idiomas, fontes, Loja, Santuário, save)' -ForegroundColor Cyan
$integration = Invoke-Godot @('res://tests/integration_tests.tscn')
$integration | Where-Object { $_ -match 'verificações|FALHOU|SCRIPT ERROR' } | Write-Host
if ($LASTEXITCODE -ne 0 -or ($integration -match 'FALHOU|SCRIPT ERROR')) { $failed = $true }

Write-Host '== 3. Determinismo (1x, 2x, 3x)' -ForegroundColor Cyan
$hashes = @()
foreach ($speed in 1, 2, 3) {
    $run = Invoke-Godot @('--fixed-fps', '60', '--', '--bot', '--seed=7', "--speed=$speed", '--quit-at=90')
    $errors = $run | Where-Object { $_ -match 'SCRIPT ERROR' }
    if ($errors) { $errors | Write-Host -ForegroundColor Red; $failed = $true }
    $line = $run | Where-Object { $_ -match '^FIM ' } | Select-Object -Last 1
    Write-Host "${speed}x: $line"
    $hashes += ($line -replace '^.*hash=', '')
}
if (($hashes | Select-Object -Unique).Count -ne 1) {
    Write-Host 'FALHOU: o estado mudou com a velocidade' -ForegroundColor Red
    $failed = $true
} else { Write-Host 'ok: mesmo estado nas três velocidades' }

Write-Host '== 4. Estresse (500 inimigos)' -ForegroundColor Cyan
$stress = Invoke-Godot @('--fixed-fps', '60', '--', '--bot', '--seed=7', '--stress=500', '--log-every=10', '--quit-at=30')
$stress | Where-Object { $_ -match '^DESEMPENHO|pior por sistema|SCRIPT ERROR' } | Write-Host
Write-Host '(o "pior" do passo em que o log é impresso inclui o tempo do próprio print)'

if ($failed) { Write-Host 'FALHOU' -ForegroundColor Red; exit 1 }
Write-Host 'TUDO OK' -ForegroundColor Green
