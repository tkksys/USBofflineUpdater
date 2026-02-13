# Pester tests for install_updates.ps1 logic (no admin, no real wusa/DISM)
# Run: Invoke-Pester -Path tests/  (Pester 3 or 5)

Describe "KB extraction from MSU filename" {
    It "extracts KB from lowercase kb in filename" {
        $msuName = "windows11.0-kb5043080-x64.msu"
        $kbMatch = [regex]::Match($msuName, '(?i)kb\d{7}')
        $kb = if ($kbMatch.Success) { $kbMatch.Value.ToUpperInvariant() } else { "Unknown" }
        $kb | Should Be "KB5043080"
    }
    It "extracts KB from uppercase KB in filename" {
        $msuName = "windows11.0-KB5077181-x64.msu"
        $kbMatch = [regex]::Match($msuName, '(?i)kb\d{7}')
        $kb = if ($kbMatch.Success) { $kbMatch.Value.ToUpperInvariant() } else { "Unknown" }
        $kb | Should Be "KB5077181"
    }
    It "returns Unknown when no KB pattern" {
        $msuName = "some-package-x64.msu"
        $kbMatch = [regex]::Match($msuName, '(?i)kb\d{7}')
        $kb = if ($kbMatch.Success) { $kbMatch.Value.ToUpperInvariant() } else { "Unknown" }
        $kb | Should Be "Unknown"
    }
}

Describe "WUSA exit code to status mapping" {
    It "maps 0 to Success" {
        $exitCode = 0
        $status = if ($exitCode -eq 0 -or $exitCode -eq 3010) { "Success" }
            elseif ($exitCode -eq -2145124329 -or $exitCode -eq 2359302) { "Skipped (not applicable)" }
            else { "Failed" }
        $status | Should Be "Success"
    }
    It "maps 3010 to Success" {
        $exitCode = 3010
        $status = if ($exitCode -eq 0 -or $exitCode -eq 3010) { "Success" }
            elseif ($exitCode -eq -2145124329 -or $exitCode -eq 2359302) { "Skipped (not applicable)" }
            else { "Failed" }
        $status | Should Be "Success"
    }
    It "maps -2145124329 to Skipped (not applicable)" {
        $exitCode = -2145124329
        $status = if ($exitCode -eq 0 -or $exitCode -eq 3010) { "Success" }
            elseif ($exitCode -eq -2145124329 -or $exitCode -eq 2359302) { "Skipped (not applicable)" }
            else { "Failed" }
        $status | Should Be "Skipped (not applicable)"
    }
    It "maps 2359302 to Skipped (not applicable)" {
        $exitCode = 2359302
        $status = if ($exitCode -eq 0 -or $exitCode -eq 3010) { "Success" }
            elseif ($exitCode -eq -2145124329 -or $exitCode -eq 2359302) { "Skipped (not applicable)" }
            else { "Failed" }
        $status | Should Be "Skipped (not applicable)"
    }
    It "maps other codes to Failed" {
        $exitCode = 1
        $status = if ($exitCode -eq 0 -or $exitCode -eq 3010) { "Success" }
            elseif ($exitCode -eq -2145124329 -or $exitCode -eq 2359302) { "Skipped (not applicable)" }
            else { "Failed" }
        $status | Should Be "Failed"
    }
}

Describe "Success determination from LogEntries" {
    It "Overall Success when no Failed" {
        $LogEntries = @(
            [PSCustomObject]@{ Status = "Success" }
            [PSCustomObject]@{ Status = "Already installed" }
        )
        $failedCount = ($LogEntries | Where-Object { $_.Status -eq "Failed" }).Count
        $failedCount | Should Be 0
        $failedCount -gt 0 | Should Be $false
    }
    It "Overall Failed when any Failed" {
        $LogEntries = @(
            [PSCustomObject]@{ Status = "Success" }
            [PSCustomObject]@{ Status = "Failed" }
        )
        $failedCount = ($LogEntries | Where-Object { $_.Status -eq "Failed" }).Count
        $failedCount | Should Be 1
        $failedCount -gt 0 | Should Be $true
    }
}

Describe "Build number to DisplayVersion map" {
    It "maps 26200 to 25H2" {
        $buildMap = @{ 22000 = "21H2"; 22621 = "22H2"; 22631 = "23H2"; 26100 = "24H2"; 26200 = "25H2" }
        $buildMap[26200] | Should Be "25H2"
    }
    It "maps 26100 to 24H2" {
        $buildMap = @{ 22000 = "21H2"; 22621 = "22H2"; 22631 = "23H2"; 26100 = "24H2"; 26200 = "25H2" }
        $buildMap[26100] | Should Be "24H2"
    }
}

Describe "Script file exists and is valid PowerShell" {
    It "install_updates.ps1 exists" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot ".." "install_updates.ps1")).Path
        Test-Path $scriptPath | Should Be $true
    }
    It "download_updates.ps1 exists" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot ".." "download_updates.ps1")).Path
        Test-Path $scriptPath | Should Be $true
    }
    It "install_updates.ps1 parses without syntax errors" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot ".." "install_updates.ps1")).Path
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
        $errors.Count | Should Be 0
    }
}
