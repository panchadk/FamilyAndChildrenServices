using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;

public partial class CasePage : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        string caseNo = (Request.QueryString["c"] ?? "").Trim();
        if (caseNo == "") { Response.Redirect("Default.aspx"); return; }

        Portal.Audit("CaseView", caseNo, null, null);

        DataTable dt = Portal.Query(@"
            SELECT CaseNumber, Form, UNID, Created, SourceDb, Era, SourceTable, Surname, GivenName, PersonSurname, PersonGiven, PersonDOB
            FROM dbo.CaseSpine
            WHERE CaseNumber = @c OR TRY_CONVERT(BIGINT, CaseNumber) = TRY_CONVERT(BIGINT, @c)
            ORDER BY Created", new SqlParameter("@c", caseNo));

        var sb = new StringBuilder();
        if (dt.Rows.Count == 0)
        {
            sb.Append("<h1>Case " + Portal.H(caseNo) + "</h1><p class='sub'>No documents found for this number.</p>");
            litCase.Text = sb.ToString(); return;
        }

        // Header: prefer a row that has a surname
        string sur = "", giv = "";
        foreach (DataRow r in dt.Rows)
            if (Convert.ToString(r["Surname"]) != "") { sur = Convert.ToString(r["Surname"]); giv = Convert.ToString(r["GivenName"]); break; }

        DateTime? first = null, last = null;
        var eras = new SortedSet<string>();
        var srcs = new SortedSet<string>();
        foreach (DataRow r in dt.Rows)
        {
            if (r["Created"] != DBNull.Value)
            {
                var d = (DateTime)r["Created"];
                if (first == null || d < first) first = d;
                if (last == null || d > last) last = d;
            }
            eras.Add(Convert.ToString(r["Era"]));
            srcs.Add(Convert.ToString(r["SourceDb"]));
        }

        sb.Append("<div class='casehead'><div><h1>" + Portal.H(caseNo));
        if (sur != "") sb.Append(" &mdash; " + Portal.H(sur) + (giv != "" ? ", " + Portal.H(giv) : ""));
        sb.Append("</h1><div class='meta'>" + dt.Rows.Count + " documents &middot; " +
            (first.HasValue ? first.Value.ToString("MMM yyyy") : "?") + " &ndash; " +
            (last.HasValue ? last.Value.ToString("MMM yyyy") : "?") +
            " &middot; Era: " + Portal.H(string.Join(" / ", eras)) +
            " &middot; Sources: " + srcs.Count + " database(s)</div></div>" +
            "<div class='actions noprint'><button class='btn' onclick='window.print()'>Print</button></div></div>");

        // Group by category
        var groups = new Dictionary<string, List<DataRow>>();
        foreach (DataRow r in dt.Rows)
        {
            string cat = Portal.CategoryFor(Convert.ToString(r["Form"]));
            if (!groups.ContainsKey(cat)) groups[cat] = new List<DataRow>();
            groups[cat].Add(r);
        }

        foreach (string cat in Portal.CategoryOrder)
        {
            if (!groups.ContainsKey(cat)) continue;
            var rows = groups[cat];
            bool open = (cat == "Case Management" || cat == "People");

            // Collapse transfer copies: group identical Form + Created timestamp.
            // Copies of the same document carried between worker databases keep
            // their creation time; we show one row and link the other copies.
            var byDoc = new Dictionary<string, List<DataRow>>();
            var order = new List<string>();
            foreach (DataRow r in rows)
            {
                string key = Convert.ToString(r["Form"]) + "|" +
                    (r["Created"] == DBNull.Value ? "?" : ((DateTime)r["Created"]).ToString("yyyy-MM-dd"));
                if (!byDoc.ContainsKey(key)) { byDoc[key] = new List<DataRow>(); order.Add(key); }
                byDoc[key].Add(r);
            }

            sb.Append("<details class='cat'" + (open ? " open" : "") + "><summary>" +
                      Portal.H(cat) + "<span class='pill'>" + order.Count +
                      (order.Count != rows.Count ? " (" + rows.Count + " incl. transfer copies)" : "") +
                      "</span></summary>");
            foreach (string key in order)
            {
                var copies = byDoc[key];
                DataRow r = copies[0];
                string form = Convert.ToString(r["Form"]);
                string syn = "";
                string pSur = dt.Columns.Contains("PersonSurname") ? Convert.ToString(r["PersonSurname"]) : "";
                string pGiv = dt.Columns.Contains("PersonGiven")   ? Convert.ToString(r["PersonGiven"])   : "";
                string pDob = dt.Columns.Contains("PersonDOB")     ? Convert.ToString(r["PersonDOB"])     : "";
                if (pSur != "" || pGiv != "")
                {
                    syn = (pSur != "" ? pSur.ToUpperInvariant() : "") +
                          (pGiv != "" ? (pSur != "" ? ", " : "") + pGiv : "");
                    if (pDob.Length >= 10) syn += " &middot; Born: " + Portal.H(pDob.Substring(0, 10));
                }
                else if (Convert.ToString(r["Surname"]) != "")
                    syn = Convert.ToString(r["Surname"]) + ", " + Convert.ToString(r["GivenName"]);
                if (r["Created"] != DBNull.Value)
                    syn += (syn != "" ? " &middot; " : "") + ((DateTime)r["Created"]).ToString("yyyy-MM-dd");
                syn += " <span style='color:#a09a8d'>(" + Portal.H(r["Era"]) + ")</span>";

                string extra = "";
                if (copies.Count > 1)
                {
                    var links = new StringBuilder();
                    for (int i = 1; i < copies.Count; i++)
                        links.Append(" <a href='Doc.aspx?t=" +
                            Server.UrlEncode(Convert.ToString(copies[i]["SourceTable"])) + "&u=" +
                            Server.UrlEncode(Convert.ToString(copies[i]["UNID"])) + "'>" + (i + 1) + "</a>");
                    extra = " <span style='color:#a09a8d;font-size:11px'>&middot; copies:" + links + "</span>";
                }
                sb.Append("<div class='docrow'><span class='f'><a href='Doc.aspx?t=" +
                    Server.UrlEncode(Convert.ToString(r["SourceTable"])) + "&u=" +
                    Server.UrlEncode(Convert.ToString(r["UNID"])) + "'>" +
                    Portal.H(Portal.CaptionFor(form)) + "</a></span><span class='s'>" + syn + extra + "</span></div>");
            }
            sb.Append("</details>");
        }
        litCase.Text = sb.ToString();
    }
}
