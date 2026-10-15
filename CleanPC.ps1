# CleanPC.ps1
param([switch]$Silent, [switch]$IncludeDISM, [string]$StreamFile = "")

$script:StreamFile  = $StreamFile
$script:BytesFreed  = 0

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
function Log-Step { param($msg, $tag = "[OK]", $color = "Green")
    $line = "  $tag  $msg"
    Stream $line
    if (-not $Silent) { Write-Host $line -ForegroundColor $color }
}
function Log-Section { param($title)
    Stream "=SECTION=$title"
}

function Get-FolderSize { param($Path)
    if (-not (Test-Path $Path)) { return 0 }
    try { (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } catch { 0 }
}

function Remove-Folder { param($Path, $Label)
    if (-not (Test-Path $Path)) { Log-Step "$Label : no existe, omitido" "[--]" "DarkGray"; return 0 }
    $before = Get-FolderSize $Path
    try {
        Get-ChildItem $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $freed = $before - (Get-FolderSize $Path)
        Log-Step "$Label : $([math]::Round($freed/1MB,1)) MB liberados" "[OK]" "Green"
        return $freed
    } catch { Log-Step "$Label : error parcial" "[!!]" "Yellow"; return 0 }
}

Log-Section "LIMPIEZA DE ARCHIVOS TEMPORALES"
$script:BytesFreed += Remove-Folder $env:TEMP              "Temp usuario (%TEMP%)"
$script:BytesFreed += Remove-Folder "C:\Windows\Temp"      "Temp sistema"
$script:BytesFreed += Remove-Folder "C:\Windows\Prefetch"  "Prefetch"
$script:BytesFreed += Remove-Folder "C:\Windows\Minidump"  "Minidumps"
$script:BytesFreed += Remove-Folder "$env:LOCALAPPDATA\CrashDumps" "CrashDumps"

Log-Section "CACHÉS DEL SISTEMA"
$thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
$before = Get-FolderSize $thumbPath
Get-ChildItem $thumbPath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$script:BytesFreed += $before - (Get-FolderSize $thumbPath)
Log-Step "Thumbnails cache: $([math]::Round(($before - (Get-FolderSize $thumbPath))/1MB,1)) MB" "[OK]"

try { Clear-DnsClientCache -ErrorAction Stop; Log-Step "Cache DNS limpiada" "[OK]" }
catch { Log-Step "Cache DNS: error" "[!!]" "Yellow" }

$script:BytesFreed += Remove-Folder "C:\Windows\SoftwareDistribution\Download" "Windows Update cache"

Log-Section "CACHÉS DE NAVEGADORES"
@{ "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default";
   "Edge"   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default" }.GetEnumerator() | ForEach-Object {
    $browser = $_.Key; $base = $_.Value
    foreach ($sub in @("Cache","Code Cache","GPUCache")) {
        $script:BytesFreed += Remove-Folder "$base\$sub" "$browser $sub"
    }
}

Log-Section "LIMPIEZA FINAL"
try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Log-Step "Papelera vaciada" "[OK]" }
catch { Log-Step "Papelera: error" "[!!]" "Yellow" }

if ($IncludeDISM) {
    Log-Step "Ejecutando DISM cleanup (puede tardar varios minutos)..." "[..]" "Cyan"
    try { & dism /online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null; Log-Step "DISM completado" "[OK]" }
    catch { Log-Step "DISM: error" "[!!]" "Yellow" }
}

$totalGB = [math]::Round($script:BytesFreed / 1GB, 2)
$totalMB = [math]::Round($script:BytesFreed / 1MB, 0)
Log-Section "RESULTADO"
Log-Step "Total liberado: $totalGB GB ($totalMB MB)" "[OK]"

[PSCustomObject]@{ BytesFreed=$script:BytesFreed; TotalGB=$totalGB }
