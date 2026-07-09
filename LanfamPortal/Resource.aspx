<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Resources — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }

    string resno = (Request["resno"] ?? "").Trim();
    var sb = new StringBuilder();
    using (var cn = Db.Open())
    {
        if (resno == "")
        {
            // ---- list mode ----
            string q = (Request["rq"] ?? "").Trim();
            sb.Append("<h1>Resource homes</h1><div class='card tabbed'>" +
                "<form method='get'><div class='searchbar'>" +
                "<div class='ac-wrap' style='position:relative;flex:1 1 260px'>" +
                "<input type='text' name='rq' id='rqbox' autocomplete='off' placeholder='Resource no or caregiver surname' value='" +
                Db.H(q) + "' style='width:100%' /><div id='rqsuggest' class='ac-list'></div></div>" +
                "<input type='submit' value='FIND' /></div></form></div>");
            if (q == "")
            {
                // default listing: category summary + all homes A-Z
                sb.Append("<div class='card'><h2>By category</h2><div class='tiles'>");
                using (var cmd = new SqlCommand(
                    "SELECT ISNULL(NULLIF(category,''),'(uncategorized)') AS cat, COUNT(*) AS n " +
                    "FROM lanfam.Resource GROUP BY category HAVING COUNT(*) >= 5 " +
                    "ORDER BY COUNT(*) DESC", cn))
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                        sb.Append("<div class='tile'><b>" + Db.H(r[1]) + "</b><span>" +
                            Db.H(r[0]) + "</span></div>");
                using (var cmd = new SqlCommand(
                    "SELECT COUNT(*) FROM lanfam.Resource r WHERE NOT EXISTS (" +
                    "SELECT 1 FROM lanfam.Resource g WHERE ISNULL(g.category,'')=ISNULL(r.category,'') " +
                    "GROUP BY g.category HAVING COUNT(*) >= 5)", cn))
                    sb.Append("<div class='tile'><b>" + cmd.ExecuteScalar() +
                        "</b><span>other / free-text</span></div>");
                sb.Append("</div></div>");

                sb.Append("<div class='card'><h2>All resource homes (1,645)</h2>" +
                    "<input class='tablefilter' placeholder='Filter by name, city, status&#8230;' />" +
                    "<table class='ledger'><tr><th>Resource</th><th>Caregivers</th>" +
                    "<th>City</th><th>Category</th><th>Status</th></tr>");
                using (var cmd = new SqlCommand(
                    "SELECT resno, surname1, given1, surname2, given2, addr2, " +
                    "CASE WHEN category IN (SELECT category FROM lanfam.Resource " +
                    "GROUP BY category HAVING COUNT(*) >= 5) THEN category ELSE '' END, " +
                    "status_text FROM lanfam.Resource WHERE resno IS NOT NULL " +
                    "ORDER BY COALESCE(NULLIF(surname1,''), surname2), resno", cn))
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                        sb.Append("<tr><td><a class='caseno' href='Resource.aspx?resno=" +
                            Server.UrlEncode((r[0] as string ?? "").Trim()) + "'>" + Db.H(r[0]) +
                            "</a></td><td>" + Caregivers(r[1], r[2], r[3], r[4]) + "</td><td>" +
                            Db.H(r[5]) + "</td><td>" + Db.H(r[6]) + "</td><td>" +
                            Db.H(r[7]) + "</td></tr>");
                sb.Append("</table></div>");
            }
            else
            {
                Db.Audit(Context, "SEARCH", "resource=" + q);
                sb.Append("<div class='card'><h2>Matches</h2>" +
                    "<table class='ledger'><tr><th>Resource</th><th>Caregivers</th>" +
                    "<th>City</th><th>Category</th><th>Status</th></tr>");
                using (var cmd = new SqlCommand(
                    "SELECT TOP 100 resno, surname1, given1, surname2, given2, addr2, " +
                    "CASE WHEN category IN (SELECT category FROM lanfam.Resource " +
                    "GROUP BY category HAVING COUNT(*) >= 5) THEN category ELSE '' END, status_text " +
                    "FROM lanfam.Resource WHERE resno LIKE @q OR surname1 LIKE @q OR surname2 LIKE @q " +
                    "ORDER BY COALESCE(NULLIF(surname1,''), surname2), resno", cn))
                {
                    cmd.Parameters.AddWithValue("@q", q + "%");
                    int n = 0;
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                        { n++;
                          sb.Append("<tr><td><a class='caseno' href='Resource.aspx?resno=" +
                              Server.UrlEncode((r[0] as string ?? "").Trim()) + "'>" + Db.H(r[0]) +
                              "</a></td><td>" + Caregivers(r[1], r[2], r[3], r[4]) + "</td><td>" +
                              Db.H(r[5]) + "</td><td>" + Db.H(r[6]) + "</td><td>" +
                              Db.H(r[7]) + "</td></tr>"); }
                    if (n == 0) sb.Append("<tr><td colspan='5'>No matching resources.</td></tr>");
                }
                sb.Append("</table></div>");
            }
        }
        else
        {
            // ---- detail mode ----
            Db.Audit(Context, "VIEW_RESOURCE", resno);
            using (var cmd = new SqlCommand("SELECT * FROM lanfam.Resource WHERE resno=@r", cn))
            {
                cmd.Parameters.AddWithValue("@r", resno);
                using (var r = cmd.ExecuteReader())
                {
                    if (!r.Read())
                        sb.Append("<h1>Resource <span class='caseno'>" + Db.H(resno) + "</span></h1>" +
                            "<div class='warn'>Not in the RESOURCE master (2000 snapshot) &#8212; " +
                            "placements referencing it are listed below.</div>");
                    else
                    {
                        sb.Append("<h1>" + Caregivers(r["surname1"], r["given1"],
                            r["surname2"], r["given2"]) +
                            " <span class='caseno'>" + Db.H(resno) + "</span></h1>");
                        sb.Append("<div class='card tabbed'><h2>Resource home</h2><div class='facts'>");
                        Fact(sb, "Category", Db.H(r["category"]));
                        Fact(sb, "Status", Db.H(r["status_text"]));
                        Fact(sb, "Address", Db.H(r["addr1"]) + ", " + Db.H(r["addr2"]) + " " + Db.H(r["postal"]));
                        Fact(sb, "Phone", Db.H(r["phone"]));
                        Fact(sb, "Employer", Db.H(r["employer"]));
                        Fact(sb, "Worker", Db.H(r["worker"]));
                        Fact(sb, "Opened", Db.H(r["open_date"]));
                        Fact(sb, "Comment", Db.H(r["comment"]));
                        sb.Append("</div></div>");
                    }
                }
            }
            sb.Append("<div class='card'><h2>Children placed at this resource</h2>" +
                "<input class='tablefilter' placeholder='Filter rows&#8230;' />" +
                "<table class='ledger'><tr><th>Case no</th><th>Child</th><th>Event date</th>" +
                "<th>Event</th><th>Service</th><th>To date</th></tr>");
            using (var cmd = new SqlCommand(
                "SELECT caseno, surname, given, event_date, event_desc, svc_desc, to_date " +
                "FROM lanfam.ChildHistory WHERE ResnoFull=@r ORDER BY event_date", cn))
            {
                cmd.Parameters.AddWithValue("@r", resno);
                int n = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { n++;
                      sb.Append("<tr><td><a class='caseno' href='Child.aspx?caseno=" +
                          Server.UrlEncode((r[0] as string ?? "").Trim()) + "'>" + Db.H(r[0]) +
                          "</a></td><td>" + Db.H(r[1]) + ", " + Db.H(r[2]) + "</td><td class='date'>" +
                          Db.D(r[3]) + "</td><td>" + Db.H(r[4]) + "</td><td>" + Db.H(r[5]) +
                          "</td><td class='date'>" + Db.H(r[6]) + "</td></tr>"); }
                if (n == 0) sb.Append("<tr><td colspan='6'>No placement rows reference this resource.</td></tr>");
            }
            sb.Append("</table></div>");
        }
    }
    Body.Text = sb.ToString();
}
string Caregivers(object s1, object g1, object s2, object g2)
{
    string a = (Db.H(s1) != "" ? Db.H(s1) + ", " + Db.H(g1) : "").TrimEnd(' ', ',');
    string b = (Db.H(s2) != "" ? Db.H(s2) + ", " + Db.H(g2) : "").TrimEnd(' ', ',');
    if (a != "" && b != "")
    {   // couple sharing a surname reads better as "ABWUNZA, GEORGE & JUDITH"
        if (Db.H(s1) == Db.H(s2)) return a + " &amp; " + Db.H(g2);
        return a + " &amp; " + b;
    }
    if (a != "") return a;
    if (b != "") return b;
    return "&#8212;";
}
void Fact(StringBuilder sb, string label, string val)
{ sb.Append("<div><b>" + label + "</b>" + (val == "" ? "&#8212;" : val) + "</div>"); }
</script>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">
  <p class="crumb"><a href="Default.aspx">&#8592; Search</a></p>
  <asp:Literal ID="Body" runat="server" />

  <style>
    .ac-list {
      position: absolute; top: 100%; left: 0; right: 0; z-index: 50;
      background: var(--card); border: 1px solid var(--rule);
      border-top: none; max-height: 320px; overflow-y: auto;
      display: none; box-shadow: 0 4px 10px rgba(0,0,0,.08);
    }
    .ac-item {
      padding: 8px 12px; cursor: pointer; font-size: 13.5px;
      border-bottom: 1px solid var(--rule);
    }
    .ac-item:last-child { border-bottom: none; }
    .ac-item:hover, .ac-item.active { background: var(--tab-soft); }
    .ac-item .n { color: var(--ink-soft); font-size: 11.5px; float: right; }
  </style>
  <script>
  (function () {
    function attachAutocomplete(box, list, urlFn, onPick) {
      if (!box || !list) return function () {};
      var timer = null, items = [], activeIdx = -1, lastQuery = null;
      function hide() { list.style.display = 'none'; activeIdx = -1; }
      function show() { if (items.length) list.style.display = 'block'; }
      function render() {
        list.innerHTML = '';
        items.forEach(function (it, i) {
          var m = it.label.match(/^(.*)\s(\(\d+ \w+\))$/);
          var div = document.createElement('div');
          div.className = 'ac-item' + (i === activeIdx ? ' active' : '');
          if (m) { div.innerHTML = m[1] + '<span class="n">' + m[2].replace(/[()]/g, '') + '</span>'; }
          else { div.textContent = it.label; }
          div.addEventListener('mousedown', function (e) { e.preventDefault(); hide(); onPick(it); });
          list.appendChild(div);
        });
      }
      function fetchSuggestions(q) {
        lastQuery = q;
        fetch(urlFn(q)).then(function (r) { return r.json(); })
          .then(function (data) {
            if (q !== lastQuery) return;
            items = data; activeIdx = -1;
            if (items.length) { render(); show(); } else { hide(); }
          }).catch(function () { hide(); });
      }
      box.addEventListener('input', function () {
        var q = box.value.trim();
        clearTimeout(timer);
        if (q.length < 2) { hide(); return; }
        timer = setTimeout(function () { fetchSuggestions(q); }, 200);
      });
      box.addEventListener('keydown', function (e) {
        if (list.style.display !== 'block') return;
        if (e.key === 'ArrowDown') { e.preventDefault();
          activeIdx = Math.min(activeIdx + 1, items.length - 1); render(); show(); }
        else if (e.key === 'ArrowUp') { e.preventDefault();
          activeIdx = Math.max(activeIdx - 1, 0); render(); show(); }
        else if (e.key === 'Enter' && activeIdx >= 0) { e.preventDefault();
          var it = items[activeIdx]; hide(); onPick(it); }
        else if (e.key === 'Escape') { hide(); }
      });
      box.addEventListener('blur', function () { setTimeout(hide, 150); });
      box.addEventListener('focus', function () { if (items.length) show(); });
      return function trigger(q) { clearTimeout(timer); fetchSuggestions(q); };
    }

    var rqBox = document.getElementById('rqbox'), rqList = document.getElementById('rqsuggest');
    // Suggests ONLY real caregiver surnames from lanfam.Resource --
    // never resource numbers themselves, since those aren't
    // meaningfully "completable" the way a name is. If you're typing
    // a number, these queries simply return nothing and stay quiet.
    attachAutocomplete(rqBox, rqList,
      function (q) { return 'NameSuggest.aspx?mode=ressurname&q=' + encodeURIComponent(q); },
      function (it) { rqBox.value = it.value; rqBox.form.submit(); });
  })();
  </script>
</asp:Content>
