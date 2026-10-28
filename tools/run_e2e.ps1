# Testes de ponta a ponta no emulador Android: instala a build de debug, apaga os dados do app
# (instalação limpa), liga o roteiro E2E do jogo (scripts\app\e2e_driver.gd) e atende aos pedidos
# dele pelo logcat: toques e arrastos reais (adb input), botão voltar, ir para segundo plano,
# fechar e reabrir o app e capturas de tela. No fim gera um relatório em build\e2e-report\<data_hora>\.
#
# Por padrão roda nos quatro aparelhos-alvo, um depois do outro (Redmi Note 14 Pro+ 5G, Samsung
# Galaxy M55 5G, Google Pixel 7 e Samsung Galaxy A15; tabela em tools\test_devices.ps1): desliga o
# emulador anterior, liga o próximo, liga o recorte de câmera emulado e roda o roteiro inteiro. Cada
# aparelho ganha a sua pasta (build\e2e-report\<data_hora>\<AVD>\) e o relatório da raiz junta tudo.
#
#   powershell -ExecutionPolicy Bypass -File tools\run_e2e.ps1 [-NoBuild] [-NoOpen] [-Avd all|nome|nome1,nome2]
#
# Opções:
#   -NoBuild        usa o último APK de debug (build\hyakki-debug.apk) sem exportar de novo. Sem ele, o APK é
#                   exportado uma vez só, antes do primeiro aparelho (com o emulador já ligando), e todos
#                   reinstalam o mesmo; se o export falhar, tudo para com erro
#   -NoChecks       não roda o tools\run_checks.ps1 em paralelo (por padrão ele roda em segundo plano logo
#                   depois do export, com log em run_checks.log na pasta do relatório; se falhar, o E2E falha)
#   -NoOpen         não abre o relatório no navegador no fim
#   -TimeoutMin N   limite do roteiro em cada aparelho (padrão 8 minutos, contados da abertura do jogo)
#   -StartTimeoutSec N  espera pelo início de cada roteiro; sem ele, o app é aberto de novo (padrão 90 s, 3 tentativas)
#   -Avd X          "all" (padrão: Redmi_Note_14_Pro_Plus_5G, Galaxy_M55_5G, Pixel_7 e Galaxy_A15), um AVD só ou
#                   uma lista separada por vírgula. Os AVDs são criados por tools\create_test_avds.ps1.
#   -OutDir pasta   (interno) pasta do relatório de um aparelho
#   -Retry          (interno) segunda tentativa depois de o emulador travar no meio do roteiro
#
# ATENÇÃO: o teste começa com "pm clear" e apaga o save do jogo em cada emulador.

param(
    [switch]$NoBuild,
    [switch]$NoChecks,
    [switch]$NoOpen,
    [int]$TimeoutMin = 8,
    [int]$StartTimeoutSec = 90,
    [string]$Avd = 'all',
    [string]$OutDir = '',
    [switch]$Retry,
    [string]$AndroidSdk = 'C:\android-sdk'
)

# Ferramentas nativas (adb, Gradle) escrevem avisos no stderr; os códigos são conferidos à mão.
$ErrorActionPreference = 'Continue'
$project = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $AndroidSdk 'platform-tools\adb.exe'
$package = 'io.github.netstart.hyakki'
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$out = if ($OutDir) { $OutDir } else { Join-Path $project "build\e2e-report\$stamp" }
New-Item -ItemType Directory -Force $out | Out-Null
$started = Get-Date

function Step([string]$text) { Write-Host "== $text" -ForegroundColor Cyan }
function Fail([string]$text) { Write-Host "FALHOU: $text" -ForegroundColor Red; exit 1 }
function Esc([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
$utf8 = New-Object Text.UTF8Encoding $true

. (Join-Path $PSScriptRoot 'test_devices.ps1')
$devices = @(Resolve-TestDevices $Avd)
if (-not $devices.Count) { Fail "nenhum AVD em -Avd '$Avd'" }

# --- Preparação: APK uma vez só e testes (run_checks) em paralelo ---------------------------------
# Ordem: liga o primeiro emulador (boot a frio, só CPU) -> exporta o APK (Godot) -> só então dispara o
# run_checks.ps1 num processo separado, enquanto o emulador termina de ligar, instala e roda o roteiro.
# Assim nunca há dois Godot ao mesmo tempo sobre o mesmo .godot\ (o export importa os assets; o
# "--import" do run_checks depois só confere). Os aparelhos (processos filhos) recebem -NoBuild -NoChecks.
if (-not $NoBuild) {
    Step 'Exportando o APK de debug (uma vez para todos os aparelhos)'
    if (-not (Test-AvdExists $devices[0].Avd)) { Fail "o AVD $($devices[0].Avd) não existe; rode tools\create_test_avds.ps1" }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_emulator.ps1') `
        -BuildOnly -Avd $devices[0].Avd -AndroidSdk $AndroidSdk | Out-Host
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $project 'build\hyakki-debug.apk'))) {
        Fail 'o export do APK de debug falhou; o E2E foi interrompido (veja build\hyakki-debug.apk.log)'
    }
    $NoBuild = $true
}
$checksProc = $null
$checksLog = Join-Path $out 'run_checks.log'
if (-not $NoChecks) {
    Step "Testes (tools\run_checks.ps1) em segundo plano: $checksLog"
    $checksProc = Start-Process -FilePath 'powershell' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        "`"$(Join-Path $PSScriptRoot 'run_checks.ps1')`"") -RedirectStandardOutput $checksLog `
        -RedirectStandardError "$checksLog.err" -PassThru -WindowStyle Hidden
    # Guarda o handle já: sem isso o PowerShell 5.1 perde o ExitCode de processos do Start-Process.
    $null = $checksProc.Handle
    $checksStarted = Get-Date
}

# Espera o run_checks (até 40 minutos) e devolve o resultado para o resumo e o relatório.
function Complete-Checks {
    if (-not $checksProc) { return $null }
    if (-not $checksProc.HasExited) { Step 'Esperando os testes (run_checks) terminarem' }
    $done = $checksProc.WaitForExit(40 * 60 * 1000)
    if (-not $done) { Stop-Process -Id $checksProc.Id -Force -ErrorAction SilentlyContinue }
    $text = @(Get-Content $checksLog -Encoding UTF8 -ErrorAction SilentlyContinue)
    $ok = $done -and $checksProc.ExitCode -eq 0 -and ($text -match '^TUDO OK')
    $bad = @($text | Where-Object { $_ -match 'FALHOU|SCRIPT ERROR|Parse Error' })
    $summary = if (-not $done) { 'tempo esgotado (40 min)' } elseif ($ok) { 'TUDO OK' } else { "FALHOU: $(($bad | Select-Object -First 3) -join ' | ')" }
    $seconds = [math]::Round(($(if ($done) { $checksProc.ExitTime } else { Get-Date }) - $checksStarted).TotalSeconds, 1)
    $color = if ($ok) { 'Green' } else { 'Red' }
    Write-Host "run_checks: $summary (${seconds}s; log: $checksLog)" -ForegroundColor $color
    [pscustomobject]@{ ok = [bool]$ok; summary = $summary; seconds = $seconds; log = $checksLog }
}

function Checks-Html($c) {
    if (-not $c) { return '' }
    $cls = if ($c.ok) { 'ok' } else { 'bad' }
    "<p>Testes (run_checks.ps1, em paralelo): <span class=`"$cls`">$(Esc $c.summary)</span> · $($c.seconds)s · " +
        "<a href=`"run_checks.log`">log</a></p>"
}

# --- 0. Vários aparelhos: um processo deste script por AVD e um relatório que junta tudo ---------
if ($devices.Count -gt 1) {
    $missing = @($devices | Where-Object { -not (Test-AvdExists $_.Avd) })
    if ($missing.Count) {
        Fail "AVD(s) não criado(s): $($missing.Avd -join ', '). Rode: powershell -ExecutionPolicy Bypass -File tools\create_test_avds.ps1"
    }
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($d in $devices) {
        Write-Host ''
        Step "Aparelho: $($d.Label) ($($d.Avd))"
        $devOut = Join-Path $out $d.Avd
        $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Avd', $d.Avd,
            '-OutDir', $devOut, '-NoOpen', '-TimeoutMin', $TimeoutMin, '-StartTimeoutSec', $StartTimeoutSec,
            '-AndroidSdk', $AndroidSdk, '-NoBuild', '-NoChecks')
        $t0 = Get-Date
        & powershell @childArgs | Out-Host
        $code = $LASTEXITCODE
        $resumo = Join-Path $devOut 'resumo.json'
        $r = if (Test-Path $resumo) { Get-Content $resumo -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
        $results.Add([pscustomobject]@{
            Device = $d; Ok = ($code -eq 0 -and $r -and $r.ok)
            Summary = $(if ($r) { $r.summary } else { "não gerou resumo (código $code; veja a saída acima)" })
            Size = $(if ($r -and $r.size) { $r.size } else { '' }); Cutout = $(if ($r -and $r.cutout) { $r.cutout } else { '' })
            Seconds = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1); Resumo = $r })
    }
    $checksResult = Complete-Checks
    $ok = -not ($results | Where-Object { -not $_.Ok }) -and (-not $checksResult -or $checksResult.ok)
    $verdict = if ($ok) { 'TUDO OK' } else { 'FALHOU' }
    $total = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    $okCount = @($results | Where-Object { $_.Ok }).Count
    $summary = "$okCount de $($results.Count) aparelhos ok: " +
        (($results | ForEach-Object { "$($_.Device.Label) $(if ($_.Ok) { 'ok' } else { 'FALHOU' })" }) -join ', ') +
        $(if ($checksResult) { "; run_checks $($checksResult.summary)" } else { '' })

    $html = New-Object System.Text.StringBuilder
    [void]$html.Append(@"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>E2E Hyakki $stamp</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root{--bg:#fff;--fg:#1d1d1f;--mut:#666;--line:#ddd;--ok:#1a7f37;--bad:#c62828}
@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#e8e8e8;--mut:#999;--line:#333;--ok:#4cc265;--bad:#ff6b6b}}
body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;max-width:1100px;margin:0 auto;padding:24px 16px}
.meta{color:var(--mut);margin-bottom:20px}.ok{color:var(--ok);font-weight:600}.bad{color:var(--bad);font-weight:600}
table{border-collapse:collapse;width:100%;margin-bottom:24px}td,th{border-bottom:1px solid var(--line);padding:5px 8px;text-align:left}
</style></head><body>
<h1>E2E nos aparelhos — <span class="$(if ($ok) { 'ok' } else { 'bad' })">$verdict</span></h1>
<div class="meta">$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') · ${total}s · $(Esc $summary)</div>
<table><tr><th>Aparelho</th><th>AVD</th><th>Tela</th><th>Recorte</th><th>Resultado</th><th>Resumo</th><th>Tempo</th></tr>
"@)
    foreach ($r in $results) {
        $link = "$($r.Device.Avd)/relatorio.html"
        [void]$html.Append("<tr><td><a href=`"$link`">$(Esc $r.Device.Label)</a></td><td>$(Esc $r.Device.Avd)</td><td>$(Esc $r.Size)</td>" +
            "<td>$(Esc $(if ($r.Cutout) { $r.Cutout } else { '—' }))</td><td class=`"$(if ($r.Ok) { 'ok' } else { 'bad' })`">$(if ($r.Ok) { 'ok' } else { 'falhou' })</td>" +
            "<td>$(Esc $r.Summary)</td><td>$($r.Seconds)s</td></tr>")
    }
    [void]$html.Append("</table>$(Checks-Html $checksResult)</body></html>")
    $report = Join-Path $out 'relatorio.html'
    [IO.File]::WriteAllText($report, $html.ToString(), $utf8)
    # Resumo combinado (lido pelo tools\run_tests_report.ps1): verificações com o aparelho na frente.
    $checks = @(); $errs = @()
    foreach ($r in $results) {
        $tag = "[$($r.Device.Label)]"
        if ($r.Resumo) {
            $checks += @($r.Resumo.checks | ForEach-Object { [pscustomobject]@{ ok = $_.ok; text = "$tag $($_.text)" } })
            $errs += @($r.Resumo.errors | ForEach-Object { "$tag $_" })
        }
        if (-not $r.Ok -and -not $r.Resumo) { $errs += "$tag $($r.Summary)" }
    }
    if ($checksResult -and -not $checksResult.ok) { $errs += "[run_checks] $($checksResult.summary)" }
    $json = [pscustomobject]@{ ok = [bool]$ok; summary = $summary; report = $report; errors = @($errs); checks = $checks
        run_checks = $checksResult
        devices = @($results | ForEach-Object { [pscustomobject]@{ avd = $_.Device.Avd; label = $_.Device.Label; ok = [bool]$_.Ok
            summary = $_.Summary; report = (Join-Path $out "$($_.Device.Avd)\relatorio.html") } }) }
    [IO.File]::WriteAllText((Join-Path $out 'resumo.json'), ($json | ConvertTo-Json -Depth 5), $utf8)

    Write-Host ''
    foreach ($r in $results) {
        Write-Host ("  {0,-24} {1,-7} {2}" -f $r.Device.Label, $(if ($r.Ok) { 'ok' } else { 'FALHOU' }), $r.Summary) `
            -ForegroundColor $(if ($r.Ok) { 'Green' } else { 'Red' })
    }
    Write-Host "Relatório: $report" -ForegroundColor Cyan
    Write-Host "$verdict — $summary (${total}s)" -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
    if (-not $NoOpen) { Start-Process $report }
    if (-not $ok) { exit 1 }
    exit 0
}

# --- Um aparelho -------------------------------------------------------------------------------
$Avd = $devices[0].Avd
$deviceLabel = $devices[0].Label

# --- 1. Compilar e instalar ----------------------------------------------------------
Step 'Build de debug e instalação (tools\run_emulator.ps1)'
$emuArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'run_emulator.ps1'),
    '-NoLaunch', '-Avd', $Avd, '-AndroidSdk', $AndroidSdk)
if ($NoBuild) { $emuArgs += '-NoBuild' }
& powershell @emuArgs | Out-Host
if ($LASTEXITCODE -ne 0) { Fail 'build ou instalação falhou' }
$serial = Wait-EmulatorFor $adb $Avd 1
if (-not $serial) { Fail "o emulador $Avd não está pronto" }
$size = ((& $adb -s $serial shell wm size) -join ' ') -replace '.*:\s*', ''
# run_emulator.ps1 já liga o recorte; aqui só confere qual ficou ativo (vai para o relatório).
$cutout = Set-EmulatorCutout $adb $serial $Avd
$wantCutout = (Get-TestDevice $Avd).Cutout
if ($wantCutout -and $cutout -ne $wantCutout) { Fail "o recorte de câmera '$wantCutout' não ficou ativo em $Avd" }
Write-Host "aparelho: $deviceLabel · $serial · $size$(if ($cutout) { " · recorte: $cutout" })"

# Comando no aparelho com tempo-limite; se o adb pendurar, o emulador travou (AGENTS.md, "Emulador travado").
$frozen = $false
function Adb([string[]]$a, [int]$Seconds = 30) {
    if ($script:frozen) { return }
    if ($null -eq (Invoke-AdbTimeout $adb (@('-s', $serial) + $a) $Seconds)) { $script:frozen = $true }
}

# Abre o jogo com o roteiro pedido e passa a esperar o "E2E BEGIN" dele (vigia da abertura no laço).
$launchSuite = ''
$launchedAt = Get-Date
$launchTries = 0
$waitingBegin = $false
function Launch([string]$suite) {
    if ($script:launchSuite -ne $suite) { $script:launchTries = 0 }
    $script:launchSuite = $suite
    $script:launchTries++
    $script:launchedAt = Get-Date
    $script:waitingBegin = $true
    $script:expectedSeq = 1
    Adb @('shell', 'am', 'force-stop', $package)
    Adb @('shell', "run-as $package sh -c 'mkdir -p files && echo $suite > files/e2e.txt'")
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
# Logcat inteiro (sistema e app), para investigar travadas e mortes do processo fora do Godot.
$fullLogFile = Join-Path $out 'logcat_completo.txt'
$fullLogcat = Start-Process -FilePath $adb -ArgumentList @('-s', $serial, 'logcat', '-v', 'threadtime') `
    -RedirectStandardOutput $fullLogFile -RedirectStandardError "$fullLogFile.err" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 1
Launch 'full'

$suites = New-Object System.Collections.Generic.List[object]
$shots = New-Object System.Collections.Generic.List[object]
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$nextStartCheck = Get-Date
$suite = $null
$stepName = ''
$pendingRelaunch = ''
$finished = $false
$read = 0
$shotIndex = 0
# Conta a partir da abertura do jogo: o boot do emulador (até 2 × 8 minutos, se travar e for
# religado) não pode comer o tempo do roteiro.
$deadline = (Get-Date).AddMinutes($TimeoutMin)

function Add-Check([bool]$ok, [string]$text) {
    if (-not $suite) { return }
    $suite.Checks.Add([pscustomobject]@{ Step = $stepName; Ok = $ok; Text = $text })
    if ($ok) { Write-Host "  ok  $text" -ForegroundColor Green } else { Write-Host "  FALHOU  $text" -ForegroundColor Red }
}

# Linhas do protocolo do roteiro: "E2E #<n> <tipo> <texto>". O logcat do Android às vezes perde linhas
# (com a máquina carregada o logd descarta mensagens); o jogo grava as mesmas linhas em
# files/e2e_log.txt, e um buraco na numeração (ou um silêncio longo) faz o script ler o que faltou de lá.
$protocol = 'E2E #(\d+) (BEGIN|STEP|OK|FALHOU|HOST|END) ?(.*)$'
$expectedSeq = 1
$lastProtocolAt = Get-Date
$nextCrashCheck = Get-Date
function Read-DriverLog {
    $text = Invoke-AdbTimeout $adb @('-s', $serial, 'shell', 'run-as', $package, 'cat', 'files/e2e_log.txt') 30
    @("$text" -split "`r?`n" | ForEach-Object {
        if ($_ -match $protocol) { [pscustomobject]@{ Seq = [int]$Matches[1]; Kind = $Matches[2]; Arg = $Matches[3].Trim() } }
    })
}

while (-not $finished -and -not $frozen -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
    $lines = @(Get-Content $logFile -Encoding UTF8 -ErrorAction SilentlyContinue)
    $entries = New-Object System.Collections.Generic.List[object]
    for (; $read -lt $lines.Count; $read++) {
        $line = $lines[$read]
        if ($line -match 'SCRIPT ERROR|USER ERROR|FATAL EXCEPTION|E/godot.*ERROR') { $errors.Add($line.Trim()) }
        if ($line -match $protocol) { $entries.Add([pscustomobject]@{ Seq = [int]$Matches[1]; Kind = $Matches[2]; Arg = $Matches[3].Trim() }) }
    }
    # Silêncio de 10 s com o roteiro rodando: confere no arquivo se a última linha (ex.: END) se perdeu.
    if (-not $entries.Count -and -not $waitingBegin -and ((Get-Date) - $lastProtocolAt).TotalSeconds -gt 10) {
        $lastProtocolAt = Get-Date
        foreach ($e in Read-DriverLog) { if ($e.Seq -ge $expectedSeq) { $entries.Add($e) } }
        if ($entries.Count) {
            $note = "o logcat perdeu $($entries.Count) linha(s) do roteiro (a partir da #$expectedSeq); lidas de files/e2e_log.txt"
            Write-Host "AVISO: $note" -ForegroundColor Yellow
            $warnings.Add($note)
        }
    }
    if ($entries.Count) { $lastProtocolAt = Get-Date }
    $queue = New-Object System.Collections.Generic.List[object]
    foreach ($e in $entries) {
        if ($e.Seq -lt $expectedSeq -or ($queue.Count -and $e.Seq -le $queue[$queue.Count - 1].Seq)) { continue }
        $last = if ($queue.Count) { $queue[$queue.Count - 1].Seq } else { $expectedSeq - 1 }
        if ($e.Seq -gt $last + 1) {
            $lost = @(Read-DriverLog | Where-Object { $_.Seq -gt $last -and $_.Seq -lt $e.Seq })
            $note = "o logcat perdeu $($e.Seq - $last - 1) linha(s) do roteiro (#$($last + 1) a #$($e.Seq - 1)); lidas de files/e2e_log.txt"
            Write-Host "AVISO: $note" -ForegroundColor Yellow
            $warnings.Add($note)
            foreach ($l in $lost) { $queue.Add($l) }
        }
        $queue.Add($e)
    }
    foreach ($e in $queue) {
        $expectedSeq = $e.Seq + 1
        $kind = $e.Kind
        $arg = $e.Arg
        switch ($kind) {
            'BEGIN' {
                $suite = [pscustomobject]@{ Name = $arg; Checks = New-Object System.Collections.Generic.List[object]; Ended = $false }
                $suites.Add($suite)
                $waitingBegin = $false
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
                        # Captura com tempo-limite; pendurada, encerra o cmd e o adb filho.
                        $cap = Start-Process cmd -ArgumentList "/c `"`"$adb`" -s $serial exec-out screencap -p > `"$(Join-Path $out $name)`"`"" `
                            -PassThru -WindowStyle Hidden
                        if (-not $cap.WaitForExit(30000)) {
                            Get-CimInstance Win32_Process -Filter "ParentProcessId = $($cap.Id)" -ErrorAction SilentlyContinue |
                                ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                            Stop-Process -Id $cap.Id -Force -ErrorAction SilentlyContinue
                            $frozen = $true
                        }
                        $shots.Add([pscustomobject]@{ File = $name; Suite = $suite.Name; Name = $p[1] })
                    }
                }
            }
        }
        if ($finished -or $frozen) { break }
    }
    # App fechou sozinho (crash) fora de um reinício pedido pelo roteiro.
    if (-not $frozen -and -not $pendingRelaunch -and $suite -and -not $suite.Ended -and $read -gt 0 `
            -and (Get-Date) -ge $nextCrashCheck) {
        $nextCrashCheck = (Get-Date).AddSeconds(3)
        $appPid = Invoke-AdbTimeout $adb @('-s', $serial, 'shell', 'pidof', $package) 30
        if ($null -ne $appPid -and -not $appPid.Trim()) {
            Start-Sleep -Seconds 3
            $appPid = Invoke-AdbTimeout $adb @('-s', $serial, 'shell', 'pidof', $package) 30
            if ($null -ne $appPid -and -not $appPid.Trim()) {
                $errors.Add('o app parou de rodar no meio do roteiro')
                break
            }
        }
        if ($null -eq $appPid) { $frozen = $true }
    }
    # Vigia da abertura: o jogo foi aberto mas o roteiro não começou (o processo morreu no boot ou
    # ficou parado antes do roteiro). Anota o estado e abre de novo, até 3 tentativas por roteiro.
    if (-not $frozen -and $waitingBegin -and (Get-Date) -ge $nextStartCheck) {
        $nextStartCheck = (Get-Date).AddSeconds(5)
        $waited = ((Get-Date) - $launchedAt).TotalSeconds
        $dead = $false
        if ($waited -gt 20) {
            $appPid = Invoke-AdbTimeout $adb @('-s', $serial, 'shell', 'pidof', $package) 30
            if ($null -eq $appPid) { $frozen = $true } elseif (-not $appPid.Trim()) { $dead = $true }
        }
        if (-not $frozen -and ($dead -or $waited -gt $StartTimeoutSec)) {
            $why = if ($dead) { 'o app fechou antes de começar o roteiro' } else { "o roteiro não começou em $StartTimeoutSec s" }
            $focus = ((Invoke-AdbTimeout $adb @('-s', $serial, 'shell', 'dumpsys', 'window') 30) -split "`r?`n" |
                Select-String 'mCurrentFocus' | Select-Object -First 1)
            $note = "$why (roteiro $launchSuite, tentativa $launchTries; $("$focus".Trim()))"
            Write-Host "AVISO: $note" -ForegroundColor Yellow
            $warnings.Add($note)
            if ($launchTries -ge 3) { $errors.Add("$why (3 tentativas; veja logcat_completo.txt)"); break }
            Launch $launchSuite
        }
    }
}
$timedOut = -not $finished
Stop-Process -Id $logcat.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $fullLogcat.Id -Force -ErrorAction SilentlyContinue

# Emulador travou no meio do roteiro: desliga à força, liga de novo e refaz o roteiro naquele AVD
# (uma vez; run_emulator.ps1 religa o emulador e reinstala o mesmo APK).
if ($frozen) {
    if ($Retry) { Fail "o emulador $Avd parou de responder de novo depois de reiniciado" }
    Write-Host "O emulador $Avd parou de responder no meio do roteiro: desligando à força, ligando de novo e refazendo o roteiro" -ForegroundColor Yellow
    Stop-EmulatorProcess $adb $Avd
    $retryArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Avd', $Avd, '-OutDir', $out,
        '-NoBuild', '-NoChecks', '-Retry', '-TimeoutMin', $TimeoutMin, '-StartTimeoutSec', $StartTimeoutSec, '-AndroidSdk', $AndroidSdk)
    if ($NoOpen) { $retryArgs += '-NoOpen' }
    & powershell @retryArgs | Out-Host
    $code = $LASTEXITCODE
    $checksResult = Complete-Checks
    if ($checksResult -and -not $checksResult.ok) { exit 1 }
    exit $code
}
Adb @('shell', 'am', 'force-stop', $package)

# --- 3. Relatório --------------------------------------------------------------------
$all = @($suites | ForEach-Object { $_.Checks })
$failed = @($all | Where-Object { -not $_.Ok })
$checksResult = Complete-Checks
$ok = -not $timedOut -and $failed.Count -eq 0 -and $errors.Count -eq 0 -and $suites.Count -ge 2 `
    -and -not ($suites | Where-Object { -not $_.Ended }) -and (-not $checksResult -or $checksResult.ok)
$verdict = if ($ok) { 'TUDO OK' } else { 'FALHOU' }
$total = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
$summary = "$($all.Count) verificações, $($failed.Count) falhas, $($errors.Count) erros no logcat" +
    $(if ($timedOut) { ', tempo esgotado' } else { '' }) +
    $(if ($checksResult) { "; run_checks $($checksResult.summary)" } else { '' })

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
<h1>E2E no emulador ($(Esc $deviceLabel)) — <span class="$(if ($ok) { 'ok' } else { 'bad' })">$verdict</span></h1>
<div class="meta">$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') · ${total}s · $(Esc $Avd) · $serial ($size$(if ($cutout) { ", recorte $cutout" })) · $(Esc $summary) · <a href="logcat.txt">logcat</a></div>
"@)
if ($errors.Count) {
    [void]$html.Append("<h2 class=`"bad`">Erros no logcat</h2><pre>$(Esc ($errors -join "`n"))</pre>")
}
if ($warnings.Count) {
    [void]$html.Append("<h2>Avisos (app aberto de novo)</h2><pre>$(Esc ($warnings -join "`n"))</pre>")
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
[void]$html.Append("$(Checks-Html $checksResult)</body></html>")
$report = Join-Path $out 'relatorio.html'
[IO.File]::WriteAllText($report, $html.ToString(), $utf8)
# Resumo para o tools\run_tests_report.ps1 (e para o modo de vários aparelhos acima).
$json = [pscustomobject]@{ ok = $ok; summary = $summary; report = $report; errors = @($errors); warnings = @($warnings)
    run_checks = $checksResult
    avd = $Avd; device = $deviceLabel; size = $size; cutout = $cutout
    checks = @($all | ForEach-Object { [pscustomobject]@{ ok = $_.Ok; text = "[$($_.Step)] $($_.Text)" } }) }
[IO.File]::WriteAllText((Join-Path $out 'resumo.json'), ($json | ConvertTo-Json -Depth 4), $utf8)

Write-Host ''
Write-Host "Relatório: $report" -ForegroundColor Cyan
Write-Host "$verdict — $summary (${total}s)" -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
if (-not $NoOpen) { Start-Process $report }
if (-not $ok) { exit 1 }
exit 0
