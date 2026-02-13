param(
    [string]$DestinationPath = $PSScriptRoot,
    [string[]]$Versions = @("21H2", "22H2", "23H2", "24H2", "25H2")
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
    $Versions = @("21H2", "22H2", "23H2", "24H2", "25H2")
}

Write-Host "=== Windows 11 Offline Update Downloader (MSCatalogLTS) ==="

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

foreach ($ver in $Versions) {
    $folderName = "Win11_$ver"
    $SavePath = Join-Path $BasePath $folderName

    if (!(Test-Path $SavePath)) {
        New-Item -ItemType Directory -Path $SavePath -Force | Out-Null
    }

    # Remove old MSU files (keep latest only)
    Get-ChildItem $SavePath -Filter "*.msu" -ErrorAction SilentlyContinue | Remove-Item -Force

    $searchQuery = "Cumulative Update for Windows 11 Version $ver for x64"
    Write-Host "Searching: $searchQuery"

    try {
        $updates = Get-MSCatalogUpdate -Search $searchQuery
        if ($updates -and $updates.Count -gt 0) {
            # Prefer x64 (exclude arm64)
            $latest = $updates | Where-Object { $_.Title -match "x64-based" -and $_.Title -notmatch "arm64" } | Select-Object -First 1
            if (-not $latest) {
                $latest = $updates | Select-Object -First 1
            }
            Write-Host "Downloading: $($latest.Title)"
            Save-MSCatalogUpdate -Update $latest -Destination $SavePath -DownloadAll
            Write-Host "Saved to $SavePath"
        } else {
            Write-Host "No updates found for $ver"
        }
    } catch {
        Write-Host "Error for $ver : $_"
    }
}

Write-Host "=== Download Complete ==="
