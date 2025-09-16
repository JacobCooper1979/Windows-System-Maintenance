@echo off
:: Launcher for MaintenanceTool.ps1 (Windows PowerShell 5.1, keeps window open)

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%MaintenanceTool.ps1"

if not exist "%SCRIPT_PATH%" (
    echo PowerShell script not found at "%SCRIPT_PATH%"
    pause
    exit /b 1
)

set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS51%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process '%PS51%' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','""%SCRIPT_PATH%""' -Verb RunAs"
