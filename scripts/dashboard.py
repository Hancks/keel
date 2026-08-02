#!/usr/bin/env python3
# keel dashboard — one self-contained HTML app: cross-project overview + client-side
# drill-in. NOT a source of truth: it renders the existing design-log files (zero drift).
#
# Usage:
#   dashboard.py [root_or_project ...]      explicit roots/projects on the CLI
#   dashboard.py                            roots from $KEEL_DASHBOARD_ROOTS, else the
#                                           config file, else the current directory
#
# Config (most-agile, plain text): $KEEL_GLOBAL_DIR/dashboard.roots
#   - one path per line: a ROOT to scan, or an explicit PROJECT dir (has design-log/)
#   - blank lines and lines starting with '#' are ignored; ~ and $VARS are expanded
# Env override: KEEL_DASHBOARD_ROOTS  (colon-separated list of roots/projects)
#
# Output (single file, one place): $KEEL_GLOBAL_DIR/dashboard/index.html
import sys, os, re, html, glob, json, datetime

GLOBAL_DIR = os.path.expanduser(os.environ.get("KEEL_GLOBAL_DIR", "~/.claude-method"))
TODAY = datetime.date.today()

# ---------------------------------------------------------------- config / discovery
def config_entries():
    # 1) explicit CLI args win
    if len(sys.argv) > 1:
        return [os.path.abspath(os.path.expanduser(a)) for a in sys.argv[1:]]
    # 2) env override
    env = os.environ.get("KEEL_DASHBOARD_ROOTS", "").strip()
    if env:
        return [os.path.abspath(os.path.expanduser(os.path.expandvars(p)))
                for p in env.split(":") if p.strip()]
    # 3) config file
    cfg = os.path.join(GLOBAL_DIR, "dashboard.roots")
    entries = []
    if os.path.isfile(cfg):
        for line in open(cfg, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            entries.append(os.path.abspath(os.path.expanduser(os.path.expandvars(line))))
    if entries:
        return entries
    # 4) default: current directory
    return [os.path.abspath(os.getcwd())]

def is_project(d):
    return os.path.isfile(os.path.join(d, "design-log", "PROJECT.md"))

def discover(entries):
    found = set()
    for e in entries:
        if is_project(e):
            found.add(e)
            continue
        # treat as a root: scan a few levels deep for design-log/PROJECT.md
        for pat in ("design-log/PROJECT.md", "*/design-log/PROJECT.md",
                    "*/*/design-log/PROJECT.md", "*/*/*/design-log/PROJECT.md"):
            for f in glob.glob(os.path.join(e, pat)):
                found.add(os.path.dirname(os.path.dirname(f)))
    return sorted(found, key=lambda p: os.path.basename(p).lower())

# ---------------------------------------------------------------- markdown-lite → html
def inline(t):
    t = html.escape(t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'~~(.+?)~~', r'<del>\1</del>', t)
    t = re.sub(r'`(.+?)`', r'<code>\1</code>', t)
    t = re.sub(r'\[(.+?)\]\((.+?)\)', r'\1', t)   # link text only (offline, no nav out)
    return t

def render_md(text, skip_h1=True, skip_quotes=False):
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
            closeul()
            if not skip_quotes: out.append(f'<p class="muted">{inline(s[2:])}</p>')
        elif s.startswith("---"):
            closeul(); out.append("<hr>")
        else:
            closeul(); out.append(f"<p>{inline(s)}</p>")
    closeul()
    return "\n".join(out) or '<p class="muted">—</p>'

def cap(text, n=32):
    """Anteprima del drill-in: prime n righe + nota se troncato (i file di lavoro
    possono avere centinaia di voci; il dump integrale rende la pagina illeggibile)."""
    lines = text.splitlines()
    if len(lines) <= n:
        return text
    return "\n".join(lines[:n]) + "\n\n— (preview troncata · apri il file per il resto)"

def items_html(text, kind, cap_n=12):
    """Rende un file di lavoro come find-card (chip/titolo/riga), stile v2 — NON dump."""
    items = []
    lines = text.splitlines()
    if kind == 'todo':
        i = 0
        while i < len(lines):
            m = re.match(r'^####\s+(.*)', lines[i].strip())
            if m:
                title = m.group(1); desc = ''
                for j in range(i + 1, min(i + 10, len(lines))):
                    s = lines[j].strip()
                    if re.match(r'^#{2,4}\s', s): break
                    mw = re.match(r'^\*\*(?:What|Cosa):?\*\*\s*(.*)', s)
                    if mw and mw.group(1): desc = mw.group(1); break
                items.append((title, desc))
            i += 1
    elif kind == 'check':
        for l in lines:
            m = re.match(r'^\s*-\s*\[[ xX]\]\s*(.*)', l)
            if m and m.group(1).strip(): items.append((m.group(1), ''))
    elif kind == 'fix':
        for l in lines:
            s = l.strip()
            if s.startswith('### ') and 'nessun' not in s.lower() and not _SEV.match(s):
                items.append((re.sub(r'^###\s+', '', s), ''))
    if not items:
        return '<p class="muted">—</p>'
    more = len(items) - cap_n
    cards = []
    for title, desc in items[:cap_n]:
        d = '<p class="fd">' + inline(desc) + '</p>' if desc else ''
        cards.append('<div class="find"><div class="ft">' + inline(title) + '</div>' + d + '</div>')
    if more > 0:
        cards.append('<p class="muted">…and ' + str(more) + ' more (open the file)</p>')
    return "".join(cards)

def focus_html(text):
    out = []
    for mark, label, cls in (('🔄', 'in progress', 'now'), ('🧪', 'to validate', 'test'), ('⏸️', 'queued', '')):
        for line in bullets_with(text, mark):
            title = clean_obj(line)
            if title:
                out.append('<div class="find"><div class="ft"><span class="fchip ' + cls + '">' + label + '</span> ' + inline(title) + '</div></div>')
    return "".join(out) or '<p class="muted">—</p>'

# ---------------------------------------------------------------- extraction
_SEV = re.compile(r'^###\s+[🔴🟡🟢⚪🟠]?\s*(critic|alt|medi|bass|high|low|medium)', re.I)

def read(dl, name):
    try:
        return open(os.path.join(dl, name), encoding="utf-8").read()
    except Exception:
        return ""

def first_h1(text, default):
    for l in text.splitlines():
        m = re.match(r'#\s+(.*)', l)
        if m:
            return re.sub(r'^(Project|Progetto)\s*[—–-]\s*', '', m.group(1).strip())
    return default

def bullets_with(text, mark):
    return [l.strip() for l in text.splitlines() if mark in l and l.strip().startswith("-")]

def clean_obj(line):
    o = re.sub(r'^\-\s*[🔄🧪⏸️]\s*', '', line)
    o = re.sub(r'⟨.*?⟩', '', o)
    o = re.sub(r'\*\*(.+?)\*\*', r'\1', o)
    o = re.sub(r'`(.+?)`', r'\1', o)
    o = re.sub(r'\[(.+?)\]\(.+?\)', r'\1', o).strip()
    return o

def newest_session(dl):
    files = sorted(os.path.basename(f) for f in glob.glob(os.path.join(dl, "sessions", "[0-9]*.md")))
    return files[-1] if files else ""

def session_days(fname):
    m = re.match(r'(\d{4})-(\d{2})-(\d{2})', fname or "")
    if not m:
        return None
    try:
        d = datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        return (TODAY - d).days
    except Exception:
        return None

def staleness(days):
    if days is None: return "none"
    if days <= 3:    return "fresh"
    if days <= 14:   return "aging"
    return "stale"

def active_designlogs(dl):
    out = []
    for f in sorted(glob.glob(os.path.join(dl, "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md"))):
        try:
            head = open(f, encoding="utf-8").read(4000)
        except Exception:
            continue
        m = re.search(r'^\s*>?\s*Status:\s*([A-Za-z]+)', head, re.M)
        status = m.group(1) if m else "?"
        if status.lower() != "implemented":
            out.append({"file": os.path.basename(f), "status": status})
    return out

def extract(proj):
    dl = os.path.join(proj, "design-log")
    focus  = read(dl, "FOCUS.md"); todo = read(dl, "TODO.md")
    totest = read(dl, "TO_TEST.md"); tofix = read(dl, "TO_FIX.md")
    done   = read(dl, "DONE.md"); fixed = read(dl, "FIXED.md")
    inbox  = read(dl, "INBOX.md"); progress = read(dl, "PROGRESS.md")
    name = first_h1(read(dl, "PROJECT.md"), os.path.basename(proj))

    obj_now = bullets_with(focus, "🔄")
    objective = clean_obj(obj_now[0]) if obj_now else ""

    counts = {
        "todo":   sum(1 for l in todo.splitlines()   if l.strip().startswith("#### ")),
        "totest": sum(1 for l in totest.splitlines() if l.strip().startswith("- [ ]")),
        "tofix":  sum(1 for l in tofix.splitlines()
                      if l.strip().startswith("### ") and "nessun" not in l.lower() and not _SEV.match(l.strip())),
        "done":   sum(1 for l in done.splitlines()   if l.strip().startswith("### ")),
    }
    inbox_untriaged = sum(1 for l in inbox.splitlines() if l.strip().startswith("- [ ]"))
    sess = newest_session(dl)
    days = session_days(sess)

    done_titles  = [re.sub(r'^###\s+', '', l.strip()) for l in done.splitlines()  if l.strip().startswith("### ")][:10]
    fixed_titles = [re.sub(r'^###\s+', '', l.strip()) for l in fixed.splitlines() if l.strip().startswith("### ")][:10]
    sessions = list(reversed(sorted(os.path.basename(f) for f in glob.glob(os.path.join(dl, "sessions", "[0-9]*.md")))))[:12]

    detail = {
        "focus":  focus_html(focus),
        "todo":   items_html(todo, 'todo'),
        "tofix":  items_html(tofix, 'fix') if counts["tofix"] else "",
        "totest": items_html(totest, 'check'),
        "done_titles":  [inline(t) for t in done_titles],
        "fixed_titles": [inline(t) for t in fixed_titles],
        "sessions": sessions,
        "active_designlogs": active_designlogs(dl),
    }
    return {
        "name": name, "path": proj, "objective": objective,
        "counts": counts, "inbox": inbox_untriaged,
        "last_session": sess, "days": days, "staleness": staleness(days),
        "detail": detail,
    }

# ---------------------------------------------------------------- render page
CSS = r"""
*{box-sizing:border-box}
:root{
  --plane:#f7f7f5; --surface:#ffffff; --ink:#1d1f1e; --ink2:#3f423f; --muted:#6b6f6d;
  --bd:#e4e5e2; --hair:#ececea;
  --todo:#0f6f68; --test:#0f6f68; --fix:#b4372f; --done:#2c7a3f; --now:#0f6f68;
  --good:#2c7a3f; --warn:#a86a0a; --serious:#a86a0a; --crit:#b4372f;
  --mono:ui-monospace,"SF Mono",Menlo,Consolas,monospace;
  color-scheme:light;
}
@media (prefers-color-scheme:dark){:root:where(:not([data-theme="light"])){
  --plane:#16181a; --surface:#1e2124; --ink:#e8e8e6; --ink2:#c3c2b7; --muted:#9a9e9c;
  --bd:#2c3033; --hair:#24272a;
  --todo:#4fb3a9; --test:#4fb3a9; --fix:#e07a70; --done:#6cc283; --now:#4fb3a9;
  color-scheme:dark;
}}
:root[data-theme="dark"]{
  --plane:#16181a; --surface:#1e2124; --ink:#e8e8e6; --ink2:#c3c2b7; --muted:#9a9e9c;
  --bd:#2c3033; --hair:#24272a;
  --todo:#4fb3a9; --test:#4fb3a9; --fix:#e07a70; --done:#6cc283; --now:#4fb3a9;
  color-scheme:dark;
}
html,body{margin:0;background:var(--plane);color:var(--ink);
  font:16px/1.55 -apple-system,system-ui,"Segoe UI",Roboto,sans-serif}
a{color:var(--now)}
.wrap{max-width:1140px;margin:0 auto;padding:40px 24px 90px}
.top{display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-bottom:24px}
.eyebrow{font-size:.72rem;text-transform:uppercase;letter-spacing:.1em;color:var(--now);font-weight:600;margin-bottom:8px}
.top h1{margin:0;font-size:1.7rem;letter-spacing:-.01em;text-wrap:balance}
.spacer{flex:1}
.btn{border:1px solid var(--bd);background:var(--surface);color:var(--ink2);
  border-radius:8px;padding:6px 11px;font-size:.8rem;font-family:var(--mono);cursor:pointer}
.btn:hover{border-color:var(--now);color:var(--now)}
.controls{display:flex;gap:12px;align-items:center;margin:0 0 22px}
.search{flex:1;max-width:340px;border:1px solid var(--bd);background:var(--surface);
  color:var(--ink);border-radius:8px;padding:8px 12px;font-size:14px}
.search::placeholder{color:var(--muted)}
.count{color:var(--muted);font-size:.78rem;font-family:var(--mono)}

/* overview grid */
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px}
.card{display:block;text-align:left;width:100%;background:var(--surface);
  border:1px solid var(--bd);border-radius:10px;padding:16px 18px;cursor:pointer;transition:border-color .14s}
.card:hover{border-color:var(--now)}
.card .nm{font-weight:650;font-size:1.04rem;margin-bottom:5px;letter-spacing:-.005em}
.card .obj{color:var(--ink2);font-size:.9rem;margin-bottom:13px;min-height:2.4em;
  display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.card .obj.none{color:var(--muted);font-style:italic}
.tiles{display:flex;gap:7px;flex-wrap:wrap;align-items:center}
.tile{display:inline-flex;align-items:baseline;gap:5px;font-size:.72rem;font-family:var(--mono);
  border:1px solid var(--bd);border-radius:20px;padding:3px 10px;color:var(--muted)}
.tile b{font-size:.8rem;color:var(--ink);font-variant-numeric:tabular-nums}
.tile.fix{border-color:var(--fix);color:var(--fix)} .tile.fix b{color:var(--fix)}
.tile.done b{color:var(--done)}
.chip{display:inline-flex;align-items:center;gap:5px;font-size:.72rem;font-family:var(--mono);padding:3px 9px;
  border-radius:20px;border:1px solid var(--bd);color:var(--muted)}
.chip .dot{width:7px;height:7px;border-radius:50%}
.dot.fresh{background:var(--good)} .dot.aging{background:var(--warn)}
.dot.stale{background:var(--crit)} .dot.none{background:var(--muted)}
.chip.inbox{border-color:var(--warn)} .chip.inbox b{color:var(--warn)}
.meta{display:flex;gap:8px;flex-wrap:wrap;margin-top:11px;align-items:center}

/* detail — editorial: left lettered index + stacked sections */
.detail{display:none}
.detail.on{display:block}
.grid.off{display:none}
.back{display:inline-flex;gap:7px;align-items:center;margin-bottom:16px;text-decoration:none;font-family:var(--mono);font-size:.8rem}
.dhead{margin:2px 0 4px;font-size:1.7rem;letter-spacing:-.01em;text-wrap:balance}
.dpath{color:var(--muted);font-size:.78rem;font-family:var(--mono);margin-bottom:22px;word-break:break-all}
.dlayout{display:grid;grid-template-columns:1fr;gap:0}
@media(min-width:940px){.dlayout{grid-template-columns:172px minmax(0,1fr);gap:40px}}
nav.didx{display:none}
@media(min-width:940px){nav.didx{display:block;position:sticky;top:28px;align-self:start}
  nav.didx ol{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:10px}
  nav.didx a{font-size:.82rem;color:var(--muted);text-decoration:none;line-height:1.4}
  nav.didx a:hover{color:var(--now)}
  nav.didx .k{color:var(--now);font-family:var(--mono);font-size:.78rem;display:inline-block;min-width:20px}}
.dmain{min-width:0}
.dsec{margin:0 0 30px;scroll-margin-top:24px}
.dsec>h2{font-size:1.22rem;margin:0 0 12px;letter-spacing:-.01em}
.panel{background:var(--surface);border:1px solid var(--bd);border-radius:10px;padding:16px 18px;overflow:auto;margin-bottom:12px}
.panel.now{border-color:var(--now)}
.panel h3{font-size:.72rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);margin:14px 0 6px}
.panel h3:first-child{margin-top:0}
.panel h4{margin:10px 0 4px;font-size:.95rem}
.panel p{margin:6px 0} .panel ul{margin:6px 0;padding-left:18px} .panel li{margin:4px 0}
li.box{list-style:none;margin-left:-18px} li.boxd{list-style:none;margin-left:-18px;color:var(--done)}
code{font-family:var(--mono);background:color-mix(in srgb,var(--now) 13%,transparent);padding:1px 5px;border-radius:4px;font-size:.82em}
del{color:var(--muted)}
.muted{color:var(--muted)} hr{border:0;border-top:1px solid var(--hair);margin:12px 0}
.slist{list-style:none;padding:0;margin:0}
.slist li{padding:3px 0;border-bottom:1px solid var(--hair);font-size:.8rem;font-family:var(--mono)}
.badge-dl{display:inline-block;font-size:.68rem;font-family:var(--mono);border:1px solid var(--bd);border-radius:6px;
  padding:1px 6px;color:var(--ink2);margin-left:6px}
footer{color:var(--muted);font-size:.82rem;margin-top:40px;border-top:1px solid var(--bd);padding-top:18px;max-width:84ch}
.empty{color:var(--muted);text-align:center;padding:60px 0}
.dtiles{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 22px}
.dtile{border:1px solid var(--bd);border-radius:10px;padding:11px 15px;min-width:96px;background:var(--surface)}
.dtile .n{font-size:1.5rem;font-weight:700;font-variant-numeric:tabular-nums;letter-spacing:-.02em;line-height:1.05}
.dtile .l{font-size:.66rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);margin-top:3px}
.dtile.fix .n{color:var(--fix)} .dtile.done .n{color:var(--done)}
.dsec h3{font-size:.7rem;text-transform:uppercase;letter-spacing:.07em;color:var(--muted);margin:20px 0 8px}
.find{border:1px solid var(--bd);border-radius:8px;padding:11px 14px;margin-bottom:9px;background:var(--surface)}
.find .ft{font-size:.92rem;font-weight:600;letter-spacing:-.005em;line-height:1.4}
.find .fd{margin:5px 0 0;font-size:.85rem;color:var(--ink2)}
.fchip{display:inline-block;font-family:var(--mono);font-size:.64rem;font-weight:600;padding:2px 8px;border-radius:20px;border:1px solid var(--bd);color:var(--muted);margin-right:7px}
.fchip.now{color:var(--now);border-color:var(--now)} .fchip.test{color:var(--test);border-color:var(--test)}
"""

JS = r"""
const D = (window.__DATA__ && window.__DATA__.projects) || [];
const $ = s => document.querySelector(s);
const el = (t,c,h) => { const e=document.createElement(t); if(c)e.className=c; if(h!=null)e.innerHTML=h; return e; };
const esc = s => (s==null?'':String(s)).replace(/[&<>"]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[m]));

// theme toggle: auto -> light -> dark -> auto
function applyTheme(t){ const r=document.documentElement;
  if(t==='auto') r.removeAttribute('data-theme'); else r.setAttribute('data-theme',t);
  $('#theme').textContent = t==='auto' ? 'Auto' : (t==='light' ? 'Light' : 'Dark'); }
let theme = localStorage.getItem('keel-theme') || 'auto';
function cycleTheme(){ theme = theme==='auto'?'light':theme==='light'?'dark':'auto';
  localStorage.setItem('keel-theme',theme); applyTheme(theme); }

function agoLabel(p){
  if(p.days==null) return 'no sessions';
  if(p.days===0) return 'today';
  if(p.days===1) return 'yesterday';
  return p.days+'d ago';
}
function score(p){ // sort: bugs first, then stale, then most open work
  return [ p.counts.tofix>0?0:1, p.staleness==='stale'?0:p.staleness==='aging'?1:2,
           -(p.counts.todo+p.counts.totest), p.name.toLowerCase() ];
}
function cmp(a,b){ const x=score(a),y=score(b);
  for(let i=0;i<x.length;i++){ if(x[i]<y[i])return -1; if(x[i]>y[i])return 1; } return 0; }

function card(p,i){
  const c = el('button','card'); c.onclick = ()=>{ location.hash='p='+i; };
  c.appendChild(el('div','nm',esc(p.name)));
  c.appendChild(el('div','obj'+(p.objective?'':' none'), p.objective?esc(p.objective):'no current objective'));
  const t = el('div','tiles');
  t.innerHTML =
    `<span class="tile todo"><b>${p.counts.todo}</b> to&nbsp;do</span>`+
    `<span class="tile test"><b>${p.counts.totest}</b> to&nbsp;verify</span>`+
    (p.counts.tofix?`<span class="tile fix"><b>${p.counts.tofix}</b> bugs</span>`:'')+
    `<span class="tile done"><b>${p.counts.done}</b> done</span>`;
  c.appendChild(t);
  const m = el('div','meta');
  m.innerHTML = `<span class="chip"><span class="dot ${p.staleness}"></span>${esc(agoLabel(p))}</span>`+
    (p.inbox?`<span class="chip inbox"><b>${p.inbox}</b> untriaged</span>`:'');
  c.appendChild(m);
  return c;
}

function renderOverview(filter){
  const grid = $('#grid'); grid.innerHTML='';
  const items = D.map((p,i)=>({p,i})).filter(o=>!filter ||
      o.p.name.toLowerCase().includes(filter) || (o.p.objective||'').toLowerCase().includes(filter));
  items.sort((a,b)=>cmp(a.p,b.p));
  if(!items.length){ grid.appendChild(el('div','empty','No projects match.')); }
  items.forEach(o=>grid.appendChild(card(o.p,o.i)));
  $('#count').textContent = D.length+' project'+(D.length===1?'':'s')+
    (filter?` · ${items.length} shown`:'');
}

function panelList(title, items, cls){
  if(!items || !items.length) return '';
  return `<h3>${title}</h3><ul class="slist">`+items.map(x=>`<li>${x}</li>`).join('')+`</ul>`;
}
function renderDetail(i){
  const p = D[i]; if(!p){ location.hash=''; return; }
  const d = p.detail;
  $('#dname').textContent = p.name;
  $('#dpath').textContent = p.path;
  const dl = (d.active_designlogs||[]).map(x=>`${esc(x.file)}<span class="badge-dl">${esc(x.status)}</span>`);
  const doneBody = (panelList('Done (recent)', d.done_titles)+panelList('Fixed (recent)', d.fixed_titles)
    +panelList('Active design logs', dl)+panelList('Sessions', (d.sessions||[]).map(esc))) || '<p class="muted">—</p>';
  const tiles = `<div class="dtiles">`+
    `<div class="dtile"><div class="n">${p.counts.todo}</div><div class="l">to do</div></div>`+
    `<div class="dtile"><div class="n">${p.counts.totest}</div><div class="l">to verify</div></div>`+
    `<div class="dtile fix"><div class="n">${p.counts.tofix}</div><div class="l">bugs</div></div>`+
    `<div class="dtile done"><div class="n">${p.counts.done}</div><div class="l">done</div></div></div>`;
  $('#dbody').innerHTML = tiles +
    `<div class="dlayout">
      <nav class="didx"><ol>
        <li><a href="#s-obj"><span class="k">A</span>Objective &amp; focus</a></li>
        <li><a href="#s-left"><span class="k">B</span>What's left</a></li>
        <li><a href="#s-done"><span class="k">C</span>Done &amp; log</a></li>
      </ol></nav>
      <div class="dmain">
        <section class="dsec" id="s-obj"><h2>A · Objective &amp; focus</h2>${d.focus||'<p class="muted">—</p>'}</section>
        <section class="dsec" id="s-left"><h2>B · What's left</h2>
          <h3>To do</h3>${d.todo||'<p class="muted">—</p>'}
          <h3>To verify</h3>${d.totest||'<p class="muted">—</p>'}
          ${d.tofix?('<h3>Open bugs</h3>'+d.tofix):''}</section>
        <section class="dsec" id="s-done"><h2>C · Done &amp; log</h2>
          <div class="panel">${doneBody}</div></section>
      </div>
    </div>`;
  $('#dbody').querySelectorAll('.didx a').forEach(a=>{
    a.addEventListener('click', e=>{ e.preventDefault();
      const t=document.getElementById(a.getAttribute('href').slice(1));
      if(t) t.scrollIntoView({behavior:'smooth',block:'start'}); });
  });
}

function route(){
  const m = location.hash.match(/p=(\d+)/);
  if(m){ $('#grid').classList.add('off'); $('#detail').classList.add('on');
    $('#controls').style.display='none'; renderDetail(+m[1]); window.scrollTo(0,0); }
  else { $('#grid').classList.remove('off'); $('#detail').classList.remove('on');
    $('#controls').style.display=''; }
}

applyTheme(theme);
renderOverview('');
route();
window.addEventListener('hashchange', route);
$('#theme').onclick = cycleTheme;
$('#search').addEventListener('input', e=>renderOverview(e.target.value.trim().toLowerCase()));
"""

def build_html(projects, sources):
    payload = json.dumps({"projects": projects}, ensure_ascii=False).replace("</", "<\\/")
    gen = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    src = html.escape(" · ".join(sources))
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>keel · dashboard</title><style>{CSS}</style></head>
<body><div class="wrap">
<div class="top">
  <div>
    <div class="eyebrow">keel · dashboard · across your projects</div>
    <h1>Where we are</h1>
  </div>
  <span class="spacer"></span>
  <button class="btn" id="theme">Auto</button>
</div>
<div class="controls" id="controls">
  <input class="search" id="search" type="search" placeholder="Filter projects…">
  <span class="count" id="count"></span>
</div>
<div class="grid" id="grid"></div>
<section class="detail" id="detail">
  <button class="btn back" onclick="location.hash=''">← All projects</button>
  <h2 class="dhead" id="dname"></h2>
  <div class="dpath" id="dpath"></div>
  <div id="dbody"></div>
</section>
<footer>rendered from design-log/ · {len(projects)} project(s) · {gen} · roots: {src}</footer>
</div>
<script>window.__DATA__ = {payload};</script>
<script>{JS}</script>
</body></html>"""

def main():
    entries = config_entries()
    projects_dirs = discover(entries)
    projects = [extract(p) for p in projects_dirs]
    outdir = os.path.join(GLOBAL_DIR, "dashboard")
    os.makedirs(outdir, exist_ok=True)
    outfile = os.path.join(outdir, "index.html")
    with open(outfile, "w", encoding="utf-8") as f:
        f.write(build_html(projects, entries))
    print(outfile)

if __name__ == "__main__":
    main()
