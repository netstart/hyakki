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
#   -Avd nome          emulador a usar (padrão Redmi_Note_14_Pro_Plus_5G)
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
$serial = Wait-Emulator
if (-not $serial) { Fail 'o emulador não ficou pronto em 5 minutos' }
Write-Host "aparelho: $serial"

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
