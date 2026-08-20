@echo off
REM Release build for User Security Role Table Access.
REM Wrapper so this runs regardless of the machine's PowerShell execution policy, which on a default
REM Windows install is Restricted and blocks .ps1 files outright.
REM
REM   release.cmd             build and verify
REM   release.cmd -Install    also refresh the local XrmToolBox / ToolBox installs
REM
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0release.ps1" %*
echo.
pause
