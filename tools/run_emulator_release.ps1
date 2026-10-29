# Teste manual da build de produção no emulador: exporta o APK de release (otimizado, assinado com a
# chave de envio, scripts compilados), liga o emulador (se preciso), instala, abre o jogo e depois
# mostra o log do Godot até a janela ser fechada.
#
#   Dois cliques em "Testar release no emulador.bat" (raiz do projeto), ou:
#   powershell -ExecutionPolicy Bypass -File tools\run_emulator_release.ps1 [-NoBuild] [-NoLog]
#
# Opções:
#   -NoBuild           reinstala o último APK (build\release\hyakki-release.apk) sem exportar de novo
#   -NoLog             não fica mostrando o log depois de abrir
#   -KeystoreEnv path  arquivo com as variáveis da chave (padrão C:\src\keys\hyakki-release.env)
#   -Avd nome          emulador a usar (padrão Redmi_Note_14_Pro_Plus_5G; também Galaxy_M55_5G e Pixel_7)
#
# Para gerar o AAB da Play Store (com verificações e conferência da assinatura) use build_release.ps1.

param(
    [switch]$NoBuild,
    [switch]$NoLog,
    [string]$KeystoreEnv = 'C:\src\keys\hyakki-release.env',
    [string]$Avd = 'Redmi_Note_14_Pro_Plus_5G',
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [string]$AndroidSdk = 'C:\android-sdk'
)

# Ferramentas nativas (adb, Gradle) escrevem avisos no stderr; os códigos são conferidos à mão.
$ErrorActionPreference = 'Continue'
$project = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $project 'build\release\hyakki-release.apk'
$adb = Join-Path $AndroidSdk 'platform-tools\adb.exe'
$package = 'io.github.netstart.hyakki'

function Step([string]$text) { Write-Host "== $text" -ForegroundColor Cyan }
function Fail([string]$text) { Write-Host "FALHOU: $text" -ForegroundColor Red; exit 1 }

# Ligar o AVD, troca de emulador e recorte de câmera (tools\emulator_common.ps1).
. (Join-Path $PSScriptRoot 'emulator_common.ps1')

# --- 1. Emulador (boot em paralelo com o export) -------------------------------------
# Processo independente (WMI); se outro AVD estiver ligado, ele é desligado antes.
try { Start-EmulatorFor $adb $AndroidSdk $Avd | Out-Null } catch { Fail $_.Exception.Message }

# --- 2. Export de release ------------------------------------------------------------
if (-not $NoBuild) {
    # A chave nunca fica no repositório: o .env define GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD,
    # que o Godot lê do ambiente na hora de assinar.
    Step 'Chave de assinatura'
    if (-not (Test-Path $KeystoreEnv)) { Fail "não achei $KeystoreEnv (veja o README, seção Publicação)" }
    foreach ($line in Get-Content $KeystoreEnv) {
        if ($line -match '^\s*([A-Z_]+)\s*=\s*(.+?)\s*$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
    }
    if (-not (Test-Path $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH)) { Fail 'keystore indicado no .env não existe' }

    # Mesmo cuidado do build_release.ps1: o Godot com os plugins Android às vezes não encerra depois
    # do export Gradle, então o script acompanha o log e fecha o processo quando termina.
    Step 'Compilando o APK de release (otimizado)'
    if (Test-Path $apk) { Remove-Item $apk -Force }
    New-Item -ItemType Directory -Force (Split-Path $apk) | Out-Null
    $log = "$apk.log"
    $godotArgs = @('--headless', '--path', "`"$project`"")
    if (-not (Test-Path (Join-Path $project 'android\build'))) { $godotArgs += '--install-android-build-template' }
    $godotArgs += @('--export-release', '"Android Release APK"', "`"$apk`"")
    $proc = Start-Process -FilePath $Godot -ArgumentList $godotArgs -RedirectStandardOutput $log `
        -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden
    $started = Get-Date
    $deadline = $started.AddMinutes(30)
    $done = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        Write-Host ("`r  {0:mm\:ss}" -f ((Get-Date) - $started)) -NoNewline
        $text = (Get-Content $log -Raw -ErrorAction SilentlyContinue) + (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue)
        if ($text -match 'DONE.*export') { $done = $true; break }
        if ($text -match 'BUILD FAILED|Project export for preset .* failed|Export failed') { break }
        if ($proc.HasExited) { $done = (Test-Path $apk); break }
    }
    Write-Host ''
    Start-Sleep -Seconds 2
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    if (-not $done -or -not (Test-Path $apk)) {
        Get-Content "$log.err" -Tail 30 -ErrorAction SilentlyContinue | Write-Host
        Fail "o export não gerou $apk (log: $log)"
    }
    Write-Host "ok: $apk ($([math]::Round((Get-Item $apk).Length / 1MB, 1)) MB)"
} elseif (-not (Test-Path $apk)) {
    Fail "não existe $apk; rode sem -NoBuild"
}

# --- 3. Instalar e abrir -------------------------------------------------------------
Step 'Esperando o emulador'
# Até 8 minutos; travado, é desligado à força e ligado de novo uma vez .
$serial = Wait-EmulatorReady $adb $AndroidSdk $Avd 8
if (-not $serial) { Fail "o emulador $Avd não ficou pronto em 8 minutos nem depois de reiniciado" }
$cutout = Set-EmulatorCutout $adb $serial $Avd
Write-Host "aparelho: $serial ($Avd$(if ($cutout) { ", recorte de câmera: $cutout" }))"

Step 'Instalando'
$install = & $adb -s $serial install -r $apk 2>&1 | Out-String
if ($install -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match') {
    Write-Host 'A versão instalada tem outra assinatura (debug): desinstalando (apaga o save do emulador)' -ForegroundColor Yellow
    & $adb -s $serial uninstall $package | Out-Null
    $install = & $adb -s $serial install $apk 2>&1 | Out-String
}
if ($install -notmatch 'Success') { Write-Host $install; Fail 'a instalação falhou' }

Step 'Abrindo o jogo'
& $adb -s $serial shell am force-stop $package
& $adb -s $serial logcat -c
& $adb -s $serial shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Write-Host 'PRONTO: a build de release está aberta no emulador.' -ForegroundColor Green

if ($NoLog) { exit 0 }
Step 'Log do Godot (feche a janela para sair; o emulador continua ligado)'
& $adb -s $serial logcat -s godot:V GodotPlugin:V AndroidRuntime:E
