<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="Browse.aspx.cs" Inherits="BrowsePage" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
  <h1>Browse Cases A&ndash;Z</h1>
  <div class="sub">Cases by surname. Click a letter, then a case.</div>
  <div class="az"><asp:Literal ID="litAZ" runat="server"/></div>
  <asp:Literal ID="litList" runat="server"/>
</asp:Content>
