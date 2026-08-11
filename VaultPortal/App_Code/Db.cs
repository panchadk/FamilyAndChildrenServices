using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Security.Principal;
using System.Web;

namespace VaultPortal
{
    /// <summary>Shared helpers for the Vault Register portal.</summary>
    public static class Db
    {
        public static string ConnString
        {
            get { return ConfigurationManager.ConnectionStrings["ArchiveDb"].ConnectionString; }
        }

        public static SqlConnection Open()
        {
            var c = new SqlConnection(ConnString);
            c.Open();
            return c;
        }

        /// <summary>True if the current user may edit records.</summary>
        public static bool IsEditor(HttpContext ctx)
        {
            var allowAll = ConfigurationManager.AppSettings["AllowAllAuthenticatedEdit"];
            if (string.Equals(allowAll, "true", StringComparison.OrdinalIgnoreCase))
                return ctx.User != null && ctx.User.Identity.IsAuthenticated;

            var grp = ConfigurationManager.AppSettings["EditorsGroup"];
            if (string.IsNullOrEmpty(grp)) return false;

            var wp = ctx.User as WindowsPrincipal;
            try { return wp != null && wp.IsInRole(grp); }
            catch { return false; }
        }

        /// <summary>
        /// Write one row to dbo.VaultAccessLog. Never throws - auditing must
        /// not take the portal down. Action: Search / View / Edit.
        /// </summary>
        public static void Audit(HttpContext ctx, string action, int? spListItemId, string detail)
        {
            try
            {
                using (var conn = Open())
                using (var cmd = new SqlCommand(@"
                    INSERT INTO dbo.VaultAccessLog
                        (LoginName, Action, SPListItemID, Detail, ClientIP)
                    VALUES (@L, @A, @Id, @D, @Ip);", conn))
                {
                    cmd.Parameters.AddWithValue("@L", ctx.User.Identity.Name ?? "");
                    cmd.Parameters.AddWithValue("@A", action ?? "");
                    cmd.Parameters.AddWithValue("@Id", (object)spListItemId ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@D",
                        (object)Truncate(detail, 4000) ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Ip",
                        (object)(ctx.Request != null ? ctx.Request.UserHostAddress : null)
                        ?? DBNull.Value);
                    cmd.ExecuteNonQuery();
                }
            }
            catch { /* swallow - see summary above */ }
        }

        public static string Truncate(string s, int max)
        {
            if (s == null) return null;
            return s.Length <= max ? s : s.Substring(0, max);
        }

        /// <summary>Trimmed text, or DBNull when empty.</summary>
        public static object TextOrNull(string s)
        {
            if (s == null) return DBNull.Value;
            s = s.Trim();
            return s.Length == 0 ? (object)DBNull.Value : s;
        }

        /// <summary>Parsed date, or DBNull when empty/invalid.</summary>
        public static object DateOrNull(string s)
        {
            DateTime d;
            if (!string.IsNullOrWhiteSpace(s) && DateTime.TryParse(s.Trim(), out d))
                return d;
            return DBNull.Value;
        }
    }
}
