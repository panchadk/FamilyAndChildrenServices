<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="Default.aspx.cs" Inherits="DefaultPage" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
  <div class="masthead">
    <div class="kicker">IFR &middot; IFRS 2000 &middot; Digitized 2026</div>
    <h1>The IFRS Archive</h1>
    <div class="rule"></div>
    <div class="lede">Child protection case records from the agency&rsquo;s Lotus Notes era &mdash;
      every case, person, referral and case note, preserved and searchable across all workers and both system generations.</div>
  </div>
  <asp:Literal ID="litStats" runat="server"/>
  <div class="searchband">
    <div class="searchbox">
      <div><label>Surname</label><asp:TextBox ID="txtSurname" runat="server" data-suggest="surname"/></div>
      <div><label>Given name</label><asp:TextBox ID="txtGiven" runat="server" data-suggest="given"/></div>
      <div><label>Case / file number</label><asp:TextBox ID="txtCase" runat="server"/></div>
      <div><label>Era</label>
        <asp:DropDownList ID="ddlEra" runat="server">
          <asp:ListItem Text="All eras" Value=""/>
          <asp:ListItem Text="ifr" Value="ifr"/>
          <asp:ListItem Text="IFRS2000" Value="IFRS2000"/>
        </asp:DropDownList></div>
      <asp:Button ID="btnSearch" runat="server" Text="Search" CssClass="btn" OnClick="btnSearch_Click"/>
    </div>
    <div class="hint">Prefix matching &mdash; &ldquo;Bow&rdquo; finds Bowyer. Number search tolerates leading zeros.
      Or browse surnames A&ndash;Z below. Every search is logged.</div>
    <div class="az"><asp:Literal ID="litAZ" runat="server"/></div>
  </div>
  <asp:Literal ID="litResults" runat="server"/>
</asp:Content>
