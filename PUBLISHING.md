# Publishing — User Access Explorer

Two tools to publish, both authored by **Mark Christie**. They share the one HTML UI but ship
through different channels:

- **XrmToolBox** → NuGet package → XrmToolBox **Tool Library**
- **Power Platform ToolBox (PPTB)** → npm → PPTB **Tool Registry**

> **Shared prerequisite — a public GitHub repo.** Both listings reference
> `https://github.com/TheMarkChristie/user-security-role-table-access` (project URL, README URL, and the
> XTB `iconUrl` → `…/main/icon.png`). Create that repo and push this project first, and make
> sure `icon.png` exists at the repo root. Without it the XTB tile icon and the PPTB readme
> link will 404.

---

## A. XrmToolBox → Tool Library

**Prerequisites:** a [nuget.org](https://www.nuget.org) account + API key; `nuget.exe` on PATH
(or NuGet Package Explorer); Node on PATH (the build copies the HTML into `app\index.html`);
the GitHub repo above.

**Rule:** the NuGet `version` must **exactly** match the assembly version. Here both are
`1.0.0` (assembly `1.0.0.0`). Bump them together for future releases (csproj `<Version>` +
`.nuspec` `<version>`).

1. **Build Release** (the `BuildApp` target runs `xrmtoolbox\build-app.js` first, which copies
   the canonical HTML into `app\index.html`):
   ```powershell
   cd V:\PCF\UserSecurityRoleTableAccess\xrmtoolbox\UserSecurityRoleTableAccess
   dotnet build -c Release
   ```
2. **Pack the NuGet** from the custom nuspec. `nuget.exe` is not required — the .NET SDK can do it:
   ```powershell
   dotnet pack UserSecurityRoleTableAccess.csproj -c Release --no-build `
     -p:NuspecFile=UserSecurityRoleTableAccess.nuspec -p:NuspecBasePath=. --output ..\..\_dist
   ```
   One warning is expected and correct: **NU5100** ("assembly is not inside the 'lib' folder") — an
   XrmToolBox plugin belongs in `Plugins\`, which is exactly what the nuspec does.

   Or with the classic tool, packing from the custom nuspec (ships only our DLL + `app\index.html` into a
   `Plugins` folder — XrmToolBox already provides WebView2 and the Dataverse SDK):
   ```powershell
   nuget pack UserSecurityRoleTableAccess.nuspec -OutputDirectory ..\..\_dist
   ```
   Produces `MarkChristie.UserSecurityRoleTableAccess.1.0.0.nupkg`.
   *(Sanity check in NuGet Package Explorer: it must contain `Plugins\UserSecurityRoleTableAccess.dll`
   + `Plugins\app\index.html`, the `XrmToolBox` dependency, the `XrmToolBox` tag, author/owner
   = Mark Christie, and a working `iconUrl`.)*
3. **Push to nuget.org** and wait for indexing (a few minutes):
   ```powershell
   nuget push ..\..\_dist\MarkChristie.UserSecurityRoleTableAccess.1.0.0.nupkg -ApiKey <YOUR_NUGET_KEY> -Source https://api.nuget.org/v3/index.json
   ```
4. **Register** the package id at **https://www.xrmtoolbox.com/plugins/new/** — paste
   `MarkChristie.UserSecurityRoleTableAccess`. The portal reads the metadata; an XrmToolBox admin
   validates it (can take a few days). Only validated tools appear in the Tool Library.

**Local install without publishing** (for testing):
```powershell
cd V:\PCF\UserSecurityRoleTableAccess\xrmtoolbox\UserSecurityRoleTableAccess
dotnet build -c Release
..\install.cmd
```
Then restart XrmToolBox → the tool appears as **User Access Explorer**.

**Updating later:** bump csproj `<Version>` + nuspec `<version>` together → `dotnet build -c
Release` → `nuget pack` → `nuget push`. The Tool Library picks up the new version automatically.

---

## B. Power Platform ToolBox → Tool Registry

**Prerequisites:** an [npmjs.com](https://www.npmjs.com) account; Node 18+; the GitHub repo
above; a PPTB account for the submission form.

1. **Confirm the npm name is free** (manifest uses `user-security-role-table-access`):
   ```powershell
   npm view user-security-role-table-access
   ```
   A 404 means it is available.
2. **Build** `dist/` from the canonical HTML:
   ```powershell
   cd V:\PCF\UserSecurityRoleTableAccess\pptb
   npm run build
   ```
3. **Validate** — fix every error before going further:
   ```powershell
   npx @pptb/validate
   ```
   (The package is scoped: a bare `npx pptb-validate` 404s.) It checks the manifest and, crucially,
   that `configurations.repository`, `readmeUrl` and `website` are **reachable** — so it cannot pass
   until the GitHub repo above exists and is public. Everything else already validates.
4. **Publish to npm:**
   ```powershell
   npm publish --access public
   ```
5. **Submit** at **https://powerplatformtoolbox.com/submit-tool** with the package name
   `user-security-role-table-access`. Pick at most three categories — *Administration*, *Security*,
   *Data* are the right ones here.

**Updating later:** bump `version` in `pptb/package.json` → `npm run build` → `npx
@pptb/validate` → `npm publish`. The registry tracks the npm version.

---

## C. Dataverse web resource (optional third host)

The same file also runs inside a model-driven app. Deploy
`webresource\prx3_UserSecurityRoleTableAccess.html` as an HTML web resource named
`prx3_UserSecurityRoleTableAccess.html` and surface it from a dashboard or the sitemap. It picks up
the logged-in user's session (same-origin `fetch`) — so it is security-trimmed by whoever opens
it, and a non-admin will simply see fewer users and get a clear error if they try to write.

---

## Version checklist (keep these four in step)

| File | Field |
| --- | --- |
| `xrmtoolbox\UserSecurityRoleTableAccess\UserSecurityRoleTableAccess.csproj` | `<Version>` |
| `xrmtoolbox\UserSecurityRoleTableAccess\UserSecurityRoleTableAccess.nuspec` | `<version>` |
| `pptb\package.json` | `version` |
| `xrmtoolbox\package\README.txt` | the version in the banner |
| `webresource\prx3_UserSecurityRoleTableAccess.html` | the `APP_VERSION` constant in the header |
