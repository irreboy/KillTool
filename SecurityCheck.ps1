# SecurityCheck.ps1
param([switch]$Silent, [switch]$AutoFix, [string]$StreamFile = "")

$ReportDate        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogFile           = "C:\Users\jdpbe\Scripts\Logs\SecurityReport_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
$script:Alerts     = @()
$script:StreamFile = $StreamFile
$script:LogLines   = @()

New-Item -ItemType Directory -Force -Path "C:\Users\jdpbe\Scripts\Logs" | Out-Null

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
    $script:LogLines += $line
}
function Write-Section { param($Title) Stream "=SECTION=$Title" }
function Write-OK   { param($msg) Stream "  [OK]  $msg" }
function Write-WARN { param($msg, [string]$FixCmd = "")
    Stream "  [!!]  $msg"
    $script:Alerts += [PSCustomObject]@{ Level="WARN"; Msg=$msg; FixCmd=$FixCmd }
}
function Write-BAD  { param($msg, [string]$FixCmd = "")
    Stream "  [XX]  $msg"
    $script:Alerts += [PSCustomObject]@{ Level="CRIT"; Msg="CRITICO: $msg"; FixCmd=$FixCmd }
}

Stream "REPORTE DE SEGURIDAD - $ReportDate"
Stream "Equipo: $env:COMPUTERNAME | Usuario: $env:USERNAME"

# --- 1. WINDOWS DEFENDER ------------------------------------------------
Write-Section "1. WINDOWS DEFENDER"
try {
    $status = Get-MpComputerStatus -ErrorAction Stop
    if ($status.RealTimeProtectionEnabled) { Write-OK "Proteccion en tiempo real: ACTIVA" }
    else { Write-BAD "Proteccion en tiempo real: DESACTIVADA" -FixCmd "Set-MpPreference -DisableRealtimeMonitoring `$false" }

    if ($status.AntivirusSignatureAge -le 3) { Write-OK "Definiciones actualizadas (hace $($status.AntivirusSignatureAge) dias)" }
    else { Write-WARN "Definiciones desactualizadas (hace $($status.AntivirusSignatureAge) dias)" -FixCmd "Update-MpSignature" }

    if ($status.IsTamperProtected) { Write-OK "Tamper Protection: ACTIVA" }
    else { Write-WARN "Tamper Protection: INACTIVA - habilita en Windows Security > Virus & threat protection" }

    $threats = Get-MpThreatDetection -ErrorAction SilentlyContinue |
               Where-Object { $_.InitialDetectionTime -gt (Get-Date).AddDays(-1) }
    if ($threats) {
        foreach ($t in $threats) {
            Write-BAD "Amenaza detectada: $($t.ThreatName) - Bloqueada: $($t.ActionSuccess)" -FixCmd "Start-MpScan -ScanType QuickScan"
        }
    } else { Write-OK "Sin amenazas en las ultimas 24h" }
} catch { Write-WARN "No se pudo consultar Windows Defender: $_" }

# --- 2. AUTOARRANQUE ----------------------------------------------------
Write-Section "2. AUTOARRANQUE (Run / RunOnce)"
$knownGood = @("OneDrive","EpicGamesLauncher","Steam","Battle.net","WallpaperEngine",
               "Discord","RobloxPlayerBeta","LGHUB","RiotClient","SecurityHealth",
               "RtkAudUService","Corsair iCUE5 Software","Riot Vanguard","RPMKickstart")
$runKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)
foreach ($key in $runKeys) {
    $entries = Get-ItemProperty $key -ErrorAction SilentlyContinue
    if ($entries) {
        $entries.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
            $name = $_.Name; $val = $_.Value
            if ($knownGood -contains $name) { Write-OK "$name => $val" }
            else {
                $sk = $key -replace "'","''"; $sn = $name -replace "'","''"
                Write-WARN "DESCONOCIDO en $key`: $name => $val" `
                    -FixCmd "Remove-ItemProperty -Path '$sk' -Name '$sn' -ErrorAction SilentlyContinue"
            }
        }
    }
}

# --- 3. WINLOGON --------------------------------------------------------
Write-Section "3. INTEGRIDAD DEL SHELL (Winlogon)"
$wl = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
if ($wl.Shell -eq "explorer.exe") { Write-OK "Shell: explorer.exe (normal)" }
else { Write-BAD "Shell modificado: $($wl.Shell)" `
    -FixCmd "Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'Shell' -Value 'explorer.exe'" }
if ($wl.Userinit -match "userinit.exe") { Write-OK "Userinit: normal" }
else { Write-BAD "Userinit modificado: $($wl.Userinit)" `
    -FixCmd "Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'Userinit' -Value 'C:\Windows\system32\userinit.exe,'" }

# --- 4. INSTALACIONES RECIENTES -----------------------------------------
Write-Section "4. PROGRAMAS INSTALADOS ULTIMOS 7 DIAS"
$since = (Get-Date).AddDays(-7).ToString("yyyyMMdd")
$recent = @()
@("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*") | ForEach-Object {
    Get-ItemProperty $_ -ErrorAction SilentlyContinue |
    Where-Object { $_.InstallDate -ge $since -and $_.DisplayName } |
    ForEach-Object { $recent += $_ }
}
if ($recent) { foreach ($a in $recent) { Write-WARN "Instalado $($a.InstallDate): $($a.DisplayName) | $($a.Publisher)" } }
else { Write-OK "Sin instalaciones recientes" }

# --- 5. TAREAS PROGRAMADAS ----------------------------------------------
Write-Section "5. TAREAS PROGRAMADAS (no-Microsoft)"
$knownTasks = @("GCC","AmdX3DInstaller","SoftLanding","GoogleUserPEH","RunPlatformExperienceHelper",
                "MSIAfterburner","NVIDIA","OneDrive","SecurityCheck_Diario")
$suspect = Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskPath -notmatch "\\Microsoft\\" -and $_.State -ne "Disabled" } |
    Where-Object { $t = $_; -not ($knownTasks | Where-Object { $t.TaskName -match $_ -or $t.TaskPath -match $_ }) }
if ($suspect) {
    foreach ($t in $suspect) {
        $action = ($t.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join " | "
        $stn = $t.TaskName -replace "'","''"; $stp = $t.TaskPath -replace "'","''"
        Write-WARN "Tarea: $($t.TaskName) | $action" -FixCmd "Disable-ScheduledTask -TaskName '$stn' -TaskPath '$stp' | Out-Null"
    }
} else { Write-OK "Sin tareas programadas sospechosas" }

# --- 6. EXTENSIONES DE NAVEGADOR ----------------------------------------
Write-Section "6. EXTENSIONES DE NAVEGADOR"
$knownExt = @("bojobppfploabceghnmlahpoonbcbacn","ihcjicgdanjaechkgeegckofjjedodee",
              "odfafepnkmbhccpbejgmiehpchacaeak","ddkjiahejlhfcafbddmgiahcphecmpfh",
              "ghbmnnjooekpmoecnnnilnnbdlolhkhi","jmjflgjpcpepeafmmgdpfkogkghcpiha",
              "ndcileolkflehcjpmjnfbnaibdcgglog","fbcohnmimjicjdomonkcbcpbpnhggkip",
              "bmanlajnpdncmhfkiccmbgeocgbncfln","nmmhkkegccagdldgiimedpiccmgmieda")
@{ "Edge"   = "C:\Users\jdpbe\AppData\Local\Microsoft\Edge\User Data\Default\Extensions";
   "Chrome" = "C:\Users\jdpbe\AppData\Local\Google\Chrome\User Data\Default\Extensions" }.GetEnumerator() |
ForEach-Object {
    $browser = $_.Key; $extPath = $_.Value
    if (-not (Test-Path $extPath)) { return }
    Get-ChildItem $extPath -Directory | ForEach-Object {
        $id  = $_.Name
        $mf  = Get-ChildItem $_.FullName -Recurse -Filter "manifest.json" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $mf) { return }
        $raw = Get-Content $mf.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        $name = $raw.name -replace "__MSG_\w+__","(loc)"
        if ($knownExt -contains $id) { Write-OK "[$browser] $name" }
        else { Write-WARN "[$browser] DESCONOCIDA: $name ($id) | $($raw.permissions -join ', ')" }
    }
}

# --- 7. EJECUTABLES RECIENTES -------------------------------------------
Write-Section "7. EJECUTABLES RECIENTES (Downloads / Temp)"
$found = $false
@("C:\Users\jdpbe\Downloads","C:\Users\jdpbe\AppData\Local\Temp") | ForEach-Object {
    $folder = $_
    Get-ChildItem $folder -File -Include "*.exe","*.bat","*.ps1","*.vbs","*.msi","*.cmd" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) } | ForEach-Object {
        $found = $true
        Write-WARN "Ejecutable en $($_.Directory.Name): $($_.Name) ($([math]::Round($_.Length/1KB,1)) KB)"
    }
}
if (-not $found) { Write-OK "Sin ejecutables recientes sospechosos" }

# --- 8. SMBv1 (VECTOR DE RANSOMWARE) ------------------------------------
Write-Section "8. SMBv1 (VECTOR DE RANSOMWARE)"
try {
    $smb = Get-SmbServerConfiguration -ErrorAction Stop
    if ($smb.EnableSMB1Protocol) {
        Write-BAD "SMBv1 HABILITADO - vector clasico de ransomware (WannaCry, NotPetya)" `
            -FixCmd "Set-SmbServerConfiguration -EnableSMB1Protocol `$false -Force"
    } else { Write-OK "SMBv1 deshabilitado" }
} catch { Write-WARN "SMBv1: no se pudo verificar - $_" }

# --- 9. LLMNR / NBNS (NAME SPOOFING) ------------------------------------
Write-Section "9. LLMNR / NBNS (NAME SPOOFING)"
$llmnr = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -ErrorAction SilentlyContinue).EnableMulticast
if ($llmnr -eq 0) {
    Write-OK "LLMNR deshabilitado via GPO"
} else {
    Write-WARN "LLMNR habilitado - permite ataques de name spoofing / NTLM relay en red local" `
        -FixCmd "if (-not (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient')) { New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Force | Out-Null }; Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -Value 0 -Type DWord"
}

# --- 10. POWERSHELL v2 (BYPASS DE LOGGING) ------------------------------
Write-Section "10. POWERSHELL v2 (BYPASS DE LOGGING)"
try {
    $psv2 = Get-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -ErrorAction Stop
    if ($psv2.State -eq "Enabled") {
        Write-WARN "PowerShell v2 habilitado - puede usarse para evadir ScriptBlock Logging" `
            -FixCmd "Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart | Out-Null"
    } else { Write-OK "PowerShell v2 deshabilitado" }
} catch { Write-OK "PowerShell v2: no disponible / no instalado en este sistema" }

# --- 11. WINDOWS FIREWALL (3 PERFILES) ----------------------------------
Write-Section "11. WINDOWS FIREWALL (3 PERFILES)"
try {
    $profiles = Get-NetFirewallProfile -ErrorAction Stop
    foreach ($p in $profiles) {
        if ($p.Enabled) { Write-OK "Firewall [$($p.Name)]: ACTIVO" }
        else { Write-BAD "Firewall [$($p.Name)]: DESACTIVADO" -FixCmd "Set-NetFirewallProfile -Name '$($p.Name)' -Enabled True" }
    }
} catch { Write-WARN "Firewall: no se pudo verificar - $_" }

# --- 12. ESCRITORIO REMOTO (RDP) ----------------------------------------
Write-Section "12. ESCRITORIO REMOTO (RDP)"
try {
    $rdpEnabled = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -ErrorAction Stop).fDenyTSConnections
    if ($rdpEnabled -eq 0) {
        Write-WARN "RDP habilitado - verifica que sea realmente necesario"
        $nla = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -ErrorAction SilentlyContinue).UserAuthentication
        if ($nla -eq 1) { Write-OK "RDP: NLA (Network Level Auth) activa - configuracion correcta" }
        else { Write-BAD "RDP sin NLA - vulnerable a ataques pre-autenticacion" `
            -FixCmd "Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'UserAuthentication' -Value 1 -Type DWord" }
    } else { Write-OK "RDP deshabilitado" }
} catch { Write-OK "RDP: estado no determinado" }

# --- 13. SECURE BOOT ----------------------------------------------------
Write-Section "13. SECURE BOOT"
try {
    $sb = Confirm-SecureBootUEFI -ErrorAction Stop
    if ($sb) { Write-OK "Secure Boot: ACTIVO" }
    else      { Write-WARN "Secure Boot: INACTIVO - habilita en BIOS/UEFI para mayor proteccion" }
} catch { Write-OK "Secure Boot: sistema BIOS legacy o estado no verificable" }

# --- 14. AUTORUN EN UNIDADES --------------------------------------------
Write-Section "14. AUTORUN EN UNIDADES"
$autorunVal = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ErrorAction SilentlyContinue).NoDriveTypeAutoRun
if ($autorunVal -eq 255 -or $autorunVal -eq 0xFF) {
    Write-OK "AutoRun deshabilitado en todas las unidades"
} else {
    Write-WARN "AutoRun no bloqueado completamente (valor: $autorunVal) - riesgo con USB maliciosos" `
        -FixCmd "Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255 -Type DWord"
}

# --- 15. CUENTAS LOCALES ADMINISTRADOR ----------------------------------
Write-Section "15. CUENTAS LOCALES ADMINISTRADOR"
try {
    $admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop | Where-Object { $_.ObjectClass -eq "User" }
    foreach ($a in $admins) {
        $localName = $a.Name -replace ".*\\"
        $user = Get-LocalUser -Name $localName -ErrorAction SilentlyContinue
        if ($user) {
            if ($user.Enabled) { Write-OK "Admin activa: $($a.Name)" }
            else               { Write-OK "Admin deshabilitada: $($a.Name) [correcto para builtin]" }
        } else { Write-OK "Admin (dominio): $($a.Name)" }
    }
    $builtinAdmin = Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue
    if ($builtinAdmin -and $builtinAdmin.Enabled) {
        Write-WARN "Cuenta 'Administrator' builtin habilitada - considera deshabilitarla si no la usas" `
            -FixCmd "Disable-LocalUser -Name 'Administrator'"
    }
} catch { Write-OK "Cuentas admin: no se pudo verificar completamente" }

# --- RESUMEN ------------------------------------------------------------
Write-Section "RESUMEN"
if ($script:Alerts.Count -eq 0) { Write-OK "Sistema limpio. Sin alertas." }
else { Write-WARN "Total de alertas: $($script:Alerts.Count)" }

$script:LogLines | Out-File -FilePath $LogFile -Encoding UTF8

if ($AutoFix) {
    foreach ($a in $script:Alerts) {
        if ($a.FixCmd) { try { & ([scriptblock]::Create($a.FixCmd)) | Out-Null } catch {} }
    }
}

[PSCustomObject]@{ Alerts=$script:Alerts; LogFile=$LogFile }
