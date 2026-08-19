@echo off
REM User Security Role Table Access - XrmToolBox installer.
REM Wrapper so this works by double-clicking, whatever the machine's PowerShell execution policy is.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Install.ps1"
echo.
pause
