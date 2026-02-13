@echo off
chcp 65001 >nul
cd /d %~dp0
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator rights required. Right-click and select "Run as administrator".
    pause
    exit /b 1
)
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install_updates.ps1"
pause
