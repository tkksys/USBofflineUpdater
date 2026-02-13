param(
    [string]$DestinationPath = $PSScriptRoot,
    [string[]]$Versions = @("22H2", "23H2", "24H2", "25H2")
)

# Output in English to avoid mojibake
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Ensure path is single string (guard for array)
if ($DestinationPath -is [array] -or [string]::IsNullOrEmpty($DestinationPath)) {
    $DestinationPath = $PSScriptRoot
}
$DestinationPath = $DestinationPath.ToString().Trim()
if ($Versions -eq $null -or $Versions.Count -eq 0) {
    $Versions = @("22H2", "23H2", "24H2", "25H2")
}

Write-Host "=== Windows 11 Offline Update Downloader (MSCatalogLTS) ==="
$ScriptStartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "PID: $PID | Started: $ScriptStartTime | Script: download_updates.ps1"
Write-Host "Liveness: In Task Manager, find this process by PID $PID; timestamps below show progress."

# Script location = USB path (auto-detect)
$UsbRoot = $DestinationPath
if ($UsbRoot -eq $PSScriptRoot) {
    Write-Host "USB path (auto): $UsbRoot"
}

# Save under Updates\Win11_xx
$BasePath = Join-Path $UsbRoot "Updates"
if (!(Test-Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
}
Write-Host "Destination: $BasePath"

# Ensure MSCatalogLTS is installed
if (-not (Get-Module -ListAvailable -Name MSCatalogLTS)) {
    Write-Host "Installing MSCatalogLTS module..."
    Install-Module MSCatalogLTS -Force -Scope CurrentUser -AllowClobber
}

Import-Module MSCatalogLTS -Force

$totalVersions = $Versions.Count
$currentStep = 0
$barWidth = 30

foreach ($ver in $Versions) {
    $currentStep++
    $pct = [math]::Min(100, [int](($currentStep / $totalVersions) * 100))
    $filled = [int]($barWidth * $currentStep / $totalVersions)
    $bar = "[" + ("|" * $filled) + ("-" * ($barWidth - $filled)) + "]"
    Write-Host "Progress: $bar $currentStep/$totalVersions ($pct%)"
    Write-Progress -Activity "Downloading Windows 11 updates" -Status "Version $ver ($currentStep of $totalVersions)" -PercentComplete $pct -CurrentOperation ""

    $folderName = "Win11_$ver"
    $SavePath = Join-Path $BasePath $folderName

    if (!(Test-Path $SavePath)) {
        New-Item -ItemType Directory -Path $SavePath -Force | Out-Null
    }

    # Remove old MSU files (keep latest only)
    Get-ChildItem $SavePath -Filter "*.msu" -ErrorAction SilentlyContinue | Remove-Item -Force

    $searchQuery = "Cumulative Update for Windows 11 Version $ver for x64"
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] Searching: $searchQuery"

    try {
        Write-Progress -Activity "Downloading Windows 11 updates" -Status "Version $ver ($currentStep of $totalVersions)" -PercentComplete $pct -CurrentOperation "Searching catalog..."
        $updates = Get-MSCatalogUpdate -Search $searchQuery
        if ($updates -and $updates.Count -gt 0) {
            # Prefer x64 (exclude arm64)
            $latest = $updates | Where-Object { $_.Title -match "x64-based" -and $_.Title -notmatch "arm64" } | Select-Object -First 1
            if (-not $latest) {
                $latest = $updates | Select-Object -First 1
            }
            Write-Progress -Activity "Downloading Windows 11 updates" -Status "Version $ver ($currentStep of $totalVersions)" -PercentComplete $pct -CurrentOperation "Downloading $($latest.Title)..."
            $ts = Get-Date -Format "HH:mm:ss"
            Write-Host "[$ts] Downloading: $($latest.Title)"
            Save-MSCatalogUpdate -Update $latest -Destination $SavePath -DownloadAll
            $ts = Get-Date -Format "HH:mm:ss"
            Write-Host "[$ts] Saved to $SavePath"
        } else {
            $ts = Get-Date -Format "HH:mm:ss"
            Write-Host "[$ts] No updates found for $ver"
        }
    } catch {
        $ts = Get-Date -Format "HH:mm:ss"
        Write-Host "[$ts] Error for $ver : $_"
    }
}

Write-Progress -Activity "Downloading Windows 11 updates" -Completed
$bar = "[" + ("|" * $barWidth) + "]"
Write-Host "Progress: $bar $totalVersions/$totalVersions (100%) - Done."
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "[$ts] === Download Complete ==="
