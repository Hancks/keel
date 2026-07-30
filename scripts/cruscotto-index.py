#!/usr/bin/env python3
# Indice cross-progetto: scansiona una root per progetti con design-log/, (ri)genera
# ogni cruscotto e costruisce una pagina che li aggrega (card per progetto + link).
# Uso: cruscotto-index.py <root_dir>  → scrive <root>/.cruscotto/index.html
import sys, os, re, html, glob, subprocess

root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Progetti/ProgettiGouttedeau"))
here = os.path.dirname(os.path.abspath(__file__))
gen = os.path.join(here, "cruscotto.py")
outdir = os.path.join(root, ".cruscotto")

def read(dl, name):
    try:
        return open(os.path.join(dl, "design-log", name), encoding="utf-8").read()
    except Exception:
        return ""

def h1(text, default):
    for l in text.splitlines():
        m = re.match(r'#\s+(.*)', l)
        if m:
            return re.sub(r'^(Project|Progetto)\s*[—–-]\s*', '', m.group(1).strip())
    return default

# trova progetti (design-log/PROJECT.md a profondità 1 e 2)
found = set()
for pat in ("*/design-log/PROJECT.md", "*/*/design-log/PROJECT.md"):
    for f in glob.glob(os.path.join(root, pat)):
        found.add(os.path.dirname(os.path.dirname(f)))
projects = sorted(found, key=lambda p: os.path.basename(p).lower())

_sev = re.compile(r'^###\s+[🔴🟡🟢⚪🟠]?\s*(critic|alt|medi|bass|high|low|medium)', re.I)
cards = []
for p in projects:
    try:
        subprocess.run(["python3", gen, p], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=25)
    except Exception:
        pass
    focus, todo, totest, tofix = read(p, "FOCUS.md"), read(p, "TODO.md"), read(p, "TO_TEST.md"), read(p, "TO_FIX.md")
    name = h1(read(p, "PROJECT.md"), os.path.basename(p))
    objs = [l.strip() for l in focus.splitlines() if "🔄" in l and l.strip().startswith("-")]
    obj = objs[0] if objs else ""
    obj = re.sub(r'^\-\s*🔄\s*', '', obj)
    obj = re.sub(r'⟨.*?⟩', '', obj)
    obj = re.sub(r'\*\*(.+?)\*\*', r'\1', obj).strip() or "—"
    if len(obj) > 160:
        obj = obj[:157] + "…"
    n_todo = sum(1 for l in todo.splitlines() if l.strip().startswith("#### "))
    n_test = sum(1 for l in totest.splitlines() if l.strip().startswith("- [ ]"))
    n_fix = sum(1 for l in tofix.splitlines() if l.strip().startswith("### ") and "nessun" not in l.lower() and not _sev.match(l.strip()))
    rel = os.path.relpath(os.path.join(p, "design-log", ".cruscotto", "index.html"), outdir)
    cards.append((name, obj, n_todo, n_test, n_fix, rel))

# in cima chi ha bug aperti, poi più roba da fare/verificare
cards.sort(key=lambda c: (-1 if c[4] else 0, -(c[2] + c[3]), c[0].lower()))

CSS = """
*{box-sizing:border-box}:root{--bg:#0f1220;--card:#171b2e;--bd:#282e49;--tx:#e7e9f3;--mut:#9aa0bd;--now:#f5b544;--todo:#7aa2ff;--test:#c792ea;--fix:#ff6b6b}
@media(prefers-color-scheme:light){:root{--bg:#f5f6fb;--card:#fff;--bd:#e3e6f0;--tx:#1b1e2b;--mut:#5b6178}}
html,body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif}
.wrap{max-width:1100px;margin:0 auto;padding:28px}
h1{margin:0 0 2px;font-size:24px}.sub{color:var(--mut);font-size:13px;margin-bottom:18px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:14px}
a.card{display:block;text-decoration:none;color:inherit;background:var(--card);border:1px solid var(--bd);border-radius:16px;padding:16px 18px;transition:border-color .15s}
a.card:hover{border-color:var(--now)}
.nm{font-weight:700;font-size:16px;margin-bottom:6px}
.obj{color:var(--tx);font-size:13.5px;margin-bottom:12px;min-height:2.6em}
.badges{display:flex;gap:8px;flex-wrap:wrap}
.b{font-size:12px;padding:3px 9px;border-radius:20px;border:1px solid var(--bd);color:var(--mut)}
.b b{color:var(--tx)} .b.todo b{color:var(--todo)} .b.test b{color:var(--test)} .b.fix{border-color:var(--fix)} .b.fix b{color:var(--fix)}
footer{color:var(--mut);font-size:12px;margin-top:22px;text-align:center}
"""

def card_html(c):
    name, obj, nt, nv, nf, rel = c
    fixb = f'<span class="b fix">🐛 <b>{nf}</b> bug</span>' if nf else ''
    return (f'<a class="card" href="{html.escape(rel)}">'
            f'<div class="nm">{html.escape(name)}</div>'
            f'<div class="obj">🎯 {html.escape(obj)}</div>'
            f'<div class="badges"><span class="b todo">📋 <b>{nt}</b> da fare</span>'
            f'<span class="b test">🧪 <b>{nv}</b> da verificare</span>{fixb}</div></a>')

body = "\n".join(card_html(c) for c in cards) or '<p class="sub">Nessun progetto con design-log/ trovato sotto la root.</p>'
out = f"""<!doctype html><html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Cruscotti · tutti i progetti</title><style>{CSS}</style></head>
<body><div class="wrap">
<h1>🧭 Cruscotti — {len(cards)} progetti</h1>
<div class="sub">root: {html.escape(root)} · ognuno mostra obiettivo corrente + cosa manca. Click = cruscotto completo.</div>
<div class="grid">{body}</div>
<footer>indice cross-progetto · reso da design-log/</footer>
</div></body></html>"""

os.makedirs(outdir, exist_ok=True)
with open(os.path.join(outdir, "index.html"), "w", encoding="utf-8") as f:
    f.write(out)
print(f"{len(cards)} progetti -> {os.path.join(outdir, 'index.html')}")
