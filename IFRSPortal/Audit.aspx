<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="Audit.aspx.cs" Inherits="AuditPage" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
  <h1>Access Audit Log</h1>
  <div class="searchbox">
    <div><label>User contains</label><asp:TextBox ID="txtUser" runat="server"/></div>
    <div><label>Case #</label><asp:TextBox ID="txtCase" runat="server"/></div>
    <div><label>Days back</label><asp:TextBox ID="txtDays" runat="server" Text="7"/></div>
    <asp:Button ID="btnGo" runat="server" Text="View" CssClass="btn" OnClick="btnGo_Click"/>
  </div>
  <asp:Literal ID="litLog" runat="server"/>
</asp:Content>
