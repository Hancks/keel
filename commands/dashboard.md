---
description: "Generate and open the keel dashboard — a single page with a cross-project overview plus per-project drill-in, rendered from your design-log files."
argument-hint: "[root-or-project ...]"
---

Generate the keel dashboard and open it, served locally from `reports/`.

1. Run the generator (pass any paths in `$ARGUMENTS` straight through as roots/projects; with none it uses `$KEEL_DASHBOARD_ROOTS`, then the config file `$KEEL_GLOBAL_DIR/dashboard.roots`, then the current directory). Capture the path it prints, copy the page into the local reports hub, then ensure the server:

   ```bash
   OUT="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.py" $ARGUMENTS | tail -1)"
   DIR="$(${CLAUDE_PLUGIN_ROOT}/scripts/serve-reports.sh dir)"; mkdir -p "$DIR"
   cp "$OUT" "$DIR/dashboard.html"
   URL="$(${CLAUDE_PLUGIN_ROOT}/scripts/serve-reports.sh ensure)"
   ```

2. Open the served page: `open "${URL}dashboard.html"` on macOS, `xdg-open "${URL}dashboard.html"` on Linux.

3. Tell the user the **local URL** `http://127.0.0.1:<port>/dashboard.html`, and that it auto-refreshes at the end of every turn (the Stop hook regenerates the dashboard and, when the local server is registered, refreshes `reports/dashboard.html` too). To aggregate several projects, add their roots — one per line — to `$KEEL_GLOBAL_DIR/dashboard.roots`.

The dashboard is a single self-contained HTML file (all data inline, no external network): an overview grid of projects (current objective, counts, staleness, untriaged inbox) with client-side drill-in into each project's FOCUS / TODO / TO_TEST / TO_FIX / recent DONE / sessions. It never writes to the design-log — it only renders it. It is served locally from `reports/` alongside `/report` and any other update (see `/serve-reports`).
