# User Security Role Table Access

**See exactly what everyone in your Dataverse environment can do, and change it in bulk.**

By **Mark Christie** — [github.com/TheMarkChristie](https://github.com/TheMarkChristie)

> **You need the System Administrator role to use this.** It reads the tables behind Dataverse security,
> and in practice only an administrator can see all of them.

## Why

Working out what a Dataverse user can actually do is genuinely hard. Their access is the sum of every
security role they have been given, *plus* every role they inherit from every team they belong to, folded
together table by table — and column security sits on top of all that, hiding individual fields no matter
what the roles say. The answer is spread across half a dozen screens, and none of them show you the total.

This tool works it out and puts it in one place. Then, when you find someone set up the way you want,
it copies that setup onto other people — and shows you exactly what will change before anything is saved.

## At a glance

| Tab | What it answers |
| --- | --- |
| **Users** | Who has a login, what roles do they have, and which of those came from a team rather than being given to them directly? |
| **Table access** | For one person: which tables can they create, read, edit, delete, assign and share records in — and whose records, theirs or everyone's? |
| **Column security** | Which protected fields can they actually see, and which profile lets them? |
| **Copy & assign** | Make other people look like this one — roles, column security profiles, teams and business unit — with a preview first. |

Every grid exports to CSV, so an access review can go in a spreadsheet and off to whoever asked for it.

## What it does

### Users

Most Dataverse environments contain far more "users" than people — service accounts, integrations and
platform plumbing typically outnumber the humans four to one. So everyone is sorted into **Person**,
**Application**, **Non-interactive** or **System**, and the list starts with the people.

Filter by business unit, role, team or name. Show disabled users if you want them. Or ask for the users
with **no role at all** — those people cannot sign in to an app, and the tool warns you when it finds any.

Each row shows the roles the user holds, with **Direct** and **Inherited** counts and a marker on every
role saying whether it was given to them or came from a team. That distinction matters: you cannot take an
inherited role away from the person, only from the team.

### Table access

Pick a user and get a table-by-table grid of what their stacked roles actually let them do:

| | Meaning |
| --- | --- |
| **U** | User — their own records |
| **B** | Business unit |
| **P** | Parent: child business units |
| **O** | Organization |
| **F** | Record filter |
| — | No access |

The depth shown is the **highest** granted by any of the user's roles, which is how Dataverse itself
resolves them — privileges only ever accumulate, there is no deny. Click any cell to see exactly which
roles granted it and at what level, and whether each came direct or via a team.

Export the whole grid to CSV for an access review.

### Column security

Table privileges are only half the story: a column marked as **secured** is hidden from everyone until a
Column Security Profile grants it back, and no amount of table-level Read will reveal it.

This tab lists every secured column in the environment — table and column, both display and logical names
— and, for the chosen user, whether their profiles allow **Read**, **Create** and **Update** on each, plus
which profile granted it and whether that profile came directly or through a team. Masking is shown
separately, because "can read the unmasked value" is a different setting with its own three levels.

Most environments secure nothing at all, and the tab says so plainly rather than showing an empty grid.

### Copy & assign

"Make Priya's account look like Sam's" — or just "give these twelve people this role".

Pick someone to copy from and tick what to include: security roles, column security profiles, team
membership, business unit. Choose **Add** (leave their other access alone) or **Mirror** (make them match
exactly). Or switch to **Assign** and pick one specific role, profile, team or business unit to apply.

Then **Preview**. It shows, per person, what will be added, what will be removed, what they already have,
and every problem it can see coming — a disabled account, a role that does not exist in their business
unit, a team whose membership is controlled by Microsoft Entra. Nothing is written until you press Apply
and confirm.

**Moving someone to a different business unit removes every security role they have.** That is Dataverse's
behaviour, not this tool's. The tool captures their roles first, moves them, then puts the equivalents back
in the new business unit — and refuses outright to make a change that would leave anyone with no role,
because a user with no role cannot sign in at all.

## Why it is built the way it is

Getting effective permissions right in Dataverse is mostly about avoiding traps. The ones that shaped this
tool:

- **`RetrieveUserPrivileges` cannot be used.** It has a documented defect: for any privilege a user
  inherits from a team it reports **Basic** depth regardless of what the team's role actually grants. A
  tool built on it silently under-reports. This one computes the stack itself from
  `RetrieveRolePrivilegesRole`, which returns the true depth per role.
- **Access teams grant no roles** (`teamtype = 1`), so they are excluded from the maths — but the default
  business-unit team is an Owner team containing everybody in the unit, so it very much is included.
- **A role exists once per business unit.** "Give Bob the same role as Alice" means finding the copy of
  that role that lives in *Bob's* business unit — Dataverse rejects the other one with
  `0x80041409 UserInWrongBusiness`. Equivalence is resolved on `roletemplateid` first (constant in every
  environment, but only the out-of-the-box roles have one), then `parentrootroleid`.
- **Every user must keep at least one role**, or Dataverse denies them access entirely. So additions are
  always applied before removals, and Mirror mode refuses to empty anyone out.
- **Licence-driven roles (`isautoassigned`) are not copied** — the platform assigns and removes those
  itself, so copying them achieves nothing.
- The privilege-to-table map comes from `EntityDefinitions?$select=LogicalName,Privileges`, not from the
  undocumented `privilegeobjecttypecodes` intersect that most tools join to.

- **Column security is a separate model.** Secured columns are deny-by-default and are granted through
  Column Security Profiles, not security roles — so it gets its own tab rather than being folded into the
  table grid. `canread`/`cancreate`/`canupdate` use `0 = Not Allowed, 4 = Allowed` (the value is 4, not 1),
  while `canreadunmasked` uses an entirely different choice: 0 None, 1 One record, 3 All records.

### What it does not cover

Privilege maths answers "which records of this table *could* this user touch". It cannot see record
sharing, access-team sharing, manager or position hierarchy security, or team-owned records — all of which
**grant** extra access. System Administrators bypass both models entirely, and the tool says so rather
than pretending the grids constrain them. For the truth about one specific record, use that record's
**Check Access** in the app.

## Hosts

One HTML file runs in three places and themes itself to match:

| Host | Detected by | Theme |
| --- | --- | --- |
| Power Platform ToolBox | `window.dataverseAPI` | Dark |
| XrmToolBox | `window.XTB_CONFIG` | Windows 95 |
| Dynamics 365 web resource | `Xrm` / same origin | Light |

`webresource/prx3_UserSecurityRoleTableAccess.html` is the single source of truth. The other two builds are
copies — there is no separate skinned version to drift out of sync.

## Install

### XrmToolBox

Build and install locally:

```powershell
cd V:\PCF\UserSecurityRoleTableAccess\xrmtoolbox\UserSecurityRoleTableAccess
dotnet build -c Release
..\install.cmd
```

`install.cmd` wraps `install.ps1` with `-ExecutionPolicy Bypass`, so it also works from Explorer. It copies
only `UserSecurityRoleTableAccess.dll` and `app\index.html` into `%APPDATA%\MscrmTools\XrmToolBox\Plugins` —
XrmToolBox already ships WebView2 and the Dataverse SDK, and shipping our own copies would clash with
other tools. To uninstall, delete those two files.

**Restart XrmToolBox**, then open **User Security Role Table Access**. Plugins are discovered at startup, so a
running instance will not see it until it restarts.

The plugin is a thin WebView2 host: it pushes the active connection's org URL and OAuth token into the page
as `window.XTB_CONFIG`, so use an **OAuth/MFA connection** — a connection type XrmToolBox cannot mint a
token for will land you on the manual token panel instead.

#### Giving it to other people

`node xrmtoolbox\build-zip.js` (after a Release build) produces
`_dist\UserSecurityRoleTableAccess-<version>.zip` — a self-contained drop for anyone who wants the tool without
going through the Tool Library. It holds `Install.cmd` / `Uninstall.cmd`, a plain-English `README.txt`, and
a `Plugins\` folder that mirrors the destination so a manual drag-and-drop install is obvious. The
installer finds the Plugins folder itself, refuses politely if XrmToolBox is running, skips files that are
already identical, and clears the mark-of-the-web that Windows puts on anything downloaded — without which
.NET can refuse to load the assembly.

To publish to the Tool Library instead, see [PUBLISHING.md](PUBLISHING.md).

### Power Platform ToolBox

```powershell
cd V:\PCF\UserSecurityRoleTableAccess\pptb
npm run build
npx @pptb/validate
```

Load `dist/` through the ToolBox Debug Menu, or publish to npm and the Tool Registry — again, see
[PUBLISHING.md](PUBLISHING.md).

### Dynamics 365 web resource

Deploy `webresource/prx3_UserSecurityRoleTableAccess.html` as an HTML web resource named
`prx3_UserSecurityRoleTableAccess.html` and surface it from a dashboard or the sitemap. It runs as the signed-in
user, so it is security-trimmed by whoever opens it.

## Permissions the tool itself needs

Reading requires read access to the **System User**, **Security Role**, **Team**, **Business Unit** and
**Privilege** tables. The Column security tab additionally needs Read on **Field Permission** and **Field
Security Profile** — in practice an administrator. Without it the tool says the profile could not be read,
rather than quietly reporting the user as having no access. Copying roles additionally requires the **Assign** privilege on Security Role, and
Dataverse will refuse to let you assign a role containing privileges you do not hold yourself
(`0x80048d3b`) — the tool surfaces the list of missing privileges verbatim when that happens. A System
Administrator has everything it needs.

## Layout

| Path | What it is |
| --- | --- |
| `webresource/prx3_UserSecurityRoleTableAccess.html` | The whole application — single source of truth |
| `xrmtoolbox/UserSecurityRoleTableAccess/` | WebView2 plugin host (.NET 4.8), nuspec, icons |
| `xrmtoolbox/build-app.js` | Copies the app into the plugin output |
| `xrmtoolbox/build-zip.js` | Builds the redistributable ZIP into `_dist/` |
| `xrmtoolbox/package/` | Installer, uninstaller and README that go inside that ZIP |
| `xrmtoolbox/install.cmd` / `install.ps1` | Local install into the XrmToolBox Plugins folder |
| `pptb/` | Power Platform ToolBox manifest and build |
| `docs/ARCHITECTURE.md` | How the permission computation and role copy work |
| `PUBLISHING.md` | Release steps for both tool libraries |
| `xrmtoolbox/gen-icondata.ps1` | Regenerates the icon PNGs and `IconData.cs` from `icon.svg` |
| `icon.svg` | The one source icon — everything else (`icon.png`, `icon32/80.png`, the PPTB SVG, the inline header mark) derives from it |
| `_dist/` | Built release artefacts: the hand-install ZIP and the NuGet package |

## Licence

MIT.
