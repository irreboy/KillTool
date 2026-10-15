# GameBoost.ps1
param([ValidateSet("Apply","Restore","Check")][string]$Mode = "Check",
      [switch]$Silent, [string]$StreamFile = "")

$BackupFile        = "C:\Users\jdpbe\Scripts\GameBoost_Backup.json"
$script:StreamFile = $StreamFile

function Stream { param($line)
    if ($script:StreamFile) {
        try {
            $fs = New-Object System.IO.FileStream($script:StreamFile,
                [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::ReadWrite)
            $sw = New-Object System.IO.StreamWriter($fs, [System.Text.Encoding]::UTF8)
            $sw.WriteLine($line); $sw.Flush(); $sw.Close()
        } catch {}
    }
}
function S-OK   { param($m) Stream "  [OK]  $m"; if (-not $Silent) { Write-Host "  [OK]  $m" -ForegroundColor Green } }
function S-WARN { param($m) Stream "  [!!]  $m"; if (-not $Silent) { Write-Host "  [!!]  $m" -ForegroundColor Yellow } }
function S-BAD  { param($m) Stream "  [XX]  $m"; if (-not $Silent) { Write-Host "  [XX]  $m" -ForegroundColor Red } }
function S-INFO { param($m) Stream "  [i]   $m"; if (-not $Silent) { Write-Host "  [i]   $m" -ForegroundColor Cyan } }
function S-Sec  { param($t) Stream "=SECTION=$t" }

function Is-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Optimizacion functions ---------------------------------------------
function Set-Nagle { param([bool]$Off)
    $ifaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
    foreach ($i in $ifaces) {
        if ($Off) {
            Set-ItemProperty $i.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty $i.PSPath -Name "TCPNoDelay"      -Value 1 -Type DWord -ErrorAction SilentlyContinue
        } else {
            Remove-ItemProperty $i.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
            Remove-ItemProperty $i.PSPath -Name "TCPNoDelay"      -ErrorAction SilentlyContinue
        }
    }
}
function Set-NetThrottle { param([bool]$Off)
    $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty $p -Name "NetworkThrottlingIndex" -Value $(if($Off){0xffffffff}else{10}) -Type DWord
    Set-ItemProperty $p -Name "SystemResponsiveness"   -Value $(if($Off){0}else{20})          -Type DWord
}
function Set-PowerPlan { param([bool]$Gaming)
    if ($Gaming) {
        $ultra = & powercfg /list 2>&1 | Select-String "Ultimate"
        if ($ultra) { $guid = ($ultra -split '\s+')[3]; & powercfg /setactive $guid 2>&1 | Out-Null; S-OK "Plan Ultimate Performance activado" }
        else { & powercfg /setactive SCHEME_MIN 2>&1 | Out-Null; S-OK "Plan Alto Rendimiento activado" }
    } else { & powercfg /setactive SCHEME_BALANCED 2>&1 | Out-Null; S-OK "Plan Equilibrado restaurado" }
}
function Set-GameDVR { param([bool]$Off)
    if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR")) {
        New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Force | Out-Null
    }
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value $(if($Off){0}else{1}) -Type DWord -ErrorAction SilentlyContinue
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR")) {
        New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Force | Out-Null
    }
    Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value $(if($Off){0}else{1}) -Type DWord -ErrorAction SilentlyContinue
}
function Set-HAGS { param([bool]$On)
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value $(if($On){2}else{1}) -Type DWord -ErrorAction SilentlyContinue
}
function Set-MouseAcc { param([bool]$Off)
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseSpeed"      -Value $(if($Off){"0"}else{"1"})
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value $(if($Off){"0"}else{"6"})
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value $(if($Off){"0"}else{"10"})
}
function Set-USBSuspend { param([bool]$Off)
    $v = if($Off){0}else{1}
    & powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 $v 2>&1 | Out-Null
    & powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 $v 2>&1 | Out-Null
    & powercfg /setactive scheme_current 2>&1 | Out-Null
}
function Set-FSO { param([bool]$Off)
    $p = "HKCU:\System\GameConfigStore"
    if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
    Set-ItemProperty $p -Name "GameDVR_FSEBehaviorMode"        -Value $(if($Off){2}else{0}) -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty $p -Name "GameDVR_HonorUserFSEBehaviorMode" -Value $(if($Off){1}else{0}) -Type DWord -ErrorAction SilentlyContinue
}
function Set-GamingDNS { param([bool]$On)
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Virtual -eq $false }
    foreach ($a in $adapters) {
        if ($On) { Set-DnsClientServerAddress -InterfaceAlias $a.Name -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue }
        else     { Set-DnsClientServerAddress -InterfaceAlias $a.Name -ResetServerAddresses -ErrorAction SilentlyContinue }
    }
}

# --- CHECK ---------------------------------------------------------------
function Invoke-Check {
    S-Sec "ESTADO ACTUAL DE OPTIMIZACIONES"

    $ifaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
    $nagleOff = $ifaces | Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).TCPNoDelay -eq 1 } | Select-Object -First 1
    if ($nagleOff) { S-OK  "Nagle: DESACTIVADO   (menor latencia TCP)" }
    else           { S-WARN "Nagle: ACTIVO        (aumenta ping en juegos)" }

    $nti = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
    if ($nti -eq 0xffffffff) { S-OK  "Network throttling: DESACTIVADO" }
    else                     { S-WARN "Network throttling: ACTIVO     (valor actual: $nti / optimo: 4294967295)" }

    $plan = & powercfg /getactivescheme 2>&1
    if ($plan -match "Alto rendimiento|High performance|Ultimate") { S-OK  "Plan de energia: OPTIMIZADO  ($plan)" }
    else                                                           { S-WARN "Plan de energia: NORMAL      (activo: $plan)" }

    $dvr = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -ErrorAction SilentlyContinue).AppCaptureEnabled
    if ($dvr -eq 0) { S-OK  "Xbox Game DVR: DESACTIVADO" }
    else            { S-WARN "Xbox Game DVR: ACTIVO      (graba pantalla en background, usa CPU/GPU)" }

    $ms = (Get-ItemProperty "HKCU:\Control Panel\Mouse" -ErrorAction SilentlyContinue).MouseSpeed
    if ($ms -eq "0") { S-OK  "Aceleracion de mouse: DESACTIVADA" }
    else             { S-WARN "Aceleracion de mouse: ACTIVA       (reduce precision en FPS)" }

    $hags = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue).HwSchMode
    if ($hags -eq 2) { S-OK  "HAGS (HW GPU Scheduling): ACTIVO" }
    else             { S-WARN "HAGS (HW GPU Scheduling): INACTIVO (puede mejorar frametime)" }

    $fso = (Get-ItemProperty "HKCU:\System\GameConfigStore" -ErrorAction SilentlyContinue).GameDVR_FSEBehaviorMode
    if ($fso -eq 2) { S-OK  "Fullscreen Optimizations: DESACTIVADAS" }
    else            { S-WARN "Fullscreen Optimizations: ACTIVAS    (puede causar micro-stuttering)" }

    try {
        $dns = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.ServerAddresses -contains "1.1.1.1" } | Select-Object -First 1)
        if ($dns) { S-OK "DNS: Cloudflare 1.1.1.1 (gaming DNS activo)" }
        else      { S-INFO "DNS: servidor por defecto (no Cloudflare)" }
    } catch { S-INFO "DNS: no se pudo verificar" }

    if (Test-Path $BackupFile) {
        $bkDate = (Get-Content $BackupFile -Raw | ConvertFrom-Json).Timestamp
        S-INFO "Backup guardado: $($bkDate.Substring(0,19)) - se puede restaurar"
    } else {
        S-INFO "Sin backup - Apply creara uno automaticamente"
    }

    S-Sec "RESUMEN"
    $optimized = 0; $total = 7
    if ($nagleOff) { $optimized++ }
    if ($nti -eq 0xffffffff) { $optimized++ }
    if ($plan -match "Alto rendimiento|High performance|Ultimate") { $optimized++ }
    if ($dvr -eq 0) { $optimized++ }
    if ($ms -eq "0") { $optimized++ }
    if ($hags -eq 2) { $optimized++ }
    if ($fso -eq 2) { $optimized++ }
    if ($optimized -eq $total) { S-OK "$optimized/$total ajustes gaming activos - COMPLETAMENTE OPTIMIZADO" }
    elseif ($optimized -ge 4)  { S-WARN "$optimized/$total ajustes gaming activos - PARCIALMENTE OPTIMIZADO" }
    else                       { S-BAD  "$optimized/$total ajustes gaming activos - USA [+] OPTIMIZAR PARA MEJORAR" }
}

# --- APPLY ---------------------------------------------------------------
function Invoke-Apply {
    if (-not (Is-Admin)) { S-BAD "Requiere ejecutar como Administrador"; return }

    $ifaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
    $f1 = $ifaces | Select-Object -First 1
    $backup = @{
        Timestamp = (Get-Date).ToString("o")
        NagleTCP  = (Get-ItemProperty $f1.PSPath -ErrorAction SilentlyContinue).TCPNoDelay
        NTI       = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
        SysResp   = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue).SystemResponsiveness
        GameDVR   = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -ErrorAction SilentlyContinue).AppCaptureEnabled
        Mouse     = (Get-ItemProperty "HKCU:\Control Panel\Mouse" -ErrorAction SilentlyContinue).MouseSpeed
        HAGS      = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue).HwSchMode
        Plan      = (& powercfg /getactivescheme 2>&1)
    }
    if (-not (Test-Path $BackupFile)) {
        $backup | ConvertTo-Json -Depth 5 | Out-File $BackupFile -Encoding UTF8
        S-INFO "Backup guardado en $BackupFile"
    }

    S-Sec "APLICANDO OPTIMIZACIONES GAMING"
    try { Set-Nagle -Off $true;          S-OK "Nagle desactivado" } catch { S-WARN "Nagle: $_" }
    try { Set-NetThrottle -Off $true;    S-OK "Network throttling desactivado" } catch { S-WARN "Net throttle: $_" }
    try { Set-PowerPlan -Gaming $true  } catch { S-WARN "Power plan: $_" }
    try { Set-GameDVR -Off $true;        S-OK "Xbox Game DVR desactivado" } catch { S-WARN "Game DVR: $_" }
    try { Set-HAGS -On $true;            S-OK "HAGS activado" } catch { S-WARN "HAGS: $_" }
    try { Set-MouseAcc -Off $true;       S-OK "Aceleracion de mouse desactivada" } catch { S-WARN "Mouse: $_" }
    try { Set-USBSuspend -Off $true;     S-OK "USB Selective Suspend desactivado" } catch { S-WARN "USB Suspend: $_" }
    try { Set-FSO -Off $true;            S-OK "Fullscreen Optimizations desactivadas" } catch { S-WARN "FSO: $_" }
    try { Set-GamingDNS -On $true;       S-OK "DNS cambiado a Cloudflare 1.1.1.1" } catch { S-WARN "DNS: $_" }
    S-INFO "Reinicia para aplicar todos los cambios"
}

# --- RESTORE -------------------------------------------------------------
function Invoke-Restore {
    if (-not (Is-Admin)) { S-BAD "Requiere ejecutar como Administrador"; return }
    if (-not (Test-Path $BackupFile)) { S-BAD "No hay backup disponible"; return }
    $bk = Get-Content $BackupFile -Raw | ConvertFrom-Json
    S-Sec "RESTAURANDO CONFIGURACION ORIGINAL (backup: $($bk.Timestamp.Substring(0,10)))"
    try { Set-Nagle -Off $false;         S-OK "Nagle restaurado" } catch { S-WARN "Nagle: $_" }
    $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    try {
        Set-ItemProperty $p -Name "NetworkThrottlingIndex" -Value $(if($bk.NTI){$bk.NTI}else{10}) -Type DWord
        Set-ItemProperty $p -Name "SystemResponsiveness"   -Value $(if($null -ne $bk.SysResp){$bk.SysResp}else{20}) -Type DWord
        S-OK "Network throttling restaurado"
    } catch { S-WARN "Net throttle: $_" }
    try { Set-PowerPlan -Gaming $false } catch { S-WARN "Power plan: $_" }
    try { Set-GameDVR -Off $false;       S-OK "Game DVR restaurado" } catch { S-WARN "Game DVR: $_" }
    try {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
            -Name "HwSchMode" -Value $(if($null -ne $bk.HAGS){$bk.HAGS}else{1}) -Type DWord
        S-OK "HAGS restaurado"
    } catch { S-WARN "HAGS: $_" }
    try { Set-MouseAcc -Off $false;      S-OK "Mouse restaurado" } catch { S-WARN "Mouse: $_" }
    try { Set-USBSuspend -Off $false;    S-OK "USB Suspend restaurado" } catch { S-WARN "USB Suspend: $_" }
    try { Set-FSO -Off $false;           S-OK "FSO restaurada" } catch { S-WARN "FSO: $_" }
    try { Set-GamingDNS -On $false;      S-OK "DNS restaurado a automatico" } catch { S-WARN "DNS: $_" }
    Remove-Item $BackupFile -Force -ErrorAction SilentlyContinue
    S-OK "Config original restaurada. Backup eliminado."
    S-INFO "Reinicia para aplicar todos los cambios"
}

switch ($Mode) {
    "Check"   { Invoke-Check }
    "Apply"   { Invoke-Apply }
    "Restore" { Invoke-Restore }
}

[PSCustomObject]@{ Mode=$Mode; HasBackup=(Test-Path $BackupFile) }
