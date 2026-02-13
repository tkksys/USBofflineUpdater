# Windows 11 Offline Installer - messages in English to avoid mojibake
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Windows 11 Offline Installer ==="

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

Write-Host "Detected: $ProductName $DisplayVersion (Build $BuildNumber)"

if (!(Test-Path $UpdatePath)) {
    Write-Host "No updates folder found. Check Updates\$TargetFolder"
    Stop-Transcript
    exit 1
}

$RebootRequired = $false
$LogEntries = @()
$ComputerName = $env:COMPUTERNAME

Get-ChildItem "$UpdatePath\*.msu" | ForEach-Object {
    $msuName = $_.Name
    $kbMatch = [regex]::Match($msuName, 'KB\d{7}')
    $kb = if ($kbMatch.Success) { $kbMatch.Value } else { "Unknown" }

    # Check if this update (KB) is already installed
    $alreadyInstalled = $false
    if ($kb -ne "Unknown") {
        $hotfix = Get-HotFix -Id $kb -ErrorAction SilentlyContinue
        if ($hotfix) {
            $alreadyInstalled = $true
            Write-Host "Already installed: $msuName (installed $($hotfix.InstalledOn))"
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
        return
    }

    Write-Host "Installing $msuName"

    $process = Start-Process "wusa.exe" `
        -ArgumentList "`"$($_.FullName)`" /quiet /norestart" `
        -Wait -PassThru

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

# Write CSV log
$CsvPath = "$LogPath\install_${ComputerName}_$(Get-Date -Format yyyyMMdd_HHmm).csv"
$LogEntries | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

Write-Host "=== Installation Complete ==="

if ($RebootRequired) {
    Write-Host "Reboot required."
} else {
    Write-Host "No reboot required."
}

Write-Host "Log: $CsvPath"
Stop-Transcript
