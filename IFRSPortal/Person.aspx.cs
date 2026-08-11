using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;

public partial class PersonPage : System.Web.UI.Page
{
    protected void btnSearch_Click(object sender, EventArgs e)
    {
        string sur = txtSurname.Text.Trim(), giv = txtGiven.Text.Trim();
        if (sur == "") return;
        Portal.Audit("PersonSearch", null, null, sur + "," + giv);

        // Match the PERSON's own name (falling back to case name only when the
        // record has no person-level name), and de-duplicate transfer copies of
        // the same case that exist in multiple worker databases.
        string where = "COALESCE(NULLIF(PersonSurname,''), Surname) LIKE @s + '%'" +
            (giv != "" ? " AND COALESCE(NULLIF(PersonGiven,''), GivenName) LIKE @g + '%'" : "");
        SqlParameter[] ps = giv != ""
            ? new[] { new SqlParameter("@s", sur), new SqlParameter("@g", giv) }
            : new[] { new SqlParameter("@s", sur) };

        DataTable dt = Portal.Query(@"
            SELECT TOP 300 COALESCE(NULLIF(PersonSurname,''), Surname) AS Surname,
                   COALESCE(NULLIF(PersonGiven,''), GivenName) AS GivenName,
                   PersonDOB, Form, CaseNumber, Created, Era, SourceTable, UNID
            FROM dbo.CaseSpine
            WHERE CopyRank = 1
              AND Form IN ('Caregiver','Child','Family','IntResponsible','Collateral','IntOther')
              AND " + where + @"
            ORDER BY 1, 2, CaseNumber, Created", ps);

        var sb = new StringBuilder();
        sb.Append("<table class='grid'><tr><th>Name</th><th>Born</th><th>Role</th><th>Case #</th><th>Date</th><th>Era</th><th></th></tr>");
        foreach (DataRow r in dt.Rows)
        {
            string dob = Convert.ToString(r["PersonDOB"]);
            if (dob.Length > 10) dob = dob.Substring(0, 10);
            sb.AppendFormat("<tr><td>{0}, {1}</td><td>{9}</td><td>{2}</td><td><a href='Case.aspx?c={3}'>{4}</a></td>" +
                "<td>{5:yyyy-MM-dd}</td><td>{6}</td><td><a href='Doc.aspx?t={7}&u={8}'>record</a></td></tr>",
                Portal.H(r["Surname"]), Portal.H(r["GivenName"]), Portal.H(r["Form"]),
                Server.UrlEncode(Convert.ToString(r["CaseNumber"])), Portal.H(r["CaseNumber"]),
                r["Created"] as DateTime?, Portal.H(r["Era"]),
                Server.UrlEncode(Convert.ToString(r["SourceTable"])),
                Server.UrlEncode(Convert.ToString(r["UNID"])), Portal.H(dob));
        }
        sb.Append("</table>");
        if (dt.Rows.Count == 0) sb.Append("<p class='sub'>No people matched.</p>");
        litResults.Text = sb.ToString();
    }
}
