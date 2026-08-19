# Changelog

All notable changes to keel are documented here. Versions are simple `MAJOR.MINOR.PATCH`.

## 0.3.0 — Cooperative sessions & traceability

Two or more Claude sessions can now work the same repository at once without stepping on each other, and every session leaves an auditable trail. The old failure modes this closes: an "eternal close" when two sessions edited the same tracking files, and questions about sessions that had simply crashed.

### Added
- **Cooperative sessions, coordinated by name.** `/startsession <name>` opens a *named shared* session. Its method files (`FOCUS`, `TODO`, `TO_FIX`, `TO_TEST`, `INBOX`) are edited on a per-session working copy and merged back into the canonical files at `/savesession` through a **3-way merge** (`git merge-file`). Two sessions editing the same tracking file no longer block each other; a line touched by both is set aside in `design-log/.conflicts/` with the canonical left intact — never corrupted.
- **Liveness-based session markers + automatic reaping.** Markers now carry the process `pid` and a stable process `start_id`. Orphan markers left by a crashed or force-closed session are reaped automatically at `/startsession` — no prompts about stale sessions. A session that is genuinely alive (even parked at a checkpoint for hours) is never reaped; a recycled pid is told apart by `start_id` (same-host).
- **Execution-log gate (traceability).** `/savesession` refuses to close a session whose log lacks an `## Execution log` section, so every session records what was *requested*, what was *done*, and what was *left undone*.
- **Per-name sprint files.** A named session auto-starts from `sprint-<name>.txt`; the solo/exclusive session keeps `sprint.txt`.
- **Quasi-live handoff notes.** Cross-project handoff notes in `.plan/inbox/` now surface at the end of *every* turn (Stop hook), not only at `/startsession`.
- **Code-backlog surface.** `TODO` / `FIXME` / `KEEL:` markers in your code are collected into `design-log/.code-backlog.md` at the end of each turn (bounded scan; excludes vcs/vendor/build).
- **Orphan-temp janitor.** `recover-temps` merges the un-saved work of a crashed shared session back into the canonical files at the next `/startsession`, so nothing is lost.
- **New `lock.sh` subcommands** powering the above: `session-advise`, `reap`, `resolve-uid`, `sprint-file`, `shared-begin`, `shared-convert`, `merge-method`, `recover-temps`, `reg-check`, `backlog-scan`.

### Changed
- **`/startsession` now runs a session-mode decision tree** — `EXCLUSIVE`, `READ_ONLY`, `SHARED_NAMED`, `SHARED_ADOPT`, `SHARED_ASK`, `BLOCKED_BY_EXCLUSIVE` — reaping orphans first, then advising on the live sessions. Crashed sessions are handled silently rather than by asking you.
- **`/startsharedsession`** converts an exclusive marker into a named shared one in place; only the *code* files are locked, while the *method* files flow through the temp + merge path.
- **The R.17 hard-block** (no work outside `design-log/` without a current objective) now reads the objective from either the canonical `FOCUS.md` or the session's own working copy, so a shared session can carry its own in-flight objective. Enforcement is otherwise unchanged and fail-safe (the temp copy can only relax the gate, never create one).
- **Session markers are named per-session** and no longer assume a single exclusive session per repo.

### Fixed
- **Sprint gate ran against the wrong directory.** `sprint-check` / `sprint-mark` used `sprint.txt` relative to the current working directory instead of the project dir; they are now `$PROJECT_DIR`-relative (and per-name).
- **Lock-name collisions.** Path→lock-name encoding is now injective (percent-encoding): `src/a.md` and `src__a.md` no longer map to the same lock file.
- **`status` could under-report.** With a path containing a space it returned zero markers/locks; it now uses quoted `nullglob` arrays.
- **Orphan per-file locks.** `end` now releases a session's per-file `.lock`s *before* removing its marker, so a crash/close no longer leaves irrecoverable locks that block `share`/`add-file`.
- **Partial writes on interruption.** Markers, per-file locks, and `sprint.txt` are written atomically (tmp + rename); an interrupted turn never leaves a truncated or empty file.

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
