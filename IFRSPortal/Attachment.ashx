<%@ WebHandler Language="C#" Class="AttachmentHandler" %>
using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;

public class AttachmentHandler : IHttpHandler
{
    public void ProcessRequest(HttpContext ctx)
    {
        int id;
        if (!int.TryParse(ctx.Request.QueryString["id"], out id)) { ctx.Response.StatusCode = 400; return; }
        bool inline = (ctx.Request.QueryString["mode"] == "inline");

        DataTable dt = Portal.Query(
            "SELECT FileName, RelativePath, UNID FROM dbo.NSF_Attachments WHERE AttachmentId = @id",
            new SqlParameter("@id", id));
        if (dt.Rows.Count == 0) { ctx.Response.StatusCode = 404; return; }

        string fileName = Convert.ToString(dt.Rows[0]["FileName"]);
        string rel      = Convert.ToString(dt.Rows[0]["RelativePath"]);
        string unid     = Convert.ToString(dt.Rows[0]["UNID"]);

        string basePath = ConfigurationManager.AppSettings["AttachmentsBase"];
        string full = Path.GetFullPath(Path.Combine(basePath, rel));
        // Path traversal guard: resolved path must stay under the base
        if (!full.StartsWith(Path.GetFullPath(basePath), StringComparison.OrdinalIgnoreCase))
        { ctx.Response.StatusCode = 403; return; }
        if (!File.Exists(full)) { ctx.Response.StatusCode = 404; return; }

        Portal.Audit("AttachmentView", null, unid, fileName + (inline ? " (view)" : " (download)"));

        string ext = Path.GetExtension(fileName).ToLowerInvariant();
        string mime;
        switch (ext)
        {
            case ".pdf":  mime = "application/pdf"; break;
            case ".jpg": case ".jpeg": mime = "image/jpeg"; break;
            case ".png":  mime = "image/png"; break;
            case ".gif":  mime = "image/gif"; break;
            case ".txt":  mime = "text/plain"; break;
            default: mime = "application/octet-stream"; inline = false; break;
        }

        ctx.Response.ContentType = mime;
        ctx.Response.AppendHeader("Content-Disposition",
            (inline ? "inline" : "attachment") + "; filename=\"" + fileName.Replace("\"", "") + "\"");
        ctx.Response.AppendHeader("X-Content-Type-Options", "nosniff");
        ctx.Response.TransmitFile(full);
    }
    public bool IsReusable { get { return true; } }
}
