using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web;

public static class Portal
{
    public static string ConnStr {
        get { return ConfigurationManager.ConnectionStrings["IFRSArchive"].ConnectionString; }
    }

    // ---- Category mapping: form -> portal category (display order below) ----
    static readonly Dictionary<string, string> CatMap =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        {"CMForm","Case Management"}, {"CAForm","Case Management"}, {"DueDateTracking","Case Management"},
        {"Caregiver","People"}, {"Child","People"}, {"Family","People"},
        {"IntResponsible","People"}, {"Collateral","People"}, {"IntOther","People"},
        {"Referral","Referrals / Intake"}, {"IntReferral","Referrals / Intake"},
        {"IntAlleged","Referrals / Intake"}, {"IntCaregiver","Referrals / Intake"},
        {"Interview1","Interviews"}, {"Interview2","Interviews"}, {"Interview3","Interviews"},
        {"Interview4","Interviews"}, {"Interview5","Interviews"}, {"Interview61","Interviews"},
        {"Interview62","Interviews"}, {"Interview63","Interviews"},
        {"IAForm","Assessments"}, {"IAOutcome","Assessments"}, {"safetyassessment","Assessments"},
        {"CompAssessment","Assessments"}, {"RiskAssessment","Assessments"}, {"Risk30DaysUpdate","Assessments"},
        {"CaseNote","Case Notes"},
        {"CDForm","Recording (CD)"},
        {"DispositionB","Dispositions & Outcomes"}, {"DispositionC","Dispositions & Outcomes"},
        {"DispositionD","Dispositions & Outcomes"}, {"DispositionE","Dispositions & Outcomes"},
        {"DispC90","Dispositions & Outcomes"}, {"Outcome","Dispositions & Outcomes"},
        {"ServicePlan","Dispositions & Outcomes"}, {"Supervision","Dispositions & Outcomes"},
        {"Medical","Court / Medical / Other"}, {"CourtCFSA","Court / Medical / Other"},
        {"CourtCriminal","Court / Medical / Other"}, {"CourtOther","Court / Medical / Other"},
        {"CourtYOA","Court / Medical / Other"}, {"Community","Court / Medical / Other"},
        {"Placement","Court / Medical / Other"}, {"Police","Court / Medical / Other"},
        {"SCAS","Court / Medical / Other"}
    };

    public static readonly string[] CategoryOrder = {
        "Case Management", "People", "Referrals / Intake", "Interviews",
        "Assessments", "Case Notes", "Recording (CD)",
        "Dispositions & Outcomes", "Court / Medical / Other", "Other"
    };

    public static string CategoryFor(string form)
    {
        string c;
        return CatMap.TryGetValue(form ?? "", out c) ? c : "Other";
    }

    // Original IFRS captions for interview forms
    static readonly Dictionary<string, string> FormCaption =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        {"Interview1","Interview with Parent(s)/Caregivers"},
        {"Interview3","Interview with Alleged Victims and Siblings"},
        {"Interview4","Interview with Person(s) Responsible for Alleged Maltreatment"},
        {"Interview5","Interview (Other)"},
        {"CDForm","Recording / CD Form"},
        {"IAForm","Initial Assessment"},
        {"IAOutcome","Initial Assessment Outcome"},
        {"safetyassessment","Safety Assessment"},
        {"CompAssessment","Comprehensive Assessment"},
        {"CMForm","Case Management"},
        {"CAForm","Case Administration"}
    };

    public static string CaptionFor(string form)
    {
        string c;
        return FormCaption.TryGetValue(form ?? "", out c) ? c : form;
    }

    // ---- Audit ----
    public static void Audit(string action, string caseNo, string unid, string detail)
    {
        try {
            using (var cn = new SqlConnection(ConnStr))
            using (var cmd = new SqlCommand(
                "INSERT INTO dbo.PortalAudit (UserName, Action, CaseNumber, UNID, Detail, ClientIP) " +
                "VALUES (@u, @a, @c, @n, @d, @ip)", cn))
            {
                var ctx = HttpContext.Current;
                cmd.Parameters.AddWithValue("@u", (object)(ctx != null ? ctx.User.Identity.Name : "system"));
                cmd.Parameters.AddWithValue("@a", action);
                cmd.Parameters.AddWithValue("@c", (object)caseNo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@n", (object)unid ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@d", (object)detail ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ip", (object)(ctx != null ? ctx.Request.UserHostAddress : null) ?? DBNull.Value);
                cn.Open(); cmd.ExecuteNonQuery();
            }
        } catch { /* auditing must never break the page */ }
    }

    // ---- Query helper ----
    public static DataTable Query(string sql, params SqlParameter[] ps)
    {
        using (var cn = new SqlConnection(ConnStr))
        using (var cmd = new SqlCommand(sql, cn))
        {
            cmd.CommandTimeout = 60;
            foreach (var p in ps) cmd.Parameters.Add(p);
            var dt = new DataTable();
            cn.Open();
            using (var rd = cmd.ExecuteReader()) dt.Load(rd);
            return dt;
        }
    }

    // Validate a table name against the catalog (prevents injection via table names)
    public static bool IsKnownTable(string table)
    {
        var dt = Query("SELECT 1 FROM dbo.NSF_TableCatalog WHERE TargetTable = @t",
                       new SqlParameter("@t", table ?? ""));
        return dt.Rows.Count > 0;
    }

    public static string H(object o) { return HttpUtility.HtmlEncode(Convert.ToString(o)); }

    // ---- Cached archive stats for the masthead ----
    public static DataRow Stats()
    {
        var app = HttpContext.Current.Application;
        var cached = app["stats"] as DataTable;
        if (cached == null)
        {
            cached = Query(@"
                SELECT
                  (SELECT COUNT(DISTINCT CaseNumber) FROM dbo.CaseSpine)                       AS Cases,
                  (SELECT COUNT(*) FROM dbo.CaseSpine WHERE CopyRank = 1)                       AS Docs,
                  (SELECT COUNT(*) FROM dbo.CaseSpine WHERE CopyRank = 1
                    AND Form IN ('Caregiver','Child','Family','IntResponsible'))                AS People,
                  (SELECT COUNT(*) FROM dbo.CaseSpine WHERE CopyRank = 1 AND Form = 'CaseNote') AS Notes,
                  (SELECT COUNT(*) FROM dbo.CaseSpine WHERE CopyRank = 1 AND Form = 'Referral') AS Referrals");
            app["stats"] = cached;
        }
        return cached.Rows[0];
    }

    public static bool IsAdmin(System.Security.Principal.IPrincipal user)
    {
        var grp = ConfigurationManager.AppSettings["AdminGroup"];
        try { return !string.IsNullOrEmpty(grp) && user.IsInRole(grp); } catch { return false; }
    }
}
