using System.ComponentModel.Composition;
using XrmToolBox.Extensibility;
using XrmToolBox.Extensibility.Interfaces;

namespace UserSecurityRoleTableAccess
{
    /// <summary>
    /// XrmToolBox plugin registration. The actual UI lives in <see cref="TableAccessControl"/>.
    /// XrmToolBox finds this via MEF (the [Export] attributes) when the dll is dropped
    /// into the Plugins folder.
    /// </summary>
    [Export(typeof(IXrmToolBoxPlugin))]
    [ExportMetadata("Name", "User Access Explorer")]
    [ExportMetadata("Description",
        "See exactly what everyone in your Dataverse environment can do, and change it in bulk. " +
        "Lists every user with the security roles they have, showing which were given to them directly " +
        "and which came from a team. Works out what that means in practice - which tables they can " +
        "create, read, edit, delete, assign and share records in, and which protected columns they can " +
        "see. Then copies that setup onto other people, showing you exactly what will change before " +
        "anything is saved. NEEDS THE SYSTEM ADMINISTRATOR ROLE.")]
    [ExportMetadata("Author", "Mark Christie")]
    [ExportMetadata("BackgroundColor", "DarkSlateGray")]
    [ExportMetadata("PrimaryFontColor", "White")]
    [ExportMetadata("SecondaryFontColor", "WhiteSmoke")]
    [ExportMetadata("SmallImageBase64", IconData.Small)]
    [ExportMetadata("BigImageBase64", IconData.Big)]
    public class UserSecurityRoleTableAccessPlugin : PluginBase
    {
        public override IXrmToolBoxPluginControl GetControl()
        {
            return new TableAccessControl();
        }
    }
}
