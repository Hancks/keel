# Resume Session Command

Loads a SPECIFIC session (other than the most recent one).

## Difference from /startsession

| Command | What it loads | When to use it |
|---------|---------------|----------------|
| `/startsession` | Always the most recent session by name | ALWAYS at the start |
| `/resumesession [file]` | A specific session | To resume a past session |

## Usage

```
/resumesession [session-file-name]
```

Examples:
```
/resumesession 2026-01-20-23-15
/resumesession 2026-01-21-00-38.md
```

---

## MANDATORY STEPS

### STEP 1: List available sessions

If the user does not specify a file, show the available sessions.

**MANDATORY OUTPUT:**
```
📁 Available sessions:

| File | Date | Summary |
|------|------|---------|
| 2026-01-21-00-38.md | 2026-01-21 | [first line of the summary] |
| 2026-01-20-23-50.md | 2026-01-20 | [first line of the summary] |
| ... | ... | ... |

Which session do you want to load?
```

---

### STEP 2: Verify the file exists

**MANDATORY OUTPUT:**
```
🔍 Session check:
✅ File found: design-log/sessions/[name].md
```

If not found:
```
❌ File not found: design-log/sessions/[name].md

Available sessions:
[list]
```

---

### STEP 3: Read the specified session

Read the requested session file.

**MANDATORY OUTPUT:**
```
📖 Session loaded:
✅ design-log/sessions/[name].md ([N] lines)
```

---

### STEP 4: Show the session context

**MANDATORY OUTPUT:**
```
📅 **Session**: [file name]

📝 **Summary**:
[Session Summary content]

📊 **State at the time of the session**:
- Working on: [from Currently Working On]
- Procedure state: [from Procedure State]

🎯 **Handoff Notes of that session**:
- [point 1 from Immediate Next Steps]
- [point 2]

⚠️ **Note**: This is a past session, not the latest.
To check the current state, use /startsession.
```

---

### 🛑 STEP 5: STOP - Wait for instructions

**MANDATORY OUTPUT:**
```
Session [name] loaded.

Do you want to:
A) Continue from where this session left off
B) Just consult this session and return to the most recent one
C) Other

What do you prefer?
```

**Do NOT proceed until the user answers.**

---

## Verification checklist for the user

After Claude runs `/resumesession`, check:

- [ ] Did it show the available sessions (if not specified)?
- [ ] Did it verify the file exists?
- [ ] Did it show the session content?
- [ ] Did it warn that it is a past session?
- [ ] Did it stop to wait for instructions?

If something is missing, Claude did not follow the command correctly.
