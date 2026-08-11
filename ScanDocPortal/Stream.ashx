<%@ WebHandler Language="C#" Class="ScanDoc_Stream" %>

using System;
using System.IO;
using System.Data.SqlClient;
using System.Web;
using System.Web.Configuration;

public class ScanDoc_Stream : IHttpHandler
{
    private static string ConnStr
    {
        get { return WebConfigurationManager.ConnectionStrings["ScanArchive"].ConnectionString; }
    }

    public void ProcessRequest(HttpContext context)
    {
        int docId;

        // Accept either path style (Stream.ashx/873.pdf) or query (?doc=873).
        // pdf.js v4 needs a .pdf-looking path, so PathInfo is the primary route.
        string fromPath = context.Request.PathInfo;   // e.g. "/873.pdf"
        bool parsed = false;
        if (!string.IsNullOrEmpty(fromPath))
        {
            string seg = fromPath.Trim('/');           // "873.pdf"
            int dot = seg.IndexOf('.');
            if (dot > 0) seg = seg.Substring(0, dot);  // "873"
            parsed = int.TryParse(seg, out docId);
        }
        else
        {
            docId = 0;
        }

        if (!parsed && !int.TryParse(context.Request.QueryString["doc"], out docId))
        {
            context.Response.StatusCode = 400;
            context.Response.Write("Bad request");
            return;
        }

        string relPath = null;
        string fileName = null;
        string shareRoot = null;

        using (var cn = new SqlConnection(ConnStr))
        {
            cn.Open();

            // Resolve the share root from config (single row).
            using (var cfg = new SqlCommand(
                "SELECT TOP 1 ShareRoot FROM scan.ScanConfig ORDER BY ConfigID DESC;", cn))
            {
                var o = cfg.ExecuteScalar();
                shareRoot = o == null ? null : o.ToString();
            }

            using (var cmd = new SqlCommand(
                "SELECT RelativePath, FileName FROM scan.ScanDocument WHERE DocID=@d;", cn))
            {
                cmd.Parameters.AddWithValue("@d", docId);
                using (var r = cmd.ExecuteReader())
                {
                    if (r.Read())
                    {
                        relPath = (string)r["RelativePath"];
                        fileName = (string)r["FileName"];
                    }
                }
            }
        }

        if (relPath == null || shareRoot == null)
        {
            context.Response.StatusCode = 404;
            context.Response.Write("Not found");
            return;
        }

        // Build the UNC path server-side. The client never sees it.
        string fullPath = Path.Combine(shareRoot, relPath);

        // Guard against traversal: resolved path must stay under shareRoot.
        string rootFull = Path.GetFullPath(shareRoot);
        string resolved = Path.GetFullPath(fullPath);
        if (!resolved.StartsWith(rootFull, StringComparison.OrdinalIgnoreCase))
        {
            context.Response.StatusCode = 403;
            context.Response.Write("Forbidden");
            return;
        }

        if (!File.Exists(resolved))
        {
            context.Response.StatusCode = 404;
            context.Response.Write("File missing on share");
            return;
        }

        context.Response.Clear();
        context.Response.ContentType = "application/pdf";
        context.Response.AddHeader("Content-Disposition",
            "inline; filename=\"" + fileName.Replace("\"", "") + "\"");
        context.Response.TransmitFile(resolved);
        context.Response.Flush();
    }

    public bool IsReusable { get { return false; } }
}
