# Cria os emuladores (AVDs) dos aparelhos-alvo dos testes que ainda não existem: Redmi Note 14 Pro+ 5G,
# Samsung Galaxy M55 5G, Google Pixel 7 e Samsung Galaxy A15 (tabela em tools\test_devices.ps1). Os que já existem não
# são tocados, a não ser com -Force (recria do zero e apaga o save do jogo nesse emulador).
#
#   powershell -ExecutionPolicy Bypass -File tools\create_test_avds.ps1 [-Force] [-Only Pixel_7]
#
# Todos usam a mesma imagem (Android 14, Google APIs, x86_64). Memória, CPU, GPU e disco seguem o
# config.ini do AVD do Redmi (referência) quando ele existe; tela e densidade vêm da tabela.
# Precisa do Java (JAVA_HOME) para o avdmanager e da imagem do sistema instalada:
#   C:\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat "system-images;android-34;google_apis;x86_64"

param(
    [switch]$Force,
    [string]$Only = '',
    [string]$AndroidSdk = 'C:\android-sdk',
    [string]$SystemImage = 'system-images;android-34;google_apis;x86_64'
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'test_devices.ps1')
$avdmanager = Join-Path $AndroidSdk 'cmdline-tools\latest\bin\avdmanager.bat'
$avdHome = Join-Path $env:USERPROFILE '.android\avd'
$reference = 'Redmi_Note_14_Pro_Plus_5G'

function Fail([string]$text) { Write-Host "FALHOU: $text" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $avdmanager)) { Fail "não achei $avdmanager (instale as cmdline-tools do Android SDK)" }
$imageDir = Join-Path $AndroidSdk (($SystemImage -replace ';', '\') + '\')
if (-not (Test-Path $imageDir)) { Fail "imagem $SystemImage não instalada (veja o cabeçalho deste script)" }

# Lê um config.ini (aceita "chave=valor" e "chave = valor") preservando a ordem.
function Read-Ini([string]$path) {
    $map = [ordered]@{}
    foreach ($line in Get-Content $path -Encoding UTF8) {
        if ($line -match '^\s*([^#=][^=]*?)\s*=\s*(.*)$') { $map[$Matches[1]] = $Matches[2] }
    }
    $map
}

function Write-Ini([string]$path, $map) {
    $text = ($map.Keys | ForEach-Object { "$_=$($map[$_])" }) -join "`n"
    [IO.File]::WriteAllText($path, $text + "`n", (New-Object Text.UTF8Encoding $false))
}

# Desempenho e disco iguais ao Redmi (o AVD de referência); valores dele mesmo se já existir.
$refIni = Join-Path $avdHome "$reference.avd\config.ini"
$shared = [ordered]@{
    'hw.ramSize' = '1536M'; 'vm.heapSize' = '384M'; 'hw.cpu.ncore' = '4'
    'hw.gpu.enabled' = 'no'; 'hw.gpu.mode' = 'auto'; 'disk.dataPartition.size' = '6442450944'
    'hw.keyboard' = 'no'; 'hw.initialOrientation' = 'portrait'; 'PlayStore.enabled' = 'no'
    'fastboot.forceColdBoot' = 'no'; 'fastboot.forceFastBoot' = 'yes'
}
if (Test-Path $refIni) {
    $ref = Read-Ini $refIni
    foreach ($k in @($shared.Keys)) { if ($ref.Contains($k) -and $ref[$k]) { $shared[$k] = $ref[$k] } }
    Write-Host "referência: $refIni"
}

$devices = if ($Only) { Resolve-TestDevices $Only } else { $TestDevices }
$created = 0
foreach ($d in $devices) {
    if (-not $d.Base) { Write-Host "$($d.Avd): não está na tabela de tools\test_devices.ps1; pulando" -ForegroundColor Yellow; continue }
    if ((Test-AvdExists $d.Avd) -and -not $Force) { Write-Host "ok: $($d.Avd) já existe"; continue }
    Write-Host "== Criando $($d.Avd) ($($d.Label), $($d.Width)x$($d.Height), $($d.Density) dpi)" -ForegroundColor Cyan
    $createArgs = @('create', 'avd', '-n', $d.Avd, '-k', $SystemImage, '-d', $d.Base)
    if ($Force) { $createArgs += '--force' }
    # "no" responde à pergunta do perfil de hardware personalizado.
    $output = 'no' | & $avdmanager @createArgs 2>&1 | Out-String
    if (-not (Test-AvdExists $d.Avd)) { Write-Host $output; Fail "o avdmanager não criou $($d.Avd)" }

    $iniPath = Join-Path $avdHome "$($d.Avd).avd\config.ini"
    $ini = Read-Ini $iniPath
    foreach ($k in $shared.Keys) { $ini[$k] = $shared[$k] }
    $ini['avd.name'] = $d.Avd
    $ini['avd.id'] = $d.Avd
    $ini['hw.lcd.width'] = "$($d.Width)"
    $ini['hw.lcd.height'] = "$($d.Height)"
    $ini['hw.lcd.density'] = "$($d.Density)"
    $ini['hw.device.manufacturer'] = $d.Manufacturer
    # Sem moldura de aparelho: a moldura do Pixel tem outra tela e o recorte vem do overlay do Android.
    $ini['showDeviceFrame'] = 'no'
    $ini['skin.dynamic'] = 'yes'
    $ini['skin.name'] = "$($d.Width)x$($d.Height)"
    $ini.Remove('skin.path')
    Write-Ini $iniPath $ini
    $created++
    Write-Host "ok: $iniPath"
}
Write-Host "PRONTO: $created AVD(s) criado(s). Recorte de câmera (cutout) é ligado pelos scripts depois do boot." -ForegroundColor Green
