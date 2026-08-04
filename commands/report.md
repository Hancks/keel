---
description: "Write and open a narrated per-project report — a single self-contained HTML page in the 'your file' style (eyebrow, letter-index, entries with what/why/how/status/who, You/I markers, done at the bottom), composed by the model from the project's design-log. On-demand; not auto-refreshed."
argument-hint: "[project-path]"
---

Generate a **narrated report** for one project and open it. This is **model-written**, not a renderer: you read the project's design-log and compose the page yourself, in the approved "your file" look. On-demand — nothing regenerates it (unlike `/dashboard`).

## 1. Resolve the target project

- If `$ARGUMENTS` is given, treat it as the project path. Otherwise use the current directory.
- The project must have a `design-log/` folder. If it doesn't, tell the user to run `/startsession` first (keel scaffolds it) and **stop**.

## 2. Read the real state (never from memory)

Read these files where present — states come from the tracking **right now**, not from recollection:
- `design-log/PROJECT.md` — the `NORTH_STAR` block (for the eyebrow one-liner).
- `design-log/FOCUS.md` — current objective: `🔄 in progress` + `🧪 to validate`.
- `design-log/TODO.md` — backlog by priority (🔴/🟡/🟢).
- `design-log/TO_FIX.md` — open bugs.
- `design-log/TO_TEST.md` — implemented, awaiting the user's eyes.
- `design-log/DONE.md` and `design-log/FIXED.md` — recently validated (for the bottom section).
- Active design logs: `design-log/YYYY-MM-DD-*.md` whose `Status:` is **not** `Implemented` (work in progress).
- The most recent `design-log/sessions/*.md` — the Handoff Notes (immediate next steps, blockers, don't-forget).

## 3. Compose the report

- Read the template `${CLAUDE_PLUGIN_ROOT}/templates/report-template.html`. Keep its `<style>` block **verbatim** (approved light+dark "your file" look). Replace only the body content. Everything **self-contained** — no network, no external asset (it is served as a static file over loopback). All text in **English** (even if the source design-log is in another language).
- Fill it in for THIS project:
  - **Eyebrow**: `keel report · <project name> · <today's date> · your-file style`. Get today's date from `date '+%-d %B %Y'`.
  - **Headline (h1)** + **sub**: one narrated line on where the project stands now, and one on how to read it.
  - **Stat tiles**: counts read from the files (to-validate, to-do, open decisions, open bugs, recently done). Drop a tile that is 0 and not meaningful.
  - **Sections** (letter-indexed; skip a section that is empty, and drop its index entry too):
    - **A · In flight** — from `FOCUS.md` (`🔄` + `🧪`). Note that green ≠ done: it's not "done" until the user sees it run.
    - **B · To do** — from `TODO.md`, grouped by priority.
    - **C · Bugs** — from `TO_FIX.md` (chip `crit`). If none, say "none open".
    - **D · Decisions** — open questions / low-priority "to discuss" items.
    - **Z · Done** — from `DONE.md`/`FIXED.md`, recent, at the **bottom** (chip `ok`) so it isn't re-opened by mistake.
  - Each entry is a `.find` card: chip + `h3` title + `.lead` one-liner + `ul.fields` with **What / Why / How / Status / Who**. Use only the fields that add signal. Mark ownership: `<span class="tu">You</span>` (the user does it — e.g. validate on screen) and `<span class="io">I</span>` (the agent does it).
  - **Cap**: if a section is long, show the most relevant entries and end it with `<p class="note">+N more in <code>FILE.md</code></p>`. Never a bare count that hides the list.
  - Keep the footer's spirit: states re-read from tracking, not memory; implemented ≠ done until seen on screen.

## 4. Write, serve, and open

- Write the finished HTML to `<project>/reports/report.html` (overwrite any previous one). `reports/` is keel's local, gitignored hub for everything it writes for you — served locally, never published to claude.ai.
- Ensure the local report server is up and capture its base URL (created on first use, reused after; binds to `127.0.0.1` only):
  ```bash
  URL="$(${CLAUDE_PLUGIN_ROOT}/scripts/serve-reports.sh ensure)"
  ```
- Open the served page: `open "${URL}report.html"` on macOS, `xdg-open "${URL}report.html"` on Linux.
- Tell the user the **local URL** `http://127.0.0.1:<port>/report.html` (and that `reports/index.html` lists everything served). `/report` is **on-demand** — it is NOT auto-refreshed (that's the dashboard's job); re-run `/report` to refresh it.

> Complements `/dashboard`: the dashboard auto-renders a cross-project glance every turn; `/report` writes a rich, narrated, single-project page when you ask for it. Both are served locally from `reports/` (see `/serve-reports`).
