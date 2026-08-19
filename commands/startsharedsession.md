# Start Shared Session Command

Converts THIS session from `exclusive` to **`shared+named`**: it assigns a **name** (the signal of a parallel session, keel #1), takes a **base snapshot** of the method files (for the 3-way merge at `/savesession`), and, if needed, creates `.lock`s only for the **CODE** files it intends to modify.

## When to use it

- When there are **2+ Claude sessions in parallel** on the same repo and this one started **exclusive** (no name).
- After `/startsession`, **BEFORE** modifying any file.
- **Not needed** if you already started with `/startsession <name>` (you are already `shared+named`: the snapshot was taken at STEP 0.5b).

**Prerequisite:** `/startsession` created a `.locks/session-{uid}.json` marker. Recover the UID from the conversation context.

**File model (keel #1) — important:**
- **METHOD files** (`FOCUS`/`TODO`/`TO_FIX`/`TO_TEST`/`INBOX`/`PROGRESS`/`issues`): **not locked** → per-session temp + **3-way merge** at `/savesession` (`shared-convert` takes the base/work snapshot; `merge-method` merges into the canonical). No blocking lock → no "eternal close".
- **CODE files**: per-file `.lock` (contention is rare and short, and there you *do* want the block).

All operations go through `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`, auto-approved. No permission prompt at each step.

---

## MANDATORY STEPS

### STEP 1: Assign the session NAME

The **name** is the signal of a parallel/shared session. If the user hasn't already given one, **propose/ask for it** (e.g. «alice», «fix-auth»): short, unique among the live sessions.

```
🔗 What name should I convert this session to shared as? (e.g. «alice»)
```

### STEP 2: Convert exclusive→shared+named (+ snapshot of the method files)

A single atomic invocation:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh shared-convert <uid> --name <NAME>
```

The script:
- **ATOMIC name claim** (`mkdir names/<NAME>`); if already taken → `ERROR: name '<NAME>' already claimed` → pick another name and repeat;
- marker `type: exclusive→shared` + `name: <NAME>` (atomic write tmp+mv);
- **base/work snapshot** of the method files in `.locks/session-<uid>/{base,work}/` (needed for the 3-way merge at `/savesession`).

**MANDATORY OUTPUT:**
```
🔗 Session now SHARED «<NAME>» — UID <uid>
   • METHOD files → temp (merged at /savesession) · sprint: sprint-<NAME>.txt
   • ✅ shared-convert OK
```

From here on **write the method files normally**: your edits go to your temp (`work/`), not the canonical; they merge at `/savesession` (`merge-method`).

### STEP 3 (optional): Lock the CODE files you'll modify

Only for **code** files (NOT the method files, which are temp+merge). Identify the ones you'll touch and:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh share --uid <uid> <code-file-1> <code-file-2> ...
```

The script checks for conflicts: if a file you need is locked by another `owner_uid` → exit 3.

```
🔒 CONFLICT: [file] locked by owner_uid [other-uid] → ⛔ do NOT modify it. STOP and report.
```

If no conflict:
```
🔒 Code locks: [N] file(s) · ✅ no conflict
```

(If you're not modifying **code** files shared with other sessions, **skip** this step.)

### STEP 4: Summary

```
🔐 SHARED SESSION «<NAME>» ACTIVE — UID {uid}

📋 CODE files locked by me: [list | none]
🗂️  METHOD files: on temp (merged at /savesession) — not locked

⚠️ Rules:
- Do NOT modify CODE files locked by other sessions (`${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status`)
- For an unforeseen code file: `add-file --uid <uid> <file>` before touching it
- At the end of work: `/stopsharedsession` (releases the CODE locks) BEFORE `/savesession` (which runs `merge-method`)

Shall I proceed with the implementation?
```

---

### 🛑 STEP 5: STOP - Wait for confirmation

**Do NOT proceed until the user confirms.**

---

## Adding a CODE file during the session

If while working you discover you need to touch an unforeseen **code** file:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh add-file --uid <uid> <file>
```

The script:
- Checks for conflicts (file already locked by another UID → exit 3)
- If free: creates `.locks/<path-encoded>.lock` AND appends to the marker's `lockedFiles`
- If already self-locked: idempotent no-op, returns OK

**OUTPUT:**
```
🔒 Extra lock: [file] · ✅ OK: added [file] · 🔄 lockedFiles += [file]
```

> **Method** files must NOT be locked with `add-file`: write them directly (they go to the temp and merge at `/savesession`).

---

## Notes

- The `.locks/` files are in `.gitignore` — they are not committed.
- Each session is responsible for its OWN code locks (identified by `owner_uid`).
- **Orphan markers** (crashed session) are **reaped automatically** at the next `/startsession` (marker with a dead/recycled pid, same-host) — no need to remove them by hand.
- If a shared session crashes, its `work/` temp stays on disk: it is **recovered automatically** at the next `/startsession` (the `recover-temps` janitor merges the un-saved work into the canonical via 3-way merge), so nothing is lost.
