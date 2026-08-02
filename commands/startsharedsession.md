# Start Shared Session Command

Declares the files this session intends to modify and creates locks to avoid conflicts with parallel sessions. Changes your session marker from `exclusive` to `shared`.

## When to use

- When there are **2+ parallel Claude sessions** on the same repo
- **BEFORE** modifying any file
- After `/startsession`, before writing code

**Prerequisite:** `/startsession` has already created an `exclusive` marker `.locks/session-{uid}.json`. Recover the UID from the conversation context.

All operations go through `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`, auto-approved. No permission prompt at every step.

---

## MANDATORY STEPS

### STEP 1: Identify the files to touch

Analyze the assigned task and identify ALL the files you might modify.

**MANDATORY OUTPUT:**
```
📋 Files I intend to modify:
1. [path/to/file1.tsx]
2. [path/to/file2.ts]
...
```

---

### STEP 2: Check existing locks

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status
```

From the JSON output, extract the `file_locks[]` list and compare it with the files to touch. If you find a lock with an `owner_uid` different from yours on a file you need:

```
🔒 CONFLICT: [file] is locked by owner_uid [other-uid]
⛔ I cannot modify this file until the lock is removed.
```

**STOP and flag it to the user.** Do NOT proceed.

If no conflict:
```
✅ No conflict — all files are free
```

---

### STEP 3: Create the per-file locks and flip the marker to `shared`

A single atomic call:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh share --uid <uid> <file1> <file2> ...
```

The script:
- Re-checks conflicts (if another UID has locked one of the files → exit 3 with an error)
- Creates `.locks/<path-encoded>.lock` for each file (naming: `path/to/file.ext` → `path__to__file.ext.lock`, extension preserved)
- Updates `.locks/session-<uid>.json`: `type: exclusive→shared`, `lockedFiles = [file1, file2, ...]`

Schema of the per-file locks created:
```json
{
  "owner_uid": "<uid>",
  "file": "<path>",
  "task": "shared session work",
  "createdAt": "<ISO 8601 UTC>"
}
```

**MANDATORY OUTPUT:**
```
🔒 Locks created and marker updated:
✅ OK: shared with [N] file(s)
   • [file1] → .locks/[lockfile1]
   • [file2] → .locks/[lockfile2]

🔄 Marker: type exclusive→shared, lockedFiles=[N]
```

---

### STEP 4: Show the summary

```
🔐 SHARED SESSION ACTIVE — UID {uid}

📋 Files locked by me:
- [file1]
- [file2]

⚠️ Rules:
- Do NOT modify files locked by other sessions (check `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status`)
- Before touching an unplanned file, check and create the lock with `add-file`
- At the end of shared work, run /stopsharedsession BEFORE /savesession

Shall I proceed with the implementation?
```

---

### 🛑 STEP 5: STOP - Wait for confirmation

**Do NOT proceed until the user confirms.**

---

## Adding files during the session

If while working you discover you need to touch an unplanned file:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh add-file --uid <uid> <file>
```

The script:
- Checks conflicts (file already locked by another UID → exit 3)
- If free: creates `.locks/<path-encoded>.lock` AND appends to the marker's `lockedFiles`
- If already locked by yourself: idempotent no-op, returns OK

**OUTPUT:**
```
🔒 Additional lock: [file]
   ✅ OK: added [file]
🔄 Marker: lockedFiles += [file]
```

---

## Notes

- The `.locks/` files are in `.gitignore` — they are not committed
- Each session is responsible for its OWN locks (identified by `owner_uid`)
- If a session crashes without /stopsharedsession, the locks remain — the user removes them manually with `rm .locks/*.lock` (NOT other sessions' `session-*.json` unless they are orphaned)
