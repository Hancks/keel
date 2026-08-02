---
description: "Generate and open the keel dashboard — a single page with a cross-project overview plus per-project drill-in, rendered from your design-log files."
argument-hint: "[root-or-project ...]"
---

Generate the keel dashboard and open it in the browser.

1. Run the generator (pass any paths in `$ARGUMENTS` straight through as roots/projects; with none it uses `$KEEL_DASHBOARD_ROOTS`, then the config file `$KEEL_GLOBAL_DIR/dashboard.roots`, then the current directory):

   ```
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.py" $ARGUMENTS
   ```

2. The script prints the path of the generated `index.html`. Open it: `open "<path>"` on macOS, `xdg-open "<path>"` on Linux.

3. Tell the user the path, and that it auto-refreshes at the end of every turn (the Stop hook regenerates it). To aggregate several projects, add their roots — one per line — to `$KEEL_GLOBAL_DIR/dashboard.roots`.

The dashboard is a single self-contained HTML file (all data inline, no server, no network): an overview grid of projects (current objective, counts, staleness, untriaged inbox) with client-side drill-in into each project's FOCUS / TODO / TO_TEST / TO_FIX / recent DONE / sessions. It never writes to the design-log — it only renders it.
