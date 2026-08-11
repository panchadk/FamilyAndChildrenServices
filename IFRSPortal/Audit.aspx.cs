using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;

public partial class AuditPage : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!Portal.IsAdmin(Context.User))
        { Response.StatusCode = 403; Response.Write("Not authorized."); Response.End(); }
    }

    protected void btnGo_Click(object sender, EventArgs e)
    {
        int days; if (!int.TryParse(txtDays.Text, out days) || days < 1) days = 7;
        DataTable dt = Portal.Query(@"
            SELECT TOP 1000 EventTime, UserName, Action, CaseNumber, UNID, Detail, ClientIP
            FROM dbo.PortalAudit
            WHERE EventTime > DATEADD(DAY, -@d, SYSDATETIME())
              AND (@u = '' OR UserName LIKE '%' + @u + '%')
              AND (@c = '' OR CaseNumber = @c)
            ORDER BY EventTime DESC",
            new SqlParameter("@d", days),
            new SqlParameter("@u", txtUser.Text.Trim()),
            new SqlParameter("@c", txtCase.Text.Trim()));

        var sb = new StringBuilder();
        sb.Append("<table class='grid'><tr><th>Time</th><th>User</th><th>Action</th><th>Case</th><th>Detail</th><th>IP</th></tr>");
        foreach (DataRow r in dt.Rows)
            sb.AppendFormat("<tr><td>{0:yyyy-MM-dd HH:mm:ss}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td>{5}</td></tr>",
                r["EventTime"], Portal.H(r["UserName"]), Portal.H(r["Action"]),
                Portal.H(r["CaseNumber"]), Portal.H(r["Detail"]), Portal.H(r["ClientIP"]));
        sb.Append("</table>");
        litLog.Text = sb.ToString();
    }
}
