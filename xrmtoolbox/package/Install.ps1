<#
    User Access Explorer - installer for XrmToolBox
    by Mark Christie  (https://github.com/TheMarkChristie)

    Copies the plugin into your XrmToolBox Plugins folder. Nothing else on the machine is touched,
    nothing is written to the registry, and no admin rights are needed.

    Run Install.cmd, or from PowerShell:
        powershell -ExecutionPolicy Bypass -File .\Install.ps1
#>
[CmdletBinding()]
param(
    # Install somewhere other than the default XrmToolBox Plugins folder (portable installs).
    [string] $PluginsPath,
    # Copy even if XrmToolBox is running (it will not see the tool until you restart it anyway).
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $here 'Plugins'

Write-Host ''
Write-Host '  User Access Explorer - XrmToolBox installer' -ForegroundColor Cyan
Write-Host '  by Mark Christie' -ForegroundColor DarkGray
Write-Host ''

if (-not (Test-Path (Join-Path $src 'UserSecurityRoleTableAccess.dll'))) {
    throw "This script must sit next to the Plugins folder from the zip. Not found: $src\UserSecurityRoleTableAccess.dll"
}

# --- work out where XrmToolBox keeps its plugins -------------------------------------------------
if ($PluginsPath) {
    $dst = $PluginsPath
} else {
    $dst = Join-Path $env:APPDATA 'MscrmTools\XrmToolBox\Plugins'
}

if (-not (Test-Path $dst)) {
    Write-Host "  XrmToolBox Plugins folder not found at:" -ForegroundColor Yellow
    Write-Host "    $dst"
    Write-Host ''
    $answer = Read-Host '  Create it and install anyway? (y/N)'
    if ($answer -notmatch '^[Yy]') { Write-Host '  Cancelled.' -ForegroundColor Yellow; return }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
}

# --- XrmToolBox locks plugin assemblies while it runs --------------------------------------------
$running = Get-Process XrmToolBox -ErrorAction SilentlyContinue
if ($running -and -not $Force) {
    Write-Host '  XrmToolBox is currently running.' -ForegroundColor Yellow
    Write-Host '  Close it first: it loads plugins at startup and locks their files.'
    Write-Host ''
    $answer = Read-Host '  Try to copy anyway? (y/N)'
    if ($answer -notmatch '^[Yy]') { Write-Host '  Cancelled - close XrmToolBox and run this again.' -ForegroundColor Yellow; return }
}

# --- copy ----------------------------------------------------------------------------------------
# Skip any file that is already byte-identical: XrmToolBox holds loaded assemblies open, and on a
# re-install only the HTML has usually changed.
function Copy-IfChanged([string] $from, [string] $to) {
    if ((Test-Path $to) -and (Get-FileHash $from).Hash -eq (Get-FileHash $to).Hash) { return }
    Copy-Item $from $to -Force
}

try {
    Copy-IfChanged (Join-Path $src 'UserSecurityRoleTableAccess.dll') (Join-Path $dst 'UserSecurityRoleTableAccess.dll')
    New-Item -ItemType Directory -Force -Path (Join-Path $dst 'app') | Out-Null
    Copy-IfChanged (Join-Path $src 'app\index.html') (Join-Path $dst 'app\index.html')
}
catch {
    Write-Host ''
    Write-Host '  COPY FAILED.' -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)"
    Write-Host '  If XrmToolBox is open, close it completely and run this again.' -ForegroundColor Yellow
    throw
}

# --- clear the "downloaded from the internet" mark, or .NET may refuse to load the assembly -------
try {
    Get-ChildItem -Path $dst -Recurse -Include 'UserSecurityRoleTableAccess.dll','index.html' -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
} catch { }

Write-Host ''
Write-Host '  Installed:' -ForegroundColor Green
Write-Host "    $dst\UserSecurityRoleTableAccess.dll"
Write-Host "    $dst\app\index.html"
Write-Host ''
Write-Host '  Next: start (or restart) XrmToolBox and open "User Access Explorer".' -ForegroundColor Cyan
Write-Host '  Connect with an OAuth / MFA connection - the tool needs an access token.' -ForegroundColor DarkGray
Write-Host ''
