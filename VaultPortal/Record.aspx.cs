using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Text;
using System.Web.UI;
using System.Web.UI.HtmlControls;
using System.Web.UI.WebControls;

namespace VaultPortal
{
    public partial class RecordPage : Page
    {
        // ---- column maps: one place defines every editable field ----
        private static readonly string[] TextCols =
        {
            "FamilyName", "FamilyNameAlt", "FileNumber", "FileType",
            "RecallBoxBarCode", "PermPaperBoxNumber", "PermPaperLocation",
            "PermPaperLocationOld", "PermPaperSignedOutTo",
            "PermPaperSignedOutToEmail", "PermPaperSignedOutToOld",
            "AudioBarCode", "AudioLocation", "AudioSignedOutTo",
            "AudioSignedOutToEmail", "AudioSignedOutToOld",
            "VideoBarCode", "VideoLocation", "VideoSignedOutTo",
            "VideoSignedOutToEmail", "VideoSignedOutToOld",
            "CdDvdBarCode", "CdDvdLocation", "CdDvdSignedOutTo",
            "CdDvdSignedOutToEmail", "CdDvdSignedOutToOld",
            "MicroficheBarCode", "MicroficheLocation", "MicroficheSignedOutTo",
            "MicroficheSignedOutToEmail", "MicroficheSignedOutToOld",
            "WorkingFileAssignedTo", "WorkingFileAssignedToEmail",
            "WorkingFileAssignedToOld",
            "WF2Type", "WF2SignedOutTo", "WF2SignedOutToEmail", "WF2SignedOutToOld",
            "WF3Type", "WF3SignedOutTo", "WF3SignedOutToEmail", "WF3SignedOutToOld",
            "Comments", "AdditionalComments"
        };

        private static readonly string[] DateCols =
        {
            "StartDate", "EndDate",
            "PermPaperSignedOutDate", "AudioSignedOutDate", "VideoSignedOutDate",
            "CdDvdSignedOutDate", "MicroficheSignedOutDate",
            "WorkingFileAssignedDate", "WF2SignedOutDate", "WF3SignedOutDate"
        };

        private static readonly string[] BoolCols =
        {
            "PermPaperFile", "AudioTape", "VideoTape", "CdDvd", "Microfiche",
            "WorkingFileCreated", "WF2Created", "WF3Created"
        };

        // read-only provenance (displayed, never saved)
        private static readonly string[] ProvCols =
        {
            "CreatedInSharePoint", "CreatedBy", "ModifiedInSharePoint",
            "ModifiedBy", "ModifiedOldVdb"
        };

        private bool IsEditor { get { return Db.IsEditor(Context); } }

        private int RecordId
        {
            get
            {
                int id;
                return int.TryParse(Request.QueryString["id"], out id) ? id : 0;
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (RecordId == 0) { Response.Redirect("Default.aspx"); return; }

            if (!IsEditor)
            {
                btnSave.Visible = false;
                roHint.Visible = true;
            }

            if (!IsPostBack)
            {
                pnlSaved.Visible = Request.QueryString["saved"] == "1";
                LoadRecord();
                Db.Audit(Context, "View", RecordId, null);
            }
        }

        // ---------- control lookup ----------
        private TextBox Txt(string col) { return (TextBox)Find(this, "f_" + col); }
        private CheckBox Chk(string col) { return (CheckBox)Find(this, "c_" + col); }

        private static Control Find(Control root, string id)
        {
            var c = root.FindControl(id);
            if (c != null) return c;
            foreach (Control child in root.Controls)
            {
                c = Find(child, id);
                if (c != null) return c;
            }
            return null;
        }

        // ---------- load ----------
        private void LoadRecord()
        {
            using (var conn = Db.Open())
            using (var cmd = new SqlCommand(
                "SELECT * FROM dbo.VaultRecord WHERE SPListItemID=@Id", conn))
            {
                cmd.Parameters.AddWithValue("@Id", RecordId);
                using (var rdr = cmd.ExecuteReader())
                {
                    if (!rdr.Read()) { Response.Redirect("Default.aspx"); return; }

                    foreach (var col in TextCols)
                        Txt(col).Text = rdr[col] == DBNull.Value ? "" : rdr[col].ToString();

                    foreach (var col in DateCols)
                        Txt(col).Text = rdr[col] == DBNull.Value
                            ? "" : ((DateTime)rdr[col]).ToString("yyyy-MM-dd");

                    foreach (var col in BoolCols)
                        Chk(col).Checked = rdr[col] != DBNull.Value && (bool)rdr[col];

                    foreach (var col in ProvCols)
                    {
                        var t = Txt(col);
                        t.Text = rdr[col] == DBNull.Value ? ""
                            : (rdr[col] is DateTime
                                ? ((DateTime)rdr[col]).ToString("yyyy-MM-dd HH:mm")
                                : rdr[col].ToString());
                        t.Enabled = false;
                    }

                    // header
                    var name = rdr["FamilyName"].ToString();
                    var alt = rdr["FamilyNameAlt"].ToString();
                    litName.Text = Server.HtmlEncode(
                        string.IsNullOrEmpty(name) ? "(no family name)" : name);
                    litSub.Text = Server.HtmlEncode(
                        (string.IsNullOrEmpty(alt) ? "" : "Alt. name: " + alt + "  ·  ")
                        + rdr["FileType"]);
                    litFileNo.Text = Server.HtmlEncode(rdr["FileNumber"].ToString());

                    var outWhat = OutList(rdr);
                    litStamp.Text = outWhat.Count > 0
                        ? "<span class='stamp stamp-out' title='" +
                          Server.HtmlEncode(string.Join(", ", outWhat)) + "'>SIGNED OUT</span>"
                        : "<span class='stamp stamp-in'>IN VAULT</span>";

                    // auto-open the sections that actually apply
                    Open(secIdentity);
                    Open(secComments);
                    if (B(rdr, "PermPaperFile")) Open(secPaper);
                    if (B(rdr, "AudioTape")) Open(secAudio);
                    if (B(rdr, "VideoTape")) Open(secVideo);
                    if (B(rdr, "CdDvd")) Open(secCd);
                    if (B(rdr, "Microfiche")) Open(secFiche);
                    if (B(rdr, "WorkingFileCreated")) Open(secWF);
                    if (B(rdr, "WF2Created")) Open(secWF2);
                    if (B(rdr, "WF3Created")) Open(secWF3);
                }
            }

            if (!IsEditor)
            {
                foreach (var col in TextCols) Txt(col).Enabled = false;
                foreach (var col in DateCols) Txt(col).Enabled = false;
                foreach (var col in BoolCols) Chk(col).Enabled = false;
            }
        }

        private static bool B(SqlDataReader rdr, string col)
        {
            return rdr[col] != DBNull.Value && (bool)rdr[col];
        }

        private static void Open(HtmlGenericControl sec)
        {
            sec.Attributes["class"] = "section open";
        }

        private static List<string> OutList(SqlDataReader rdr)
        {
            var pairs = new[]
            {
                new[] { "PermPaperSignedOutTo", "paper file" },
                new[] { "AudioSignedOutTo", "audio" },
                new[] { "VideoSignedOutTo", "video" },
                new[] { "CdDvdSignedOutTo", "CD/DVD" },
                new[] { "MicroficheSignedOutTo", "microfiche" },
                new[] { "WorkingFileAssignedTo", "working file" },
                new[] { "WF2SignedOutTo", "WF2" },
                new[] { "WF3SignedOutTo", "WF3" }
            };
            var outWhat = new List<string>();
            foreach (var p in pairs)
            {
                var v = rdr[p[0]] == DBNull.Value ? "" : rdr[p[0]].ToString().Trim();
                if (v.Length > 0) outWhat.Add(p[1] + ": " + v);
            }
            return outWhat;
        }

        // ---------- save ----------
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (!IsEditor)
            {
                litError.Text = "You do not have edit access to the register.";
                pnlError.Visible = true;
                return;
            }

            // validate dates before touching the database
            foreach (var col in DateCols)
            {
                var t = Txt(col).Text;
                DateTime d;
                if (!string.IsNullOrWhiteSpace(t) && !DateTime.TryParse(t.Trim(), out d))
                {
                    litError.Text = "\"" + Server.HtmlEncode(t) +
                        "\" is not a valid date (use yyyy-mm-dd). Nothing was saved.";
                    pnlError.Visible = true;
                    return;
                }
            }

            // read the current row so the audit log records before -> after
            var before = new Dictionary<string, string>();
            using (var conn = Db.Open())
            using (var cmd = new SqlCommand(
                "SELECT * FROM dbo.VaultRecord WHERE SPListItemID=@Id", conn))
            {
                cmd.Parameters.AddWithValue("@Id", RecordId);
                using (var rdr = cmd.ExecuteReader())
                {
                    if (!rdr.Read())
                    {
                        litError.Text = "Record no longer exists.";
                        pnlError.Visible = true;
                        return;
                    }
                    foreach (var col in TextCols)
                        before[col] = rdr[col] == DBNull.Value ? "" : rdr[col].ToString().Trim();
                    foreach (var col in DateCols)
                        before[col] = rdr[col] == DBNull.Value
                            ? "" : ((DateTime)rdr[col]).ToString("yyyy-MM-dd");
                    foreach (var col in BoolCols)
                        before[col] = B2(rdr[col]) ? "1" : "0";
                }
            }

            // build the diff + UPDATE
            var diff = new StringBuilder();
            var sets = new List<string>();
            var ps = new List<SqlParameter>();
            int i = 0;

            foreach (var col in TextCols)
            {
                var nv = (Txt(col).Text ?? "").Trim();
                if (nv != before[col]) AddDiff(diff, col, before[col], nv);
                sets.Add(col + "=@p" + i);
                ps.Add(new SqlParameter("@p" + i, Db.TextOrNull(nv)));
                i++;
            }
            foreach (var col in DateCols)
            {
                var raw = (Txt(col).Text ?? "").Trim();
                var nv = raw.Length == 0 ? "" : DateTime.Parse(raw).ToString("yyyy-MM-dd");
                if (nv != before[col]) AddDiff(diff, col, before[col], nv);
                sets.Add(col + "=@p" + i);
                ps.Add(new SqlParameter("@p" + i, Db.DateOrNull(raw)));
                i++;
            }
            foreach (var col in BoolCols)
            {
                var nv = Chk(col).Checked ? "1" : "0";
                if (nv != before[col]) AddDiff(diff, col, before[col], nv);
                sets.Add(col + "=@p" + i);
                ps.Add(new SqlParameter("@p" + i, Chk(col).Checked));
                i++;
            }

            if (diff.Length == 0)
            {
                // nothing changed - do not write, do not log an empty edit
                Response.Redirect("Record.aspx?id=" + RecordId);
                return;
            }

            using (var conn = Db.Open())
            using (var cmd = new SqlCommand(
                "UPDATE dbo.VaultRecord SET " + string.Join(", ", sets) +
                " WHERE SPListItemID=@Id", conn))
            {
                cmd.Parameters.AddWithValue("@Id", RecordId);
                cmd.Parameters.AddRange(ps.ToArray());
                cmd.ExecuteNonQuery();
            }

            Db.Audit(Context, "Edit", RecordId, diff.ToString());
            Response.Redirect("Record.aspx?id=" + RecordId + "&saved=1");
        }

        private static bool B2(object o) { return o != DBNull.Value && (bool)o; }

        private static void AddDiff(StringBuilder sb, string col, string oldV, string newV)
        {
            if (sb.Length > 0) sb.Append(" | ");
            sb.Append(col).Append(": \"")
              .Append(Db.Truncate(oldV, 120)).Append("\" -> \"")
              .Append(Db.Truncate(newV, 120)).Append("\"");
        }
    }
}
