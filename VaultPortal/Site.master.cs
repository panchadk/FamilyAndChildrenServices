using System;
using System.Web.UI;

namespace VaultPortal
{
    public partial class SiteMaster : MasterPage
    {
        public bool IsEditor
        {
            get { return Db.IsEditor(Context); }
        }

        protected void Page_Load(object sender, EventArgs e) { }
    }
}
