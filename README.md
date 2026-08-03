# Keel

> The problem was never the prompt.

**Keel** keeps a Claude Code agent on course at scale — it inherits memory across sessions and projects, holds the big picture, draws out the real intent behind each task, verifies instead of trusting, and stays traceable even when it runs on its own. Enforced by **hooks** (harness-level) and **skills** (model-level), not by better prompts.

Having the most powerful model no longer sets anyone apart — everyone has it. What sets you apart is the method you govern it with. Keel gives a Claude Code agent what no model carries on its own: the memory of what you decided and why, the direction you're headed, the design each change lives in, the judgment to stop and **ask instead of guess**, and the rule that *"it compiles" is never "it's done."* It keeps work broken into living records — in progress, to do, done, broken — so neither you nor the agent carries the whole weight at once, and the context never collapses. And when the agent runs on its own, for hours, cost, decisions and responsibility stay legible **even with the screen off**.

Not better prompts — a process that holds.

## What's here
- **Standalone method** — bundles the full command set (`/startsession`, `/add-task`, `/savesession`, `/merge-design-log`, `/startcoord`, …) and **scaffolds a new project's `design-log/`** on first run, so keel works on its own: no separate command-based install, no `~/.claude-method` to clone (the cross-project memory dir is created for you).
- **GUARDIAN** — re-injects the project's north-star, current objective, and cardinal principles so the agent never loses the thread (at session start, when a new task begins, after a context compaction).
- **Lossless capture** — every "note this" is written down the moment it's said.
- **Hard-blocks** — edits are denied when there's no active session or no declared objective; a turn can't end while a request is left uncaptured.
- **Local dashboard** — one self-contained page (no server, no network) with a cross-project overview and per-project drill-in — objective / left / done — rendered from your design-log files. Open it with `/dashboard`.
- **Narrated report** — a per-project report **on demand**, written by the model in a rich "your file" style (grouped by type; each item explained — what / why / how / status / who — with You/I markers, and "done" at the bottom). One self-contained page; open it with `/report`.

## Install

**Via the plugin marketplace** (recommended):
```
/plugin marketplace add Hancks/keel
/plugin install keel@keel-marketplace
```

**Or point Claude Code at a local checkout:**
```
git clone https://github.com/Hancks/keel
claude --plugin-dir /path/to/keel
```

## Quick start

Point Claude Code at keel and open a project:
```
cd your-project
claude --plugin-dir /path/to/keel     # or install via the marketplace (above)
```
Then run the loop:

1. **`/keel:startsession`** — at the start of every session. On a new project it scaffolds `design-log/`, reads your state, and shows where you left off. On an empty `PROJECT.md` it interviews you (or reads the repo) to fill it in.
2. **Work.** Say **"note: <anything>"** (or *segna*, *remember*, *jot* …) and it lands in `INBOX.md` immediately — nothing is lost. For anything non-trivial, run **`/keel:add-task "<what>"`**: it opens a design log, asks the questions it needs, waits for your OK, then implements.
3. **`/keel:savesession`** — before you stop. It syncs the tracking, prunes `FOCUS` and the sprint, writes a session log, and checks whether any report is stale.

See the whole thing end-to-end in **[TUTORIAL.md](TUTORIAL.md)**.

## Commands

All commands are namespaced `/keel:…` (so they coexist with any other setup). Full detail + examples in **[COMMANDS.md](COMMANDS.md)**.

| Command | What it does |
|---|---|
| `/keel:startsession` | Load the project context; scaffold a new project; auto-start `sprint.txt` if present |
| `/keel:savesession` | Close cleanly: sync tracking, prune FOCUS + sprint, session log, remove the session marker |
| `/keel:resumesession` | Load a specific past session (not the latest) |
| `/keel:add-task "<task>"` | Force the methodology for a significant task: design log → Q&A → approval → implement |
| `/keel:new-issue` | Create a tracked issue (bug / enhancement / review) |
| `/keel:bug-hunt` | On-demand light bug hunt: a finder per lens (Opus) + adversarial refuters (Fable), report triaged by impact |
| `/keel:dashboard` | Generate + open a self-contained cross-project dashboard (glance) |
| `/keel:report` | Write + open a narrated per-project report ("your file" style) |
| `/keel:sync-dlogs` | Safety net: re-sync the tracking files if they drifted |
| `/keel:startsharedsession` · `/keel:stopsharedsession` | Coordinate 2+ parallel Claude sessions on the same repo (per-file locks) |
| `/keel:startcoord` · `/keel:stopcoord` | A cross-project DAG plan visible from each sub's `/startsession` |
| `/keel:merge-design-log` | Merge a branch's design-log into the target without noisy conflicts / lost entries |

## Core concepts

- **`design-log/`** — the project's memory: plain Markdown, version-controlled. Split by type so no file grows past the reading limit: `FOCUS` (current objective) · `INBOX` (raw capture) · `TODO` / `TO_FIX` (backlog) · `TO_TEST` (implemented, awaiting your eyes) · `DONE` / `FIXED` (validated) · `PROGRESS` (light index) · `LEARNED` (project facts) · `sessions/` · `issues/` · dated design logs.
- **The work pipeline** — `INBOX → TODO/TO_FIX → FOCUS → TO_TEST → DONE/FIXED`. Every item has one home at a time.
- **Done = validated, not implemented** — a green build is *implemented*; it reaches `DONE` only after **you** see it work.
- **GUARDIAN** — the north-star + current objective + cardinal principles, re-injected by hooks so they never fade during a long session.
- **Two memories** — *local* (facts about this project, in `design-log/LEARNED.md`) and *global* (universal principles of how you work, in `~/.claude-method/LEARNED_GLOBAL/`, shared across projects). Writes to memory always need your confirmation.
- **Capture verbs (bilingual)** — `note · remember · jot · capture · remind` (and Italian `segna · appunta · annota · ricorda · memorizza · nota`).
- **Sprint auto-start (`sprint.txt`)** — an optional plain-text file at the project root: a short, free-form list of the jobs to pick up next. If it's there, `/keel:startsession` **auto-starts** — it treats the items as your request and gets to work, no confirmation. `/keel:savesession` **prunes** it (drops done/superseded items) so tomorrow never restarts from a stale plan. A hand-off note to your next session.

## Cross-project memory (zero-config)

Keel keeps a shared, cross-project memory of the **principles** you accumulate — how *you* work and build — kept separate from each project's own local notes. It lives in `~/.claude-method/` and is **created automatically** the first time keel runs: nothing to set up. Put it elsewhere by setting `KEEL_GLOBAL_DIR`. If the directory can't be created, keel degrades gracefully to per-project memory only. Writes to this memory always require your **explicit confirmation** — keel never records a lesson behind your back.

## Permissions

Keel's commands call a bundled helper (`scripts/lock.sh`) many times per session. A plugin **can't pre-approve its own Bash calls** — Claude Code never lets a plugin self-grant permissions — so the first call asks for approval.

Simplest: approve **"Yes, and don't ask again"** on that first prompt. Claude Code saves the rule to `.claude/settings.local.json` at your repo root, and later sessions in that repo run keel without prompting.

To set it up ahead of time, add an allow-rule to your `~/.claude/settings.json` (or project `.claude/settings.json`), matching where the plugin's script lives on your install:
```json
{ "permissions": { "allow": ["Bash(*/keel/scripts/lock.sh:*)"] } }
```
If prompts persist, copy the exact command shown in the prompt and allow that (install paths vary between marketplace and `--plugin-dir`).

## Structure
```
README.md · COMMANDS.md · TUTORIAL.md  # docs: overview · command reference · end-to-end walkthrough
.claude-plugin/plugin.json       # plugin manifest
.claude-plugin/marketplace.json  # marketplace manifest (for /plugin marketplace add)
hooks/hooks.json                 # SessionStart · UserPromptSubmit · PreToolUse · PostToolUse · PreCompact · Stop
scripts/lock.sh                  # hook logic + session/method engine (init·gates·scaffold) + global memory
scripts/dashboard.py             # cross-project dashboard generator
design-log/                      # bundled method docs (BEHAVIORS, METHODOLOGY) — self-contained
skills/                          # guardian, design-log method, adversarial review, systematic debugging
agents/                          # critic, verifier, tester, learned-distiller, bug hunters
commands/                        # full method: startsession · add-task · savesession · merge-design-log · startcoord · … + bug hunt · dashboard · report
workflows/                       # bug-hunt orchestration
templates/                       # narrated report page style (used by /report)
principi/                        # cardinal principles: universal · per project-type · per project
```

## License

MIT — see [LICENSE](LICENSE).

> ⚠️ Early / experimental — Phase 1. Starting spark: Yoav Abrahami's design-log idea (Wix Engineering); this goes well beyond it.
