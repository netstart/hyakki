# Roda todos os testes automatizados e gera um relatório completo em build\test-report\<data_hora>\:
#   relatorio.html   resumo por etapa, cada verificação (ok/falhou), desempenho e o log de cada etapa
#   relatorio.md     o mesmo resumo em texto
#   *.log            saída completa de cada etapa
#
#   powershell -ExecutionPolicy Bypass -File tools\run_tests_report.ps1 [-NoOpen] [-SkipStress] [-E2E]
#
# Etapas: importação (sintaxe), lint, regras puras, textos/i18n, licenças, ficha da loja,
# integração, determinismo (1x/2x/3x), estresse (500 inimigos) e, com -E2E, ponta a ponta no
# emulador. Mesmas de run_checks.ps1, mas com cada verificação listada (testes GDScript rodam com
# --verbose) e o relatório salvo.
#
# Opções:
#   -NoOpen       não abre o relatório no navegador no fim
#   -SkipStress   pula o teste de estresse (o mais lento)
#   -E2E          também roda os testes de ponta a ponta no emulador (tools\run_e2e.ps1; apaga o save
#                 do emulador e leva alguns minutos a mais)

param(
    [switch]$NoOpen,
    [switch]$SkipStress,
    [switch]$E2E,
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' })
)

# Godot, Python e gdlint escrevem avisos no stderr; os códigos de saída são conferidos à mão.
$ErrorActionPreference = 'Continue'
# Saída capturada de Godot e Python (-X utf8) em UTF-8; sem isso os acentos do Python se perdem.
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$project = Split-Path -Parent $PSScriptRoot
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$out = Join-Path $project "build\test-report\$stamp"
New-Item -ItemType Directory -Force $out | Out-Null
$results = New-Object System.Collections.Generic.List[object]
$started = Get-Date

function Step([string]$text) { Write-Host "== $text" -ForegroundColor Cyan }

# Roda um comando, salva a saída em <id>.log e devolve as linhas e o código de saída.
function Invoke-Logged([string]$id, [scriptblock]$command) {
    $t0 = Get-Date
    $lines = @(& $command 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    [IO.File]::WriteAllLines((Join-Path $out "$id.log"), [string[]]$lines, (New-Object Text.UTF8Encoding $true))
    return @{ Lines = $lines; Code = $code; Seconds = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1) }
}

function Add-Result([string]$id, [string]$name, [string]$status, $run, [string]$summary,
        [string[]]$passed = @(), [string[]]$failures = @()) {
    $results.Add([pscustomobject]@{
        Id = $id; Name = $name; Status = $status; Seconds = $run.Seconds; Summary = $summary
        Passed = $passed; Failures = $failures; Log = $run.Lines })
    $color = @{ ok = 'Green'; falhou = 'Red'; pulado = 'Yellow' }[$status]
    Write-Host ("  {0}: {1} ({2}s)" -f $status.ToUpper(), $summary, $run.Seconds) -ForegroundColor $color
    foreach ($f in $failures | Select-Object -First 10) { Write-Host "    $f" -ForegroundColor Red }
}

function Godot([string[]]$GodotArgs) { & $Godot --headless --path $project @GodotArgs }

# Testes GDScript: "ok: x" / "FALHOU: x" por verificação e "N verificações, M falhas" no fim.
function Add-GodotTests([string]$id, [string]$name, $run) {
    $passed = @($run.Lines | Where-Object { $_ -match '^ok: ' } | ForEach-Object { $_.Substring(4) })
    $failures = @($run.Lines | Where-Object { $_ -match 'FALHOU: |SCRIPT ERROR|Parse Error' })
    $total = $run.Lines | Where-Object { $_ -match '^\d+ verificações' } | Select-Object -Last 1
    $ok = $run.Code -eq 0 -and $failures.Count -eq 0 -and $total
    if (-not $total) { $total = 'não chegou ao fim (veja o log)' }
    Add-Result $id $name $(if ($ok) { 'ok' } else { 'falhou' }) $run $total $passed $failures
}

# --- Etapas --------------------------------------------------------------------------
Step '1. Importação (sintaxe de todos os scripts)'
$run = Invoke-Logged 'importacao' { Godot @('--import') }
$errs = @($run.Lines | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' })
Add-Result 'importacao' 'Importação' $(if ($errs) { 'falhou' } else { 'ok' }) $run `
    $(if ($errs) { "$($errs.Count) erro(s)" } else { 'sem erros de script' }) @() $errs

Step '2. Lint (gdlint)'
if (Get-Command gdlint -ErrorAction SilentlyContinue) {
    $run = Invoke-Logged 'lint' { gdlint (Join-Path $project 'scripts') (Join-Path $project 'tests') }
    $problems = @($run.Lines | Where-Object { $_ -match ':\d+: Error:' })
    $last = ($run.Lines | Where-Object { $_ } | Select-Object -Last 1)
    Add-Result 'lint' 'Lint (gdlint)' $(if ($run.Code -eq 0) { 'ok' } else { 'falhou' }) $run $last @() $problems
} else {
    Add-Result 'lint' 'Lint (gdlint)' 'pulado' @{ Seconds = 0; Lines = @() } 'gdlint não instalado (pip install "gdtoolkit==4.*")'
}

Step '3. Regras puras'
Add-GodotTests 'regras' 'Regras puras' (Invoke-Logged 'regras' { Godot @('--script', 'res://tests/run_tests.gd', '--', '--verbose') })

foreach ($py in @(
        @{ Id = 'i18n'; Name = 'Textos (i18n)'; Args = @((Join-Path $PSScriptRoot 'build_i18n.py'), '--check') },
        @{ Id = 'licencas'; Name = 'Licenças'; Args = @((Join-Path $PSScriptRoot 'check_licenses.py')) },
        @{ Id = 'loja'; Name = 'Ficha da loja'; Args = @((Join-Path $PSScriptRoot 'check_store_listing.py')) })) {
    Step "4. $($py.Name)"
    $pyArgs = $py.Args
    $run = Invoke-Logged $py.Id { python -I -X utf8 @pyArgs }
    $problems = @($run.Lines | Where-Object { $_ -match 'ERRO|ERROR|FALH|faltando|missing|Traceback' })
    $last = ($run.Lines | Where-Object { $_ } | Select-Object -Last 1)
    Add-Result $py.Id $py.Name $(if ($run.Code -eq 0) { 'ok' } else { 'falhou' }) $run $last @() $problems
}

Step '5. Integração'
Add-GodotTests 'integracao' 'Integração' (Invoke-Logged 'integracao' { Godot @('res://tests/integration_tests.tscn', '--', '--verbose') })

Step '6. Determinismo (1x, 2x, 3x)'
$t0 = Get-Date
$detLines = @(); $hashes = @(); $detFail = @(); $detPass = @()
foreach ($speed in 1, 2, 3) {
    $run = Invoke-Logged "determinismo_${speed}x" { Godot @('--fixed-fps', '60', '--', '--bot', '--seed=7', "--speed=$speed", '--quit-at=90') }
    $detLines += "---- ${speed}x ----"; $detLines += $run.Lines
    $detFail += @($run.Lines | Where-Object { $_ -match 'SCRIPT ERROR' })
    $line = $run.Lines | Where-Object { $_ -match '^FIM ' } | Select-Object -Last 1
    if (-not $line) { $detFail += "${speed}x: a partida não chegou ao FIM"; continue }
    $detPass += "${speed}x: $line"
    $hashes += ($line -replace '^.*hash=', '')
}
$same = $hashes.Count -eq 3 -and @($hashes | Select-Object -Unique).Count -eq 1
if ($hashes.Count -eq 3 -and -not $same) { $detFail += 'o estado final mudou com a velocidade' }
Add-Result 'determinismo' 'Determinismo' $(if ($same -and -not $detFail) { 'ok' } else { 'falhou' }) `
    @{ Seconds = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1); Lines = $detLines } `
    $(if ($same) { 'mesmo estado nas três velocidades' } else { 'estados diferentes ou incompletos' }) $detPass $detFail

Step '7. Estresse (500 inimigos)'
if ($SkipStress) {
    Add-Result 'estresse' 'Estresse' 'pulado' @{ Seconds = 0; Lines = @() } 'pulado com -SkipStress'
} else {
    $run = Invoke-Logged 'estresse' { Godot @('--fixed-fps', '60', '--', '--bot', '--seed=7', '--stress=500', '--log-every=10', '--quit-at=30') }
    $perf = @($run.Lines | Where-Object { $_ -match '^DESEMPENHO|pior por sistema' })
    $errs = @($run.Lines | Where-Object { $_ -match 'SCRIPT ERROR' })
    $summary = if ($perf) { ($perf | Select-Object -Last 1) } else { 'sem linha de DESEMPENHO' }
    Add-Result 'estresse' 'Estresse' $(if ($errs -or -not $perf) { 'falhou' } else { 'ok' }) $run $summary $perf $errs
}

Step '8. Ponta a ponta no emulador (E2E)'
if ($E2E) {
    $run = Invoke-Logged 'e2e' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_e2e.ps1') -NoOpen }
    $e2eDir = Get-ChildItem (Join-Path $project 'build\e2e-report') -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object -Last 1
    $resumo = if ($e2eDir) { Join-Path $e2eDir.FullName 'resumo.json' }
    if ($resumo -and (Test-Path $resumo) -and $e2eDir.LastWriteTime -ge $started) {
        $e = Get-Content $resumo -Raw -Encoding UTF8 | ConvertFrom-Json
        $passed = @($e.checks | Where-Object { $_.ok } | ForEach-Object { $_.text })
        $failures = @($e.checks | Where-Object { -not $_.ok } | ForEach-Object { $_.text }) + @($e.errors)
        Add-Result 'e2e' 'Ponta a ponta (emulador)' $(if ($e.ok) { 'ok' } else { 'falhou' }) $run `
            "$($e.summary) · relatório: $($e.report)" $passed $failures
    } else {
        Add-Result 'e2e' 'Ponta a ponta (emulador)' 'falhou' $run 'o roteiro não gerou resumo (veja o log)' @() `
            @($run.Lines | Where-Object { $_ -match 'FALHOU' })
    }
} else {
    Add-Result 'e2e' 'Ponta a ponta (emulador)' 'pulado' @{ Seconds = 0; Lines = @() } 'use -E2E para rodar no emulador'
}

# --- Relatório -----------------------------------------------------------------------
$total = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
$failedSteps = @($results | Where-Object { $_.Status -eq 'falhou' })
$verdict = if ($failedSteps) { 'FALHOU' } else { 'TUDO OK' }
$commit = (git -C $project rev-parse --short HEAD 2>$null) -join ''
$dirty = if ((git -C $project status --porcelain 2>$null)) { ' (com alterações locais)' } else { '' }
$godotVersion = ((& $Godot --version 2>$null) -join '').Trim()
$checks = ($results | ForEach-Object { $_.Passed.Count + $_.Failures.Count } | Measure-Object -Sum).Sum

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Relatório de testes do Hyakki — $verdict")
[void]$md.AppendLine('')
[void]$md.AppendLine("- Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')  ·  duração: ${total}s")
[void]$md.AppendLine("- Commit: $commit$dirty  ·  Godot $godotVersion")
[void]$md.AppendLine("- Etapas: $($results.Count) ($(@($results | Where-Object Status -eq 'ok').Count) ok, $($failedSteps.Count) falharam, $(@($results | Where-Object Status -eq 'pulado').Count) puladas)  ·  itens verificados: $checks")
[void]$md.AppendLine('')
[void]$md.AppendLine('| Etapa | Resultado | Tempo | Resumo |')
[void]$md.AppendLine('|---|---|---|---|')
foreach ($r in $results) { [void]$md.AppendLine("| $($r.Name) | $($r.Status) | $($r.Seconds)s | $($r.Summary -replace '\|', '/') |") }
foreach ($r in $results | Where-Object { $_.Failures }) {
    [void]$md.AppendLine(''); [void]$md.AppendLine("## Falhas: $($r.Name)")
    foreach ($f in $r.Failures) { [void]$md.AppendLine("- $f") }
}
$utf8 = New-Object Text.UTF8Encoding $true
[IO.File]::WriteAllText((Join-Path $out 'relatorio.md'), $md.ToString(), $utf8)

function Esc([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
$html = New-Object System.Text.StringBuilder
[void]$html.Append(@"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Testes Hyakki $stamp</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root{--bg:#fff;--fg:#1d1d1f;--mut:#666;--line:#ddd;--ok:#1a7f37;--bad:#c62828;--skip:#9a6700;--code:#f5f5f5}
@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#e8e8e8;--mut:#999;--line:#333;--ok:#4cc265;--bad:#ff6b6b;--skip:#e3b341;--code:#222}}
body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;max-width:1000px;margin:0 auto;padding:24px 16px}
h1{margin:0 0 4px}.meta{color:var(--mut);margin-bottom:20px}
table{border-collapse:collapse;width:100%;margin-bottom:24px}td,th{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left;vertical-align:top}
.ok{color:var(--ok);font-weight:600}.falhou{color:var(--bad);font-weight:600}.pulado{color:var(--skip);font-weight:600}
details{border:1px solid var(--line);border-radius:6px;padding:8px 12px;margin:8px 0}summary{cursor:pointer;font-weight:600}
ul{margin:6px 0;padding-left:20px}li.f{color:var(--bad)}
pre{background:var(--code);padding:10px;overflow:auto;max-height:400px;font-size:12px;white-space:pre-wrap}
</style></head><body>
<h1>Testes do Hyakki — <span class="$(if ($failedSteps) { 'falhou' } else { 'ok' })">$verdict</span></h1>
<div class="meta">$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') · ${total}s · commit $(Esc "$commit$dirty") · Godot $(Esc $godotVersion) · $checks itens verificados</div>
<table><tr><th>Etapa</th><th>Resultado</th><th>Tempo</th><th>Resumo</th></tr>
"@)
foreach ($r in $results) {
    [void]$html.Append("<tr><td><a href=`"#$($r.Id)`">$(Esc $r.Name)</a></td><td class=`"$($r.Status)`">$($r.Status)</td><td>$($r.Seconds)s</td><td>$(Esc $r.Summary)</td></tr>")
}
[void]$html.Append('</table>')
foreach ($r in $results) {
    $open = if ($r.Status -eq 'falhou') { ' open' } else { '' }
    [void]$html.Append("<details id=`"$($r.Id)`"$open><summary><span class=`"$($r.Status)`">$($r.Status)</span> · $(Esc $r.Name) · $($r.Passed.Count) ok, $($r.Failures.Count) falha(s)</summary>")
    if ($r.Failures -or $r.Passed) {
        [void]$html.Append('<ul>')
        foreach ($f in $r.Failures) { [void]$html.Append("<li class=`"f`">$(Esc $f)</li>") }
        foreach ($p in $r.Passed) { [void]$html.Append("<li>$(Esc $p)</li>") }
        [void]$html.Append('</ul>')
    }
    if ($r.Log) { [void]$html.Append("<details><summary>Log completo</summary><pre>$(Esc ($r.Log -join "`n"))</pre></details>") }
    [void]$html.Append('</details>')
}
[void]$html.Append('</body></html>')
$report = Join-Path $out 'relatorio.html'
[IO.File]::WriteAllText($report, $html.ToString(), $utf8)

Write-Host ''
Write-Host "Relatório: $report" -ForegroundColor Cyan
Write-Host "$verdict (${total}s)" -ForegroundColor $(if ($failedSteps) { 'Red' } else { 'Green' })
if (-not $NoOpen) { Start-Process $report }
if ($failedSteps) { exit 1 }
