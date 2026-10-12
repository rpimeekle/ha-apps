// Injected at the top of TrueNAS's index.html by the ingress proxy.
// TrueNAS builds its websocket, upload and download URLs from the site root
// (e.g. wss://<host>/api/current, /_download/...). Under ingress the site root
// is Home Assistant, so prefix any same-host, root-relative URL with the panel
// path. URLs already inside the panel, and other hosts, pass through untouched.
// No "$" characters: nginx would read them as variables.
(function () {
  var P = "__PREFIX__";
  if (!P) return;
  function fix(u) {
    if (u == null) return u;
    try {
      var x = new URL(String(u), document.baseURI);
      if (x.host !== location.host) return u;
      if (x.pathname === P || x.pathname.indexOf(P + "/") === 0) return u;
      x.pathname = P + x.pathname;
      return x.href;
    } catch (e) { return u; }
  }
  var open = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (m, u) { arguments[1] = fix(u); return open.apply(this, arguments); };
  var f = window.fetch;
  if (f) window.fetch = function (i, n) {
    if (typeof i === "string" || i instanceof URL) { i = fix(i); }
    else if (i && i.url) { var v = fix(i.url); if (v !== i.url) i = new Request(v, i); }
    return f.call(this, i, n);
  };
  var W = window.WebSocket;
  var S = function (u, p) { return arguments.length > 1 ? new W(fix(u), p) : new W(fix(u)); };
  S.prototype = W.prototype; S.CONNECTING = 0; S.OPEN = 1; S.CLOSING = 2; S.CLOSED = 3;
  window.WebSocket = S;
  var E = window.EventSource;
  if (E) { var ES = function (u, c) { return new E(fix(u), c); }; ES.prototype = E.prototype; window.EventSource = ES; }
  var wo = window.open;
  window.open = function (u) { if (u) arguments[0] = fix(u); return wo.apply(this, arguments); };
  window.__haIngressFix = fix;
})();
