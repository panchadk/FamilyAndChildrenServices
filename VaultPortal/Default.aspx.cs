using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace VaultPortal
{
    public partial class DefaultPage : Page
    {
        // Columns that "signed out" / "signed out to" searches look at.
        private static readonly string[] SignedOutToCols =
        {
            "PermPaperSignedOutTo", "AudioSignedOutTo", "VideoSignedOutTo",
            "CdDvdSignedOutTo", "MicroficheSignedOutTo",
            "WorkingFileAssignedTo", "WF2SignedOutTo", "WF3SignedOutTo"
        };

        private static readonly HashSet<string> SortWhitelist =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "FileNumber", "FamilyName", "FamilyNameAlt", "FileType",
                "StartDate", "EndDate", "SignedOutFlag"
            };

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                BindAZ();
                LoadStats();

                // Direct-link category views (e.g. Default.aspx?view=out).
                // The meta line is reconstructed in BindResults from these criteria.
                var view = Request.QueryString["view"];
                if (view == "out")          Crit("out", "1");
                else if (view == "media")   Crit("media", "1");
                else if (view == "paper")   Crit("paper", "1");
                else if (view == "working") Crit("working", "1");

                BindResults(true);
            }
        }

        // ---------- persisted search state ----------
        private Dictionary<string, string> Criteria
        {
            get
            {
                var d = ViewState["crit"] as Dictionary<string, string>;
                if (d == null) { d = new Dictionary<string, string>(); ViewState["crit"] = d; }
                return d;
            }
        }
        private void Crit(string k, string v)
        {
            if (string.IsNullOrWhiteSpace(v)) Criteria.Remove(k);
            else Criteria[k] = v.Trim();
        }
        private string SortCol
        {
            get { return (string)(ViewState["sortcol"] ?? "FamilyName"); }
            set { ViewState["sortcol"] = value; }
        }
        private bool SortDesc
        {
            get { return (bool)(ViewState["sortdesc"] ?? false); }
            set { ViewState["sortdesc"] = value; }
        }

        // ---------- stats ----------
        private void LoadStats()
        {
            var outPred = OutPredicate();
            using (var conn = Db.Open())
            using (var cmd = new SqlCommand(@"
                SELECT
                  (SELECT COUNT(*) FROM dbo.VaultRecord)                       AS Total,
                  (SELECT COUNT(*) FROM dbo.VaultRecord WHERE PermPaperFile=1) AS Paper,
                  (SELECT COUNT(*) FROM dbo.VaultRecord
                     WHERE AudioTape=1 OR VideoTape=1 OR CdDvd=1 OR Microfiche=1)  AS Media,
                  (SELECT COUNT(*) FROM dbo.VaultRecord
                     WHERE WorkingFileCreated=1 OR WF2Created=1 OR WF3Created=1)   AS Working,
                  (SELECT COUNT(*) FROM dbo.VaultRecord WHERE " + outPred + @") AS OutNow;", conn))
            {
                using (var rdr = cmd.ExecuteReader())
                {
                    if (rdr.Read())
                    {
                        litTotal.Text   = string.Format("{0:n0}", rdr["Total"]);
                        litPaper.Text   = string.Format("{0:n0}", rdr["Paper"]);
                        litMedia.Text   = string.Format("{0:n0}", rdr["Media"]);
                        litWorking.Text = string.Format("{0:n0}", rdr["Working"]);
                        litOut.Text     = string.Format("{0:n0}", rdr["OutNow"]);
                    }
                }
            }
        }

        private static string OutPredicate()
        {
            var parts = new List<string>();
            foreach (var c in SignedOutToCols)
                parts.Add("NULLIF(LTRIM(RTRIM(" + c + ")), '') IS NOT NULL");
            return "(" + string.Join(" OR ", parts) + ")";
        }

        // ---------- stat tiles (clickable category filters) ----------
        protected void Tile_Command(object sender, CommandEventArgs e)
        {
            Criteria.Clear();
            txtQuick.Text = txtFamilyName.Text = txtFileNumber.Text =
                txtFileType.Text = txtSignedOutTo.Text = txtKeyword.Text = "";
            gvResults.PageIndex = 0;

            // Set only the filter criterion; the descriptive meta line is
            // reconstructed from these criteria inside BindResults, so it stays
            // correct through subsequent sorting and paging. "all" sets nothing.
            switch (e.CommandName)
            {
                case "paper":   Crit("paper", "1");   break;
                case "media":   Crit("media", "1");   break;
                case "working": Crit("working", "1"); break;
                case "out":     Crit("out", "1");     break;
                case "all":
                default:        /* no criteria -> all holdings */ break;
            }
            BindResults(true);
        }

        // ---------- A-Z ----------
        private void BindAZ()
        {
            var letters = new List<string>();
            for (char c = 'A'; c <= 'Z'; c++) letters.Add(c.ToString());
            rptAZ.DataSource = letters;
            rptAZ.DataBind();
        }

        protected void rptAZ_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "Letter") return;
            Criteria.Clear();
            Crit("letter", e.CommandArgument.ToString());
            gvResults.PageIndex = 0;
            BindResults(true);
        }

        // ---------- searches ----------
        protected void btnQuickGo_Click(object sender, EventArgs e)
        {
            Criteria.Clear();
            Crit("quick", txtQuick.Text);
            gvResults.PageIndex = 0;
            BindResults(true);
        }

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            Criteria.Clear();
            Crit("name",    txtFamilyName.Text);
            Crit("fileno",  txtFileNumber.Text);
            Crit("type",    txtFileType.Text);
            Crit("outto",   txtSignedOutTo.Text);
            Crit("keyword", txtKeyword.Text);
            gvResults.PageIndex = 0;
            BindResults(true);
        }

        protected void btnClear_Click(object sender, EventArgs e)
        {
            Criteria.Clear();
            txtQuick.Text = txtFamilyName.Text = txtFileNumber.Text =
                txtFileType.Text = txtSignedOutTo.Text = txtKeyword.Text = "";
            gvResults.PageIndex = 0;
            litResultMeta.Text = "";
            BindResults(false);
        }

        protected void gvResults_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            gvResults.PageIndex = e.NewPageIndex;
            BindResults(false);   // keeps the current search - fixes the old paging bug
        }

        protected void gvResults_Sorting(object sender, GridViewSortEventArgs e)
        {
            if (!SortWhitelist.Contains(e.SortExpression)) return;
            if (string.Equals(SortCol, e.SortExpression, StringComparison.OrdinalIgnoreCase))
                SortDesc = !SortDesc;
            else { SortCol = e.SortExpression; SortDesc = false; }
            gvResults.PageIndex = 0;
            BindResults(false);
        }

        // ---------- the query ----------
        private void BindResults(bool logIt)
        {
            using (var conn = Db.Open())
            using (var cmd = new SqlCommand())
            {
                cmd.Connection = conn;

                var sql = @"
                    SELECT TOP 500
                        SPListItemID, FamilyName, FamilyNameAlt, FileNumber,
                        FileType, StartDate, EndDate,
                        CONCAT(
                            CASE WHEN PermPaperFile = 1 THEN 'P' ELSE '' END,
                            CASE WHEN AudioTape     = 1 THEN 'A' ELSE '' END,
                            CASE WHEN VideoTape     = 1 THEN 'V' ELSE '' END,
                            CASE WHEN CdDvd         = 1 THEN 'C' ELSE '' END,
                            CASE WHEN Microfiche    = 1 THEN 'M' ELSE '' END,
                            CASE WHEN WorkingFileCreated = 1 THEN 'W' ELSE '' END
                        ) AS MediaFlags,
                        CASE WHEN " + OutPredicate() + @" THEN 1 ELSE 0 END AS SignedOutFlag
                    FROM dbo.VaultRecord
                    WHERE 1=1";

                string v;
                var c = Criteria;

                if (c.TryGetValue("letter", out v))
                {
                    sql += " AND FamilyName LIKE @Letter + '%'";
                    cmd.Parameters.AddWithValue("@Letter", v);
                }
                if (c.TryGetValue("quick", out v))
                {
                    sql += @" AND (FileNumber LIKE @Q + '%'
                               OR FamilyName LIKE @Q + '%'
                               OR FamilyNameAlt LIKE @Q + '%'
                               OR Comments LIKE '%' + @Q + '%'
                               OR AdditionalComments LIKE '%' + @Q + '%')";
                    cmd.Parameters.AddWithValue("@Q", v);
                }
                if (c.TryGetValue("name", out v))
                {
                    sql += " AND (FamilyName LIKE @N + '%' OR FamilyNameAlt LIKE @N + '%')";
                    cmd.Parameters.AddWithValue("@N", v);
                }
                if (c.TryGetValue("fileno", out v))
                {
                    sql += " AND FileNumber LIKE @F + '%'";
                    cmd.Parameters.AddWithValue("@F", v);
                }
                if (c.TryGetValue("type", out v))
                {
                    sql += " AND FileType LIKE @T + '%'";
                    cmd.Parameters.AddWithValue("@T", v);
                }
                if (c.TryGetValue("outto", out v))
                {
                    var parts = new List<string>();
                    foreach (var col in SignedOutToCols)
                        parts.Add(col + " LIKE @O + '%'");
                    sql += " AND (" + string.Join(" OR ", parts) + ")";
                    cmd.Parameters.AddWithValue("@O", v);
                }
                if (c.TryGetValue("keyword", out v))
                {
                    sql += " AND (Comments LIKE '%' + @K + '%' OR AdditionalComments LIKE '%' + @K + '%')";
                    cmd.Parameters.AddWithValue("@K", v);
                }
                if (c.ContainsKey("out"))
                    sql += " AND " + OutPredicate();
                if (c.ContainsKey("media"))
                    sql += " AND (AudioTape=1 OR VideoTape=1 OR CdDvd=1 OR Microfiche=1)";
                if (c.ContainsKey("paper"))
                    sql += " AND PermPaperFile = 1";
                if (c.ContainsKey("working"))
                    sql += " AND (WorkingFileCreated=1 OR WF2Created=1 OR WF3Created=1)";

                var sortBy = SortWhitelist.Contains(SortCol) ? SortCol : "FamilyName";
                sql += " ORDER BY " + sortBy + (SortDesc ? " DESC" : " ASC");
                if (!sortBy.Equals("FamilyName", StringComparison.OrdinalIgnoreCase))
                    sql += ", FamilyName";
                if (!sortBy.Equals("FileNumber", StringComparison.OrdinalIgnoreCase))
                    sql += ", FileNumber";

                cmd.CommandText = sql;

                var dt = new DataTable();
                using (var da = new SqlDataAdapter(cmd))
                    da.Fill(dt);

                gvResults.DataSource = dt;
                gvResults.DataBind();

                // Build the result-meta line. Category views (from the stat tiles)
                // get a descriptive prefix reconstructed from the criteria itself,
                // so it survives sorting and paging (which re-run BindResults).
                string prefix = null;
                if (c.ContainsKey("out"))     prefix = "Showing holdings currently signed out.";
                else if (c.ContainsKey("media"))   prefix = "Showing holdings with audio, video, disc, or microfiche items.";
                else if (c.ContainsKey("paper"))   prefix = "Showing permanent paper files.";
                else if (c.ContainsKey("working")) prefix = "Showing holdings with a working file.";

                string countLine = string.Format(
                        "{0:n0} holding{1} (500 max shown) &mdash; sorted by {2}{3}.",
                        dt.Rows.Count, dt.Rows.Count == 1 ? "" : "s",
                        sortBy, SortDesc ? " (desc)" : "");

                if (prefix != null)
                    litResultMeta.Text = prefix + " " + countLine;
                else if (Criteria.Count > 0)
                    litResultMeta.Text = string.Format(
                        "{0:n0} holding{1} match{2} (500 max shown) &mdash; sorted by {3}{4}.",
                        dt.Rows.Count, dt.Rows.Count == 1 ? "" : "s",
                        dt.Rows.Count == 1 ? "es" : "", sortBy, SortDesc ? " (desc)" : "");
                else if (dt.Rows.Count > 0)
                    litResultMeta.Text = "Showing all holdings. " + countLine;
            }

            if (logIt && Criteria.Count > 0)
            {
                var bits = new List<string>();
                foreach (var kv in Criteria) bits.Add(kv.Key + "=" + kv.Value);
                Db.Audit(Context, "Search", null, string.Join("; ", bits));
            }
        }
    }
}
