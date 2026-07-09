<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Family record — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }

    string famno = (Request["famno"] ?? "").Trim();
    if (famno == "") { Body.Text = "<div class='warn'>No family number supplied.</div>"; return; }
    Db.Audit(Context, "VIEW_FAMILY", famno);

    var sb = new StringBuilder();
    sb.Append("<h1>Family <span class='caseno'>" + Db.H(famno) + "</span></h1>");
    sb.Append("<div class='section-jump'><a href='#hist'>History</a><a href='#refs'>Referrals</a></div>");
    using (var cn = Db.Open())
    {
        sb.Append("<div class='card'><h2 id='hist'>Case open / close history</h2>" +
            "<table class='ledger'><tr><th>Code</th><th>Opened</th><th>Closed</th></tr>");
        using (var cmd = new SqlCommand(
            "SELECT code, open_date, close_date FROM lanfam.FamilyHistory " +
            "WHERE famno=@f ORDER BY open_date", cn))
        {
            cmd.Parameters.AddWithValue("@f", famno);
            int n = 0;
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                {
                    n++;
                    sb.Append("<tr><td>" + Db.H(r[0]) + "</td><td class='date'>" + Db.D(r[1]) +
                        "</td><td class='date'>" + Db.D(r[2]) + "</td></tr>");
                }
            if (n == 0) sb.Append("<tr><td colspan='3'>No history rows.</td></tr>");
        }
        sb.Append("</table></div>");

        using (var cmd = new SqlCommand(
            "SELECT ref_date, ref_time, surname, given, source, worker_cd, narrative " +
            "FROM lanfam.Referral WHERE famno=@f ORDER BY ref_date, ref_time", cn))
        {
            cmd.Parameters.AddWithValue("@f", famno);
            int n = 0;
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                {
                    n++;
                    if (n == 1) sb.Append("<a id='refs'></a>");
                    sb.Append("<div class='card tabbed'><h2>Referral &#8212; " + Db.D(r[0]) +
                        " " + Db.H(r[1]) + "</h2><div class='facts'>");
                    sb.Append("<div><b>Name</b><a class='link' href='Default.aspx?surname=" + Server.UrlEncode((r[2] as string ?? "").Trim()) + "'>" + Db.H(r[2]) + ", " + Db.H(r[3]) + "</a></div>");
                    sb.Append("<div><b>Source</b>" + Db.H(r[4]) + "</div>");
                    sb.Append("<div><b>Worker code</b>" + Db.H(r[5]) + "</div>");
                    sb.Append("</div>");
                    string narr = r[6] as string;
                    if (!string.IsNullOrEmpty(narr))
                        sb.Append("<div class='narrative'>" + Db.H(narr) + "</div>");
                    sb.Append("</div>");
                }
            if (n == 0) sb.Append("<div class='card'><h2>Referrals</h2>" +
                "<p>No referrals recorded for this family number.</p></div>");
        }
    }
    Body.Text = sb.ToString();
}
</script>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">
  <p class="crumb"><a href="Default.aspx">&#8592; Search</a></p>
  <asp:Literal ID="Body" runat="server" />
</asp:Content>
