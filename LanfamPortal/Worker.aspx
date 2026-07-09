<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Workers — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }

    string cd = (Request["cd"] ?? "").Trim();
    var sb = new StringBuilder();
    using (var cn = Db.Open())
    {
        if (cd == "")
        {
            Db.Audit(Context, "VIEW_WORKERS", "roster");
            sb.Append("<h1>Worker roster</h1><div class='card tabbed'>" +
                "<h2>170 workers &#8212; click a code for their caseload</h2>" +
                "<input class='tablefilter' placeholder='Filter by name&#8230;' />" +
                "<table class='ledger'><tr><th>Code</th><th>Worker</th><th>Supervisor</th></tr>");
            using (var cmd = new SqlCommand(
                "SELECT worker_cd, worker, supervisor FROM lanfam.Worker ORDER BY worker", cn))
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                    sb.Append("<tr><td><a class='caseno' href='Worker.aspx?cd=" +
                        Server.UrlEncode(r.GetString(0)) + "'>" + Db.H(r[0]) + "</a></td><td>" +
                        Db.H(r[1]) + "</td><td>" + Db.H(r[2]) + "</td></tr>");
            sb.Append("</table></div>");
        }
        else
        {
            Db.Audit(Context, "VIEW_WORKER", cd);
            using (var cmd = new SqlCommand(
                "SELECT worker, supervisor FROM lanfam.Worker WHERE worker_cd=@c", cn))
            {
                cmd.Parameters.AddWithValue("@c", cd);
                using (var r = cmd.ExecuteReader())
                    sb.Append(r.Read()
                        ? "<h1>" + Db.H(r[0]) + " <span class='caseno'>" + Db.H(cd) +
                          "</span></h1><p class='hint'>Supervisor: " + Db.H(r[1]) + "</p>"
                        : "<h1>Worker <span class='caseno'>" + Db.H(cd) +
                          "</span></h1><div class='warn'>Code not in the 1999 roster snapshot.</div>");
            }

            sb.Append("<div class='card tabbed'><h2>Referrals handled by this worker</h2>" +
                "<p class='hint'>Every referral where this worker is listed as the intake worker " +
                "&#8212; includes brief services that never became a full admission, so this can " +
                "show activity even when Admissions and Caseload below are empty.</p>" +
                "<input class='tablefilter' placeholder='Filter&#8230;' />" +
                "<table class='ledger'><tr><th>Referral #</th><th>Name</th><th>Date</th><th>Family</th></tr>");
            using (var cmd = new SqlCommand(
                "SELECT caseno, famno, ref_date, ref_time, surname, given " +
                "FROM lanfam.Referral WHERE worker_cd=@c ORDER BY ref_date DESC", cn))
            {
                cmd.Parameters.AddWithValue("@c", cd);
                int n = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { n++;
                      string rcaseno = r.IsDBNull(0) ? "" : r.GetString(0);
                      string rfamno = r.IsDBNull(1) ? "" : r.GetString(1);
                      sb.Append("<tr><td>" +
                          (rcaseno != "" ? "<a class='link caseno' href='CrossReference.aspx?ref=" +
                              Server.UrlEncode(rcaseno) + "'>" + Db.H(rcaseno) + "</a>" : "&#8212;") +
                          "</td><td>" + Db.H(r[4]) + ", " + Db.H(r[5]) + "</td><td class='date'>" +
                          Db.D(r[2]) + " " + Db.H(r[3]) + "</td><td>" +
                          (rfamno != "" ? "<a class='link caseno' href='Family.aspx?famno=" +
                              Server.UrlEncode(rfamno) + "'>" + Db.H(rfamno) + "</a>" : "&#8212;") +
                          "</td></tr>"); }
                if (n == 0) sb.Append("<tr><td colspan='4'>None recorded.</td></tr>");
            }
            sb.Append("</table></div>");

            sb.Append("<div class='card tabbed'><h2>Admissions by this worker</h2>" +
                "<input class='tablefilter' placeholder='Filter&#8230;' />" +
                "<table class='ledger'><tr><th>Case no</th><th>Child</th><th>Admitted</th><th>Reason</th></tr>");
            using (var cmd = new SqlCommand(
                "SELECT caseno, surname, givename, admit_date, adm_reason1 " +
                "FROM lanfam.Child WHERE admit_wrk_cd=@c ORDER BY admit_date", cn))
            {
                cmd.Parameters.AddWithValue("@c", cd);
                int n = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { n++;
                      sb.Append("<tr><td><a class='caseno' href='Child.aspx?caseno=" +
                          Server.UrlEncode(r.GetString(0)) + "'>" + Db.H(r[0]) + "</a></td><td>" +
                          Db.H(r[1]) + ", " + Db.H(r[2]) + "</td><td class='date'>" + Db.D(r[3]) +
                          "</td><td>" + Db.H(Db.Decode("SR", r[4] as string)) + "</td></tr>"); }
                if (n == 0) sb.Append("<tr><td colspan='4'>None recorded.</td></tr>");
            }
            sb.Append("</table></div>");

            sb.Append("<div class='card'><h2>Current caseload (2008 snapshot)</h2>" +
                "<table class='ledger'><tr><th>Case no</th><th>Child</th><th>Admitted</th></tr>");
            using (var cmd = new SqlCommand(
                "SELECT caseno, surname, givename, admit_date FROM lanfam.Child " +
                "WHERE cur_wrk_cd=@c ORDER BY surname", cn))
            {
                cmd.Parameters.AddWithValue("@c", cd);
                int n = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { n++;
                      sb.Append("<tr><td><a class='caseno' href='Child.aspx?caseno=" +
                          Server.UrlEncode(r.GetString(0)) + "'>" + Db.H(r[0]) + "</a></td><td>" +
                          Db.H(r[1]) + ", " + Db.H(r[2]) + "</td><td class='date'>" +
                          Db.D(r[3]) + "</td></tr>"); }
                if (n == 0) sb.Append("<tr><td colspan='3'>None recorded.</td></tr>");
            }
            sb.Append("</table></div>");
        }
    }
    Body.Text = sb.ToString();
}
</script>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">
  <p class="crumb"><a href="Default.aspx">&#8592; Search</a></p>
  <asp:Literal ID="Body" runat="server" />
</asp:Content>
