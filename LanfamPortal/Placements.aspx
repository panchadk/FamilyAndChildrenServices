<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Placement events — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
const int PageSize = 100;
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }

    string ev   = (Request["ev"] ?? "").Trim();
    string svc  = (Request["svc"] ?? "").Trim();
    string from = (Request["from"] ?? "").Trim();
    string to   = (Request["to"] ?? "").Trim();
    int page; if (!int.TryParse(Request["p"], out page) || page < 1) page = 1;
    bool any = ev != "" || svc != "" || from != "" || to != "";

    var sb = new StringBuilder();
    using (var cn = Db.Open())
    {
        // dropdown options from the data itself
        sb.Append("<h1>Placement events</h1><div class='card tabbed'>" +
            "<form method='get'><div class='searchbar'>" +
            "<select name='ev' style='padding:9px;font:14px Georgia,serif;border:1px solid var(--rule);'>" +
            "<option value=''>Any event type</option>");
        using (var c = new SqlCommand(
            "SELECT event_desc, COUNT(*) FROM lanfam.ChildHistory " +
            "WHERE ISNULL(event_desc,'')<>'' GROUP BY event_desc " +
            "HAVING COUNT(*)>=10 ORDER BY COUNT(*) DESC", cn))
        using (var r = c.ExecuteReader())
            while (r.Read())
                sb.Append("<option value='" + Db.H(r[0]) + "'" +
                    (ev == (r[0] as string) ? " selected" : "") + ">" + Db.H(r[0]) +
                    " (" + r[1] + ")</option>");
        sb.Append("</select><select name='svc' style='padding:9px;font:14px Georgia,serif;border:1px solid var(--rule);'>" +
            "<option value=''>Any service</option>");
        using (var c = new SqlCommand(
            "SELECT svc_desc, COUNT(*) FROM lanfam.ChildHistory " +
            "WHERE ISNULL(svc_desc,'')<>'' GROUP BY svc_desc " +
            "HAVING COUNT(*)>=10 ORDER BY COUNT(*) DESC", cn))
        using (var r = c.ExecuteReader())
            while (r.Read())
                sb.Append("<option value='" + Db.H(r[0]) + "'" +
                    (svc == (r[0] as string) ? " selected" : "") + ">" + Db.H(r[0]) +
                    " (" + r[1] + ")</option>");
        sb.Append("</select>" +
            "<input type='text' name='from' placeholder='From yyyy-mm-dd' value='" + Db.H(from) + "' style='max-width:150px' />" +
            "<input type='text' name='to' placeholder='To yyyy-mm-dd' value='" + Db.H(to) + "' style='max-width:150px' />" +
            "<input type='submit' value='SEARCH' /></div>" +
            "<p class='hint'>23,432 events across all children. Counts in the dropdowns " +
            "show how often each type occurs. Combine with a date range for questions like " +
            "&#8220;all RETURN events in 1996&#8221;.</p></form></div>");

        if (any)
        {
            Db.Audit(Context, "SEARCH_PLACEMENT", "ev=" + ev + "; svc=" + svc + "; " + from + ".." + to);
            string where = " WHERE 1=1";
            if (ev  != "") where += " AND event_desc = @e";
            if (svc != "") where += " AND svc_desc = @s";
            if (from != "") where += " AND event_date >= @f";
            if (to   != "") where += " AND event_date <= @o";
            Action<SqlCommand> bind = c => {
                if (ev  != "") c.Parameters.AddWithValue("@e", ev);
                if (svc != "") c.Parameters.AddWithValue("@s", svc);
                if (from != "") c.Parameters.AddWithValue("@f", from);
                if (to   != "") c.Parameters.AddWithValue("@o", to);
            };

            int total;
            using (var c = new SqlCommand("SELECT COUNT(*) FROM lanfam.ChildHistory" + where, cn))
            { bind(c); total = (int)c.ExecuteScalar(); }

            sb.Append("<div class='card'><h2>" + total.ToString("N0") + " events" +
                (total > PageSize ? " &#8212; page " + page : "") + "</h2>" +
                "<input class='tablefilter' placeholder='Filter this page&#8230;' />" +
                "<table class='ledger'><tr><th>Date</th><th>Case no</th><th>Child</th>" +
                "<th>Event</th><th>Resource</th><th>Resource name</th><th>Service</th></tr>");
            using (var c = new SqlCommand(
                "SELECT event_date, caseno, surname, given, event_desc, ResnoFull, res_surname, svc_desc " +
                "FROM lanfam.ChildHistory" + where +
                " ORDER BY event_date OFFSET @off ROWS FETCH NEXT @ps ROWS ONLY", cn))
            {
                bind(c);
                c.Parameters.AddWithValue("@off", (page - 1) * PageSize);
                c.Parameters.AddWithValue("@ps", PageSize);
                using (var r = c.ExecuteReader())
                    while (r.Read())
                        sb.Append("<tr><td class='date'>" + Db.D(r[0]) + "</td><td>" +
                            "<a class='caseno' href='Child.aspx?caseno=" +
                            Server.UrlEncode((r[1] as string ?? "").Trim()) + "'>" + Db.H(r[1]) +
                            "</a></td><td>" + Db.H(r[2]) + ", " + Db.H(r[3]) + "</td><td>" +
                            Db.H(r[4]) + "</td><td><a class='caseno' href='Resource.aspx?resno=" +
                            Server.UrlEncode((r[5] as string ?? "").Trim()) + "'>" + Db.H(r[5]) +
                            "</a></td><td>" + Db.H(r[6]) + "</td><td>" + Db.H(r[7]) + "</td></tr>");
            }
            sb.Append("</table>");
            int pages = (total + PageSize - 1) / PageSize;
            if (pages > 1)
            {
                string qs = "ev=" + Server.UrlEncode(ev) + "&svc=" + Server.UrlEncode(svc) +
                    "&from=" + Server.UrlEncode(from) + "&to=" + Server.UrlEncode(to);
                sb.Append("<div class='pager'>");
                int lo = Math.Max(1, page - 7), hi = Math.Min(pages, page + 7);
                if (lo > 1) sb.Append("<a href='Placements.aspx?" + qs + "&p=1'>1</a><span>&#8230;</span>");
                for (int i = lo; i <= hi; i++)
                    sb.Append(i == page ? "<span class='cur'>" + i + "</span>"
                        : "<a href='Placements.aspx?" + qs + "&p=" + i + "'>" + i + "</a>");
                if (hi < pages) sb.Append("<span>&#8230;</span><a href='Placements.aspx?" + qs +
                    "&p=" + pages + "'>" + pages + "</a>");
                sb.Append("</div>");
            }
            sb.Append("</div>");
        }
    }
    Body.Text = sb.ToString();
}
</script>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">
  <p class="crumb"><a href="Default.aspx">&#8592; Search</a></p>
  <asp:Literal ID="Body" runat="server" />
</asp:Content>
