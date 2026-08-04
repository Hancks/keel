# Changelog

All notable changes to keel are documented here. Versions are simple `MAJOR.MINOR.PATCH`.

## 0.2.0

### Added
- **Local reports server** — a per-project static server (`scripts/serve-reports.sh`) that serves a gitignored `reports/` folder over `127.0.0.1` **only** (never exposed off your machine). It's the local hub for all communication between you and the method: the narrated report, the dashboard, and any update page keel writes — reachable at a stable `http://127.0.0.1:<port>/` URL, with an auto-updating index.
- **`/serve-reports`** command — `start` · `status` · `stop` for the local server. Idempotent; **one server per project**, recorded in `reports/.server.json`; picks the first free port from `8912` (override with `KEEL_REPORTS_PORT`).

### Changed
- **`/report`** now writes to `reports/report.html`, ensures the local server, and returns a `http://127.0.0.1:<port>/report.html` URL — served locally by default instead of an ad-hoc `file://` path or an external service.
- **`/dashboard`** now also lands in `reports/dashboard.html` and is served locally, while keeping its per-turn auto-refresh and cross-project scope.
- **Session lifecycle** — `/startsession` restarts a previously-registered reports server if it was left down; `/savesession` **asks** before stopping it, never silently. The Stop hook keeps the served dashboard and the `reports/` index fresh at the end of every turn.

## 0.1.0

- Initial release — standalone method plugin: bundled command set, GUARDIAN, lossless capture, hard-blocks, cross-project memory, local dashboard, narrated report, bug hunt, adversarial review, methodical debugging.
