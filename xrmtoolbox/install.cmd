@echo off
REM Installs User Security Role Table Access into XrmToolBox.
REM Wrapper so this works by double-clicking, regardless of the machine's PowerShell execution policy.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"
echo.
pause
