# Deploying v1.0.0

Everything is built and verified. What is left needs credentials, so it is yours to run.

Run `.\release.ps1` first — it rebuilds every artefact from the one source file and fails loudly if the
five version numbers disagree, the host payloads are stale, the JavaScript does not parse, or the NuGet
package is missing something the Tool Library needs. Do not publish if it reports a failure.

---

## 0. The GitHub repo — this blocks both channels

Neither library will accept the tool until this exists **and is public**:

- the PPTB validator checks `configurations.repository`, `readmeUrl` and `website` actually resolve;
- the XrmToolBox tile icon is fetched from `…/main/icon.png`, and a broken `iconUrl` gets a submission
  rejected.

```powershell
gh auth login                       # not currently logged in on this machine
cd V:\PCF\UserSecurityRoleTableAccess
gh repo create user-security-role-table-access --public --source . --remote origin --push
```

Then confirm these three resolve in a browser — the validator is checking exactly these:

- <https://github.com/TheMarkChristie/user-security-role-table-access>
- <https://github.com/TheMarkChristie/user-security-role-table-access#readme>
- <https://raw.githubusercontent.com/TheMarkChristie/user-security-role-table-access/main/README.md>

And that `icon.png` is at the repo root, because the tile icon comes from there.

---

## 1. XrmToolBox → Tool Library

**You need:** a [nuget.org](https://www.nuget.org) account and an API key.

```powershell
cd V:\PCF\UserSecurityRoleTableAccess
.\release.ps1
nuget push _dist\MarkChristie.UserSecurityRoleTableAccess.1.0.0.nupkg `
  -ApiKey <YOUR_NUGET_KEY> -Source https://api.nuget.org/v3/index.json
```

`nuget.exe` is not on PATH here; `dotnet nuget push` takes the same arguments if you would rather not
install it.

Wait for nuget.org to index (a few minutes), then register the package id at
<https://www.xrmtoolbox.com/plugins/new/>:

```
MarkChristie.UserSecurityRoleTableAccess
```

An XrmToolBox admin validates it by hand — allow a few days. Only validated tools appear in the Tool
Library.

---

## 2. Power Platform ToolBox → Tool Registry

**You need:** an [npmjs.com](https://www.npmjs.com) account, and a PPTB account for the submission form.

```powershell
cd V:\PCF\UserSecurityRoleTableAccess\pptb
npm login                           # not currently logged in on this machine
npx @pptb/validate                  # must be clean - it will fail until the repo above is public
npm publish --access public
```

The npm name `user-security-role-table-access` was free as of 19 Aug 2026.

Then submit at <https://powerplatformtoolbox.com/submit-tool> with that package name. Pick at most three
categories — **Users & Security**, **Environments**, **Troubleshooting** are the ones the manifest already
declares.

---

## Order, and why

1. **GitHub first.** Both listings point at it, and `@pptb/validate` fails without it.
2. **NuGet second.** It has the longer tail: indexing, then manual admin validation.
3. **npm last.** Instant, and the PPTB submission form is quick.

## Afterwards

- Remove the hand-installed local copy from Power Platform ToolBox so the registry version replaces it
  cleanly: delete the tool's folder under `%APPDATA%\powerplatform-toolbox\tools\` and its entry in
  `manifest.json` (a `manifest.json.bak-*` from the hand-install sits beside it).
- XrmToolBox will offer the Tool Library version as an update over the locally installed DLL.
- `_dist\UserSecurityRoleTableAccess-1.0.0.zip` stays useful regardless — it is the copy to send anyone
  who wants the tool without going through either library.

## Releasing a later version

Bump all five in step, then `.\release.ps1` will confirm they match:

| File | Field |
| --- | --- |
| `xrmtoolbox\UserSecurityRoleTableAccess\UserSecurityRoleTableAccess.csproj` | `<Version>` |
| `xrmtoolbox\UserSecurityRoleTableAccess\UserSecurityRoleTableAccess.nuspec` | `<version>` |
| `pptb\package.json` | `version` |
| `webresource\prx3_UserSecurityRoleTableAccess.html` | `APP_VERSION` |
| `xrmtoolbox\package\README.txt` | the version in the banner |
