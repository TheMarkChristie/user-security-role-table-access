================================================================================
  USER SECURITY ROLE TABLE ACCESS  v1.0.2  --  a tool for XrmToolBox
  by Mark Christie   https://github.com/TheMarkChristie
================================================================================

  *** THIS TOOL REQUIRES THE SYSTEM ADMINISTRATOR ROLE ***

  Reading users, roles, teams and privileges needs read access across the
  security tables, and reading column security needs the Field Permission
  table - which in practice only an administrator has. Assigning roles,
  profiles, teams or business units needs write access on top of that.
  With anything less, parts of the tool will tell you what they could not
  read rather than showing you a wrong answer.


WHAT IT DOES

  See exactly what everyone in your Dataverse environment can do, and change
  it in bulk.

  Security in Dataverse is hard to see. A user's access is the sum of every
  role they have been given, plus every role they inherit from a team, folded
  together table by table - and column security sits on top of that, hiding
  fields no matter what the roles say. This tool works all of that out for you
  and shows it in one place.

  * Users        Every active user, with the security roles they hold directly
                 and the ones they inherit from teams. Filter by business unit,
                 role, team or name. Flags anyone with no role at all - those
                 people cannot sign in to a model-driven app. Export to CSV.

  * Table access Pick a user, get a table-by-table grid of what their stacked
                 roles actually let them do: Create, Read, Write, Delete,
                 Append, Append To, Assign, Share - each showing the access
                 level that applies (User / Business unit / Parent:child /
                 Organization). Click any cell to see which role granted it,
                 and whether it came direct or through a team. Export to CSV.

  * Column      Table privileges are only half the story. A column marked as
    security    secured is hidden from everyone until a Column Security Profile
                grants it back - no amount of table-level Read will reveal it.
                This lists every secured column in the environment, and whether
                the chosen user can Read, Create and Update each one, and which
                profile granted it. Most environments secure nothing at all, and
                the tab says so rather than showing an empty grid. Export to CSV.

  * Copy &       Copy from one user onto one or many others - any combination
    assign       of security roles, column security profiles, team membership
                 and business unit - or assign specific ones directly. Roles are
                 matched into each target's own business unit. Preview first;
                 nothing is written until you confirm.

                 CHANGING A USER'S BUSINESS UNIT REMOVES EVERY SECURITY ROLE
                 THEY HAVE. The tool captures them first and re-applies the
                 equivalents in the new unit immediately afterwards, and refuses
                 a move that would leave anyone with no role at all.


--------------------------------------------------------------------------------
INSTALL
--------------------------------------------------------------------------------

  1. Close XrmToolBox. (It loads plugins at startup and locks their files.)

  2. Double-click  Install.cmd

  3. Start XrmToolBox and open "User Security Role Table Access".

  If Windows shows a SmartScreen warning, that is because the zip came from the
  internet: choose "More info" then "Run anyway", or right-click the zip BEFORE
  extracting it, pick Properties, and tick Unblock. The installer also clears
  that mark from the files it copies.


  Prefer to do it by hand? Copy the contents of the Plugins folder in this zip
  into:

      %APPDATA%\MscrmTools\XrmToolBox\Plugins

  so you end up with:

      ...\XrmToolBox\Plugins\UserSecurityRoleTableAccess.dll
      ...\XrmToolBox\Plugins\app\index.html

  Both files are needed - the DLL is a thin host and the HTML is the tool.


--------------------------------------------------------------------------------
USING IT
--------------------------------------------------------------------------------

  Connect with an OAuth / MFA connection. The plugin passes that connection's
  access token to the tool, which is how it reaches the Dataverse Web API. If
  XrmToolBox cannot produce a token for your connection type, the tool tells you
  and offers a box to paste one into instead of silently failing.

  Permissions you need:

    Reading   - read access to the System User, Security Role, Team, Business
                Unit and Privilege tables. The Column security tab also needs
                read on Field Permission and Field Security Profile, which in
                practice means an administrator; without it the tool says the
                profile could not be read rather than reporting no access.
    Copying   - additionally the Assign privilege on Security Role. Dataverse
                will not let you assign a role containing privileges you do not
                hold yourself; if that happens the tool shows you exactly which
                privileges you are missing.

    A System Administrator has everything it needs.


--------------------------------------------------------------------------------
WHAT THE ACCESS GRID DOES NOT COVER
--------------------------------------------------------------------------------

  Privilege maths answers "which records of this table COULD this user touch".

  It cannot see record sharing, access-team sharing, manager or position
  hierarchy security, or team-owned records - all of which GRANT extra access.
  System Administrators bypass both models entirely, and the tool says so rather
  than pretending the grids constrain them.

  For the truth about one specific record, use that record's "Check Access" in
  the app itself.


--------------------------------------------------------------------------------
COPYING ROLES - PLEASE READ
--------------------------------------------------------------------------------

  This writes to your environment and there is no undo.

  Two modes:
    Add      leaves the targets' other roles alone.
    Mirror   makes the targets match the source exactly - so it REMOVES roles
             the source does not have.

  Safeguards built in:
    - Preview shows every change and every problem before anything happens.
    - The targets' current roles are re-read at the moment you apply; if anyone
      changed them since you previewed, nothing is written.
    - Additions always run before removals.
    - A user's removals are abandoned if any of their additions failed.
    - No removal is allowed to take a user to zero roles - Dataverse locks out
      users who have none.
    - Removing System Administrator, or targeting your own account, needs an
      extra confirmation.

  Even so: read the preview.


--------------------------------------------------------------------------------
UNINSTALL
--------------------------------------------------------------------------------

  Close XrmToolBox, then double-click Uninstall.cmd.

  Or delete these two files yourself:
      %APPDATA%\MscrmTools\XrmToolBox\Plugins\UserSecurityRoleTableAccess.dll
      %APPDATA%\MscrmTools\XrmToolBox\Plugins\app\index.html

  Nothing else is installed. No registry keys, no services, no admin rights.


--------------------------------------------------------------------------------
NOTES
--------------------------------------------------------------------------------

  Requires  XrmToolBox (current versions) on .NET Framework 4.8, and the
            WebView2 runtime - XrmToolBox already ships both, so there is
            nothing extra to install.

  Privacy   The tool talks only to the Dataverse environment you are connected
            to. Nothing is sent anywhere else, and it bundles no third-party
            code or CDN references.

  Licence   MIT.

  Issues / source
            https://github.com/TheMarkChristie/user-security-role-table-access
