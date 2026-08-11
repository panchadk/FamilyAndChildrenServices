<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/Site.master"
    CodeFile="Default.aspx.cs" Inherits="VaultPortal.DefaultPage" %>

<asp:Content ContentPlaceHolderID="Head" runat="server">
<script>
// Dependency-free autocomplete on the quick-search box (file no. + surname).
document.addEventListener("DOMContentLoaded", function () {
    var box = document.getElementById("txtQuick");
    if (!box) return;
    var wrap = box.parentNode, list = null, timer = null, sel = -1;

    function close() { if (list) { wrap.removeChild(list); list = null; sel = -1; } }

    function render(items) {
        close();
        if (!items.length) return;
        list = document.createElement("div");
        list.className = "suggestlist";
        items.forEach(function (it) {
            var d = document.createElement("div");
            d.textContent = it.v;
            if (it.t === "name") d.className = "s-name";
            d.onmousedown = function (ev) {
                ev.preventDefault();
                box.value = it.v; close();
                document.getElementById("<%= btnQuickGo.ClientID %>").click();
            };
            list.appendChild(d);
        });
        wrap.appendChild(list);
    }

    box.addEventListener("input", function () {
        clearTimeout(timer);
        var q = box.value.trim();
        if (q.length < 2) { close(); return; }
        timer = setTimeout(function () {
            fetch("Suggest.ashx?q=" + encodeURIComponent(q), { credentials: "same-origin" })
                .then(function (r) { return r.json(); })
                .then(render)
                .catch(close);
        }, 180);
    });

    box.addEventListener("keydown", function (ev) {
        if (!list) return;
        var kids = list.children;
        if (ev.key === "ArrowDown") { sel = Math.min(sel + 1, kids.length - 1); }
        else if (ev.key === "ArrowUp") { sel = Math.max(sel - 1, 0); }
        else if (ev.key === "Enter" && sel >= 0) {
            ev.preventDefault(); box.value = kids[sel].textContent; close();
            document.getElementById("<%= btnQuickGo.ClientID %>").click(); return;
        }
        else if (ev.key === "Escape") { close(); return; }
        else return;
        ev.preventDefault();
        for (var i = 0; i < kids.length; i++)
            kids[i].className = kids[i].className.replace(" sel", "") + (i === sel ? " sel" : "");
    });

    box.addEventListener("blur", function () { setTimeout(close, 150); });
});
</script>
</asp:Content>

<asp:Content ContentPlaceHolderID="Body" runat="server">

    <!-- MASTHEAD -->
    <div class="masthead">
        <div class="kicker">Physical records vault &middot; Register maintained since 2009 &middot; Digitized 2026</div>
        <h1>The Vault Register</h1>
        <div class="rule"></div>
        <div class="lede">
            Every physical file in the agency vault &mdash; permanent paper, audio, video,
            disc, and microfiche &mdash; with its shelf location, sign-out record,
            and working-file history in one searchable register.
        </div>
    </div>

    <!-- STATS -->
    <div class="statsband">
        <div class="statrow">
            <asp:LinkButton runat="server" CssClass="stat" CommandName="all"
                OnCommand="Tile_Command" ToolTip="Show all holdings">Holdings<span><asp:Literal ID="litTotal" runat="server" /></span></asp:LinkButton>
            <asp:LinkButton runat="server" CssClass="stat" CommandName="paper"
                OnCommand="Tile_Command" ToolTip="Show permanent paper files">Perm. paper files<span><asp:Literal ID="litPaper" runat="server" /></span></asp:LinkButton>
            <asp:LinkButton runat="server" CssClass="stat" CommandName="media"
                OnCommand="Tile_Command" ToolTip="Show holdings with media items">Media items<span><asp:Literal ID="litMedia" runat="server" /></span></asp:LinkButton>
            <asp:LinkButton runat="server" CssClass="stat" CommandName="working"
                OnCommand="Tile_Command" ToolTip="Show holdings with working files">Working files<span><asp:Literal ID="litWorking" runat="server" /></span></asp:LinkButton>
            <asp:LinkButton runat="server" CssClass="stat stat-out" CommandName="out"
                OnCommand="Tile_Command" ToolTip="Show holdings currently signed out">Signed out<span><asp:Literal ID="litOut" runat="server" /></span></asp:LinkButton>
        </div>
    </div>

    <!-- SEARCH -->
    <div class="searchband">
        <h2 class="searchtitle">Search the register</h2>

        <div class="searchbox" style="margin-bottom:16px;">
            <div class="field field-num">
                <label>Quick search &mdash; file no. or surname</label>
                <span class="quickwrap">
                    <asp:TextBox ID="txtQuick" runat="server" CssClass="quickbox"
                        ClientIDMode="Static" autocomplete="off" />
                </span>
            </div>
            <asp:Button ID="btnQuickGo" runat="server" Text="GO" CssClass="btn"
                OnClick="btnQuickGo_Click" />
        </div>

        <div class="searchbox">
            <div class="field">
                <label>Family name</label>
                <asp:TextBox ID="txtFamilyName" runat="server" />
            </div>
            <div class="field field-num">
                <label>File number</label>
                <asp:TextBox ID="txtFileNumber" runat="server" />
            </div>
            <div class="field">
                <label>File type</label>
                <asp:TextBox ID="txtFileType" runat="server" />
            </div>
            <div class="field">
                <label>Signed out to</label>
                <asp:TextBox ID="txtSignedOutTo" runat="server" />
            </div>
            <div class="field">
                <label>Keyword in comments</label>
                <asp:TextBox ID="txtKeyword" runat="server" />
            </div>
            <asp:Button ID="btnSearch" runat="server" Text="SEARCH" CssClass="btn"
                OnClick="btnSearch_Click" />
            <asp:Button ID="btnClear" runat="server" Text="CLEAR" CssClass="btn btn-quiet"
                OnClick="btnClear_Click" />
        </div>

        <div class="hint">
            Prefix matching &mdash; &ldquo;Bel&rdquo; finds Beltman; file numbers keep their
            suffix letters (2825A). &ldquo;Signed out to&rdquo; searches every sign-out and
            assignment name field. Keyword searches both comment fields.
            Click a column header to sort. Every search is logged.
        </div>

        <div class="az">
            <asp:Repeater ID="rptAZ" runat="server" OnItemCommand="rptAZ_ItemCommand">
                <ItemTemplate>
                    <asp:LinkButton runat="server" Text='<%# Container.DataItem %>'
                        CommandName="Letter" CommandArgument='<%# Container.DataItem %>'
                        CssClass="azlink" />
                </ItemTemplate>
            </asp:Repeater>
        </div>
    </div>

    <!-- RESULTS -->
    <div class="resultsband">
        <div class="resultmeta"><asp:Literal ID="litResultMeta" runat="server" /></div>

        <asp:GridView ID="gvResults" runat="server" CssClass="grid"
            AutoGenerateColumns="False" AllowPaging="True" PageSize="25"
            AllowSorting="True" PagerStyle-CssClass="pager"
            OnPageIndexChanging="gvResults_PageIndexChanging"
            OnSorting="gvResults_Sorting"
            DataKeyNames="SPListItemID" GridLines="None">
            <Columns>
                <asp:TemplateField HeaderText="File no." SortExpression="FileNumber">
                    <ItemTemplate>
                        <a class="cell-num" href='Record.aspx?id=<%# Eval("SPListItemID") %>'><%# Eval("FileNumber") %></a>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:BoundField DataField="FamilyName" HeaderText="Family name" SortExpression="FamilyName" />
                <asp:BoundField DataField="FamilyNameAlt" HeaderText="Alt. name" SortExpression="FamilyNameAlt" />
                <asp:BoundField DataField="FileType" HeaderText="Type" SortExpression="FileType" />
                <asp:TemplateField HeaderText="Holdings">
                    <ItemTemplate><span class="media-flags"><%# Eval("MediaFlags") %></span></ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Status" SortExpression="SignedOutFlag">
                    <ItemTemplate>
                        <span class='stamp <%# (int)Eval("SignedOutFlag") == 1 ? "stamp-out" : "stamp-in" %>'>
                            <%# (int)Eval("SignedOutFlag") == 1 ? "SIGNED OUT" : "IN VAULT" %></span>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:BoundField DataField="StartDate" HeaderText="Start" SortExpression="StartDate"
                    DataFormatString="{0:yyyy-MM-dd}" ItemStyle-CssClass="cell-num" />
                <asp:BoundField DataField="EndDate" HeaderText="End" SortExpression="EndDate"
                    DataFormatString="{0:yyyy-MM-dd}" ItemStyle-CssClass="cell-num" />
            </Columns>
            <EmptyDataTemplate>
                <div style="padding:16px;">No holdings match this search.
                Try a shorter prefix, or search a keyword in comments.</div>
            </EmptyDataTemplate>
        </asp:GridView>
    </div>

</asp:Content>
