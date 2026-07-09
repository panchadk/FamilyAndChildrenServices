<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Search — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Results.Text = "<div class='warn'>Your account is not in the archive readers group. Contact IT to request access.</div>"; return; }

    // ---- quick search box: route by pattern ----
    string q = (Request["q"] ?? "").Trim();
    string sur = (Request["surname"] ?? "").Trim();
    string giv = (Request["given"] ?? "").Trim();
    string cno = (Request["caseno"] ?? "").Trim();
    string fno = (Request["famno"] ?? "").Trim();
    string oldRef = "";  // old-style cross-reference / brief-service number
    if (q != "")
    {
        if (Regex.IsMatch(q, @"^\d{4,5}[A-Za-z]?$")) cno = q;               // 14503A
        else if (Regex.IsMatch(q, @"^[SsJj]\d{4,6}$")) fno = q;             // S001670
        else if (Regex.IsMatch(q, @"^[A-Za-z]{0,4}\d{3,9}[A-Za-z]{0,2}$"))  // 0004779, 78LB01304, A1233, F3573
        { oldRef = q; sur = q; }  // try both: it might be a name OR an old reference number
        else if (q.Contains(","))                                            // Surname, Given
        { var p = q.Split(','); sur = p[0].Trim(); giv = p[1].Trim(); }
        else sur = q;   // bare word or phrase: search as surname prefix.
                        // (Word order for "First Last" vs "Last First" is
                        // genuinely ambiguous without a comma -- guessing
                        // wrong would silently return nothing, which is the
                        // exact failure this fix is meant to prevent. Use
                        // the Surname/Given boxes below for a two-word name.)
    }

    // ---- stat tiles (cheap, cached per app lifetime) ----
    Tiles.Text = StatTiles();

    if (sur == "" && giv == "" && cno == "" && fno == "") return;
    Db.Audit(Context, "SEARCH",
        "surname=" + sur + "; given=" + giv + "; caseno=" + cno + "; famno=" + fno);

    var sb = new StringBuilder();
    using (var cn = Db.Open())
    {
        if (cno != "")
            using (var cmd = new SqlCommand(
                "SELECT TOP 50 caseno, surname, givename, birthdate, sex, admit_date " +
                "FROM lanfam.Child WHERE caseno LIKE @c ORDER BY caseno", cn))
            { cmd.Parameters.AddWithValue("@c", cno + "%");
              RenderChildren(cmd, sb, "Children in care — case number match"); }

        if (oldRef != "")
        {
            using (var cmd = new SqlCommand(
                "SELECT TOP 20 refno, refcode, surname, given, filed_date FROM lanfam.CrossRef " +
                "WHERE refno LIKE @r ORDER BY filed_date DESC", cn))
            {
                cmd.Parameters.AddWithValue("@r", oldRef + "%");
                var rows = new StringBuilder(); int cn3 = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { cn3++;
                      rows.Append("<tr><td><a class='link caseno' href='CrossReference.aspx?ref=" +
                          Server.UrlEncode(Db.H(r[0])) + "'>" + Db.H(r[0]) +
                          (Db.H(r[1]) != "" ? "-" + Db.H(r[1]) : "") + "</a></td><td>" + Db.H(r[2]) +
                          ", " + Db.H(r[3]) + "</td><td class='date'>" + Db.D(r[4]) + "</td></tr>"); }
                if (cn3 > 0)
                    sb.Append("<div class='card tabbed'><h2>Looks like an old reference number (" + cn3 +
                        " match" + (cn3 == 1 ? "" : "es") + ")</h2>" +
                        "<table class='ledger'><tr><th>Ref #</th><th>Name</th><th>Filed</th></tr>" +
                        rows + "</table><p class='hint'><a class='link' href='CrossReference.aspx?ref=" +
                        Server.UrlEncode(oldRef) + "'>Open full cross-reference search &#8594;</a></p></div>");
            }
            using (var cmd = new SqlCommand(
                "SELECT TOP 20 refno, surname, given, xref_to FROM lanfam.NameIndex " +
                "WHERE refno LIKE @r ORDER BY surname, given", cn))
            {
                cmd.Parameters.AddWithValue("@r", oldRef + "%");
                var rows = new StringBuilder(); int cn4 = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { cn4++;
                      string xt = Db.H(r[3]);
                      rows.Append("<tr><td><a class='link caseno' href='CrossReference.aspx?ref=" +
                          Server.UrlEncode(Db.H(r[0])) + "'>" + Db.H(r[0]) + "</a></td><td>" + Db.H(r[1]) +
                          ", " + Db.H(r[2]) + "</td><td>" +
                          (xt != "" ? "<a class='link' href='CrossReference.aspx?ref=" +
                              Server.UrlEncode(xt) + "'>" + xt + "</a>" : "&#8212;") + "</td></tr>"); }
                if (cn4 > 0)
                    sb.Append("<div class='card tabbed'><h2>Also in the person name index (" + cn4 + ")</h2>" +
                        "<table class='ledger'><tr><th>Ref #</th><th>Name</th><th>Linked to</th></tr>" +
                        rows + "</table></div>");
            }
        }

        if (fno != "")
        {
            // An "S/J + digits" string is ambiguous by format alone: the
            // SAME shape (e.g. S011368) is used both for family/case
            // numbers (FamilyIndex.famno) AND for a referral's own filing
            // number printed on the paper form (Referral.caseno). These
            // are two different fields -- checking only one silently
            // misses the other whenever someone has, say, the physical
            // Record of Referral in hand rather than a case file number.
            using (var cmd = new SqlCommand(
                "SELECT TOP 50 f.famno, " +
                "(SELECT COUNT(*) FROM lanfam.Referral r WHERE r.famno=f.famno), " +
                "(SELECT COUNT(*) FROM lanfam.FamilyHistory h WHERE h.famno=f.famno) " +
                "FROM lanfam.FamilyIndex f WHERE f.famno LIKE @f ORDER BY f.famno", cn))
            {
                cmd.Parameters.AddWithValue("@f", fno + "%");
                var rows = new StringBuilder(); int fcnt = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { fcnt++;
                      rows.Append("<tr><td><a class='caseno' href='Family.aspx?famno=" +
                          Server.UrlEncode(Db.H(r[0])) + "'>" + Db.H(r[0]) +
                          "</a></td><td class='num'>" + Db.H(r[1]) +
                          "</td><td class='num'>" + Db.H(r[2]) + "</td></tr>"); }
                if (fcnt > 0)
                    sb.Append("<div class='card'><h2>Families &#8212; number match</h2>" +
                        "<table class='ledger'><tr><th>Family no</th><th>Referrals</th><th>History rows</th></tr>" +
                        rows + "</table></div>");
            }
            using (var cmd = new SqlCommand(
                "SELECT TOP 50 caseno, famno, ref_date, ref_time, surname, given " +
                "FROM lanfam.Referral WHERE caseno LIKE @f ORDER BY ref_date DESC", cn))
            {
                cmd.Parameters.AddWithValue("@f", fno + "%");
                var rows = new StringBuilder(); int rcnt = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { rcnt++;
                      string rfamno = Db.H(r[1]);
                      rows.Append("<tr><td class='caseno'>" + Db.H(r[0]) + "</td><td>" +
                          Db.H(r[4]) + ", " + Db.H(r[5]) + "</td><td class='date'>" + Db.D(r[2]) +
                          " " + Db.H(r[3]) + "</td><td>" +
                          (rfamno != "" ? "<a class='link caseno' href='Family.aspx?famno=" +
                              Server.UrlEncode(rfamno) + "'>" + rfamno + "</a>" : "&#8212;") + "</td></tr>"); }
                if (rcnt > 0)
                    sb.Append("<div class='card tabbed'><h2>Referral filing numbers &#8212; number match</h2>" +
                        "<p class='hint'>This is the S.O. number printed on the physical Record of " +
                        "Referral &#8212; a different number space from a family/case number, even " +
                        "though the format looks the same. Click through to see the whole family's file.</p>" +
                        "<table class='ledger'><tr><th>Referral #</th><th>Name</th><th>Date</th><th>Family</th></tr>" +
                        rows + "</table></div>");
            }
        }

        if (sur != "" || giv != "")
        {
            using (var cmd = new SqlCommand(
                "SELECT TOP 50 caseno, surname, givename, birthdate, sex, admit_date " +
                "FROM lanfam.Child WHERE (@s='' OR surname LIKE @s) AND (@g='' OR givename LIKE @g) " +
                "ORDER BY surname, givename", cn))
            { cmd.Parameters.AddWithValue("@s", sur == "" ? "" : sur + "%");
              cmd.Parameters.AddWithValue("@g", giv == "" ? "" : giv + "%");
              RenderChildren(cmd, sb, "Children in care"); }

            // ---- referrals by the name on the form -- this table (14,161
            // rows) was never actually queried by the main surname search
            // before; someone could be all over the Referral table and
            // still show "no results" here despite being fully searchable
            // on the dedicated Referrals page. Every name search should
            // check this table too. ----
            using (var cmd = new SqlCommand(
                "SELECT TOP 50 caseno, famno, ref_date, ref_time, surname, given " +
                "FROM lanfam.Referral WHERE (@s='' OR surname LIKE @s) AND (@g='' OR given LIKE @g) " +
                "ORDER BY ref_date DESC", cn))
            {
                cmd.Parameters.AddWithValue("@s", sur == "" ? "" : sur + "%");
                cmd.Parameters.AddWithValue("@g", giv == "" ? "" : giv + "%");
                var rows = new StringBuilder(); int rn = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { rn++;
                      string rcaseno = Db.H(r[0]), rfamno = Db.H(r[1]);
                      rows.Append("<tr><td>" +
                          (rcaseno != "" ? "<a class='link caseno' href='CrossReference.aspx?ref=" +
                              Server.UrlEncode(rcaseno) + "'>" + rcaseno + "</a>" : "&#8212;") +
                          "</td><td>" + Db.H(r[4]) + ", " + Db.H(r[5]) + "</td><td class='date'>" +
                          Db.D(r[2]) + " " + Db.H(r[3]) + "</td><td>" +
                          (rfamno != "" ? "<a class='link caseno' href='Family.aspx?famno=" +
                              Server.UrlEncode(rfamno) + "'>" + rfamno + "</a>" : "&#8212;") +
                          "</td></tr>"); }
                if (rn > 0)
                    sb.Append("<div class='card tabbed'><h2>Referrals (" + rn + (rn == 50 ? "+" : "") + ")</h2>" +
                        "<p class='hint'>Every referral naming this person, newest first. " +
                        "<a class='link' href='Referrals.aspx?name=" +
                        Server.UrlEncode(sur != "" ? sur : giv) +
                        "'>Open full referral search &#8594;</a></p>" +
                        "<table class='ledger'><tr><th>Referral #</th><th>Name</th><th>Date</th><th>Family</th></tr>" +
                        rows + "</table></div>");
            }

            using (var cmd = new SqlCommand(
                "SELECT TOP 500 refno, surname, given, xref_to " +
                "FROM lanfam.NameIndex WHERE (@s='' OR surname LIKE @s) AND (@g='' OR given LIKE @g) " +
                "ORDER BY surname, given", cn))
            {
                cmd.Parameters.AddWithValue("@s", sur == "" ? "" : sur + "%");
                cmd.Parameters.AddWithValue("@g", giv == "" ? "" : giv + "%");
                sb.Append("<div class='card'><h2>Person name index (all roles)</h2>" +
                    "<p class='hint'>Every person LANFAM tracked, however they were involved. " +
                    "<b>Linked to</b> is a cross-reference pointer &#8212; someone can appear here " +
                    "without being the primary subject of any file. Click a linked number to see " +
                    "the connection.</p>" +
                    "<input class='tablefilter' placeholder='Filter these results&#8230;' />" +
                    "<table class='ledger'><tr><th>Ref #</th><th>Surname</th><th>Given</th><th>Linked to</th></tr>");
                int n = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { n++;
                      string xrefTo = Db.H(r[3]);
                      sb.Append("<tr><td><a class='link caseno' href='CrossReference.aspx?ref=" +
                          Server.UrlEncode(Db.H(r[0])) + "'>" + Db.H(r[0]) + "</a></td><td>" + Db.H(r[1]) +
                          "</td><td>" + Db.H(r[2]) + "</td><td>" +
                          (xrefTo != "" ? "<a class='link' href='CrossReference.aspx?ref=" +
                              Server.UrlEncode(xrefTo) + "'>" + xrefTo + "</a>" : "&#8212;") +
                          "</td></tr>"); }
                if (n == 0) sb.Append("<tr><td colspan='4'>No matches in the name index.</td></tr>");
                if (n == 500) sb.Append("<tr><td colspan='4' class='hint'>500-row limit reached &#8212; " +
                    "add a given name above to narrow a common surname like this one.</td></tr>");
                sb.Append("</table></div>");
            }

            // ---- also check the cross-reference ledger ----
            using (var cmd = new SqlCommand(
                "SELECT TOP 20 refno, refcode, surname, given, filed_date FROM lanfam.CrossRef " +
                "WHERE (@s='' OR surname LIKE @s) AND (@g='' OR given LIKE @g) " +
                "ORDER BY filed_date DESC", cn))
            {
                cmd.Parameters.AddWithValue("@s", sur == "" ? "" : sur + "%");
                cmd.Parameters.AddWithValue("@g", giv == "" ? "" : giv + "%");
                var crossHits = new StringBuilder();
                int cn2 = 0;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                    { cn2++;
                      crossHits.Append("<tr><td><a class='link caseno' href='CrossReference.aspx?ref=" +
                          Server.UrlEncode(Db.H(r[0])) + "'>" + Db.H(r[0]) +
                          (Db.H(r[1]) != "" ? "-" + Db.H(r[1]) : "") + "</a></td><td>" +
                          Db.H(r[2]) + ", " + Db.H(r[3]) + "</td><td class='date'>" +
                          Db.D(r[4]) + "</td></tr>"); }
                if (cn2 > 0)
                {
                    sb.Append("<div class='card tabbed'><h2>Cross references &amp; old brief services (" +
                        cn2 + (cn2 == 20 ? "+" : "") + ")</h2>" +
                        "<p class='hint'>Found in the old cross-reference ledger &#8212; may be linked " +
                        "into another file rather than filed on its own. <a class='link' href='CrossReference.aspx?q=" +
                        Server.UrlEncode(sur != "" ? sur : giv) + "'>Open full cross-reference search &#8594;</a></p>" +
                        "<table class='ledger'><tr><th>Ref #</th><th>Name</th><th>Filed</th></tr>" +
                        crossHits + "</table></div>");
                }
            }
        }
    }
    Results.Text = sb.ToString();
}

static string _tiles;
string StatTiles()
{
    if (_tiles != null) return _tiles;
    try
    {
        using (var cn = Db.Open())
        using (var cmd = new SqlCommand(
            "SELECT (SELECT COUNT(*) FROM lanfam.Child)," +
            "(SELECT COUNT(*) FROM lanfam.FamilyIndex)," +
            "(SELECT COUNT(*) FROM lanfam.Referral)," +
            "(SELECT COUNT(*) FROM lanfam.ChildHistory)," +
            "(SELECT COUNT(*) FROM lanfam.Resource)", cn))
        using (var r = cmd.ExecuteReader())
        {
            r.Read();
            _tiles = "<div class='tiles'>" +
                Tile(r.GetInt32(0), "children in care", "Browse.aspx") +
                Tile(r.GetInt32(1), "families", "Families.aspx") +
                Tile(r.GetInt32(2), "referrals", "Referrals.aspx") +
                Tile(r.GetInt32(3), "placement events", "Placements.aspx") +
                Tile(r.GetInt32(4), "resource homes", "Resource.aspx") + "</div>";
        }
    }
    catch { _tiles = ""; }
    return _tiles;
}
string Tile(int n, string label, string href)
{ return "<a class='tile' href='" + href + "'><b>" + n.ToString("N0") +
         "</b><span>" + label + "</span></a>"; }

static string _decades;
string DecadeBar()
{
    if (_decades != null) return _decades;
    try
    {
        var counts = new System.Collections.Generic.SortedDictionary<int,int>();
        using (var cn = Db.Open())
        using (var cmd = new SqlCommand(
            "SELECT (YEAR(d)/10)*10, COUNT(*) FROM (" +
            "SELECT admit_date d FROM lanfam.Child WHERE admit_date IS NOT NULL " +
            "UNION ALL SELECT ref_date FROM lanfam.Referral WHERE ref_date IS NOT NULL " +
            "UNION ALL SELECT event_date FROM lanfam.ChildHistory WHERE event_date IS NOT NULL" +
            ") u WHERE YEAR(d) BETWEEN 1970 AND 2029 GROUP BY (YEAR(d)/10)*10", cn))
        using (var r = cmd.ExecuteReader())
            while (r.Read()) counts[r.GetInt32(0)] = r.GetInt32(1);
        int max = 1; foreach (var v in counts.Values) if (v > max) max = v;
        var sb = new StringBuilder(
            "<div class='card'><h2>Archive activity by decade</h2><div class='decades'>");
        foreach (var kv in counts)
        {
            int h = Math.Max(3, (int)(78.0 * kv.Value / max));
            sb.Append("<a class='decade' href='Placements.aspx?from=" + kv.Key +
                "-01-01&to=" + (kv.Key + 9) + "-12-31'><i>" + kv.Value.ToString("N0") +
                "</i><span class='bar' style='height:" + h + "px'></span><em>" +
                kv.Key + "s</em></a>");
        }
        sb.Append("</div><p class='hint'>Admissions, referrals, and placement events " +
            "combined. Click a decade to see its placement activity.</p></div>");
        _decades = sb.ToString();
    }
    catch { _decades = ""; }
    return _decades;
}

void RenderChildren(SqlCommand cmd, StringBuilder sb, string title)
{
    sb.Append("<div class='card tabbed'><h2>" + title + "</h2>" +
        "<table class='ledger'><tr><th>Case no</th><th>Surname</th><th>Given</th>" +
        "<th>Birth</th><th>Sex</th><th>Admitted</th></tr>");
    int n = 0;
    using (var r = cmd.ExecuteReader())
        while (r.Read())
        { n++;
          sb.Append("<tr><td><a class='caseno' href='Child.aspx?caseno=" +
              Server.UrlEncode(Db.H(r[0])) + "'>" + Db.H(r[0]) + "</a></td><td>" +
              Db.H(r[1]) + "</td><td>" + Db.H(r[2]) + "</td><td class='date'>" +
              Db.D(r[3]) + "</td><td>" + Db.H(r[4]) + "</td><td class='date'>" +
              Db.D(r[5]) + "</td></tr>"); }
    if (n == 0) sb.Append("<tr><td colspan='6'>No matching children in care.</td></tr>");
    sb.Append("</table></div>");
}
</script>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">
  <% if ((Request["q"] ?? "") == "" && (Request["surname"] ?? "") == "" &&
         (Request["caseno"] ?? "") == "" && (Request["famno"] ?? "") == "" &&
         (Request["given"] ?? "") == "") { %>
  <div class="hero">
    <div class="est">Est. 1970 &#183; digitized 2026</div>
    <h1>The LANFAM Archive</h1>
    <div class="rule"></div>
    <p>Fifty years of family and children&#8217;s services records &#8212; every child,
       family, referral, placement, and foster home from the agency&#8217;s DOS-era
       case system, preserved and searchable.</p>
  </div>
  <% } else { %><h1>Search the archive</h1><% } %>
  <asp:Literal ID="Tiles" runat="server" />
  <div class="card tabbed">
    <form method="get" action="Default.aspx">
      <div class="searchbar">
        <div class="ac-wrap" style="position:relative;flex:1 1 180px">
          <input type="text" name="surname" id="surbox" autocomplete="off" placeholder="Surname"
                 value="<%= Db.H(Request["surname"]) %>" style="width:100%" />
          <div id="sursuggest" class="ac-list"></div>
        </div>
        <div class="ac-wrap" style="position:relative;flex:1 1 180px">
          <input type="text" name="given" id="givbox" autocomplete="off" placeholder="Given name"
                 value="<%= Db.H(Request["given"]) %>" style="width:100%" />
          <div id="givsuggest" class="ac-list"></div>
        </div>
        <input type="text" name="caseno" placeholder="Case no (e.g. 14503A)"
               value="<%= Db.H(Request["caseno"]) %>" />
        <input type="text" name="famno" placeholder="Family no (e.g. S001670)"
               value="<%= Db.H(Request["famno"]) %>" />
        <input type="submit" value="SEARCH" />
      </div>
      <p class="hint">Prefix matching &#8212; &#8220;Bel&#8221; finds Beltman. Or browse:
      surnames A&#8211;Z under <a class="link" href="Browse.aspx">Browse children</a>.
      Click any column header to sort results. Every search is logged.</p>
    </form>
    <div class="azstrip">
      <% foreach (char ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ") { %>
        <a href="Browse.aspx?letter=<%= ch %>"><%= ch %></a>
      <% } %>
    </div>
  </div>
  <% if ((Request["q"] ?? "") == "" && (Request["surname"] ?? "") == "" &&
         (Request["caseno"] ?? "") == "" && (Request["famno"] ?? "") == "" &&
         (Request["given"] ?? "") == "") { %>
  <div class="sections">
    <a class="scard" href="Referrals.aspx"><b>Referrals</b>
      <span>Search words inside 14,156 referral narratives &#8212; a name, a school, a street.</span></a>
    <a class="scard" href="Placements.aspx"><b>Placement events</b>
      <span>Every admission, move, return and discharge, filterable by type and date.</span></a>
    <a class="scard" href="Families.aspx"><b>Families</b>
      <span>Find a family by number or by the people named on its referrals.</span></a>
    <a class="scard" href="Codes.aspx"><b>Code book</b>
      <span>What every code meant &#8212; service reasons, religions, geographies.</span></a>
  </div>
  <%= DecadeBar() %>
  <% } %>
  <asp:Literal ID="Results" runat="server" />

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
    // Reusable typeahead: wire an <input> + a suggestion <div> together.
    // urlFn(query) builds the NameSuggest.aspx URL for the current box.
    // onPick(item) decides what happens when a suggestion is chosen
    // (fill only, fill+move to next field, or fill+submit).
    function attachAutocomplete(box, list, urlFn, onPick) {
      if (!box || !list) return function () {};
      var timer = null, items = [], activeIdx = -1, lastQuery = null;

      function hide() { list.style.display = 'none'; activeIdx = -1; }
      function show() { if (items.length) list.style.display = 'block'; }

      function render() {
        list.innerHTML = '';
        items.forEach(function (it, i) {
          var m = it.label.match(/^(.*)\s(\(\d+ records?\))$/);
          var div = document.createElement('div');
          div.className = 'ac-item' + (i === activeIdx ? ' active' : '');
          if (m) { div.innerHTML = m[1] + '<span class="n">' + m[2].replace(/[()]/g, '') + '</span>'; }
          else { div.textContent = it.label; }
          div.addEventListener('mousedown', function (e) {
            e.preventDefault();
            hide();
            onPick(it);
          });
          list.appendChild(div);
        });
      }

      function fetchSuggestions(q) {
        lastQuery = q;
        fetch(urlFn(q))
          .then(function (r) { return r.json(); })
          .then(function (data) {
            if (q !== lastQuery) return;
            items = data; activeIdx = -1;
            if (items.length) { render(); show(); } else { hide(); }
          })
          .catch(function () { hide(); });
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

      // Exposed so another control (e.g. the surname box, after a pick)
      // can proactively populate this box's suggestions without
      // requiring the user to type anything here first.
      return function trigger(q) { clearTimeout(timer); fetchSuggestions(q); };
    }

    var surBox = document.getElementById('surbox'), surList = document.getElementById('sursuggest');
    var givBox = document.getElementById('givbox'), givList = document.getElementById('givsuggest');

    // Given box: suggest given names scoped to whatever surname is
    // currently typed (if any), so it narrows to real people rather
    // than every given name in the archive. Picking one submits.
    var triggerGiven = attachAutocomplete(givBox, givList,
      function (q) {
        return 'NameSuggest.aspx?mode=given&q=' + encodeURIComponent(q) +
               '&surname=' + encodeURIComponent(surBox ? surBox.value.trim() : '');
      },
      function (it) { givBox.value = it.value; givBox.form.submit(); });

    // Surname box: suggest surnames; picking one fills the box, moves
    // focus to Given, and immediately shows every given name that
    // belongs to that surname -- no typing required to see them,
    // since the surname alone is often already a small, specific set.
    attachAutocomplete(surBox, surList,
      function (q) { return 'NameSuggest.aspx?mode=surname&q=' + encodeURIComponent(q); },
      function (it) {
        surBox.value = it.value;
        if (givBox) { givBox.focus(); triggerGiven(''); }
      });
  })();
  </script>
</asp:Content>
