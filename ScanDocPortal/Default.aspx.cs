using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.Web.Configuration;
using System.Web.UI;
using System.Web.UI.WebControls;

public partial class ScanDoc_Default : Page
{
    private static string ConnStr
    {
        get { return WebConfigurationManager.ConnectionStrings["ScanArchive"].ConnectionString; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            LoadStats();
            LoadCategoryBreakdown();
            LoadDocTypeBreakdown();
            BuildAZStrip();

            // Deep link: Default.aspx?az=C runs a surname-prefix browse.
            string az = (Request.QueryString["az"] ?? "").Trim();
            if (az.Length == 1 && char.IsLetter(az[0]))
                RunSearch(az, "", true);   // surnameStartsWith mode

            // Deep link: Default.aspx?ref=12001 shows all cases in that
            // base-ref family (the family record + its children).
            string refv = (Request.QueryString["ref"] ?? "").Trim();
            if (refv.Length > 0)
                RunSearchByBaseRef(refv);
        }
    }

    private void LoadStats()
    {
        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand(
            "SELECT (SELECT COUNT(*) FROM scan.ScanCase) AS Cases, " +
            "(SELECT COUNT(*) FROM scan.ScanDocument) AS Docs;", cn))
        {
            cn.Open();
            using (var r = cmd.ExecuteReader())
            {
                if (r.Read())
                {
                    litCases.Text = ((int)r["Cases"]).ToString("N0");
                    litDocs.Text = ((int)r["Docs"]).ToString("N0");
                }
            }
        }
    }

    private void LoadCategoryBreakdown()
    {
        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand(
            "SELECT Category, COUNT(*) AS Cnt FROM scan.ScanCase " +
            "GROUP BY Category;", cn))
        {
            cn.Open();
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    string cat = r["Category"] == DBNull.Value ? "" : (string)r["Category"];
                    string cnt = ((int)r["Cnt"]).ToString("N0");
                    if (cat == "Children") litChildren.Text = cnt;
                    else if (cat == "Family") litFamily.Text = cnt;
                }
            }
        }
    }

    private void LoadDocTypeBreakdown()
    {
        var dt = new DataTable();
        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand(
            // Top 6 clean doctypes only. Exclude the dirty long tail:
            // filename fragments (contain digits or underscores-with-digits),
            // stray extensions, and parenthetical notes.
            "SELECT TOP 6 DocType, COUNT(*) AS Cnt " +
            "FROM scan.ScanDocument " +
            "WHERE DocType IS NOT NULL AND DocType <> '' " +
            "  AND DocType NOT LIKE '%[0-9]%' " +   // no filename fragments w/ digits
            "  AND DocType NOT LIKE '%(%' " +        // no (FORMERLY ...) notes
            "  AND DocType NOT LIKE '.%' " +         // no .bak etc.
            "GROUP BY DocType " +
            "ORDER BY COUNT(*) DESC;", cn))
        {
            cn.Open();
            using (var da = new SqlDataAdapter(cmd))
                da.Fill(dt);
        }
        rptDocTypes.DataSource = dt;
        rptDocTypes.DataBind();
    }

    private void BuildAZStrip()
    {
        // Which first-letters actually have surnames -> active vs greyed.
        var present = new System.Collections.Generic.HashSet<char>();
        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand(
            "SELECT DISTINCT UPPER(LEFT(LastName,1)) AS L FROM scan.ScanCase " +
            "WHERE LastName IS NOT NULL AND LastName <> '';", cn))
        {
            cn.Open();
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    string l = r["L"] == DBNull.Value ? "" : (string)r["L"];
                    if (l.Length == 1 && char.IsLetter(l[0]))
                        present.Add(l[0]);
                }
            }
        }

        var sb = new StringBuilder();
        for (char c = 'A'; c <= 'Z'; c++)
        {
            if (present.Contains(c))
                sb.Append("<a href=\"Default.aspx?az=").Append(c).Append("\">")
                  .Append(c).Append("</a>");
            else
                sb.Append("<a class=\"disabled\">").Append(c).Append("</a>");
        }
        litAZ.Text = sb.ToString();
    }

    // --- category pill renderer for result rows ---
    protected string RenderCatPill(object category)
    {
        if (category == DBNull.Value || category == null) return "";
        string c = category.ToString();
        string cls = c == "Children" ? "children" : "family";
        return "<span class=\"catpill " + cls + "\">" + Server.HtmlEncode(c) + "</span>";
    }

    protected void btnSearch_Click(object sender, EventArgs e)
    {
        RunSearch((txtQuery.Text ?? "").Trim(), (ddlCategory.SelectedValue ?? "").Trim());
    }

    // Clicking either stat tile lists all cases (Documents lands on the
    // same case list, since documents live under cases). Same pattern as
    // the Vault Register clickable tiles.
    protected void tile_Click(object sender, EventArgs e)
    {
        txtQuery.Text = "";
        RunSearch("", (ddlCategory.SelectedValue ?? "").Trim());
    }

    // Category mini-tile: list all cases in that category.
    protected void miniCat_Click(object sender, EventArgs e)
    {
        var lb = (LinkButton)sender;
        string cat = lb.CommandArgument;
        ddlCategory.SelectedValue = cat;
        txtQuery.Text = "";
        RunSearch("", cat);
    }

    // Doc-type mini-tile: find all cases holding that document type.
    protected void docType_Command(object sender, CommandEventArgs e)
    {
        string dt = e.CommandArgument == null ? "" : e.CommandArgument.ToString();
        txtQuery.Text = dt;
        RunSearch(dt, "");
    }

    private void RunSearch(string q, string category)
    {
        RunSearch(q, category, false);
    }

    private void RunSearch(string q, string category, bool surnameStartsWith)
    {
        // "Search anything": one box matches case ref (full or base),
        // person name (surname / "surname, given" / "surname given"),
        // or document type. All parameterised.
        // Empty query (a stat-tile "show all" click) lifts the cap so the
        // full list shows rather than silently truncating at 500.
        int topN = (q.Length == 0) ? 5000 : 500;
        var sb = new StringBuilder(
            "SELECT DISTINCT TOP " + topN + " c.CaseID, c.CaseRef, c.Category, " +
            "c.FirstName, c.LastName, c.FolderDate, c.CaseRefBase " +
            "FROM scan.ScanCase c ");

        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand())
        {
            var where = new StringBuilder("WHERE 1=1 ");

            // A-Z browse: surname starts with the given letter, nothing else.
            if (surnameStartsWith && q.Length == 1)
            {
                where.Append("AND c.LastName LIKE @azp ");
                cmd.Parameters.AddWithValue("@azp", q + "%");
                q = "";  // skip the general predicate below
            }

            if (q.Length > 0)
            {
                // Detect a name with two parts ("clark, jason" / "clark jason")
                string namePart1 = null, namePart2 = null;
                int comma = q.IndexOf(',');
                int space = q.IndexOf(' ');
                if (comma >= 0)
                {
                    namePart1 = q.Substring(0, comma).Trim();
                    namePart2 = q.Substring(comma + 1).Trim();
                }
                else if (space >= 0)
                {
                    namePart1 = q.Substring(0, space).Trim();
                    namePart2 = q.Substring(space + 1).Trim();
                }

                // Strip alpha suffix off a ref for base matching (12043a -> 12043)
                string qBase = q.TrimEnd(
                    'a','b','c','d','e','f','g','h','i','j','k','l','m',
                    'n','o','p','q','r','s','t','u','v','w','x','y','z');

                where.Append("AND ( ");
                where.Append("c.CaseRef LIKE @q ");
                where.Append("OR c.CaseRefBase LIKE @qBase ");
                where.Append("OR c.LastName LIKE @qContains ");
                where.Append("OR c.FirstName LIKE @qContains ");
                where.Append("OR EXISTS (SELECT 1 FROM scan.ScanDocument d " +
                             "WHERE d.CaseID = c.CaseID AND d.DocType LIKE @qContains) ");
                if (namePart1 != null && namePart1.Length > 0 && namePart2 != null && namePart2.Length > 0)
                {
                    where.Append("OR (c.LastName LIKE @np1 AND c.FirstName LIKE @np2) ");
                    cmd.Parameters.AddWithValue("@np1", namePart1 + "%");
                    cmd.Parameters.AddWithValue("@np2", namePart2 + "%");
                }
                where.Append(") ");

                cmd.Parameters.AddWithValue("@q", q + "%");
                cmd.Parameters.AddWithValue("@qBase", qBase + "%");
                cmd.Parameters.AddWithValue("@qContains", "%" + q + "%");
            }

            if (category.Length > 0)
            {
                where.Append("AND c.Category = @cat ");
                cmd.Parameters.AddWithValue("@cat", category);
            }

            sb.Append(where.ToString());
            sb.Append("ORDER BY c.CaseRefBase, c.Category, c.CaseRef;");

            cmd.CommandText = sb.ToString();
            cmd.Connection = cn;

            var dt = new DataTable();
            cn.Open();
            using (var da = new SqlDataAdapter(cmd))
                da.Fill(dt);

            LogAudit(cn, "SEARCH", null, null,
                string.Format("q='{0}' cat='{1}'", q, category));

            // Any search collapses the landing sections into the result list.
            pnlLanding.Visible = false;

            if (dt.Rows.Count > 0)
            {
                rptCases.DataSource = dt;
                rptCases.DataBind();
                pnlResults.Visible = true;
                pnlEmpty.Visible = false;
            }
            else
            {
                pnlResults.Visible = false;
                pnlEmpty.Visible = true;
            }
        }
    }

    // Show every case sharing an exact base ref (family + its children),
    // e.g. 12001 -> the 12001 family record plus 12001a..d children.
    // Exact match on CaseRefBase so 12001 does not also pull 120010.
    private void RunSearchByBaseRef(string baseRef)
    {
        var sb = new StringBuilder(
            "SELECT DISTINCT TOP 500 c.CaseID, c.CaseRef, c.Category, " +
            "c.FirstName, c.LastName, c.FolderDate, c.CaseRefBase " +
            "FROM scan.ScanCase c WHERE c.CaseRefBase = @b " +
            "ORDER BY c.Category, c.CaseRef;");

        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand(sb.ToString(), cn))
        {
            cmd.Parameters.AddWithValue("@b", baseRef);
            var dt = new DataTable();
            cn.Open();
            using (var da = new SqlDataAdapter(cmd))
                da.Fill(dt);

            LogAudit(cn, "SEARCH", null, null, "baseref='" + baseRef + "'");

            pnlLanding.Visible = false;
            txtQuery.Text = baseRef;

            if (dt.Rows.Count > 0)
            {
                rptCases.DataSource = dt;
                rptCases.DataBind();
                pnlResults.Visible = true;
                pnlEmpty.Visible = false;
            }
            else
            {
                pnlResults.Visible = false;
                pnlEmpty.Visible = true;
            }
        }
    }

    // --- Build the doc-type pill links for a case (opens Viewer window) ---
    protected string BuildDocLinks(int caseId)
    {
        var sb = new StringBuilder();
        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand(
            "SELECT DocID, DocType, FileName FROM scan.ScanDocument " +
            "WHERE CaseID=@c ORDER BY DocType;", cn))
        {
            cmd.Parameters.AddWithValue("@c", caseId);
            cn.Open();
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    int docId = (int)r["DocID"];
                    string label = r["DocType"] == DBNull.Value
                        ? "master" : (string)r["DocType"];
                    string title = Server.HtmlEncode((string)r["FileName"]);
                    sb.AppendFormat(
                        "<a class=\"doclink\" href=\"Viewer.aspx?doc={0}\" " +
                        "target=\"_blank\" title=\"{2}\">" +
                        "<span class=\"pill\">{1}</span></a>",
                        docId, Server.HtmlEncode(label), title);
                }
            }
        }
        return sb.Length == 0 ? "<span class=\"pill\">(no files)</span>" : sb.ToString();
    }

    protected string FormatName(object first, object last)
    {
        string f = first == DBNull.Value || first == null ? "" : first.ToString();
        string l = last == DBNull.Value || last == null ? "" : last.ToString();
        return (f + " " + l).Trim();
    }

    protected string FormatDate(object d)
    {
        if (d == DBNull.Value || d == null) return "";
        return Convert.ToDateTime(d).ToString("yyyy-MM-dd");
    }

    private string GetUserName()
    {
        if (User != null && User.Identity != null && !string.IsNullOrEmpty(User.Identity.Name))
            return User.Identity.Name;
        return "(unknown)";
    }

    private void LogAudit(SqlConnection cn, string action, int? caseId, int? docId, string detail)
    {
        using (var cmd = new SqlCommand(
            "INSERT INTO scan.ScanAudit (UserName, Action, CaseID, DocID, Detail, ClientIP) " +
            "VALUES (@u,@a,@c,@d,@det,@ip);", cn))
        {
            cmd.Parameters.AddWithValue("@u", GetUserName());
            cmd.Parameters.AddWithValue("@a", action);
            cmd.Parameters.AddWithValue("@c", (object)caseId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@d", (object)docId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@det", (object)detail ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@ip", Request.UserHostAddress ?? "");
            cmd.ExecuteNonQuery();
        }
    }
}
