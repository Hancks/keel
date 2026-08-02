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
