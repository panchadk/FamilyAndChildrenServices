using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;

public partial class DocPage : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        string table = (Request.QueryString["t"] ?? "").Trim();
        string unid  = (Request.QueryString["u"] ?? "").Trim();
        if (table == "" || unid == "" || !Portal.IsKnownTable(table))
        { Response.Redirect("Default.aspx"); return; }

        DataTable dt = Portal.Query(
            "SELECT TOP 1 * FROM dbo." + Quote(table) + " WHERE UNID = @u",
            new SqlParameter("@u", unid));
        if (dt.Rows.Count == 0)
        { litDoc.Text = "<p class='sub'>Document not found.</p>"; return; }
        DataRow r = dt.Rows[0];

        // Catalog info (form, era, source db)
        DataTable cat = Portal.Query(
            "SELECT [Form], SourceDb, Era FROM dbo.NSF_TableCatalog WHERE TargetTable = @t",
            new SqlParameter("@t", table));
        string form = cat.Rows.Count > 0 ? Convert.ToString(cat.Rows[0]["Form"]) : "";
        string caseNo = dt.Columns.Contains("CaseNumber") ? Convert.ToString(r["CaseNumber"]) : null;

        Portal.Audit("DocView", caseNo, unid, table);

        var sb = new StringBuilder();
        sb.Append("<div class='casehead'><div><h1 class='doc'>" + Portal.H(Portal.CaptionFor(form)) + "</h1>");
        if (!string.IsNullOrEmpty(caseNo))
            sb.Append("<div class='meta'>Case <a href='Case.aspx?c=" + Server.UrlEncode(caseNo) + "'>" +
                      Portal.H(caseNo) + "</a></div>");
        sb.Append("</div><div class='actions noprint'><button class='btn' onclick='window.print()'>Print</button></div></div>");

        // Short fields as a table; long/multiline fields as narrative blocks
        var narrs = new StringBuilder();
        sb.Append("<table class='fieldtbl'>");
        foreach (DataColumn c in dt.Columns)
        {
            string name = c.ColumnName;
            if (name == "UNID" || name == "NoteID" || name == "_Attachments") continue;
            string val = Convert.ToString(r[c]);
            if (string.IsNullOrWhiteSpace(val)) continue;
            if (r[c] is DateTime) val = ((DateTime)r[c]).ToString("yyyy-MM-dd HH:mm");

            if (val.Length > 250 || val.Contains("\n"))
                narrs.Append("<div class='narrhead'>" + Portal.H(name) + "</div><div class='narr'>" +
                             Portal.H(val) + "</div>");
            else
                sb.Append("<tr><td class='k'>" + Portal.H(name) + "</td><td>" + Portal.H(val) + "</td></tr>");
        }
        sb.Append("</table>");
        sb.Append(narrs.ToString());

        // Attachments for this document
        DataTable att = Portal.Query(
            "SELECT AttachmentId, FileName, SizeBytes FROM dbo.NSF_Attachments WHERE UNID = @u ORDER BY FileName",
            new SqlParameter("@u", unid));
        if (att.Rows.Count > 0)
        {
            sb.Append("<div class='narrhead'>Attachments (" + att.Rows.Count + ")</div><table class='grid'>");
            foreach (DataRow a in att.Rows)
                sb.AppendFormat("<tr><td>{0}</td><td>{1:n0} bytes</td>" +
                    "<td class='noprint'><a href='Attachment.ashx?id={2}&mode=inline'>View</a> &middot; " +
                    "<a href='Attachment.ashx?id={2}'>Download</a></td></tr>",
                    Portal.H(a["FileName"]), a["SizeBytes"], a["AttachmentId"]);
            sb.Append("</table>");
        }

        sb.Append("<div class='prov'>Source: " + Portal.H(cat.Rows.Count > 0 ? cat.Rows[0]["SourceDb"] : table) +
                  " (" + Portal.H(cat.Rows.Count > 0 ? cat.Rows[0]["Era"] : "") + ") &middot; Table: " +
                  Portal.H(table) + " &middot; UNID: " + Portal.H(unid));
        if (dt.Columns.Contains("Created") && r["Created"] != DBNull.Value)
            sb.Append(" &middot; Created: " + ((DateTime)r["Created"]).ToString("yyyy-MM-dd HH:mm"));
        sb.Append("</div>");

        litDoc.Text = sb.ToString();
    }

    static string Quote(string ident) { return "[" + ident.Replace("]", "]]") + "]"; }
}
