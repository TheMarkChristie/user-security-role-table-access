# Regenerates UserSecurityRoleTableAccess\IconData.cs from ..\icon.svg.
# Requires resvg.exe (bundled with Amiga A19883). No Python needed - the base64 is done in PowerShell.
$ErrorActionPreference = 'Stop'
$root  = Split-Path $PSScriptRoot -Parent
$resvg = 'V:\PCF\AmigaA19883\server\bin\resvg.exe'
if (-not (Test-Path $resvg)) { throw "resvg.exe not found at $resvg" }

& $resvg (Join-Path $root 'icon.svg') (Join-Path $root 'icon32.png') --width 32  --height 32
& $resvg (Join-Path $root 'icon.svg') (Join-Path $root 'icon80.png') --width 80  --height 80
& $resvg (Join-Path $root 'icon.svg') (Join-Path $root 'icon.png')   --width 256 --height 256
Copy-Item (Join-Path $root 'icon.png') (Join-Path $root 'logo.png') -Force

$small = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root 'icon32.png')))
$big   = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root 'icon80.png')))
$out   = Join-Path $PSScriptRoot 'UserSecurityRoleTableAccess\IconData.cs'

$cs = @"
// Auto-generated from icon.svg (32px + 80px) for the XrmToolBox tool tile.
// Regenerate: xrmtoolbox\gen-icondata.ps1
namespace UserSecurityRoleTableAccess
{
    internal static class IconData
    {
        public const string Small = "$small";

        public const string Big = "$big";
    }
}
"@
[IO.File]::WriteAllText($out, $cs, (New-Object Text.UTF8Encoding $false))
Write-Host "IconData.cs regenerated -> $out" -ForegroundColor Green
