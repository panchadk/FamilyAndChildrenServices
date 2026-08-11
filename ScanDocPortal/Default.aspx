<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="ScanDoc_Default" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Scanned Document Archive &ndash; FCSGW</title>
    <style>
        :root { --navy:#1f3a5f; --navy2:#274b78; --gold:#c8a13a; --line:#e2e6ea; --muted:#6b7683; }
        * { box-sizing:border-box; }
        body { margin:0; font-family:Segoe UI,Arial,sans-serif; color:#1f2933; background:#f5f7f9; }
        header { background:linear-gradient(135deg,var(--navy) 0%,var(--navy2) 100%); color:#fff; padding:20px 28px; border-bottom:3px solid var(--gold); }
        header h1 { margin:0; font-size:21px; font-weight:600; letter-spacing:.01em; }
        header .sub { color:#c9d6e5; font-size:13px; margin-top:3px; }
        .wrap { max-width:1080px; margin:24px auto; padding:0 20px; }
        .section-label { font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; color:var(--muted); margin:22px 0 10px; }
        .search { background:#fff; border:1px solid var(--line); border-radius:8px; padding:18px 20px; display:flex; gap:12px; flex-wrap:wrap; align-items:flex-end; box-shadow:0 1px 3px rgba(31,58,95,.05); }
        .fld { display:flex; flex-direction:column; gap:4px; }
        .fld label { font-size:12px; color:var(--muted); font-weight:600; }
        .fld input, .fld select { padding:8px 10px; border:1px solid #ccd3da; border-radius:5px; font-size:14px; min-width:180px; }
        .fld input:focus, .fld select:focus { outline:none; border-color:var(--navy); box-shadow:0 0 0 3px rgba(31,58,95,.12); }
        .btn { background:var(--navy); color:#fff; border:0; border-radius:5px; padding:9px 20px; font-size:14px; cursor:pointer; transition:background .1s ease; }
        .btn:hover { background:#16304f; }
        .tiles { display:flex; gap:14px; margin:18px 0; flex-wrap:wrap; }
        .tile { background:#fff; border:1px solid var(--line); border-radius:8px; padding:14px 18px; min-width:150px; box-shadow:0 1px 3px rgba(31,58,95,.05); }
        .tile-click { display:inline-block; text-decoration:none; color:inherit; cursor:pointer; transition:transform .08s ease, box-shadow .08s ease, border-color .08s ease; }
        .tile-click:hover { transform:translateY(-2px); box-shadow:0 6px 16px rgba(31,58,95,.14); border-color:var(--navy); }
        .tile-click:hover .n { color:var(--gold); }
        .tile .n { font-size:24px; font-weight:700; color:var(--navy); }
        .tile .l { font-size:12px; color:var(--muted); text-transform:uppercase; letter-spacing:.04em; }
        /* breakdown mini-tiles */
        .mini-row { display:flex; gap:10px; flex-wrap:wrap; }
        .mini { background:#fff; border:1px solid var(--line); border-radius:7px; padding:10px 16px; text-decoration:none; color:inherit; cursor:pointer; transition:transform .08s ease, box-shadow .08s ease, border-color .08s ease; }
        .mini:hover { transform:translateY(-2px); box-shadow:0 5px 13px rgba(31,58,95,.12); border-color:var(--navy); }
        .mini .mn { font-size:19px; font-weight:700; color:var(--navy); }
        .mini:hover .mn { color:var(--gold); }
        .mini .ml { font-size:11px; color:var(--muted); text-transform:uppercase; letter-spacing:.04em; margin-top:1px; }
        /* A-Z strip */
        .azstrip { display:flex; flex-wrap:wrap; gap:5px; }
        .azstrip a { display:inline-block; min-width:30px; text-align:center; padding:6px 0; background:#fff; border:1px solid var(--line); border-radius:5px; color:var(--navy); text-decoration:none; font-weight:600; font-size:13px; transition:all .08s ease; }
        .azstrip a:hover { background:var(--navy); color:#fff; border-color:var(--navy); }
        .azstrip a.disabled { color:#c3cbd3; pointer-events:none; background:#f7f9fb; font-weight:400; }
        table { width:100%; border-collapse:collapse; background:#fff; border:1px solid var(--line); border-radius:8px; overflow:hidden; box-shadow:0 1px 3px rgba(31,58,95,.05); }
        th, td { text-align:left; padding:10px 14px; border-bottom:1px solid var(--line); font-size:14px; }
        th { background:#f0f3f6; color:var(--navy); font-weight:600; }
        tr:last-child td { border-bottom:0; }
        tr:hover td { background:#f9fbfd; }
        .doclink { color:var(--navy); text-decoration:none; font-weight:600; }
        .doclink:hover { text-decoration:underline; }
        .pill { display:inline-block; background:#eef2f6; color:#43535f; border-radius:12px; padding:2px 10px; font-size:12px; margin:0 4px 4px 0; }
        .catpill { display:inline-block; border-radius:12px; padding:2px 10px; font-size:12px; font-weight:600; }
        .catpill.children { background:#e8f0e6; color:#3f6b34; }
        .catpill.family { background:#e7edf5; color:#2c4a73; }
        .empty { padding:28px; text-align:center; color:var(--muted); }
        .caseref { font-weight:700; color:var(--gold); }
        a.reflink { text-decoration:none; }
        a.reflink:hover { text-decoration:underline; }
        /* dependency-free autocomplete dropdown */
        .ac-wrap { position:relative; }
        .ac-list { position:absolute; left:0; right:0; top:100%; background:#fff; border:1px solid #ccd3da; border-top:0; border-radius:0 0 5px 5px; list-style:none; margin:0; padding:4px 0; max-height:300px; overflow-y:auto; z-index:1000; box-shadow:0 4px 14px rgba(0,0,0,.12); display:none; }
        .ac-list li { padding:7px 14px; font-size:14px; color:#1f2933; cursor:pointer; }
        .ac-list li.active, .ac-list li:hover { background:var(--navy); color:#fff; }
    </style>
</head>
<body>
<header>
    <h1>Scanned Document Archive</h1>
    <div class="sub">Family &amp; Children's Services of Guelph-Wellington &mdash; read-only</div>
</header>
<form id="form1" runat="server">
<div class="wrap">

    <div class="tiles">
        <asp:LinkButton id="tileCases" runat="server" CssClass="tile tile-click" OnClick="tile_Click">
            <div class="n"><asp:Literal id="litCases" runat="server" Text="0" /></div><div class="l">Cases</div>
        </asp:LinkButton>
        <asp:LinkButton id="tileDocs" runat="server" CssClass="tile tile-click" OnClick="tile_Click">
            <div class="n"><asp:Literal id="litDocs" runat="server" Text="0" /></div><div class="l">Documents</div>
        </asp:LinkButton>
    </div>

    <div class="search">
        <div class="fld" style="flex:1 1 340px;">
            <label for="txtQuery">Search (case ref, name, or document type)</label>
            <div class="ac-wrap">
                <asp:TextBox id="txtQuery" runat="server" autocomplete="off" placeholder="e.g. 12001  ·  clark, jason  ·  casenotes" style="width:100%;" />
                <ul id="acList" class="ac-list"></ul>
            </div>
        </div>
        <div class="fld">
            <label for="ddlCategory">Category</label>
            <asp:DropDownList id="ddlCategory" runat="server">
                <asp:ListItem Value="" Text="All" />
                <asp:ListItem Value="Children" Text="Children" />
                <asp:ListItem Value="Family" Text="Family" />
            </asp:DropDownList>
        </div>
        <asp:Button id="btnSearch" runat="server" CssClass="btn" Text="Search" OnClick="btnSearch_Click" />
    </div>

    <asp:Panel id="pnlLanding" runat="server">
        <div class="section-label">By category</div>
        <div class="mini-row">
            <asp:LinkButton id="miniChildren" runat="server" CssClass="mini" OnClick="miniCat_Click" CommandArgument="Children">
                <div class="mn"><asp:Literal id="litChildren" runat="server" Text="0" /></div>
                <div class="ml">Children</div>
            </asp:LinkButton>
            <asp:LinkButton id="miniFamily" runat="server" CssClass="mini" OnClick="miniCat_Click" CommandArgument="Family">
                <div class="mn"><asp:Literal id="litFamily" runat="server" Text="0" /></div>
                <div class="ml">Family</div>
            </asp:LinkButton>
        </div>

        <div class="section-label">By document type</div>
        <div class="mini-row">
            <asp:Repeater id="rptDocTypes" runat="server">
                <ItemTemplate>
                    <asp:LinkButton runat="server" CssClass="mini"
                        OnCommand="docType_Command"
                        CommandArgument='<%# Eval("DocType") %>'>
                        <div class="mn"><%# Eval("Cnt") %></div>
                        <div class="ml"><%# Server.HtmlEncode((string)Eval("DocType")) %></div>
                    </asp:LinkButton>
                </ItemTemplate>
            </asp:Repeater>
        </div>

        <div class="section-label">Browse by surname</div>
        <div class="azstrip">
            <asp:Literal id="litAZ" runat="server" />
        </div>
    </asp:Panel>

    <asp:Panel id="pnlResults" runat="server" Visible="false" style="margin-top:20px;">
        <asp:Repeater id="rptCases" runat="server">
            <HeaderTemplate>
                <table>
                    <tr><th>Case Ref</th><th>Category</th><th>Name</th><th>Documents</th><th>Folder Date</th></tr>
            </HeaderTemplate>
            <ItemTemplate>
                <tr>
                    <td><a class="caseref reflink" href='<%# "Default.aspx?ref=" + Server.UrlEncode((string)Eval("CaseRefBase")) %>' title="Show all cases in this family"><%# Server.HtmlEncode((string)Eval("CaseRef")) %></a></td>
                    <td><%# RenderCatPill(Eval("Category")) %></td>
                    <td><%# Server.HtmlEncode(FormatName(Eval("FirstName"), Eval("LastName"))) %></td>
                    <td><%# BuildDocLinks((int)Eval("CaseID")) %></td>
                    <td><%# FormatDate(Eval("FolderDate")) %></td>
                </tr>
            </ItemTemplate>
            <FooterTemplate></table></FooterTemplate>
        </asp:Repeater>
    </asp:Panel>

    <asp:Panel id="pnlEmpty" runat="server" Visible="false">
        <div class="empty">No matching cases found.</div>
    </asp:Panel>

</div>
</form>
<script>
(function () {
    var box = document.getElementById('<%= txtQuery.ClientID %>');
    var list = document.getElementById('acList');
    var cat = document.getElementById('<%= ddlCategory.ClientID %>');
    if (!box || !list) return;

    var items = [], active = -1, timer = null, lastQ = '';

    function hide() { list.style.display = 'none'; active = -1; }
    function abortable() { if (window._acx) { window._acx.abort(); } }

    function render() {
        list.innerHTML = '';
        if (!items.length) { hide(); return; }
        items.forEach(function (it, i) {
            var li = document.createElement('li');
            li.textContent = it.label;
            li.setAttribute('data-val', it.value);
            li.addEventListener('mousedown', function (e) {
                e.preventDefault();
                box.value = it.value;
                hide();
                box.form.submit();
            });
            list.appendChild(li);
        });
        list.style.display = 'block';
    }

    function setActive(n) {
        var lis = list.querySelectorAll('li');
        if (!lis.length) return;
        if (active >= 0 && lis[active]) lis[active].classList.remove('active');
        active = n;
        if (active < 0) active = lis.length - 1;
        if (active >= lis.length) active = 0;
        lis[active].classList.add('active');
        lis[active].scrollIntoView({ block: 'nearest' });
    }

    function fetchSuggest(q) {
        var url = 'NameSuggest.aspx?q=' + encodeURIComponent(q) +
                  '&cat=' + encodeURIComponent(cat ? cat.value : '');
        abortable();
        window._acx = new XMLHttpRequest();
        window._acx.open('GET', url, true);
        window._acx.onreadystatechange = function () {
            if (window._acx.readyState === 4 && window._acx.status === 200) {
                try { items = JSON.parse(window._acx.responseText) || []; }
                catch (e) { items = []; }
                active = -1;
                render();
            }
        };
        window._acx.send();
    }

    box.addEventListener('input', function () {
        var q = box.value.trim();
        if (q.length < 2) { hide(); return; }
        if (q === lastQ) return;
        lastQ = q;
        clearTimeout(timer);
        timer = setTimeout(function () { fetchSuggest(q); }, 180);
    });

    box.addEventListener('keydown', function (e) {
        if (list.style.display !== 'block') return;
        if (e.key === 'ArrowDown') { e.preventDefault(); setActive(active + 1); }
        else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(active - 1); }
        else if (e.key === 'Enter') {
            if (active >= 0) {
                e.preventDefault();
                var lis = list.querySelectorAll('li');
                box.value = lis[active].getAttribute('data-val');
                hide();
                box.form.submit();
            }
        } else if (e.key === 'Escape') { hide(); }
    });

    document.addEventListener('click', function (e) {
        if (e.target !== box) hide();
    });
})();
</script>
</body>
</html>
