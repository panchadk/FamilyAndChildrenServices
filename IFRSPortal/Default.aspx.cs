using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;

public partial class DefaultPage : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            var az = new System.Text.StringBuilder();
            for (char c = 'A'; c <= 'Z'; c++)
                az.Append("<a href='Browse.aspx?l=" + c + "'>" + c + "</a>");
            litAZ.Text = az.ToString();

            DataRow s = Portal.Stats();
            litStats.Text = "<div class='stats'>" +
                Stat(s["Cases"], "Cases", "Browse.aspx") +
                Stat(s["Docs"], "Documents", "Records.aspx?k=all") +
                Stat(s["People"], "People records", "Person.aspx") +
                Stat(s["Notes"], "Case notes", "Records.aspx?k=casenote") +
                Stat(s["Referrals"], "Referrals", "Records.aspx?k=referral") + "</div>";
        }
    }
    static string Stat(object n, string label, string url)
    {
        return "<a class='stat' href='" + url + "'><div class='n'>" + string.Format("{0:n0}", n) +
               "</div><div class='l'>" + label + "</div></a>";
    }

    protected void btnSearch_Click(object sender, EventArgs e)
    {
        string sur = txtSurname.Text.Trim(), giv = txtGiven.Text.Trim(), num = txtCase.Text.Trim();
        if (sur == "" && giv == "" && num == "") return;

        Portal.Audit("Search", num == "" ? null : num, null,
                     ("name:" + sur + "," + giv).Trim(':',' ',','));

        string where; SqlParameter[] ps;
        var plist = new System.Collections.Generic.List<SqlParameter>();
        if (num != "")
        {
            where = "(CaseNumber = @n OR TRY_CONVERT(BIGINT, CaseNumber) = TRY_CONVERT(BIGINT, @n))";
            plist.Add(new SqlParameter("@n", num));
        }
        else
        {
            where = "(Surname LIKE @s + '%' OR PersonSurname LIKE @s + '%')" +
                    (giv != "" ? " AND (GivenName LIKE @g + '%' OR PersonGiven LIKE @g + '%')" : "");
            plist.Add(new SqlParameter("@s", sur));
            if (giv != "") plist.Add(new SqlParameter("@g", giv));
        }
        string era = ddlEra.SelectedValue;
        if (era != "") { where += " AND Era = @e"; plist.Add(new SqlParameter("@e", era)); }
        ps = plist.ToArray();

        DataTable dt = Portal.Query(@"
            SELECT TOP 200 CaseNumber,
                   MAX(Surname) AS Surname, MAX(GivenName) AS GivenName,
                   COUNT(*) AS Docs,
                   MIN(Created) AS FirstDoc, MAX(Created) AS LastDoc,
                   MIN(Era) + CASE WHEN MIN(Era) <> MAX(Era)
                                   THEN ' / ' + MAX(Era) ELSE '' END AS Eras
            FROM dbo.CaseSpine
            WHERE CopyRank = 1 AND CaseNumber IS NOT NULL AND CaseNumber <> '' AND " + where + @"
            GROUP BY CaseNumber
            ORDER BY MAX(Surname), CaseNumber", ps);

        var sb = new StringBuilder();
        sb.Append("<table class='grid'><tr><th>Case #</th><th>Name</th><th>Documents</th><th>First</th><th>Last</th><th>Era</th></tr>");
        foreach (DataRow r in dt.Rows)
        {
            string cn = Convert.ToString(r["CaseNumber"]);
            sb.AppendFormat("<tr><td><a href='Case.aspx?c={0}'>{1}</a></td><td>{2}, {3}</td><td>{4}</td><td>{5:yyyy-MM-dd}</td><td>{6:yyyy-MM-dd}</td><td>{7}</td></tr>",
                Server.UrlEncode(cn), Portal.H(cn),
                Portal.H(r["Surname"]), Portal.H(r["GivenName"]),
                r["Docs"],
                r["FirstDoc"] as DateTime?, r["LastDoc"] as DateTime?,
                Portal.H(r["Eras"]));
        }
        sb.Append("</table>");
        if (dt.Rows.Count == 0) sb.Append("<p class='sub'>No cases matched.</p>");
        if (dt.Rows.Count == 200) sb.Append("<p class='sub'>Showing first 200 - refine the search.</p>");
        litResults.Text = sb.ToString();
    }
}
