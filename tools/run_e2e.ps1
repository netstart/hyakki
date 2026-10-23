# Testes de ponta a ponta no emulador Android: instala a build de debug, apaga os dados do app
# (instalação limpa), liga o roteiro E2E do jogo (scripts\app\e2e_driver.gd) e atende aos pedidos
# dele pelo logcat: toques e arrastos reais (adb input), botão voltar, ir para segundo plano,
# fechar e reabrir o app e capturas de tela. No fim gera um relatório em build\e2e-report\<data_hora>\.
#
#   powershell -ExecutionPolicy Bypass -File tools\run_e2e.ps1 [-NoBuild] [-NoOpen]
#
# Opções:
#   -NoBuild        usa o último APK de debug (build\hyakki-debug.apk) sem exportar de novo
#   -NoOpen         não abre o relatório no navegador no fim
#   -TimeoutMin N   limite total do roteiro (padrão 8 minutos)
#   -Avd nome       emulador a usar (padrão Redmi_Note_14_Pro_Plus_5G)
#
# ATENÇÃO: o teste começa com "pm clear" e apaga o save do jogo no emulador.

param(
    [switch]$NoBuild,
    [switch]$NoOpen,
    [int]$TimeoutMin = 8,
    [string]$Avd = 'Redmi_Note_14_Pro_Plus_5G',
    [string]$AndroidSdk = 'C:\android-sdk'
)

# Ferramentas nativas (adb, Gradle) escrevem avisos no stderr; os códigos são conferidos à mão.
$ErrorActionPreference = 'Continue'
$project = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $AndroidSdk 'platform-tools\adb.exe'
$package = 'dev.hyakki.prototype'
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$out = Join-Path $project "build\e2e-report\$stamp"
New-Item -ItemType Directory -Force $out | Out-Null
$started = Get-Date

function Step([string]$text) { Write-Host "== $text" -ForegroundColor Cyan }
function Fail([string]$text) { Write-Host "FALHOU: $text" -ForegroundColor Red; exit 1 }

# --- 1. Compilar e instalar ----------------------------------------------------------
Step 'Build de debug e instalação (tools\run_emulator.ps1)'
$emuArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'run_emulator.ps1'),
    '-NoLaunch', '-Avd', $Avd, '-AndroidSdk', $AndroidSdk)
if ($NoBuild) { $emuArgs += '-NoBuild' }
& powershell @emuArgs | Out-Host
if ($LASTEXITCODE -ne 0) { Fail 'build ou instalação falhou' }
$device = (& $adb devices) | Select-String 'emulator-\d+\s+device' | Select-Object -First 1
if (-not $device) { Fail 'nenhum emulador pronto' }
$serial = ($device -split '\s+')[0]
$size = ((& $adb -s $serial shell wm size) -join ' ') -replace '.*:\s*', ''

function Adb([string[]]$a) { & $adb -s $serial @a 2>&1 | Out-Null }

function Launch([string]$suite) {
    Adb @('shell', 'am', 'force-stop', $package)
    & $adb -s $serial shell "run-as $package sh -c 'mkdir -p files && echo $suite > files/e2e.txt'"
    Adb @('shell', 'monkey', '-p', $package, '-c', 'android.intent.category.LAUNCHER', '1')
}

# --- 2. Roteiro ----------------------------------------------------------------------
Step 'Instalação limpa (pm clear) e roteiro E2E'
Adb @('shell', 'pm', 'clear', $package)
Adb @('logcat', '-c')
$logFile = Join-Path $out 'logcat.txt'
$logcat = Start-Process -FilePath $adb -ArgumentList @('-s', $serial, 'logcat', '-v', 'time',
    'godot:V', 'GodotPlugin:V', 'AndroidRuntime:E', '*:S') -RedirectStandardOutput $logFile `
    -RedirectStandardError "$logFile.err" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 1
Launch 'full'

$suites = New-Object System.Collections.Generic.List[object]
$shots = New-Object System.Collections.Generic.List[object]
$errors = New-Object System.Collections.Generic.List[string]
$suite = $null
$stepName = ''
$pendingRelaunch = ''
$finished = $false
$read = 0
$shotIndex = 0
$deadline = $started.AddMinutes($TimeoutMin)

function Add-Check([bool]$ok, [string]$text) {
    if (-not $suite) { return }
    $suite.Checks.Add([pscustomobject]@{ Step = $stepName; Ok = $ok; Text = $text })
    if ($ok) { Write-Host "  ok  $text" -ForegroundColor Green } else { Write-Host "  FALHOU  $text" -ForegroundColor Red }
}

while (-not $finished -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
    $lines = @(Get-Content $logFile -Encoding UTF8 -ErrorAction SilentlyContinue)
    for (; $read -lt $lines.Count; $read++) {
        $line = $lines[$read]
        if ($line -match 'SCRIPT ERROR|USER ERROR|FATAL EXCEPTION|E/godot.*ERROR') { $errors.Add($line.Trim()) }
        if ($line -notmatch 'E2E (BEGIN|STEP|OK|FALHOU|HOST|END) ?(.*)$') { continue }
        $kind = $Matches[1]
        $arg = $Matches[2].Trim()
        switch ($kind) {
            'BEGIN' {
                $suite = [pscustomobject]@{ Name = $arg; Checks = New-Object System.Collections.Generic.List[object]; Ended = $false }
                $suites.Add($suite)
                $stepName = ''
                Write-Host "-- roteiro: $arg" -ForegroundColor Cyan
            }
            'STEP' { $stepName = $arg; Write-Host " [$arg]" }
            'OK' { Add-Check $true $arg }
            'FALHOU' { Add-Check $false $arg }
            'END' {
                if ($suite) { $suite.Ended = $true }
                if ($pendingRelaunch) {
                    Write-Host "-- fechando e reabrindo o app ($pendingRelaunch)"
                    Launch $pendingRelaunch
                    $pendingRelaunch = ''
                } else { $finished = $true }
            }
            'HOST' {
                $p = $arg -split '\s+'
                switch ($p[0]) {
                    'tap' { Adb @('shell', 'input', 'tap', $p[1], $p[2]) }
                    'swipe' { Adb @('shell', 'input', 'swipe', $p[1], $p[2], $p[3], $p[4], $p[5]) }
                    'key' { Adb @('shell', 'input', 'keyevent', "KEYCODE_$($p[1])") }
                    'home' {
                        Adb @('shell', 'input', 'keyevent', 'KEYCODE_HOME')
                        Start-Sleep -Seconds 2
                        Adb @('shell', 'monkey', '-p', $package, '-c', 'android.intent.category.LAUNCHER', '1')
                    }
                    'relaunch' { $pendingRelaunch = $p[1] }
                    'shot' {
                        $shotIndex++
                        $name = '{0:D2}_{1}_{2}.png' -f $shotIndex, $suite.Name, $p[1]
                        & cmd /c "`"$adb`" -s $serial exec-out screencap -p > `"$(Join-Path $out $name)`""
                        $shots.Add([pscustomobject]@{ File = $name; Suite = $suite.Name; Name = $p[1] })
                    }
                }
            }
        }
        if ($finished) { break }
    }
    # App fechou sozinho (crash) fora de um reinício pedido pelo roteiro.
    if (-not $pendingRelaunch -and $suite -and -not $suite.Ended -and $read -gt 0) {
        $appPid = ((& $adb -s $serial shell pidof $package) -join '').Trim()
        if (-not $appPid) {
            Start-Sleep -Seconds 3
            if (-not ((& $adb -s $serial shell pidof $package) -join '').Trim()) {
                $errors.Add('o app parou de rodar no meio do roteiro')
                break
            }
        }
    }
}
$timedOut = -not $finished
Stop-Process -Id $logcat.Id -Force -ErrorAction SilentlyContinue
& $adb -s $serial shell am force-stop $package

# --- 3. Relatório --------------------------------------------------------------------
$all = @($suites | ForEach-Object { $_.Checks })
$failed = @($all | Where-Object { -not $_.Ok })
$ok = -not $timedOut -and $failed.Count -eq 0 -and $errors.Count -eq 0 -and $suites.Count -ge 2 `
    -and -not ($suites | Where-Object { -not $_.Ended })
$verdict = if ($ok) { 'TUDO OK' } else { 'FALHOU' }
$total = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
$summary = "$($all.Count) verificações, $($failed.Count) falhas, $($errors.Count) erros no logcat" +
    $(if ($timedOut) { ', tempo esgotado' } else { '' })

function Esc([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
$html = New-Object System.Text.StringBuilder
[void]$html.Append(@"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>E2E Hyakki $stamp</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root{--bg:#fff;--fg:#1d1d1f;--mut:#666;--line:#ddd;--ok:#1a7f37;--bad:#c62828;--code:#f5f5f5}
@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#e8e8e8;--mut:#999;--line:#333;--ok:#4cc265;--bad:#ff6b6b;--code:#222}}
body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;max-width:1100px;margin:0 auto;padding:24px 16px}
.meta{color:var(--mut);margin-bottom:20px}.ok{color:var(--ok);font-weight:600}.bad{color:var(--bad);font-weight:600}
table{border-collapse:collapse;width:100%;margin-bottom:24px}td,th{border-bottom:1px solid var(--line);padding:5px 8px;text-align:left}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:12px}
figure{margin:0}figure img{width:100%;border:1px solid var(--line);border-radius:4px}figcaption{color:var(--mut);font-size:13px}
pre{background:var(--code);padding:10px;overflow:auto;max-height:300px;font-size:12px;white-space:pre-wrap}
</style></head><body>
<h1>E2E no emulador — <span class="$(if ($ok) { 'ok' } else { 'bad' })">$verdict</span></h1>
<div class="meta">$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') · ${total}s · $serial ($size) · $(Esc $summary) · <a href="logcat.txt">logcat</a></div>
"@)
if ($errors.Count) {
    [void]$html.Append("<h2 class=`"bad`">Erros no logcat</h2><pre>$(Esc ($errors -join "`n"))</pre>")
}
foreach ($s in $suites) {
    [void]$html.Append("<h2>Roteiro: $(Esc $s.Name)$(if (-not $s.Ended) { ' <span class="bad">(não terminou)</span>' })</h2>")
    [void]$html.Append('<table><tr><th>Etapa</th><th>Resultado</th><th>Verificação</th></tr>')
    foreach ($c in $s.Checks) {
        $cls = if ($c.Ok) { 'ok' } else { 'bad' }
        [void]$html.Append("<tr><td>$(Esc $c.Step)</td><td class=`"$cls`">$(if ($c.Ok) { 'ok' } else { 'falhou' })</td><td>$(Esc $c.Text)</td></tr>")
    }
    [void]$html.Append('</table><div class="grid">')
    foreach ($shot in $shots | Where-Object { $_.Suite -eq $s.Name }) {
        [void]$html.Append("<figure><a href=`"$($shot.File)`"><img src=`"$($shot.File)`" loading=`"lazy`"></a><figcaption>$(Esc $shot.Name)</figcaption></figure>")
    }
    [void]$html.Append('</div>')
}
[void]$html.Append('</body></html>')
$utf8 = New-Object Text.UTF8Encoding $true
$report = Join-Path $out 'relatorio.html'
[IO.File]::WriteAllText($report, $html.ToString(), $utf8)
# Resumo para o tools\run_tests_report.ps1.
$json = [pscustomobject]@{ ok = $ok; summary = $summary; report = $report; errors = @($errors)
    checks = @($all | ForEach-Object { [pscustomobject]@{ ok = $_.Ok; text = "[$($_.Step)] $($_.Text)" } }) }
[IO.File]::WriteAllText((Join-Path $out 'resumo.json'), ($json | ConvertTo-Json -Depth 4), $utf8)

Write-Host ''
Write-Host "Relatório: $report" -ForegroundColor Cyan
Write-Host "$verdict — $summary (${total}s)" -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
if (-not $NoOpen) { Start-Process $report }
if (-not $ok) { exit 1 }
