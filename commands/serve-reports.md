---
description: "Manage keel's local report server — a per-project static server (127.0.0.1 only) that serves everything keel writes to reports/: the narrated /report, the /dashboard, and any update the agent produces. start·stop·status. Idempotent; nothing is ever exposed off-loopback."
argument-hint: "[start|stop|status]"
---

Manage the **local reports server** for the current project. `reports/` is the local, gitignored hub for **all communication between you and the method** — the narrated `/report`, the `/dashboard`, and any ad-hoc update page keel writes. The server exposes them at a stable local URL (`http://127.0.0.1:<port>/`) instead of an external service or clumsy `file://` links. It binds **only** to `127.0.0.1` — never reachable off your machine.

`/report` and `/dashboard` start this server automatically, so you rarely need this command. Use it to start it explicitly, check its state, or stop it.

## Resolve the sub-command

Read `$ARGUMENTS`. If empty, default to **status**.

- **start** (or no server yet): ensure a server is running for this project.
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/serve-reports.sh ensure
  ```
  Idempotent: if one is already up for this project it reuses it (same URL); otherwise it creates `reports/` (adds it to `.gitignore`), picks a free port starting at `8912`, launches `python3 -m http.server` in the background bound to `127.0.0.1`, and records port + PID in `reports/.server.json`. It prints the base URL. Tell the user the URL and that `reports/index.html` lists everything in the folder.

- **status**:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/serve-reports.sh status
  ```
  Reports `running · <url> · port · pid`, or `stopped`. Relay it verbatim.

- **stop**:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/serve-reports.sh stop
  ```
  Kills the registered PID only (never a blind `kill $(lsof …)`, which could take clients down with it) and clears the registry.

## Notes

- **One server per project** — each project gets its own port and its own `reports/.server.json`.
- **Anything you want served just goes in `reports/`.** When you write an update/report page for the user, write a **self-contained** HTML file (no external CDN/network, like an Artifact) into `<project>/reports/`, then refresh the index:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/serve-reports.sh reindex
  ```
  (The Stop hook also re-indexes at the end of every turn, so new files show up on their own.)
- **Lifecycle**: `/startsession` restarts a previously-registered server if it's down; `/savesession` **asks** before stopping it — it is never stopped silently.
- **Port override**: set `KEEL_REPORTS_PORT` to change the starting port (default `8912`).
