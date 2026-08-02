# Add Task Command

FORCES the use of the Design-Log methodology for every new task.

## Why this command exists

Claude admitted: "If you hadn't asked me, I would not have followed the methodology."

This command FORCES the correct behavior. It is not optional.

## Usage

```
/add-task "task description"
```

Example:
```
/add-task "Add JWT authentication"
```

---

## MANDATORY STEPS

### STEP 1: Check whether it already exists

Search `TODO.md` (and `TO_FIX.md` if it is a bug) for whether the task is already there. Fallback: if the project is not migrated (empty split files), search `PROGRESS.md`.

**Glance at `INBOX.md`** (BEHAVIORS R.15): the request may already have been captured there by an earlier "note". If so, this `/add-task` is **triaging** it — remove it from `INBOX.md` when you bring it into TODO/FOCUS. Take the chance to triage any other related INBOX items too.

**MANDATORY OUTPUT:**
```
🔍 Existing-task check:
✅ Searched TODO.md / TO_FIX.md / INBOX.md (fallback PROGRESS.md if not migrated)
📋 Result: [NOT FOUND | FOUND in [file/section] | ALREADY IN INBOX → triaging]
```

If FOUND, ask:
```
This task seems to already exist in [file].
Do you want to:
A) Work on the existing one
B) Create a new one anyway
```

---

### STEP 2: Assess complexity

**MANDATORY OUTPUT:**
```
📊 Complexity assessment:
- Files involved (estimate): [number]
- Type: [simple | significant]
- Requires a design log: [YES | NO]
```

**Criteria:**
- **Simple** (NO design log): < 3 files, obvious fix, no architectural decision
- **Significant** (YES design log): >= 3 files, new feature, decisions to make

If **NO** → skip to STEP 9 (implement directly)
If **YES** → continue with STEP 3

---

### STEP 3: Create the design log

Create the file: `design-log/YYYY-MM-DD-[slug].md`

**MANDATORY OUTPUT:**
```
📝 Design log created:
✅ File: design-log/[file-name].md
```

---

### STEP 4: Write Background and Problem

Fill in the initial sections of the design log.

**MANDATORY OUTPUT:**
```
📄 Sections filled in:
✅ Background - [1-2 sentence summary]
✅ Problem - [1-2 sentence summary]
```

---

### STEP 5: Write questions (Socratic Method)

Do NOT assume. ASK questions about anything that is not clear.

**MANDATORY OUTPUT:**
```
❓ Questions for you:

Q1: [specific question]
Q2: [specific question]
Q3: [specific question]
...
```

At least 2 questions. If there are no questions, explain why:
```
❓ No questions: [explanation of why everything is clear]
```

---

### 🛑 STEP 6: STOP - Wait for answers

**MANDATORY OUTPUT:**
```
🛑 CHECKPOINT

Waiting for your answers to the questions before proceeding.
I will not proceed until you answer.
```

**Do NOT proceed until the user answers.**

---

### STEP 7: Complete the Design

After the answers, update the design log:
- Fill in the Q&A section with the answers
- Write the Design section
- Define the Implementation Plan

**MANDATORY OUTPUT:**
```
📐 Design completed:
✅ Q&A filled in with answers
✅ Design section written
✅ Implementation Plan: [N] steps defined
```

---

### 🛑 STEP 8: STOP - Ask for approval

**MANDATORY OUTPUT:**
```
🛑 CHECKPOINT - APPROVAL REQUIRED

Design completed: design-log/[file-name].md

Summary:
- [key point 1 of the design]
- [key point 2 of the design]
- [key point 3 of the design]

Implementation Plan:
1. [step 1]
2. [step 2]
3. [step 3]
...

Do you approve the implementation? (yes/no)
```

**Do NOT proceed until the user says "yes", "approved", "ok", "go" or similar.**

---

### STEP 9: Implement

Only AFTER explicit approval (or if it is a simple task with no design log).

**Before writing**: bring this task into `FOCUS.md` as `🔄 in progress` (BEHAVIORS R.17 — only one item in progress at a time; if there is already one, mark it `⏸️` or finish it first). Note the **"done" criterion** (how the user will see that it works).

**MANDATORY OUTPUT (during implementation):**
```
🎯 Brought into FOCUS.md: 🔄 [task] — done criterion: [...]
🔨 Implementation in progress:
✅ [file created/modified] - [what]
✅ [file created/modified] - [what]
...
```

---

### STEP 10: Update the tracking files (split by type) — done = validated (R.16)

⚠️ **Tell implemented apart from validated (BEHAVIORS R.16).** A green `tsc`/build is NOT "done".

- **Implemented but NOT validated** (you finished writing it, the user has not yet seen it work) → the item goes to `TO_TEST.md` and stays in `FOCUS.md` with the state `🧪 to validate`. **NOT** in `DONE.md`. The task is NOT closed.
- **Validated in this same session** (the user has seen it work) → ONLY now:
  - A rich entry (What/How/Files/Notes) in `DONE.md` (or `FIXED.md` if it was a bug)
  - Remove the task from `TODO.md`/`TO_FIX.md`/`TO_TEST.md` and from `FOCUS.md`
  - If `DONE.md`/`FIXED.md` exceeds ~400 lines → archive the old entries in `progress.old.md`
- Update the counters + "Last updated" in `PROGRESS.md` (index)
- Fallback: if the project is not migrated, update the DONE section of `PROGRESS.md`

**MANDATORY OUTPUT:**
```
📊 Tracking updated:
[if validated] ✅ Entry in DONE.md (or FIXED.md) · removed from TODO/TO_FIX/TO_TEST + FOCUS
[if only implemented] 🧪 In TO_TEST.md + FOCUS.md (🧪 to validate) — NOT closed, awaiting user validation
✅ PROGRESS.md index + counters updated · Timestamp: [new timestamp]
```

---

### STEP 11: Update the design log (if it exists)

**MANDATORY OUTPUT:**
```
📝 Design log updated:
✅ Implementation Plan: all steps checked off
✅ Status: Implemented
✅ Implementation Results: notes added
```

---

## Final summary

**MANDATORY OUTPUT:**
```
✅ TASK COMPLETED

📋 Task: [description]
📝 Design log: [path or "not required"]
📁 Files modified: [number]
📊 Tracking: DONE.md/FIXED.md + TODO.md/TO_FIX.md + PROGRESS.md index updated

Suggested next step: [from TODO.md — or PROGRESS.md TODO if not migrated]
```

---

## Verification checklist for the user

After Claude runs `/add-task`, check:

- [ ] Did it check whether the task already existed?
- [ ] Did it assess the complexity?
- [ ] (If significant) Did it create a design log?
- [ ] (If significant) Did it ask questions?
- [ ] (If significant) Did it stop to wait for answers?
- [ ] (If significant) Did it ask for explicit approval?
- [ ] Did it bring the task into `FOCUS.md` (🔄 in progress) before implementing?
- [ ] Did it respect done=validated (R.16): in DONE/FIXED only if the user validated; otherwise TO_TEST + FOCUS 🧪?
- [ ] Did it update the tracking files at the end (DONE.md/FIXED.md + TODO.md/TO_FIX.md + PROGRESS.md index)?
- [ ] Did it update the design log at the end (if it exists)?

If something is missing, Claude did not follow the command correctly.
