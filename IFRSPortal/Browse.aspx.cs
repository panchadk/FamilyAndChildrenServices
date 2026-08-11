using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;

public partial class BrowsePage : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        string l = (Request.QueryString["l"] ?? "A").Trim().ToUpper();
        if (l.Length != 1 || l[0] < 'A' || l[0] > 'Z') l = "A";

        var az = new System.Text.StringBuilder();
        for (char c = 'A'; c <= 'Z'; c++)
            az.Append("<a class='" + (c.ToString() == l ? "on" : "") +
                      "' href='Browse.aspx?l=" + c + "'>" + c + "</a>");
        litAZ.Text = az.ToString();

        Portal.Audit("Search", null, null, "browse:" + l);

        DataTable dt = Portal.Query(@"
            SELECT TOP 500 CaseNumber,
                   MAX(Surname) AS Surname, MAX(GivenName) AS GivenName,
                   COUNT(*) AS Docs, MIN(Created) AS FirstDoc, MAX(Created) AS LastDoc,
                   MIN(Era) + CASE WHEN MIN(Era) <> MAX(Era) THEN ' / ' + MAX(Era) ELSE '' END AS Eras
            FROM dbo.CaseSpine
            WHERE CopyRank = 1 AND Surname LIKE @l + '%' AND CaseNumber IS NOT NULL AND CaseNumber <> ''
            GROUP BY CaseNumber
            ORDER BY MAX(Surname), MAX(GivenName), CaseNumber",
            new SqlParameter("@l", l));

        var sb = new StringBuilder();
        sb.Append("<table class='grid'><tr><th>Name</th><th>Case #</th><th>Documents</th><th>First</th><th>Last</th><th>Era</th></tr>");
        foreach (DataRow r in dt.Rows)
        {
            string cn = Convert.ToString(r["CaseNumber"]);
            sb.AppendFormat("<tr><td>{0}, {1}</td><td><a href='Case.aspx?c={2}'>{3}</a></td>" +
                "<td>{4}</td><td>{5:yyyy-MM-dd}</td><td>{6:yyyy-MM-dd}</td><td>{7}</td></tr>",
                Portal.H(r["Surname"]), Portal.H(r["GivenName"]),
                Server.UrlEncode(cn), Portal.H(cn), r["Docs"],
                r["FirstDoc"] as DateTime?, r["LastDoc"] as DateTime?, Portal.H(r["Eras"]));
        }
        sb.Append("</table>");
        if (dt.Rows.Count == 0) sb.Append("<p class='sub'>No cases under '" + Portal.H(l) + "'.</p>");
        if (dt.Rows.Count == 500) sb.Append("<p class='sub'>Showing first 500.</p>");
        litList.Text = sb.ToString();
    }
}
