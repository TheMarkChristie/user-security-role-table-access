# Installs the compiled User Security Role Table Access plugin into XrmToolBox.
# XrmToolBox already ships WebView2 + the Dataverse SDK, so we copy ONLY our plugin dll
# and its bundled app/ (the shared HTML) to avoid assembly version conflicts.
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'UserSecurityRoleTableAccess\bin\Release\net48'
$dst = Join-Path $env:APPDATA 'MscrmTools\XrmToolBox\Plugins'
if (-not (Test-Path $src)) { throw "Build first: dotnet build -c Release  ($src not found)" }
if (-not (Test-Path $dst)) { throw "XrmToolBox Plugins folder not found: $dst" }

# XrmToolBox holds loaded plugin assemblies open, so skip any file that is already identical -
# during development only the HTML usually changes, and that alone does not need a restart.
function Copy-IfChanged([string] $from, [string] $to) {
    if ((Test-Path $to) -and
        (Get-FileHash $from).Hash -eq (Get-FileHash $to).Hash) {
        Write-Host "  unchanged  $(Split-Path $to -Leaf)" -ForegroundColor DarkGray
        return
    }
    Copy-Item $from $to -Force
    Write-Host "  updated    $(Split-Path $to -Leaf)" -ForegroundColor Green
}

Copy-IfChanged (Join-Path $src 'UserSecurityRoleTableAccess.dll') (Join-Path $dst 'UserSecurityRoleTableAccess.dll')
New-Item -ItemType Directory -Force (Join-Path $dst 'app') | Out-Null
Copy-IfChanged (Join-Path $src 'app\index.html') (Join-Path $dst 'app\index.html')

Write-Host "Installed UserSecurityRoleTableAccess.dll + app\index.html to:`n  $dst" -ForegroundColor Green
Write-Host "Restart XrmToolBox -> tool 'User Security Role Table Access'." -ForegroundColor Yellow
