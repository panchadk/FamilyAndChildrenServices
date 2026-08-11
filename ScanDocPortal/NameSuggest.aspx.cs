using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.Web.Configuration;
using System.Web.UI;

public partial class ScanDoc_NameSuggest : Page
{
    private static string ConnStr
    {
        get { return WebConfigurationManager.ConnectionStrings["ScanArchive"].ConnectionString; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        Response.ContentType = "application/json";
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);

        string q = (Request.QueryString["q"] ?? "").Trim();
        string category = (Request.QueryString["cat"] ?? "").Trim();

        // 2-char minimum, same as LANFAM.
        if (q.Length < 2)
        {
            Response.Write("[]");
            Response.End();
            return;
        }

        // Split "smith, john" or "smith john" into surname + given parts so
        // the suggestions narrow as the user types the second word.
        string last, first;
        SplitTerm(q, out last, out first);

        var sb = new StringBuilder("[");
        int n = 0;

        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand())
        {
            var sql = new StringBuilder(
                "SELECT TOP 15 LastName, FirstName, COUNT(*) AS Cnt " +
                "FROM scan.ScanCase " +
                "WHERE LastName IS NOT NULL ");

            if (last.Length > 0)
            {
                sql.Append("AND LastName LIKE @last ");
                cmd.Parameters.AddWithValue("@last", last + "%");
            }
            if (first.Length > 0)
            {
                sql.Append("AND FirstName LIKE @first ");
                cmd.Parameters.AddWithValue("@first", first + "%");
            }
            if (category.Length > 0)
            {
                sql.Append("AND Category = @cat ");
                cmd.Parameters.AddWithValue("@cat", category);
            }
            sql.Append("GROUP BY LastName, FirstName ");
            sql.Append("ORDER BY LastName, FirstName;");

            cmd.CommandText = sql.ToString();
            cmd.Connection = cn;
            cn.Open();

            using (var r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    string ln = r["LastName"] == DBNull.Value ? "" : (string)r["LastName"];
                    string fn = r["FirstName"] == DBNull.Value ? "" : (string)r["FirstName"];
                    int cnt = (int)r["Cnt"];

                    string display = (ln + ", " + fn).Trim().TrimEnd(',');
                    string label = display + " (" + cnt + (cnt == 1 ? " case)" : " cases)");
                    string value = display;

                    if (n > 0) sb.Append(",");
                    sb.Append("{\"label\":\"").Append(JsonEscape(label))
                      .Append("\",\"value\":\"").Append(JsonEscape(value))
                      .Append("\"}");
                    n++;
                }
            }
        }

        sb.Append("]");
        Response.Write(sb.ToString());
        Response.End();
    }

    private void SplitTerm(string q, out string last, out string first)
    {
        last = q;
        first = "";
        int comma = q.IndexOf(',');
        if (comma >= 0)
        {
            last = q.Substring(0, comma).Trim();
            first = q.Substring(comma + 1).Trim();
            return;
        }
        int sp = q.IndexOf(' ');
        if (sp >= 0)
        {
            last = q.Substring(0, sp).Trim();
            first = q.Substring(sp + 1).Trim();
        }
    }

    private string JsonEscape(string s)
    {
        if (string.IsNullOrEmpty(s)) return "";
        return s.Replace("\\", "\\\\").Replace("\"", "\\\"")
                .Replace("\r", "").Replace("\n", "");
    }
}
