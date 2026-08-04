# Keel — Tutorial (end to end)

A concrete walkthrough: from install to a full day's loop, then a bug hunt and the two views. For the one-line-per-command reference, see [COMMANDS.md](COMMANDS.md).

Every command is namespaced **`/keel:…`**.

---

## 0. Install

**Marketplace (recommended):**
```
/plugin marketplace add Hancks/keel
/plugin install keel@keel-marketplace
```

**Or a local checkout:**
```
git clone https://github.com/Hancks/keel
cd your-project
claude --plugin-dir /path/to/keel
```

The **first time** keel runs a bundled helper (`scripts/lock.sh`), Claude Code asks for Bash permission — approve **"Yes, and don't ask again"** (a plugin can't pre-approve itself; see the README "Permissions").

---

## 1. Start a session

```
/keel:startsession
```

On a **brand-new project** (no `design-log/` yet) keel:
- scaffolds `design-log/` (FOCUS, INBOX, TODO, TO_FIX, TO_TEST, DONE, FIXED, PROGRESS, LEARNED, `sessions/`, `issues/` …),
- creates the global memory dir (`~/.claude-method/`, or wherever `KEEL_GLOBAL_DIR` points),
- sees `PROJECT.md` is empty and enters **Project Discovery Mode** — it either interviews you ("what does this project do? who is it for? stack? constraints?") or, if there's already code, analyzes the repo and asks you to confirm what it deduced.

On an **existing keel project** it instead reads `FOCUS` first, surfaces any untriaged `INBOX` items, reads the tracking, and prints a summary ending with the **current objective** and a **suggested next step**.

> If the project root has a `sprint.txt`, `/keel:startsession` **auto-starts** it — it treats the sprint items as your request and gets to work.

---

## 2. Capture as you think — nothing is lost

While working, just say a **capture verb** and it's written to `INBOX.md` immediately, before any work:

```
note: the login button overflows on mobile
```
(also works: `segna …`, `remember …`, `jot …`, `capture …`, `remind …`)

It goes to `INBOX.md` as a raw item to triage later — not something to do right now. You'll triage it at `/add-task`, on-demand, or at `/savesession`.

---

## 3. Do a real task

For anything non-trivial (≥3 files, a new feature, a decision), run:

```
/keel:add-task "add JWT authentication"
```

Keel forces the methodology:
1. **Design log** created (`design-log/YYYY-MM-DD-jwt-auth.md`), with Background + Problem.
2. **Questions** (Socratic): *"Which library? Token TTL? Refresh-token flow? Where are secrets stored?"* — and it **stops for your answers**.
3. After your answers → it writes the **Design** + a checkable **Implementation Plan**, and **stops for your approval**.
4. On your "yes" → it brings the task into `FOCUS.md` as `🔄 in progress`, implements, and updates the tracking.

A **trivial** change (say, fixing a typo in one file) skips all this — keel recognizes it and just does it.

> **Done = validated, not implemented.** When the code is written and the build is green, the item is **implemented**, not "done": it goes to `TO_TEST.md` and stays `🧪` in FOCUS until **you** have seen it work. Only then does it move to `DONE.md`.

---

## 4. Hunt for bugs (optional)

```
/keel:bug-hunt
```
Pick the lenses from the menu (e.g. `security`, `data`, `correctness`). Keel runs one strong finder per lens over the current diff, dedups, and an adversarial refuter checks each finding. You get a report grouped by impact and triage each confirmed item into `TO_FIX` / `INBOX` / trash.

> "Light" on purpose: a few finders, bounded scope. A clean report means "nothing with a symptom right now", not "the code is perfect".

---

## 5. Close the session

```
/keel:savesession
```
Keel:
- **sweeps** the whole conversation so no request you made is left only in the chat,
- **triages `INBOX`** (blocking — it won't close with untriaged items),
- **syncs** the tracking (DONE/FIXED/TODO/TO_FIX/TO_TEST + PROGRESS),
- **prunes `FOCUS`** and **prunes `sprint.txt`** (removes done/superseded items so the next session doesn't restart from a stale plan),
- **asks itself** whether any report/artifact (e.g. `reports/report.html`, `reports/dashboard.html`) went stale and updates it, and **asks before stopping** the local reports server,
- extracts any **lessons** learned, classifies them (local fact vs global principle) and — **with your confirmation** — writes them to memory,
- writes a **session log** and removes the session marker.

---

## 6. Next day — resume

```
/keel:startsession
```
It loads the most recent session by name, shows the handoff notes and the current objective, and you continue. To load a **specific older** session instead: `/keel:resumesession 2026-08-01-20-56`.

---

## Resume from a sprint (`sprint.txt`)

Some days you already know where tomorrow starts. Drop a **`sprint.txt`** at the project root — a short, free-form list of the jobs to pick up next, one per line:

```
1. Finish the checkout flow (payment step + confirmation email).
2. Document the new config file in the README.
3. Field-test the import command on a real dataset.
```

Next time you run `/keel:startsession`, keel reads it and **auto-starts** — it treats the items as your request and gets to work, without a "shall I proceed?". At the other end, `/keel:savesession` **prunes** it: done and superseded items are removed and partial ones updated, so the next session never restarts from a stale plan.

Write it yourself at the end of a session (or ask keel to write it), as a hand-off to your next self. It's optional — with no `sprint.txt`, `/keel:startsession` simply shows where you left off and suggests a next step.

---

## 7. See where things stand

**Cross-project glance:**
```
/keel:dashboard ~/Projects
```
One self-contained HTML page: a grid of every project under that root (objective, counts, staleness), with client-side drill-in. Served locally from `reports/` (see below) and auto-refreshed at the end of every turn.

**A narrated report of one project:**
```
/keel:report
```
Writes `reports/report.html`, serves it locally, and opens `http://127.0.0.1:<port>/report.html` — a rich "your file" page: what / why / how / status / who for each item, You/I markers, "done" at the bottom.

**Everything served locally, under your control.** Both views — and any update page keel writes — land in a per-project, gitignored **`reports/`** folder, served by a small static server bound to **`127.0.0.1`** only (never exposed off your machine). You get a stable `http://127.0.0.1:<port>/` URL with an auto-updating index instead of an external service or clumsy `file://` links:
```
/keel:serve-reports start    # start (or reuse) the server, print the URL
/keel:serve-reports status   # port / pid / url
/keel:serve-reports stop     # clean stop
```
`/report` and `/dashboard` start it automatically, so you rarely need this. **One server per project.** `/keel:startsession` restarts it if it was left registered; `/keel:savesession` **asks** before stopping it — never silently. Drop any self-contained `.html` into `reports/` and it appears in the index on its own.

---

## Working with others (optional)

- **Two Claude sessions on the same repo?** In the second one, run `/keel:startsharedsession` before editing (it locks the files you'll touch), and `/keel:stopsharedsession` before `/savesession`.
- **A task that spans several projects?** `/keel:startcoord` builds a cross-project plan visible from each sub's `/startsession`; `/keel:stopcoord` reconciles and closes it.
- **Merging a branch that touched design-log files?** `/keel:merge-design-log <branch>` avoids the noisy conflicts.

---

## Things to remember

- Commands are **`/keel:…`** — they coexist with anything else you have.
- Say **"note: …"** (or *segna*, *remember*, …) to capture — it's bilingual.
- **`/keel:startsession`** at the start, **`/keel:savesession`** at the end. That's the spine.
- **Green ≠ done.** It's done when you've seen it work.
- The whole memory is plain Markdown under `design-log/` — commit it with your code.
- Reports and the dashboard are served locally from **`reports/`** on `127.0.0.1` — your machine only, gitignored, never published.
