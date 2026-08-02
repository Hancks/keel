# New Issue Command

Creates a new issue in `design-log/issues/`.

## Usage

```
/new-issue [type] [title]
```

Where:
- `type`: bug | enhancement | review
- `title`: a short descriptive title

Examples:
```
/new-issue bug Login fails on mobile
/new-issue enhancement Add dark mode
/new-issue review Check query performance
```

---

## MANDATORY STEPS

### STEP 1: Verify the structure

**MANDATORY OUTPUT:**
```
📁 Structure check:
✅ design-log/issues/ exists
✅ design-log/issues/_INDEX.md exists
```

If something is missing, create it:
```
❌ design-log/issues/ does not exist → CREATED
❌ _INDEX.md does not exist → CREATED
```

---

### STEP 2: Parse or ask for details

If type/title are provided:
```
📋 Issue:
- Type: [bug/enhancement/review]
- Title: [title]
```

If not provided, ask:
```
❓ What type of issue?
- 🐛 bug - Something is broken
- ✨ enhancement - An improvement
- 👀 review - To be checked

❓ What is the title?
```

---

### STEP 3: Ask for severity/priority

For a bug:
```
❓ Severity?
- 🔴 critical - System unusable
- 🟠 major - Important feature broken
- 🟡 minor - Minor problem, workaround exists
- ⚪ trivial - Cosmetic
```

For enhancement/review:
```
❓ Priority?
- 🔴 high
- 🟡 medium
- 🟢 low
```

---

### STEP 4: Determine the next ID

Count the existing files to determine the ID.

**MANDATORY OUTPUT:**
```
🔢 Assigned ID:
- Type: [BUG/ENH/REV]
- Number: [NNN]
- Full ID: [TYPE]-[NNN]
```

---

### STEP 5: Ask for the description

```
❓ Describe the issue in detail:
- What happens? (for a bug)
- What do you want to achieve? (for an enhancement)
- What needs to be checked? (for a review)
```

---

### STEP 6: Create the issue file

Create `design-log/issues/{TYPE}-{NNN}-{slug}.md`

**MANDATORY OUTPUT:**
```
📝 Issue created:
✅ File: design-log/issues/[TYPE]-[NNN]-[slug].md

Content:
- Title: [title]
- Type: [type]
- Severity/Priority: [level]
- Status: in-progress
- Description: [short]
```

---

### STEP 7: Update _INDEX.md

Add a row to the table and update the stats.

**MANDATORY OUTPUT:**
```
📊 _INDEX.md updated:
✅ New row added to the table
✅ Stats updated: In Progress [N]
```

---

### STEP 8: Final summary

**MANDATORY OUTPUT:**
```
✅ ISSUE CREATED

[TYPE]-[NNN]: [Title]

📁 File: design-log/issues/[TYPE]-[NNN]-[slug].md
📊 Severity/Priority: [level]
📋 Status: in-progress

Next steps:
- Work on the issue
- When resolved, update Solution and close it
```

---

## Issue Auto-Detection

Claude should automatically detect potential issues during the conversation.

### When to suggest

1. **User mentions a bug:**
   - "It doesn't work...", "There is an error...", "I found a problem..."

2. **User suggests an improvement:**
   - "It would be nice if...", "We could improve...", "We should optimize..."

3. **User mentions a check:**
   - "We need to check...", "Let's verify...", "Let's review..."

4. **Claude finds a problem:**
   - Unexpected behavior, test failure, edge case

### Suggestion format

```
🔍 I noticed something that might be an issue:
- Type: [bug/enhancement/review]
- Description: [short]

Do you want me to create an issue? (yes/no)
```

---

## Verification checklist for the user

After Claude runs `/new-issue`, check:

- [ ] Did it verify the structure?
- [ ] Did it ask for type and title (if not provided)?
- [ ] Did it ask for severity/priority?
- [ ] Did it assign the correct ID?
- [ ] Did it ask for the description?
- [ ] Did it create the file?
- [ ] Did it update _INDEX.md?
- [ ] Did it show the final summary?

If something is missing, Claude did not follow the command correctly.
