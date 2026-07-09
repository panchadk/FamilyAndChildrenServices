<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Families — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
const int PageSize = 50;
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }

    string fno = (Request["fno"] ?? "").Trim();
    string nm  = (Request["nm"] ?? "").Trim();
    int page; if (!int.TryParse(Request["p"], out page) || page < 1) page = 1;

    var sb = new StringBuilder();
    sb.Append("<h1>Families</h1><div class='card tabbed'>" +
        "<form method='get'><div class='searchbar'>" +
        "<input type='text' name='fno' placeholder='Family no (e.g. S001670 or 16036)' value='" + Db.H(fno) + "' />" +
        "<input type='text' name='nm' placeholder='Person surname (matches via referrals)' value='" + Db.H(nm) + "' />" +
        "<input type='submit' value='FIND' /></div>" +
        "<p class='hint'>6,731 family numbers across both masters. Surname search finds " +
        "families through the names on their referrals &#8212; useful when you know who " +
        "but not the number. Leave both blank to page through all families.</p></form></div>");

    Db.Audit(Context, "SEARCH_FAMILY", "fno=" + fno + "; nm=" + nm + "; p=" + page);
    using (var cn = Db.Open())
    {
        string where, join = "";
        if (nm != "")
        {
            join = " JOIN (SELECT DISTINCT famno FROM lanfam.Referral WHERE surname LIKE @n " +
                   "AND famno IS NOT NULL) m ON m.famno = f.famno";
            where = fno != "" ? " WHERE f.famno LIKE @f" : "";
        }
        else where = fno != "" ? " WHERE f.famno LIKE @f" : "";

        Action<SqlCommand> bind = c => {
            if (fno != "") c.Parameters.AddWithValue("@f", fno + "%");
            if (nm  != "") c.Parameters.AddWithValue("@n", nm + "%");
        };

        int total;
        using (var c = new SqlCommand(
            "SELECT COUNT(*) FROM lanfam.FamilyIndex f" + join + where, cn))
        { bind(c); total = (int)c.ExecuteScalar(); }

        sb.Append("<div class='card'><h2>" + total.ToString("N0") + " families" +
            (total > PageSize ? " &#8212; page " + page : "") + "</h2>" +
            "<table class='ledger'><tr><th>Family no</th><th>Source</th><th>Referrals</th>" +
            "<th>First referral</th><th>Last referral</th><th>Names on referrals</th></tr>");
        using (var c = new SqlCommand(
            "SELECT f.famno, f.SourceTable, " +
            " (SELECT COUNT(*) FROM lanfam.Referral r WHERE r.famno=f.famno), " +
            " (SELECT MIN(ref_date) FROM lanfam.Referral r WHERE r.famno=f.famno), " +
            " (SELECT MAX(ref_date) FROM lanfam.Referral r WHERE r.famno=f.famno), " +
            " STUFF((SELECT DISTINCT ', ' + r.surname FROM lanfam.Referral r " +
            "        WHERE r.famno=f.famno AND ISNULL(r.surname,'')<>'' " +
            "        FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,2,'') " +
            "FROM lanfam.FamilyIndex f" + join + where +
            " ORDER BY f.famno OFFSET @off ROWS FETCH NEXT @ps ROWS ONLY", cn))
        {
            bind(c);
            c.Parameters.AddWithValue("@off", (page - 1) * PageSize);
            c.Parameters.AddWithValue("@ps", PageSize);
            int n = 0;
            using (var r = c.ExecuteReader())
                while (r.Read())
                { n++;
                  string names = r[5] as string ?? "";
                  if (names.Length > 90) names = names.Substring(0, 90) + "&#8230;";
                  sb.Append("<tr><td><a class='caseno' href='Family.aspx?famno=" +
                      Server.UrlEncode(r.GetString(0)) + "'>" + Db.H(r[0]) + "</a></td><td>" +
                      Db.H(r[1]) + "</td><td class='num'>" + Db.H(r[2]) + "</td><td class='date'>" +
                      Db.D(r[3]) + "</td><td class='date'>" + Db.D(r[4]) + "</td><td>" +
                      names + "</td></tr>"); }
            if (n == 0) sb.Append("<tr><td colspan='6'>No matching families.</td></tr>");
        }
        sb.Append("</table>");

        int pages = (total + PageSize - 1) / PageSize;
        if (pages > 1)
        {
            string qs = "fno=" + Server.UrlEncode(fno) + "&nm=" + Server.UrlEncode(nm);
            sb.Append("<div class='pager'>");
            int lo = Math.Max(1, page - 7), hi = Math.Min(pages, page + 7);
            if (lo > 1) sb.Append("<a href='Families.aspx?" + qs + "&p=1'>1</a><span>&#8230;</span>");
            for (int i = lo; i <= hi; i++)
                sb.Append(i == page ? "<span class='cur'>" + i + "</span>"
                    : "<a href='Families.aspx?" + qs + "&p=" + i + "'>" + i + "</a>");
            if (hi < pages) sb.Append("<span>&#8230;</span><a href='Families.aspx?" + qs +
                "&p=" + pages + "'>" + pages + "</a>");
            sb.Append("</div>");
        }
        sb.Append("</div>");
    }
    Body.Text = sb.ToString();
}
</script>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">
  <p class="crumb"><a href="Default.aspx">&#8592; Search</a></p>
  <asp:Literal ID="Body" runat="server" />
</asp:Content>
