# Aparelhos-alvo dos testes no emulador Android (AVDs) e funções comuns aos scripts do emulador.
# Carregado com ". (Join-Path $PSScriptRoot 'test_devices.ps1')" por run_emulator.ps1, run_e2e.ps1,
# run_emulator_release.ps1, build_release.ps1 e create_test_avds.ps1.
#
# Toda versão nova passa pelo E2E nos quatro (veja AGENTS.md, "Política de testes automatizados").
# Resolução lógica = física / 4 (a do Godot com o stretch do projeto).
#   Redmi Note 14 Pro+ 5G   2712x1220  480 dpi   -> 678x305
#   Samsung Galaxy M55 5G   2400x1080  450 dpi   -> 600x270   furo central de câmera (cutout emulado)
#   Google Pixel 7          2400x1080  420 dpi   -> 600x270   furo central de câmera (cutout emulado)
#   Samsung Galaxy A15      2340x1080  450 dpi   -> 585x270   gota d'água (notch em U); emulado com o
#                                                             furo central ('hole'), o overlay mais próximo
#
# Base = definição de aparelho do avdmanager usada para criar o AVD; tela e densidade são
# ajustadas depois no config.ini. Cutout = overlay de recorte de tela do Android
# (com.android.internal.display.cutout.emulation.<Cutout>), ligado depois do boot.

$TestDevices = @(
    [pscustomobject]@{ Avd = 'Redmi_Note_14_Pro_Plus_5G'; Label = 'Redmi Note 14 Pro+ 5G'; Base = 'pixel_6_pro'
        Manufacturer = 'Xiaomi'; Width = 1220; Height = 2712; Density = 480; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Galaxy_M55_5G'; Label = 'Samsung Galaxy M55 5G'; Base = 'pixel_7'
        Manufacturer = 'Samsung'; Width = 1080; Height = 2400; Density = 450; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Pixel_7'; Label = 'Google Pixel 7'; Base = 'pixel_7'
        Manufacturer = 'Google'; Width = 1080; Height = 2400; Density = 420; Cutout = 'hole' }
    # A15 4G (SM-A155F) / A15 5G (SM-A156B): notch em gota; o Android não tem overlay de gota, 'hole' é o mais próximo.
    [pscustomobject]@{ Avd = 'Galaxy_A15'; Label = 'Samsung Galaxy A15'; Base = 'pixel_7'
        Manufacturer = 'Samsung'; Width = 1080; Height = 2340; Density = 450; Cutout = 'hole' }
    # S24 Ultra (SM-S928B) / S25 Ultra (SM-S938B), mesma tela 3120x1440, na resolução nativa QHD+; o FHD+ de fábrica já é coberto pelo Galaxy_A15 (585x270).
    [pscustomobject]@{ Avd = 'Galaxy_S24_Ultra'; Label = 'Samsung Galaxy S24 Ultra (QHD+)'; Base = 'pixel_7'
        Manufacturer = 'Samsung'; Width = 1440; Height = 3120; Density = 600; Cutout = 'hole' }
)

$CutoutOverlayPrefix = 'com.android.internal.display.cutout.emulation'

function Get-TestDevice([string]$Name) {
    $TestDevices | Where-Object { $_.Avd -eq $Name } | Select-Object -First 1
}

# "all" (ou vazio) = todos da tabela; senão uma lista separada por vírgula. AVDs fora da tabela também
# valem (sem cutout), para testar outro emulador à mão.
function Resolve-TestDevices([string]$Spec) {
    if (-not $Spec -or $Spec -eq 'all') { return @($TestDevices) }
    @($Spec -split '[,;\s]+' | Where-Object { $_ } | ForEach-Object {
        $d = Get-TestDevice $_
        if ($d) { $d } else {
            [pscustomobject]@{ Avd = $_; Label = $_; Base = ''; Manufacturer = ''; Width = 0; Height = 0; Density = 0; Cutout = '' }
        }
    })
}

function Test-AvdExists([string]$Name) {
    Test-Path (Join-Path $env:USERPROFILE ".android\avd\$Name.ini")
}

# Roda o adb com tempo-limite: um emulador congelado deixa "adb shell" e "adb emu" pendurados para
# sempre. Devolve a saída (texto) ou $null se o tempo estourou (o adb é encerrado à força).
function Invoke-AdbTimeout([string]$Adb, [string[]]$Arguments, [int]$Seconds = 15) {
    $psi = New-Object Diagnostics.ProcessStartInfo $Adb
    $psi.Arguments = ($Arguments | ForEach-Object {
        if ("$_" -eq '' -or "$_" -match '[\s"]') { '"' + ("$_" -replace '"', '\"') + '"' } else { "$_" } }) -join ' '
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $p = [Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEndAsync(); $null = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($Seconds * 1000)) { try { $p.Kill() } catch {}; return $null }
    $p.WaitForExit()
    return $out.Result
}

# Emuladores ligados: serial, estado e nome do AVD (adb emu avd name).
function Get-RunningEmulators([string]$Adb) {
    $ErrorActionPreference = 'Continue'
    @((& $Adb devices 2>$null) | ForEach-Object {
        if ($_ -match '^(emulator-\d+)\s+(device|offline)') {
            $serial = $Matches[1]; $state = $Matches[2]
            # O console do emulador responde mesmo com o adb ainda "offline" (no boot); congelado, não.
            $name = ((Invoke-AdbTimeout $Adb @('-s', $serial, 'emu', 'avd', 'name') 10) -split "`r?`n" | Select-Object -First 1)
            $name = if ($name -and "$name" -notmatch '^KO|error') { "$name".Trim() } else { '' }
            [pscustomobject]@{ Serial = $serial; State = $state; Avd = $name }
        }
    })
}

# Desliga os emuladores que não são o AVD pedido (um por vez: o E2E manda toques para o único
# aparelho ligado) e espera eles sumirem do adb.
function Stop-OtherEmulators([string]$Adb, [string]$Avd) {
    $ErrorActionPreference = 'Continue'
    $others = @(Get-RunningEmulators $Adb | Where-Object { $_.Avd -ne $Avd })
    if (-not $others.Count) { return }
    foreach ($e in $others) {
        Write-Host "Desligando o emulador $($e.Serial) ($(if ($e.Avd) { $e.Avd } else { $e.State }))" -ForegroundColor Yellow
        Invoke-AdbTimeout $Adb @('-s', $e.Serial, 'emu', 'kill') 10 | Out-Null
    }
    $deadline = (Get-Date).AddSeconds(90)
    while ((Get-Date) -lt $deadline) {
        $left = @((& $Adb devices 2>$null) | Select-String ($others.Serial -join '|'))
        if (-not $left.Count) { break }
        Start-Sleep -Seconds 2
    }
    # Congelado, o "emu kill" não adianta (e o nome do AVD pode nem vir): desliga à força os processos
    # de emulador que não são do AVD pedido.
    if ($left.Count) {
        $mine = "-avd\s+$([regex]::Escape($Avd))(\s|$)"
        Get-CimInstance Win32_Process -Filter "Name LIKE 'qemu-system%' OR Name = 'emulator.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -notmatch $mine } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 5
    }
    Start-Sleep -Seconds 2
}

# Desliga à força o emulador do AVD (qemu-system-* e emulator.exe com "-avd <nome>" na linha de
# comando) e espera o adb esquecer dele. Só um emulador fica ligado por vez (Stop-OtherEmulators).
function Stop-EmulatorProcess([string]$Adb, [string]$Avd) {
    $ErrorActionPreference = 'Continue'
    $pattern = "-avd\s+$([regex]::Escape($Avd))(\s|$)"
    $procs = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'qemu-system%' OR Name = 'emulator.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match $pattern })
    if (-not $procs.Count) { return }
    foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        $left = @(((Invoke-AdbTimeout $Adb @('devices') 10) -split "`r?`n") | Where-Object { $_ -match '^emulator-\d+\s' })
        if (-not $left.Count) { break }
        Start-Sleep -Seconds 2
    }
    Start-Sleep -Seconds 2
}

# Serial do emulador do AVD pedido, depois do boot completo (ou $null no tempo-limite).
function Wait-EmulatorFor([string]$Adb, [string]$Avd, [int]$Minutes = 8) {
    $ErrorActionPreference = 'Continue'
    $deadline = (Get-Date).AddMinutes($Minutes)
    $since = Get-Date
    $pattern = "-avd\s+$([regex]::Escape($Avd))(\s|$)"
    while ((Get-Date) -lt $deadline) {
        # O emulador fechou sozinho (ex.: falha ao carregar o snapshot): não adianta esperar o resto.
        $alive = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'qemu-system%' OR Name = 'emulator.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -match $pattern })
        if (-not $alive.Count -and ((Get-Date) - $since).TotalSeconds -gt 60) { return $null }
        $e = Get-RunningEmulators $Adb | Where-Object { $_.State -eq 'device' -and $_.Avd -eq $Avd } | Select-Object -First 1
        # Com tempo-limite: um emulador congelado deixa o "adb shell" pendurado para sempre.
        $boot = if ($e) { Invoke-AdbTimeout $Adb @('-s', $e.Serial, 'shell', 'getprop', 'sys.boot_completed') 15 }
        if ($boot -and $boot.Trim() -eq '1') { return $e.Serial }
        Start-Sleep -Seconds 3
    }
    return $null
}

# Regra "Emulador travado" (AGENTS.md): espera o AVD até $Minutes; se não responder (boot congelado ou
# adb pendurado), desliga à força, liga de novo do mesmo jeito e espera mais $Minutes. Uma só nova
# tentativa: devolve o serial ou $null.
function Wait-EmulatorReady([string]$Adb, [string]$AndroidSdk, [string]$Avd, [int]$Minutes = 8, [switch]$NoWindow) {
    $serial = Wait-EmulatorFor $Adb $Avd $Minutes
    if ($serial) { return $serial }
    Write-Host "O emulador $Avd não respondeu em $Minutes minutos (ou fechou sozinho): desligando à força e ligando de novo" -ForegroundColor Yellow
    Stop-EmulatorProcess $Adb $Avd
    Start-EmulatorFor $Adb $AndroidSdk $Avd -NoWindow:$NoWindow | Out-Null
    return (Wait-EmulatorFor $Adb $Avd $Minutes)
}

# Liga (ou desliga) o recorte de câmera emulado do aparelho. O estado fica salvo no /data do AVD,
# mas é reaplicado a cada execução. Devolve o texto do overlay ativo ('' = nenhum).
function Set-EmulatorCutout([string]$Adb, [string]$Serial, [string]$Avd) {
    $ErrorActionPreference = 'Continue'
    $d = Get-TestDevice $Avd
    $want = if ($d -and $d.Cutout) { "$CutoutOverlayPrefix.$($d.Cutout)" } else { '' }
    # Com tempo-limite: com o system_server engasgado, "cmd overlay" fica pendurado para sempre.
    $list = ((Invoke-AdbTimeout $Adb @('-s', $Serial, 'shell', 'cmd', 'overlay', 'list') 30) -split "`r?`n") |
        Select-String $CutoutOverlayPrefix
    foreach ($line in $list) {
        if ($line -match '\[x\]\s+(\S+)' -and $Matches[1] -ne $want) {
            Invoke-AdbTimeout $Adb @('-s', $Serial, 'shell', 'cmd', 'overlay', 'disable', $Matches[1]) 30 | Out-Null
        }
    }
    if ($want) {
        if (-not ($list | Select-String ([regex]::Escape($want)))) {
            Write-Host "AVISO: o overlay $want não existe nesta imagem do Android" -ForegroundColor Yellow
            return ''
        }
        Invoke-AdbTimeout $Adb @('-s', $Serial, 'shell', 'cmd', 'overlay', 'enable-exclusive', '--category', $want) 30 | Out-Null
        Start-Sleep -Seconds 2
    }
    $active = ((Invoke-AdbTimeout $Adb @('-s', $Serial, 'shell', 'cmd', 'overlay', 'list') 30) -split "`r?`n") | Select-String "\[x\]\s+$([regex]::Escape($CutoutOverlayPrefix))\.(\S+)"
    if ($active) { return $active[0].Matches[0].Groups[1].Value }
    return ''
}

# Liga o emulador do AVD num processo independente (WMI: não morre com o terminal), depois de
# desligar os outros. Não espera o boot (use Wait-EmulatorFor).
function Start-EmulatorFor([string]$Adb, [string]$AndroidSdk, [string]$Avd, [switch]$NoWindow) {
    $ErrorActionPreference = 'Continue'
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "`"$Adb`" start-server"; CurrentDirectory = (Split-Path $Adb) } | Out-Null
    Start-Sleep -Seconds 2
    if (-not (Test-AvdExists $Avd)) {
        throw "o AVD $Avd não existe; crie com: powershell -ExecutionPolicy Bypass -File tools\create_test_avds.ps1"
    }
    Stop-OtherEmulators $Adb $Avd
    if (Get-RunningEmulators $Adb | Where-Object { $_.Avd -eq $Avd }) { return $false }
    Write-Host "== Ligando o emulador ($Avd)" -ForegroundColor Cyan
    Remove-Item "$env:USERPROFILE\.android\avd\$Avd.avd\*.lock" -Recurse -Force -ErrorAction SilentlyContinue
    # -no-snapshot: boot a frio (~30 s), sem carregar nem salvar o snapshot rápido. O snapshot salvo
    # pelo "emu kill" voltava com o system_server engasgado (cmd overlay/dumpsys pendurados, app que
    # abre e não passa da inicialização) ou nem subia.
    $extra = ' -no-snapshot' + $(if ($NoWindow) { ' -no-window' } else { '' })
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "`"$(Join-Path $AndroidSdk 'emulator\emulator.exe')`" -avd $Avd -no-boot-anim$extra" } | Out-Null
    return $true
}
