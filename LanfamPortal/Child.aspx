<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Child record — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }
    string caseno = (Request["caseno"] ?? "").Trim();
    if (caseno == "") { Body.Text = "<div class='warn'>No case number supplied.</div>"; return; }
    Db.Audit(Context, "VIEW_CHILD", caseno);

    var sb = new StringBuilder();
    using (var cn = Db.Open())
    {
        string surname = "";
        using (var cmd = new SqlCommand("SELECT * FROM lanfam.Child WHERE caseno=@c", cn))
        {
            cmd.Parameters.AddWithValue("@c", caseno);
            using (var r = cmd.ExecuteReader())
            {
                if (!r.Read())
                    sb.Append("<h1>Case <span class='caseno'>" + Db.H(caseno) + "</span></h1>" +
                        "<div class='warn'>Not in the CHILD master (2008 snapshot). History and cost rows may still exist below.</div>");
                else
                {
                    surname = r["surname"] as string ?? "";
                    sb.Append("<h1>" + Db.H(r["surname"]) + ", " + Db.H(r["givename"]) +
                        " <span class='caseno'>" + Db.H(caseno) + "</span></h1>");
                    sb.Append("<div class='section-jump'><a href='#master'>Master</a>" +
                        "<a href='#timeline'>Timeline</a><a href='#history'>History table</a>" +
                        "<a href='#costs'>Costs</a></div>");
                    sb.Append("<div class='card tabbed' id='master'><h2>Master record</h2><div class='facts'>");
                    Fact(sb, "Birth date", Db.D(r["birthdate"]) +
                        ("Y".Equals(r["birth_verified"] as string, StringComparison.OrdinalIgnoreCase) ? " (verified)" : ""));
                    Fact(sb, "Sex", Db.H(r["sex"]));
                    Fact(sb, "Alias", Db.H(r["alias"]));
                    Fact(sb, "Admitted", Db.D(r["admit_date"]));
                    Fact(sb, "Admission reason", Db.Decode("SR", r["adm_reason1"] as string));
                    Fact(sb, "New / readmit", "R".Equals(r["new_readmit"] as string) ? "Readmission" : "New");
                    Fact(sb, "Ward status", Db.H(r["ward_status"]));
                    Fact(sb, "Admit worker", WorkerLink(r["admit_wrk_cd"], r["admit_worker"]) +
                        " / " + Db.H(r["admit_super"]));
                    Fact(sb, "Current worker", WorkerLink(r["cur_wrk_cd"], r["cur_worker"]) +
                        " / " + Db.H(r["cur_super"]));
                    Fact(sb, "Family worker", WorkerLink(r["fam_wrk_cd"], r["fam_worker"]));
                    Fact(sb, "Placement date", Db.D(r["place_date"]));
                    Fact(sb, "Resource no", Db.H(r["res_no"]));
                    sb.Append("</div><p class='hint'>Possible family links: " +
                        "<a class='link' href='Default.aspx?surname=" + Server.UrlEncode(surname) +
                        "'>search this surname</a> across the whole archive.</p></div>");
                }
            }
        }

        // ---- visual timeline (dated events only) ----
        sb.Append("<div class='card' id='timeline'><h2>Placement timeline</h2><div class='timeline'>");
        int tn = 0;
        using (var cmd = new SqlCommand(
            "SELECT event_date, event_desc, ResnoFull, res_surname, svc_desc " +
            "FROM lanfam.ChildHistory WHERE caseno=@c AND event_date IS NOT NULL " +
            "ORDER BY event_date, ChildHistoryID", cn))
        {
            cmd.Parameters.AddWithValue("@c", caseno);
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                {
                    tn++;
                    string what = Db.H(r[1]); if (what == "") what = Db.H(r[4]);
                    sb.Append("<div class='tl-item'><span class='tl-date'>" + Db.D(r[0]) +
                        "</span><div class='tl-what'>" + (what == "" ? "Placement event" : what) +
                        "</div><div class='tl-meta'>" + ResLink(r[2] as string, r[3] as string) +
                        (Db.H(r[4]) != "" ? " &#183; " + Db.H(r[4]) : "") + "</div></div>");
                }
        }
        if (tn == 0) sb.Append("<p>No dated events.</p>");
        sb.Append("</div></div>");

        // ---- full history table ----
        sb.Append("<div class='card' id='history'><h2>Placement &amp; status history (all rows)</h2>" +
            "<input class='tablefilter' placeholder='Filter rows&#8230;' />" +
            "<table class='ledger'><tr><th>Event date</th><th>Event</th><th>Resource</th>" +
            "<th>Resource name</th><th>Service</th><th>Rates</th><th>To date</th><th>Comment</th></tr>");
        using (var cmd = new SqlCommand(
            "SELECT event_date, event_desc, ResnoFull, res_surname, svc_desc, rate1, rate2, to_date, comment " +
            "FROM lanfam.ChildHistory WHERE caseno=@c ORDER BY event_date, ChildHistoryID", cn))
        {
            cmd.Parameters.AddWithValue("@c", caseno);
            int n = 0;
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                { n++;
                  sb.Append("<tr><td class='date'>" + Db.D(r[0]) + "</td><td>" + Db.H(r[1]) +
                      "</td><td>" + ResLink(r[2] as string, null) + "</td><td>" + Db.H(r[3]) +
                      "</td><td>" + Db.H(r[4]) + "</td><td class='num'>" + Db.H(r[5]) + " / " +
                      Db.H(r[6]) + "</td><td class='date'>" + Db.H(r[7]) + "</td><td>" +
                      Db.H(r[8]) + "</td></tr>"); }
            if (n == 0) sb.Append("<tr><td colspan='8'>No history rows.</td></tr>");
        }
        sb.Append("</table></div>");

        // ---- costs ----
        sb.Append("<div class='card' id='costs'><h2>Cost lines</h2>" +
            "<input class='tablefilter' placeholder='Filter rows&#8230;' />" +
            "<table class='ledger'><tr><th>From</th><th>To</th><th>Days</th><th>Resource</th>" +
            "<th>Rates</th><th>Amount</th><th>Posted by</th><th>Posted</th><th>Comment</th></tr>");
        using (var cmd = new SqlCommand(
            "SELECT from_date, to_date, days, resno, rate1, rate2, amount, worker_cd, post_date, comment " +
            "FROM lanfam.CostPurchase WHERE caseno=@c ORDER BY from_date", cn))
        {
            cmd.Parameters.AddWithValue("@c", caseno);
            int n = 0;
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                { n++;
                  sb.Append("<tr><td class='date'>" + Db.D(r[0]) + "</td><td class='date'>" +
                      Db.D(r[1]) + "</td><td class='num'>" + Db.H(r[2]) + "</td><td>" +
                      Db.H(r[3]) + "</td><td class='num'>" + Db.H(r[4]) + " / " + Db.H(r[5]) +
                      "</td><td class='num'>" + Db.H(r[6]) + "</td><td>" +
                      WorkerLink(r[7], null) + "</td><td class='date'>" + Db.D(r[8]) +
                      "</td><td>" + Db.H(r[9]) + "</td></tr>"); }
            if (n == 0) sb.Append("<tr><td colspan='9'>No cost rows.</td></tr>");
        }
        sb.Append("</table></div>");
    }
    Body.Text = sb.ToString();
}

string WorkerLink(object cd, object name)
{
    string c = (cd as string ?? "").Trim();
    string label = Db.H(name) != "" ? Db.H(name) : c;
    if (c == "") return label == "" ? "&#8212;" : label;
    return "<a class='link' href='Worker.aspx?cd=" + Server.UrlEncode(c) + "'>" + label + "</a>";
}
string ResLink(string resno, string name)
{
    string r = (resno ?? "").Trim();
    if (r == "") return Db.H(name);
    return "<a class='caseno' href='Resource.aspx?resno=" + Server.UrlEncode(r) + "'>" + Db.H(r) + "</a>" +
        (Db.H(name) != "" ? " " + Db.H(name) : "");
}
void Fact(StringBuilder sb, string label, string val)
{ sb.Append("<div><b>" + label + "</b>" + (val == "" ? "&#8212;" : val) + "</div>"); }
</script>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">
  <p class="crumb"><a href="Default.aspx">&#8592; Search</a></p>
  <asp:Literal ID="Body" runat="server" />
</asp:Content>
