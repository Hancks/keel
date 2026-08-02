# 🧠 BEHAVIORS TO FOLLOW WITHOUT EXCEPTION - Read BEFORE doing anything

> Last updated: 2026-05-07

This file contains behavioral rules that FUTURE Claude must absolutely respect.

---

## CRITICAL RULES

### 1. You do NOT follow the methodology automatically
- You have empirically shown that you skip steps unless you are forced
- Don't fool yourself into thinking you "learned it" - every session you start from zero

### 2. When the user asks to implement something
- ❌ Do NOT start implementing directly
- ❌ Do NOT ask "Shall I proceed?"
- ✅ SUGGEST: "This task needs /add-task. May I run it?"

### 3. /add-task works because it FORCES you
- Without it, you will skip: the design log, the questions, the approval
- WITH it, you have the steps in front of you and follow them one by one
- It is the only way to guarantee that you follow the methodology

### 4. If the user says "proceed" or "do X"
1. STOP
2. Ask yourself: "Is it a significant task? Does it need /add-task?"
3. If YES → suggest /add-task
4. If NO (a trivial task < 3 files) → proceed

### 5. The fundamental principle
**"Don't trust yourself. Use the commands that force you."**


### Rule 6: Do EXACTLY what the user says, not variants
- **If the user says to do X, DO X. Not a variant. Not something similar. X.**

### Rule 7: Do NOT extend the scope — only what was asked
- **If the user lists X and Y, do ONLY X and Y. Not Z, even if it seems consistent.**

### Rule 8: - After writing the code, RE-READ the code
- **Verify POINT BY POINT that every user request is implemented**

### Rule 9. Parallel sessions — LOCK mandatory
- `/startsession` ALWAYS creates a marker `.locks/session-{uid}.json` (by default `exclusive`).
- If at startup you find an `exclusive` marker of another session → **READ-ONLY MODE**: you don't modify any file.
- If at startup you find only `shared` markers → you enter normally but do NOT touch the files present in the union of the `lockedFiles`.
- When there are 2+ Claude sessions on the same repo and you need to modify files: **ALWAYS** use `/startsharedsession` (changes your marker from `exclusive` to `shared` and creates the per-file `.lock`s).
- Do **NOT** modify a file with a `.lock` owned by another `owner_uid` — STOP and flag it.
- Before adding an unplanned file during the work: check the locks with `ls .locks/*.lock`.
- At the end of shared work: **ALWAYS** run `/stopsharedsession` BEFORE `/savesession`.
- `/savesession` removes its own marker `session-{uid}.json`.
- If you find an orphaned marker or lock (crashed session): flag it to the user, do NOT remove it yourself.

### Rule 10. Symlinks: Glob does NOT find them, use ls
- The `Glob` tool doesn't detect symlinks in general
- To verify the existence of a symlink: use `Bash` with `ls -la path/to/symlink`
- Do NOT try to recreate a symlink without first checking with `ls -la`
- Do NOT use `Glob` as proof that a file doesn't exist if it could be a symlink
- History: this rule was born for the `sessions/latest.md` symlink, removed in 2026-05-06 (see design log F3). The rule stays valid for any other future symlink.

### Rule 11. Extensions are discussed together, not applied unilaterally
- When new ideas or extensions emerge while working on a task, do NOT apply them on your own initiative. The user must control the scope and timing of the extensions, even if they seem consistent with the current task.

### Rule 12. Multi-branch design-log merge — use `/merge-design-log`
- When you need to merge a branch (e.g. `release-2.x`, `feature/login`) into the target (default `main`), do NOT use a direct `git merge`: the files `PROGRESS.md`, `LEARNED.md`, `issues/_INDEX.md` produce noisy conflicts and lost entries.
- ALWAYS use `/merge-design-log <source> [--into <target>]`: it handles the isolation, the merge, the automatic sync-from-branch and the source reset to keep the history clean.
- The command warns if `git push --force` is needed (when the source was pushed): coordinate with others if the branch is shared.
- In case of REAL conflicts on application files: the command stops → resolve manually → `git add` + `git commit` → re-run with `/merge-design-log --resume <source>`.
- For BEHAVIORS / PROJECT / METHODOLOGY modified on the branch: the command does NOT auto-merge, but flags with a WARNING. They must be merged by hand from the copy in `design-log/branches/<source>/`.

### Rule 13. Cross-project coordination — use `/startcoord`, no manual commands for `completed`
- When an initiative spans multiple sub-projects, do NOT plan in your head or with scattered notes: use `/startcoord` from an active session in the originator sub. It creates a DAG plan visible from every `/startsession` in the involved subs.
- Task completion is **auto-detected from the artifact**: no manual command (`/coord-done` does not exist). A task is `completed` if and only if its design log artifact has `Status: Implemented`.
- The copies of the JSON `.plan/<plan_id>.json` in the various subs are opportunistic caches. If you suspect divergences between copies, the artifact is the source of truth — delete the misaligned copy and re-run `/startsession` (opportunistic rebuild from the artifact).
- Constraint: all the `sub_path`s must be accessible via the local filesystem from the machine where you run `/startsession`.
- `.plan/` is committed (default). If you want a "private" gitignored plan, that is a project choice, not the default.

### Rule 14. /savesession does NOT write to BEHAVIORS or METHODOLOGY — it classifies and routes
- BEHAVIORS.md and METHODOLOGY.md contain ONLY the method's **general** rules/methodology. They are **overwritten on method updates**. No session should slip project-specific rules in there: they would be lost at the first update.
- When a new behavioral rule or technical lesson emerges in a session, `/savesession` **classifies** it and routes it to the right file:
  - **Project-local behavioral rule** (how Claude should behave in this project) → `design-log/BEHAVIORS_LOCAL.md`
  - **Project-local context/convention/operational decision** (workflow, naming, deploy, architectural tensions, changed scope) → `design-log/PROJECT_UPDATES.md`
  - **Global (cross-project) lesson — a universal PRINCIPLE**: ONLY if it is a **principle of *how you work / how you build*, always true by nature** (e.g. "if it doesn't work, don't guess: turn the logs up and trace the flow, expected vs actual"; "it compiles ≠ it works"; "verify, don't assume") → the right domain file in `~/.claude-method/LEARNED_GLOBAL/` (`general.md`, `preferences.md`, `software-general.md`, `software-apple.md`, `software-web.md`, `design.md`). The file is chosen by **kind of knowledge**, not by project of origin. See the index `~/.claude-method/LEARNED_GLOBAL.md` for the criterion and the map.
  - **Project-local technical lesson** → `design-log/LEARNED.md`. **EVERY specific fact/gotcha** of a tool/API/project goes there — **even if "technically general / reusable"** (e.g. "a plugin's `hooks/hooks.json` auto-loads", a single API's quirk): a specific *fact* stays local, and local memories are **recalled** cross-project when needed (no need to globalize them for reuse). **Blunt rule: GLOBAL = principle · LOCAL = specific fact. The "≥2 projects" count is FALLACIOUS and NOT used** (a thousand identical projects make nothing global).
- The auto-classification is **proposed by Claude** and **confirmed by the user**. Conservative default: local. Near-zero-reuse items (a one-off incident): not written.
- Manual edits of BEHAVIORS or METHODOLOGY are reserved for the evolution of the **method itself** (the meta-project), not for individual project sessions.
- History: rule introduced 2026-05-07 (`PROJECT_LOCAL.md` a single local file). 2026-05-11 split: rules → `BEHAVIORS_LOCAL.md`, context → `PROJECT_UPDATES.md`. **2026-06-05: `LEARNED_GLOBAL.md` (single file) → the `LEARNED_GLOBAL/` folder with a file per domain + conditional loading by stack** (design log `2026-06-05-learned-global-scalable.md`). **2026-07-30: classification criterion CORRECTED — from "high bar = useful to ≥2 projects" (fallacious, a recurring cause of over-globalization) to "GLOBAL = universal principle · LOCAL = specific fact"** (the user's correction; the project count has no value and local memories are recalled cross-project).

### Rule 15. Capture-instantly — write BEFORE acting
- Every user request, **even the smallest**, must be **written to a file BEFORE you start working**. Conversation memory is NOT reliable: something said and not written down right away is lost.
- When the user says to **capture something** (a "note"/"segna" verb, or throws out a raw/impulsive idea) → it goes to **`design-log/INBOX.md`**, NOT to `TODO.md`. `TODO.md` is the **curated official list**; `INBOX.md` is the raw capture to triage later.
- If it is already clear, prioritizable planning → directly to `TODO.md` (or `TO_FIX.md` if it is a bug).
- Forbidden to answer "ok I'll do it / I'll remember" without writing it first. The **capture** is real-time; the **triage** (INBOX→TODO/TO_FIX/🗑) can be batched (at `/add-task`, on-demand, and mandatory at `/savesession`).
- History: introduced 2026-06-24 (design log `2026-06-24-rafforzamento-metodo.md`). See METHODOLOGY "The lifecycle of work".

### Rule 16. Done = validated, not implemented
- A green `tsc`/build/test = **implemented**, NOT "done". An item enters `DONE.md`/`FIXED.md` **only after the user has seen it work** ("on-screen" validation).
- A feature implemented but not yet validated lives in **`TO_TEST.md`** (+ the state `🧪 to validate` in `FOCUS.md`), **never** in `DONE.md`.
- NEVER declare a task closed, nor write it in DONE/FIXED, on the evidence of compilation alone. This reinforces the principle "Don't trust yourself. Verify." and the lesson "NEVER declare green without reading the output".
- On validation: move it to DONE/FIXED **and remove the item** from TODO/TO_FIX/TO_TEST and from FOCUS (so TODO stays a living list, not a graveyard).

### Rule 17. One feature at a time + FOCUS-first
- **`FOCUS.md` is read FIRST** at every session (`/startsession` does it) and the work starts **from there**, not from the `TODO.md` backlog nor from the last chat message.
- In `FOCUS.md` there is **only ONE** `🔄 in progress` item at a time: it is brought to **validated** before opening another. The others stay `⏸️ queued` or `🧪 to validate`.
- `FOCUS.md` must stay **short** (the objective of right now): if it bloats like the TODO, it has stopped focusing.
- History: introduced 2026-06-24 (design log `2026-06-24-rafforzamento-metodo.md`).


## HOW TO USE THIS FILE

1. /startsession MUST read this file
2. /startsession MUST show these rules in the summary
3. **Do NOT add rules/lessons that emerged during a session here**: use the `/savesession` classification (Rule 14) → BEHAVIORS_LOCAL.md (local rules) / PROJECT_UPDATES.md (local context) / LEARNED.md (local lessons) / `LEARNED_GLOBAL/<domain>.md` (cross-project: a universal PRINCIPLE, not a specific fact).

---

## LEARNING HISTORY

### 2026-01-22 - Methodology debugging session
- **Discovered:** Claude doesn't automatically read the files at the start
- **Discovered:** Claude doesn't follow the methodology unless forced
- **Solution:** Created the mandatory /startsession and /add-task
- **Derived rule:** Always suggest /add-task for significant tasks
