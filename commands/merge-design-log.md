# Merge Design-Log Command

Merges a branch into the target (default `main`), handling the shared design-log files correctly to avoid noisy conflicts and lost entries.

## When to use

When you developed a feature/release on a separate branch that modified:
- `design-log/PROGRESS.md`
- `design-log/LEARNED.md`
- `design-log/issues/_INDEX.md`
- (possibly) `design-log/BEHAVIORS.md`, `PROJECT.md`, `METHODOLOGY.md`

And now you want to merge that branch into the target without:
- "Dumb" merge conflicts on the sectioned files
- Loss of DONE/TODO/Pattern/Mistakes entries
- Permanent pollution of the source branch's history (which stays alive for other bugfixes until the release)

---

## Usage

```
/merge-design-log <source-branch> [--into <target>]
/merge-design-log --resume <source-branch>
```

Examples:
```
/merge-design-log release-2.x
/merge-design-log feature/login --into develop
/merge-design-log release-2.x --resume          # resume after real conflicts
```

Default `--into`: `main`.

---

## What it does (mental model)

1. On the source: move the sectioned files into `design-log/branches/<source>/` and commit "isolate"
2. Checkout the target → `git merge <source>` (brings the "isolate" commit + all the feature commits onto the target, no conflict on the isolated files)
3. On the target: merge the entries from `branches/<source>/...` into the main files (sync-from-branch), commit "sync"
4. On the source: `git reset --hard <pre-isolate-sha>` → the "isolate" commit disappears, files back at their original paths, clean ex-ante history

Result:
- **Source branch**: ex-ante (files at their original paths, no plumbing commit)
- **Target branch**: explicit merge history + the `branches/<source>/` folder as a permanent archive

---

## MANDATORY STEPS

### STEP 0: Preflight

Check the preconditions.

```bash
git status --short
git rev-parse --verify <source-branch>
git rev-parse --verify <target-branch>
git rev-parse <source-branch>   # store pre-isolate-sha
```

**MANDATORY OUTPUT:**
```
🔧 Preflight:
✅ Working tree clean
✅ Source branch <source> exists
✅ Target branch <target> exists
🔖 Pre-isolate SHA: <abbrev>
```

If the working tree is NOT clean → STOP, ask the user to commit/stash before re-running.

---

### STEP 1: Detect the files to isolate

The command ALWAYS isolates: `PROGRESS.md`, `LEARNED.md`, `issues/_INDEX.md`.

It isolates CONDITIONALLY (if modified on <source> relative to <target>): `BEHAVIORS.md`, `PROJECT.md`, `METHODOLOGY.md`.

Detect via:
```bash
git diff --name-only <target>...<source> -- design-log/BEHAVIORS.md design-log/PROJECT.md design-log/METHODOLOGY.md
```

**MANDATORY OUTPUT:**
```
📋 Files to isolate:
  Always:
  ✅ design-log/PROGRESS.md
  ✅ design-log/LEARNED.md
  ✅ design-log/issues/_INDEX.md
  Conditional (modified on <source>):
  ✅ design-log/PROJECT.md (yes) | ⏭️ (no)
  ✅ design-log/BEHAVIORS.md (yes) | ⏭️ (no)
  ✅ design-log/METHODOLOGY.md (yes) | ⏭️ (no)
```

---

### STEP 2: Detect a `branches/<source>/` collision

If `design-log/branches/<source>/` already exists on <target> (e.g. from a previous merge with the same branch name recreated) → use a timestamp suffix.

```bash
git ls-tree --name-only <target> design-log/branches/ | grep -x "design-log/branches/<source>"
```

**MANDATORY OUTPUT:**
```
📂 Archive destination:
✅ design-log/branches/<source>/
  or
⚠️ design-log/branches/<source>/ already exists on <target> → using design-log/branches/<source>-YYYY-MM-DD-HH-MM/
```

Store `BRANCH_DEST` (the effective path).

---

### STEP 3: Pre-merge isolation (on the source)

On the source branch:
1. Copy the branch files into `<BRANCH_DEST>/...` (preserve the branch version as an archive)
2. Overwrite the files in their original position with the target's version (`git checkout <target> -- <file>`). This prevents the `git merge` from deleting/replacing the target's files — at merge time, the target already has its version and `<BRANCH_DEST>/` is only an addition.
3. Commit "isolate"

```bash
git checkout <source>
mkdir -p <BRANCH_DEST>
mkdir -p <BRANCH_DEST>/issues

# 1) Copy the branch version into the archive (not git mv: the file also stays in its original position)
cp design-log/PROGRESS.md <BRANCH_DEST>/PROGRESS.md
cp design-log/LEARNED.md <BRANCH_DEST>/LEARNED.md
cp design-log/issues/_INDEX.md <BRANCH_DEST>/issues/_INDEX.md
git add <BRANCH_DEST>/PROGRESS.md <BRANCH_DEST>/LEARNED.md <BRANCH_DEST>/issues/_INDEX.md

# Conditional (only if identified at STEP 1)
cp design-log/BEHAVIORS.md <BRANCH_DEST>/BEHAVIORS.md
cp design-log/PROJECT.md <BRANCH_DEST>/PROJECT.md
cp design-log/METHODOLOGY.md <BRANCH_DEST>/METHODOLOGY.md
git add <BRANCH_DEST>/BEHAVIORS.md <BRANCH_DEST>/PROJECT.md <BRANCH_DEST>/METHODOLOGY.md

# 2) Overwrite the files in their original position with the target's version
#    (so the merge is clean: the target has its versions, the source has the same + the new archive)
git checkout <target> -- design-log/PROGRESS.md design-log/LEARNED.md design-log/issues/_INDEX.md
# Conditional (only if identified at STEP 1)
git checkout <target> -- design-log/BEHAVIORS.md design-log/PROJECT.md design-log/METHODOLOGY.md

# 3) Commit
git commit -m "isolate design-log for merge into <target>"
```

**Why `cp` + `git checkout target --` instead of `git mv`?**
With `git mv`, the merge brings the post-isolate state (files MOVED) onto the target, making the target's files disappear from their original position. With the "copy + overwrite" strategy: after the isolate, on <source> the files in their original position are equal to the target's → the merge applies only the addition of `<BRANCH_DEST>/` (zero changes to the target's files in their original position).

**MANDATORY OUTPUT:**
```
🔀 Isolation completed:
✅ Copied N files into <BRANCH_DEST>/
✅ Files in original position replaced with the <target> version
✅ Commit "isolate design-log for merge into <target>"
🔖 Isolate SHA: <abbrev>
```

---

### STEP 4: Merge onto the target

```bash
git checkout <target>
git merge <source>
```

**MANDATORY OUTPUT (success case):**
```
🤝 Merge done:
✅ git merge <source> → <target>
✅ Merge commit: <abbrev>
```

**REAL CONFLICTS case** (on application files, not design-log):
```
⛔ REAL CONFLICTS detected on:
  - <file1>
  - <file2>
  ...

Resolve manually, then:
  git add <file1> <file2>
  git commit
  /merge-design-log --resume <source>

(The sync-from-branch will run after the resolution.)
```
STOP — do not proceed further. Wait for the re-run with `--resume`.

---

### STEP 5: Sync-from-branch (on the target)

For each file in `<BRANCH_DEST>/` apply the correct logic.

#### 5a: PROGRESS.md (entry-based)

For the `## ✅ DONE` section:
- Extract all the entries from the branch file. Header pattern: `### YYYY-MM-DD - <Title>`.
- For each entry, look for an exact match on `### YYYY-MM-DD - <Title>` in the target.
- If NOT present → insert into the target keeping reverse chronological order (most recent at the top under `## ✅ DONE`).

For the `## 📋 TODO` section (subsections 🔴/🟡/🟢):
- Pattern: `#### <Title>` or `#### ~~<Title>~~ ✅ DONE`.
- For each branch TODO, look for a match on `#### <Title>` (ignoring ~~) in the target.
- If NOT present → append at the bottom of the same priority subsection.

Update in the target:
- `> Last updated:` to the most recent of branch and target
- `> Last session:` to the most recent of branch and target

#### 5b: LEARNED.md (line-based)

Sections: `## Technical Patterns`, `## Mistakes Not to Repeat`, `## User Preferences`, `## Reusable Solutions`.

For each section:
- Entry pattern: a line starting with `- **<key>**: <body>`
- For each branch line, exact match in the target.
- If NOT present → append at the bottom of the same section, preceded on the first append by:
  ```
  <!-- merged from branch <source> on YYYY-MM-DD -->
  ```

Update `> Last updated:` to the most recent.

#### 5c: _INDEX.md (full rebuild)

Scan `design-log/issues/*.md` (excluding `_INDEX.md`).
For each file read: type, severity/priority, status, created, title.
Rebuild the tables `## 🐛 Bugs`, `## ✨ Enhancements`, `## 👀 Reviews` + the `## Quick Stats` section + `## Recent Activity`.

#### 5d: BEHAVIORS / PROJECT / METHODOLOGY (manual warning)

If isolated at STEP 1 → do NOT apply an automatic merge. Leave the target's file intact and flag it:

```
⚠️ <file> modified on the branch but NOT auto-merged.
   Branch version in: <BRANCH_DEST>/<file>
   Manual merge required. Open the file and integrate it by hand.
```

#### 5e: Commit the sync

```bash
git add design-log/PROGRESS.md design-log/LEARNED.md design-log/issues/_INDEX.md
git commit -m "sync design-log entries from branch <source>"
```

**MANDATORY OUTPUT:**
```
🔄 Sync-from-branch completed:
✅ PROGRESS.md: N DONE entries added, M TODOs added
✅ LEARNED.md: K lines added (with a marker)
✅ issues/_INDEX.md: rebuilt from issues/ (X issues indexed)
⚠️ J files with a manual merge required (see above)
✅ Commit "sync design-log entries from branch <source>"
🔖 Sync SHA: <abbrev>
```

---

### 🛑 STEP 6: WARNING + reset of the source

Show the warning BEFORE proceeding with the reset.

**MANDATORY OUTPUT:**
```
🛑 SOURCE RESET — CONFIRMATION REQUIRED

I am about to reset <source> to <pre-isolate-sha> (removing "isolate" from the history).
This brings the files back to their original paths (ex-ante) and keeps the source's history clean.

⚠️ WARNING: if <source> is already pushed to the remote, after the reset you will need:
   git push --force origin <source>

If multiple people work on the same branch, the force-push requires coordination.

Proceed with the reset? (yes/no)
- yes → reset + return to the target
- no  → done: the "isolate" commit stays in <source>'s history ("noisy" variant)
```

**Do NOT proceed until the user confirms.**

On CONFIRMATION:
```bash
git checkout <source>
git reset --hard <pre-isolate-sha>
git checkout <target>
```

**OUTPUT (after reset):**
```
🔁 Source reset completed:
✅ <source> now at <pre-isolate-sha> (ex-ante)
✅ Back to <target>

⚠️ Remember: if <source> was pushed, run:
   git push --force origin <source>
```

On REFUSAL:
```bash
git checkout <target>
```

**OUTPUT:**
```
⏭️  Reset skipped. <source> keeps the "isolate" commit in its history.
✅ Back to <target>
```

---

### STEP 7: Final summary

**MANDATORY OUTPUT:**
```
✅ MERGE-DESIGN-LOG COMPLETED

📂 Source: <source>
📂 Target: <target>
📁 Permanent archive: <BRANCH_DEST>/

🔄 Automatic sync:
- PROGRESS.md: N DONE + M TODOs added
- LEARNED.md: K lines added
- issues/_INDEX.md: rebuilt from X issues

⚠️ Manual merge required on:
- <file1> (see <BRANCH_DEST>/<file1>)
- ...

🌿 Source after merge:
  ✅ ex-ante (reset)
  or
  ⏭️ "isolate" commit kept

Next steps:
- Check the files with a manual merge (if any)
- (If source was pushed and reset) git push --force origin <source>
- (If needed) push the target: git push origin <target>
```

---

## --resume mode

When the automatic merge (STEP 4) finds real conflicts on application files:

1. The command stops at STEP 4 with instructions
2. The user resolves the conflicts, does `git add` and `git commit`
3. The user runs `/merge-design-log --resume <source>`

`--resume` skips STEP 0-4 (assumes you are already on <target> with the merge committed) and restarts from STEP 5 (sync-from-branch).

**Pre-resume checks**:
```bash
git status --short                                # must be clean (post merge commit)
git rev-parse --abbrev-ref HEAD                   # must be <target>
ls design-log/branches/<source>/                  # must exist (left by the isolation)
```

If one of the checks fails → STOP + diagnosis.

---

## Verification checklist for the user

After Claude runs `/merge-design-log`, check:

- [ ] Did it show the preflight (working tree clean, branches existing, pre-isolate SHA)?
- [ ] Did it show the list of files to isolate (always + conditional)?
- [ ] Did it handle any `branches/<source>/` collision with a timestamp suffix?
- [ ] Did it do the isolation with `cp` + `git checkout <target> --` (NOT `git mv`) and the "isolate" commit?
- [ ] Did it run `git merge` onto the target (and, on real conflicts, STOP with resume instructions)?
- [ ] Did it run the automatic sync-from-branch for PROGRESS, LEARNED, _INDEX?
- [ ] Did it flag (with a WARNING) the files with a manual merge required (BEHAVIORS/PROJECT/METHODOLOGY)?
- [ ] Did it commit the sync on the target?
- [ ] Did it show a WARNING + ask for confirmation BEFORE resetting the source?
- [ ] (If confirmed) Did it reset the source + remind that `git push --force` is needed if the branch was pushed?
- [ ] Did it show a final summary with the archive + next steps?

If something is missing, Claude did not follow the command correctly.
