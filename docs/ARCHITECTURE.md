# Architecture — User Access Explorer

One HTML file, three hosts, no build step for the UI. This document records how the tool talks to
Dataverse and, more importantly, **why each call was chosen over the obvious alternative**. Most of these
decisions exist because the obvious alternative is quietly wrong.

## 1. Host abstraction

`makeConn()` detects the host and `makeApi(conn)` returns one object with the same surface regardless:

| Host | Detected by | Transport |
| --- | --- | --- |
| Power Platform ToolBox | `window.dataverseAPI` | `dataverseAPI.*` only — a raw `fetch` there carries no credentials. Org URL from `toolboxAPI.connections.getActiveConnection()` |
| XrmToolBox | `window.XTB_CONFIG` | `fetch` with a bearer token injected by the plugin, from a virtual `https://` origin (see below) |
| D365 web resource | `Xrm` present, or a `*.dynamics.com` origin | same-origin `fetch` with cookies |
| Standalone | none of the above | `fetch` with a hand-pasted URL + token |

`body[data-host]` is set from the same detection, and the stylesheet carries all three palettes as design
tokens. There is deliberately no separate skinned build to drift out of sync.

**Several calls cannot be expressed as a plain OData query**, so the API object exposes them as named
methods, each with its own per-host implementation. This matters most in ToolBox, where a sandboxed tool
cannot authenticate a raw `fetch` at all — anything without a `dataverseAPI` route would simply not work
there:

| Method | ToolBox | Everything else |
| --- | --- | --- |
| `whoAmI()` | `execute({operationName:'WhoAmI', operationType:'function'})` | `GET WhoAmI` |
| `tablePrivileges()` | `getAllEntitiesMetadata([...])` | `GET EntityDefinitions?$select=…,Privileges` |
| `securedColumns()` | the System Administrator profile's `fieldpermissions` | `GET EntityDefinitions?$expand=Attributes(…IsSecured…)` |
| `rolePrivileges(id)` | `execute({operationName:'RetrieveRolePrivilegesRole', …})` | `GET RetrieveRolePrivilegesRole(RoleId=…)` |
| `userRoles(id)` / `userTeams(id)` / `teamRoles(id)` | `fetchXmlQuery` with a `link-entity` over the intersect | `GET …/systemuserroles_association` etc. |
| `assocRole` / `unassocRole` | `associate` / `disassociate` | `POST`/`DELETE` on `…/systemuserroles_association/$ref` |

The three traversal methods exist because ToolBox's `queryData` models only `entityset?query` — it cannot
walk a key predicate into a navigation property. FetchXML with a `link-entity` across `systemuserroles`,
`teammembership` and `teamroles` is the documented way through, and its host API supports it directly.

Everything else is a plain entity-set query and goes through `get()`, which uses `queryData` in ToolBox and
`fetch` elsewhere.

## 2. Loading the environment

`loadOrg()` runs once, in this order:

1. `whoAmI()` — caller context.
2. `businessunits` — the whole list, used to resolve names and to match roles into the right unit.
3. `roles` filtered to `componentstate eq 0` (Published). Unpublished and soft-deleted solution rows exist
   and would otherwise pollute every count.
4. `teams`, then `teams(<id>)/teamroles_association` per team, **skipping `teamtype = 1`** — access teams
   confer no security roles at all and including them invents privileges the user does not have.
5. `systemusers` with a single-level `$expand` of `systemuserroles_association` and
   `teammembership_association`.

### `getAllTolerant`

Several useful columns (`applicationid`, `azurestate`, `isautoassigned`, `isinherited`, `isdefault`,
`membershiptype`, `azureactivedirectoryobjectid`) are not present on every platform version, and **one bad
column 400s the entire request**. `getAllTolerant(pathFn, required, optional)` retries, dropping one
optional column from the end each time, until the request succeeds — and only on a genuine `400`, so a
transient network error cannot start amputating columns.

Each optional list is deliberately ordered so the safety-critical column survives longest: `applicationid`
on users (losing it would reclassify every application user as a person) and `isautoassigned` on roles
(losing it disables the licence-role protection, so the tool detects that case and withdraws Mirror mode
rather than carrying on regardless).

### The `$expand` fallback

A single-level `$expand` of two N:N collections alongside a top-level `$filter`/`$orderby` is legal, but it
is two joins across the whole `systemuser` table and a very large environment can refuse it. If it throws,
the tool reloads users without the expand and fetches roles and team membership per user at concurrency 8.
Slower, always correct.

### Paging

Dataverse does not support `$skip`, and `$top` is silently ignored when `odata.maxpagesize` is set. `getAll`
follows `@odata.nextLink` verbatim and resends the identical `Prefer` header on every page — changing the
page size mid-run corrupts the paging cookie. Every `$orderby` ends on a unique column, because paging
without a deterministic order duplicates and drops rows.

`If-None-Match: null` is sent on every request: collection-valued `$expand` results are browser-cacheable
and can be stale, which for a security tool running inside the user's live browser session is a
correctness bug, not a performance note.

## 3. Computing effective access

### Why not ask the platform

The obvious call is `RetrieveUserPrivileges`. It must not be used: Microsoft documents that it returns
**Basic** depth for every privilege a user inherits through team membership, *"regardless of the actual
depth granted by the team's security roles"*. A user with Global Delete through a team is reported as
User-level. `RetrieveAggregatedUserPrivileges`, which people reach for next, **does not exist**.

The correct platform-side primitives are `RetrieveUserSetOfPrivilegesByNames` / `ByIds`, but they take a
`Collection(Edm.String)` function parameter whose wire encoding is not documented on any Learn page, and a
full sweep would mean chunking several thousand privilege names through the URL. So the tool computes the
stack itself, which is fully documented and costs one call per distinct role.

### The algorithm

```text
effectiveRoles(user) = user's direct roles
                     ∪ roles of every team the user belongs to, where team.teamtype ≠ 1

for each role:  RetrieveRolePrivilegesRole(roleId)   → { PrivilegeId → Depth }   [cached]

grants[privilegeId] = [ {depth, roleId, via:'direct'|'team', viaName} , … ]

for each table T, for each verb V in {Create,Read,Write,Delete,Append,AppendTo,Assign,Share}:
    privilegeId = tablePrivilegeMap[T][V]
    cell = the grant with the highest depth rank, or none
```

Depth ranks are `Basic 1 < Local 2 < Deep 3 < Global 4`. **`RecordFilter` is ranked 0**, deliberately: it is
an orthogonal mechanism, not "better than Global", and a naive `Math.max` over the raw enum would rank it
above everything. Unknown depth names are never ranked but are still displayed, because the live org
verification turned up a `privilegedepthmask` of `16` that no Microsoft documentation describes.

There is no deny in Dataverse — privileges only accumulate — so max-depth is the whole rule.

### Two depth encodings

This is the single easiest thing to get wrong:

| | Basic | Local | Deep | Global | RecordFilter |
| --- | --- | --- | --- | --- | --- |
| `PrivilegeDepth` enum (what functions return, as a **string name**) | 0 | 1 | 2 | 3 | 4 |
| `roleprivileges.privilegedepthmask` (the stored column) | 1 | 2 | 4 | 8 | *(16 observed)* |

Mask `4` is Deep; enum `4` is RecordFilter. The tool works entirely in the **enum name** returned by
`RetrieveRolePrivilegesRole` and only consults `MASK_DEPTH` if a numeric depth ever arrives.

Similarly, `PrivilegeType` (Create 1, Read 2, Write 3, Delete 4, Assign 5, Share 6, Append 7, AppendTo 8)
and `AccessRights` (Read 1, Write 2, Append 4, AppendTo 16, Create 32, Delete 65536, Share 262144, Assign
524288) are different numbering schemes for the same eight verbs and collide on small integers. They never
share a decoder here; the tool only uses `PrivilegeType`, and accepts it as a string.

### The privilege → table map

`EntityDefinitions?$select=LogicalName,SchemaName,DisplayName,ObjectTypeCode,Privileges`.

`Privileges` is a **property** typed `Collection(SecurityPrivilegeMetadata)`, not a navigation property, so
`$expand=Privileges` fails and `$select` is required. Metadata queries are never paged — one response
carries every table — so there is no `nextLink` loop here. The table identity comes for free because the
privileges arrive nested inside the table they belong to, which also means non-table privileges
(`prvExportToExcel`, `prvActOnBehalfOfAnotherUser`, …) are excluded automatically.

The alternative most tools use, joining `privilegeobjecttypecodes`, was rejected: it has no Learn page at
all, and its `objecttypecode` is an **integer** ObjectTypeCode, not the logical name the string rendering
makes it look like.

Loading is lazy — it is the largest payload in the tool — and cached for the session.

## 4. Copying roles

### Business-unit equivalence

A security role is replicated into every business unit; each replica is a separate row with its own
`roleid` and the same name. Assigning the wrong replica fails with
`0x80041409 UserInWrongBusiness`. `resolveRoleForBu(role, buId)`:

1. Same business unit → use the role as-is.
2. Match on `roletemplateid` within the target BU. Template IDs are constant in every environment, but
   only the out-of-the-box roles have one (8 of 129 in the verification org).
3. Match on `parentrootroleid` within the target BU. This is `SystemRequired`, so it is always populated,
   and it is the universal key for custom roles.
4. No match → reported in the preview as unmatched, and skipped.

Never matched on `roleid` (not unique) or on `name` (not stable).

### Plan and apply

Pressing **Preview** first re-reads the current direct roles of the source and every target
(`refreshTargetRoles`, bounded by the tick list), so the plan is built against what is true now rather than
against whatever the page loaded with. `buildPlan()` then produces, per target: roles to add, roles already
held, roles to remove (Mirror only), unmatched roles, and any pre-flight warnings. Comparison is on `_root`
(the `parentrootroleid` family), not `roleid`, so a target already holding another BU's copy is correctly
recognised as already having it.

Mirror's keep-set is built from the source's **full** direct role list, not the ticked subset. Unticking a
role means "do not copy this"; it must never mean "strip it from everyone who has it".

**Five layers stop a user being emptied**, because Dataverse denies access to anyone with no security role
at all and there is no undo:

1. `buildPlan` drops all removals for a target whose net role count would reach zero.
2. `applyPlan` re-reads every target and **aborts the entire run** if any target's role set changed since
   Preview — someone else may have moved things while the tab sat open.
3. Every add is queued before every remove.
4. A target's removals are abandoned entirely if any of that target's additions failed.
5. Each individual removal is checked against the **live** in-memory role count and skipped if it would be
   the user's last one.

Anything that still ends up with zero roles is named explicitly in the log and turns the result banner
red — a partial failure is never reported as a success.

Removing System Administrator, and targeting your own account (`S.meId` from `WhoAmI`), are called out in
the plan and force an extra acknowledgement in the confirm dialog.

Writes are individual `$ref` calls rather than `$batch`. Volumes are small (targets × roles), individual
calls give a usable per-item error, and `$batch` carries its own traps — it requires CRLF line endings, a
boundary mismatch returns a green 200 having executed nothing, and without
`Prefer: odata.continue-on-error` it aborts at the first failure and discards the rest.

`isautoassigned` roles are excluded from the copy: they are licence-driven, and the platform adds and
removes them itself. That column is optional on older platform versions, and `getAllTolerant` would drop
it on a 400 — so the tool checks whether it actually came back and **withdraws Mirror mode** if it did not,
rather than quietly fighting the platform over licence roles.

### Throttling

`freq()` retries `429` and `503` up to four times with exponential backoff, honouring `Retry-After` where
the browser can see it (it is not a CORS-safelisted response header, so cross-origin it usually cannot).
Service protection limits are a "come back shortly", not a failure worth showing the operator — and a
browser looping over hundreds of users is exactly the shape that trips them.

### Errors

`ERRORS` maps the documented codes to something actionable — wrong business unit, disabled user,
application user, access team, Entra group team needing an inheritable role, tenant admin that cannot be
removed from System Administrator, and the privilege-escalation guard `0x80048d3b`, whose message lists
the privileges the *caller* is missing and is surfaced verbatim.

## 5. Accessibility

- Three palettes, all checked for WCAG 2.1 AA contrast — including each of the five permission-depth cell
  colour pairs in each theme.
- Depth is never colour alone: every cell carries its letter, a `title`, and an `aria-label` naming the
  verb, the table and the access level.
- Tablist implements arrow-key navigation with roving `tabindex`; the modal traps Tab, closes on Escape
  and restores focus; matrix cells are real `<button>`s.
- Focus outlines are replaced, never removed; the Windows 95 theme uses the classic dotted ring.
- `prefers-reduced-motion` collapses the spinner and progress animation.

## 6. Known limits

- Entra group teams (`teamtype` 2 and 3) derive membership at sign-in, so `teammembership` can lag the
  real group. The tool warns when a user belongs to one rather than pretending the list is authoritative.
- The multi-business-unit role-replica path could not be regression-tested: the verification environment
  has a single business unit. The logic is written to be correct either way, but it wants a multi-BU org.
- Matrix data access (`EnableOwnershipAcrossBusinessUnits`) changes what a cross-BU role means. Detecting
  whether it is on is unreliable by design — `orgdborgsettings` only records explicitly-set values — so
  the tool does not claim to know, and lets the assignment succeed or fail on its merits.

## 7. Why the XrmToolBox plugin does not load the page from `file://`

The obvious way to host a bundled HTML file in WebView2 is to navigate to its `file://` URL. That breaks
every Dataverse call: a `file://` page sends `Origin: null` on the CORS preflight, and the Web API refuses
it. The plugin therefore maps its `app` folder onto a virtual host with
`SetVirtualHostNameToFolderMapping` and navigates to `https://usersecurityroletableaccess.local/index.html`, so
the page has a real, stable origin. The bearer token from the active XrmToolBox connection is injected as
`window.XTB_CONFIG` via `AddScriptToExecuteOnDocumentCreatedAsync`, before any document script runs.

If the connection has no OAuth token — a connection type XrmToolBox cannot mint one for — the page says so
and offers the manual token panel rather than reporting itself connected and then failing every request
with an error that looks like an authentication problem but is not.

Those tokens last about an hour, and a bulk role copy across a large tenant can outlive one. On a `401`
the page posts `{"type":"refreshToken"}` over the WebView2 message channel; the plugin re-reads
`ServiceClient.CurrentAccessToken`, posts it back, and the request is retried once. If nothing answers
within 2.5 seconds the `401` surfaces with a message that names the actual cause.

The plugin also cancels any navigation away from the virtual host and opens it in the user's real browser
instead. The injected `XTB_CONFIG` carries a live bearer token, and it must never end up in a document
that is not ours.

## 8. What ToolBox can and cannot do

A ToolBox tool is sandboxed and holds no access token of its own, so a raw `fetch` there can never be
authenticated. That makes the per-host method table in §1 a correctness requirement rather than an
optimisation: anything without a `dataverseAPI` route simply would not work.

For the same reason `get()` does **not** fall back to `fetch` when `queryData` rejects in ToolBox. The
fallback would always fail, and worse it would replace a real Dataverse error — a `403` the tool has copy
for, or the `400` that `getAllTolerant` needs to recognise a missing column — with an unrelated network
error. The host's error is allowed through unchanged.

One residual ToolBox limitation: `queryData` cannot carry a `Prefer` header, so pages come back at the
server default size rather than a requested one. Paging still works through `@odata.nextLink`.

## 9. Column-level security

A second, independent model. Table privileges say which *records* a user can touch; column security says
which *columns* of those records they can see. A column with `AttributeMetadata.IsSecured = true` is
**deny by default** — hidden from everyone, whatever their table privileges — until a Column Security
Profile grants it back.

### Queries

| Purpose | Call |
| --- | --- |
| Every secured column in the org | `EntityDefinitions?$select=LogicalName,SchemaName,DisplayName&$expand=Attributes($select=LogicalName,DisplayName,IsSecured;$filter=IsSecured eq true)` |
| A user's profiles (direct only) | `systemusers(<id>)/systemuserprofiles_association` |
| A team's profiles | `teams(<id>)/teamprofiles_association` |
| The permissions in a profile | `fieldpermissions?$select=…&$filter=_fieldsecurityprofileid_value eq <id>` |

The secured-column list comes from **metadata**, which any user can read — deliberately, because the field
permissions themselves need `prvReadFieldPermission` (in practice, an administrator). If that read fails
the tool names the profiles it could not open, instead of reporting the user as having no access. For a
security-audit tool, "cannot read" and "has no access" must never look the same.

`IsSecured` lives on the base `AttributeMetadata` type, so no cast is needed inside the `$expand`, and
metadata queries are not paged — one round trip covers the whole environment.

The profile permissions are read as a **flat entity-set query** rather than through the documented
`fieldsecurityprofiles(<id>)/lk_fieldpermission_fieldsecurityprofileid` navigation path. Two reasons: a
flat query works through ToolBox's `queryData` where a navigation path does not, and it keeps every host
on OData. That second point is load-bearing — `entityname` is an `EntityName`-typed column, and the live
verification showed that through FetchXML it comes back as the **object type code** (`2`) or the table's
**display name** (`Contact`), neither of which joins to metadata. Over the Web API it is the logical name.

### Option values

| Column | Choice | Values |
| --- | --- | --- |
| `canread`, `cancreate`, `canupdate` | `field_security_permission_type` | **0** Not Allowed, **4** Allowed |
| `canreadunmasked` | `field_security_permission_readunmasked` | **0** None, **1** One record, **3** All records |

Two traps here. The allowed value is **4, not 1**. And `canreadunmasked` is a different choice with three
levels — rendering it as a yes/no toggle would misreport it, so it gets its own column.

`fsAllowed()` deliberately accepts numbers, numeric strings and labels: some surfaces return
`"Allowed"` / `"Not Allowed"` rather than the integer, and `Number("Allowed")` is `NaN` — which would sail
straight past a naive `!== 0` test and report access that does not exist.

### The fold

```text
profiles(user) = systemuserprofiles_association(user)
               ∪ teamprofiles_association(each non-access team the user is in)

for each profile:  fieldpermissions where _fieldsecurityprofileid_value = profile   [cached]

for each secured column C:
    grants = every profile permission matching C.table + '.' + C.column
    read   = admin OR any grant allows read          (same for create and update)
    masking = the highest canreadunmasked across the grants
```

Permissions are a union — most permissive wins, and there is no deny. **System Administrators are never
subject to column security at all**, so the tool short-circuits them and says so rather than presenting a
computed grid that implies limits which do not exist.

`systemuserprofiles_association` returns only *directly* assigned profiles; team-derived ones are invisible
to it, so the union is done explicitly — exactly as with security roles. Access teams (`teamtype = 1`)
carry no profiles and are skipped.
