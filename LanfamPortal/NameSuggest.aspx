<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Collections.Generic" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.Cache.SetCacheability(HttpCacheability.NoCache);

    string q = (Request["q"] ?? "").Trim();
    string mode = (Request["mode"] ?? "").Trim().ToLower();
    string surScopeParam = (Request["surname"] ?? "").Trim();
    var sb = new StringBuilder("[");

    // Normally require 2+ typed characters before querying, to avoid a
    // flood of near-meaningless matches. Exception: given-name mode with
    // a surname already selected is already narrow enough on its own
    // (e.g. "show me the 6 Bellengers") -- no typing should be required
    // to see them.
    bool okToQuery = q.Length >= 2 || (mode == "given" && surScopeParam != "");

    if (Db.CanRead(Context) && okToQuery)
    {
        try
        {
          if (mode == "surname")
          {
              using (var cn = Db.Open()) WriteSurnamesOnly(cn, sb, q);
          }
          else if (mode == "given")
          {
              string surScope = (Request["surname"] ?? "").Trim();
              using (var cn = Db.Open()) WriteGivenOnly(cn, sb, q, surScope);
          }
          else if (mode == "ressurname")
          {
              using (var cn = Db.Open()) WriteResourceSurnames(cn, sb, q);
          }
          else
          {
            // Two-part query ("Smith, J" or "Smith j"): the user is now
            // specifying a given name too -- suggest actual PEOPLE,
            // matching both fragments as a name pair (same logic as the
            // real search, so the dropdown promises what the search
            // will actually find).
            string w1 = q, w2 = null;
            if (q.Contains(","))
            {
                var p = q.Split(',');
                w1 = p[0].Trim();
                w2 = p.Length > 1 ? p[1].Trim() : "";
            }
            else if (q.Contains(" "))
            {
                var p = q.Trim().Split(new[] { ' ' }, 2);
                w1 = p[0].Trim();
                w2 = p[1].Trim();
            }

            using (var cn = Db.Open())
            {
                if (w2 != null && w2 != "")
                    WritePeople(cn, sb, w1, w2);
                else if (w2 == "")
                    WritePeople(cn, sb, w1, null); // "Smith, " typed, nothing after comma yet
                else
                    WriteSurnames(cn, sb, q);
            }
          }
        }
        catch { /* suggestions are best-effort; a failure here should never
                    block the actual search */ }
    }
    sb.Append("]");
    Response.Write(sb.ToString());
    Response.End();
}

/// <summary>Single fragment typed: suggest SURNAMES (deduplicated,
/// aggregated across every given name under them) so a common surname
/// like Smith is one short entry, not 400 individual rows competing
/// for the same 15 slots.</summary>
void WriteSurnames(SqlConnection cn, StringBuilder sb, string q)
{
    using (var cmd = new SqlCommand(
        "SELECT TOP 15 surname, SUM(cnt) AS total FROM (" +
        "  SELECT surname, COUNT(*) AS cnt FROM lanfam.NameIndex " +
        "    WHERE surname LIKE @q GROUP BY surname" +
        "  UNION ALL" +
        "  SELECT surname, COUNT(*) AS cnt FROM lanfam.CrossRef " +
        "    WHERE surname LIKE @q GROUP BY surname" +
        ") u WHERE ISNULL(surname,'') <> '' " +
        "GROUP BY surname ORDER BY SUM(cnt) DESC, surname", cn))
    {
        cmd.Parameters.AddWithValue("@q", q + "%");
        bool first = true;
        using (var r = cmd.ExecuteReader())
            while (r.Read())
            {
                string sur = r.IsDBNull(0) ? "" : r.GetString(0);
                int cnt = r.IsDBNull(1) ? 0 : Convert.ToInt32(r[1]);
                if (sur == "") continue;
                if (!first) sb.Append(","); first = false;
                sb.Append("{\"label\":\"").Append(JsEsc(sur)).Append(" (")
                  .Append(cnt).Append(cnt == 1 ? " record)" : " records)")
                  .Append("\",\"value\":\"").Append(JsEsc(sur)).Append(", \"")
                  .Append(",\"final\":false}");
            }
    }
}

/// <summary>Surname suggestions for a form with SEPARATE surname/given
/// boxes (e.g. Default.aspx): value is the bare surname, no trailing
/// comma -- selecting one fills just that box and moves on to the
/// given-name box, rather than continuing to build one combined
/// string.</summary>
void WriteSurnamesOnly(SqlConnection cn, StringBuilder sb, string q)
{
    using (var cmd = new SqlCommand(
        "SELECT TOP 15 surname, SUM(cnt) AS total FROM (" +
        "  SELECT surname, COUNT(*) AS cnt FROM lanfam.NameIndex " +
        "    WHERE surname LIKE @q GROUP BY surname" +
        "  UNION ALL" +
        "  SELECT surname, COUNT(*) AS cnt FROM lanfam.CrossRef " +
        "    WHERE surname LIKE @q GROUP BY surname" +
        ") u WHERE ISNULL(surname,'') <> '' " +
        "GROUP BY surname ORDER BY SUM(cnt) DESC, surname", cn))
    {
        cmd.Parameters.AddWithValue("@q", q + "%");
        bool first = true;
        using (var r = cmd.ExecuteReader())
            while (r.Read())
            {
                string sur = r.IsDBNull(0) ? "" : r.GetString(0);
                int cnt = r.IsDBNull(1) ? 0 : Convert.ToInt32(r[1]);
                if (sur == "") continue;
                if (!first) sb.Append(","); first = false;
                sb.Append("{\"label\":\"").Append(JsEsc(sur)).Append(" (")
                  .Append(cnt).Append(cnt == 1 ? " record)" : " records)")
                  .Append("\",\"value\":\"").Append(JsEsc(sur)).Append("\"}");
            }
    }
}

/// <summary>Given-name suggestions for a form with SEPARATE surname/given
/// boxes. If surScope is non-empty, suggestions are limited to given
/// names that actually co-occur with that surname (so typing "Smith"
/// in the surname box first narrows the given-name dropdown to real
/// Smiths, not every given name in the archive).</summary>
void WriteGivenOnly(SqlConnection cn, StringBuilder sb, string q, string surScope)
{
    using (var cmd = new SqlCommand(
        "SELECT TOP 15 given, SUM(cnt) AS total FROM (" +
        "  SELECT given, COUNT(*) AS cnt FROM lanfam.NameIndex " +
        "    WHERE given LIKE @q AND (@sur = '' OR surname LIKE @sur) GROUP BY given" +
        "  UNION ALL" +
        "  SELECT given, COUNT(*) AS cnt FROM lanfam.CrossRef " +
        "    WHERE given LIKE @q AND (@sur = '' OR surname LIKE @sur) GROUP BY given" +
        ") u WHERE ISNULL(given,'') <> '' " +
        "GROUP BY given ORDER BY SUM(cnt) DESC, given", cn))
    {
        cmd.Parameters.AddWithValue("@q", q + "%");
        cmd.Parameters.AddWithValue("@sur", surScope == "" ? "" : surScope + "%");
        bool first = true;
        using (var r = cmd.ExecuteReader())
            while (r.Read())
            {
                string giv = r.IsDBNull(0) ? "" : r.GetString(0);
                int cnt = r.IsDBNull(1) ? 0 : Convert.ToInt32(r[1]);
                if (giv == "") continue;
                if (!first) sb.Append(","); first = false;
                sb.Append("{\"label\":\"").Append(JsEsc(giv)).Append(" (")
                  .Append(cnt).Append(cnt == 1 ? " record)" : " records)")
                  .Append("\",\"value\":\"").Append(JsEsc(giv)).Append("\"}");
            }
    }
}

/// <summary>Caregiver surname suggestions scoped ONLY to
/// lanfam.Resource -- deliberately not the general NameIndex/CrossRef
/// population, since suggesting a name that isn't actually a resource
/// caregiver would send someone to a search with zero results. Checks
/// both caregiver-surname columns (a resource home can have two).</summary>
void WriteResourceSurnames(SqlConnection cn, StringBuilder sb, string q)
{
    using (var cmd = new SqlCommand(
        "SELECT TOP 15 sur, SUM(cnt) AS total FROM (" +
        "  SELECT surname1 AS sur, COUNT(*) AS cnt FROM lanfam.Resource " +
        "    WHERE surname1 LIKE @q GROUP BY surname1" +
        "  UNION ALL" +
        "  SELECT surname2 AS sur, COUNT(*) AS cnt FROM lanfam.Resource " +
        "    WHERE surname2 LIKE @q GROUP BY surname2" +
        ") u WHERE ISNULL(sur,'') <> '' " +
        "GROUP BY sur ORDER BY SUM(cnt) DESC, sur", cn))
    {
        cmd.Parameters.AddWithValue("@q", q + "%");
        bool first = true;
        using (var r = cmd.ExecuteReader())
            while (r.Read())
            {
                string sur = r.IsDBNull(0) ? "" : r.GetString(0);
                int cnt = r.IsDBNull(1) ? 0 : Convert.ToInt32(r[1]);
                if (sur == "") continue;
                if (!first) sb.Append(","); first = false;
                sb.Append("{\"label\":\"").Append(JsEsc(sur)).Append(" (")
                  .Append(cnt).Append(cnt == 1 ? " home)" : " homes)")
                  .Append("\",\"value\":\"").Append(JsEsc(sur)).Append("\"}");
            }
    }
}

/// <summary>Two fragments typed: suggest actual PEOPLE matching both
/// as a name pair, in either order -- same matching rule as the real
/// search, so picking a suggestion always finds something.</summary>
void WritePeople(SqlConnection cn, StringBuilder sb, string w1, string w2)
{
    string where = (w2 != null)
        ? "(surname LIKE @w1 AND given LIKE @w2) OR (surname LIKE @w2 AND given LIKE @w1)"
        : "surname LIKE @w1";
    using (var cmd = new SqlCommand(
        "SELECT TOP 15 surname, given, SUM(cnt) AS total FROM (" +
        "  SELECT surname, given, COUNT(*) AS cnt FROM lanfam.NameIndex " +
        "    WHERE " + where + " GROUP BY surname, given" +
        "  UNION ALL" +
        "  SELECT surname, given, COUNT(*) AS cnt FROM lanfam.CrossRef " +
        "    WHERE " + where + " GROUP BY surname, given" +
        ") u WHERE ISNULL(surname,'') <> '' OR ISNULL(given,'') <> '' " +
        "GROUP BY surname, given ORDER BY SUM(cnt) DESC, surname, given", cn))
    {
        cmd.Parameters.AddWithValue("@w1", w1 + "%");
        cmd.Parameters.AddWithValue("@w2", (w2 ?? "") + "%");
        bool first = true;
        using (var r = cmd.ExecuteReader())
            while (r.Read())
            {
                string sur = r.IsDBNull(0) ? "" : r.GetString(0);
                string giv = r.IsDBNull(1) ? "" : r.GetString(1);
                int cnt = r.IsDBNull(2) ? 0 : Convert.ToInt32(r[2]);
                string label = (sur != "" && giv != "") ? sur + ", " + giv
                    : (sur != "" ? sur : giv);
                if (label == "") continue;
                if (!first) sb.Append(","); first = false;
                sb.Append("{\"label\":\"").Append(JsEsc(label)).Append(" (")
                  .Append(cnt).Append(cnt == 1 ? " record)" : " records)")
                  .Append("\",\"value\":\"").Append(JsEsc(label)).Append("\",\"final\":true}");
            }
    }
}

string JsEsc(string s)
{
    return s.Replace("\\", "\\\\").Replace("\"", "\\\"")
             .Replace("\n", " ").Replace("\r", "");
}
</script>
