<%@ WebHandler Language="C#" Class="SuggestHandler" %>
using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.Web;

public class SuggestHandler : IHttpHandler
{
    public void ProcessRequest(HttpContext ctx)
    {
        string f = ctx.Request.QueryString["f"] ?? "";
        string q = (ctx.Request.QueryString["q"] ?? "").Trim();
        ctx.Response.ContentType = "application/json";
        if (q.Length < 2) { ctx.Response.Write("[]"); return; }

        string col;
        switch (f)
        {
            case "surname":  col = "Surname"; break;
            case "given":    col = "GivenName"; break;
            case "psurname": col = "COALESCE(NULLIF(PersonSurname,''), Surname)"; break;
            case "pgiven":   col = "COALESCE(NULLIF(PersonGiven,''), GivenName)"; break;
            default: ctx.Response.Write("[]"); return;
        }

        DataTable dt = Portal.Query(
            "SELECT DISTINCT TOP 12 " + col + " AS V FROM dbo.CaseSpine " +
            "WHERE " + col + " LIKE @q + '%' AND " + col + " <> '' ORDER BY V",
            new SqlParameter("@q", q));

        var sb = new StringBuilder("[");
        bool first = true;
        foreach (DataRow r in dt.Rows)
        {
            if (!first) sb.Append(",");
            sb.Append("\"" + Convert.ToString(r["V"]).Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"");
            first = false;
        }
        sb.Append("]");
        ctx.Response.Write(sb.ToString());
    }
    public bool IsReusable { get { return true; } }
}
