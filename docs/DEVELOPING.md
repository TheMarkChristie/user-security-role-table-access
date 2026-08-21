# Developing

Everything about building, installing locally and releasing. None of this belongs in `README.md` — that
file is rendered on the public tool listings, so it stays about *using* the tool.

## Shape of the repo

One HTML file is the whole application. It detects its host at runtime, sets `body[data-host]`, and the
stylesheet carries all three palettes as design tokens — so there is no separately skinned build to drift
out of sync.

| Host | Detected by | Theme |
| --- | --- | --- |
| Power Platform ToolBox | `window.dataverseAPI` | Dark |
| XrmToolBox | `window.XTB_CONFIG` | Windows 95 |
| Dynamics 365 web resource | `Xrm` / same origin | Light |

| Path | What it is |
| --- | --- |
| `webresource/prx3_UserSecurityRoleTableAccess.html` | The whole application — single source of truth |
| `xrmtoolbox/UserSecurityRoleTableAccess/` | WebView2 plugin host (.NET 4.8), nuspec, icons |
| `xrmtoolbox/build-app.js` | Copies the app into the plugin output |
| `xrmtoolbox/build-zip.js` | Builds the redistributable ZIP into `_dist/` |
| `xrmtoolbox/package/` | Installer, uninstaller and README that go inside that ZIP |
| `xrmtoolbox/install.cmd` / `install.ps1` | Local install into the XrmToolBox Plugins folder |
| `xrmtoolbox/gen-icondata.ps1` | Regenerates the icon PNGs and `IconData.cs` from `icon.svg` |
| `pptb/` | Power Platform ToolBox manifest and build |
| `icon.svg` | The one source icon — `icon.png`, `icon32/80.png`, the ToolBox SVG and the inline header mark all derive from it |
| `release.ps1` / `release.cmd` | Rebuilds and verifies every artefact; run before publishing |
| `docs/ARCHITECTURE.md` | How the permission computation and the copy/assign path work |
| `DEPLOY.md` | The deploy runbook — what to run, in what order, and what blocks what |
| `PUBLISHING.md` | Reference detail behind those steps |
| `_dist/` | Built release artefacts: the hand-install ZIP and the NuGet package |

## Build

```powershell
.\release.cmd
```

Use the `.cmd`: a default Windows execution policy is Restricted and blocks `.ps1` outright.

It rebuilds every artefact from the one source file and fails loudly on the things that are easy to get
wrong at release time — the five version numbers disagreeing, a host payload going stale, the JavaScript
not parsing, the ToolBox package missing `npm-shrinkwrap.json` (the Tool Registry rejects it without one),
or the NuGet package missing something the Tool Library needs.

## Run it locally

```powershell
.\release.cmd -Install
```

Refreshes both hosts. Close them first — XrmToolBox holds its DLL open, and ToolBox reads its manifest at
startup. One host being open no longer stops the other being refreshed.

For Power Platform ToolBox there is also the **Debug Menu**, which loads a tool straight from the `pptb`
folder. That is the better loop while actively changing things: rebuild, reload, no copying and no
manifest editing.

## Hand out a copy without either library

`node xrmtoolbox\build-zip.js` (after a Release build) produces
`_dist\UserSecurityRoleTableAccess-<version>.zip` — self-contained, with `Install.cmd` / `Uninstall.cmd`, a
plain-English `README.txt`, and a `Plugins\` folder that mirrors the destination so a manual drag-and-drop
install is obvious.

The installer finds the Plugins folder itself, refuses politely if XrmToolBox is running, skips files that
are already identical, and clears the mark-of-the-web that Windows puts on anything downloaded — without
which .NET can refuse to load the assembly.

## Deploy as a Dynamics 365 web resource

Deploy `webresource/prx3_UserSecurityRoleTableAccess.html` as an HTML web resource named
`prx3_UserSecurityRoleTableAccess.html`, and surface it from a dashboard or the sitemap.

## Release

See [DEPLOY.md](../DEPLOY.md) for the runbook and [PUBLISHING.md](../PUBLISHING.md) for the detail behind
it. Version numbers move in lockstep across five files; `release.cmd` verifies they match.

Note that the display name and the package identifiers deliberately differ. The tool was renamed to
**User Access Explorer** after it had been published, and a nuget.org package id cannot be deleted — only
unlisted — so the ids keep the original name rather than stranding anyone who had already installed it:

| | |
| --- | --- |
| NuGet id | `MarkChristie.UserSecurityRoleTableAccess` |
| npm name | `user-security-role-table-access` |
| Assembly, namespace, folder, repo | `UserSecurityRoleTableAccess` |
| Display name everywhere a person sees it | **User Access Explorer** |
