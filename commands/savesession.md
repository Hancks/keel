# Save Session Command

Saves the context of the current session and syncs ALL the methodology documents.

## When to use

- Long conversation (15+ exchanges)
- Before ending the session
- Before switching context
- After an important milestone
- After complex debugging

---

## MANDATORY STEPS

### STEP 1: Re-read METHODOLOGY.md

Re-read `design-log/METHODOLOGY.md` to refresh your memory on what you need to do.

**MANDATORY OUTPUT:**
```
📖 METHODOLOGY.md re-read
```

---

### STEP 1.5: 🧹 Completeness sweep + INBOX triage (FORCING — BEHAVIORS R.15)

> This exists because the method's problem #1 is "requests lost between turns": something said and not written down disappears. Here, before closing, you **guarantee** that every request of the session has landed in a file and that `INBOX.md` doesn't stay full.

#### 1.5a: Completeness sweep (re-read the session)

Go back through THIS session's conversation from the start and **extract everything the user asked, proposed, or said to capture ("note")** — even the smallest, even the ones not yet done. For each one, verify it is tracked in a file (`INBOX.md`, `TODO.md`, `TO_FIX.md`, `FOCUS.md`, or already closed in `DONE.md`/`FIXED.md`/`TO_TEST.md`).

If something is **only in the chat and in no file** → write it NOW (INBOX if raw/untriaged, TODO/TO_FIX if it is already clear work). Do NOT close the session with live requests only in the conversation.

#### 1.5b: INBOX triage (blocking)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh inbox-check
```

If `inbox_untriaged > 0`: **triage every item** in `INBOX.md` — for each one decide `→ TODO.md` (with priority), `→ TO_FIX.md` (bug), or `🗑 dropped` (with a why). An item brought into the current work also goes into `FOCUS.md`.

> **The "triage MOVES" rule (2026-07-14)**: a triaged item is **TRANSFERRED** into the destination file (with its origin, e.g. `(from INBOX, YYYY-MM-DD)`) and **deleted from INBOX**. FORBIDDEN to annotate it in place: no `- [x]`, no "✅ done/triaged → …" left inside INBOX. At the end of triage `INBOX.md` contains ONLY whatever the user explicitly deferred; otherwise it goes back to empty (`*(empty)*`). — This is the pattern that on 2026-07-14 had turned INBOX into a thicket: the design was right, the rule was unenforced prose.

If `inbox_residue > 0` (from the `inbox-check` output): inside INBOX there are lines that are NOT open captures `- [ ]` (checked items, annotations, prose) = **in-place triage residue** from past sessions → **move them NOW** into the right file (TO_TEST/TODO/TO_FIX/DONE, with origin) and delete them from INBOX.

⚠️ **Do NOT proceed to STEP 2 with `inbox_untriaged > 0` or `inbox_residue > 0`**, unless the user explicitly asks to defer specific items (in which case they stay in INBOX with a note, and ONLY those).

**MANDATORY OUTPUT:**
```
🧹 Completeness sweep: [N session requests verified] · [M written now because only-in-chat | all already tracked]
📥 INBOX triage: [K items MOVED → TODO/TO_FIX/🗑 | INBOX already empty] · [R residue moved | no residue] · final inbox-check: inbox_untriaged=0 · inbox_residue=0
```

---

### STEP 2: Sync documents (sync-dlogs logic)

Analyze the conversation and sync ALL the documents.

#### 2a: Analyze the conversation

Identify: completed tasks, decisions made, files modified, design logs involved.

#### 2b: Verify and update the tracking files (split by type)

The tracking is **split by type** (see METHODOLOGY "The lifecycle of work"). `PROGRESS.md` is only a **light index**; the entries live in the split files. **Tell implemented apart from validated (BEHAVIORS R.16)** and route like this:

- **Implemented but NOT validated** (green build, the user has not yet seen it) → the item goes to `TO_TEST.md` and stays in `FOCUS.md` with the state `🧪 to validate`. Do **NOT** write it to `DONE.md`/`FIXED.md`.
- **Validated** (the user has seen it work in this session) → ONLY now a rich entry (What/How/Files/Notes) in `DONE.md`; if it was a bug → `FIXED.md`. **Remove the item** from `TODO.md`/`TO_FIX.md`/`TO_TEST.md`.
- **New task opened** → `TODO.md` (with priority 🔴/🟡/🟢); a new bug → `TO_FIX.md`.
- **Refresh `FOCUS.md`**: the validated item leaves; if the current objective frees up, promote the next `⏸️` to `🔄`. FOCUS must stay short and truthful.
- **Multisession — track the origin in `FOCUS.md` (BEHAVIORS R.9)**: if this session ran **in parallel** with others — i.e. at `/startsession` there were already other markers in `.locks/` (Case B/C), or this session was `shared`, or `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status` **now** shows other active markers besides yours — then different sessions write **the same `FOCUS.md` without seeing each other**, so:
  1. **Tag EVERY item** you write or update in `FOCUS.md` with the session of origin, at the end of the item: `— ⟨session {short-uid} · {YYYY-MM-DD}⟩` (the `{uid}` is yours, announced at `/startsession`; the STEP 4 session log carries the same UID, so it is traceable). Without the tag you can't tell which session an indication comes from.
  2. Put (or leave, if another parallel session already put it) **at the top of `FOCUS.md`**, on a single line, the explicit marker:
     `> ⚠️ MULTISESSION {YYYY-MM-DD}: this round had parallel sessions — /startsession must read ALL sessions of this date (not just the last one by name).`
  3. **Marker lifecycle**: the marker + tags stay until the parallel work is **consolidated**. The first subsequent **single-session** `/savesession` (no other active marker) that re-reads and reconciles `FOCUS.md` **removes** the marker and the now-useless tags. _(This clause-3 is a hygiene addition, not explicitly required: it just avoids leaving the marker in FOCUS forever.)_
- **Threshold archiving**: if `DONE.md` or `FIXED.md` exceeds **~400 lines**, move the **oldest** entries into `progress.old.md`.
- Update `PROGRESS.md` (only: "Last updated" + TODO/bug/test counters + links). NO log entries in PROGRESS.md.

Checklist:
- [ ] PROGRESS.md "Last updated" current + counters updated?
- [ ] In `DONE.md`/`FIXED.md` ONLY work **validated** by the user (implemented-not-validated is in `TO_TEST.md` + `FOCUS.md` `🧪`)?
- [ ] Validated items removed from `TODO.md`/`TO_FIX.md`/`TO_TEST.md` and from `FOCUS.md`?
- [ ] `FOCUS.md` updated (only ONE `🔄 in progress`, closed items removed)?
- [ ] New TODOs/bugs routed to `TODO.md`/`TO_FIX.md`?
- [ ] `DONE.md`/`FIXED.md` under ~400 lines (over → archived in `progress.old.md`)?
- [ ] Missing split files (incl. `FOCUS.md`/`INBOX.md`) → created from templates (see METHODOLOGY)?

> Backward compatibility: if the project still has a monolithic `PROGRESS.md` (empty split files), this is the session where the organic migration starts: write the NEW entries in the split files. The history already in PROGRESS.md is NOT to be moved by force.

#### 2b-bis: 🌿 PRUNE FOCUS.md (FORCING — 2026-07-14 rule "FOCUS is pruned at every close")

> This exists because FOCUS, if you only APPEND to it, becomes a second TODO and stops focusing (incident 2026-07-14: FOCUS thicket; diagnosis shared with the user: the design was right, the rule was unenforced prose). Here the condition is checked by **script** and the action is **blocking**.

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh focus-check
```

Read `focus_lines` / `focus_bloat` (threshold `focus_bloat_threshold`, default 40 lines):

- **`focus_bloat=no`** → FOCUS within threshold. Refine it anyway (this is the ordinary prune of 2b): the closed/validated items LEAVE (their history goes down into the STEP 4 **session log**), only ONE `🔄 in progress` remains + the essential in-flight/to-validate items.
- **`focus_bloat=yes`** → ⛔ **PRUNE REQUIRED before proceeding**: move to the session log (STEP 4) all the history and the items already tracked elsewhere (TO_TEST/TODO/DONE — in FOCUS a pointer is enough, not the story); in FOCUS only the current objective + the in-flight items remain. Then **re-run `focus-check`**: it must give `focus_bloat=no`. Do NOT proceed to STEP 3 with `focus_bloat=yes`.
- **Multisession exception**: if `FOCUS.md` is locked by another active session, the prune is **DEFERRED** with an explicit note in the session log ("FOCUS not prunable: locked by {uid}") — the first single-session `/savesession` will do it (same logic as the MULTISESSION marker, point 3 above).

**MANDATORY OUTPUT:**
```
🌿 Prune FOCUS: focus_lines=[N] · focus_bloat=[no | yes → pruned, re-check: focus_lines=[M], focus_bloat=no] · [K items moved down to the session log | none to move | DEFERRED: FOCUS locked by {uid}]
```

#### 2b-ter: 🏃 Review and PRUNE `sprint.txt` (FORCING — if the file exists)

> This exists because `sprint.txt` (which `/startsession` STEP 5A auto-runs) was NOT reviewed at the end of work → it stayed STALE: already-done items still listed, superseded items, state not updated. The next `/startsession` restarts from an old plan (FM1: objective amnesia). It must be **pruned at every close**, like FOCUS.

If `sprint.txt` exists in the project root:
1. **Re-read it in full.**
2. For EACH item, compare it with the real state just synced (2b): done/validated → in `DONE.md`/`FIXED.md`? implemented-not-validated → `TO_TEST.md`? still open? superseded/no longer valid?
3. **Prune**: REMOVE the completed/validated items and the superseded ones; UPDATE the partial ones to the real state (with a note); keep ONLY what truly remains to do.
4. If after the prune it is empty (all done): leave just the header/comment and flag it — a sprint full of already-done stuff is a plan that **LIES** to the next `/startsession`.
5. The prune **removes/updates, does not add**: new work goes to `TODO.md`, not to the sprint.

**MANDATORY OUTPUT:**
```
🏃 Prune sprint.txt: [N items reviewed · K removed (done/superseded) · J updated · remaining: <1-line summary> | sprint.txt absent → skip]
```

#### 2b-quater: 📄 ASK YOURSELF whether there are reports/artifacts to update (FORCING)

> Some projects have "showcase" files **derived from state** — e.g. the `/report` output (`design-log/report.html`), a dashboard, other artifacts/reports. They do NOT auto-update at the end of work → they stay stale (the RECURRING gap: files misaligned at reopening). The method must **ask itself ON ITS OWN** at every close, not wait for the user to say so.

**Ask yourself**: did anything change in this session that one or more of these files should reflect?
1. **Look for** the project's reports/artifacts: `design-log/report.html`, a dashboard, `.html`/artifacts in `design-log/`, files cited as "report/showcase" in FOCUS/PROJECT_UPDATES.
2. For each, assess whether it is **stale** relative to the state just synced (2b).
3. If it is stale → **update/regenerate it** (or re-run the command that produces it, e.g. `/report`). Do not leave it stale silently: if you decide NOT to regenerate it (e.g. costly and not needed), **say so explicitly** in the summary with the why.

**MANDATORY OUTPUT:**
```
📄 Reports/artifacts: [found: <list> · updated: <which> · left (why): <which> | none]
```

#### 2c: Verify and update the Design Log (if it exists)

Checklist:
- [ ] Implementation Results updated?
- [ ] Implementation Plan checked off?
- [ ] Status correct?

#### 2d: Verify and update issues/_INDEX.md (if needed)

Checklist:
- [ ] New issues created during the session?
- [ ] Issue statuses updated?

**MANDATORY OUTPUT:**
```
🔄 Document sync:
✅ Tracking - DONE.md/FIXED.md: [N entries] · TODO.md/TO_FIX.md/TO_TEST.md: [N] · PROGRESS.md index: [updated | in sync] · progress.old.md: [N archived | -]
✅ Design log [name] - [updated | already in sync | none]
✅ Issues - [updated | already in sync]
```

If something was out of sync, show what was corrected:
```
❌ DONE.md - entry for [task] was missing → UPDATED
❌ DONE.md - over ~400 lines → [N] old entries moved to progress.old.md
```

---

### STEP 3: Extract lessons/rules that emerged, classify, route them

Reflect on the session and identify ALL the new behavioral rules and technical lessons that emerged.

Ask yourself:
- Did I discover a reusable technical pattern?
- Did I make a mistake I must not repeat?
- Did I discover a user preference?
- Did I find a solution to a problem that could recur?
- Did a new behavioral rule emerge (about how Claude should behave)?

If there are entries, **classify** and **route** them per BEHAVIORS Rule 14. **NEVER write to BEHAVIORS.md or METHODOLOGY.md.**

#### 3a: Automatic classification

For each entry, apply the heuristic:

**Local vs Global — PRINCIPLE vs FACT:**
- **Global (cross-project)** ONLY if the entry is a **universal PRINCIPLE of *how you work / how you build***, always true by nature and independent of the tool/project (e.g. "if it doesn't work, don't guess: turn the logs up and trace the flow, expected vs actual"; "it compiles ≠ it works"; "verify, don't assume"; "a cause deduced by elimination must be tested with the cheapest means").
- **Local to the project** if the entry is a **specific FACT/gotcha** — even if "technically general / reusable":
  - It contains project paths/proper names/integrations/conventions, OR
  - It is a fact about a single API/tool/library (e.g. "a plugin's `hooks/hooks.json` auto-loads"; a single library's quirk) — **a specific fact stays local even if several projects will use it**: local memories are **recalled** cross-project when needed.
- **Trash (not written)** if the entry has near-zero reuse: a one-off incident, too specific to recur.
- **Conservative default: local** if unsure.
- ⚠️ **Do NOT use the "≥2 projects" count** (a fallacious criterion, abandoned 2026-07-30): the number of projects makes nothing global. Blunt rule: **GLOBAL = principle · LOCAL = specific fact**.

**Type (for local entries):**
- **Behavioral rule** (about how Claude should behave in the project) → `BEHAVIORS_LOCAL.md`
- **Context/convention/operational decision** (workflow, naming, deploy, architectural tensions, changed scope) → `PROJECT_UPDATES.md`
- **Technical lesson/pattern** (about how something works in the project, incl. a niche single-project gotcha) → `LEARNED.md`

**Domain (for global entries) → one FILE in `~/.claude-method/LEARNED_GLOBAL/`** (since 2026-06-05; chosen by kind of knowledge, not by project of origin):
- Swift/iOS/macOS/Catalyst/AVFoundation/Xcode/StoreKit → `software-apple.md`
- web/backend/JS/TS/Next/React/Astro/Node/Python-backend/DB/auth/SaaS/cloud → `software-web.md`
- git/bash/tooling/build/cross-repo architecture/ML-OCR/ffmpeg/cross-language → `software-general.md`
- aesthetics/UX/spacing/contrast/typography/controls → `design.md`
- analysis/citations/literature/dataset → `research.md` (create it if it doesn't exist)
- style/voice/audience/editing → `writing.md` (create it if it doesn't exist)
- workflow/method/communication/working-with-agents cross-domain → `general.md`
- user preferences **across all projects** → `preferences.md` (NOT preferences of a single project/suite)

**Sub-section (inside the domain file):**
- `### Technical Patterns` — a reusable pattern
- `### Mistakes Not to Repeat` — an anti-pattern, a mistake already made
- `### Reusable Solutions` — a complete solution to a recurring problem
(`general.md`/`preferences.md`/`design.md` may have fewer sub-sections; follow the file's existing structure.)

#### 3b: Show the classification and ask for confirmation

**MANDATORY OUTPUT:**
```
📝 New rules/lessons that emerged in this session:

1. [LOCAL/Behavioral] "<entry text>"
   → BEHAVIORS_LOCAL.md / Behavioral Rules

2. [LOCAL/Context] "<entry text>"
   → PROJECT_UPDATES.md / Project Context / Conventions

3. [GLOBAL/software-web/Mistakes Not to Repeat] "<entry text>"
   → ~/.claude-method/LEARNED_GLOBAL/software-web.md / Mistakes Not to Repeat

4. [LOCAL/Technical lesson] "<entry text>"
   → LEARNED.md / Technical Patterns

Do you confirm this classification? (yes / correct: number → new target)
```

**If no entries**:
```
🧠 No new lessons or rules emerged in this session.
```

#### 3c: Wait for confirmation and write

🛑 **CHECKPOINT** — do not proceed until the user confirms or corrects.

After confirmation, write each entry into the right file, the right section.

**MANDATORY OUTPUT:**
```
✍️  Entries written:
✅ BEHAVIORS_LOCAL.md: 1 entry in Behavioral Rules
✅ PROJECT_UPDATES.md: 1 entry in Project Context / Conventions
✅ LEARNED.md: 1 entry in Technical Patterns
✅ ~/.claude-method/LEARNED_GLOBAL/software-web.md: 1 entry in Mistakes Not to Repeat
```

**NEVER write to BEHAVIORS.md or METHODOLOGY.md.** If during the session the user explicitly asked for changes to the method (the meta-project's BEHAVIORS or METHODOLOGY), those go as an explicit task (`/add-task`), not from `/savesession`.

---

### STEP 4: Create the session log

Generate a timestamp in the format `YYYY-MM-DD-HH-MM`.
Create the file `design-log/sessions/[timestamp].md` with the full structure (see METHODOLOGY.md).

**MANDATORY OUTPUT:**
```
📝 Session log created:
✅ File: design-log/sessions/[timestamp].md
```

---

### STEP 5: Remove the session marker

Identify and remove the marker created by THIS session in `/startsession`. All operations go through `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`, auto-approved.

#### 5a: Identify your own UID

The UID was announced by `/startsession` of this same conversation (Case A or B of STEP 0.5). Recover it from the context.

**If you can't find it in the context** (e.g. compacted conversation or read-only mode):
- Run `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status` to see the present markers (with `host` + `startedAt`)
- Ask the user: "Which one is yours? (or 'none' if you were in read-only mode)"
- Wait for the answer before proceeding

#### 5b: Check the marker state and remove it

Before removing, run `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status` and read your marker. If `type` is still `shared` or `lockedFiles` is not empty:
⚠️ **WARNING**: replace `{uid}` with the real UID BEFORE running the command. `rm -f` fails silently if the file doesn't exist — so a literal `{uid}` would give no error but remove nothing. Use the expanded variable and **verify** the removal.

```bash
# Replace MYUID with your real UID (you announced it in /startsession)
MYUID="YOUR-REAL-UID"
MARKER=".locks/session-${MYUID}.json"

if [ ! -f "${MARKER}" ]; then
  echo "⚠️ MARKER NOT FOUND: ${MARKER} — check the correct UID"
  ls .locks/
  exit 1
fi

rm "${MARKER}"

# Post-rm check
if [ -f "${MARKER}" ]; then
  echo "❌ REMOVAL FAILED: ${MARKER} still exists"
  exit 1
fi

echo "✅ Marker removed: ${MARKER}"
```

**If the command prints `⚠️ MARKER NOT FOUND` or `❌ REMOVAL FAILED`**, stop and flag it to the user — do NOT move on to STEP 7 with a fake success output.

**If you were in READ-ONLY MODE** (Case C of startsession): do NOT remove anything — you didn't create a marker.

**If you were in SHARED MODE**: the user should already have run `/stopsharedsession` before `/savesession`. If you still find a non-empty `lockedFiles` in your marker, flag it:
```
⚠️ Marker still SHARED with locked files: [...]
   Run /stopsharedsession BEFORE /savesession.
```
**STOP and flag it to the user.**

Otherwise remove it:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh end <uid>
```

**If you were in READ-ONLY MODE** (Case C of startsession): do NOT run `end` — you didn't create a marker.

#### 5c: Include the UID in the session log

In the session log created at STEP 4, add at the top (after the header):
```markdown
**Session UID**: {uid}
**Marker type at close**: {exclusive | shared | read-only}
```
So that re-reading the logs shows whether there were concurrent sessions at that time.

**MANDATORY OUTPUT:**
```
🔓 Marker removed: .locks/session-{uid}.json
   (or: ⏭️  Read-only mode — no marker to remove)
```

---

### STEP 6: Final summary

**MANDATORY OUTPUT:**
```
✅ SESSION SAVED

🆔 UID: {uid} — marker removed ({exclusive|shared|read-only})
📁 Session log: design-log/sessions/[timestamp].md
🔄 Sync: [N] documents updated, [M] already in sync
✍️  Entries routed:
   - BEHAVIORS_LOCAL.md: [N] entries
   - PROJECT_UPDATES.md: [N] entries
   - LEARNED.md (local): [N] entries
   - ~/.claude-method/LEARNED_GLOBAL/<domain>.md: [N] entries

Content saved:
- Active skills: [short list]
- Next steps: [first step]

To resume, use /startsession (it will read the most recent session by name,
BEHAVIORS, BEHAVIORS_LOCAL, local LEARNED, LEARNED_GLOBAL and PROJECT_UPDATES automatically).
```

**Important reminder:** if you updated a file in the global dir (`$GLOBAL_DIR/LEARNED_GLOBAL/` — resolved by `lock.sh global-dir`, default `~/.claude-method`, override `KEEL_GLOBAL_DIR`) **and** that dir is a git repo, consider committing and pushing:
```bash
GLOBAL_DIR="$(${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh global-dir)"
cd "$GLOBAL_DIR" && git rev-parse --git-dir >/dev/null 2>&1 && git add . && git commit -m "Update LEARNED_GLOBAL: <short description>" && git push
```
(The dir auto-bootstrapped by the standalone might **not** be a git repo: in that case no commit, the files stay only on disk. Pushing requires a configured remote.)

---

## Session Log Template (Reference)

The file must contain these sections (see METHODOLOGY.md for details):

1. **Session Summary** - What was done
2. **CRITICAL SECTIONS**:
   - Active Skills & Methodologies
   - Procedure State
   - What We Tried That Didn't Work
   - User Preferences Discovered
3. **Context Snapshot**:
   - Currently Working On
   - Key Decisions Made
   - Problems Encountered
4. **Handoff Notes**:
   - Immediate Next Steps
   - Blockers / Waiting On
   - Don't Forget
5. **Files Modified This Session**

---

## Verification checklist for the user

After Claude runs `/savesession`, check:

- [ ] Did it re-read METHODOLOGY.md?
- [ ] Did it do the completeness sweep (every session request landed in a file) and triage `INBOX.md` by **MOVING** the items out (until `inbox_untriaged=0` **and** `inbox_residue=0` — no "✅ done" annotations left inside)?
- [ ] Did it write to DONE/FIXED ONLY work **validated** by the user (implemented-not-validated → TO_TEST + FOCUS 🧪)?
- [ ] Did it run the **FOCUS prune** (2b-bis): `focus_bloat=no` on re-check (or prune DEFERRED with a note because FOCUS was locked by another session)?
- [ ] Did it **review and prune `sprint.txt`** (2b-ter): removed done/superseded items, updated the state — no stale sprint for the next `/startsession`?
- [ ] Did it **ask itself** (2b-quater) whether there were stale reports/artifacts (e.g. `design-log/report.html`, dashboard), and update/regenerate them (or explicitly say why not)?
- [ ] Did it update `FOCUS.md` (closed items removed, only ONE 🔄 in progress, history moved down to the session log)?
- [ ] Did it route the items into the split files (DONE/FIXED/TODO/TO_FIX/TO_TEST) and update PROGRESS.md index + counters?
- [ ] Did it archive to progress.old.md if DONE.md/FIXED.md exceeded ~400 lines?
- [ ] Did it sync the design log (if it exists)?
- [ ] Did it sync the issues (if needed)?
- [ ] Did it extract the entries, show the classification, and ask for confirmation?
- [ ] Did it route the entries into BEHAVIORS_LOCAL.md / PROJECT_UPDATES.md / LEARNED.md / the right domain file in LEARNED_GLOBAL/ per the confirmed classification (PRINCIPLE vs FACT criterion: only universal principles go global, specific facts stay local)?
- [ ] Did it **NOT write to BEHAVIORS.md or METHODOLOGY.md**?
- [ ] Did it create the session log with all the sections?
- [ ] Did it remove the marker `.locks/session-{uid}.json` (or explain why not, read-only)?
- [ ] Did it show the final summary (including the entry count per file)?

If something is missing, Claude did not follow the command correctly.
