# Stop Shared Session Command

Releases all per-file locks created by this session and returns your marker from `shared` to `exclusive`.

## When to use

- **At the end of shared work** when `/startsharedsession` was used
- **BEFORE** `/savesession`
- When the parallel task is complete

All operations go through `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`, auto-approved.

---

## MANDATORY STEPS

### STEP 1: List active per-file locks

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status
```

From the JSON output, extract the `file_locks[]` list. The current session marker (`type: shared`) already has `lockedFiles` populated — they match the per-file `.lock`s whose `owner_uid` equals your UID.

**MANDATORY OUTPUT:**
```
🔒 Per-file locks currently active:
- [file1] → owner_uid: [uid]
- [file2] → owner_uid: [uid]
```

---

### STEP 2: Tell MY locks apart from others'

Recover your own `uid` from the context (announced by `/startsession`).

**MANDATORY OUTPUT:**
```
🔓 Locks to release (mine, owner_uid={uid}):
- [file1]
- [file2]

🔒 Locks of other sessions (do NOT touch):
- [file3] (owner_uid: [other-uid])
```

---

### STEP 3: Release my locks and restore the marker → `exclusive`

A single atomic call:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh release --uid <uid>
```

The script:
- Iterates over all per-file `.lock`s in `.locks/`
- Removes ONLY those whose `owner_uid` equals your UID
- Updates `.locks/session-<uid>.json`: `type: shared→exclusive`, `lockedFiles = []`

**MANDATORY OUTPUT:**
```
🔓 Locks released and marker restored:
✅ OK: released [N] lock(s)
🔄 Marker: type shared→exclusive, lockedFiles=[]
```

---

### STEP 4: Confirm cleanup

```
✅ SHARED SESSION CLOSED — UID {uid}

🔓 [N] per-file locks released
🔒 [M] per-file locks of other sessions still active
🔄 Marker back to EXCLUSIVE
📂 Directory .locks/: contains my session-{uid}.json + [M] others' locks

You can now run /savesession (it will remove the marker).
```
