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

foreach ($msu in $msuFiles) {
    $currentStep++
    $msuName = $msu.Name
    $kbMatch = [regex]::Match($msuName, 'KB\d{7}')
    $kb = if ($kbMatch.Success) { $kbMatch.Value } else { "Unknown" }

    $pct = if ($totalMsus -gt 0) { [math]::Min(100, [int](($currentStep / $totalMsus) * 100)) } else { 100 }
    Write-Progress -Activity "Installing Windows 11 updates" -Status "Update $currentStep of $totalMsus" -PercentComplete $pct -CurrentOperation $msuName

    # Check if this update (KB) is already installed
    $alreadyInstalled = $false
    if ($kb -ne "Unknown") {
        $hotfix = Get-HotFix -Id $kb -ErrorAction SilentlyContinue
        if ($hotfix) {
            $alreadyInstalled = $true
            $ts = Get-Date -Format "HH:mm:ss"
            Write-Host "[$ts] Already installed: $msuName (installed $($hotfix.InstalledOn))"
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
    $status = if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) { "Success" } else { "Failed" }
    if ($process.ExitCode -eq 3010) {
        $RebootRequired = $true
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
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "[$ts] === Installation Complete ==="

# Write CSV log
$CsvPath = "$LogPath\install_${ComputerName}_$(Get-Date -Format yyyyMMdd_HHmm).csv"
$LogEntries | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

if ($RebootRequired) {
    Write-Host "Reboot required."
} else {
    Write-Host "No reboot required."
}

Write-Host "Log: $CsvPath"
Stop-Transcript
