# User Access Explorer

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

## Where it runs

The same tool runs in three places and themes itself to match each one:

| Host | Theme |
| --- | --- |
| Power Platform ToolBox | Dark |
| XrmToolBox | Windows 95 |
| Dynamics 365 web resource | Light |

## Installing

**Power Platform ToolBox** — find **User Access Explorer** in the Tool Library and install it.

**XrmToolBox** — find **User Access Explorer** in the Tool Library and install it, then restart
XrmToolBox. Plugins are discovered at startup, so a running instance will not see it until it restarts.

Connect with an **OAuth / MFA connection**. The plugin passes that connection's access token to the tool,
which is how it reaches the Dataverse Web API. If XrmToolBox cannot produce a token for your connection
type, the tool tells you and offers a box to paste one into rather than failing silently.

**Dynamics 365** — the tool can also run inside a model-driven app as an HTML web resource, surfaced from
a dashboard or the sitemap. It runs as the signed-in user, so it is security-trimmed by whoever opens it.

## Permissions you need

**Reading** requires read access to the **System User**, **Security Role**, **Team**, **Business Unit** and
**Privilege** tables. The Column security tab additionally needs Read on **Field Permission** and **Field
Security Profile**. Without those, the tool tells you what it could not read rather than quietly reporting
a user as having no access — for an access-audit tool, "cannot read" and "has no access" must never look
the same.

**Changing** roles, profiles, team membership or business units needs write access on top of that, and the
**Assign** privilege on Security Role. Dataverse will not let you assign a role containing privileges you
do not hold yourself (`0x80048d3b`); when that happens the tool shows you exactly which privileges you are
missing.

A **System Administrator** has everything it needs. With anything less, expect parts of the tool to report
what they could not see.

## A word on the write features

Copying roles, profiles, teams and especially **business units** changes real access, and there is no undo.
Read the preview line by line and start with one user before doing anything in bulk.

Moving a business unit is the one to watch: Dataverse removes *every* security role the user has. The tool
captures them first and re-applies the equivalents in the new unit immediately afterwards, and refuses
outright to make a change that would leave anyone with no role at all — because a user with no role cannot
sign in. But if one of their roles has no counterpart in the destination, they come out with less than they
went in with. The preview tells you which, before you commit to it.

## Building from source

See [docs/DEVELOPING.md](docs/DEVELOPING.md).

## Licence

MIT.
