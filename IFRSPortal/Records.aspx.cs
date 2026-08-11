using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;

public partial class RecordsPage : System.Web.UI.Page
{
    // form querystring value -> (spine Form filter list, page title)
    static readonly Dictionary<string, string[]> Kinds =
        new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase)
    {
        { "casenote",  new[] { "CaseNote" } },
        { "referral",  new[] { "Referral", "IntReferral" } },
        { "cdform",    new[] { "CDForm" } },
        { "all",       new string[0] }
    };

    string Kind { get { return (Request.QueryString["k"] ?? "all").ToLowerInvariant(); } }

    protected void Page_Load(object sender, EventArgs e)
    {
        string title = Kind == "casenote" ? "Case Notes"
                     : Kind == "referral" ? "Referrals"
                     : Kind == "cdform"   ? "Recording (CD) Forms"
                     : "All Documents";
        litTitle.Text = title;
        litSub.Text = "Most recent first. Use the surname filter to narrow, or open the case for full context.";
        if (!IsPostBack) Bind();
    }

    protected void btnGo_Click(object sender, EventArgs e) { Bind(); }

    void Bind()
    {
        string sur = txtSurname.Text.Trim();
        string era = ddlEra.SelectedValue;
        Portal.Audit("Search", null, null, "records:" + Kind + (sur != "" ? " sur:" + sur : ""));

        var wh = new List<string>();
        var ps = new List<SqlParameter>();

        string[] forms;
        if (Kinds.TryGetValue(Kind, out forms) && forms.Length > 0)
        {
            var names = new List<string>();
            for (int i = 0; i < forms.Length; i++)
            {
                names.Add("@f" + i);
                ps.Add(new SqlParameter("@f" + i, forms[i]));
            }
            wh.Add("Form IN (" + string.Join(",", names) + ")");
        }
        if (sur != "")
        {
            wh.Add("(Surname LIKE @s + '%' OR PersonSurname LIKE @s + '%')");
            ps.Add(new SqlParameter("@s", sur));
        }
        if (era != "") { wh.Add("Era = @e"); ps.Add(new SqlParameter("@e", era)); }
        wh.Insert(0, "CopyRank = 1");
        string where = "WHERE " + string.Join(" AND ", wh);

        DataTable dt = Portal.Query(@"
            SELECT TOP 200 Created, Form,
                   COALESCE(NULLIF(PersonSurname,''), Surname) AS Surname,
                   COALESCE(NULLIF(PersonGiven,''), GivenName) AS GivenName,
                   CaseNumber, Era, SourceTable, UNID
            FROM dbo.CaseSpine " + where + @"
            ORDER BY Created DESC", ps.ToArray());

        var sb = new StringBuilder();
        sb.Append("<table class='grid'><tr><th>Date</th><th>Type</th><th>Name</th><th>Case #</th><th>Era</th><th></th></tr>");
        foreach (DataRow r in dt.Rows)
        {
            sb.AppendFormat("<tr><td>{0:yyyy-MM-dd}</td><td>{1}</td><td>{2}, {3}</td>" +
                "<td><a href='Case.aspx?c={4}'>{5}</a></td><td>{6}</td>" +
                "<td><a href='Doc.aspx?t={7}&u={8}'>open</a></td></tr>",
                r["Created"] as DateTime?, Portal.H(Portal.CaptionFor(Convert.ToString(r["Form"]))),
                Portal.H(r["Surname"]), Portal.H(r["GivenName"]),
                Server.UrlEncode(Convert.ToString(r["CaseNumber"])), Portal.H(r["CaseNumber"]),
                Portal.H(r["Era"]),
                Server.UrlEncode(Convert.ToString(r["SourceTable"])),
                Server.UrlEncode(Convert.ToString(r["UNID"])));
        }
        sb.Append("</table>");
        if (dt.Rows.Count == 0) sb.Append("<p class='sub'>Nothing matched.</p>");
        if (dt.Rows.Count == 200) sb.Append("<p class='sub'>Showing most recent 200 - use the surname filter to narrow.</p>");
        litList.Text = sb.ToString();
    }
}
