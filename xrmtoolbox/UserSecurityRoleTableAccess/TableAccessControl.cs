using System;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;
using McTools.Xrm.Connection;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using Microsoft.Xrm.Sdk;
using XrmToolBox.Extensibility;
using XrmToolBox.Extensibility.Interfaces;

namespace UserSecurityRoleTableAccess
{
    /// <summary>
    /// WebView2 host for the shared User Security Role Table Access HTML app. On every connection
    /// change we push the org URL + a fresh OAuth access token into the page as
    /// window.XTB_CONFIG, then (re)load it so the JS picks "XrmToolBox (WebView2)" mode and
    /// calls the Dataverse Web API directly.
    /// </summary>
    public partial class TableAccessControl : PluginControlBase, IGitHubPlugin, IHelpPlugin
    {
        /// <summary>
        /// The app is served from this virtual https host rather than from file://. A file:// page sends
        /// "Origin: null", which the Dataverse Web API rejects on the CORS preflight; a virtual host gives
        /// the page a real, stable origin that Dataverse will answer.
        /// </summary>
        private const string VirtualHost = "usersecurityroletableaccess.local";

        private readonly WebView2 _web;
        private bool _webReady;
        private string _orgUrl;
        private string _token;
        private string _userName;
        private string _configScriptId;
        private ConnectionDetail _detail;

        /// <summary>
        /// UpdateConnection fires and forgets, so two connection changes can interleave between removing
        /// the old config script and adding the new one - leaving a stale org URL and token registered.
        /// One at a time.
        /// </summary>
        private readonly System.Threading.SemaphoreSlim _configLock = new System.Threading.SemaphoreSlim(1, 1);

        // IGitHubPlugin -> adds the "Report an issue" menu
        public string RepositoryName => "user-security-role-table-access";
        public string UserName => "TheMarkChristie";

        // IHelpPlugin -> adds the Help menu
        public string HelpUrl => "https://github.com/TheMarkChristie/user-security-role-table-access#readme";

        public TableAccessControl()
        {
            _web = new WebView2 { Dock = DockStyle.Fill };
            Controls.Add(_web);
            Load += async (s, e) => await InitWebViewAsync();
        }

        private async Task InitWebViewAsync()
        {
            // isolate the WebView2 user-data folder under %LOCALAPPDATA% so it works
            // even when the dll runs from a read-only Plugins folder.
            var udf = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "UserSecurityRoleTableAccess", "WebView2");
            Directory.CreateDirectory(udf);

            var env = await CoreWebView2Environment.CreateAsync(null, udf);
            await _web.EnsureCoreWebView2Async(env);
            _webReady = true;

            // the tool is read-mostly; keep the browser chrome out of the way
            _web.CoreWebView2.Settings.AreDefaultContextMenusEnabled = true;
            _web.CoreWebView2.Settings.IsStatusBarEnabled = false;

            // Map the plugin's app folder onto a virtual https origin. Without this the page loads from
            // file://, whose "null" origin Dataverse refuses on the CORS preflight, and every Web API
            // call fails with an error that looks like an auth problem but is not.
            var appDir = Path.Combine(
                Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? ".", "app");
            if (Directory.Exists(appDir))
            {
                // DenyCors: nothing else should be able to pull resources out of this virtual host.
                _web.CoreWebView2.SetVirtualHostNameToFolderMapping(
                    VirtualHost, appDir, CoreWebView2HostResourceAccessKind.DenyCors);
            }

            // The injected config carries a live bearer token, so the WebView must never navigate
            // anywhere else. Anything that is not our own page is cancelled and opened externally.
            _web.CoreWebView2.NavigationStarting += (s, e) =>
            {
                if (e.Uri != null &&
                    e.Uri.StartsWith("https://" + VirtualHost + "/", StringComparison.OrdinalIgnoreCase)) return;
                e.Cancel = true;
                TryOpenExternally(e.Uri);
            };
            _web.CoreWebView2.NewWindowRequested += (s, e) =>
            {
                e.Handled = true;
                TryOpenExternally(e.Uri);
            };

            // The page asks for a fresh token when its own has expired (they last about an hour,
            // and a bulk role copy across a large tenant can easily straddle that boundary).
            _web.CoreWebView2.WebMessageReceived += (s, e) =>
            {
                try
                {
                    if (!(e.TryGetWebMessageAsString() ?? "").Contains("refreshToken")) return;
                    var fresh = _detail?.ServiceClient?.CurrentAccessToken;
                    if (string.IsNullOrEmpty(fresh)) return;
                    _token = fresh;
                    _web.CoreWebView2.PostWebMessageAsJson(
                        "{\"type\":\"token\",\"token\":" + JsString(fresh) + "}");
                    LogInfo("User Security Role Table Access: refreshed the access token for the page.");
                }
                catch (Exception ex) { LogError("Token refresh failed: " + ex.Message); }
            };

            await PushConfigAndNavigateAsync();
        }

        /// <summary>Resolve org URL + token from the connection and (re)load the app.</summary>
        private async Task PushConfigAndNavigateAsync()
        {
            if (!_webReady) return;

            await _configLock.WaitAsync();
            try
            {

                // inject config BEFORE any document script runs
                var configJs = string.IsNullOrEmpty(_orgUrl)
                    ? "window.XTB_CONFIG = undefined;"
                    : "window.XTB_CONFIG = { baseUrl: " + JsString(_orgUrl) +
                      ", token: " + JsString(_token) +
                      ", userName: " + JsString(_userName) + " };";

                // Replace the previous script rather than stacking another one: UpdateConnection fires on
                // every org switch, and WebView2 does not guarantee the relative order of registered
                // scripts, so leftovers could hand the page a stale org URL and token.
                if (_configScriptId != null)
                {
                    _web.CoreWebView2.RemoveScriptToExecuteOnDocumentCreated(_configScriptId);
                    _configScriptId = null;
                }
                _configScriptId = await _web.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync(configJs);

                var html = Path.Combine(
                    Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? ".",
                    "app", "index.html");

                if (File.Exists(html))
                    // via the virtual host, so the page has a real origin for the Dataverse CORS preflight
                    _web.CoreWebView2.Navigate("https://" + VirtualHost + "/index.html");
                else
                    _web.CoreWebView2.NavigateToString(
                        "<h3 style='font-family:Segoe UI'>app/index.html not found next to the plugin dll.</h3>" +
                        "<p>The build copies prx3_UserSecurityRoleTableAccess.html into the output 'app' folder. " +
                        "Run <code>node xrmtoolbox\\build-app.js</code> and rebuild the project. " +
                        "(That step needs Node on PATH and fails quietly without it.)</p>");
            }
            finally
            {
                _configLock.Release();
            }
        }

        /// <summary>Open a URL in the user's real browser rather than inside the token-bearing WebView.</summary>
        private void TryOpenExternally(string uri)
        {
            try
            {
                if (!string.IsNullOrEmpty(uri) &&
                    (uri.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ||
                     uri.StartsWith("http://", StringComparison.OrdinalIgnoreCase)))
                {
                    System.Diagnostics.Process.Start(uri);
                }
            }
            catch (Exception ex) { LogWarning("Could not open " + uri + " externally: " + ex.Message); }
        }

        private static string JsString(string s) =>
            s == null ? "null" : "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";

        /// <summary>Called by XrmToolBox whenever the active org connection changes.</summary>
        public override void UpdateConnection(
            IOrganizationService newService, ConnectionDetail detail,
            string actionName = "", object parameter = null)
        {
            base.UpdateConnection(newService, detail, actionName, parameter);

            try
            {
                _detail = detail;
                _orgUrl = detail?.WebApplicationUrl?.TrimEnd('/')
                          ?? detail?.OrganizationServiceUrl?.Replace("/XRMServices/2011/Organization.svc", "").TrimEnd('/');
                _userName = detail?.UserName;

                // ServiceClient (CrmServiceClient in current XTB) exposes the OAuth bearer token
                var svc = detail?.ServiceClient;
                _token = svc?.CurrentAccessToken;

                if (string.IsNullOrEmpty(_token))
                    LogWarning("No OAuth access token available on this connection — " +
                               "the page will fall back to its manual token panel. Use an OAuth/MFA connection.");
                else
                    LogInfo("User Security Role Table Access connected to " + _orgUrl);
            }
            catch (Exception ex)
            {
                LogError("Failed to resolve connection token: " + ex.Message);
            }

            // fire-and-forget reload with the new config
            _ = PushConfigAndNavigateAsync();
        }
    }
}
