# Keel — Command reference

All commands are namespaced **`/keel:<name>`** so they coexist with any other setup. Below, each command lists **what it does**, **when** to use it, its **usage**, and an **example**.

> New here? Start with the [README](README.md) and the [TUTORIAL](TUTORIAL.md).

---

## Session lifecycle

### `/keel:startsession`
**What** — Loads the project's context at the start of a session: creates a session marker, resolves the global memory, verifies the `design-log/` structure (and **scaffolds it** on a brand-new project), reads `FOCUS` first, surfaces untriaged `INBOX` items, reads the tracking, and prints a summary with the behavioral rules, the key learnings, the current objective, and the suggested next step. If `PROJECT.md` is empty it enters **Project Discovery Mode** (interviews you, or analyzes the repo). If a `sprint.txt` exists in the root it **auto-starts** it.
**When** — ALWAYS, at the start of every session.
**Usage** — `/keel:startsession`
**Example** — Open a fresh folder → `/keel:startsession` → keel scaffolds `design-log/` in English, sees `PROJECT.md` is empty, and asks you what the project is.

### `/keel:savesession`
**What** — Closes cleanly. It sweeps the whole conversation so no request is lost, triages `INBOX` (blocking), syncs the tracking files, **prunes `FOCUS`** and **prunes `sprint.txt`** (removes done/superseded items), **asks itself** whether any report/artifact (e.g. `design-log/report.html`) went stale and updates it, extracts and classifies any new lessons (with your confirmation), writes a **session log**, and removes the session marker.
**When** — Before ending, before switching context, after a milestone, or when the conversation gets long.
**Usage** — `/keel:savesession`
**Example** — After finishing a feature → `/keel:savesession` → the item moves to `TO_TEST` (implemented, not yet validated by you), the sprint is pruned, a session log is written.

### `/keel:resumesession`
**What** — Loads a **specific past session** instead of the latest one (which `/startsession` loads).
**When** — When you want to pick up a particular older session.
**Usage** — `/keel:resumesession [session-file-name]`
**Example** — `/keel:resumesession 2026-08-01-20-56` → loads that session's summary + handoff notes.

---

## Doing the work

### `/keel:add-task`
**What** — Forces the Design-Log methodology for a **significant** task (≥3 files, a new feature, an architectural decision): creates a design log, writes Background/Problem, **asks questions** (Socratic method), **stops for your answers**, completes the Design + Implementation Plan, **stops for your approval**, then implements and updates the tracking. A trivial task (<3 files, obvious) skips the ceremony.
**When** — Whenever you're about to build/change something non-trivial.
**Usage** — `/keel:add-task "<task description>"`
**Example** — `/keel:add-task "add JWT authentication"` → design log + Q&A ("which library? token TTL? refresh flow?") → you approve → implement.

### `/keel:new-issue`
**What** — Creates a tracked issue in `design-log/issues/` (bug / enhancement / review), assigns an ID, and updates the index.
**When** — To log a bug/enhancement/review you don't want to fix right now.
**Usage** — `/keel:new-issue [type] [title]` (type = `bug` | `enhancement` | `review`)
**Example** — `/keel:new-issue bug Login fails on mobile`

### `/keel:sync-dlogs`
**What** — A **safety net**: re-reads the recent conversation and re-syncs the tracking files (DONE/FIXED/TODO/TO_FIX/TO_TEST + PROGRESS index) and the active design log if they drifted. `/savesession` already does this; use `/sync-dlogs` for a mid-session double-check.
**When** — After Claude did work but didn't update the files, or before `/savesession` as a check.
**Usage** — `/keel:sync-dlogs`

---

## Quality

### `/keel:bug-hunt`
**What** — An on-demand **light** bug hunt. You pick the **lenses** (`security · permissions · data · robustness · correctness · dead-code · efficiency · requirements`); it runs a **strong finder per lens** (Opus) over the target, dedups by `file:lines`, then a **cheap adversarial refuter/validator per finding** (Fable) kills the plausible-but-false. Output: a report **triaged by impact** (`A / B-public / B-technical / C`) written to `design-log/bug-hunt/`, then item-by-item triage into `TO_FIX` / `INBOX` / trash (nothing is written without your confirmation). Default target = the current diff expanded to whole files. "Light" = a few finders, bounded scope — not hundreds of agents.
**When** — On a diff or a hot path you want scrutinized. (A clean report does **not** prove the code is clean — it only finds what has a symptom now.)
**Usage** — `/keel:bug-hunt [lenses…]` (no args → it asks via a menu)
**Example** — `/keel:bug-hunt` → pick `security` + `data` → it hunts the current diff → reports 3 confirmed, groups them by impact, and you triage each.

---

## Views (read-only, self-contained)

### `/keel:dashboard`
**What** — Generates and opens **one self-contained HTML page** (no server, no network) with a **cross-project overview** (objective, counts, staleness, untriaged inbox) and per-project client-side drill-in. Rendered deterministically from your design-log files; auto-refreshed at the end of each turn.
**When** — For a quick glance across projects.
**Usage** — `/keel:dashboard [root-or-project …]` (no args → uses `KEEL_DASHBOARD_ROOTS`, then `$KEEL_GLOBAL_DIR/dashboard.roots`, then the current dir)
**Example** — `/keel:dashboard ~/Projects` → aggregates every project with a `design-log/` under that root.

### `/keel:report`
**What** — Writes and opens a **narrated per-project report** — a rich "your file" page (eyebrow · stat tiles · letter-index · one card per item with *what / why / how / status / who* and **You/I** markers · "done" at the bottom), composed by the model from the real tracking. On-demand (it is NOT auto-refreshed, unlike the dashboard).
**When** — When you want a readable, narrated status of one project (to review or share).
**Usage** — `/keel:report [project-path]` (no args → the current project)
**Example** — `/keel:report` → writes `design-log/report.html` and opens it.

---

## Parallel sessions (same repo)

### `/keel:startsharedsession`
**What** — When 2+ Claude sessions run on the same repo: declares the files this session will modify and creates **per-file locks**, flipping your marker from `exclusive` to `shared`. Refuses a file already locked by another session.
**When** — Before editing files while another Claude session is active on the same repo.
**Usage** — `/keel:startsharedsession`

### `/keel:stopsharedsession`
**What** — Releases your per-file locks and flips your marker back to `exclusive`. Run it **before** `/savesession`.
**When** — At the end of shared work.
**Usage** — `/keel:stopsharedsession`

---

## Cross-project coordination

### `/keel:startcoord`
**What** — Creates a cross-project **DAG plan** (`.plan/<id>.json`) across N sub-projects that use the design-log system. From then on, each sub's `/startsession` is plan-aware ("your turn" / "waiting on X" / "done"). Task completion is auto-detected from the artifact (`Status: Implemented` in the design log).
**When** — When a task spans multiple sub-projects.
**Usage** — `/keel:startcoord [<plan_id>] [--from <template.json>]`

### `/keel:stopcoord`
**What** — The symmetric bookend: reconciles task state from the artifacts, **syncs all the copies** of the plan across the subs in one shot, produces a closing report + handoff, and archives the plan if complete (or with `--cancel`).
**When** — When you've finished your part of a cross-project push, or to abandon a plan.
**Usage** — `/keel:stopcoord [<plan_id>] [--cancel "<reason>"] [--archive]`

### `/keel:merge-design-log`
**What** — Merges a branch into the target (default `main`) handling the shared design-log files correctly: pre-merge isolation → `git merge` → automatic sync-from-branch (PROGRESS/LEARNED/_INDEX) → source reset — so you avoid noisy conflicts and lost entries.
**When** — Merging a feature/release branch that touched design-log files.
**Usage** — `/keel:merge-design-log <source-branch> [--into <target>]` (resume after real conflicts: `--resume <source>`)
**Example** — `/keel:merge-design-log release-2.x`

---

## Capture (no command — just say it)

Say a **capture verb** followed by anything and it is written to `INBOX.md` immediately (before any work), so nothing is lost:
- English: `note · remember · jot · capture · remind`
- Italian: `segna · appunta · annota · ricorda · memorizza · nota`

Example: `note: the header overflows on mobile` → captured to `INBOX.md`, to be triaged later (at `/add-task`, on-demand, or at `/savesession`).
