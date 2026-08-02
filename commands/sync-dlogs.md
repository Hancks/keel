# Sync Design Logs Command

A safety net to sync the files when Claude forgets to update them.

## When to use

- After Claude completes a task but does not update the files
- When you are not sure whether the files are in sync
- Before /savesession (as a double-check)
- After significant changes

---

## MANDATORY STEPS

### STEP 1: Analyze the recent conversation

Identify:
- Completed tasks
- Decisions made
- Files modified
- Design logs created/updated

**MANDATORY OUTPUT:**
```
🔍 Conversation analysis:
- Completed tasks: [list]
- Decisions made: [list]
- Files modified: [list]
- Design logs involved: [list or "none"]
```

---

### STEP 2: Verify the tracking files (split by type)

Check whether they are up to date. The tracking is split by type; `PROGRESS.md` is only the index (see METHODOLOGY).

**Checklist to verify:**
- [ ] `INBOX.md` triaged (no raw request forgotten)?
- [ ] `FOCUS.md` reflects the current objective (only ONE 🔄 in progress)?
- [ ] In `DONE.md`/`FIXED.md` ONLY **validated** work (implemented-not-validated → `TO_TEST.md` + `FOCUS.md` 🧪, BEHAVIORS R.16)?
- [ ] Validated tasks with What/How/Files/Notes and removed from TODO/TO_FIX/TO_TEST + FOCUS?
- [ ] New TODOs/bugs in `TODO.md`/`TO_FIX.md`?
- [ ] `DONE.md`/`FIXED.md` under ~400 lines (over → archive in `progress.old.md`)?
- [ ] `PROGRESS.md` index: "Last updated" + counters + links correct?
- [ ] Fallback: non-migrated project (empty split files) → check the DONE/TODO section of `PROGRESS.md`

**MANDATORY OUTPUT:**
```
📊 Tracking:
✅ DONE.md/FIXED.md with What/How/Files
❌ Entry for [task] was missing in DONE.md → UPDATED
✅ TODO.md/TO_FIX.md/TO_TEST.md updated · PROGRESS.md index in sync
```

If something is missing → UPDATE it and show ❌ → UPDATED

---

### STEP 3: Verify the Design Log (if it exists)

**Checklist to verify:**
- [ ] Implementation Results updated?
- [ ] Implementation Plan checked off?
- [ ] Status correct?

**MANDATORY OUTPUT:**
```
📝 Design log [name]:
✅ Implementation Results updated
❌ Implementation Plan not checked off → UPDATED
✅ Status: Implementing
```

If there is no design log:
```
📝 Design log: none involved
```

---

### STEP 4: Verify the Session Log (if needed)

**Checklist to verify:**
- [ ] Long session (15+ exchanges)?
- [ ] New skills/procedures to document?
- [ ] Failed attempts to record?
- [ ] User preferences discovered?

**MANDATORY OUTPUT:**
```
📅 Session log:
⚠️ Long session (20+ exchanges) - consider /savesession
✅ No failed attempts to record
✅ No new preferences
```

---

### STEP 5: Final summary

**MANDATORY OUTPUT:**
```
🔄 SYNC COMPLETED

Updates made:
✅ Tracking (DONE/FIXED/TODO/TO_FIX/TO_TEST + PROGRESS index) - [what was updated]
✅ design-log/[name].md - [what was updated]
⏭️ Session log - already in sync

Total: [X] files updated, [Y] already in sync

⚠️ Suggestion: [if needed, e.g. "consider /savesession"]
```

If everything was already in sync:
```
✅ ALL IN SYNC

No update needed.

Last update:
- Tracking (PROGRESS.md index + split files): [timestamp]
- Active design log: [name or "none"]
- Last session: [timestamp]
```

---

## Verification checklist for the user

After Claude runs `/sync-dlogs`, check:

- [ ] Did it analyze the conversation?
- [ ] Did it verify the tracking files (DONE/FIXED/TODO/TO_FIX/TO_TEST + PROGRESS.md index)?
- [ ] Did it verify the design log (if it exists)?
- [ ] Did it consider the session log?
- [ ] Did it show a summary with ✅/❌?

If something is missing, Claude did not follow the command correctly.
