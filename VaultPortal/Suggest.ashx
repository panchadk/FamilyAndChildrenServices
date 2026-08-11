<%@ WebHandler Language="C#" Class="VaultPortal.Suggest" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Text;
using System.Web;

namespace VaultPortal
{
    /// <summary>
    /// GET Suggest.ashx?q=prefix  ->  JSON array of
    /// {"v":"2825A","t":"num"} / {"v":"BELTMAN","t":"name"} suggestions.
    /// </summary>
    public class Suggest : IHttpHandler
    {
        public void ProcessRequest(HttpContext ctx)
        {
            ctx.Response.ContentType = "application/json";
            var q = (ctx.Request.QueryString["q"] ?? "").Trim();
            var items = new List<string[]>();

            if (q.Length >= 1)
            {
                using (var conn = Db.Open())
                using (var cmd = new SqlCommand(@"
                    SELECT TOP 10 'num' AS T, FileNumber AS V
                    FROM dbo.VaultRecord
                    WHERE FileNumber LIKE @Q + '%'
                    GROUP BY FileNumber
                    UNION ALL
                    SELECT TOP 10 'name' AS T, FamilyName AS V
                    FROM dbo.VaultRecord
                    WHERE FamilyName LIKE @Q + '%'
                    GROUP BY FamilyName
                    ORDER BY T DESC, V;", conn))
                {
                    cmd.Parameters.AddWithValue("@Q", q);
                    using (var rdr = cmd.ExecuteReader())
                        while (rdr.Read())
                            items.Add(new[] { rdr["T"].ToString(), rdr["V"].ToString() });
                }
            }

            var sb = new StringBuilder("[");
            for (int i = 0; i < items.Count; i++)
            {
                if (i > 0) sb.Append(",");
                sb.Append("{\"t\":\"").Append(J(items[i][0]))
                  .Append("\",\"v\":\"").Append(J(items[i][1])).Append("\"}");
            }
            sb.Append("]");
            ctx.Response.Write(sb.ToString());
        }

        private static string J(string s)
        {
            return (s ?? "")
                .Replace("\\", "\\\\").Replace("\"", "\\\"")
                .Replace("\r", " ").Replace("\n", " ");
        }

        public bool IsReusable { get { return true; } }
    }
}
