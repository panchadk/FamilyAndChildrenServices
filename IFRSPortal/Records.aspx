<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="Records.aspx.cs" Inherits="RecordsPage" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
  <h1><asp:Literal ID="litTitle" runat="server"/></h1>
  <div class="sub"><asp:Literal ID="litSub" runat="server"/></div>
  <div class="searchbox">
    <div><label>Surname filter</label><asp:TextBox ID="txtSurname" runat="server" data-suggest="psurname"/></div>
    <div><label>Era</label>
      <asp:DropDownList ID="ddlEra" runat="server">
        <asp:ListItem Text="All eras" Value=""/>
        <asp:ListItem Text="ifr" Value="ifr"/>
        <asp:ListItem Text="IFRS2000" Value="IFRS2000"/>
      </asp:DropDownList></div>
    <asp:Button ID="btnGo" runat="server" Text="Filter" CssClass="btn" OnClick="btnGo_Click"/>
  </div>
  <asp:Literal ID="litList" runat="server"/>
</asp:Content>
