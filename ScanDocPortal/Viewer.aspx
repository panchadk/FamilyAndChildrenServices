<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Viewer.aspx.cs" Inherits="ScanDoc_Viewer" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <title><asp:Literal id="litTitle" runat="server" Text="Document" /> &ndash; ScanDoc</title>
    <style>
        html,body { margin:0; height:100%; background:#525659; font-family:Segoe UI,Arial,sans-serif; }
        .bar { background:#1f3a5f; color:#fff; padding:8px 16px; font-size:14px; display:flex; justify-content:space-between; align-items:center; }
        .bar .name { font-weight:600; }
        .bar a { color:#c9d6e5; text-decoration:none; font-size:13px; }
        .bar a:hover { text-decoration:underline; }
        iframe { border:0; width:100%; height:calc(100% - 37px); }
        .err { color:#fff; padding:30px; }
    </style>
</head>
<body>
    <div class="bar">
        <span class="name"><asp:Literal id="litName" runat="server" /></span>
        <a href="javascript:window.close()">Close</a>
    </div>
    <asp:Literal id="litFrame" runat="server" />
</body>
</html>
