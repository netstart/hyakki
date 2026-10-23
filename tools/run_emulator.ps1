# Teste manual no emulador: exporta o APK de debug, liga o emulador (se preciso), instala e abre o
# jogo, e depois mostra o log do Godot até a janela ser fechada.
#
#   Dois cliques em "Testar no emulador.bat" (raiz do projeto), ou:
#   powershell -ExecutionPolicy Bypass -File tools\run_emulator.ps1 [-Scenario chest] [-NoBuild] [-NoLog]
#
# Opções:
#   -NoBuild     reinstala o último APK (build\hyakki-debug.apk) sem exportar de novo
#   -Scenario X  abre direto num cenário de teste: chest, kami, revive, dawn, ending, secret, hero:yuki
#   -NoLog       não fica mostrando o log depois de abrir
#   -NoLaunch    só compila e instala (usado por run_e2e.ps1)
#   -Avd nome    emulador a usar (padrão Redmi_Note_14_Pro_Plus_5G)

param(
    [switch]$NoBuild,
    [string]$Scenario = '',
    [switch]$NoLog,
    [switch]$NoLaunch,
    [string]$Avd = 'Redmi_Note_14_Pro_Plus_5G',
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [string]$AndroidSdk = 'C:\android-sdk'
)

# Ferramentas nativas (adb, Gradle) escrevem avisos no stderr; os códigos são conferidos à mão.
$ErrorActionPreference = 'Continue'
$project = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $project 'build\hyakki-debug.apk'
$adb = Join-Path $AndroidSdk 'platform-tools\adb.exe'
$package = 'dev.hyakki.prototype'

function Step([string]$text) { Write-Host "== $text" -ForegroundColor Cyan }
function Fail([string]$text) { Write-Host "FALHOU: $text" -ForegroundColor Red; exit 1 }

# Liga o emulador já no começo (processo independente via WMI) para ele dar boot enquanto exporta.
function Start-Emulator {
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "`"$adb`" start-server"; CurrentDirectory = (Split-Path $adb) } | Out-Null
    Start-Sleep -Seconds 2
    $running = (& $adb devices 2>$null) | Select-String 'emulator-\d+\s+(device|offline)'
    if ($running) { return }
    Step "Ligando o emulador ($Avd)"
    Remove-Item "$env:USERPROFILE\.android\avd\$Avd.avd\*.lock" -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "`"$(Join-Path $AndroidSdk 'emulator\emulator.exe')`" -avd $Avd -no-boot-anim" } | Out-Null
}

function Wait-Emulator {
    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-Date) -lt $deadline) {
        $device = (& $adb devices 2>$null) | Select-String 'emulator-\d+\s+device' | Select-Object -First 1
        if ($device) {
            $serial = ($device -split '\s+')[0]
            if (((& $adb -s $serial shell getprop sys.boot_completed 2>$null) -join '').Trim() -eq '1') { return $serial }
        }
        Start-Sleep -Seconds 3
    }
    return $null
}

# --- 1. Emulador (boot em paralelo com o export) -------------------------------------
Start-Emulator

# --- 2. Export de debug --------------------------------------------------------------
# Mesmo cuidado do build_release.ps1: o Godot com os plugins Android às vezes não encerra depois
# do export Gradle, então o script acompanha o log e fecha o processo quando termina.
if (-not $NoBuild) {
    Step 'Compilando o APK de debug'
    if (Test-Path $apk) { Remove-Item $apk -Force }
    $log = "$apk.log"
    $godotArgs = @('--headless', '--path', "`"$project`"")
    if (-not (Test-Path (Join-Path $project 'android\build'))) { $godotArgs += '--install-android-build-template' }
    $godotArgs += @('--export-debug', '"Android"', "`"$apk`"")
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
$serial = Wait-Emulator
if (-not $serial) { Fail 'o emulador não ficou pronto em 5 minutos' }
Write-Host "aparelho: $serial"

Step 'Instalando'
$install = & $adb -s $serial install -r $apk 2>&1 | Out-String
if ($install -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match') {
    Write-Host 'A versão instalada tem outra assinatura (release): desinstalando (apaga o save do emulador)' -ForegroundColor Yellow
    & $adb -s $serial uninstall $package | Out-Null
    $install = & $adb -s $serial install $apk 2>&1 | Out-String
}
if ($install -notmatch 'Success') { Write-Host $install; Fail 'a instalação falhou' }
if ($NoLaunch) { Write-Host 'PRONTO: instalado no emulador.' -ForegroundColor Green; exit 0 }

Step 'Abrindo o jogo'
& $adb -s $serial shell am force-stop $package
if ($Scenario) {
    & $adb -s $serial shell "run-as $package sh -c 'mkdir -p files && echo $Scenario > files/scenario.txt'"
    Write-Host "cenário: $Scenario"
}
& $adb -s $serial logcat -c
& $adb -s $serial shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Write-Host 'PRONTO: o jogo está aberto no emulador.' -ForegroundColor Green

if ($NoLog) { exit 0 }
Step 'Log do Godot (feche a janela para sair; o emulador continua ligado)'
& $adb -s $serial logcat -s godot:V GodotPlugin:V AndroidRuntime:E
