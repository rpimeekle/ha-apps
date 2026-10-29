#!/usr/bin/env python3
"""Make a Mainsail release bundle work under Home Assistant ingress.

Mainsail is built for the site root ("/"). Under ingress the browser sees it at
/api/hassio_ingress/<token>/, and that prefix is only known per request. So we
replace every root-relative reference with the placeholder /__HA_INGRESS__,
which nginx swaps for the X-Ingress-Path header at runtime (and for "" when
there is no ingress, so the bundle still works at "/").

Each patch states how many matches it expects. If a new Mainsail release
changes its code, the build fails here with a clear message instead of
producing a panel that silently doesn't load.
"""
import pathlib
import re
import sys

P = "/__HA_INGRESS__"
root = pathlib.Path(sys.argv[1])
errors = []


def patch(files, pattern, repl, *, expect="1", label):
    """expect: '1' exactly one, '+' at least one, '?' zero or one (optional)."""
    rx = re.compile(pattern)
    total = 0
    for f in files:
        text = f.read_text(encoding="utf-8")
        new, n = rx.subn(repl, text)
        if n:
            f.write_text(new, encoding="utf-8")
            total += n
    ok = {"1": total == 1, "+": total >= 1, "?": total <= 1}[expect]
    status = "ok" if ok else "FAILED"
    print(f"[patch] {label}: {total} match(es) {status}")
    if not ok:
        errors.append(label)


js = sorted(root.glob("assets/*.js"))
css = sorted(root.glob("assets/*.css")) + sorted(root.glob("css/**/*.css"))
html = [root / "index.html"]

# --- JavaScript ---------------------------------------------------------------
# Vite preload helper: function(e){return`/`+e}
patch(js, r"function\((\w)\)\{return`/`\+\1\}",
      lambda m: f"function({m[1]}){{return`{P}/`+{m[1]}}}",
      label="module preload base")
# config.json is fetched from the build base ("/")
patch(js, r"fetch\(`\$\{\w+\}config\.json`\)",
      f"fetch(`{P}/config.json`)", label="config.json location")
# vue-router in history mode, base "/"
patch(js, r"\(\{base:`/`,mode:`history`",
      f"({{base:`{P}/`,mode:`history`", label="router base")
# Mainsail bug: config.json "path" is stored as route_prefix, but the socket
# URL is built from "path", so the setting is ignored. Optional: if upstream
# fixes it, this simply stops matching.
patch(js, r"route_prefix:(\w)\.path\}", r"path:\1.path}",
      expect="?", label="config.json path -> socket path")
# Host URL (used to resolve relative webcam URLs) should include the panel prefix
patch(js, r"getHostUrl:(\w)=>`\$\{\1\.protocol===`wss`\?`https`:`http`\}://\$\{\1\.hostname\}/`",
      lambda m: f"getHostUrl:{m[1]}=>`${{{m[1]}.protocol===`wss`?`https`:`http`}}://${{location.host}}{P}/`",
      expect="?", label="host URL includes panel prefix")
# Webcam URLs. Mainsail resolves every camera address through convertUrl().
#  - A full camera address (e.g. http://10.0.0.5:8080/?action=stream) that
#    starts with one of the camera addresses the app routes
#    (__HA_WEBCAM_BASES__, space-separated, filled in by nginx) is shown
#    through the panel at webcams/<index>/, which the app proxies to that
#    camera. The browser never has to reach the camera itself, so the same
#    setting works at home and remotely.
#  - Root-relative addresses ("/webcam/?action=stream") are kept inside the
#    panel instead of escaping to the root of the Home Assistant site.
# Outside ingress both placeholders are "" and this is a no-op. Names start
# with __ so they can't shadow the minified code's own variables.
CAM_JS = (
    "if(typeof @V@==`string`){"
    "let __wb=`__HA_WEBCAM_BASES__`.split(` `).filter(Boolean),__wm=``;"
    "if(__wb.length&&/^https?:[/][/]/i.test(@V@)){try{let __wu=new URL(@V@).href;"
    "for(let __w of __wb)if(__wu.startsWith(__w)&&__w.length>__wm.length)__wm=__w;"
    "if(__wm)@V@=`PFX/webcams/`+__wb.indexOf(__wm)+`/`+__wu.slice(__wm.length)}catch(__wx){}}"
    "if(@V@.startsWith(`/`)&&!@V@.startsWith(`//`)&&!@V@.startsWith(`PFX/`))@V@=`PFX`+@V@}"
)
patch(js, r"convertUrl\((\w),(\w)\)\{",
      lambda m: f"convertUrl({m[1]},{m[2]}){{" + CAM_JS.replace("@V@", m[1]).replace("PFX", P),
      label="webcam URLs routed through the panel")
# Never register Mainsail's service worker: at the HA origin it would claim
# scope "/" over Home Assistant itself.
patch(js, r"`serviceWorker`in navigator", "!1", label="disable service worker")
# Remaining root-relative static paths in string literals
patch(js, r"([`\"'])/(assets|img|css|fonts)/", rf"\1{P}/\2/",
      expect="+", label="static asset paths in JS")

# --- CSS / HTML ---------------------------------------------------------------
patch(css, r"url\((['\"]?)/(?!/)", rf"url(\1{P}/", expect="+", label="CSS url(/...)")
patch(html, r'<link rel="manifest"[^>]*>', "", expect="?", label="drop PWA manifest link")
patch(html, r'(href|src)="/(?!/)', rf'\1="{P}/', expect="+", label="index.html links")

# PWA files are never used under ingress
for name in ["sw.js", "manifest.webmanifest"]:
    (root / name).unlink(missing_ok=True)
for f in root.glob("workbox-*.js"):
    f.unlink()

if errors:
    print("\nMainsail bundle layout changed; update patch_mainsail.py for: "
          + ", ".join(errors), file=sys.stderr)
    sys.exit(1)
print("[patch] all patches applied")
