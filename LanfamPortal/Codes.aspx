<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Code book — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }
    Db.Audit(Context, "VIEW_CODES", null);

    var sb = new StringBuilder();
    sb.Append("<h1>Code book</h1><p class='hint'>Every lookup code LANFAM used, " +
        "merged from the CASE and FAMILY code tables. Use the filter to find a code fast.</p>");
    sb.Append("<div class='card tabbed'>" +
        "<input class='tablefilter' placeholder='Filter codes (e.g. neglect, A01, religion)&#8230;' />" +
        "<table class='ledger'><tr><th>Category</th><th>Code</th><th>Description</th><th>Source</th></tr>");
    using (var cn = Db.Open())
    using (var cmd = new SqlCommand(
        "SELECT category, code, description, Source FROM lanfam.Codes " +
        "ORDER BY category, code, Source", cn))
    using (var r = cmd.ExecuteReader())
        while (r.Read())
            sb.Append("<tr><td class='caseno'>" + Db.H(r[0]) + "</td><td class='caseno'>" +
                Db.H(r[1]) + "</td><td>" + Db.H(r[2]) + "</td><td>" +
                Db.H(r[3]) + "</td></tr>");
    sb.Append("</table></div>");
    Body.Text = sb.ToString();
}
</script>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">
  <p class="crumb"><a href="Default.aspx">&#8592; Search</a></p>
  <asp:Literal ID="Body" runat="server" />
</asp:Content>
