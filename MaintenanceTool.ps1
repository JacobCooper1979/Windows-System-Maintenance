<#
Unified Tool
- Top menu:
  (1) Run FULL System Maintenance
  (2) Custom System Maintenance Scan
  (3) BSOD scan (create HTML report)  <-- always generates & auto-opens full HTML
- Live output for DISM/SFC/Defrag/CHKDSK/Cleanmgr
- Descriptive variable names
- Storage reliability fallback: Get-StorageReliabilityCounter -> Win32_DiskDrive (Model/Status)
- Author: Jacob Cooper
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

# ---------- Helpers ----------
function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Run PowerShell as Administrator for best results (DISM/SFC/CHKDSK)."
  }
}

function Pause-ForKey { $null = Read-Host "`nPress Enter to continue" }

# ---------- SMART ----------
function Show-DriveSMART {
  Write-Host "`n[SMART] Drive Health Summary"
  try {
    $smartOk = $false
    try {
      $pd = Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, Size
      if ($pd) {
        $smartOk = $true
        $pd | Sort-Object FriendlyName | ForEach-Object {
          $sizeGB = "{0:N1} GB" -f ($_.Size / 1GB)
          Write-Host ("  {0,-25} {1,-9} Health:{2,-12} Status:{3,-15} Size:{4}" -f $_.FriendlyName,$_.MediaType,$_.HealthStatus,$_.OperationalStatus,$sizeGB)
        }
      }
    } catch {}
    if (-not $smartOk) {
      $disks = Get-WmiObject Win32_DiskDrive
      $pred  = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue
      foreach ($d in $disks) {
        $p = $pred | Where-Object { $_.InstanceName -like "*$($d.PNPDeviceID.Replace('\','\\'))*" }
        if ($p) {
          $warn = if ($p.PredictFailure) { "WARNING (SMART predicts failure)" } else { "OK" }
          Write-Host ("  {0,-35}  Model:{1}  SMART:{2}" -f $d.DeviceID, $d.Model, $warn)
        } else {
          Write-Host ("  {0,-35}  Model:{1}  SMART: Unknown" -f $d.DeviceID, $d.Model)
        }
      }
    }
    Write-Host "[SMART] Done."
  } catch {
    Write-Warning "[SMART] Failed: $($_.Exception.Message)"
  }
}

# ---------- Maintenance Tasks ----------
function Run-DISM-HealthAndRepair {
  Write-Host "`n[DISM] Scanning image health..."
  try {
    & dism.exe /Online /Cleanup-Image /ScanHealth
    if ($LASTEXITCODE -ne 0) { Write-Warning "[DISM] /ScanHealth exit code $LASTEXITCODE" }

    Write-Host "[DISM] Restoring health..."
    & dism.exe /Online /Cleanup-Image /RestoreHealth
    if ($LASTEXITCODE -eq 0) { Write-Host "[DISM] Completed successfully." }
    else { Write-Warning "[DISM] /RestoreHealth exit code $LASTEXITCODE" }
  } catch { Write-Warning "[DISM] Failed: $($_.Exception.Message)" }
}

function Run-SFC-ScanNow {
  Write-Host "`n[SFC] /scannow..."
  try {
    & sfc.exe /scannow
    if ($LASTEXITCODE -eq 0) { Write-Host "[SFC] Completed successfully." }
    else { Write-Warning "[SFC] Exit code $LASTEXITCODE (repairs may have been made)" }
  } catch { Write-Warning "[SFC] Failed: $($_.Exception.Message)" }
}

function Run-CHKDSK-ScanThenOfferFix {
  Write-Host "`n[Disk Repair] CHKDSK online scan..."
  try {
    $volumes = Get-CimInstance Win32_LogicalDisk |
               Where-Object { $_.DriveType -eq 3 -and $_.FileSystem -eq 'NTFS' -and $_.DeviceID -match '^[A-Z]:' }
    if (-not $volumes) { Write-Host "No fixed NTFS volumes found."; return }

    foreach ($volume in $volumes) {
      $driveLetter = ($volume.DeviceID)[0]
      Write-Host "  chkdsk ${driveLetter}: /scan"
      $scanOutput = @()
      cmd /c "chkdsk ${driveLetter}: /scan" 2>&1 `
        | Tee-Object -Variable scanOutput `
        | ForEach-Object { Write-Host $_ }

      $scanText = ($scanOutput | Out-String)

      $repairNeeded = ($scanText -match "found problems") -or
                      ($scanText -match "Run CHKDSK with the /F") -or
                      ($scanText -match "errors were found")

      if ($repairNeeded) {
        Write-Host "  Issues detected on ${driveLetter}:. A reboot-time repair may be required."
        $resp = Read-Host "  Schedule CHKDSK /F for ${driveLetter}: at next boot? (y/n)"
        if ($resp -match '^(?i)y$') {
          cmd /c "echo Y|chkdsk ${driveLetter}: /F"
          Write-Host "  Repair scheduled for ${driveLetter}:. You'll be prompted on next reboot."
        } else {
          Write-Host "  Skipped scheduling repair for ${driveLetter}:."
        }
      } else {
        Write-Host "  No repair needed on ${driveLetter}:."
      }
    }
    Write-Host "[Disk Repair] Scan complete."
  } catch { Write-Warning "[Disk Repair] $($_.Exception.Message)" }
}

function Run-Defrag-All {
  Write-Host "`n[Defrag] Optimizing all drives..."
  try {
    & defrag.exe /C /O /U /V
    if ($LASTEXITCODE -eq 0) { Write-Host "[Defrag] Completed successfully." }
    else { Write-Warning "[Defrag] Exit code $LASTEXITCODE" }
  } catch { Write-Warning "[Defrag] Failed: $($_.Exception.Message)" }
}

function Run-DiskCleanup {
  Write-Host "`n[Disk Cleanup]"
  try {
    & cleanmgr.exe /sagerun:1
    if ($LASTEXITCODE -ne 0) {
      Write-Host "SAGERUN preset missing or exit $LASTEXITCODE; trying /VERYLOWDISK..."
      & cleanmgr.exe /VERYLOWDISK
    }
    Write-Host "[Disk Cleanup] Done."
  } catch { Write-Warning "[Disk Cleanup] Failed: $($_.Exception.Message)" }
}

# ---------- Option 1: Full Maintenance ----------
function Run-FullSystemMaintenance {
  Write-Host "`n========== RUNNING FULL SYSTEM MAINTENANCE =========="
  Run-CHKDSK-ScanThenOfferFix
  Run-DISM-HealthAndRepair
  Run-SFC-ScanNow
  Show-DriveSMART
  Write-Host "============ FULL SYSTEM MAINTENANCE DONE ============"
}

# ---------- Option 2: Custom Maintenance ----------
function Show-CustomMenu {
  do {
    Write-Host ""
    Write-Host "----- Custom System Maintenance -----"
    Write-Host "1) Disk Cleanup"
    Write-Host "2) CHKDSK (scan then offer repair)"
    Write-Host "3) DISM (ScanHealth + RestoreHealth)"
    Write-Host "4) SFC /scannow"
    Write-Host "5) Defrag/Optimize"
    Write-Host "6) Show SMART health"
    Write-Host "B) Back to main menu"
    $c = Read-Host "Select an option"
    switch ($c) {
      '1' { Run-DiskCleanup; Pause-ForKey }
      '2' { Run-CHKDSK-ScanThenOfferFix; Pause-ForKey }
      '3' { Run-DISM-HealthAndRepair; Pause-ForKey }
      '4' { Run-SFC-ScanNow; Pause-ForKey }
      '5' { Run-Defrag-All; Pause-ForKey }
      '6' { Show-DriveSMART; Pause-ForKey }
      'b' { break }
      'B' { break }
      default { Write-Host "Invalid selection."; Pause-ForKey }
    }
  } while ($true)
}

# =========================
# BSOD Diagnostics (FULL) — always builds & opens HTML
# =========================
try { wevtutil sl "Microsoft-Windows-PowerShell/Operational" /e:true | Out-Null } catch {}

function Get-SafeWinEvent {
  param(
    [Parameter(Mandatory)] [string]  $LogName,
    [int[]]                          $Id,
    [string]                         $ProviderName,
    [datetime]                       $StartTime
  )
  try {
    if ($ProviderName) {
      return Get-WinEvent -FilterHashtable @{ LogName=$LogName; Id=$Id; StartTime=$StartTime; ProviderName=$ProviderName } -ErrorAction Stop
    } else {
      return Get-WinEvent -FilterHashtable @{ LogName=$LogName; Id=$Id; StartTime=$StartTime } -ErrorAction Stop
    }
  } catch {
    try {
      $events = Get-WinEvent -FilterHashtable @{ LogName=$LogName; Id=$Id; StartTime=$StartTime } -ErrorAction Stop
      if ($ProviderName) { return $events | Where-Object { $_.ProviderName -eq $ProviderName } }
      return $events
    } catch { return $null }
  }
}

function Run-BSODDiagnostics {
  param([int]$Days = 14)

  $startTime = (Get-Date).AddDays(-[math]::Abs($Days))
  Write-Host "`n[BSOD Diagnostics] Last $Days day(s) since $startTime"

  # Signals
  $bugCheck     = Get-SafeWinEvent -LogName 'System' -Id 1001 -ProviderName 'BugCheck' -StartTime $startTime
  $werSystemErr = Get-SafeWinEvent -LogName 'System' -Id 1001 -ProviderName 'Microsoft-Windows-WER-SystemErrorReporting' -StartTime $startTime
  $kernPower41  = Get-SafeWinEvent -LogName 'System' -Id 41   -ProviderName 'Microsoft-Windows-Kernel-Power' -StartTime $startTime
  $unexpected   = Get-SafeWinEvent -LogName 'System' -Id 6008 -ProviderName 'EventLog' -StartTime $startTime

  $appErr   = Get-SafeWinEvent -LogName 'Application' -Id @() -ProviderName 'Application Error' -StartTime $startTime |
              Where-Object Message -match 'LiveKernelEvent|BlueScreen|BugCheck|0x'
  $dotnetRt = Get-SafeWinEvent -LogName 'Application' -Id @() -ProviderName '.NET Runtime' -StartTime $startTime |
              Where-Object Message -match 'BlueScreen|BugCheck'

  $miniDumpPath = Join-Path $env:SystemRoot 'Minidump'
  $miniDumps    = if (Test-Path $miniDumpPath) {
    Get-ChildItem $miniDumpPath -Filter *.dmp -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  }

  $crashCtrl = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -ErrorAction SilentlyContinue |
    Select-Object CrashDumpEnabled, DumpFile, MinidumpDir, LogEvent, AutoReboot, Overwrite, FilterPages

  $recentDrivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
    Where-Object { $_.DriverDate -and ([datetime]$_.DriverDate) -ge $startTime } |
    Sort-Object DriverDate -Descending |
    Select-Object DeviceName, DriverVersion, DriverDate, Manufacturer, DriverProviderName, InfName

  # Storage reliability (with fallback)
  try {
    $reliability = Get-StorageReliabilityCounter -ErrorAction Stop |
      Select-Object FriendlyName, Temperature, ReadErrorsTotal, WriteErrorsTotal, Wear, PowerOnHours
  } catch { $reliability = $null }

  $diskHealth = $null
  if (-not $reliability) {
    $diskHealth = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue |
                  Select-Object Model, Status
  }

  $thermalWarn = Get-SafeWinEvent -LogName 'System' -Id @() -ProviderName 'ACPI' -StartTime $startTime |
                 Where-Object Message -match 'Thermal'
  $volMgrErr   = Get-SafeWinEvent -LogName 'System' -Id @() -ProviderName 'volmgr' -StartTime $startTime |
                 Where-Object Id -in 161,46

  # Console summary (kept)
  Write-Host "== Crash Dump Configuration (CrashControl) ==" -ForegroundColor Cyan
  $crashCtrl | Format-List | Out-String | Write-Host

  Write-Host "`n== BugCheck 1001 (System) ==" -ForegroundColor Cyan
  $bugCheck | Sort-Object TimeCreated -Descending | Select-Object -First 10 TimeCreated, Id, Message | Format-Table -AutoSize

  Write-Host "`n== WER System Error 1001 (System) ==" -ForegroundColor Cyan
  $werSystemErr | Sort-Object TimeCreated -Descending | Select-Object -First 10 TimeCreated, Id, Message | Format-Table -AutoSize

  Write-Host "`n== Kernel-Power 41 (System) ==" -ForegroundColor Cyan
  $kernPower41 | Sort-Object TimeCreated -Descending | Select-Object -First 10 TimeCreated, Id, Message | Format-Table -AutoSize

  Write-Host "`n== Unexpected Shutdown 6008 (System) ==" -ForegroundColor Cyan
  $unexpected | Sort-Object TimeCreated -Descending | Select-Object -First 10 TimeCreated, Id, Message | Format-Table -AutoSize

  Write-Host "`n== Application Error / .NET Runtime (Application) ==" -ForegroundColor Cyan
  ($appErr + $dotnetRt) | Sort-Object TimeCreated -Descending |
    Select-Object -First 10 TimeCreated, Id, ProviderName, Message | Format-List

  Write-Host "`n== Recent Minidumps ==" -ForegroundColor Cyan
  if ($miniDumps) { $miniDumps | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize; Write-Host "Path: $miniDumpPath" }
  else { Write-Host "No minidumps found at $miniDumpPath" }

  Write-Host "`n== Recent Driver Changes (last $Days days) ==" -ForegroundColor Cyan
  if ($recentDrivers) { $recentDrivers | Select-Object DriverDate, DeviceName, Manufacturer, DriverVersion, InfName | Format-Table -AutoSize }
  else { Write-Host "No driver updates detected in the last $Days days." }

  Write-Host "`n== Storage Health ==" -ForegroundColor Cyan
  if ($reliability) {
    $reliability | Format-Table -AutoSize
  } elseif ($diskHealth) {
    $diskHealth | Format-Table -AutoSize
  } else {
    Write-Host "No storage health data available."
  }

  Write-Host "`n== Volume Manager Warnings/Errors ==" -ForegroundColor Cyan
  $volMgrErr | Sort-Object TimeCreated -Descending | Select-Object -First 10 TimeCreated, Id, Message | Format-Table -AutoSize

  Write-Host "`n== Thermal/ACPI Warnings (last $Days days) ==" -ForegroundColor Cyan
  $thermalWarn | Sort-Object TimeCreated -Descending | Select-Object -First 10 TimeCreated, Id, Message | Format-Table -AutoSize

  # --------- Build & auto-open HTML (always) ---------
  $htmlPath = "$env:PUBLIC\BSOD_Report_$(Get-Date -Format yyyyMMdd_HHmmss).html"

  $bugCheckFrag   = ($bugCheck     | Select TimeCreated,Id,Message | ConvertTo-Html -Fragment)
  $werSystemFrag  = ($werSystemErr | Select TimeCreated,Id,Message | ConvertTo-Html -Fragment)
  $kernPowerFrag  = ($kernPower41  | Select TimeCreated,Id,Message | ConvertTo-Html -Fragment)
  $unexpectedFrag = ($unexpected   | Select TimeCreated,Id,Message | ConvertTo-Html -Fragment)
  $appNetFrag     = (($appErr+$dotnetRt) | Select TimeCreated,Id,ProviderName,Message | ConvertTo-Html -Fragment)

  $minidumpFrag = if ($miniDumps)     { $miniDumps     | Select Name,Length,LastWriteTime | ConvertTo-Html -Fragment } else { '<p>No minidumps</p>' }
  $driversFrag  = if ($recentDrivers) { $recentDrivers | ConvertTo-Html -Fragment }                                      else { '<p>No driver changes</p>' }

  $storageFrag = if ($reliability) {
    $reliability | ConvertTo-Html -Fragment
  } elseif ($diskHealth) {
    $diskHealth | ConvertTo-Html -Fragment
  } else {
    '<p>No storage health data available.</p>'
  }

  $volMgrFrag  = if ($volMgrErr)   { $volMgrErr | Select TimeCreated,Id,Message | ConvertTo-Html -Fragment } else { '<p>None</p>' }
  $thermalFrag = if ($thermalWarn) { $thermalWarn | Select TimeCreated,Id,Message | ConvertTo-Html -Fragment } else { '<p>None</p>' }

  $blocks = @(
    @{Title='CrashControl';         Data=($crashCtrl | ConvertTo-Html -Fragment)}
    @{Title='BugCheck 1001';        Data=$bugCheckFrag}
    @{Title='WER System Error 1001';Data=$werSystemFrag}
    @{Title='Kernel-Power 41';      Data=$kernPowerFrag}
    @{Title='Unexpected 6008';      Data=$unexpectedFrag}
    @{Title='App/.NET Errors';      Data=$appNetFrag}
    @{Title='Minidumps';            Data=$minidumpFrag}
    @{Title='Recent Drivers';       Data=$driversFrag}
    @{Title='Storage Health';       Data=$storageFrag}
    @{Title='volmgr';               Data=$volMgrFrag}
    @{Title='Thermal/ACPI';         Data=$thermalFrag}
  )

  $html = @"
<html>
<head>
<meta charset='utf-8' />
<title>BSOD Report</title>
<style>
body{font-family:Segoe UI,Arial; margin:24px;}
h1{margin-top:0}
h2{border-bottom:1px solid #ccc; padding-bottom:4px;}
table{border-collapse:collapse; width:100%; margin-bottom:16px;}
th,td{border:1px solid #ddd; padding:6px; text-align:left; font-size:13px;}
tr:nth-child(even){background:#f9f9f9;}
.meta{color:#555; margin-bottom:12px;}
</style>
</head>
<body>
<h1>BSOD Report (last $Days day(s))</h1>
<p class="meta">Generated: $(Get-Date)</p>
$(
  ($blocks | ForEach-Object { "<h2>$($_.Title)</h2>`n$($_.Data)" }) -join "`n"
)
</body>
</html>
"@
  $html | Out-File -FilePath $htmlPath -Encoding UTF8
  Write-Host "`nHTML report saved to: $htmlPath"

  # Always try to open it (Start-Process first, then Invoke-Item fallback)
  try { Start-Process $htmlPath -ErrorAction Stop }
  catch {
    try { Invoke-Item $htmlPath } catch {}
  }
}

# ---------- Option 3 wrapper (prompt days, always HTML) ----------
function Run-BSOD-Report {
  Write-Host "`n[BSOD] Generate FULL report (HTML)"
  $daysBackInput = Read-Host "How many days back would you like to scan for BSOD events?"
  if (-not [int]::TryParse($daysBackInput, [ref]([int]$null))) {
    Write-Warning "Invalid number entered. Defaulting to 14 days."
    $daysBack = 14
  } else {
    $daysBack = [int]$daysBackInput
    if ($daysBack -lt 1) { $daysBack = 14 }
  }
  Run-BSODDiagnostics -Days $daysBack
}

# ---------- Main Menu ----------
Assert-Admin

do {
  Write-Host ""
  Write-Host "========================"
  Write-Host "         MENU"
  Write-Host "========================"
  Write-Host "(1) Run FULL System Maintenance"
  Write-Host "(2) Custom System Maintenance Scan"
  Write-Host "(3) BSOD scan (create HTML report)"
  Write-Host "(Q) Quit"
  $choice = Read-Host "Select an option"

  switch ($choice.ToUpper()) {
    '1' { Run-FullSystemMaintenance; Pause-ForKey }
    '2' { Show-CustomMenu }
    '3' { Run-BSOD-Report; Pause-ForKey }
    'Q' { break }
    default { Write-Host "Invalid selection." }
  }
} while ($true)
