# Windows 11 Offline Installer - messages in English to avoid mojibake
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Windows 11 Offline Installer ==="
$ScriptStartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "PID: $PID | Started: $ScriptStartTime | Script: install_updates.ps1"
Write-Host "Liveness: In Task Manager, find this process by PID $PID; timestamps and child PIDs below show progress."

$LogPath = "$PSScriptRoot\logs"
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath | Out-Null
}

$LogFile = "$LogPath\install_$(Get-Date -Format yyyyMMdd_HHmmss).log"
# -Encoding not supported in Windows PowerShell 5.1
Start-Transcript $LogFile

# Best practice: require Administrator (batch also checks; this is a safeguard)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script must be run as Administrator."
    Stop-Transcript
    exit 1
}

$RegPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Reg = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue

# OS build: registry CurrentBuild (reliable). Script previously used WindowsBuildNumber which does not exist.
$BuildNumber = [int]($Reg.CurrentBuild -as [string])
if ($BuildNumber -eq 0) {
    $OS = Get-ComputerInfo -ErrorAction SilentlyContinue
    $BuildNumber = [int]($OS.OsBuildNumber -as [string])
}
if ($BuildNumber -eq 0) { $BuildNumber = 26200 }

$ProductName = $Reg.ProductName -as [string]
if ([string]::IsNullOrEmpty($ProductName)) {
    $OS = Get-ComputerInfo -ErrorAction SilentlyContinue
    $ProductName = $OS.WindowsProductName -as [string]
}

# DisplayVersion from registry (e.g. 24H2, 23H2, 25H2)
$DisplayVersion = $Reg.DisplayVersion -as [string]

# Fallback: map build number to DisplayVersion
if ([string]::IsNullOrEmpty($DisplayVersion)) {
    $buildMap = @{
        22000 = "21H2"
        22621 = "22H2"
        22631 = "23H2"
        26100 = "24H2"
        26200 = "25H2"
    }
    $DisplayVersion = $buildMap[$BuildNumber]
    if ([string]::IsNullOrEmpty($DisplayVersion)) {
        $DisplayVersion = "Build$BuildNumber"
    }
}

# Windows 11: ProductName often reports "Windows 10" (known issue). Use build number.
# Build 22000+ = Windows 11
$IsWin11 = ($ProductName -like "*Windows 11*") -or ($BuildNumber -ge 22000)
if (-not $IsWin11) {
    Write-Host "This script supports Windows 11 only."
    Stop-Transcript
    exit 1
}

# Normalize display: registry often shows "Windows 10 Pro" on Windows 11
if ($BuildNumber -ge 22000 -and $ProductName -like "*Windows 10*") {
    $ProductName = $ProductName -replace "Windows 10", "Windows 11"
}

$TargetFolder = "Win11_$DisplayVersion"
$UpdatePath = "$PSScriptRoot\Updates\$TargetFolder"

$ts = Get-Date -Format "HH:mm:ss"
Write-Host "[$ts] Detected: $ProductName $DisplayVersion (Build $BuildNumber)"

if (!(Test-Path $UpdatePath)) {
    Write-Host "No updates folder found. Check Updates\$TargetFolder"
    Stop-Transcript
    exit 1
}

$RebootRequired = $false
$LogEntries = @()
$ComputerName = $env:COMPUTERNAME

$msuFiles = @(Get-ChildItem "$UpdatePath\*.msu")
$totalMsus = $msuFiles.Count
$currentStep = 0

# Get DISM package list once (detect already-installed CUs that Get-HotFix may miss)
$ts = Get-Date -Format "HH:mm:ss"
Write-Host "[$ts] Checking installed packages (DISM)..."
$dismPackageList = & dism.exe /online /get-packages 2>$null | Out-String

$barWidth = 30
foreach ($msu in $msuFiles) {
    $currentStep++
    $msuName = $msu.Name
    # Match KB + 7 digits (case-insensitive: windows11.0-kb5043080-x64.msu)
    $kbMatch = [regex]::Match($msuName, '(?i)kb\d{7}')
    $kb = if ($kbMatch.Success) { $kbMatch.Value.ToUpperInvariant() } else { "Unknown" }

    $pct = if ($totalMsus -gt 0) { [math]::Min(100, [int](($currentStep / $totalMsus) * 100)) } else { 100 }
    $filled = if ($totalMsus -gt 0) { [int]($barWidth * $currentStep / $totalMsus) } else { $barWidth }
    $bar = "[" + ("|" * $filled) + ("-" * ($barWidth - $filled)) + "]"
    Write-Host "Progress: $bar $currentStep/$totalMsus ($pct%)"
    Write-Progress -Activity "Installing Windows 11 updates" -Status "Update $currentStep of $totalMsus" -PercentComplete $pct -CurrentOperation $msuName

    # Check if this update (KB) is already installed (Get-HotFix misses some CUs; DISM is more reliable)
    $alreadyInstalled = $false
    if ($kb -ne "Unknown") {
        $hotfix = Get-HotFix -Id $kb -ErrorAction SilentlyContinue
        if ($hotfix) {
            $alreadyInstalled = $true
            $ts = Get-Date -Format "HH:mm:ss"
            Write-Host "[$ts] Already installed: $msuName (Get-HotFix: $($hotfix.InstalledOn))"
        }
        if (-not $alreadyInstalled -and $dismPackageList -match [regex]::Escape(($kb -replace '^KB', ''))) {
            $alreadyInstalled = $true
            $ts = Get-Date -Format "HH:mm:ss"
            Write-Host "[$ts] Already installed: $msuName (found in DISM packages)"
        }
    }

    if ($alreadyInstalled) {
        $LogEntries += [PSCustomObject]@{
            PCName    = $ComputerName
            OS        = "Win11_$DisplayVersion"
            KB        = $kb
            Status    = "Already installed"
            Date      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        continue
    }

    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] Installing $msuName (script PID: $PID)"
    Write-Progress -Activity "Installing Windows 11 updates" -Status "Update $currentStep of $totalMsus - Installing $kb..." -PercentComplete $pct -CurrentOperation "Running wusa.exe..."

    $process = Start-Process "wusa.exe" `
        -ArgumentList "`"$($msu.FullName)`" /quiet /norestart" `
        -PassThru -WindowStyle Hidden
    Write-Host "[$ts] wusa.exe started (child PID: $($process.Id)) - check Task Manager for liveness"
    $null = $process.WaitForExit(-1)

    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] wusa.exe finished (PID $($process.Id) exit code: $($process.ExitCode))"
    # 0=success, 3010=reboot required, -2145124329/0x80240017=not applicable (e.g. already installed), 2359302=often not applicable
    $exitCode = $process.ExitCode
    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
        $status = "Success"
        if ($exitCode -eq 3010) { $RebootRequired = $true }
    } elseif ($exitCode -eq -2145124329 -or $exitCode -eq 2359302) {
        $status = "Skipped (not applicable)"
        Write-Host "[$ts] Update not applicable to this system (already installed or wrong build)."
    } else {
        $status = "Failed"
    }

    $LogEntries += [PSCustomObject]@{
        PCName    = $ComputerName
        OS        = "Win11_$DisplayVersion"
        KB        = $kb
        Status    = $status
        Date      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

Write-Progress -Activity "Installing Windows 11 updates" -Completed
if ($totalMsus -gt 0) {
    $bar = "[" + ("|" * $barWidth) + "]"
    Write-Host "Progress: $bar $totalMsus/$totalMsus (100%) - Done."
}
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "[$ts] === Installation Complete ==="

# Write CSV log
$CsvPath = "$LogPath\install_${ComputerName}_$(Get-Date -Format yyyyMMdd_HHmm).csv"
$LogEntries | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

# Success determination: no "Failed" = success (Success, Skipped, Already installed are all OK)
$failedCount = ($LogEntries | Where-Object { $_.Status -eq "Failed" }).Count
$successCount = ($LogEntries | Where-Object { $_.Status -eq "Success" }).Count
$skippedCount = ($LogEntries | Where-Object { $_.Status -eq "Skipped (not applicable)" }).Count
$alreadyCount = ($LogEntries | Where-Object { $_.Status -eq "Already installed" }).Count

Write-Host "--- Result ---"
Write-Host "Success: $successCount | Already installed: $alreadyCount | Skipped (not applicable): $skippedCount | Failed: $failedCount"
if ($failedCount -gt 0) {
    Write-Host "Overall: Failed ($failedCount update(s) failed)"
    $script:ExitCode = 1
} else {
    Write-Host "Overall: Success"
    $script:ExitCode = 0
}

if ($RebootRequired) {
    Write-Host "Reboot required."
} else {
    Write-Host "No reboot required."
}

Write-Host "Log: $CsvPath"
Stop-Transcript
exit $script:ExitCode
