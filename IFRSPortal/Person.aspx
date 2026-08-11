<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="Person.aspx.cs" Inherits="PersonPage" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
  <h1>People Search</h1>
  <div class="sub">Find a person across Caregiver, Child, Family and related records; results link to their cases.</div>
  <div class="searchbox">
    <div><label>Surname</label><asp:TextBox ID="txtSurname" runat="server" data-suggest="psurname"/></div>
    <div><label>Given name</label><asp:TextBox ID="txtGiven" runat="server" data-suggest="pgiven"/></div>
    <asp:Button ID="btnSearch" runat="server" Text="Search" CssClass="btn" OnClick="btnSearch_Click"/>
  </div>
  <asp:Literal ID="litResults" runat="server"/>
</asp:Content>
