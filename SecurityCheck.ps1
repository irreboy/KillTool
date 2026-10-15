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

function Write-Section { param($Title)
    Stream "=SECTION=$Title"
}
function Write-OK   { param($msg)
    Stream "  [OK]  $msg"
}
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
    if ($status.RealTimeProtectionEnabled) {
        Write-OK "Proteccion en tiempo real: ACTIVA"
    } else {
        Write-BAD "Proteccion en tiempo real: DESACTIVADA" `
            -FixCmd "Set-MpPreference -DisableRealtimeMonitoring `$false"
    }
    if ($status.AntivirusSignatureAge -le 3) {
        Write-OK "Definiciones actualizadas (hace $($status.AntivirusSignatureAge) dias)"
    } else {
        Write-WARN "Definiciones desactualizadas (hace $($status.AntivirusSignatureAge) dias)" `
            -FixCmd "Update-MpSignature"
    }
    $threats = Get-MpThreatDetection -ErrorAction SilentlyContinue |
               Where-Object { $_.InitialDetectionTime -gt (Get-Date).AddDays(-1) }
    if ($threats) {
        foreach ($t in $threats) {
            Write-BAD "Amenaza detectada: $($t.ThreatName) - Bloqueada: $($t.ActionSuccess)" `
                -FixCmd "Start-MpScan -ScanType QuickScan"
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
                $sk = $key  -replace "'","''"
                $sn = $name -replace "'","''"
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
        Write-WARN "Tarea: $($t.TaskName) | $action" `
            -FixCmd "Disable-ScheduledTask -TaskName '$stn' -TaskPath '$stp' | Out-Null"
    }
} else { Write-OK "Sin tareas programadas sospechosas" }

# --- 6. EXTENSIONES DE NAVEGADOR ----------------------------------------
Write-Section "6. EXTENSIONES DE NAVEGADOR"
$knownExt = @("bojobppfploabceghnmlahpoonbcbacn","ihcjicgdanjaechkgeegckofjjedodee",
              "odfafepnkmbhccpbejgmiehpchacaeak","ddkjiahejlhfcafbddmgiahcphecmpfh",
              "ghbmnnjooekpmoecnnnilnnbdlolhkhi","jmjflgjpcpepeafmmgdpfkogkghcpiha",
              "ndcileolkflehcjpmjnfbnaibdcgglog","fbcohnmimjicjdomonkcbcpbpnhggkip",
              "bmanlajnpdncmhfkiccmbgeocgbncfln","nmmhkkegccagdldgiimedpiccmgmieda")
@{ "Edge"="C:\Users\jdpbe\AppData\Local\Microsoft\Edge\User Data\Default\Extensions";
   "Chrome"="C:\Users\jdpbe\AppData\Local\Google\Chrome\User Data\Default\Extensions" }.GetEnumerator() |
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
