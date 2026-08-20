<#
    User Security Role Table Access - release build.
    by Mark Christie  (https://github.com/TheMarkChristie)

    Rebuilds every artefact from the one source file and checks the things that are easy to get wrong
    at release time. It does NOT publish anything - see PUBLISHING.md for the two push commands, which
    need credentials this script deliberately does not touch.

        .\release.ps1              build and verify
        .\release.ps1 -Install     also refresh the local XrmToolBox / ToolBox installs
#>
[CmdletBinding()]
param([switch] $Install)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$proj = Join-Path $root 'xrmtoolbox\UserSecurityRoleTableAccess'
$fail = @()

function Step($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "   OK   $t" -ForegroundColor Green }
function Bad($t)  { Write-Host "   FAIL $t" -ForegroundColor Red; $script:fail += $t }

# ---------------------------------------------------------------- build ---------------------------
Step 'Build'
Push-Location $proj
dotnet build -c Release --nologo -v q | Out-Null
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'dotnet build failed' }
Pop-Location
node (Join-Path $root 'pptb\build.js') | Out-Null
Ok 'plugin + both host payloads'

# ---------------------------------------------------------------- checks --------------------------
Step 'Version consistency'
$v = @{
  csproj = ([xml](Get-Content "$proj\UserSecurityRoleTableAccess.csproj")).Project.PropertyGroup.Version
  nuspec = ([xml](Get-Content "$proj\UserSecurityRoleTableAccess.nuspec")).package.metadata.version
  pptb   = (Get-Content "$root\pptb\package.json" -Raw | ConvertFrom-Json).version
  html   = (Select-String "$root\webresource\prx3_UserSecurityRoleTableAccess.html" -Pattern 'APP_VERSION = "(.*?)"').Matches[0].Groups[1].Value
  readme = (Select-String "$root\xrmtoolbox\package\README.txt" -Pattern 'v(\d+\.\d+\.\d+)').Matches[0].Groups[1].Value
}
$dll = [Reflection.AssemblyName]::GetAssemblyName("$proj\bin\Release\net48\UserSecurityRoleTableAccess.dll").Version.ToString(3)
$all = @($v.Values) + $dll | Select-Object -Unique
if (@($all).Count -eq 1) { Ok "all five files and the assembly agree at $(@($all)[0])" }
else { Bad "versions disagree: $($v | ConvertTo-Json -Compress); assembly $dll" }

Step 'The one source file reached both hosts'
$src = Get-FileHash "$root\webresource\prx3_UserSecurityRoleTableAccess.html"
foreach ($t in @("$proj\app\index.html", "$root\pptb\dist\index.html")) {
  # the copies gain a build banner, so compare length rather than hash
  $d = (Get-Item $t).Length - (Get-Item "$root\webresource\prx3_UserSecurityRoleTableAccess.html").Length
  $where = Split-Path (Split-Path $t -Parent) -Leaf
  if ($d -ge 0 -and $d -lt 400) { Ok "$(Split-Path $t -Leaf) in $where" }
  else { Bad "$t is not a copy of the current source (delta $d bytes)" }
}

Step 'JavaScript parses'
$js = [IO.File]::ReadAllText("$root\webresource\prx3_UserSecurityRoleTableAccess.html")
$m = [regex]::Match($js, '(?s)<script>(.*)</script>')
$tmp = Join-Path $env:TEMP 'usrta-check.js'
[IO.File]::WriteAllText($tmp, $m.Groups[1].Value)
node --check $tmp 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Ok 'node --check clean' } else { Bad 'JavaScript does not parse' }
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------- package -------------------------
Step 'Package'
Remove-Item "$root\_dist\*.nupkg" -Force -ErrorAction SilentlyContinue
node (Join-Path $root 'xrmtoolbox\build-zip.js') | Out-Null
Push-Location $proj
# NU5100 is expected: an XrmToolBox plugin dll belongs in Plugins\, not lib\
dotnet pack UserSecurityRoleTableAccess.csproj -c Release --no-build --nologo -v q `
  -p:NuspecFile=UserSecurityRoleTableAccess.nuspec -p:NuspecBasePath=. --output "$root\_dist" | Out-Null
Pop-Location
Get-ChildItem "$root\_dist" | ForEach-Object { Ok ("{0} ({1} KB)" -f $_.Name, [math]::Round($_.Length / 1KB)) }

Step 'The NuGet package contains what the Tool Library needs'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::OpenRead((Get-ChildItem "$root\_dist\*.nupkg").FullName)
$names = $z.Entries.FullName
$z.Dispose()
foreach ($need in @('Plugins/UserSecurityRoleTableAccess.dll','Plugins/app/index.html','icon.png','README.md')) {
  if ($names -contains $need) { Ok $need } else { Bad "missing from nupkg: $need" }
}

# ---------------------------------------------------------------- optional install ----------------
if ($Install) {
  Step 'Refresh the local installs'
  & (Join-Path $root 'xrmtoolbox\install.ps1')
  $pptbTool = Get-ChildItem (Join-Path $env:APPDATA 'powerplatform-toolbox\tools') -Directory -ErrorAction SilentlyContinue |
              Where-Object { Test-Path (Join-Path $_.FullName 'dist\index.html') } |
              Where-Object { (Get-Content (Join-Path $_.FullName 'package.json') -Raw) -match 'user-security-role-table-access' }
  if ($pptbTool) {
    Copy-Item "$root\pptb\dist\index.html" (Join-Path $pptbTool.FullName 'dist') -Force
    Copy-Item "$root\pptb\package.json"    $pptbTool.FullName -Force
    Ok "Power Platform ToolBox refreshed ($($pptbTool.Name))"
  } else { Write-Host '   --   not installed in Power Platform ToolBox; skipped' -ForegroundColor DarkGray }
}

# ---------------------------------------------------------------- result --------------------------
Write-Host ''
if ($fail.Count) {
  Write-Host "$($fail.Count) check(s) FAILED - do not publish." -ForegroundColor Red
  exit 1
}
Write-Host 'All checks passed. Artefacts are in _dist\.' -ForegroundColor Green
Write-Host 'Publishing needs credentials and is not done here - see PUBLISHING.md.' -ForegroundColor DarkGray
