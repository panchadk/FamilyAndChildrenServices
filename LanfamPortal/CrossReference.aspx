<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Cross references — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
const int PageSize = 50;
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }

    string q    = (Request["q"] ?? "").Trim();     // name or free text (checks name + address + notes)
    string refno = (Request["ref"] ?? "").Trim();  // exact / prefix reference number
    int page; if (!int.TryParse(Request["p"], out page) || page < 1) page = 1;
    bool any = q != "" || refno != "";

    // A two-word query is almost always "Surname Given" or "Given Surname" --
    // split it so both orders are tried, rather than gluing it into one
    // prefix that will never match a single-word surname field.
    string qWord1 = q, qWord2 = "";
    if (q.Contains(",")) { var p = q.Split(','); qWord1 = p[0].Trim(); qWord2 = p.Length>1 ? p[1].Trim() : ""; }
    else if (q.Contains(" ")) { var p = q.Trim().Split(new[]{' '}, 2); qWord1 = p[0].Trim(); qWord2 = p[1].Trim(); }

    var sb = new StringBuilder();
    sb.Append("<h1>Cross references &amp; old brief services</h1>" +
        "<div class='card tabbed'><p class='hint'>" +
        "This is LANFAM's old cross-reference ledger &#8212; where a person or family " +
        "was linked to another file without necessarily being the primary subject of " +
        "it (a relative, a partner, a co-referral). It also covers old brief-service " +
        "numbers filed before the current system. Every record ends with a " +
        "<b>filed date</b> &#8212; the same one staff used to know which year's paper " +
        "folder to pull from the vault.</p>" +
        "<form method='get'><div class='searchbar'>" +
        "<div class='ac-wrap' style='position:relative;flex:1 1 260px'>" +
        "<input type='text' name='q' id='qbox' autocomplete='off' placeholder='Name, address, or any word in the notes' value='" +
        Db.H(q) + "' style='width:100%' />" +
        "<div id='qsuggest' class='ac-list'></div></div>" +
        "<input type='text' name='ref' placeholder='Reference number (e.g. 0004779)' value='" +
        Db.H(refno) + "' style='max-width:220px' />" +
        "<input type='submit' value='SEARCH' /></div>" +
        "<p class='hint'>A full name (e.g. &#8220;John Smith&#8221;) matches that person " +
        "precisely first. A single word also searches address and notes text more " +
        "broadly, which can return many results for a common name. Start typing a " +
        "name for suggestions.</p></form></div>");

    if (any)
    {
        Db.Audit(Context, "SEARCH_CROSSREF", "q=" + q + "; ref=" + refno);
        using (var cn = Db.Open())
        {
            // ==================================================================
            // SECTION 1: precise, name-based results -- shown FIRST, since this
            // is almost always what someone searching a specific person wants.
            // Each match resolves and shows its own filed date inline, so
            // finding "is this person cross-referenced, and when was it filed"
            // takes one search, not a chain of clicks through separate pages.
            // ==================================================================
            if (refno != "")
            {
                using (var nc = new SqlCommand(
                    "SELECT n.refno, n.surname, n.given, n.xref_to, cr.filed_date " +
                    "FROM lanfam.NameIndex n " +
                    "LEFT JOIN lanfam.CrossRef cr ON cr.refno = n.refno " +
                    "WHERE n.refno LIKE @r ORDER BY n.surname, n.given", cn))
                {
                    nc.Parameters.AddWithValue("@r", refno + "%");
                    var rows = new StringBuilder();
                    int nn = 0;
                    using (var r = nc.ExecuteReader())
                        while (r.Read())
                        { nn++;
                          string xt = r.IsDBNull(3) ? "" : r.GetString(3);
                          rows.Append("<tr><td><a class='link caseno' href='CrossReference.aspx?ref=" +
                              Server.UrlEncode(r.IsDBNull(0)?"":r.GetString(0)) + "'>" +
                              Db.H(r.IsDBNull(0)?"":r.GetString(0)) + "</a></td><td>" +
                              Db.H(r.IsDBNull(1)?"":r.GetString(1)) + ", " + Db.H(r.IsDBNull(2)?"":r.GetString(2)) +
                              "</td><td>" + (r.IsDBNull(4) ? "&#8212;" : Db.D(r[4])) + "</td><td>" +
                              (xt != "" ? "<a class='link' href='CrossReference.aspx?ref=" +
                                  Server.UrlEncode(xt) + "'>" + Db.H(xt) + "</a>" : "&#8212;") + "</td></tr>"); }
                    if (nn > 0)
                        sb.Append("<div class='card tabbed'><h2>Found in the person name index (" + nn +
                            ")</h2><table class='ledger'><tr><th>Ref #</th><th>Name</th><th>Filed</th><th>Linked to</th></tr>" +
                            rows + "</table></div>");
                }
            }

            if (q != "")
            {
              try
              {
                string w1 = qWord1 + "%", w2 = qWord2 != "" ? qWord2 + "%" : null;
                var matches = new System.Collections.Generic.List<string[]>(); // [refno, surname, given, xref_to]
                // Two-word query: require BOTH words together (as a name pair,
                // in either order) -- NOT "either word matches either field",
                // which is what was pulling in every John-anything and every
                // Smith-anything as 1,500+ separate unrelated matches.
                string matchWhere = w2 != null
                    ? "(surname LIKE @w1 AND given LIKE @w2) OR (surname LIKE @w2 AND given LIKE @w1)"
                    : "surname LIKE @w1 OR given LIKE @w1";
                using (var nc = new SqlCommand(
                    "SELECT refno, surname, given, xref_to FROM lanfam.NameIndex " +
                    "WHERE " + matchWhere +
                    " ORDER BY surname, given", cn))
                {
                    nc.Parameters.AddWithValue("@w1", w1);
                    if (w2 != null) nc.Parameters.AddWithValue("@w2", w2);
                    using (var r = nc.ExecuteReader())
                        while (r.Read())
                            matches.Add(new string[] {
                                r.IsDBNull(0) ? "" : r.GetString(0),
                                r.IsDBNull(1) ? "" : r.GetString(1),
                                r.IsDBNull(2) ? "" : r.GetString(2),
                                r.IsDBNull(3) ? "" : r.GetString(3) });
                }

                var withLinks = new System.Collections.Generic.List<string[]>();
                foreach (var m in matches) if (m[3] != "") withLinks.Add(m);

                if (withLinks.Count > 0)
                {
                    var groups = new StringBuilder();
                    int groupCount = 0;
                    foreach (var m in withLinks)
                    {
                        string myRefno = m[0], mySur = m[1], myGiv = m[2], myXref = m[3];

                        // Resolve THIS person's filed date. Whether the CrossRef
                        // ledger record is keyed under this person's OWN number or
                        // under the number they point to (xref_to) depends on which
                        // side of the pair they are -- the "primary" case subject's
                        // xref_to matches the ledger, but someone cross-referenced
                        // INTO that file has the ledger number as their OWN refno.
                        // Check both so it resolves correctly either way.
                        string myFiled = null;
                        using (var fc = new SqlCommand(
                            "SELECT TOP 1 filed_date FROM lanfam.CrossRef " +
                            "WHERE refno = @own OR refno = @x ORDER BY CASE WHEN refno=@own THEN 0 ELSE 1 END", cn))
                        {
                            fc.Parameters.AddWithValue("@own", myRefno);
                            fc.Parameters.AddWithValue("@x", myXref);
                            var res = fc.ExecuteScalar();
                            if (res != null && res != DBNull.Value) myFiled = Convert.ToDateTime(res).ToString("yyyy-MM-dd");
                        }

                        var connected = new StringBuilder();
                        int cc = 0;
                        using (var nc2 = new SqlCommand(
                            "SELECT n.refno, n.surname, n.given, n.xref_to, " +
                            "COALESCE(cr1.filed_date, cr2.filed_date) AS filed_date " +
                            "FROM lanfam.NameIndex n " +
                            "LEFT JOIN lanfam.CrossRef cr1 ON cr1.refno = n.refno " +
                            "LEFT JOIN lanfam.CrossRef cr2 ON cr2.refno = n.xref_to " +
                            "WHERE n.refno = @p", cn))
                        {
                            nc2.Parameters.AddWithValue("@p", myXref);
                            using (var r = nc2.ExecuteReader())
                                while (r.Read())
                                {
                                    cc++;
                                    connected.Append("<tr><td><a class='link caseno' href='CrossReference.aspx?ref=" +
                                        Server.UrlEncode(r.IsDBNull(0)?"":r.GetString(0)) + "'>" +
                                        Db.H(r.IsDBNull(0)?"":r.GetString(0)) + "</a></td><td>" +
                                        Db.H(r.IsDBNull(1)?"":r.GetString(1)) + ", " +
                                        Db.H(r.IsDBNull(2)?"":r.GetString(2)) + "</td><td>" +
                                        (r.IsDBNull(4) ? "&#8212;" : Db.D(r[4])) + "</td></tr>");
                                }
                        }
                        if (cc > 0)
                        {
                            groupCount++;
                            string name = (mySur + myGiv) != "" ? Db.H(mySur) + ", " + Db.H(myGiv) : "(name not on file)";
                            groups.Append("<div class='card tabbed'><h2>" + name +
                                " <span class='caseno'>" + Db.H(myRefno) + "</span></h2>" +
                                "<p class='hint'>Cross-referenced under <a class='link caseno' href='CrossReference.aspx?ref=" +
                                Server.UrlEncode(myXref) + "'>" + Db.H(myXref) + "</a>" +
                                (myFiled != null ? " &#8212; <b>filed " + myFiled + "</b>" : " &#8212; no filed date on record") +
                                "</p><table class='ledger'><tr><th>Ref #</th><th>Connected to</th><th>Filed</th></tr>" +
                                connected + "</table></div>");
                        }
                    }
                    if (groupCount > 0)
                        sb.Append("<div class='card tabbed' style='border-top-color:var(--stamp)'>" +
                            "<h2 style='color:var(--stamp)'>Exact matches &amp; their connections (" + groupCount + ")</h2>" +
                            "<p class='hint'>The filed date is resolved right here &#8212; no need to click through.</p>" +
                            "</div>" + groups.ToString());
                }
              }
              catch (Exception ex)
              {
                  sb.Append("<div class='warn'>Could not check cross-referenced connections: " +
                      Db.H(ex.Message) + "</div>");
              }
            }

            // ==================================================================
            // SECTION 2: broader free-text ledger search -- moved below the
            // precise results, and tightened for a two-word query so a common
            // name like "John Smith" doesn't flood the page with every record
            // that merely contains "John" OR "Smith" somewhere. A two-word
            // query now requires BOTH words together (as name or as an exact
            // phrase in the notes), not either word alone.
            // ==================================================================
            string where = " WHERE 1=1";
            if (refno != "") where += " AND refno LIKE @r";
            if (q != "") {
                if (qWord2 != "")
                    where += " AND ((surname LIKE @q1 AND given LIKE @q2) " +
                             "OR (surname LIKE @q2 AND given LIKE @q1) " +
                             "OR address LIKE @qc OR notes LIKE @qc)";
                else
                    where += " AND (surname LIKE @q1 OR given LIKE @q1 OR address LIKE @qc OR notes LIKE @qc)";
            }
            Action<SqlCommand> bind = c => {
                if (refno != "") c.Parameters.AddWithValue("@r", refno + "%");
                if (q != "") {
                    c.Parameters.AddWithValue("@q1", qWord1 + "%");
                    if (qWord2 != "") c.Parameters.AddWithValue("@q2", qWord2 + "%");
                    c.Parameters.AddWithValue("@qc", "%" + q + "%");
                }
            };

            int total;
            using (var c = new SqlCommand("SELECT COUNT(*) FROM lanfam.CrossRef" + where, cn))
            { bind(c); total = (int)c.ExecuteScalar(); }

            sb.Append("<div class='card' style='margin-top:30px'><h2>" + total.ToString("N0") +
                (q != "" ? " broader text match" + (total==1?"":"es") + " in the ledger" : " matching records") +
                (total > PageSize ? " &#8212; page " + page : "") + "</h2>");
            if (q != "" && total > PageSize)
                sb.Append("<p class='hint'>This searches every word in every record's address and notes, so " +
                    "common names can return a lot. The exact matches above are usually what you want; " +
                    "use this list only if you're hunting for a specific mention in the notes text.</p>");

            using (var c = new SqlCommand(
                "SELECT refno, refcode, surname, given, address, notes, filed_date " +
                "FROM lanfam.CrossRef" + where +
                " ORDER BY filed_date DESC OFFSET @off ROWS FETCH NEXT @ps ROWS ONLY", cn))
            {
                bind(c);
                c.Parameters.AddWithValue("@off", (page - 1) * PageSize);
                c.Parameters.AddWithValue("@ps", PageSize);
                int n = 0;
                using (var r = c.ExecuteReader())
                    while (r.Read())
                    {
                        n++;
                        sb.Append("<div class='card tabbed'><h2><a class='link caseno' href='CrossReference.aspx?ref=" +
                            Server.UrlEncode(Db.H(r[0])) + "'>Ref# " + Db.H(r[0]) +
                            (Db.H(r[1]) != "" ? "-" + Db.H(r[1]) : "") + "</a>" +
                            (Db.H(r[6]) != "" ? " &#8212; filed " + Db.D(r[6]) : " &#8212; no filed date on record") +
                            "</h2><div class='facts'>");
                        sb.Append("<div><b>Primary name</b>" +
                            ((Db.H(r[2]) + Db.H(r[3])) != "" ? Db.H(r[2]) + ", " + Db.H(r[3]) : "&#8212;") + "</div>");
                        sb.Append("<div><b>Address</b>" + Highlight(r[4] as string ?? "", q) + "</div>");
                        sb.Append("</div>");
                        string notes = r[5] as string ?? "";
                        if (notes != "")
                            sb.Append("<div class='narrative'><b style='display:block;font:10.5px Verdana,sans-serif;" +
                                "letter-spacing:1.2px;text-transform:uppercase;color:var(--ink-soft);margin-bottom:4px'>" +
                                "Cross-referenced to / notes</b>" + Highlight(notes, q) + "</div>");
                        sb.Append("</div>");
                    }
                if (n == 0) sb.Append("<p>No matching cross-reference records.</p>");
            }
            int pages = (total + PageSize - 1) / PageSize;
            if (pages > 1)
            {
                string qs = "q=" + Server.UrlEncode(q) + "&ref=" + Server.UrlEncode(refno);
                sb.Append("<div class='pager'>");
                int lo = Math.Max(1, page - 7), hi = Math.Min(pages, page + 7);
                if (lo > 1) sb.Append("<a href='CrossReference.aspx?" + qs + "&p=1'>1</a><span>&#8230;</span>");
                for (int i = lo; i <= hi; i++)
                    sb.Append(i == page ? "<span class='cur'>" + i + "</span>"
                        : "<a href='CrossReference.aspx?" + qs + "&p=" + i + "'>" + i + "</a>");
                if (hi < pages) sb.Append("<span>&#8230;</span><a href='CrossReference.aspx?" + qs +
                    "&p=" + pages + "'>" + pages + "</a>");
                sb.Append("</div>");
            }
            sb.Append("</div>");
        }
    }
    Body.Text = sb.ToString();
}

string Highlight(string text, string term)
{
    string safe = Db.H(text);
    if (term == "") return safe;
    string safeTerm = Db.H(term);
    int i = 0; var sb = new StringBuilder();
    while (true)
    {
        int hit = safe.IndexOf(safeTerm, i, StringComparison.OrdinalIgnoreCase);
        if (hit < 0) { sb.Append(safe.Substring(i)); break; }
        sb.Append(safe.Substring(i, hit - i));
        sb.Append("<mark>").Append(safe.Substring(hit, safeTerm.Length)).Append("</mark>");
        i = hit + safeTerm.Length;
    }
    return sb.ToString();
}
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
    var box = document.getElementById('qbox');
    var list = document.getElementById('qsuggest');
    if (!box || !list) return;
    var timer = null, items = [], activeIdx = -1, lastQuery = '';

    function hide() { list.style.display = 'none'; activeIdx = -1; }
    function show() { if (items.length) list.style.display = 'block'; }

    function render() {
      list.innerHTML = '';
      items.forEach(function (it, i) {
        var m = it.label.match(/^(.*)\s(\(\d+ records?\))$/);
        var div = document.createElement('div');
        div.className = 'ac-item' + (i === activeIdx ? ' active' : '');
        if (m) {
          div.innerHTML = m[1] + '<span class="n">' + m[2].replace(/[()]/g, '') + '</span>';
        } else {
          div.textContent = it.label;
        }
        div.addEventListener('mousedown', function (e) {
          e.preventDefault();
          box.value = it.value;
          hide();
          if (it.final) {
            box.form.submit();
          } else {
            // surname-level pick: keep typing the given name --
            // re-trigger suggestions for what's now in the box instead
            // of searching on a bare surname.
            box.focus();
            var q = box.value.trim();
            clearTimeout(timer);
            if (q.length >= 2) timer = setTimeout(function () { fetchSuggestions(q); }, 50);
          }
        });
        list.appendChild(div);
      });
    }

    function fetchSuggestions(q) {
      lastQuery = q;
      fetch('NameSuggest.aspx?q=' + encodeURIComponent(q))
        .then(function (r) { return r.json(); })
        .then(function (data) {
          if (q !== lastQuery) return; // a newer keystroke has superseded this
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
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        activeIdx = Math.min(activeIdx + 1, items.length - 1); render(); show();
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        activeIdx = Math.max(activeIdx - 1, 0); render(); show();
      } else if (e.key === 'Enter' && activeIdx >= 0) {
        e.preventDefault();
        var it = items[activeIdx];
        box.value = it.value; hide();
        if (it.final) {
          box.form.submit();
        } else {
          box.focus();
          var q = box.value.trim();
          clearTimeout(timer);
          if (q.length >= 2) timer = setTimeout(function () { fetchSuggestions(q); }, 50);
        }
      } else if (e.key === 'Escape') { hide(); }
    });

    box.addEventListener('blur', function () { setTimeout(hide, 150); });
    box.addEventListener('focus', function () { if (items.length) show(); });
  })();
  </script>
</asp:Content>
