<%@ Page Language="C#" MasterPageFile="~/Site.master" Title="Referrals — LANFAM Archive" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
const int PageSize = 25;
protected void Page_Load(object sender, EventArgs e)
{
    if (!Db.CanRead(Context)) { Response.StatusCode = 403;
        Body.Text = "<div class='warn'>Not authorized.</div>"; return; }

    string text = (Request["text"] ?? "").Trim();
    string name = (Request["name"] ?? "").Trim();
    string wrk  = (Request["wrk"] ?? "").Trim();
    string from = (Request["from"] ?? "").Trim();
    string to   = (Request["to"] ?? "").Trim();
    int page; if (!int.TryParse(Request["p"], out page) || page < 1) page = 1;
    bool any = text != "" || name != "" || wrk != "" || from != "" || to != "";

    var sb = new StringBuilder();
    sb.Append("<h1>Search referrals</h1><div class='card tabbed'>" +
        "<form method='get'><div class='searchbar'>" +
        "<input type='text' name='text' placeholder='Words in the narrative' value='" + Db.H(text) + "' />" +
        "<div class='ac-wrap' style='position:relative;flex:1 1 180px'>" +
        "<input type='text' name='name' id='namebox' autocomplete='off' placeholder='Referred surname' value='" +
        Db.H(name) + "' style='width:100%' /><div id='namesuggest' class='ac-list'></div></div>" +
        "<input type='text' name='wrk' placeholder='Worker code' value='" + Db.H(wrk) + "' style='max-width:130px' />" +
        "<input type='text' name='from' placeholder='From yyyy-mm-dd' value='" + Db.H(from) + "' style='max-width:150px' />" +
        "<input type='text' name='to' placeholder='To yyyy-mm-dd' value='" + Db.H(to) + "' style='max-width:150px' />" +
        "<input type='submit' value='SEARCH' /></div>" +
        "<p class='hint'>14,156 referrals, 1992&#8211;2023. Narrative search finds words " +
        "anywhere in the referral text &#8212; e.g. a school, a street, a phrase. " +
        "Combine filters freely; dates accept yyyy-mm-dd.</p></form></div>");

    if (any)
    {
        Db.Audit(Context, "SEARCH_REFERRAL",
            "text=" + text + "; name=" + name + "; wrk=" + wrk + "; " + from + ".." + to);
        using (var cn = Db.Open())
        {
            string where = " WHERE 1=1";
            var cmdText = new SqlCommand(); // parameter holder pattern
            if (text != "") where += " AND narrative LIKE @t";
            if (name != "") where += " AND surname LIKE @n";
            if (wrk  != "") where += " AND worker_cd = @w";
            if (from != "") where += " AND ref_date >= @f";
            if (to   != "") where += " AND ref_date <= @o";

            Action<SqlCommand> bind = c => {
                if (text != "") c.Parameters.AddWithValue("@t", "%" + text + "%");
                if (name != "") c.Parameters.AddWithValue("@n", name + "%");
                if (wrk  != "") c.Parameters.AddWithValue("@w", wrk);
                if (from != "") c.Parameters.AddWithValue("@f", from);
                if (to   != "") c.Parameters.AddWithValue("@o", to);
            };

            int total;
            using (var c = new SqlCommand("SELECT COUNT(*) FROM lanfam.Referral" + where, cn))
            { bind(c); total = (int)c.ExecuteScalar(); }

            sb.Append("<div class='card'><h2>" + total.ToString("N0") + " matching referrals" +
                (total > PageSize ? " &#8212; page " + page : "") + "</h2>");

            using (var c = new SqlCommand(
                "SELECT ref_date, ref_time, famno, surname, given, source, worker_cd, narrative " +
                "FROM lanfam.Referral" + where +
                " ORDER BY ref_date, ref_time OFFSET @off ROWS FETCH NEXT @ps ROWS ONLY", cn))
            {
                bind(c);
                c.Parameters.AddWithValue("@off", (page - 1) * PageSize);
                c.Parameters.AddWithValue("@ps", PageSize);
                using (var r = c.ExecuteReader())
                    while (r.Read())
                    {
                        sb.Append("<div class='card tabbed'><h2>" + Db.D(r[0]) + " " + Db.H(r[1]) +
                            (Db.H(r[2]) != "" ? " &#8212; family <a class='caseno' href='Family.aspx?famno=" +
                             Server.UrlEncode((r[2] as string ?? "").Trim()) + "'>" + Db.H(r[2]) + "</a>" : "") +
                            "</h2><div class='facts'>" +
                            "<div><b>Name</b>" + Db.H(r[3]) + ", " + Db.H(r[4]) + "</div>" +
                            "<div><b>Source</b>" + Db.H(r[5]) + "</div>" +
                            "<div><b>Worker</b>" + Db.H(r[6]) + "</div></div>");
                        string narr = r[7] as string ?? "";
                        if (narr != "")
                            sb.Append("<div class='narrative'>" + Highlight(narr, text) + "</div>");
                        sb.Append("</div>");
                    }
            }
            int pages = (total + PageSize - 1) / PageSize;
            if (pages > 1)
            {
                string qs = "text=" + Server.UrlEncode(text) + "&name=" + Server.UrlEncode(name) +
                    "&wrk=" + Server.UrlEncode(wrk) + "&from=" + Server.UrlEncode(from) +
                    "&to=" + Server.UrlEncode(to);
                sb.Append("<div class='pager'>");
                int lo = Math.Max(1, page - 7), hi = Math.Min(pages, page + 7);
                if (lo > 1) sb.Append("<a href='Referrals.aspx?" + qs + "&p=1'>1</a><span>&#8230;</span>");
                for (int i = lo; i <= hi; i++)
                    sb.Append(i == page ? "<span class='cur'>" + i + "</span>"
                        : "<a href='Referrals.aspx?" + qs + "&p=" + i + "'>" + i + "</a>");
                if (hi < pages) sb.Append("<span>&#8230;</span><a href='Referrals.aspx?" + qs +
                    "&p=" + pages + "'>" + pages + "</a>");
                sb.Append("</div>");
            }
            sb.Append("</div>");
        }
    }
    Body.Text = sb.ToString();
}

// HTML-encode, then mark search hits
string Highlight(string narrative, string term)
{
    string safe = Db.H(narrative);
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

    var nameBox = document.getElementById('namebox'), nameList = document.getElementById('namesuggest');
    // Single surname field on this page (referrals search by surname
    // only) -- picking a suggestion fills the box and searches right away.
    attachAutocomplete(nameBox, nameList,
      function (q) { return 'NameSuggest.aspx?mode=refsurname&q=' + encodeURIComponent(q); },
      function (it) { nameBox.value = it.value; nameBox.form.submit(); });
  })();
  </script>
</asp:Content>
