using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web;

/// <summary>Shared helpers for the LANFAM Archive Portal.</summary>
public static class Db
{
    public static SqlConnection Open()
    {
        var cn = new SqlConnection(
            ConfigurationManager.ConnectionStrings["Lanfam"].ConnectionString);
        cn.Open();
        return cn;
    }

    /// <summary>True if the current user may use the portal at all.</summary>
    public static bool CanRead(HttpContext ctx)
    {
        if (string.Equals(ConfigurationManager.AppSettings["AllowAllAuthenticated"],
                          "true", StringComparison.OrdinalIgnoreCase))
            return ctx.User != null && ctx.User.Identity.IsAuthenticated;
        string grp = ConfigurationManager.AppSettings["ReadersGroup"];
        return ctx.User != null && ctx.User.IsInRole(grp);
    }

    /// <summary>True if the current user may see adoption records.</summary>
    public static bool CanReadAdoption(HttpContext ctx)
    {
        string grp = ConfigurationManager.AppSettings["AdoptionGroup"];
        return ctx.User != null && ctx.User.IsInRole(grp);
    }

    /// <summary>Write one audit row. Never throws (auditing must not break pages).</summary>
    public static void Audit(HttpContext ctx, string action, string detail)
    {
        try
        {
            using (var cn = Open())
            using (var cmd = new SqlCommand(
                "INSERT INTO lanfam.AccessLog (LoginName, ClientIP, Action, Detail) " +
                "VALUES (@u, @ip, @a, @d)", cn))
            {
                cmd.Parameters.AddWithValue("@u",
                    (object)(ctx.User != null ? ctx.User.Identity.Name : null)
                    ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ip",
                    (object)ctx.Request.UserHostAddress ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@a", action);
                cmd.Parameters.AddWithValue("@d",
                    (object)(detail != null && detail.Length > 400
                             ? detail.Substring(0, 400) : detail) ?? DBNull.Value);
                cmd.ExecuteNonQuery();
            }
        }
        catch { /* auditing is best-effort */ }
    }

    private static Dictionary<string, string> _codes;
    private static readonly object _lock = new object();

    /// <summary>Decode a LANFAM code to its description (cached).</summary>
    public static string Decode(string category, string code)
    {
        if (string.IsNullOrEmpty(code)) return "";
        if (_codes == null)
        {
            lock (_lock)
            {
                if (_codes == null)
                {
                    var d = new Dictionary<string, string>(
                        StringComparer.OrdinalIgnoreCase);
                    using (var cn = Open())
                    using (var cmd = new SqlCommand(
                        "SELECT category, code, MIN(description) " +
                        "FROM lanfam.Codes GROUP BY category, code", cn))
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                            d[r.GetString(0) + "|" + r.GetString(1)] =
                                r.IsDBNull(2) ? "" : r.GetString(2);
                    _codes = d;
                }
            }
        }
        string v;
        return _codes.TryGetValue((category ?? "") + "|" + code, out v)
            ? v + " (" + code + ")" : code;
    }

    public static string H(object o)   // HTML-encode helper
    {
        return o == null || o == DBNull.Value
            ? "" : HttpUtility.HtmlEncode(o.ToString());
    }

    public static string D(object o)   // date display helper
    {
        if (o == null || o == DBNull.Value) return "";
        var dt = o as DateTime?;
        return dt.HasValue ? dt.Value.ToString("yyyy-MM-dd") : o.ToString();
    }
}
