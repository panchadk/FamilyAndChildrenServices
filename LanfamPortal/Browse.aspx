<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Browse — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
const int PageSize = 50;
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }

    string letter = (Request["letter"] ?? "A").Trim().ToUpper();
    if (letter.Length != 1 || letter[0] < 'A' || letter[0] > 'Z') letter = "A";
    int page; if (!int.TryParse(Request["p"], out page) || page < 1) page = 1;
    Db.Audit(Context, "BROWSE", "letter=" + letter + "; page=" + page);

    var sb = new StringBuilder();
    sb.Append("<h1>Browse children in care</h1><div class='azstrip'>");
    foreach (char ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        sb.Append("<a class='" + (ch.ToString() == letter ? "on" : "") +
            "' href='Browse.aspx?letter=" + ch + "'>" + ch + "</a>");
    sb.Append("</div>");

    using (var cn = Db.Open())
    {
        int total;
        using (var cmd = new SqlCommand(
            "SELECT COUNT(*) FROM lanfam.Child WHERE surname LIKE @l", cn))
        { cmd.Parameters.AddWithValue("@l", letter + "%");
          total = (int)cmd.ExecuteScalar(); }

        sb.Append("<div class='card tabbed'><h2>" + Db.H(letter) + " &#8212; " +
            total.ToString("N0") + " children</h2>" +
            "<table class='ledger'><tr><th>Case no</th><th>Surname</th><th>Given</th>" +
            "<th>Birth</th><th>Admitted</th><th>Current worker</th></tr>");
        using (var cmd = new SqlCommand(
            "SELECT caseno, surname, givename, birthdate, admit_date, cur_worker " +
            "FROM lanfam.Child WHERE surname LIKE @l ORDER BY surname, givename " +
            "OFFSET @o ROWS FETCH NEXT @n ROWS ONLY", cn))
        {
            cmd.Parameters.AddWithValue("@l", letter + "%");
            cmd.Parameters.AddWithValue("@o", (page - 1) * PageSize);
            cmd.Parameters.AddWithValue("@n", PageSize);
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                    sb.Append("<tr><td><a class='caseno' href='Child.aspx?caseno=" +
                        Server.UrlEncode(r.GetString(0)) + "'>" + Db.H(r[0]) + "</a></td><td>" +
                        Db.H(r[1]) + "</td><td>" + Db.H(r[2]) + "</td><td class='date'>" +
                        Db.D(r[3]) + "</td><td class='date'>" + Db.D(r[4]) + "</td><td>" +
                        Db.H(r[5]) + "</td></tr>");
        }
        sb.Append("</table>");

        int pages = (total + PageSize - 1) / PageSize;
        if (pages > 1)
        {
            sb.Append("<div class='pager'>");
            for (int i = 1; i <= pages; i++)
                sb.Append(i == page ? "<span class='cur'>" + i + "</span>"
                    : "<a href='Browse.aspx?letter=" + letter + "&p=" + i + "'>" + i + "</a>");
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
