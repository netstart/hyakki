# Funções comuns aos scripts de teste MANUAL no emulador Android (run_emulator.ps1,
# run_emulator_release.ps1, build_release.ps1): ligar o AVD, esperar o boot, ligar o recorte de
# câmera emulado e desligar o emulador travado. Carregado com
# ". (Join-Path $PSScriptRoot 'emulator_common.ps1')".
#
# Testes automatizados no emulador Android são proibidos (AGENTS.md, "Política de testes
# automatizados"): o emulador serve só para uma pessoa jogar e conferir à mão. Os testes por
# resolução rodam só no Godot, com os perfis de tests/device_profiles.gd.
#
# AVDs conhecidos (criados à mão no Device Manager do Android Studio, com a tela de cada aparelho):
# o recorte de câmera emulado (com.android.internal.display.cutout.emulation.<Cutout>) é ligado
# depois do boot. AVD fora da lista também vale, sem recorte.

$EmulatorDevices = @(
    [pscustomobject]@{ Avd = 'Redmi_Note_14_Pro_Plus_5G'; Label = 'Redmi Note 14 Pro+ 5G'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Galaxy_M55_5G'; Label = 'Samsung Galaxy M55 5G'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Pixel_7'; Label = 'Google Pixel 7'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Galaxy_A15'; Label = 'Samsung Galaxy A15'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Galaxy_S24_Ultra'; Label = 'Samsung Galaxy S24 Ultra (QHD+)'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Galaxy_Tab_S9'; Label = 'Samsung Galaxy Tab S9'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Tablet_4x3'; Label = 'Tablet 4:3 (2048x1536)'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Galaxy_A05'; Label = 'Samsung Galaxy A05 (HD+)'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Galaxy_Z_Fold_Open'; Label = 'Samsung Galaxy Z Fold (aberto)'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Galaxy_Z_Fold_Cover'; Label = 'Samsung Galaxy Z Fold (fechado)'; Cutout = 'hole' }
    [pscustomobject]@{ Avd = 'Xperia_1'; Label = 'Sony Xperia 1 (21:9)'; Cutout = 'hole' }
)

$CutoutOverlayPrefix = 'com.android.internal.display.cutout.emulation'

function Get-EmulatorDevice([string]$Name) {
    $EmulatorDevices | Where-Object { $_.Avd -eq $Name } | Select-Object -First 1
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

# Desliga os emuladores que não são o AVD pedido (um ligado por vez) e espera eles sumirem do adb.
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
        if (-not $alive.Count -and ((Get-Date) - $since).TotalSeconds -gt 20) {
            $why = Get-EmulatorFailure $Avd
            Write-Host "O emulador $Avd fechou sozinho$(if ($why) { ": $why" })" -ForegroundColor Yellow
            return $null
        }
        $e = Get-RunningEmulators $Adb | Where-Object { $_.State -eq 'device' -and $_.Avd -eq $Avd } | Select-Object -First 1
        # Com tempo-limite: um emulador congelado deixa o "adb shell" pendurado para sempre.
        $boot = if ($e) { Invoke-AdbTimeout $Adb @('-s', $e.Serial, 'shell', 'getprop', 'sys.boot_completed') 15 }
        if ($boot -and $boot.Trim() -eq '1') { return $e.Serial }
        Start-Sleep -Seconds 3
    }
    return $null
}

# Emulador travado: espera o AVD até $Minutes; se não responder (boot congelado ou
# adb pendurado), desliga à força, liga de novo do mesmo jeito e espera mais $Minutes. Uma só nova
# tentativa: devolve o serial ou $null.
function Wait-EmulatorReady([string]$Adb, [string]$AndroidSdk, [string]$Avd, [int]$Minutes = 8) {
    $serial = Wait-EmulatorFor $Adb $Avd $Minutes
    if ($serial) { return $serial }
    Write-Host "O emulador $Avd não respondeu em $Minutes minutos (ou fechou sozinho): desligando à força e ligando de novo" -ForegroundColor Yellow
    Stop-EmulatorProcess $Adb $Avd
    try { Start-EmulatorFor $Adb $AndroidSdk $Avd | Out-Null } catch {
        Write-Host "FALHOU: $($_.Exception.Message)" -ForegroundColor Red; return $null }
    return (Wait-EmulatorFor $Adb $Avd $Minutes)
}

# Liga (ou desliga) o recorte de câmera emulado do aparelho. O estado fica salvo no /data do AVD,
# mas é reaplicado a cada execução. Devolve o texto do overlay ativo ('' = nenhum).
function Set-EmulatorCutout([string]$Adb, [string]$Serial, [string]$Avd) {
    $ErrorActionPreference = 'Continue'
    $d = Get-EmulatorDevice $Avd
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
function Start-EmulatorFor([string]$Adb, [string]$AndroidSdk, [string]$Avd) {
    $ErrorActionPreference = 'Continue'
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "`"$Adb`" start-server"; CurrentDirectory = (Split-Path $Adb) } | Out-Null
    Start-Sleep -Seconds 2
    if (-not (Test-AvdExists $Avd)) {
        throw "o AVD $Avd não existe; crie-o no Device Manager do Android Studio (ou use -Avd com um AVD que já existe)"
    }
    Stop-OtherEmulators $Adb $Avd
    if (Get-RunningEmulators $Adb | Where-Object { $_.Avd -eq $Avd }) { return $false }
    Write-Host "== Ligando o emulador ($Avd)" -ForegroundColor Cyan
    $avdDir = Join-Path $env:USERPROFILE ".android\avd\$Avd.avd"
    Remove-Item "$avdDir\*.lock" -Recurse -Force -ErrorAction SilentlyContinue
    # RAM do convidado em arquivo (snapshots\default_boot\ram.img, 2,5 a 4 GB por AVD) que sobra de
    # execuções antigas: com -no-snapshot ela nunca é carregada, só ocupa o disco.
    Remove-Item "$avdDir\snapshots\default_boot\ram.img" -Force -ErrorAction SilentlyContinue
    Assert-EmulatorDiskSpace $Avd
    # -no-snapshot: boot a frio (~30 s), sem carregar nem salvar o snapshot rápido. O snapshot salvo
    # pelo "emu kill" voltava com o system_server engasgado (cmd overlay/dumpsys pendurados, app que
    # abre e não passa da inicialização) ou nem subia.
    # -feature -QuickbootFileBacked: a RAM do convidado fica na memória, não num ram.img do tamanho da
    # RAM gravado no disco a cada boot (sem snapshot ele não serve para nada; e boota mais rápido).
    $extra = ' -no-snapshot -feature -QuickbootFileBacked'
    # Saída do emulador num log: se ele fechar sozinho (ex.: FATAL de disco), o motivo aparece.
    $log = Get-EmulatorLogPath $Avd
    Remove-Item $log -Force -ErrorAction SilentlyContinue
    $emu = Join-Path $AndroidSdk 'emulator\emulator.exe'
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "cmd.exe /d /c `"`"$emu`" -avd $Avd -no-boot-anim$extra > `"$log`" 2>&1`"" } | Out-Null
    return $true
}

function Get-EmulatorLogPath([string]$Avd) {
    Join-Path $env:USERPROFILE ".android\avd\$Avd.avd\hyakki-emulator.log"
}

# Motivo de o emulador ter fechado sozinho: linhas FATAL/ERROR do log da última vez que ele foi ligado.
function Get-EmulatorFailure([string]$Avd) {
    $log = Get-EmulatorLogPath $Avd
    if (-not (Test-Path $log)) { return '' }
    $bad = @(Get-Content $log -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*(FATAL|ERROR)\b' } |
        ForEach-Object { ($_ -replace '^\s*(FATAL|ERROR)\s*\|\s*', '').Trim() } | Select-Object -First 3)
    $bad -join ' | '
}

# Espaço em disco: AVD sem userdata ainda (1º boot) precisa de 1,2 x a partição de dados livre, senão o
# emulador fecha com "Not enough space to create userdata partition" (e o boot parecia só travado).
# Com userdata, sobra uma folga para ela crescer durante o uso.
function Assert-EmulatorDiskSpace([string]$Avd) {
    $avdDir = Join-Path $env:USERPROFILE ".android\avd\$Avd.avd"
    $iniPath = Join-Path $avdDir 'config.ini'
    $dataBytes = [double]6GB
    if (Test-Path $iniPath) {
        $line = Get-Content $iniPath | Where-Object { $_ -match '^\s*disk\.dataPartition\.size\s*=\s*(\d+)\s*([KMG]?)' } | Select-Object -First 1
        if ($line -and $line -match '=\s*(\d+)\s*([KMG]?)') {
            $mult = @{ '' = 1; 'K' = 1KB; 'M' = 1MB; 'G' = 1GB }[$Matches[2].ToUpper()]
            $dataBytes = [double]$Matches[1] * $mult
        }
    }
    $firstBoot = -not (Test-Path (Join-Path $avdDir 'userdata-qemu.img'))
    $need = if ($firstBoot) { $dataBytes * 1.2 + 1GB } else { [double]2GB }
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($avdDir))
    if ($drive.AvailableFreeSpace -lt $need) {
        throw ("disco cheio para o emulador {0}: {1:N1} GB livres em {2}, precisa de {3:N1} GB{4}. Libere espaço (ex.: AVDs e snapshots antigos em {5})" -f
            $Avd, ($drive.AvailableFreeSpace / 1GB), $drive.Name, ($need / 1GB),
            $(if ($firstBoot) { ' (1º boot: cria a partição de dados)' } else { '' }), (Split-Path $avdDir))
    }
}
