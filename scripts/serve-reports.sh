#!/usr/bin/env bash
# keel — local static report server, per project.
#
# Serves the <project>/reports/ folder on 127.0.0.1:<port> (loopback ONLY, never
# exposed). It's the local hub for ALL communication between the user and the
# method: reports (/report), the dashboard (/dashboard), and any other update/
# artifact HTML keel produces while working. The user opens them at a stable local
# URL — not on an external service, not as clumsy file:// links.
#
# Robust by construction: no `set -e`; every branch degrades without crashing the
# session. Depends on python3 (already required — it is also the file server).
#
# Per-project registry: <project>/reports/.server.json  {port,pid,url,host,started_at}
# The reports/ folder is gitignored (reports are local/ephemeral, out of git history).
#
# Subcommands:
#   ensure    Ensure a server is up (start it if needed). Idempotent. Prints the base URL.
#   start     Alias of ensure (explicit start).
#   stop      Stop the registered server (kill its PID) and clear the registry.
#   status    State: running/stopped, port, pid, url.
#   url       Print the base URL if running (empty if stopped).
#   reindex   Regenerate reports/index.html listing every HTML file in the folder.
#   dir       Print the absolute path of the project's reports/ folder.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
REPORTS_DIR="$PROJECT_DIR/reports"
REGISTRY="$REPORTS_DIR/.server.json"
DEFAULT_PORT="${KEEL_REPORTS_PORT:-8912}"
BIND="127.0.0.1"

# --- registry (JSON via python3) -------------------------------------------
registry_get() { # $1=field
  [ -f "$REGISTRY" ] || return 0
  python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get(sys.argv[2],""))
except Exception: pass' "$REGISTRY" "$1" 2>/dev/null
}

write_registry() { # $1=port $2=pid
  python3 -c 'import json,sys,socket,time
port=int(sys.argv[2]); pid=int(sys.argv[3])
json.dump({"port":port,"pid":pid,"url":"http://127.0.0.1:%d/"%port,
          "host":socket.gethostname(),
          "started_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())},
          open(sys.argv[1],"w"),indent=2)' "$REGISTRY" "$1" "$2" 2>/dev/null
}

# is the port free? (bind test — portable, does not depend on lsof)
port_free() { # $1=port
  python3 -c 'import socket,sys
s=socket.socket()
try:
    s.bind(("127.0.0.1",int(sys.argv[1]))); s.close(); sys.exit(0)
except OSError:
    sys.exit(1)' "$1" 2>/dev/null
}

find_free_port() {
  local i p
  for i in $(seq 0 60); do
    p=$((DEFAULT_PORT + i))
    if port_free "$p"; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

# is a server alive for THIS project? (pid alive + port occupied)
is_alive() {
  [ -f "$REGISTRY" ] || return 1
  local pid port; pid="$(registry_get pid)"; port="$(registry_get port)"
  [ -n "$pid" ] && [ -n "$port" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if port_free "$port"; then return 1; else return 0; fi
}

# --- reports/ folder + gitignore -------------------------------------------
gitignore_reports() {
  local gi="$PROJECT_DIR/.gitignore"
  # only manage .gitignore if this is a git repo or a .gitignore already exists
  [ -d "$PROJECT_DIR/.git" ] || [ -f "$gi" ] || return 0
  if [ -f "$gi" ]; then
    grep -qxF 'reports/' "$gi" 2>/dev/null && return 0
    # newline-safety: if the last line has no trailing \n, add one before appending
    [ -s "$gi" ] && [ -n "$(tail -c1 "$gi" 2>/dev/null)" ] && printf '\n' >> "$gi"
    printf 'reports/\n' >> "$gi"
  else
    printf 'reports/\n' > "$gi"
  fi
}

ensure_reports_dir() {
  mkdir -p "$REPORTS_DIR" 2>/dev/null || return 1
  gitignore_reports
  [ -f "$REPORTS_DIR/index.html" ] || cmd_reindex >/dev/null 2>&1
}

# --- subcommands ------------------------------------------------------------
cmd_reindex() {
  mkdir -p "$REPORTS_DIR" 2>/dev/null || return 1
  python3 - "$REPORTS_DIR" <<'PY'
import os, sys, html, datetime
d = sys.argv[1]
items = []
for name in os.listdir(d):
    if not name.lower().endswith(".html") or name == "index.html":
        continue
    p = os.path.join(d, name)
    try: mt = os.path.getmtime(p)
    except OSError: mt = 0
    items.append((mt, name))
items.sort(reverse=True)
rows = []
for mt, name in items:
    when = datetime.datetime.fromtimestamp(mt).strftime("%Y-%m-%d %H:%M") if mt else ""
    title = os.path.splitext(name)[0].replace("-", " ").replace("_", " ").strip()
    rows.append(
        f'<li><a href="./{html.escape(name)}">{html.escape(title)}</a>'
        f'<span class="when">{html.escape(when)}</span></li>'
    )
body = "\n".join(rows) if rows else '<li class="empty">No reports yet — run /report or /dashboard.</li>'
gen = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
proj = html.escape(os.path.basename(os.path.dirname(os.path.abspath(d))))
page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>keel · reports · {proj}</title>
<style>
:root{{--bg:#f7f5f0;--fg:#1c1a17;--mut:#6b655c;--card:#fffdf8;--line:#e5e0d6;--acc:#8a5a2b}}
@media (prefers-color-scheme:dark){{:root{{--bg:#16140f;--fg:#ece7dd;--mut:#9a9284;--card:#201d17;--line:#332f27;--acc:#d8a15e}}}}
:root[data-theme="dark"]{{--bg:#16140f;--fg:#ece7dd;--mut:#9a9284;--card:#201d17;--line:#332f27;--acc:#d8a15e}}
:root[data-theme="light"]{{--bg:#f7f5f0;--fg:#1c1a17;--mut:#6b655c;--card:#fffdf8;--line:#e5e0d6;--acc:#8a5a2b}}
*{{box-sizing:border-box}}
body{{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}}
.wrap{{max-width:760px;margin:0 auto;padding:48px 24px}}
.eyebrow{{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mut);font-family:ui-monospace,SFMono-Regular,Menlo,monospace}}
h1{{font-size:28px;margin:.2em 0 .1em}}
.sub{{color:var(--mut);margin:0 0 28px}}
ul{{list-style:none;margin:0;padding:0;border-top:1px solid var(--line)}}
li{{display:flex;align-items:baseline;justify-content:space-between;gap:16px;padding:14px 4px;border-bottom:1px solid var(--line)}}
li a{{color:var(--fg);text-decoration:none;font-weight:600}}
li a:hover{{color:var(--acc);text-decoration:underline}}
.when{{color:var(--mut);font-size:13px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;white-space:nowrap}}
.empty{{color:var(--mut);justify-content:flex-start}}
footer{{color:var(--mut);font-size:13px;margin-top:28px}}
</style></head>
<body><div class="wrap">
<div class="eyebrow">keel · reports · {proj}</div>
<h1>Reports &amp; updates</h1>
<p class="sub">The local record of communication between you and the method — served from <code>reports/</code>, on <code>127.0.0.1</code>.</p>
<ul>
{body}
</ul>
<footer>{gen} · self-contained · loopback only</footer>
</div></body></html>"""
open(os.path.join(d, "index.html"), "w", encoding="utf-8").write(page)
PY
  echo "$REPORTS_DIR/index.html"
}

cmd_ensure() {
  ensure_reports_dir || { echo "ERROR: cannot create $REPORTS_DIR" >&2; return 1; }
  if is_alive; then
    cmd_reindex >/dev/null 2>&1
    registry_get url
    return 0
  fi
  # stale registry or server down → start clean
  rm -f "$REGISTRY" 2>/dev/null
  local port pid
  port="$(find_free_port)" || { echo "ERROR: no free port from $DEFAULT_PORT" >&2; return 1; }
  nohup python3 -m http.server "$port" --bind "$BIND" --directory "$REPORTS_DIR" >/dev/null 2>&1 &
  pid=$!
  # minimal check: is the process still alive?
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "ERROR: server failed to start on port $port" >&2; return 1
  fi
  write_registry "$port" "$pid"
  cmd_reindex >/dev/null 2>&1
  printf 'http://%s:%s/\n' "$BIND" "$port"
}

cmd_stop() {
  if [ -f "$REGISTRY" ]; then
    local pid port; pid="$(registry_get pid)"; port="$(registry_get port)"
    # kill ONLY the registered pid (our listener) — never a blind `kill $(lsof -ti :port)`,
    # which would also take down any clients connected to the port.
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; fi
    rm -f "$REGISTRY" 2>/dev/null
    echo "🛑 keel report server stopped (was pid ${pid:-?}, port ${port:-?})"
  else
    echo "ℹ️ no keel report server registered for this project"
  fi
}

cmd_status() {
  if is_alive; then
    printf 'running · %s · port %s · pid %s\n' "$(registry_get url)" "$(registry_get port)" "$(registry_get pid)"
  elif [ -f "$REGISTRY" ]; then
    printf 'stopped (stale registry) · was port %s pid %s\n' "$(registry_get port)" "$(registry_get pid)"
  else
    echo "stopped · no server registered"
  fi
}

cmd_url() { is_alive && registry_get url || true; }
cmd_dir() { printf '%s\n' "$REPORTS_DIR"; }

case "${1:-}" in
  ensure|start) cmd_ensure ;;
  stop)         cmd_stop ;;
  status)       cmd_status ;;
  url)          cmd_url ;;
  reindex)      cmd_reindex ;;
  dir)          cmd_dir ;;
  *) echo "usage: serve-reports.sh {ensure|start|stop|status|url|reindex|dir}" >&2; exit 2 ;;
esac
