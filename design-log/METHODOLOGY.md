# Design-Log Methodology - Complete Guide

> This file contains the detailed methodology. For the essential instructions, see `CLAUDE.md` in the root.

## Overview

This project uses the **Design-Log Methodology** (inspired by [Wix Engineering](https://www.wix.engineering/post/why-i-stop-prompting-and-start-logging-the-design-log-methodology)). Claude is not just a coder, but a **partner in the architectural process**.

## Core Principles

1. **Design Before You Implement**: A design log must be created and approved BEFORE writing code.

2. **Immutable History**: Once implementation begins, the "Design" section is FROZEN. Changes go to "Implementation Results".

3. **The Socratic Method**: For missing information, ASK QUESTIONS in the design log. Don't assume, ask.

4. **Traceable Implementation**: If you deviate from the plan, document WHY in "Implementation Results".

---

## Complete Folder Structure

```
./design-log/
├── PROJECT.md                          # Project overview (stable)
├── FOCUS.md                            # 🎯 Current objective — read FIRST every session
├── INBOX.md                            # 📥 Raw capture ("note"), to triage
├── PROGRESS.md                         # Light index → points to the files below
├── TODO.md                             # Things to do (features, improvements) — curated backlog
├── TO_FIX.md                           # Bugs to fix
├── TO_TEST.md                          # IMPLEMENTED but not validated (awaits the user's eyes)
├── DONE.md                             # VALIDATED work (recent)
├── FIXED.md                            # VALIDATED bugs (recent)
├── progress.old.md                     # Archive of old sessions
├── METHODOLOGY.md                      # This file
├── BEHAVIORS.md                        # Behavioral rules for Claude
├── LEARNED.md                          # Reusable technical knowledge
├── sessions/                           # Session logs
│   └── YYYY-MM-DD-HH-MM.md            # Sessions (the most recent by name is "latest")
├── issues/                             # Issue tracking
│   ├── _INDEX.md                       # Issue index
│   └── {TYPE}-{NNN}-{slug}.md         # Individual issues
└── YYYY-MM-DD-feature-name.md          # Design decisions (immutable after approval)
```

**Note on the progress structure (split by type):**
- `PROGRESS.md` is only a **light index**: header + counters (open TODOs, open bugs, last session) + links to the files below. It no longer contains bulky log entries.
- The work is split into separate files by type: `TODO.md` / `TO_FIX.md` / `TO_TEST.md` (current work) and `DONE.md` / `FIXED.md` (recently completed, with rich What/How/Files/Notes entries).
- `progress.old.md` is the **archive**: when `DONE.md` or `FIXED.md` exceed **~400 lines**, the oldest entries are moved here (keeping the working files under Claude's practical reading limit).
- **Always active**: `/savesession` and `/add-task` route the items directly into the split files (not into PROGRESS.md). See the "After Each Task" section.
- **Why the split** (original reason): to prevent a single progress file from growing beyond Claude's reading limit in a tool call (a monolithic PROGRESS >~500-1500 lines → gets truncated → `/startsession` loses pieces).
- **Backward compatibility (reading)**: `/startsession` reads the split files; if they are absent or empty it **falls back to `PROGRESS.md`** (not-yet-migrated projects keep working and migrate organically at the first `/savesession`).
- **FORCING migration GATE (STEP 1.7 of `/startsession`)**: the backward compatibility above is *prose* and was being skipped (Claude reads only the head of a monolithic PROGRESS → loses the `## TODO` at the bottom; incident 2026-06-02). To make it non-skippable, `/startsession` runs `.claude/scripts/lock.sh progress-check` which returns a machine-readable `verdict`: `MIGRATED` / `MONOLITH_SMALL` (read PROGRESS in full) / `MIGRATE_REQUIRED` (⛔ **blocking** migration to the split files before proceeding, with a `MIGRATED` re-check to confirm) / `PROGRESS_MISSING`. The detection is in the script (impossible to fake); the slicing into files is left to Claude (judgment is needed to classify the entries). Monolith threshold: `> 250` lines with `## DONE/TODO/TO_FIX` sections and ≥3 `### ` entries.

**Note on active design logs:** The `YYYY-MM-DD-feature-name.md` files with a Status other than "Implemented" are designs in progress and must be read during `/startsession` to keep context on the in-progress architectural decisions.

---

## The lifecycle of work (pipeline) — `INBOX → … → DONE`

> Introduced 2026-06-24 (design log `2026-06-24-rafforzamento-metodo.md` in the meta-project). Born from three real weaknesses: requests lost between turns, a bloated unreadable TODO, "implemented" mistaken for "done". Every work item has **one home at a time**; the movement between homes is the flow below.

```
   user request / "note X"
        │  ① CAPTURE  — instant, BEFORE acting               (BEHAVIORS R.15)
        ▼
   INBOX.md            raw, unordered
        │  ② TRIAGE  — at /add-task · on "go" for a task · on-demand · /savesession (blocking)
        ├──────────────► 🗑 trash (dropped with a why)
        ▼
   TODO.md / TO_FIX.md   full backlog, prioritized (🔴🟡🟢)
        │  ③ bring into the current work
        ▼
   FOCUS.md            objective NOW: few items, only ONE 🔄 in progress   (BEHAVIORS R.17)
        │  implement (green tsc/build = IMPLEMENTED, NOT "done")
        ▼
   TO_TEST.md          implemented, awaits the user's eyes
        │  ④ the user validates on screen ✅                  (BEHAVIORS R.16)
        ▼
   DONE.md / FIXED.md   VALIDATED = really done
        │  archiving at ~400 lines
        ▼
   progress.old.md
```

### Lifecycle table (what it holds · when an item ENTERS · when/where it EXITS)

| File | What it holds | When an item ENTERS | When/where it EXITS |
|------|---------------|---------------------|---------------------|
| `INBOX.md` | raw requests/ideas just captured | as soon as the user asks something or says **"note"** — *instant, before acting* | at **triage** → `TODO`/`TO_FIX` or 🗑 |
| `FOCUS.md` | current objective: few in-flight items, **1 `🔄` in progress** | when I bring a `TODO` item into the active work | when the feature is **validated** (the closing goes to `DONE`) |
| `TODO.md` | full prioritized backlog | from the triage of `INBOX` or direct planning | when it enters `FOCUS` (work) or is validated → `DONE`; **forced removal** at closing |
| `TO_FIX.md` | open bugs | triage / bug discovery | when fixed **and validated** → `FIXED` |
| `TO_TEST.md` | **implemented but NOT validated** (awaits the user) | when a feature/fix is implemented (green build) and needs the user's eyes | when the user validates → `DONE`/`FIXED`; the item exits |
| `DONE.md` | **VALIDATED** features | **only after** user validation | archiving at ~400 lines → `progress.old` |
| `FIXED.md` | **VALIDATED** bugs | **only after** user validation | archiving → `progress.old` |
| `progress.old.md` | historical archive | when `DONE`/`FIXED` > ~400 lines | never (archive) |

### The three rules that hold the pipeline together (see BEHAVIORS.md)

- **Capture-instantly (R.15)**: every request is **written before acting**. "note" → `INBOX.md`. Forbidden to say "I'll remember it".
- **Done = validated (R.16)**: a green `tsc`/build = *implemented*, not *done*. You enter `DONE`/`FIXED` **only** after the user has seen it work (moving from `TO_TEST`).
- **One feature at a time + FOCUS-first (R.17)**: `FOCUS.md` is read first; only one `🔄 in progress` item until validated.

### Testing = validating

`TO_TEST.md` is **no longer** "to test on device": it is the state *"implemented, the user hasn't seen it yet"*. When the user validates, the item exits and flows into `DONE`/`FIXED`. There is **no** separate "TESTED" file (it would be another file to empty).

---

## Template: PROJECT.md

```markdown
# [Project Name]

## Vision
What is this project? What problem does it solve? One paragraph max.

## Tech Stack
- Language: [e.g., TypeScript, Python]
- Framework: [e.g., Next.js, FastAPI]
- Database: [e.g., PostgreSQL, MongoDB]
- Other: [e.g., Redis, Docker]

## Architecture Overview
Brief description of how the system is organized.

## Key Directories
/src          - Main source code
/tests        - Test files
/docs         - Documentation

## Conventions
- Naming: [e.g., camelCase for functions, PascalCase for classes]
- Testing: [e.g., Jest, pytest]
- Git: [e.g., conventional commits]

## Getting Started
How to run the project locally (brief commands).
```

---

## Template: PROGRESS.md (light index)

`PROGRESS.md` no longer contains the log entries: it is only an index with counters and links to the split files.

```markdown
# Project Progress (index)

> Last updated: YYYY-MM-DD HH:MM
> Last session: [link to session file]

## Quick status
- 📋 Open TODOs: N → [TODO.md](./TODO.md)
- 🐛 Bugs to fix: N → [TO_FIX.md](./TO_FIX.md)
- 🧪 To validate: N → [TO_TEST.md](./TO_TEST.md)
- ✅ Recently completed → [DONE.md](./DONE.md) · 🔧 Fixed bugs → [FIXED.md](./FIXED.md)
- 🗄️ Historical archive → [progress.old.md](./progress.old.md)

## Open Questions
- [ ] Question 1

## Quick Links
- [PROJECT.md](./PROJECT.md) · [Sessions](./sessions/) (the most recent by name) · [Issues](./issues/_INDEX.md)
```

### Templates of the split files

`FOCUS.md` (current objective — read FIRST every session):
```markdown
# 🎯 FOCUS — Current objective

> Read FIRST every session. The few things in flight NOW. Only ONE 🔄 in progress at a time.
> States: 🔄 in progress · 🧪 implemented, to validate · ⏸️ queued. "Done" = validated by the user on screen.

## In flight
- 🔄 [feature] — done criterion: [how you see it works] — [TODO/design log link]
- ⏸️ [queued feature]
```

`INBOX.md` (raw capture — "note"):
```markdown
# 📥 INBOX — Raw capture (to triage)

> Anything the user says to capture, or asks on the fly, goes HERE right away, before acting.
> It is NOT the official list: it is triaged (→ TODO/TO_FIX or 🗑) at /add-task, on-demand, and at /savesession.

## To triage
- [ ] [raw request/idea] (captured: YYYY-MM-DD)
```

`TODO.md` (features/improvements):
```markdown
# TODO - To do

### 🔴 High Priority
#### [Task Name]
**What:** What needs to be done
**Why:** Why it's important
**How (proposed):** Initial thoughts
**Design log:** Link or "Needs design"

### 🟡 Medium Priority
### 🟢 Low Priority / Ideas
```

`TO_FIX.md` (open bugs):
```markdown
# TO_FIX - Bugs to fix

### 🔴 CRITICAL
### 🟡 MEDIUM
### 🟢 LOW
```

`TO_TEST.md` (implemented, to validate — the user hasn't seen it yet):
```markdown
# TO_TEST - Implemented, to validate
- [ ] [what the user must see working] (from: [task/session/feature in FOCUS])
```

`DONE.md` (recently completed) and `FIXED.md` (recently fixed bugs) — rich entries:
```markdown
# DONE - Completed work (recent)

### [Date] - [Feature/Task Name]
**What:** Brief description
**How:** Technical approach, key decisions
**Files:** List of files created/modified
**Design log:** [Link if exists]
**Notes:** Gotchas, learnings
```

`progress.old.md` (archive): same format as DONE/FIXED, receives the oldest entries when DONE.md/FIXED.md exceed ~400 lines.

---

## Template: Design Log

For new features or significant changes, create `YYYY-MM-DD-feature-name.md`:

```markdown
# [Feature/Decision Name]

> Created: YYYY-MM-DD
> Status: Draft | Approved | Implementing | Implemented
> Author: [Human/Claude]

## Background
Context and motivation. Why this is needed now.

## Problem
Clear statement of what needs to be solved.

## Questions and Answers

> Use Socratic method: Ask questions, don't guess!

**Q:** [Question]
**A:** [Answer - keep both permanently]

## Design

> This section is FROZEN once implementation begins.

### Overview
High-level approach.

### Detailed Design
- Include specific file paths
- Include type signatures
- Include validation rules

## Implementation Plan

- [ ] Step 1: [description]
- [ ] Step 2: [description]
- [ ] Step 3: [description]

## Trade-offs

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| A | ... | ... | Chosen/Rejected |
| B | ... | ... | Chosen/Rejected |

**Rationale:** [Why this approach]

## Implementation Results

> Add notes here DURING implementation. Never modify Design section.

### [Date] - Notes
- Deviated from plan because: [reason]
- Discovered issue: [description]
- Actual files created: [list]
```

---

## Template: Session Log

Save in `sessions/YYYY-MM-DD-HH-MM.md`:

```markdown
# Session Log: YYYY-MM-DD HH:MM

## Session Summary
One paragraph: goal and achievement.

---

## CRITICAL SECTIONS - What Compaction Loses

### Active Skills & Methodologies
1. **[Skill Name]**
   - Purpose: [what it does]
   - Key principles: [2-3 bullet points]
   - Current usage: [how we're applying it]

### Procedure State
**[Procedure Name]** (X/Y completed):
- [x] Step 1
- [x] Step 2
- [ ] Step 3 <- CURRENT STEP
- [ ] Step 4

### What We Tried That Didn't Work
- **[Attempt]**: [Why it failed] -> [What we did instead]

### User Preferences Discovered
- [Preference]: [Context/example]

---

## Context Snapshot

### Currently Working On
- Feature/task: [current task]
- File(s): [files being edited]
- Branch: [git branch]

### Key Decisions Made This Session
1. **[Decision]**: [WHY not just what]

### Problems Encountered & Resolutions
- **[Problem]**: [Resolution or status]

---

## Handoff Notes

### Immediate Next Steps
1. [Specific actionable step]

### Blockers / Waiting On
- [ ] [Blocker]

### Don't Forget
- [Critical detail]

---

## Files Modified This Session
- [path] - [description]
```

---

## Issue Tracking

### Issue Types
- `bug` - Something doesn't work
- `enhancement` - Improvement to an existing feature
- `review` - Something to verify

### Severity (bug) / Priority (others)
- Bug: critical -> major -> minor -> trivial
- Enhancement/Review: high -> medium -> low

### Status
- `in-progress` - Being worked on
- `blocked` - Blocked (specify why)
- `closed` - Completed (document the solution)
- `rejected` - Won't do (specify why)

### Issue Template

```markdown
# [{TYPE}-{NNN}] {Title}

> Type: bug | enhancement | review
> Severity/Priority: [level]
> Status: in-progress | blocked | closed | rejected
> Created: YYYY-MM-DD

## Description
[description]

## Context
Discovered during: [session/context]

## Steps to Reproduce (for bugs)
1. ...
2. ...

**Expected:**
**Actual:**

## Solution

### Approach
[how it was solved]

### Changes Made
[files modified]

### Related
[links to design logs, commits]
```

---

## Quality Checklists

### PROJECT.md
- [ ] Vision clear in one paragraph
- [ ] Tech stack complete
- [ ] Key directories explained
- [ ] Conventions documented

### PROGRESS.md (index) + split files
- [ ] "Last updated" current
- [ ] PROGRESS.md is a light index (counters + links), it does not contain bulky log entries
- [ ] `FOCUS.md` reflects the current objective (only ONE 🔄 in progress item) and is up to date
- [ ] `INBOX.md` triaged (no raw item forgotten)
- [ ] Only **validated** work in `DONE.md`/`FIXED.md` (the implemented-not-validated is in `TO_TEST.md`/`FOCUS.md`)
- [ ] Completed work in `DONE.md`/`FIXED.md` with How/Files
- [ ] TODOs in `TODO.md` have proposed approaches; bugs in `TO_FIX.md`; implemented-to-validate in `TO_TEST.md`
- [ ] `DONE.md`/`FIXED.md` under ~400 lines (over → archive in `progress.old.md`)
- [ ] Priorities clear · Reference to latest session

### Design Logs
- [ ] Background explains WHY
- [ ] Problem specific and clear
- [ ] Q&A has actual questions/answers
- [ ] Design includes file paths
- [ ] Implementation Plan has checkable items
- [ ] Status accurate

### Session Logs
- [ ] Summary captures goal/achievement
- [ ] Key decisions documented with reasoning
- [ ] Next steps specific and actionable
- [ ] Files modified listed

---

## Project Discovery Mode

When `/startsession` finds an empty PROJECT.md, the **Project Discovery Mode** activates and interrupts the normal flow.

### "Empty PROJECT.md" criterion
- Does not exist
- Exists but has only a title, placeholders, an uncompiled template
- No line with real informative content about the project

### Two scenarios

**Existing project** (there are source files, a package manager, a recognizable structure):
1. Deep analysis: structure, stack, architecture, core code, config, tests, docs
2. For large projects (>50 files): parallelize with Agent
3. Present the deductions (nature, purpose, target, stack, architecture, state)
4. Ask for confirmation/corrections
5. After confirmation: populate PROJECT.md and PROGRESS.md

**New project** (only design-log files in the directory):
1. Guided questions: purpose, target, features, tech, UI/UX, constraints
2. Additional contextual questions based on the answers
3. After answers and confirmation: populate PROJECT.md and PROGRESS.md

After discovery, the normal /startsession flow resumes.

Full details: see `.claude/commands/startsession.md`

---

## Session Lock System (`.locks/`)

> File-based cooperative locking to manage 2+ parallel Claude sessions on the same repo.

### Single entry point: `.claude/scripts/lock.sh`

All lock operations go through a committed bash script `.claude/scripts/lock.sh`. The script uses `jq` as its primary tool with an internal `python3` fallback (so it doesn't block if `jq` is missing). It is auto-approved in `.claude/settings.json` with the single permission `Bash(.claude/scripts/lock.sh:*)` — no prompt during `/startsession` and its siblings.

Subcommands:

| Subcommand | Effect |
|---|---|
| `preflight` | Prints `jq:OK` or `jq:MISSING` (with a warning). Run at the start of `/startsession`. |
| `status` | Prints JSON `{markers: [...], file_locks: [...]}` with the full current state. |
| `init` | Creates an `exclusive` marker. Prints the new UID on stdout. |
| `share --uid <uid> <file1> [<file2>...]` | Flip `exclusive→shared` + create per-file `.lock`s. Refuses if one of the files is already locked by others. |
| `add-file --uid <uid> <file>` | Append a file to the active shared marker + create a `.lock`. Idempotent if already self-owned. |
| `release --uid <uid>` | Removes your own per-file `.lock`s + flip `shared→exclusive`. |
| `end <uid>` | Removes `.locks/session-<uid>.json`. |

### Two lock levels

1. **Session marker** — `.locks/session-{uid}.json`
   Identifies an active Claude session. Created by `lock.sh init` (called by `/startsession`), removed by `lock.sh end <uid>` (called by `/savesession`).
   Schema:
   ```json
   {
     "uid": "uuid-v4",
     "type": "exclusive | shared",
     "startedAt": "ISO 8601 UTC",
     "host": "hostname",
     "lockedFiles": []
   }
   ```

2. **Per-file lock** — `.locks/<path-encoded>.lock`
   Declares intent to modify a specific file. Created by `lock.sh share` or `lock.sh add-file` (called by `/startsharedsession`), removed by `lock.sh release` (called by `/stopsharedsession`).
   Naming: `path/to/file.ext` → `path__to__file.ext.lock` (keeps the original extension).
   JSON schema: `{ owner_uid, file, task, createdAt }`.

### Possible states

| Markers present | `type` | `/startsession` behavior |
|---|---|---|
| None | — | Creates its own `exclusive` marker, proceeds normally |
| All `shared` | shared | Flags them + creates its own `exclusive` marker (READ + does not touch the files in the `lockedFiles` union) |
| At least one `exclusive` | exclusive | **READ-ONLY MODE** — does not create a marker, does not modify anything |

### Full lifecycle

```
/startsession          → lock.sh preflight + lock.sh status + lock.sh init  (exclusive)
/startsharedsession    → lock.sh share --uid <uid> <files...>               (flip to shared + per-file lock)
... work ...
/stopsharedsession     → lock.sh release --uid <uid>                        (removes locks + flip to exclusive)
/savesession           → lock.sh end <uid>                                  (removes marker)
```

### Location

`.locks/` lives in the **repo root**, NOT in `design-log/`. It is in `.gitignore`. The script creates it automatically if missing.

### Crash recovery

If a session crashes without calling `/savesession` or `/stopsharedsession`, markers and locks are left orphaned. Only the user removes them (Claude flags, it does not act):
```bash
rm .locks/session-{orphan-uid}.json
rm .locks/*.lock   # only if you're sure there are no active sessions
```

### Dependencies

- `jq` (recommended): `brew install jq` on macOS. Native at `/usr/bin/jq` on recent macOS.
- Internal `python3` fallback: used automatically if `jq` is missing. Same behavior, slightly slower.

Full details: see the four command files in `.claude/commands/` and the script in `.claude/scripts/lock.sh`.

---

## Multi-branch + Merge design-log

When working on separate branches (e.g. `release-2.x`, `feature/login`), the shared design-log files produce noisy merge conflicts if merged with a standard `git merge`. The `/merge-design-log` command orchestrates a flow that avoids this problem.

### File categories

| Category | Files | Strategy |
|----------|-------|----------|
| Sectioned (auto sync) | `PROGRESS.md`, `LEARNED.md`, `issues/_INDEX.md` | Pre-merge isolation → automatic sync-from-branch |
| Narrative (manual warning) | `BEHAVIORS.md`, `PROJECT.md`, `METHODOLOGY.md` | Pre-merge isolation IF modified → flag, manual merge |
| Naturally non-colliding | `sessions/*.md`, `YYYY-MM-DD-*.md` | No treatment (unique timestamps/slugs) |

### Flow of the `/merge-design-log <source> [--into <target>]` command

1. **Preflight**: clean working tree, existing branches, store the source's `pre-isolate-sha`
2. **Detect**: files to isolate (always + conditional via `git diff --name-only target...source -- design-log/`)
3. **Isolation** (on the source): move the files into `design-log/branches/<source>/`, commit "isolate"
4. **Merge** (on the target): `git merge <source>`. If there are real conflicts on application files → STOP + `--resume` instructions
5. **Sync-from-branch** (on the target):
   - PROGRESS.md: insert DONE entries by date, append missing TODOs by title
   - LEARNED.md: append new lines with a `<!-- merged from branch <source> on YYYY-MM-DD -->` marker
   - issues/_INDEX.md: full rebuild from `design-log/issues/*.md`
   - For BEHAVIORS/PROJECT/METHODOLOGY: WARNING + manual merge from the archive
   - Commit "sync design-log entries from branch <source>"
6. **Source reset** (with explicit confirmation): `git reset --hard <pre-isolate-sha>` → source returns ex-ante (clean history). WARNING: `git push --force` is needed if the branch was pushed.
7. **Return to the target**.

### Result

- **Source branch**: ex-ante, files at their original paths, no plumbing commit in the history. Stays alive for other bugfixes until the release.
- **Target branch**: explicit merge history (the "isolate" commit in the merge + the "sync" commit) + the `design-log/branches/<source>/` folder as a permanent archive.
- Collision: if `branches/<source>/` already exists → timestamp suffix `branches/<source>-YYYY-MM-DD-HH-MM/`.

### `--resume` mode

After real conflicts on application files at STEP 4: the user resolves them manually, does `git add` + `git commit`, and runs `/merge-design-log --resume <source>`. The command skips isolation/merge and restarts from the sync.

Full details: `.claude/commands/merge-design-log.md`.

---

## Cross-project coordination (`.plan/`)

When an initiative spans multiple distinct projects (subs) that use the design-log system, `/startcoord` lets you formalize the cross-project DAG plan and make it visible to every `/startsession` in the involved subs.

### Model

- The user runs `/startcoord` from an **active session in any sub** (the originator). No pre-dedicated parent orchestrator.
- Claude uses the current session's context to make smart proposals during the interactive Q&A.
- The command writes `.plan/<plan_id>.json` in all the involved `sub_path`s.
- All the copies are initially identical and post-creation are **peers**: none is "master".
- Post-creation work: the user is free (sequential by closing/opening sessions in the subs, parallel by opening multiple Claude sessions in different subs, mixed).

### The `.plan/` folder

Every sub that uses the system has a `.plan/` folder (analogous to `.locks/`):
- Empty → no active plan (zero overhead in `/startsession`)
- With `*.json` files → active plans (load and classify)
- With `archived/` → completed plans (ignored by `/startsession`)

`.plan/` is created best-effort by `/startsession`. The content is committed (default).

### Handoff inbox (`.plan/inbox/`) — 2026-06-07 convention

The **cross-project handoff** notes (one sub writing to another: "here is what you need to do", requirements, unblocks) live in **`.plan/inbox/`** of the **recipient** sub, NOT in `design-log/` (where they were hard to find). A single predictable place, next to the coord's `.plan/*.json`.

- **Where**: `<recipient-sub>/.plan/inbox/`.
- **Naming**: one `.md` file per note, `YYYY-MM-DD-from-<origin-sub>.md` (e.g. `2026-06-07-from-ocrscore.md`).
- **Who writes**: whoever sends a handoff (manually, or `/startcoord` / `/stopcoord` when they leave instructions for a sub) puts it in the recipient's inbox.
- **Who reads**: `/startsession` (STEP 3.5f) lists `.plan/inbox/*.md` and flags the notes in the summary. Consumed notes are moved to `.plan/inbox/archived/` so they are not re-flagged.
- **Git**: committed with `.plan/` (default).

### Plan schema

```json
{
  "plan_id": "monorepo-2026-q2",
  "title": "...",
  "created_at": "ISO 8601 UTC",
  "originator_host": "...",
  "originator_uid": "...",
  "originator_sub_path": "/abs/path/to/sub-where-it-was-created",
  "tasks": [
    {
      "id": "core-1",
      "sub_path": "/abs/path/to/core",
      "title": "...",
      "status": "pending|in_progress|completed",
      "artifact": "design-log/<file>.md",
      "depends_on": ["..."],
      "started_at": null,
      "completed_at": null
    }
  ]
}
```

### Auto-detection of completion

Task completion does NOT require manual commands. The `pending → in_progress → completed` transition is deduced by `/startsession` reading the design log artifact:
- Artifact doesn't exist → task pending
- Artifact exists with `Status: Draft` or `Implementing` → in_progress
- Artifact with `Status: Implemented` → completed

The copies of the JSON in the subs are opportunistic caches updated by the sessions that touch them. The source of truth is always the design log artifact.

### Dependency verification

When `/startsession` evaluates a pending task of the current sub, for each `dep_id` in `depends_on` it reads the artifact declared in the dependency's `sub_path` (cross-sub filesystem), and looks for `Status: Implemented`. If ALL dependencies are satisfied → task ready. Otherwise → task blocked (shows which deps are still pending).

### Auto-archive

When ALL the tasks of a plan are `completed` (all artifacts `Implemented`), `/startsession` moves `.plan/<plan_id>.json` to `.plan/archived/<plan_id>.json` (best-effort across all reachable subs).

### Constraints

- All the `sub_path`s must be accessible via the local filesystem from the sub that runs `/startsession`.
- Distributed setups (subs on different machines) are NOT supported in the minimal version.

Full details: `.claude/commands/startcoord.md`.

---

## Complete Workflow

### Receiving a Task

0. **CAPTURE FIRST (R.15)**: whatever the user asks — even the smallest thing — must be **written before acting**. If it is "note" or a raw idea → `INBOX.md`. If it is already clear planning → `TODO.md`. Never keep it only "in mind".

1. Is the task in `TODO.md` (or just triaged from `INBOX.md`)?
   - Yes: check whether a design log exists
   - No: add it to the appropriate priority

2. Do you need a design log?
   - Small change (< 3 files): proceed directly
   - Significant change: create a design log FIRST

   When you actually start working on it, **bring it into `FOCUS.md`** (`🔄 in progress`) — only one item in progress at a time (R.17).

3. For design logs:
   - Create a draft with Background, Problem, Questions
   - ASK questions (Socratic method)
   - Wait for the user's answers
   - Complete the Design
   - Get approval
   - THEN implement

### After Each Task

1. Tracking files (split by type — ALWAYS active). **Tell implemented apart from validated (R.16):**
   - **Implemented but not yet validated** (green build, the user hasn't seen it) → the item goes to `TO_TEST.md` and stays in `FOCUS.md` with the state `🧪 to validate`. **NOT** in DONE.
   - **Validated** (the user has seen it work) → ONLY now move it to `DONE.md` (a rich What/How/Files/Notes entry); if it was a bug → `FIXED.md`. **Remove the item** from `TODO.md`/`TO_FIX.md`/`TO_TEST.md` and from `FOCUS.md`.
   - **Archiving**: if `DONE.md` or `FIXED.md` exceeds ~400 lines, move the oldest entries to `progress.old.md`
   - Update `FOCUS.md` (the closed item exits; if it frees up, promote the next `⏸️` to `🔄`)
   - Update `PROGRESS.md` (index only: counters + links, no log entries)
   - Update the timestamp

2. Design log (if it exists):
   - Check off completed items in the Implementation Plan
   - Add notes in Implementation Results
   - Update the Status

3. Session log (if needed):
   - Long session (15+ exchanges)?
   - Important milestone completed?
   - About to switch context?

---

## Local/Global Pattern — Fundamental, local and global files

> Introduced 2026-05-07. See design log `2026-05-07-local-global-pattern.md`.

The system distinguishes six "types" of customization files, organized on three planes: **method fundamentals** (overwritten on updates), **project-local** (persist cross-update), **cross-project global** (live outside the repos).

### Responsibility table

| File | Life | What it holds | Updated by | Overwritten on updates? |
|------|------|---------------|------------|-------------------------|
| `BEHAVIORS.md` | In every project, symlink to the meta | ONLY the method's **general** behavioral rules | Only the meta-project via release | **YES** |
| `METHODOLOGY.md` | In every project, symlink to the meta | ONLY the method's **general** methodology | Only the meta-project via release | **YES** |
| `BEHAVIORS_LOCAL.md` | In every project | **Project-specific** behavioral rules (how Claude should behave here) | `/savesession` (classifies local) or the user | NO |
| `PROJECT_UPDATES.md` | In every project | **Project-specific context/conventions/operational decisions** (workflow, naming, deploy, architectural tensions, changed scope) | `/savesession` (classifies local) or the user | NO |
| `LEARNED.md` | In every project | **Project-specific** technical knowledge (incl. niche single-API gotchas used by a single project) | `/savesession` (classifies local) or the user | NO |
| `~/.claude-method/LEARNED_GLOBAL/` (folder) | Global repo outside the projects | **Universal PRINCIPLES** of how-you-work/build (NOT specific facts), **one file per domain**; `/startsession` loads only the domains relevant to the stack | `/savesession` (classifies global) or the user | NO (lives outside) |

### Fundamental rule: `/savesession` does not write to BEHAVIORS/METHODOLOGY

See BEHAVIORS Rule 14. When a new rule/lesson emerges in a session, `/savesession` classifies it and routes it to the right file:
- **Project-local behavioral rule** (about how Claude should behave) → `BEHAVIORS_LOCAL.md`
- **Project-local context/convention/operational decision** → `PROJECT_UPDATES.md`
- **Global lesson (a universal PRINCIPLE of how-you-work/build)** → the right domain file in `~/.claude-method/LEARNED_GLOBAL/` (see the PRINCIPLE-vs-FACT criterion below)
- **Project-local technical lesson** (every specific fact/gotcha of a tool/API/project) → `LEARNED.md`

The auto-classification is proposed by Claude and confirmed by the user. Conservative default: local. **PRINCIPLE vs FACT criterion**: only a universal *principle* of *how you work/build* goes global; every specific *fact* (tool/API/project) is local — even if "reusable" (local memories are recalled cross-project). The "≥2 projects" count is **fallacious** and not used.

### Classification examples

| Example rule/lesson | Where it goes | Why |
|---------------------|---------------|-----|
| "This is a sub-project of X, parent in `../../`, don't duplicate info" | `BEHAVIORS_LOCAL.md` / Behavioral Rules | Project-specific behavioral rule |
| "When talking about feature X, always check module Y" | `BEHAVIORS_LOCAL.md` / Behavioral Rules | Project-specific behavioral rule |
| "main = next version's branch; release/X.Y = parking" | `PROJECT_UPDATES.md` / Context/Conventions | Project operational convention |
| "Architectural tension meta-vs-centralized — Model 1 current, Model 3 escape hatch" | `PROJECT_UPDATES.md` / Context/Conventions | Operational decision / architectural context |
| "if it doesn't work, don't guess: turn the logs up and trace the flow, expected vs actual" | `LEARNED_GLOBAL/general.md` / Mistakes | **PRINCIPLE**, a universal debugging one, always true |
| "it compiles ≠ it works: trace the flows before saying done" | `LEARNED_GLOBAL/software-general.md` / Solutions | **PRINCIPLE** of how-you-build, tool-independent |
| "`git mv` doesn't work for pre-merge isolation" | project-local `LEARNED.md` | **FACT** about a tool (git): specific → local, even if "reusable" (recalled cross-project) |
| "`AVAudioUnitSampler` ignores onChannel" | that app's local `LEARNED.md` | **FACT** about a single API → local |
| "make operations idempotent to handle double delivery" (webhook) | `LEARNED_GLOBAL/software-web.md` / Solutions | **PRINCIPLE** of how-you-build a safe webhook (the detail of code `23505` stays in the project's local entry) |
| "Rotary knobs awkward for precise values → prefer sliders" | `LEARNED_GLOBAL/design.md` / Technical Patterns | **PRINCIPLE**, a UX one, holds regardless of the framework |
| "Don't commit settings.local.json" | `LEARNED_GLOBAL/preferences.md` | Preference across ALL projects |
| "The user prefers tabs to dropdowns in this project" | `PROJECT_UPDATES.md` / Context | UX of a specific project → local |

### Global repo `~/.claude-method/`

A dedicated repo **required** by the method:
- **Hardcoded** path: `~/.claude-method/`
- Every project's `/startsession` checks its existence at startup. If missing → **blocking error**, session interrupted until the setup is complete.
- Multi-workstation setup via `git clone` (see the README inside the repo)
- Contains: `LEARNED_GLOBAL.md` (index/manifest) + the `LEARNED_GLOBAL/` folder (a file per domain) + `README.md`

**`LEARNED_GLOBAL/` structure (a file per domain, since 2026-06-05):**
```
LEARNED_GLOBAL.md          ← index: explains the split, the criterion, what to load when (ALWAYS read)
LEARNED_GLOBAL/
├── general.md             ← ALWAYS loaded (cross-domain: method, workflow, agents)
├── preferences.md         ← ALWAYS loaded (cross-cutting user preferences)
├── software-general.md    ← conditional (git/bash/tooling/architecture/ML/ffmpeg)
├── software-apple.md      ← conditional (Swift/iOS/macOS/Catalyst/AVFoundation/Xcode)
├── software-web.md        ← conditional (web/backend/DB/auth/SaaS/cloud)
└── design.md              ← conditional (UX/visual/controls)
```
Each domain file contains `### Technical Patterns`, `### Mistakes Not to Repeat`, `### Reusable Solutions`.

**Loading by stack**: `/startsession` ALWAYS reads the index + `general` + `preferences`, and ONLY the conditional domains relevant to the stack declared in `PROJECT.md` (mapping in the index). Goal: a web project doesn't read the Apple rules and vice versa. `software-general` is NOT always-loaded — a project may not be software at all; it is loaded only if it contains code/scripting/build. The full stack→domains map lives in the index `LEARNED_GLOBAL.md`.

### What NOT to modify manually

- A project's `BEHAVIORS.md` and `METHODOLOGY.md`: they are symlinks to the meta-project, overwritten on updates. A manual edit does not survive the next update.
- To change the method: work on the meta-project (Claude Persistent Memory System) or on StartingKit, make a release, propagate.
- To change a single project's behaviors: use `BEHAVIORS_LOCAL.md` (rules) or `PROJECT_UPDATES.md` (context/conventions).

---

## LEARNED.md (local) vs LEARNED_GLOBAL/ — What to write and where

The distinction is **PRINCIPLE vs FACT**: a lesson goes to `~/.claude-method/LEARNED_GLOBAL/` **only if it is a universal PRINCIPLE** of *how you work / how you build* (always true by nature, independent of the tool/project). Every **specific fact/gotcha** (a single API/tool/library/project) stays **local** — even if "technically general / reusable": local memories are **recalled** cross-project when needed. The "≥2 projects" count is **fallacious** and abandoned (2026-07-30). Everything else stays local (or is not written).

### ✅ GOES in the project's local LEARNED
- Patterns specific to the project's codebase (e.g. "module X uses pattern Y for Z")
- **Every specific FACT/gotcha** of a tool/API/library/project — **even if "technically general / reusable"** (e.g. "`AVAudioUnitSampler` behaves like this"; "a plugin's `hooks/hooks.json` auto-loads"; "`git mv` breaks the pre-merge isolation"). A specific *fact* is local: it is **recalled** cross-project when needed, no need to globalize it.
- Test conventions and hardcoded project configs

### ✅ GOES in LEARNED_GLOBAL/<domain> (ONLY universal principles of how-you-work/build)
- **Method/debugging/verification principles** that are always true (e.g. "turn the logs up and trace the flow, expected vs actual"; "it compiles ≠ it works"; "verify, don't assume") → `general.md` / `software-general.md`
- **How-you-build principles** independent of the tool (e.g. "make operations idempotent to handle double delivery"; "design BEFORE code for complex protocols") → the relevant domain
- **UX/product principles** that are cross-framework (e.g. "knobs awkward for precise values → slider") → `design.md`
- Classified by **kind of knowledge** (domain), not by project of origin

### ❌ Does NOT go in LEARNED (nor in LEARNED_GLOBAL)
- Business or product rules/decisions ("the Advanced preset has priority", "the slider drone appears only if active")
- Feature-specific behavior, hardcoded project values
- Single-project user/UX preferences ("the user wants tabs here") → `PROJECT_UPDATES.md`
- Behavioral rules for Claude → `BEHAVIORS_LOCAL.md` (if local) or BEHAVIORS.md (method only, via the meta)
- Very-low-reuse items (a one-off incident) → trash, not written

**Quick test (PRINCIPLE vs FACT):**
- "Is it a **PRINCIPLE of how-you-work/build**, always true and tool-independent — or a **FACT** about a specific tool/API/project?" Principle → `LEARNED_GLOBAL/<domain>`. Specific fact → local `LEARNED.md` (even if "reusable"). Near-zero reuse → trash.
- "Is this a behavioral rule for Claude?" Local → `BEHAVIORS_LOCAL.md`. General (method) → only via the meta-project.
- Which **domain**? Apple/Swift → `software-apple.md`; web/backend → `software-web.md`; git/bash/tooling/architecture → `software-general.md`; UX/visual → `design.md`; method/workflow → `general.md`; cross-cutting preference → `preferences.md`.

---

## The Fundamental Principle

**"Don't trust Claude. Verify."**

Every command has:
1. **MANDATORY steps** - ORDERS, not suggestions
2. **VISIBLE output** - a checklist the user sees
3. **Checkpoints** - points where Claude STOPS and waits
