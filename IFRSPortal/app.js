// Lightweight autocomplete: any input with data-suggest="surname|given|psurname"
// gets a shared datalist filled from Suggest.ashx as the user types.
(function () {
  function debounce(fn, ms) { var t; return function () {
    var a = arguments, c = this; clearTimeout(t);
    t = setTimeout(function () { fn.apply(c, a); }, ms); }; }

  document.querySelectorAll('input[data-suggest]').forEach(function (inp, i) {
    var listId = 'dl_' + i;
    var dl = document.createElement('datalist');
    dl.id = listId; document.body.appendChild(dl);
    inp.setAttribute('list', listId);
    inp.setAttribute('autocomplete', 'off');
    inp.addEventListener('input', debounce(function () {
      var q = inp.value.trim();
      if (q.length < 2) { dl.innerHTML = ''; return; }
      fetch('Suggest.ashx?f=' + encodeURIComponent(inp.dataset.suggest) +
            '&q=' + encodeURIComponent(q))
        .then(function (r) { return r.json(); })
        .then(function (names) {
          dl.innerHTML = names.map(function (n) {
            return '<option value="' + n.replace(/"/g, '&quot;') + '">';
          }).join('');
        }).catch(function () {});
    }, 220));
  });
})();
