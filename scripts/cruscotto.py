#!/usr/bin/env python3
# Cruscotto locale «obiettivo / fatto / manca» — rende lo stato del design-log in HTML.
# Uso: cruscotto.py <project_dir>  → scrive <project_dir>/design-log/.cruscotto/index.html
# NON è una nuova fonte di verità: rende i file design-log esistenti (zero drift).
import sys, os, re, html

proj = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
DL = os.path.join(proj, "design-log")

def read(name):
    try:
        return open(os.path.join(DL, name), encoding="utf-8").read()
    except Exception:
        return ""

def first_h1(text, default):
    for l in text.splitlines():
        m = re.match(r'#\s+(.*)', l)
        if m:
            return re.sub(r'^(Project|Progetto)\s*[—–-]\s*', '', m.group(1).strip())
    return default

def inline(t):
    t = html.escape(t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'`(.+?)`', r'<code>\1</code>', t)
    t = re.sub(r'\[(.+?)\]\((.+?)\)', r'\1', t)
    return t

def render_md(text, skip_h1=True):
    out, inlist = [], False
    def closeul():
        nonlocal inlist
        if inlist:
            out.append("</ul>"); inlist = False
    for raw in text.splitlines():
        s = raw.strip()
        if not s:
            closeul(); continue
        if s.startswith("# ") and skip_h1:
            continue
        if s.startswith("#### "):
            closeul(); out.append(f"<h4>{inline(s[5:])}</h4>")
        elif s.startswith("### "):
            closeul(); out.append(f"<h4>{inline(s[4:])}</h4>")
        elif s.startswith("## "):
            closeul(); out.append(f"<h3>{inline(s[3:])}</h3>")
        elif s.startswith("- [ ] "):
            if not inlist: out.append("<ul>"); inlist = True
            out.append(f'<li class="box">☐ {inline(s[6:])}</li>')
        elif re.match(r'- \[[xX]\] ', s):
            if not inlist: out.append("<ul>"); inlist = True
            out.append(f'<li class="boxd">☑ {inline(s[6:])}</li>')
        elif s.startswith("- "):
            if not inlist: out.append("<ul>"); inlist = True
            out.append(f"<li>{inline(s[2:])}</li>")
        elif s.startswith("> "):
            closeul(); out.append(f'<p class="muted">{inline(s[2:])}</p>')
        elif s.startswith("---"):
            closeul(); out.append("<hr>")
        else:
            closeul(); out.append(f"<p>{inline(s)}</p>")
    closeul()
    return "\n".join(out) or '<p class="muted">—</p>'

focus, todo, totest, tofix = read("FOCUS.md"), read("TODO.md"), read("TO_TEST.md"), read("TO_FIX.md")
done, fixed, progress = read("DONE.md"), read("FIXED.md"), read("PROGRESS.md")
project_name = first_h1(read("PROJECT.md"), os.path.basename(proj))

def bullets_with(text, mark):
    return [l.strip() for l in text.splitlines() if mark in l and l.strip().startswith("-")]

obj_now = bullets_with(focus, "🔄")
obj_val = bullets_with(focus, "🧪")

n_todo   = sum(1 for l in todo.splitlines() if l.strip().startswith("#### "))
n_test   = sum(1 for l in totest.splitlines() if l.strip().startswith("- [ ]"))
_sev = re.compile(r'^###\s+[🔴🟡🟢⚪🟠]?\s*(critic|alt|medi|bass|high|low|medium)', re.I)
n_fix    = sum(1 for l in tofix.splitlines() if l.strip().startswith("### ") and "nessun" not in l.lower() and not _sev.match(l.strip()))
done_titles = [re.sub(r'^###\s+', '', l.strip()) for l in done.splitlines() if l.strip().startswith("### ")]
n_done   = len(done_titles)

def grab(rx):
    m = re.search(rx, progress)
    return m.group(1).strip() if m else ""
last_session = grab(r'Last session:\s*(.*)')
last_updated = grab(r'Last updated:\s*(.*)')

# --- sezioni ---
now_html = render_md("## In volo\n" + "\n".join(obj_now + obj_val)) if (obj_now or obj_val) else '<p class="muted">Nessun obiettivo in FOCUS.</p>'
manca_html = (
    '<h3>📋 Da fare</h3>' + render_md(todo) +
    '<h3>🧪 Da verificare</h3>' + render_md(totest) +
    ('<h3>🐛 Bug aperti</h3>' + render_md(tofix) if n_fix else '')
)
fatto_items = "".join(f"<li>{inline(t)}</li>" for t in done_titles[:8]) or '<li class="muted">—</li>'
fatto_html = f"<ul>{fatto_items}</ul>"

def tile(num, label, cls):
    return f'<div class="tile {cls}"><div class="num">{num}</div><div class="lbl">{label}</div></div>'

tiles = (
    tile(len(obj_now), "obiettivo in corso", "t-now") +
    tile(n_todo, "da fare", "t-todo") +
    tile(n_test, "da verificare", "t-test") +
    tile(n_fix, "bug aperti", "t-fix") +
    tile(n_done, "fatto (recente)", "t-done")
)

CSS = """
*{box-sizing:border-box} :root{--bg:#0f1220;--card:#171b2e;--bd:#282e49;--tx:#e7e9f3;--mut:#9aa0bd;--acc:#6ee7d0;--now:#f5b544;--todo:#7aa2ff;--test:#c792ea;--fix:#ff6b6b;--done:#5ad19b}
@media(prefers-color-scheme:light){:root{--bg:#f5f6fb;--card:#fff;--bd:#e3e6f0;--tx:#1b1e2b;--mut:#5b6178;--acc:#0ea88a}}
html,body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif}
.wrap{max-width:1200px;margin:0 auto;padding:28px}
header h1{margin:0 0 4px;font-size:26px} header .sub{color:var(--mut);font-size:13px}
.tiles{display:flex;gap:12px;flex-wrap:wrap;margin:20px 0}
.tile{flex:1;min-width:130px;background:var(--card);border:1px solid var(--bd);border-radius:14px;padding:14px 16px}
.tile .num{font-size:28px;font-weight:700} .tile .lbl{color:var(--mut);font-size:12px;text-transform:uppercase;letter-spacing:.04em}
.t-now .num{color:var(--now)} .t-todo .num{color:var(--todo)} .t-test .num{color:var(--test)} .t-fix .num{color:var(--fix)} .t-done .num{color:var(--done)}
.cols{display:grid;grid-template-columns:1.1fr 1.1fr .9fr;gap:16px}
@media(max-width:900px){.cols{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--bd);border-radius:16px;padding:18px 20px;overflow:auto}
.card>.ttl{font-weight:700;font-size:13px;text-transform:uppercase;letter-spacing:.05em;color:var(--mut);margin:0 0 10px}
.card.now{border-color:var(--now)} .card.now>.ttl{color:var(--now)}
.card h3{font-size:13px;text-transform:uppercase;letter-spacing:.04em;color:var(--mut);margin:16px 0 6px}
.card h4{margin:10px 0 4px;font-size:15px} .card p{margin:6px 0} .card ul{margin:6px 0;padding-left:18px}
.card li{margin:4px 0} li.box{list-style:none;margin-left:-18px} li.boxd{list-style:none;margin-left:-18px;color:var(--done)}
code{background:rgba(127,127,127,.16);padding:1px 5px;border-radius:5px;font-size:.9em}
.muted{color:var(--mut)} hr{border:0;border-top:1px solid var(--bd);margin:12px 0}
footer{color:var(--mut);font-size:12px;margin-top:22px;text-align:center}
"""

htmlout = f"""<!doctype html><html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Cruscotto · {html.escape(project_name)}</title><style>{CSS}</style></head>
<body><div class="wrap">
<header><h1>🧭 {html.escape(project_name)}</h1>
<div class="sub">Ultima sessione: {html.escape(last_session) or '—'} · agg. {html.escape(last_updated) or '—'}</div></header>
<div class="tiles">{tiles}</div>
<div class="cols">
  <div class="card now"><div class="ttl">🎯 Obiettivo · ORA</div>{now_html}</div>
  <div class="card"><div class="ttl">📋 Manca · DOPO</div>{manca_html}</div>
  <div class="card"><div class="ttl">✅ Fatto (recente)</div>{fatto_html}</div>
</div>
<footer>cruscotto locale · reso da design-log/ · {html.escape(proj)}</footer>
</div></body></html>"""

outdir = os.path.join(DL, ".cruscotto")
os.makedirs(outdir, exist_ok=True)
with open(os.path.join(outdir, "index.html"), "w", encoding="utf-8") as f:
    f.write(htmlout)
print(os.path.join(outdir, "index.html"))
