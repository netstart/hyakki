# Verificações do Hyakki (plano 14 e 15.1), em paralelo:
#   1. importa o projeto (valida a sintaxe de todos os scripts), sozinho e antes de tudo
#   2. depois, ao mesmo tempo, cada tarefa num processo próprio:
#      - integração em N fatias (--shard=k/N: as resoluções × idiomas × furo dos dois lados de
#        DeviceProfiles.layout_cases() e as suítes sem layout repartidas entre as fatias; a união das
#        fatias é o conjunto completo, conferido por um teste)
#      - testes de regras (tests/run_tests.gd)
#      - determinismo: o bot em 1x, 2x, 3x e 3x na qualidade Baixa (o estado tem de ser idêntico)
#      - fogo, gelo e clones: o mesmo determinismo com o arsenal novo forçado (--arsenal=..., armas
#        novas, evoluções e as três uniões)
#      - jornada pelos três níveis: o bot invencível passa pelos dois portais até o Tokoyo e vence
#        o último chefe, com o mesmo estado em 1x, 2x e 3x
#      - estresse com 500 inimigos (custo da simulação neste PC; com -StressAlone roda sozinho no fim)
#      - com janela (sem --headless; -NoWindow pula): os traços do Stroke iguais aos do motor pixel a
#        pixel (tests/stroke_pixel_tests.tscn), o mesmo quadro da partida pelos dois caminhos
#        (tests/game_bench.tscn --compare-shots --strict) e a navegação entre os menus sem piscar
#        (tests/nav_bench.tscn --strict-flicker, em NavShards processos; os ms só são impressos)
#      - gdlint (regras em gdlintrc) dividido em partes
#      - textos, licenças, ficha da loja e site irmão (netstart.github.io: app-ads.txt gerado do
#        ID do AdMob, política de privacidade e página do jogo lá, sem cópias em docs/)
#
# Isolamento: cada Godot roda com APPDATA própria (pasta temporária), então user:// (save,
# settings.cfg, runs.csv, logs) nunca é o perfil real do jogador, e as fatias não disputam
# arquivos. No fim o script confere que os arquivos do perfil real não mudaram.
#
# Travou? Uma tarefa sem saída nova por -StallMinutes (padrão 8, regra do AGENTS.md) é encerrada à
# força (com os processos filhos) e rodada de novo uma vez; se travar de novo, é falha.
# Qualquer falha, erro de script ou trava em qualquer tarefa reprova o todo.
#
# Fila, ordem e prioridade: no máximo -MaxParallel tarefas ao mesmo tempo (núcleos − 2 e o que a
# memória comporta), da mais longa para a mais curta; a jornada (a mais longa, uma partida de 11 min
# que não se divide) fica em Normal e todas as outras em BelowNormal (o Godot se põe em AboveNormal), para
# ela ter um núcleo inteiro e o PC continuar usável enquanto as fatias dividem o resto da máquina.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
#       -Shards N        fatias da integração (padrão: pelo número de núcleos)
#       -StallMinutes M  minutos sem saída para considerar a tarefa travada (padrão 8)
#       -StressAlone     roda o estresse sozinho, depois das outras tarefas (números sem disputa de CPU)
#       -NoWindow        pula as tarefas que abrem janela (pixels e navegação)
#       -NavShards N     processos do benchmark de navegação (padrão 3)
#       -SamePriority    todas as tarefas com a mesma prioridade (sem dar a vez à jornada)
#       -MaxParallel N   teto de processos ao mesmo tempo (padrão: núcleos lógicos − 2, e o que a
#                        memória livre comporta: (livre − ReserveMB) / GodotMemoryMB); o resto espera
#                        na fila, a mais longa primeiro, e cada vaga liberada puxa a próxima
#       -GodotMemoryMB M memória de um Godot de teste (padrão 600; fatia headless ~500, com janela ~800)
#       -ReserveMB M     memória que fica livre para a máquina (padrão 4096): sem ela, a fila espera
#       -Only a,b        só as tarefas cujo nome começa com um destes (ex.: -Only integracao,regras)
#       -KeepTemp        mantém as pastas APPDATA temporárias
#       -Godot "C:\caminho\Godot_v4.7.2-stable_win64_console.exe"
# Saída de cada tarefa: build\checks\<data_hora>\<tarefa>.log (e godot_<tarefa>.log do --log-file).

param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [int]$Shards = 0,
    [double]$StallMinutes = 8,
    [switch]$StressAlone,
    [switch]$NoWindow,
    [int]$NavShards = 3,
    [switch]$SamePriority,
    [int]$MaxParallel = 0,
    [int]$GodotMemoryMB = 600,
    [int]$ReserveMB = 4096,
    [string[]]$Only = @(),
    [switch]$KeepTemp
)

$ErrorActionPreference = 'Stop'
# Fim da jornada do bot pelos três níveis (segundos da noite): depois do último chefe no Tokoyo.
$JourneyEnd = 660
# -Only a,b chega como um texto só quando o script é chamado com -File: separa nas vírgulas.
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$project = Split-Path -Parent $PSScriptRoot
$started = [Diagnostics.Stopwatch]::StartNew()
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$logDir = Join-Path $project "build\checks\$stamp"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "hyakki-checks\$stamp"
New-Item -ItemType Directory -Force $logDir, $tempRoot | Out-Null
$utf8 = New-Object Text.UTF8Encoding $false

# Memória disponível agora (MB): livre + cache que o Windows devolve na hora.
Add-Type -AssemblyName Microsoft.VisualBasic
function Get-AvailableMB { return [math]::Floor((New-Object Microsoft.VisualBasic.Devices.ComputerInfo).AvailablePhysicalMemory / 1MB) }

# Teto de processos ao mesmo tempo: núcleos lógicos − 2 (a máquina continua usável) e o que a
# memória comporta. Mais que isso disputa CPU sem andar mais rápido (as fatias, o lint e o Python
# ficavam 2 a 7 vezes mais lentos com 38 processos em 16 linhas) e pode esgotar a memória.
if ($MaxParallel -le 0) {
    $byCpu = [math]::Max(2, [Environment]::ProcessorCount - 2)
    $byMemory = [math]::Max(2, [math]::Floor(((Get-AvailableMB) - $ReserveMB) / $GodotMemoryMB))
    $MaxParallel = [math]::Min($byCpu, $byMemory)
}
if ($Shards -le 0) {
    # Cada fatia é um processo de uma linha de execução. A jornada ocupa 3 vagas o tempo todo e
    # sobra 1 para a fila das tarefas curtas (bot, regras, navegação, lint, Python) desde o começo;
    # as outras entram nas vagas da jornada 3x e 2x e das fatias, antes da jornada 1x acabar.
    $Shards = [math]::Max(2, [math]::Min(12, $MaxParallel - 4))
}

# Perfil real do jogador (user:// sem isolamento): os arquivos e seus hashes antes de tudo.
$realProfile = Join-Path $env:APPDATA 'Godot\app_userdata\Hyakki'
function Get-ProfileHashes {
    $map = @{}
    foreach ($name in 'save.json', 'save.bak', 'save.tmp', 'settings.cfg', 'runs.csv', 'test_save.json', 'test_save.bak',
            'test_save.tmp', 'test_settings.cfg') {
        $path = Join-Path $realProfile $name
        $map[$name] = if (Test-Path $path) { (Get-FileHash $path -Algorithm MD5).Hash } else { '' }
    }
    return $map
}
$profileBefore = Get-ProfileHashes

# --- Tarefas ---------------------------------------------------------------------------
# Cada tarefa: Name, Exe, Args, Godot (APPDATA isolada), Check (scriptblock que recebe as linhas
# e devolve @{ Ok; Summary; Details }).
$tasks = New-Object System.Collections.Generic.List[object]

function Test-ScriptErrors([string[]]$Lines) {
    return @($Lines | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' })
}

# Testes GDScript: "N verificações, M falhas" no fim, "FALHOU: x" por verificação que falhou.
$checkGdTests = {
    param($Lines, $Code)
    $fails = @($Lines | Where-Object { $_ -match 'FALHOU' })
    $errors = Test-ScriptErrors $Lines
    $total = $Lines | Where-Object { $_ -match '^\d+ verificações, \d+ falhas' } | Select-Object -Last 1
    $ok = $Code -eq 0 -and $total -and -not $fails -and -not $errors
    $summary = if ($total) { $total } else { 'não chegou ao fim (veja o log)' }
    return @{ Ok = [bool]$ok; Summary = $summary; Details = @($fails + $errors) }
}

# -Window: sem --headless (a tarefa desenha de verdade: comparação de pixels, navegação).
function Add-GodotTask([string]$Name, [string[]]$GodotArgs, [scriptblock]$Check, [switch]$Window) {
    [string[]]$head = @(if (-not $Window) { '--headless' })
    $tasks.Add([pscustomobject]@{ Name = $Name; Exe = $Godot; Godot = $true; Check = $Check
        Args = $head + @('--path', $project, '--log-file', (Join-Path $logDir "godot_$Name.log")) + $GodotArgs })
}

function Add-ToolTask([string]$Name, [string]$Exe, [string[]]$ToolArgs) {
    $tasks.Add([pscustomobject]@{ Name = $Name; Exe = $Exe; Args = $ToolArgs; Godot = $false; Check = {
        param($Lines, $Code)
        $last = $Lines | Where-Object { $_ } | Select-Object -Last 1
        return @{ Ok = ($Code -eq 0); Summary = "$last"; Details = @(if ($Code -ne 0) { $Lines | Select-Object -Last 15 }) }
    } })
}

for ($k = 1; $k -le $Shards; $k++) {
    # --fixed-fps: cada quadro anda 1/60 s de simulação sem esperar o relógio (as esperas dos testes
    # contam quadros e tempo de simulação, nunca o relógio da parede).
    Add-GodotTask "integracao_$k" @('--fixed-fps', '60', 'res://tests/integration_tests.tscn', '--', "--shard=$k/$Shards") $checkGdTests
}
Add-GodotTask 'regras' @('--script', 'res://tests/run_tests.gd') $checkGdTests

$checkBot = {
    param($Lines, $Code)
    $errors = Test-ScriptErrors $Lines
    $line = $Lines | Where-Object { $_ -match '^FIM ' } | Select-Object -Last 1
    $ok = $Code -eq 0 -and $line -and -not $errors
    return @{ Ok = [bool]$ok; Summary = $(if ($line) { $line } else { 'a partida não chegou ao FIM' }); Details = $errors }
}
foreach ($speed in 1, 2, 3) {
    Add-GodotTask "determinismo_${speed}x" @('--fixed-fps', '60', '--', '--bot', '--seed=7', "--speed=$speed", '--quit-at=90') $checkBot
}
# Jornada pelos três níveis (RiftPortal): o bot invencível (--god) vence o Guardião do Limiar,
# atravessa o portal, vence a Sombra no Kakuriyo, atravessa o torii dourado e vence o último chefe
# no Tokoyo (linha CHEFES); o estado no fim é o mesmo em 1x, 2x e 3x.
$checkJourney = {
    param($Lines, $Code)
    $verdict = & $checkBot $Lines $Code
    $journey = $Lines | Where-Object { $_ -match '^CHEFES ' } | Select-Object -Last 1
    $ok = $verdict.Ok -and $journey -match 'reino=2 tokoyo=true vencidos=.*kappa_elder'
    if (-not $ok -and $journey) { $verdict.Details = @($verdict.Details) + @("$journey") }
    return @{ Ok = [bool]$ok; Summary = $verdict.Summary; Details = $verdict.Details }
}
foreach ($speed in 1, 2, 3) {
    Add-GodotTask "jornada_${speed}x" @('--fixed-fps', '60', '--', '--bot', '--seed=7', '--god', "--speed=$speed", "--quit-at=$JourneyEnd") $checkJourney
}
# Qualidade gráfica não pode mudar a simulação (clima e superfícies lentas incluídos no hash).
Add-GodotTask 'determinismo_3x_baixa' @('--fixed-fps', '60', '--', '--bot', '--seed=7', '--speed=3', '--gfx=low', '--quit-at=90') $checkBot
# Fogo, gelo e clones (.ai/06-fogo-gelo-clones.md): arsenal forçado com as armas novas no nível máximo
# (bases, evoluções e as três uniões), mesmo estado em 1x, 2x, 3x e na Baixa.
$Arsenal = '--arsenal=horokubiya,tsurara,kage_bunshin,kagutsuchi,yukionna,senkage,onmyo_taikyoku,kitsune_yomeiri,hyokyo'
foreach ($speed in 1, 2, 3) {
    Add-GodotTask "arsenal_${speed}x" @('--fixed-fps', '60', '--', '--bot', '--seed=7', $Arsenal, "--speed=$speed", '--quit-at=60') $checkBot
}
Add-GodotTask 'arsenal_3x_baixa' @('--fixed-fps', '60', '--', '--bot', '--seed=7', $Arsenal, '--speed=3', '--gfx=low', '--quit-at=60') $checkBot

$checkStress = {
    param($Lines, $Code)
    $errors = Test-ScriptErrors $Lines
    $perf = @($Lines | Where-Object { $_ -match '^DESEMPENHO|pior por sistema' })
    $ok = $Code -eq 0 -and $perf -and -not $errors
    return @{ Ok = [bool]$ok; Summary = $(if ($perf) { $perf[-1] } else { 'sem linha de DESEMPENHO' }); Details = @($errors + $perf) }
}
Add-GodotTask 'estresse' @('--fixed-fps', '60', '--', '--bot', '--seed=7', '--stress=500', '--log-every=10', '--quit-at=30') $checkStress

# Com janela: o que precisa desenhar de verdade (não roda com --headless).
if (-not $NoWindow) {
    Add-GodotTask 'pixels_stroke' @('res://tests/stroke_pixel_tests.tscn') $checkGdTests -Window
    $checkCompare = {
        param($Lines, $Code)
        $errors = Test-ScriptErrors $Lines
        $fails = @($Lines | Where-Object { $_ -match 'FALHOU' })
        $line = $Lines | Where-Object { $_ -match '^COMPARA ' } | Select-Object -Last 1
        $ok = $Code -eq 0 -and $line -and -not $errors -and -not $fails
        return @{ Ok = [bool]$ok; Summary = $(if ($line) { $line } else { 'sem a linha COMPARA' }); Details = @($fails + $errors) }
    }
    Add-GodotTask 'pixels_partida' @('res://tests/game_bench.tscn', '--', '--bot', '--seed=7', '--stress=500', '--bench-seconds=4',
        '--strict', "--compare-shots=$(Join-Path $logDir 'pixels_partida')") $checkCompare -Window
    # Navegação entre os menus: nenhuma piscada e o título parado na volta de um submenu (os ms da
    # troca dependem da disputa de CPU: só impressos; o critério de ms é o --strict, rodado sozinho).
    $checkNav = {
        param($Lines, $Code)
        $errors = Test-ScriptErrors $Lines
        $fails = @($Lines | Where-Object { $_ -match 'FALHOU' })
        $line = $Lines | Where-Object { $_ -match '^\d+ casos medidos, \d+ acima dos limites' } | Select-Object -Last 1
        $ok = $Code -eq 0 -and $line -and -not $errors -and -not $fails
        return @{ Ok = [bool]$ok; Summary = $(if ($line) { $line } else { 'não chegou ao fim (veja o log)' }); Details = @($fails + $errors) }
    }
    $NavShards = [math]::Max(1, $NavShards)
    for ($k = 1; $k -le $NavShards; $k++) {
        Add-GodotTask "navegacao_$k" @('res://tests/nav_bench.tscn', '--', '--strict-flicker', '--cycles=1', "--shard=$k/$NavShards") $checkNav -Window
    }
}

$gdlint = Get-Command gdlint -ErrorAction SilentlyContinue
if ($gdlint) {
    # gdlint é lento (~0,13 s por arquivo); os arquivos vão em partes de tamanho parecido.
    $files = @(Get-ChildItem (Join-Path $project 'scripts'), (Join-Path $project 'tests') -Recurse -Filter '*.gd' |
            Sort-Object Length -Descending)
    $parts = [math]::Max(1, [math]::Min(6, [math]::Ceiling($files.Count / 30)))
    $buckets = @(for ($i = 0; $i -lt $parts; $i++) { , (New-Object System.Collections.Generic.List[string]) })
    $sizes = New-Object long[] $parts
    foreach ($f in $files) {
        $i = 0
        for ($j = 1; $j -lt $parts; $j++) { if ($sizes[$j] -lt $sizes[$i]) { $i = $j } }
        $buckets[$i].Add($f.FullName.Substring($project.Length + 1))
        $sizes[$i] += $f.Length
    }
    for ($i = 0; $i -lt $parts; $i++) { Add-ToolTask "lint_$($i + 1)" $gdlint.Source $buckets[$i].ToArray() }
} else { Write-Host 'gdlint não instalado (pip install "gdtoolkit==4.*"); pulando' -ForegroundColor Yellow }

$python = (Get-Command python).Source
Add-ToolTask 'py_i18n' $python @('-I', '-X', 'utf8', (Join-Path $PSScriptRoot 'build_i18n.py'), '--check')
Add-ToolTask 'py_licencas' $python @('-I', '-X', 'utf8', (Join-Path $PSScriptRoot 'check_licenses.py'))
Add-ToolTask 'py_ficha_loja' $python @('-I', '-X', 'utf8', (Join-Path $PSScriptRoot 'check_store_listing.py'))
Add-ToolTask 'py_test_sync_site' $python @('-I', '-X', 'utf8', (Join-Path $PSScriptRoot 'test_sync_site.py'))
Add-ToolTask 'py_test_pre_commit' $python @('-I', '-X', 'utf8', (Join-Path $PSScriptRoot 'test_pre_commit.py'))
Add-ToolTask 'py_sync_site' $python @('-I', '-X', 'utf8', (Join-Path $PSScriptRoot 'sync_site.py'), '--check')

if ($Only.Count -gt 0) {
    $wanted = @($tasks | Where-Object { $n = $_.Name; @($Only | Where-Object { $n.StartsWith($_) }).Count -gt 0 })
    $tasks = New-Object System.Collections.Generic.List[object]
    foreach ($t in $wanted) { $tasks.Add($t) }
}

# --- Processos -------------------------------------------------------------------------
function Format-Arg([string]$a) { if ($a -match '[\s"]' -or $a -eq '') { '"' + ($a -replace '"', '\"') + '"' } else { $a } }

# Inicia a tarefa via cmd.exe (stdout e stderr juntos, na ordem, no mesmo arquivo).
function Start-Task($task) {
    $log = Join-Path $logDir "$($task.Name).log"
    $line = ((@($task.Exe) + $task.Args) | ForEach-Object { Format-Arg $_ }) -join ' '
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = '/d /s /c "' + $line + ' > ' + (Format-Arg $log) + ' 2>&1"'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $project
    if ($task.Godot) {
        $appdata = Join-Path $tempRoot $task.Name
        New-Item -ItemType Directory -Force $appdata | Out-Null
        $psi.EnvironmentVariables['APPDATA'] = $appdata
        $psi.EnvironmentVariables['HYAKKI_CHECKS_APPDATA'] = $appdata
    }
    $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
    $self = [Diagnostics.Process]::GetCurrentProcess()
    $low = -not $SamePriority -and -not (Test-LongPole $task)
    if ($low) { $self.PriorityClass = 'BelowNormal' }
    try { $proc = [Diagnostics.Process]::Start($psi) } finally { if ($low) { $self.PriorityClass = 'Normal' } }
    $task | Add-Member -Force NoteProperty Process $proc
    $task | Add-Member -Force NoteProperty Log $log
    $task | Add-Member -Force NoteProperty Watch ([Diagnostics.Stopwatch]::StartNew())
    $task | Add-Member -Force NoteProperty LastSize -1L
    $task | Add-Member -Force NoteProperty LastChange ([Diagnostics.Stopwatch]::StartNew())
    if (-not ($task.PSObject.Properties.Name -contains 'Attempts')) { $task | Add-Member NoteProperty Attempts 0 }
    $task.Attempts++
}

# Encerra o cmd.exe e tudo o que ele abriu (Godot_*_console.exe e o Godot_*.exe filho).
function Stop-Tree($proc) {
    # Pelo cmd (saída descartada lá): com $ErrorActionPreference = 'Stop', o stderr do taskkill
    # ("não pôde ser finalizado", filho que já saiu) viraria erro e derrubaria o run_checks.
    if ($proc -and -not $proc.HasExited) { & $env:ComSpec /d /c "taskkill /PID $($proc.Id) /T /F >nul 2>&1" | Out-Null }
}

function Read-Lines([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    return @([IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8))
}

$results = New-Object System.Collections.Generic.List[object]
function Complete-Task($task, [bool]$stalled) {
    $lines = Read-Lines $task.Log
    $code = if ($stalled) { -1 } else { $task.Process.ExitCode }
    $verdict = & $task.Check $lines $code
    if ($stalled) {
        $verdict = @{ Ok = $false; Summary = "TRAVOU: $StallMinutes min sem saída nova (encerrada à força)"; Details = @($lines | Select-Object -Last 5) }
    }
    $seconds = [math]::Round($task.Watch.Elapsed.TotalSeconds, 1)
    $results.Add([pscustomobject]@{ Name = $task.Name; Ok = $verdict.Ok; Summary = $verdict.Summary; Details = $verdict.Details
        Seconds = $seconds; Attempts = $task.Attempts; Lines = $lines })
    $color = if ($verdict.Ok) { 'Green' } else { 'Red' }
    Write-Host ('  {0,-24} {1,6:N1}s  {2}  {3}' -f $task.Name, $seconds, $(if ($verdict.Ok) { 'ok    ' } else { 'FALHOU' }), $verdict.Summary) -ForegroundColor $color
}

# Ordem de início: as mais longas primeiro (a jornada, as fatias, as partidas do bot...).
$StartOrder = @('jornada_1x', 'jornada_2x', 'jornada_3x', 'integracao_', 'determinismo_1x', 'estresse', 'determinismo_', 'arsenal_', 'regras',
    'navegacao_', 'pixels_', 'lint_', 'py_')
function Get-StartRank($task) {
    for ($i = 0; $i -lt $StartOrder.Count; $i++) { if ($task.Name.StartsWith($StartOrder[$i])) { return $i } }
    return $StartOrder.Count
}
# Prioridade: o Godot sobe a própria prioridade para AboveNormal ao abrir; o run_checks baixa cada
# Godot para BelowNormal (a máquina continua usável) e deixa só a jornada, a mais longa e que não se
# divide (3 processos), em Normal: ela é quem marca o tempo total. O cmd.exe, o gdlint e o Python já nascem em BelowNormal (o filho herda a
# prioridade abaixo do normal: este processo baixa a própria enquanto abre a tarefa).
function Test-LongPole($task) { return $task.Name -like 'jornada_*' }
function Set-GodotPriorities($running) {
    $pending = @($running | Where-Object { $_.Godot -and -not $_.PriorityDone })
    if (-not $pending -or $SamePriority) { return }
    $procs = @(Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" -ErrorAction SilentlyContinue)
    foreach ($t in $pending) {
        $mark = "godot_$($t.Name).log"
        $mine = @($procs | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($mark) })
        $class = if (Test-LongPole $t) { 'Normal' } else { 'BelowNormal' }
        foreach ($p in $mine) {
            try { (Get-Process -Id $p.ProcessId -ErrorAction Stop).PriorityClass = $class } catch { }
        }
        # Pronto quando o Godot de verdade (não o _console, que só repassa a saída) já foi achado.
        if (@($mine | Where-Object { $_.Name -notlike '*console*' }).Count -gt 0) { $t.PriorityDone = $true }
    }
}

# Picos (relatório no fim): processos de tarefa ao mesmo tempo e a menor memória disponível.
$script:peakRunning = 0
$script:minAvailableMB = [int]::MaxValue

# Roda as tarefas com no máximo $MaxParallel ao mesmo tempo (fila, a mais longa primeiro; cada vaga
# liberada puxa a próxima, se a memória disponível comportar mais um Godot) e espera todas,
# vigiando as travadas.
function Invoke-Parallel($list) {
    $queue = New-Object System.Collections.Generic.Queue[object]
    foreach ($t in @($list | Sort-Object { Get-StartRank $_ })) { $t | Add-Member -Force NoteProperty PriorityDone $false; $queue.Enqueue($t) }
    $running = New-Object System.Collections.Generic.List[object]
    $tick = 0
    try {
        while ($running.Count -gt 0 -or $queue.Count -gt 0) {
            while ($queue.Count -gt 0 -and $running.Count -lt $MaxParallel) {
                $available = Get-AvailableMB
                $script:minAvailableMB = [math]::Min($script:minAvailableMB, $available)
                # Sem memória para mais um Godot: espera uma vaga (nunca para com nada rodando).
                if ($running.Count -gt 0 -and $queue.Peek().Godot -and $available - $GodotMemoryMB -lt $ReserveMB) { break }
                $t = $queue.Dequeue()
                Start-Task $t
                $running.Add($t)
            }
            $script:peakRunning = [math]::Max($script:peakRunning, $running.Count)
            Start-Sleep -Milliseconds 500
            if ($tick++ % 4 -eq 0) {
                Set-GodotPriorities $running
                $script:minAvailableMB = [math]::Min($script:minAvailableMB, (Get-AvailableMB))
            }
            foreach ($t in $running.ToArray()) {
                if ($t.Process.HasExited) {
                    $t.Process.WaitForExit()
                    $running.Remove($t) | Out-Null
                    Complete-Task $t $false
                    continue
                }
                $size = if (Test-Path $t.Log) { (Get-Item $t.Log).Length } else { 0 }
                if ($size -ne $t.LastSize) { $t.LastSize = $size; $t.LastChange.Restart(); continue }
                if ($t.LastChange.Elapsed.TotalMinutes -lt $StallMinutes) { continue }
                Stop-Tree $t.Process
                $t.Process.WaitForExit()
                if ($t.Attempts -lt 2) {
                    Write-Host "  $($t.Name): $StallMinutes min sem saída; encerrada à força e rodada de novo" -ForegroundColor Yellow
                    Copy-Item $t.Log "$($t.Log -replace '\.log$', '')_travou.log" -Force
                    $t.PriorityDone = $false
                    Start-Task $t
                } else {
                    $running.Remove($t) | Out-Null
                    Complete-Task $t $true
                }
            }
        }
    } finally {
        # Ctrl+C ou erro: nada fica rodando.
        foreach ($t in $running) { Stop-Tree $t.Process }
    }
}

# --- Execução --------------------------------------------------------------------------
Write-Host "== Verificações do Hyakki ($Shards fatias de integração, até $MaxParallel processos ao mesmo tempo, $(Get-AvailableMB) MB disponíveis, logs em $logDir)" -ForegroundColor Cyan

$failed = $false
if ($Only.Count -eq 0 -or @($Only | Where-Object { 'importacao'.StartsWith($_) }).Count -gt 0) {
    Write-Host '== 1. Importação' -ForegroundColor Cyan
    $import = [pscustomobject]@{ Name = 'importacao'; Exe = $Godot; Godot = $true
        Args = @('--headless', '--path', $project, '--log-file', (Join-Path $logDir 'godot_importacao.log'), '--import')
        Check = { param($Lines, $Code)
            $errors = Test-ScriptErrors $Lines
            return @{ Ok = (-not $errors); Summary = $(if ($errors) { "$($errors.Count) erro(s) de script" } else { 'sem erros de script' })
                Details = $errors } } }
    Invoke-Parallel @($import)
}

if ($tasks.Count -eq 0 -and $Only.Count -gt 0 -and @($Only | Where-Object { 'importacao'.StartsWith($_) }).Count -eq 0) {
    Write-Host "FALHOU: nenhuma tarefa com o nome começando por $($Only -join ', ')" -ForegroundColor Red
    exit 1
}
$alone = @($tasks | Where-Object { $StressAlone -and $_.Name -eq 'estresse' })
$batch = @($tasks | Where-Object { $alone -notcontains $_ })
Write-Host "== 2. $($batch.Count) tarefas, até $MaxParallel ao mesmo tempo" -ForegroundColor Cyan
Invoke-Parallel $batch
if ($alone) {
    Write-Host '== 3. Estresse sozinho' -ForegroundColor Cyan
    Invoke-Parallel $alone
}

# --- Resumo ----------------------------------------------------------------------------
Write-Host ''
Write-Host '== Resumo' -ForegroundColor Cyan
foreach ($r in $results | Where-Object { -not $_.Ok }) {
    $failed = $true
    Write-Host "FALHOU: $($r.Name) — $($r.Summary) (log: $(Join-Path $logDir "$($r.Name).log"))" -ForegroundColor Red
    foreach ($d in @($r.Details) | Select-Object -First 20) { Write-Host "    $d" -ForegroundColor Red }
}

# Integração: soma das fatias e as suítes mais lentas (pior fatia de cada uma).
$shardResults = @($results | Where-Object { $_.Name -like 'integracao_*' })
if ($shardResults) {
    $checks = 0; $fails = 0
    $suites = @{}
    foreach ($r in $shardResults) {
        foreach ($l in $r.Lines) {
            if ($l -match '^(\d+) verificações, (\d+) falhas') { $checks += [int]$Matches[1]; $fails += [int]$Matches[2] }
            if ($l -match '^SUÍTE (\S+): (\d+) ms, (\d+) verificações') {
                $prev = $suites[$Matches[1]]
                $ms = [int]$Matches[2]; $n = [int]$Matches[3]
                if ($prev) { $suites[$Matches[1]] = @{ Ms = [math]::Max($prev.Ms, $ms); Sum = $prev.Sum + $ms; N = $prev.N + $n } }
                else { $suites[$Matches[1]] = @{ Ms = $ms; Sum = $ms; N = $n } }
            }
        }
    }
    $slowest = ($shardResults | Measure-Object Seconds -Maximum).Maximum
    Write-Host ("Integração: {0} verificações, {1} falhas em {2} fatias (a mais lenta: {3:N1}s)" -f $checks, $fails, $shardResults.Count, $slowest)
    $top = $suites.GetEnumerator() | Sort-Object { $_.Value.Sum } -Descending | Select-Object -First 8
    Write-Host ('  suítes mais caras (soma das fatias): ' + (($top | ForEach-Object { '{0} {1:N1}s' -f $_.Key, ($_.Value.Sum / 1000.0) }) -join ', '))

    # Cobertura: a união das fatias tem de ser o conjunto completo. Cada fatia imprime
    # "COBERTURA k/N casos=a-b/T suites=... todas=..."; os casos [a, b) das N fatias emendam de 0 a T e
    # toda suíte da lista "todas" roda em alguma fatia (e cada fatia rodou todas as que disse rodar).
    $coverage = @($shardResults | ForEach-Object { $_.Lines | Where-Object { $_ -match '^COBERTURA ' } | Select-Object -First 1 })
    $gaps = @()
    if ($coverage.Count -ne $Shards) { $gaps += "$($coverage.Count) de $Shards fatias imprimiram a cobertura" }
    $ranges = @(); $ran = @{}; $all = @()
    foreach ($c in $coverage) {
        if ($c -notmatch '^COBERTURA (\d+)/(\d+) casos=(\d+)-(\d+)/(\d+) suites=(\S*) todas=(\S*)') { $gaps += "linha inválida: $c"; continue }
        $ranges += , @([int]$Matches[3], [int]$Matches[4], [int]$Matches[5])
        foreach ($s in $Matches[6].Split(',')) { if ($s) { $ran[$s] = $true } }
        $all = $Matches[7].Split(',')
    }
    $next = 0
    foreach ($r in $ranges | Sort-Object { $_[0] }) { if ($r[0] -ne $next) { $gaps += "casos $next..$($r[0]) sem fatia" }; $next = $r[1] }
    if ($ranges -and $next -ne $ranges[0][2]) { $gaps += "casos $next..$($ranges[0][2]) sem fatia" }
    foreach ($s in $all) { if ($s -and -not $ran[$s]) { $gaps += "suíte $s não rodou em nenhuma fatia" } }
    foreach ($r in $shardResults) {
        $said = ($r.Lines | Where-Object { $_ -match '^COBERTURA ' } | Select-Object -First 1) -replace '^.* suites=(\S*) .*$', '$1'
        $done = @($r.Lines | Where-Object { $_ -match '^SUÍTE (\S+):' } | ForEach-Object { $_ -replace '^SUÍTE (\S+):.*$', '$1' })
        foreach ($s in $said.Split(',')) { if ($s -and -not $s.EndsWith('.resto') -and $done -notcontains $s) { $gaps += "$($r.Name): suíte $s não terminou" } }
    }
    if ($gaps) {
        $failed = $true
        Write-Host 'FALHOU: cobertura das fatias incompleta' -ForegroundColor Red
        $gaps | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    } else { Write-Host "Cobertura: $($all.Count) suítes e os $($ranges[0][2]) casos (resolução × idioma × furo) cobertos pela união das fatias" }
}
foreach ($r in $results | Where-Object { $_.Name -eq 'regras' }) { Write-Host "Regras: $($r.Summary)" }

# Determinismo: as 4 partidas com o mesmo hash.
$det = @($results | Where-Object { $_.Name -like 'determinismo_*' })
if ($det) {
    $hashes = @($det | ForEach-Object { $_.Summary -replace '^.*hash=', '' })
    if ($det.Count -ne 4 -or @($hashes | Select-Object -Unique).Count -ne 1 -or @($det | Where-Object { -not $_.Ok })) {
        Write-Host 'FALHOU: determinismo: o estado mudou com a velocidade ou com a qualidade gráfica' -ForegroundColor Red
        foreach ($r in $det) { Write-Host "    $($r.Name): $($r.Summary)" -ForegroundColor Red }
        $failed = $true
    } else { Write-Host "Determinismo: mesmo estado em 1x, 2x, 3x e 3x Baixa (hash=$($hashes[0]))" }
}
# Fogo, gelo e clones: as 4 partidas com o arsenal novo com o mesmo hash.
$ars = @($results | Where-Object { $_.Name -like 'arsenal_*' })
if ($ars) {
    $hashes = @($ars | ForEach-Object { $_.Summary -replace '^.*hash=', '' })
    if ($ars.Count -ne 4 -or @($hashes | Select-Object -Unique).Count -ne 1 -or @($ars | Where-Object { -not $_.Ok })) {
        Write-Host 'FALHOU: com fogo, gelo e clones, o estado mudou com a velocidade ou com a qualidade gráfica' -ForegroundColor Red
        foreach ($r in $ars) { Write-Host "    $($r.Name): $($r.Summary)" -ForegroundColor Red }
        $failed = $true
    } else { Write-Host "Fogo, gelo e clones: mesmo estado em 1x, 2x, 3x e 3x Baixa (hash=$($hashes[0]))" }
}
$trip = @($results | Where-Object { $_.Name -like 'jornada_*' })
if ($trip) {
    $hashes = @($trip | ForEach-Object { $_.Summary -replace '^.*hash=', '' })
    if ($trip.Count -ne 3 -or @($hashes | Select-Object -Unique).Count -ne 1 -or @($trip | Where-Object { -not $_.Ok })) {
        Write-Host 'FALHOU: jornada: o bot não chegou ao Tokoyo e venceu o último chefe, ou o estado mudou com a velocidade' -ForegroundColor Red
        foreach ($r in $trip) { Write-Host "    $($r.Name): $($r.Summary) $($r.Details -join ' ')" -ForegroundColor Red }
        $failed = $true
    } else { Write-Host "Jornada: Kakuriyo, Tokoyo e o último chefe com o mesmo estado em 1x, 2x e 3x (hash=$($hashes[0]))" }
}
foreach ($r in $results | Where-Object { $_.Name -eq 'estresse' }) {
    $r.Details | Where-Object { $_ -match '^DESEMPENHO|pior por sistema' } | Select-Object -Last 2 | Write-Host
    if (-not $StressAlone) { Write-Host '(estresse medido junto com as outras tarefas; -StressAlone mede sem disputa de CPU)' }
}

# Isolamento: o perfil real do jogador não pode ter mudado.
$profileAfter = Get-ProfileHashes
foreach ($name in $profileBefore.Keys) {
    if ($profileBefore[$name] -ne $profileAfter[$name]) {
        Write-Host "FALHOU: os testes mexeram em $(Join-Path $realProfile $name) (perfil real)" -ForegroundColor Red
        $failed = $true
    }
}

if ($script:peakRunning -gt 0) {
    Write-Host ("Pico: {0} tarefas ao mesmo tempo (teto {1}); menor memória disponível {2} MB (reserva {3} MB)" -f $script:peakRunning,
        $MaxParallel, $script:minAvailableMB, $ReserveMB)
}
$slow = @($results | Sort-Object Seconds -Descending | Select-Object -First 5)
if ($slow) { Write-Host ('Mais lentas: ' + (($slow | ForEach-Object { '{0} {1:N1}s' -f $_.Name, $_.Seconds }) -join ', ')) }
$retried = @($results | Where-Object { $_.Attempts -gt 1 })
if ($retried) { Write-Host "Rodadas de novo depois de travar: $(($retried | ForEach-Object Name) -join ', ')" -ForegroundColor Yellow }
if (-not $KeepTemp -and -not $failed) { Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue }
Write-Host ("Tempo total: {0:N1}s · logs em {1}" -f $started.Elapsed.TotalSeconds, $logDir)
if ($failed) { Write-Host 'FALHOU' -ForegroundColor Red; exit 1 }
Write-Host 'TUDO OK' -ForegroundColor Green
