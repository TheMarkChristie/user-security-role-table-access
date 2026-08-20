@echo off
REM User Access Explorer - remove from XrmToolBox.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Uninstall.ps1"
echo.
pause
