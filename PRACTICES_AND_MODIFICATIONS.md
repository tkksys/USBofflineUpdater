# Modifications vs. Best Practices (Cross-Check)

## 1. Current Modifications Summary

### install_updates.ps1
| Area | Implementation |
|------|----------------|
| **param** | First statement; optional params with defaults |
| **Encoding** | UTF-8 output; no `-Encoding` on Start-Transcript (WinPS 5.1) |
| **OS detection** | Registry `CurrentBuild`, `DisplayVersion`, `ProductName` (Get-ComputerInfo.WindowsBuildNumber does not exist) |
| **Windows 11 check** | Build >= 22000 OR ProductName like "*Windows 11*" (ProductName often wrong on Win11) |
| **Display** | Normalize "Windows 10 Pro" → "Windows 11 Pro" when build >= 22000 |
| **Already installed** | (1) Get-HotFix -Id KB (2) DISM /online /get-packages once, match KB digits in output |
| **KB extraction** | Case-insensitive regex `(?i)kb\d{7}`, normalize to uppercase |
| **wusa** | Start-Process -PassThru, WaitForExit; child PID and timestamps for liveness |
| **Exit codes** | 0/3010 = Success; -2145124329 (WU_E_NOT_APPLICABLE) / 2359302 = Skipped (not applicable); else Failed |
| **Logging** | Transcript, CSV (PCName, OS, KB, Status, Date), Write-Progress |
| **Liveness** | PID, start time, script name, timestamps on key steps |

### download_updates.ps1
| Area | Implementation |
|------|----------------|
| **param** | First statement; DestinationPath default $PSScriptRoot; Versions array |
| **Path guard** | Ensure DestinationPath is single string; Versions default if null |
| **Catalog** | MSCatalogLTS; search "Cumulative Update for Windows 11 Version X for x64"; prefer x64, exclude arm64 |
| **Progress** | Write-Progress (version N of M, %); timestamps; PID and start time for liveness |

### Batch / Run
| Area | Implementation |
|------|----------------|
| **Admin** | run_install.bat / install_updates.bat: `net session` check, message "Administrator rights required..." |
| **Console** | chcp 65001 for UTF-8; -NoProfile for PowerShell |

---

## 2. Best Practices (from search)

### Installation and verification
- **Run as Administrator** – required for installing updates.  
  **Us:** Batch checks with `net session`; script does not re-check. **Match.**
- **Get-HotFix limitation** – Only reports CBS updates; many cumulative updates may be missing (Win32_QuickFixEngineering).  
  **Us:** We use Get-HotFix first, then DISM `/online /get-packages` as fallback. **Match (DISM broadens coverage).**
- **Most comprehensive “is installed” check** – Windows Update API: `Microsoft.Update.Session`, `CreateUpdateSearcher()`, `Search("IsInstalled=1")`.  
  **Us:** We do not use this. Search can be very slow (up to ~10 minutes). We rely on Get-HotFix + DISM for speed and avoid WU API. **Intentional trade-off.**
- **WUSA and DISM** – Standard tools for offline update installation.  
  **Us:** We use wusa.exe for MSU. **Match.** (DISM /add-package is an alternative for troubleshooting; not used by default.)

### Exit codes and handling
- **0x80240017 (-2145124329)** – WU_E_NOT_APPLICABLE (update not applicable to this computer; e.g. already installed, wrong build).  
  **Us:** Treated as "Skipped (not applicable)", not Failed. **Match.**
- **3010** – Success, reboot required.  
  **Us:** Treated as Success and RebootRequired. **Match.**

### Script and operations
- **Pre-deployment validation and audit** – Validate update list and keep audit trail.  
  **Us:** Transcript + CSV log with PCName, OS, KB, Status, Date. **Match.**
- **Allow time; no visual feedback** – Installation can take long with little output.  
  **Us:** Write-Progress, timestamps, PID/child PID for liveness. **Match.**
- **param() position** – Must be first executable statement in PowerShell script.  
  **Us:** param is first in download_updates.ps1; install_updates.ps1 has no param. **Match.**

---

## 3. Alignment Summary

| Best practice | Our implementation | Status |
|---------------|--------------------|--------|
| Run as Administrator | Batch checks `net session` | OK |
| Don’t rely only on Get-HotFix for “installed” | Get-HotFix + DISM | OK |
| Treat 0x80240017 as “not applicable” | Skipped (not applicable) | OK |
| Treat 3010 as success + reboot | Success + RebootRequired | OK |
| Audit trail | Transcript + CSV | OK |
| Progress / liveness | Write-Progress, PID, timestamps | OK |
| param first | Yes in download script | OK |
| WU API for “installed” | Not used (slow) | Trade-off |

---

## 4. Optional Improvements (not required)

1. **Windows Update API** – Add a third “already installed” check via `Search("IsInstalled=1")` only if DISM and Get-HotFix both say “not installed”. Not implemented because the first Search can take many minutes; Get-HotFix + DISM are a reasonable compromise.
2. **DISM as install fallback** – If wusa fails with certain errors, retry with `dism /online /add-package /packagepath:...` (e.g. after extracting .cab from MSU). Can be added later for specific failure cases.
3. **Admin check inside script** – In addition to batch, use e.g. `([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)` and exit with a clear message if not admin. Optional hardening.

---

## 5. References (summary)

- Get-HotFix / Win32_QuickFixEngineering: does not list all installed updates; DISM or WU API more complete.
- WU_E_NOT_APPLICABLE (0x80240017): update not applicable; treat as skip, not failure.
- Offline install: wusa and DISM are standard; admin required; transcript/logging and progress recommended.
