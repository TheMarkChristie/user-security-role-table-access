@echo off
REM User Security Role Table Access - remove from XrmToolBox.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Uninstall.ps1"
echo.
pause
