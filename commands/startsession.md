# Start Session Command

Loads the project context at the start of every session.

## THIS COMMAND IS MANDATORY

The user MUST invoke `/startsession` at the start of every session.
If they don't, Claude MUST ask for it before doing anything else.

---

## MANDATORY STEPS

### STEP 0: Preflight `jq`

All marker operations go through the script `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`. The script uses `jq` as its primary tool with an internal `python3` fallback (silent, no extra prompts). The preflight only checks the state of `jq`. *(Permissions note: a plugin cannot auto-approve its own Bash. To avoid a prompt on every `lock.sh` invocation, the user adds an allow-rule in their own settings — see README "Permissions" — or approves "don't ask again" at the first prompt.)*

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh preflight
```

OUTPUT:
```
🔧 Preflight: jq:OK
```
Or, if it is missing:
```
🔧 Preflight: jq:MISSING
⚠️  jq not in PATH. Recommended: brew install jq
   Continuing with the internal python3 fallback.
```

---

### STEP 0.4: Global memory — resolve + auto-bootstrap (standalone, does NOT block)

keel is **standalone**: the cross-project global memory (`LEARNED_GLOBAL.md` index + the `LEARNED_GLOBAL/` folder) lives in a dir **resolved by `lock.sh`** — default `~/.claude-method`, overridable with the env `KEEL_GLOBAL_DIR`. Unlike the old command-based method, here the dir is **NOT a blocking prerequisite**: if it is missing it gets **auto-created** (index + 6 domains); if it cannot be created (read-only FS / permissions), keel **degrades to local-only** and proceeds.

The bootstrap already runs silently at startup (hook `SessionStart` → `global-bootstrap`). Here it is run **explicitly and idempotently**, and the dir to use for the rest of the session (LEARNED_GLOBAL reads/writes) is resolved:

```bash
GLOBAL_DIR="$(${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh global-dir)"
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh global-bootstrap
test -f "$GLOBAL_DIR/LEARNED_GLOBAL.md" && echo "global:OK ($GLOBAL_DIR)" || echo "global:LOCAL-ONLY"
```

**If OK:**
```
🌍 Preflight global: $GLOBAL_DIR OK (idempotent auto-bootstrap · override: KEEL_GLOBAL_DIR)
```

**If LOCAL-ONLY (an expected degrade, NOT an error):**
```
🌍 Preflight global: global dir not creatable ($GLOBAL_DIR) → keel proceeds LOCAL-ONLY
   (cross-project memory disabled for this session; the rest of the method works)
```

**Proceed in BOTH cases.** In the rest of the command, wherever `~/.claude-method/LEARNED_GLOBAL/…` appears, read it as **`$GLOBAL_DIR/LEARNED_GLOBAL/…`** (the dir resolved above). Local-only = degrade, not a stop.

---

### STEP 0.5: Session sentinel (cooperative lock)

Check and create the marker that identifies this session. It lets you know — even from other Claude sessions active on the same repo — what is happening. It must run **BEFORE** any other read/write operation on the project.

#### 0.5a: Census existing markers

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status
```

Returns JSON `{markers: [...], file_locks: [...]}`. Schema of each marker:
```json
{
  "uid": "...",
  "type": "exclusive" | "shared",
  "startedAt": "ISO 8601 UTC",
  "host": "...",
  "lockedFiles": []
}
```

`.locks/` lives in the **repo root** (NOT in `design-log/`) and is in `.gitignore`. The script creates it automatically if missing.

#### 0.5b: Decide the mode based on the markers found

**Case A — No marker present:**
Create your own `exclusive` marker:
```bash
# SESSION_UID, not UID: in zsh UID is read-only → `UID=$(...)` crashes (bad math expr) and captures nothing
SESSION_UID=$(${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh init); echo "$SESSION_UID"
```

OUTPUT:
```
🟢 No active session — creating an EXCLUSIVE marker
✅ .locks/session-{uid}.json
🆔 UID: {uid}
```

**Case B — Only `shared` markers exist:**
Compute the union of the `lockedFiles` of all shared markers + the per-file `.lock`s (from the `lock.sh status` JSON).

OUTPUT:
```
🔄 [N] SHARED session(s) active:
  • UID xxx (host yyy, started zzz) — files: a, b
  • UID www (host kkk, started qqq) — files: c
🔒 Locked files (union): a, b, c

I create my own EXCLUSIVE marker anyway (to enter shared mode you need
an explicit /startsharedsession).
⚠️ I will NOT modify any file present in the union of the locked ones.
```
Then create the marker as in Case A:
```bash
# SESSION_UID, not UID: in zsh UID is read-only → `UID=$(...)` crashes (bad math expr) and captures nothing
SESSION_UID=$(${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh init); echo "$SESSION_UID"
```

**Case C — At least one `exclusive` marker (besides any shared ones):**
⛔ Another exclusive session is already active. Do NOT create any marker.

OUTPUT:
```
⛔ EXCLUSIVE SESSION ALREADY ACTIVE — entering READ-ONLY MODE
Marker detected:
  • UID xxx (host yyy, started zzz, type: exclusive)

⚠️ For the rest of this session:
  • I do NOT create my own marker
  • I do NOT modify ANY file (no Edit/Write/Bash with effects)
  • I can only read, explain, answer

If you know the session is orphaned (Claude crashed), remove the
marker manually and restart /startsession:
  rm .locks/session-{uid}.json
```

#### 0.5c: Store your own UID in the conversation

Note and **restate in the final summary (STEP 4)** your own `uid`. It is needed for:
- `/savesession` to remove the right marker (`lock.sh end <uid>`)
- `/startsharedsession` / `/stopsharedsession` to modify your own `lockedFiles` (passed as `--uid <uid>`)

---

### STEP 1: Verify the COMPLETE structure

**Scaffold (standalone keel):** if `design-log/` **does not exist** (a new project never initialized with keel), run FIRST:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh scaffold
```
It creates the whole `design-log/` structure — the method files `BEHAVIORS.md`/`METHODOLOGY.md` as **symlinks to the plugin** (no `~/.claude-method`) + all the per-project templates (FOCUS/INBOX/TODO/TO_FIX/TO_TEST/DONE/FIXED/progress.old/PROGRESS/PROJECT/BEHAVIORS_LOCAL/PROJECT_UPDATES/LEARNED/issues). Idempotent. Then continue with the check below.

Verify that ALL of these directories and files exist.
If something is missing, CREATE it (for `PROJECT_UPDATES.md`, `BEHAVIORS_LOCAL.md`, `FOCUS.md`, `INBOX.md` create them from an empty template — see METHODOLOGY "Templates of the split files").

For `FOCUS.md`/`INBOX.md` the check is scripted (organic migration, idempotent):
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh method-check
```
- `verdict=METHOD_OK` → both present, proceed.
- `verdict=METHOD_MIGRATE` → **create the missing files** from the template (FOCUS = `## In flight` + `*(empty)*`; INBOX = `## To triage` + `*(empty)*`), then proceed. The presence of the files IS the migration marker.

**Checklist to verify:**
- `design-log/`
- `design-log/sessions/`
- `design-log/issues/`
- `design-log/PROJECT.md`
- `design-log/PROJECT_UPDATES.md` ← project-specific context/conventions/operational decisions (created empty if missing)
- `design-log/BEHAVIORS_LOCAL.md` ← project-specific behavioral rules (created empty if missing)
- `design-log/FOCUS.md` ← 🎯 current objective (created from template if missing — organic migration)
- `design-log/INBOX.md` ← 📥 raw capture (created from template if missing — organic migration)
- `design-log/PROGRESS.md` ← light index (counters + links to the split files)
- `design-log/TODO.md` / `TO_FIX.md` / `TO_TEST.md` ← current work (created from template if missing)
- `design-log/DONE.md` / `FIXED.md` ← recently completed (created from template if missing)
- `design-log/progress.old.md` ← historical archive (created empty if missing)
- `design-log/METHODOLOGY.md`
- `design-log/BEHAVIORS.md` ← CRITICAL: general behavioral rules
- `design-log/LEARNED.md` ← the project's local memory
- `design-log/issues/_INDEX.md`
- at least one `design-log/sessions/YYYY-MM-DD-HH-MM.md` file (the most recent session by name)

**MANDATORY OUTPUT:**
```
📁 Structure check:
✅ design-log/
✅ design-log/sessions/
✅ design-log/issues/
✅ PROJECT.md
✅ PROJECT_UPDATES.md
✅ BEHAVIORS_LOCAL.md
✅ FOCUS.md · INBOX.md (method-check: [METHOD_OK | METHOD_MIGRATE → created])
✅ PROGRESS.md (index)
✅ TODO.md · TO_FIX.md · TO_TEST.md · DONE.md · FIXED.md · progress.old.md (split tracking)
✅ METHODOLOGY.md
✅ BEHAVIORS.md
✅ LEARNED.md
✅ issues/_INDEX.md
✅ sessions/[most recent file by name]
```

If something is missing, show:
```
❌ [file/folder] → CREATED
```

---

### STEP 1.7: 🚦 GATE tracking migration/reading (FORCING — not skippable)

> This gate exists because the rule "read the TODO all the way through" as plain prose was being skipped (see `BEHAVIORS.md` Rule 1: *"you don't follow the methodology unless you are forced"*). Real incident 2026-06-02: a monolithic PROGRESS.md of 1022 lines, only the first 170 read, `## TODO` at the bottom (line 936) skipped. Here the condition is checked by **script** and the action is **BLOCKING**, not left to good will.

Run:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh progress-check
```

Interpret the `verdict` field:

- **`verdict=MIGRATED`** → tracking already split. Proceed: in STEP 3 you will read `TODO.md` · `TO_FIX.md` · `TO_TEST.md` **in full**.
- **`verdict=PROGRESS_MISSING`** → new project / no PROGRESS. Proceed (STEP 1 created the templates).
- **`verdict=MONOLITH_SMALL`** → `PROGRESS.md` is monolithic but small (≤ `threshold` lines). No need to migrate now, BUT in STEP 3 **read `PROGRESS.md` IN FULL** (Done and Todo are there; the Todo may be at the bottom). Suggest the migration to the user when convenient.
- **`verdict=MIGRATE_REQUIRED`** → ⛔ **STOP. Migration MANDATORY before continuing.** It is a large monolith (> `threshold` lines) that keeps the current work at the bottom: reading only the top skips the TODO. Do **NOT** proceed to STEP 2+ and do **NOT** produce the STEP 4 summary until you have migrated.

  Migration procedure (do it **YOURSELF**, with judgment — there is no reliable auto-slicer for heterogeneous formats):
  1. **Read `PROGRESS.md` IN FULL**, in blocks with offsets (a large file → a single Read gets truncated). You must see every section, including the `## TODO` at the bottom.
  2. Split into (preserve EVERY item — no losses; verify by counting the `### ` entries before/after):
     - `DONE.md` ← `### <date>` entries of **recently** completed work.
     - `progress.old.md` ← **older** completed entries (historical archive).
     - `FIXED.md` ← fixed bugs (`✅ RESOLVED …`).
     - `TO_FIX.md` ← still **open** bugs.
     - `TO_TEST.md` ← "to validate at runtime".
     - `TODO.md` ← all the **work to do** (the `## TODO` section, priority 🔴/🟡/🟢). **This is the priority file to read.**
     - `PROGRESS.md` ← rewrite it as a **light index**: counters + links to the split files + "Quick status" + Quick Links.
  3. **Re-run `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh progress-check`**: it must give `verdict=MIGRATED`. Only then proceed.

**MANDATORY OUTPUT:**
```
🚦 Tracking gate: verdict=[…] · PROGRESS.md [N] lines · split_populated=[yes|no]
[if MIGRATE_REQUIRED] → migration done: DONE([N]) · progress.old([N]) · FIXED([N]) · TO_FIX([N]) · TO_TEST([N]) · TODO([N]); re-check ⇒ MIGRATED ✅
[otherwise] → no migration needed
```

---

### STEP 1.8: 🎯 FOCUS-first + INBOX surface (BEHAVIORS R.15/R.17)

> `FOCUS.md` (the current objective) is read **FIRST** — the work starts from there, not from the backlog nor from the last chat message. `INBOX.md` may contain requests captured but not yet triaged in previous sessions: they must be **surfaced** right away.

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh focus-check
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh inbox-check
```

- **`focus-check`**:
  - `verdict=FOCUS_OK` → **read `FOCUS.md` IN FULL** now. It is the basis of the summary (STEP 4) and of the "next step".
  - `verdict=FOCUS_EMPTY` → FOCUS exists but is empty: no current objective set. In the summary, propose to populate it (from the first 🔴 of TODO).
  - `verdict=FOCUS_MISSING` → STEP 1 should have created it; create it now from the template, then proceed.
  - Also read `focus_lines`/`focus_bloat` (2026-07-14 rule "FOCUS is pruned"): if `focus_bloat=yes` (over `focus_bloat_threshold`, default 40 lines) → **flag it in the summary** "⚠️ FOCUS over threshold ([N] lines) → needs pruning: `/savesession` forces it (STEP 2b-bis)". At the start of a session FOCUS is NOT rewritten (it is read); pruning is the closing's job.
- **`inbox-check`**: if `inbox_untriaged > 0`, **read `INBOX.md`** and keep those items ready to flag in the summary (they must be triaged, not forgotten). If `inbox_residue > 0` (lines that are not open captures: checked items, "✅ done" annotations): they are **in-place triage residue** — the 2026-07-14 rule "triage MOVES" — flag them in the summary: they will need to be MOVED into the right file at the next triage (`/savesession` forces it).
- **MULTISESSION detection (BEHAVIORS R.9)**: while reading `FOCUS.md`, check whether it contains the marker `⚠️ MULTISESSION {date}` (written by `/savesession` when the round had **parallel** sessions writing the same FOCUS without seeing each other). **If it is there**: the last session **by name** is NOT enough and may hide the most important work/handoff (e.g. it is a demo closed 20 min after the session that matters) → **memorize the given dates** and in **STEP 3 read ALL the sessions of those dates**, not just the last one. The tags `⟨session … · {date}⟩` on the individual FOCUS items say which session each indication comes from.

**MANDATORY OUTPUT:**
```
🎯 FOCUS: [current objective — 🔄 in-progress item, or "empty"] (focus-check: [FOCUS_OK|FOCUS_EMPTY|FOCUS_MISSING→created] · [N] lines[ · ⚠️ over threshold → prune at /savesession])
📥 INBOX: [N] untriaged items [→ short list] (or: empty) [· ⚠️ [R] annotated residue to MOVE at the next triage]
🧵 MULTISESSION: [marker detected for {date} → in STEP 3 I read ALL the sessions of those dates | no marker, I read only the last by name]
```

---

### STEP 2: Read BEHAVIORS + BEHAVIORS_LOCAL + local LEARNED + LEARNED_GLOBAL + PROJECT_UPDATES

ALWAYS read these five files first (order matters):

1. `design-log/BEHAVIORS.md` — the method's general behavioral rules
2. `design-log/BEHAVIORS_LOCAL.md` — this project's specific behavioral rules
3. `design-log/LEARNED.md` — the project's local learning memory
4. **Cross-project global memory** in `~/.claude-method/LEARNED_GLOBAL/` (since 2026-06-05 it is a folder per domain, NOT a single file anymore):
   - ALWAYS: `~/.claude-method/LEARNED_GLOBAL.md` (index/manifest) + `LEARNED_GLOBAL/general.md` + `LEARNED_GLOBAL/preferences.md`
   - CONDITIONAL (based on the Tech Stack in PROJECT.md, read at STEP 2.5/3): load ONLY the relevant domain files — `software-apple.md` (Swift/iOS/macOS), `software-web.md` (web/backend/cloud), `software-general.md` (any code/git/bash/build), `design.md` (UX/visual), `research.md`/`writing.md` if they exist. The stack→domains map is in the index.
   - Since the stack is only known after PROJECT.md, read NOW the index + general + preferences; load the conditional domains **right after** reading PROJECT.md (STEP 2.5/3). A non-software project loads only index + general + preferences.
5. `design-log/PROJECT_UPDATES.md` — this project's specific context/conventions/operational decisions (may be empty, that is ok)

**MANDATORY OUTPUT:**
```
📖 Base files read:
✅ BEHAVIORS.md ([N] lines) ← GENERAL BEHAVIORAL RULES
✅ BEHAVIORS_LOCAL.md ([N] lines) ← LOCAL BEHAVIORAL RULES [or: EMPTY]
✅ LEARNED.md ([N] lines) ← LOCAL MEMORY
✅ LEARNED_GLOBAL.md (index) + general.md + preferences.md ← GLOBAL MEMORY (always)
✅ LEARNED_GLOBAL/<conditional domains>.md ← loaded for the stack: [list, e.g. software-apple] [or: only the always-loaded ones]
✅ PROJECT_UPDATES.md ([N] lines) ← LOCAL CONTEXT/CONVENTIONS/OPERATIONAL DECISIONS [or: EMPTY]
```

---

### STEP 2.5: 🔍 GATE - Read PROJECT.md and assess whether it is empty

Read `design-log/PROJECT.md` and ASSESS whether it contains real information about the project.

**PROJECT.md is considered EMPTY if:**
- It does not exist
- It exists but has 0 lines of content
- It exists but contains ONLY: a title (`# ...`), placeholders (`[...]`), an uncompiled template, comments, empty lines
- There are not at least 2 lines with real informative content describing the project

**MANDATORY OUTPUT:**
```
🔍 PROJECT.md assessment:
📄 State: [POPULATED | EMPTY]
```

**If POPULATED** → go to STEP 3 (normal flow)
**If EMPTY** → go to STEP P1 (Project Discovery Mode) ⚠️ THE NORMAL FLOW IS INTERRUPTED

---

## 🔍 PROJECT DISCOVERY MODE

> This block activates ONLY if PROJECT.md is empty.
> The normal /startsession flow is INTERRUPTED until it completes.

### STEP P1: Analyze the repository

Examine the project directory to understand whether code/content already exists.

**Criteria for "existing project":**
- There are source files (*.py, *.js, *.ts, *.swift, *.go, *.rs, *.java, *.c, *.cpp, etc.)
- There are project files (package.json, Cargo.toml, requirements.txt, Makefile, *.xcodeproj, etc.)
- There are assets, documents, significant configurations
- Any recognizable project structure BEYOND the design-log system files

**Criteria for "new project":**
- The directory contains ONLY the design-log system files (.claude/, design-log/, CLAUDE.md)
- No source file, no project structure

**MANDATORY OUTPUT:**
```
🔍 Repository analysis:
📂 Type: [EXISTING PROJECT | NEW PROJECT]
📄 Evidence: [short list of what was found or "only design-log files"]
```

**If EXISTING PROJECT** → go to STEP E1
**If NEW PROJECT** → go to STEP N1

---

### Branch A: EXISTING PROJECT

#### STEP E1: Deep analysis

Claude must reach an understanding sufficient to manage the project AUTONOMOUSLY.

**Analyze IN DEPTH:**

1. **Directory structure** - folder layout, module organization
2. **Technology stack** - languages, frameworks, dependencies (from the package manager, config files)
3. **Architecture** - patterns (MVC, MVVM, microservices, etc.), entry point, data flow
4. **Source code** - read the main files, understand the core logic, the data models, the APIs
5. **Configurations** - build system, CI/CD, env, database
6. **Tests** - test framework, coverage, how to run them
7. **Existing documentation** - README, comments, inline docs

**If the project is large (>50 source files):**
Use Agent to parallelize the analysis into sub-tasks:
- Agent 1: structure + dependencies + config
- Agent 2: architecture + core code + data models
- Agent 3: tests + docs + build system

**MANDATORY OUTPUT:**
```
🔬 Deep analysis completed:

📂 **Structure**: [layout description]
🛠️ **Stack**: [main languages, frameworks, dependencies]
🏗️ **Architecture**: [patterns, main modules, data flow]
📝 **Core code**: [main files and their role]
⚙️ **Config/Build**: [how it builds, runs, deploys]
🧪 **Tests**: [framework, how to run them]
📖 **Docs**: [documentation found]
```

---

#### STEP E2: Present the deductions

Show the user what you deduced and ask for confirmation.

**MANDATORY OUTPUT:**
```
🧠 Here is what I deduced about the project:

📂 **Project name**: [deduced or to confirm]
🎯 **Purpose**: [what the project does, what problem it solves]
👥 **Target**: [who it is for]
🛠️ **Technology stack**: [full list]
🏗️ **Architecture**: [description of pattern and organization]
📋 **Main features**:
   1. [feature 1]
   2. [feature 2]
   3. [feature N]

📊 **Current project state**:
   - [what seems completed]
   - [what seems in progress]
   - [what seems missing or to do]

❓ **Questions/doubts**:
   - [what is not clear from the analysis]
   - [where clarification is needed]
```

---

#### 🛑 STEP E3: STOP - Ask for confirmation

**MANDATORY OUTPUT:**
```
🛑 CHECKPOINT - CONFIRM DEDUCTIONS

Are the deductions above correct? Correct me where I am wrong.
In particular, confirm:
- The project's purpose
- The target
- The main features
- The current state

Any corrections or additions?
```

**Do NOT proceed until the user confirms or corrects.**

---

#### STEP E4: Populate the files

After confirmation, write:
- **PROJECT.md** - filled in with all the confirmed information
- **PROGRESS.md** - with DONE (deduced already-done work) and TODO (deduced to-do items), only if confirmed

**MANDATORY OUTPUT:**
```
📝 Files updated:
✅ PROJECT.md - filled in ([N] lines)
✅ PROGRESS.md - updated with [N] DONE and [N] TODO deduced
```

**→ Go to STEP 3 (resume the normal flow)**

---

### Branch B: NEW PROJECT

#### STEP N1: Guided questions

Claude asks adaptive questions to define the project. A minimal set, but Claude MUST add contextual questions based on the type of project that emerges.

**MANDATORY OUTPUT:**
```
🆕 New project! I need some information to get started.

❓ Questions:

1. **Purpose**: What should this project do? What problem does it solve?
2. **Target**: Who is it for? (end users, developers, internal team, etc.)
3. **Main features**: What are the core features you want?
4. **Technology**: Do you have preferences on language/framework? Technical constraints?
5. **Interface**: Is a user interface needed? What kind? (web, mobile, CLI, desktop, none)
6. **Constraints**: Deadline, external dependencies, integrations with other systems?
```

Claude MUST add extra questions if the context calls for it. Examples:
- If the user mentions "mobile app" → questions about the platform (iOS/Android/cross), design system
- If they mention "API" → questions about authentication, rate limiting, documentation
- If they mention "game" → questions about genre, platform, engine
- If it is not a software project → questions about the specific nature (research, documentation, design, etc.)

---

#### 🛑 STEP N2: STOP - Wait for answers

**MANDATORY OUTPUT:**
```
🛑 CHECKPOINT

Waiting for your answers. Answer however you like - even in free form,
you don't have to follow the numbering.
```

**Do NOT proceed until the user answers.**

---

#### STEP N3: Populate the files

After the answers, Claude:
1. Summarizes what it understood and asks for a quick confirmation
2. After confirmation, writes:
   - **PROJECT.md** - filled in with all the information
   - **PROGRESS.md** - with an initial TODO based on the described features

**MANDATORY OUTPUT:**
```
📝 Files created:
✅ PROJECT.md - filled in ([N] lines)
✅ PROGRESS.md - initial plan with [N] TODOs
```

**→ Go to STEP 3 (resume the normal flow)**

---

## NORMAL FLOW (continues after STEP 2.5 or after Discovery)

### STEP 3: Read the remaining files

Read the remaining files in the specified order:

1. `design-log/PROJECT.md` - (re-read it if just populated by the discovery)
2. **Progress state (split by type)**:
   - `design-log/PROGRESS.md` (index: counters + links)
   - `design-log/TODO.md`, `TO_FIX.md`, `TO_TEST.md` - current work — **READ THEM IN FULL** (priorities, open bugs, to test). `TODO.md` is the **priority file to read**.
   - `design-log/DONE.md`, `FIXED.md` - recently completed (do NOT read `progress.old.md`: it is an archive, on-demand only)
   - **NOTE (post-GATE STEP 1.7):** the monolith migration is already handled by the gate. Here only `verdict=MONOLITH_SMALL` may remain (a small monolith not migrated): in that case read `PROGRESS.md` **IN FULL** — Done and Todo are there, the Todo may be at the bottom. **NEVER** read only the top part of a monolithic PROGRESS.md nor deduce the state from the head of the file alone.
3. **Most recent session(s)** - Normally resolve the last one with `ls -1 design-log/sessions/[0-9]*.md | sort | tail -1` and read it. **BUT if STEP 1.8 detected the marker `⚠️ MULTISESSION {date}` in `FOCUS.md`** (parallel sessions in that round, writing the same FOCUS without seeing each other): **do NOT stop at the last by name** — read **ALL** the sessions of that/those date(s): `ls -1 design-log/sessions/{date}-*.md`. The last by name may be a minor parallel session (e.g. a demo) and hide the session with the most important work/handoff. Cross the `⟨session …⟩` tags in FOCUS with the `**Session UID**` at the top of each session log to see who wrote what.
4. `design-log/METHODOLOGY.md` - How to work
5. `design-log/issues/_INDEX.md` - Open issues

**MANDATORY OUTPUT:**
```
📖 Files read:
✅ PROJECT.md ([N] lines)
✅ Tracking - PROGRESS.md index ([N]) · TODO/TO_FIX/TO_TEST ([N]/[N]/[N]) · DONE/FIXED ([N]/[N])
   (or, if not migrated: ✅ monolithic PROGRESS.md ([N] lines) ← FALLBACK, split files empty)
✅ sessions/[file(s) read] ([N] lines) ← the last by name, or ALL the sessions of the date(s) if FOCUS flags ⚠️ MULTISESSION
✅ METHODOLOGY.md ([N] lines)
✅ issues/_INDEX.md ([N] lines)
```

---

### STEP 3.5: Plan awareness (`.plan/`)

Check for any active cross-project coordination plans in the current sub.

#### 3.5a: Create `.plan/` if it doesn't exist

```bash
mkdir -p .plan .plan/inbox
```
Best effort. If `.plan/` already existed (even empty), `mkdir -p` does nothing. `.plan/inbox/` is the folder for incoming cross-project handoff notes (see 3.5f).

#### 3.5b: List active plans

```bash
ls -1 .plan/*.json 2>/dev/null
```

Excludes `.plan/archived/`.

**MANDATORY OUTPUT:**
```
📋 Active plans:
✅ <N> plans found: <list of plan_id>
   or
⏭️ No active plan (zero overhead)
```

If no plan → skip to STEP 4.

#### 3.5c: For each plan, classify the current sub's tasks

For each `.plan/<plan_id>.json`:
1. Load the JSON.
2. Identify the tasks with `sub_path` = the current sub's absolute pwd. For the match, normalize the paths (resolve symlinks, no trailing slash).
3. For each task of the current sub:
   - **completed**: status = "completed" → show ✅
   - **in_progress**: status = "in_progress" → show 🔄 (suggest resuming via the design log artifact)
   - **pending**: check the dependencies. For each `dep_id` in `depends_on`:
     a. Find the task with that `id` in `tasks[]` (even if in another sub)
     b. Artifact path: `<dep.sub_path>/<dep.artifact>`
     c. Read the design log artifact (if it exists)
     d. Look for the header `Status: Implemented` (or `Status:** Implemented**`)
     e. If found → the dependency is satisfied
   - If ALL dependencies satisfied → 🟢 ready
   - If at least one not satisfied → ⏳ blocked (show which)
4. Opportunistically update the local copy of the plan with the verified statuses (idempotent write of `<sub_path>/.plan/<plan_id>.json` with updated `status` and `started_at`/`completed_at`). If the current sub's task has the artifact with `Status: Implemented`, mark it `completed` (with `completed_at`); if the artifact exists but is `Implementing`/`Draft`, mark it `in_progress` (with `started_at`).

#### 3.5d: Auto-archive

If for the plan ALL the tasks (of all subs, not just the current one) are `completed` (verified via artifact, even cross-sub):
1. Move `.plan/<plan_id>.json` to `.plan/archived/<plan_id>.json` in the current sub
2. Best-effort: also try the move in the other `sub_path`s reachable via the local filesystem
3. Output:
```
📦 Plan <plan_id> all tasks completed → archived in .plan/archived/
```

#### 3.5e: Plan summary output

For each active plan (not archived after 3.5d):
```
📊 Plan: <plan_id> — <title>
  Tasks in this sub:
  ✅ <id_a>: <title> — completed
  🔄 <id_b>: <title> — in_progress (artifact: <path>)
  🟢 <id_c>: <title> — ready (no deps pending)
  ⏳ <id_d>: <title> — blocked by: <id_x> (sub <sub_x>)
```

#### 3.5f: Handoff inbox (`.plan/inbox/`)

The **incoming** cross-project handoff notes live in `.plan/inbox/*.md` (2026-06-07 convention — a single predictable place next to the plans, NOT in `design-log/`). List them:
```bash
ls -1 .plan/inbox/*.md 2>/dev/null   # excludes .plan/inbox/archived/
```

**MANDATORY OUTPUT:**
```
📬 Handoff inbox: <N> notes → <list of file names>
   (or: ⏭️ Inbox empty)
```

If there are notes, **read them** (they are short and addressed to this sub) and take them into account in the summary (STEP 4) and in the suggested next step. A note already consumed should be moved to `.plan/inbox/archived/` (best-effort) so it isn't re-flagged to future sessions.

---

### STEP 3.6: 🌐 Local reports server (restart if registered but down)

> keel serves reports, the dashboard, and any update page locally from `<project>/reports/` — the hub for user↔method communication, on `127.0.0.1` (never exposed). If a previous session left a server registered but it's now down, restart it so reports are immediately reachable. If none is registered → zero overhead, skip.

Only if `reports/.server.json` exists:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/serve-reports.sh ensure
```
`ensure` is idempotent: if the server is already alive it reuses the same URL; if it was down it restarts it (first free port from `8912`). It prints the base URL and regenerates `reports/index.html`.

**MANDATORY OUTPUT:**
```
🌐 Reports server: [restarted → http://127.0.0.1:<port>/ (index: reports/index.html) | already running → <url> | none registered → skip]
```

---

### STEP 4: Generate the summary

Show the user that you UNDERSTOOD the context.

**MANDATORY OUTPUT:**
```
🧠 **GENERAL BEHAVIORAL RULES** (from BEHAVIORS.md):
- [critical rule 1]
- [critical rule 2]
- [critical rule 3]

📌 **LOCAL BEHAVIORAL RULES** (from BEHAVIORS_LOCAL.md):
- [local behavioral rule 1]
- [local behavioral rule 2]
- (if BEHAVIORS_LOCAL is empty: "⏭️ No project-specific local behavioral rule")

🗂️ **CONTEXT / CONVENTIONS / OPERATIONAL DECISIONS** (from PROJECT_UPDATES.md):
- [convention / operational decision 1]
- [convention / operational decision 2]
- (if PROJECT_UPDATES is empty: "⏭️ No specific local context")

💡 **KEY LEARNINGS** (from local LEARNED.md):
- [relevant learning 1]
- [relevant learning 2]

🌍 **RELEVANT GLOBAL LEARNINGS** (from the domain files loaded in `~/.claude-method/LEARNED_GLOBAL/`):
- [global learning 1, from the domains relevant to the stack]
- [global learning 2]
- (show at most 3-5 most relevant items from the domain files actually loaded for this project; also state which domains were loaded, e.g. "domains: general + preferences + software-apple")

🆔 **Session**: UID `{uid}` — type `{exclusive|shared|read-only}` — marker `.locks/session-{uid}.json`

📂 **Project**: [name and short description from PROJECT.md]
🛠️ **Stack**: [technologies from PROJECT.md]

🎯 **Current objective (FOCUS.md)**: [the `🔄 in progress` item + "done" criterion — or "none set, to populate"]
📥 **INBOX to triage**: [N items → short list | empty]

📊 **Current state**:
- Last session: [date from the most recent session]
- Last work: [what from the most recent session]
- Open issues: [number from _INDEX.md]
- Next priority: **[the `🔄 in progress` item of FOCUS.md; if FOCUS is empty, the first 🔴 item of TODO.md]** (post-GATE the tracking is migrated; if `MONOLITH_SMALL`, from the `## TODO` of `PROGRESS.md` read IN FULL). ⚠️ Work starts from FOCUS (R.17), not from the "Quick status" nor from the last chat message.

📝 **From the last session**:
- [key point 1 from the Handoff Notes]
- [key point 2 from the Handoff Notes]

📊 **Active cross-project plans** (from STEP 3.5, if any):
- <plan_id>: <N> tasks in this sub (<N_done> completed, <N_progress> in_progress, <N_ready> ready, <N_blocked> blocked)
- (if no plan: omit this line)

📬 **Handoff inbox** (from `.plan/inbox/`, if any):
- [note name]: [1-line summary + sender]
- (if inbox empty: omit this line)

🎯 **Suggested next step**: [specific action based on TODO, Handoff, Inbox and ready Plan tasks]
```

---

### 🛑 STEP 5: sprint.txt — if it EXISTS start AUTOMATICALLY; if it does NOT exist, wait for confirmation

###STEP 5A: SPRINT FILE EXISTS → AUTO-START (no confirmation asked):

If a `sprint.txt` file exists, **read it in full**.

**Before auto-starting, verify the sprint is not STALE** (script-based detection, since 2026-08-03 — before, the end-of-session prune was prose only and got skipped):
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh sprint-check
```
> ⚠️ **FRESH ≠ "items still open" (2026-08-05).** `sprint-check` tells you **only** whether the last session pruned the sprint (UID match); it does **not** verify the items are still open. The user can close items **out of session** (publish, file a submission, run a field-test) → no new session log → the UID still matches → **FRESH "forever" on stale content**. That's why the script now prints `reconcile=REQUIRED`: reconciliation is **mandatory in every case**.

- `verdict=SPRINT_FRESH` (or `SPRINT_NO_BASELINE` / `SPRINT_ABSENT`) → the last session pruned (or there's no baseline). **Still do NOT start blindly**: (a) **reconcile each item** against the real state (`DONE`/`FIXED`/`TO_TEST`/`TODO`/`FOCUS`) and **skip the already-closed ones**; (b) for **user-completable / external** items (publications, submissions, purchases, a field-test the user runs, third-party waits) a script **cannot** know whether you already closed them out of session → **list them and CONFIRM with the user** they're still open **before** executing. Auto-execute RIGHT AWAY **only** the **in-repo items verified still open**.
- `verdict=SPRINT_STALE` → ⚠️ **the last `/savesession` did NOT prune the sprint** (the marker UID doesn't match the most recent session log): it almost certainly contains **already-done/superseded** items. Same reconciliation as the FRESH case but with maximum suspicion — **re-read it critically**, **skip the already-closed ones**, **tell the user** the sprint was stale, and proceed only on the genuinely-open items (confirming the user-gated ones).

**OUTPUT (add to the STEP 5 line):** `🏃 Sprint-check: verdict=[…] · reconcile=REQUIRED → reconciling each item vs real state + confirming user-gated/external items before executing`

For the **in-repo items verified still open** by the reconciliation (above), **start executing RIGHT AWAY, WITHOUT asking for confirmation**: organize the execution plan and work as if they were a request entered by the user via the console (create/update the files, apply the methodology, proceed). Auto-start on THOSE is the **intended** behavior: the presence of `sprint.txt` IS already the authorization to start.

⚠️ Do **NOT** apply the general STEP 5B checkpoint here (which stops everything to wait for confirmation): with `sprint.txt` present you do NOT wait for confirmation **on the open in-repo items**. The **targeted confirmation of user-gated/external items** introduced above is a different thing — not the 5B checkpoint, it's the reconciliation that avoids "executing" an item the user already closed out of session (a script can't know that). (If a single item requires `/add-task` because the requirements aren't clear, apply that ceremony for THAT item — but don't stop the whole sprint.)

**MANDATORY OUTPUT:**
```
Proceeding with the sprint
```
Then **proceed immediately** with the first item (no waiting for confirmation).


If the sprint.txt file does not exist, then:

###STEP 5B: NO SPRINT FILE:
**MANDATORY OUTPUT:**
```
Shall I proceed with [suggested action] or do you prefer something else?
```

**Do NOT proceed until the user confirms.**

---

## Difference from /resumesession

| Command | Purpose | When to use it |
|---------|---------|----------------|
| `/startsession` | Always loads the most recent session by name + auto-discovery if PROJECT is empty | ALWAYS at the start |
| `/resumesession [file]` | Loads a specific session | When you want to resume a past session |

---

## Verification checklist for the user

After Claude runs `/startsession`, check:

- [ ] Did it run STEP 0 (preflight `jq`) and STEP 0.4 (resolved `$GLOBAL_DIR` via `lock.sh global-dir` + idempotent auto-bootstrap; degrade to local-only if not creatable, **without blocking**)?
- [ ] Did it run STEP 0.5 (sentinel) and show the state of the `.locks/` markers?
- [ ] Did it announce its OWN UID (or declare READ-ONLY MODE if it did not create one)?
- [ ] Did it show the structure checklist (including PROJECT_UPDATES.md and BEHAVIORS_LOCAL.md)?
- [ ] Did it run STEP 1.7 (gate `lock.sh progress-check`) and, if `MIGRATE_REQUIRED`, migrate PROGRESS.md into the split files (re-check `MIGRATED`) BEFORE proceeding?
- [ ] Did it run STEP 1.8 (`method-check`/`focus-check`/`inbox-check`), read `FOCUS.md` first and surface the untriaged `INBOX.md` items — also flagging `focus_bloat=yes` (FOCUS over threshold → prune at /savesession) and any `inbox_residue` (in-place annotations to MOVE)?
- [ ] Did it read TODO.md/TO_FIX.md/TO_TEST.md IN FULL and take the "Next priority" from FOCUS (then TODO), not from the Quick status?
- [ ] Did it read BEHAVIORS.md, BEHAVIORS_LOCAL.md, LEARNED.md, ~/.claude-method/LEARNED_GLOBAL.md and PROJECT_UPDATES.md?
- [ ] Did it assess whether PROJECT.md is empty or populated?
- [ ] (If empty) Did it analyze the repo or ask questions for a new project?
- [ ] (If empty) Did it stop to ask for confirmation of the deductions/answers?
- [ ] (If empty) Did it populate PROJECT.md and PROGRESS.md after confirmation?
- [ ] Did it show how many lines it read for each file?
- [ ] Did it show a summary with behavioral rules, local rules, local and global learnings?
- [ ] Did it stop to wait for the final confirmation?

If something is missing, Claude did not follow the command correctly.
