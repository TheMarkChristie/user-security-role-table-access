/**
 * Builds the redistributable ZIP for people who install User Security Role Table Access by hand,
 * without going through the XrmToolBox Tool Library.
 *
 * Layout inside the zip (Plugins/ mirrors the folder it is copied into, so a manual
 * drag-and-drop install is obvious):
 *
 *   README.txt
 *   Install.cmd  /  Install.ps1
 *   Uninstall.cmd  /  Uninstall.ps1
 *   Plugins/
 *     UserSecurityRoleTableAccess.dll
 *     app/index.html
 *
 * Prerequisite: dotnet build -c Release   (which also runs build-app.js)
 * Run:          node build-zip.js
 * Output:       ../_dist/UserSecurityRoleTableAccess-<version>.zip
 */
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const root    = __dirname;                                   // xrmtoolbox/
const proj    = path.join(root, "UserSecurityRoleTableAccess");
const bin     = path.join(proj, "bin", "Release", "net48");
const pkgSrc  = path.join(root, "package");                  // the installer + readme
const dist    = path.join(root, "..", "_dist");
const staging = path.join(dist, "zip-staging");

// version comes from the csproj, so the zip name can never drift from the assembly
const csproj  = fs.readFileSync(path.join(proj, "UserSecurityRoleTableAccess.csproj"), "utf8");
const version = (csproj.match(/<Version>([^<]+)<\/Version>/) || [])[1];
if (!version) throw new Error("Could not read <Version> from UserSecurityRoleTableAccess.csproj");

const dll  = path.join(bin, "UserSecurityRoleTableAccess.dll");
const html = path.join(bin, "app", "index.html");
for (const f of [dll, html]) {
  if (!fs.existsSync(f)) {
    throw new Error("Missing " + f + "\nBuild first:  dotnet build -c Release  (in xrmtoolbox/UserSecurityRoleTableAccess)");
  }
}

// fresh staging every time, so a removed file never lingers in the zip
fs.rmSync(staging, { recursive: true, force: true });
fs.mkdirSync(path.join(staging, "Plugins", "app"), { recursive: true });
fs.mkdirSync(dist, { recursive: true });

fs.copyFileSync(dll,  path.join(staging, "Plugins", "UserSecurityRoleTableAccess.dll"));
fs.copyFileSync(html, path.join(staging, "Plugins", "app", "index.html"));
for (const f of fs.readdirSync(pkgSrc)) {
  fs.copyFileSync(path.join(pkgSrc, f), path.join(staging, f));
}

const zip = path.join(dist, "UserSecurityRoleTableAccess-" + version + ".zip");
fs.rmSync(zip, { force: true });

// Compress-Archive rather than tar: GNU tar on Windows mangles the entry paths, and
// Compress-Archive produces a zip File Explorer opens without complaint.
execFileSync("powershell.exe", [
  "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
  `Compress-Archive -Path '${path.join(staging, "*")}' -DestinationPath '${zip}' -CompressionLevel Optimal -Force`
], { stdio: "inherit" });

fs.rmSync(staging, { recursive: true, force: true });

const kb = (fs.statSync(zip).size / 1024).toFixed(0);
console.log("Built " + path.relative(path.join(root, ".."), zip) + "  (" + kb + " KB)");
