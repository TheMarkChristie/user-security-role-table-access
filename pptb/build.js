/**
 * Assembles the Power Platform ToolBox distribution into ./dist.
 * PPTB loads `main` (index.html) and `icon` relative to the dist root.
 *
 * SINGLE SOURCE OF TRUTH: the tri-mode app at
 *   ../webresource/prx3_UserSecurityRoleTableAccess.html
 * It uses window.dataverseAPI when running inside ToolBox, and same-origin / bearer-token
 * fetch as a Dataverse web resource or inside the XrmToolBox WebView2 plugin.
 *
 * There is no theme injection here: the HTML sets body[data-host="pptb"] at runtime and the
 * stylesheet's dark palette is bound to that selector, so ToolBox opens DARK by default
 * without a build-time transform.
 *
 * Run:  node build.js   (or npm run build)
 */
const fs = require("fs");
const path = require("path");

const root = __dirname;
const dist = path.join(root, "dist");
const srcHtml = path.join(root, "..", "webresource", "prx3_UserSecurityRoleTableAccess.html");
const srcIcon = path.join(root, "..", "icon.svg");

// icon file name must match the "icon" field in package.json (named after the tool)
// no spaces: a filename with them is legal but trips more tooling than it is worth
const ICON = "icon.svg";

if (!fs.existsSync(srcHtml)) throw new Error("Canonical HTML not found: " + srcHtml);

fs.mkdirSync(dist, { recursive: true });
const html = fs.readFileSync(srcHtml, "utf8");
fs.writeFileSync(path.join(dist, "index.html"), html, "utf8");
fs.copyFileSync(srcIcon, path.join(dist, ICON));

console.log("Built dist/ from", path.relative(root, srcHtml));
console.log("  dist/index.html (" + html.length + " bytes), dist/" + ICON);
