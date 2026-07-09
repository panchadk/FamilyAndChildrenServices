// LANFAM Archive - table sort & filter (no dependencies)
(function () {
  // Sorting: click any ledger header
  document.querySelectorAll("table.ledger").forEach(function (tbl) {
    var headers = tbl.querySelectorAll("th");
    headers.forEach(function (th, idx) {
      th.classList.add("sortable");
      th.addEventListener("click", function () {
        var rows = Array.prototype.slice.call(tbl.querySelectorAll("tr"))
                        .filter(function (r) { return r.querySelector("td"); });
        if (!rows.length) return;
        var asc = !th.classList.contains("sorted-asc");
        headers.forEach(function (h) { h.classList.remove("sorted-asc", "sorted-desc"); });
        th.classList.add(asc ? "sorted-asc" : "sorted-desc");
        rows.sort(function (a, b) {
          var x = (a.cells[idx] ? a.cells[idx].textContent : "").trim();
          var y = (b.cells[idx] ? b.cells[idx].textContent : "").trim();
          var nx = parseFloat(x.replace(/,/g, "")), ny = parseFloat(y.replace(/,/g, ""));
          if (!isNaN(nx) && !isNaN(ny) && x !== "" && y !== "")
            return asc ? nx - ny : ny - nx;
          return asc ? x.localeCompare(y) : y.localeCompare(x);
        });
        rows.forEach(function (r) { r.parentNode.appendChild(r); });
      });
    });
  });

  // Filtering: any input.tablefilter narrows the next table
  document.querySelectorAll("input.tablefilter").forEach(function (inp) {
    var tbl = inp.parentNode.querySelector("table.ledger");
    if (!tbl) return;
    inp.addEventListener("input", function () {
      var q = inp.value.toLowerCase();
      tbl.querySelectorAll("tr").forEach(function (r) {
        if (!r.querySelector("td")) return;
        r.style.display =
          r.textContent.toLowerCase().indexOf(q) > -1 ? "" : "none";
      });
    });
  });
})();
