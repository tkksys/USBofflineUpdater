@echo off
chcp 65001 >nul
cd /d %~dp0
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0download_updates.ps1"
pause
