using System;
using System.Data.SqlClient;
using System.Web.Configuration;
using System.Web.UI;

public partial class ScanDoc_Viewer : Page
{
    private static string ConnStr
    {
        get { return WebConfigurationManager.ConnectionStrings["ScanArchive"].ConnectionString; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        int docId;
        if (!int.TryParse(Request.QueryString["doc"], out docId))
        {
            litFrame.Text = "<div class=\"err\">No document specified.</div>";
            return;
        }

        string fileName = null;
        int? caseId = null;

        using (var cn = new SqlConnection(ConnStr))
        {
            cn.Open();
            using (var cmd = new SqlCommand(
                "SELECT FileName, CaseID FROM scan.ScanDocument WHERE DocID=@d;", cn))
            {
                cmd.Parameters.AddWithValue("@d", docId);
                using (var r = cmd.ExecuteReader())
                {
                    if (r.Read())
                    {
                        fileName = (string)r["FileName"];
                        caseId = (int)r["CaseID"];
                    }
                }
            }

            if (fileName == null)
            {
                litFrame.Text = "<div class=\"err\">Document not found.</div>";
                return;
            }

            // Audit the view
            using (var cmd = new SqlCommand(
                "INSERT INTO scan.ScanAudit (UserName, Action, CaseID, DocID, Detail, ClientIP) " +
                "VALUES (@u,'VIEW',@c,@d,@det,@ip);", cn))
            {
                cmd.Parameters.AddWithValue("@u",
                    (User != null && User.Identity != null && !string.IsNullOrEmpty(User.Identity.Name))
                        ? User.Identity.Name : "(unknown)");
                cmd.Parameters.AddWithValue("@c", (object)caseId ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@d", docId);
                cmd.Parameters.AddWithValue("@det", fileName);
                cmd.Parameters.AddWithValue("@ip", Request.UserHostAddress ?? "");
                cmd.ExecuteNonQuery();
            }
        }

        litTitle.Text = Server.HtmlEncode(fileName);
        litName.Text = Server.HtmlEncode(fileName);

        // pdf.js viewer pointed at the secure stream handler.
        // The PDF is delivered via Stream.ashx (never a raw UNC path to the client).
        // Path style (Stream.ashx/{id}.pdf) so pdf.js v4 treats it as a .pdf
        // file, and ROOT-RELATIVE (leading /) rather than an absolute URL so
        // the viewer's same-origin check passes. Absolute http URLs trip the
        // "file origin does not match viewer" guard and load 0 pages.
        string appRoot = Request.ApplicationPath.TrimEnd('/');
        string streamPath = appRoot + "/Stream.ashx/" + docId + ".pdf";
        string viewerUrl = "pdfjs/web/viewer.html?file=" +
            Server.UrlEncode(streamPath);

        litFrame.Text = "<iframe src=\"" + viewerUrl + "\"></iframe>";
    }
}
