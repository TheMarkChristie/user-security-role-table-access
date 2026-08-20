<#
    User Access Explorer - uninstaller for XrmToolBox
    by Mark Christie  (https://github.com/TheMarkChristie)

    Removes the two files the installer copied. Nothing else is touched.
#>
[CmdletBinding()]
param(
    # Remove from somewhere other than the default XrmToolBox Plugins folder.
    [string] $PluginsPath,
    # Delete even if XrmToolBox is running (only sensible when removing from a folder it is not using).
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$dst = if ($PluginsPath) { $PluginsPath } else { Join-Path $env:APPDATA 'MscrmTools\XrmToolBox\Plugins' }

Write-Host ''
Write-Host '  User Access Explorer - uninstaller' -ForegroundColor Cyan
Write-Host ''

$running = Get-Process XrmToolBox -ErrorAction SilentlyContinue
if ($running -and -not $Force) {
    Write-Host '  Close XrmToolBox first - it holds the plugin file open while it runs.' -ForegroundColor Yellow
    Write-Host '  (Re-run with -Force if you are removing it from a folder XrmToolBox is not using.)' -ForegroundColor DarkGray
    Write-Host ''
    return
}

$targets = @(
    (Join-Path $dst 'UserSecurityRoleTableAccess.dll'),
    (Join-Path $dst 'app\index.html')
)

$removed = 0
foreach ($t in $targets) {
    if (Test-Path $t) { Remove-Item $t -Force; Write-Host "  Removed $t"; $removed++ }
}

# only remove the app folder if it is now empty - other tools may share it
$appDir = Join-Path $dst 'app'
if ((Test-Path $appDir) -and -not (Get-ChildItem $appDir -Force)) { Remove-Item $appDir -Force }

Write-Host ''
if ($removed) { Write-Host "  Done - $removed file(s) removed." -ForegroundColor Green }
else          { Write-Host '  Nothing to remove; it was not installed here.' -ForegroundColor Yellow }
Write-Host ''
