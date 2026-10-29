# Build de publicação do Hyakki (plano 16): AAB assinado para a Play Store + APK de release
# para conferir à mão, com R8 (minify) e só os recursos que vão no jogo.
#
#   powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
#
# Opções:
#   -SkipChecks        não roda tools\run_checks.ps1 antes
#   -VersionCode N     versionCode do Android (cada envio à Play Store precisa de um maior)
#   -VersionName X     versão visível (ex.: 1.0.1)
#   -KeystoreEnv path  arquivo com as variáveis da chave (padrão C:\src\keys\hyakki-release.env)
#
# Não instala nem testa no emulador: testes automatizados no emulador Android são proibidos
# (AGENTS.md). Para conferir a build à mão: "Testar release no emulador.bat" -NoBuild.
#
# A chave de envio (upload key) NUNCA fica no repositório: o arquivo .env tem
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
# que o Godot lê do ambiente na hora de assinar.

param(
    [switch]$SkipChecks,
    [int]$VersionCode = 0,
    [string]$VersionName = '',
    [string]$KeystoreEnv = 'C:\src\keys\hyakki-release.env',
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [string]$AndroidSdk = 'C:\android-sdk'
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$out = Join-Path $project 'build\release'

function Step([string]$text) { Write-Host "== $text" -ForegroundColor Cyan }
function Fail([string]$text) { Write-Host "FALHOU: $text" -ForegroundColor Red; exit 1 }

# --- 1. Chave de assinatura ----------------------------------------------------------
Step 'Chave de assinatura'
if (-not (Test-Path $KeystoreEnv)) { Fail "não achei $KeystoreEnv (veja o README, seção Publicação)" }
foreach ($line in Get-Content $KeystoreEnv) {
    if ($line -match '^\s*([A-Z_]+)\s*=\s*(.+?)\s*$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
}
if (-not (Test-Path $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH)) { Fail 'keystore indicado no .env não existe' }
Write-Host "keystore: $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH (alias $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER)"

# --- 2. Versão -----------------------------------------------------------------------
$presets = Join-Path $project 'export_presets.cfg'
if ($VersionCode -gt 0 -or $VersionName) {
    Step 'Versão'
    $text = Get-Content $presets -Raw
    if ($VersionCode -gt 0) { $text = $text -replace 'version/code=\d+', "version/code=$VersionCode" }
    if ($VersionName) { $text = $text -replace 'version/name="[^"]*"', "version/name=`"$VersionName`"" }
    [IO.File]::WriteAllText($presets, $text)
    if ($VersionName) {
        $godotCfg = Join-Path $project 'project.godot'
        $p = (Get-Content $godotCfg -Raw) -replace 'config/version="[^"]*"', "config/version=`"$VersionName`""
        [IO.File]::WriteAllText($godotCfg, $p)
    }
}
$code = ([regex]::Match((Get-Content $presets -Raw), 'version/code=(\d+)')).Groups[1].Value
$name = ([regex]::Match((Get-Content $presets -Raw), 'version/name="([^"]*)"')).Groups[1].Value
Write-Host "versão $name (code $code)"

# --- 3. Verificações -----------------------------------------------------------------
if (-not $SkipChecks) {
    Step 'Verificações (tools\run_checks.ps1)'
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_checks.ps1') -Godot $Godot | Out-Host
    if ($LASTEXITCODE -ne 0) { Fail 'as verificações falharam; nada foi exportado' }
}

# --- 4. Export -----------------------------------------------------------------------
# O Godot 4.7 com os plugins Android às vezes não encerra depois do export Gradle: o script
# acompanha o log, espera o "[ DONE ] export" (ou um erro) e então fecha o processo.
function Export-Preset([string]$preset, [string]$target) {
    Step "Export: $preset"
    if (Test-Path $target) { Remove-Item $target -Force }
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    $log = "$target.log"
    $godotArgs = @('--headless', '--path', "`"$project`"")
    if (-not (Test-Path (Join-Path $project 'android\build'))) { $godotArgs += '--install-android-build-template' }
    $godotArgs += @('--export-release', "`"$preset`"", "`"$target`"")
    $proc = Start-Process -FilePath $Godot -ArgumentList $godotArgs -RedirectStandardOutput $log `
        -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden
    $deadline = (Get-Date).AddMinutes(30)
    $done = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $text = (Get-Content $log -Raw -ErrorAction SilentlyContinue) + (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue)
        if ($text -match 'DONE.*export') { $done = $true; break }
        if ($text -match 'BUILD FAILED|Project export for preset .* failed|Export failed') { break }
        if ($proc.HasExited) { $done = (Test-Path $target); break }
    }
    Start-Sleep -Seconds 2
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    if (-not $done -or -not (Test-Path $target)) {
        Get-Content "$log.err" -Tail 30 -ErrorAction SilentlyContinue | Write-Host
        Fail "export de '$preset' não gerou $target (log: $log)"
    }
    $mb = [math]::Round((Get-Item $target).Length / 1MB, 1)
    Write-Host "ok: $target ($mb MB)"
}

$aab = Join-Path $out 'hyakki-release.aab'
$apk = Join-Path $out 'hyakki-release.apk'
Export-Preset 'Android Release AAB' $aab
Export-Preset 'Android Release APK' $apk

# --- 5. Conferência ------------------------------------------------------------------
# Daqui em diante os códigos de saída são conferidos à mão: ferramentas nativas (adb, apksigner)
# escrevem avisos esperados no stderr, o que no PowerShell 5.1 com 'Stop' encerraria o script.
$ErrorActionPreference = 'Continue'
Step 'Conferência da assinatura e do conteúdo'
$buildTools = Get-ChildItem (Join-Path $AndroidSdk 'build-tools') | Sort-Object Name -Descending | Select-Object -First 1
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$certs = & $apksigner verify --print-certs $apk 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Write-Host $certs; Fail 'APK sem assinatura válida' }
if ($certs -match 'Android Debug') { Fail 'APK assinado com a chave de DEBUG' }
Write-Host ($certs -split "`n" | Select-String 'Signer #1 certificate DN|SHA-256' | Select-Object -First 2)
& jarsigner -verify $aab | Out-Null
if ($LASTEXITCODE -ne 0) { Fail 'AAB sem assinatura válida' }
Write-Host 'AAB assinado (jarsigner -verify ok)'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($aab)
$abis = $zip.Entries | Where-Object { $_.FullName -match '^base/lib/([^/]+)/' } |
    ForEach-Object { $Matches[1] } | Sort-Object -Unique
$debugSo = $zip.Entries | Where-Object { $_.FullName -match 'libgodot_android\.so' } |
    ForEach-Object { [math]::Round($_.Length / 1MB, 1) }
$zip.Dispose()
Write-Host "ABIs no AAB: $($abis -join ', ')  ·  libgodot_android.so por ABI: $($debugSo -join ' / ') MB"
Write-Host 'A Play Store entrega só a ABI do aparelho (o download fica bem menor que o AAB).'

Write-Host "PRONTO: envie $aab para a Play Console (teste interno ou fechado)." -ForegroundColor Green
Write-Host 'Para conferir à mão no emulador: "Testar release no emulador.bat" -NoBuild'
