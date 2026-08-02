# Start Coord Command

Creates a cross-project coordination plan: a DAG of tasks distributed across N sub-projects that use the design-log system. Writes `.plan/<plan_id>.json` in all the involved subs.

## When to use

You are in an active Claude session (post `/startsession`) in some sub (e.g. `api/`). While working, you realize the current task extends to other subs (e.g. "to do this endpoint I first need a change in core, then here, then UI"). From this session you run `/startcoord` to formalize the plan, leveraging the context already loaded.

From that moment, every `/startsession` in an involved sub is plan-aware: it tells you "it's your turn", "wait for X to finish", "✅ already completed".

You do NOT need a pre-dedicated orchestrator. The current sub is the plan's "originator" (the authority to write into the siblings), but post-creation all the copies are peers. Task completion is auto-detected from the artifact (`Status: Implemented` in the design log).

---

## Usage

```
/startcoord [<plan_id>] [--from <path/to/template.json>]
```

Examples:
```
/startcoord                              # Claude proposes a plan_id and starts interactive
/startcoord monorepo-2026-q2             # explicit plan_id + interactive
/startcoord --from ~/plans/q2.json       # load from template, skip Q&A
```

---

## Plan JSON schema

```json
{
  "plan_id": "monorepo-2026-q2",
  "title": "Q2 monorepo migration: DB → API → UI",
  "created_at": "2026-05-07T20:00:00Z",
  "originator_host": "macbook-enzo",
  "originator_uid": "C716DC80-...",
  "originator_sub_path": "/Users/enzo/repos/api",
  "tasks": [
    {
      "id": "core-1",
      "sub_path": "/Users/enzo/repos/core",
      "title": "Migrate DB schema to v2",
      "status": "pending",
      "artifact": "design-log/2026-05-07-db-migration.md",
      "depends_on": [],
      "started_at": null,
      "completed_at": null
    }
  ]
}
```

Notes:
- `sub_path` = **absolute** filesystem path
- `artifact` = path **relative** to the `sub_path` (= a Git-friendly path)
- `depends_on` = list of other tasks' `id`s
- `status` ∈ {pending, in_progress, completed}, transition automatic via artifact (`/startsession` reads the design log and looks for `Status: Implemented`)

---

## MANDATORY STEPS

### STEP 0: Preflight

Check the preconditions.

```bash
# Active session (presence of a .locks/ marker)
ls -1 .locks/session-*.json 2>/dev/null | wc -l
```

**MANDATORY OUTPUT:**
```
🔧 Preflight:
✅ Active session (marker .locks/session-{uid}.json present)
✅ pwd = <current sub> = <absolute path>
```

If NO marker → STOP, ask the user to run `/startsession` first.

---

### STEP 1: Choose the mode

Determine the mode based on the arguments.

**MANDATORY OUTPUT:**
```
🎯 Mode: [INTERACTIVE | FROM-FILE]
🆔 Plan ID: [<plan_id> | to be decided via Q&A]
```

If `--from <path>` → STEP 4 (validation), skip Q&A.
Otherwise → STEP 2 (interactive Q&A).

---

### STEP 2: Interactive Q&A

Leverage the current session's context to make smart proposals. For each question, show a proposal based on the context and let the user confirm/modify.

**MANDATORY OUTPUT (example):**
```
❓ Questions to build the plan:

Q1: Plan ID
Proposal: monorepo-2026-q2 (based on the session context)
Confirm or want to change it?

Q2: Descriptive plan title
Proposal: "Q2 monorepo migration: DB → API → UI"
Confirm or want to change it?

Q3: How many sub-projects involved? (including the current one)
[Waiting for the answer]

Q4 (for each sub): absolute path + task title + artifact (design log path) + depends_on
Example for the current sub (proposal based on the active session):
  - sub_path: /Users/enzo/repos/api (← pwd)
  - task title: <deduced from the current design log/task>
  - artifact: <deduced>
  - depends_on: <empty or deduced>

For the other subs, ask the user one at a time.
```

**🛑 CHECKPOINT** after each group of questions: wait for the answer before continuing.

At the end, build the JSON structure in memory.

---

### STEP 3: (interactive only) Build the JSON

After the answers, assemble the JSON with:
- `plan_id`, `title`, `created_at` (ISO 8601 UTC), `originator_host` (`hostname`), `originator_uid` (from the marker), `originator_sub_path` (= absolute pwd)
- `tasks[]` as per Q4

**MANDATORY OUTPUT:**
```
🧱 Plan built:
✅ plan_id: <id>
✅ tasks: <N> total across <M> subs
```

---

### STEP 4: Validation

Verify:

1. **Sub paths exist and use design-log**:
   - For each `sub_path`: `[ -d <sub_path>/design-log ]`
   - If one or more sub_paths are invalid → STOP + list of errors

2. **DAG with no cycles**:
   - Topological sort on the `depends_on`
   - If a cycle is detected → STOP + list of cycles

3. **All the `id`s in `depends_on` exist**:
   - For each `dep_id` in each `depends_on`: look for a match in `tasks[].id`
   - If missing → STOP + list of missing ones

4. **Plan ID does not collide**:
   - For each `sub_path`: verify that `<sub_path>/.plan/<plan_id>.json` does NOT already exist
   - If a collision → ask the user: overwrite (Y/N) or change the plan_id

**MANDATORY OUTPUT:**
```
🔍 Validation:
✅ All the sub_paths exist and have design-log/
✅ Acyclic DAG (topological order: <list>)
✅ All the depends_on resolved
✅ Plan ID available in all the subs
```

---

### STEP 5: Preview + Confirm

Show the final JSON to the user for explicit confirmation.

**MANDATORY OUTPUT:**
```
📄 Preview of the plan to write:

<formatted indented JSON>

It will be written to:
- <sub_path_1>/.plan/<plan_id>.json
- <sub_path_2>/.plan/<plan_id>.json
- ...

🛑 Confirm the write? (yes/no)
```

**Do NOT proceed until the user confirms.**

---

### STEP 6: Write

For each `sub_path`:
1. Create `<sub_path>/.plan/` if it doesn't exist (`mkdir -p`)
2. Write `<sub_path>/.plan/<plan_id>.json` with the JSON content

Do **NOT** commit automatically. The user will decide what to commit and when.

**MANDATORY OUTPUT:**
```
💾 Write:
✅ <sub_path_1>/.plan/<plan_id>.json (mkdir + write)
✅ <sub_path_2>/.plan/<plan_id>.json (mkdir + write)
...
```

If one or more writes fail (e.g. permissions, disk full) → clearly flag which subs are ok and which are not, and suggest recovery (`/startcoord --from <saved copy>`).

---

### STEP 7: Final summary

**MANDATORY OUTPUT:**
```
✅ PLAN CREATED

📋 Plan ID: <plan_id>
📝 Title: <title>
📂 Originator: <pwd>
🌐 Subs involved: <N>

📊 Ready tasks (no pending dependencies):
🟢 <id_a>: <title> (sub: <sub_path_a>)
🟢 <id_b>: <title> (sub: <sub_path_b>)

⏳ Tasks with dependencies (waiting):
- <id_c>: depends on <id_a>, <id_b>
- ...

🎯 Suggested next steps:
- To work on <id_a>: cd <sub_path_a> and open Claude
- Or stay here if you have a task in the current sub
```

---

## Operational notes

### Current sub involved vs not

Typically the current sub IS involved in the plan (the user is working there and had the cross-project idea). But it is permissible to create a plan that does NOT include the current sub (e.g. "I launch the initiative from here but then I won't work on it"). In that case, the current sub does NOT receive `.plan/<plan_id>.json` (unless the user includes it explicitly).

### `--from` mode

When using `--from <path>`, the JSON file must have the correct schema. The command skips STEP 2-3, does only STEP 4 (validation) + STEP 5 (preview) + STEP 6 (write).

### Handoff via `.plan/inbox/` (2026-06-07 convention)

If while creating the plan you want to leave instructions for a sub (e.g. "as soon as I unblock, here is what you consume"), write them as a `.md` note in the **recipient's inbox**: `<recipient-sub>/.plan/inbox/YYYY-MM-DD-from-<origin-sub>.md`. NOT in `design-log/`. The recipient's `/startsession` lists and flags them (STEP 3.5f). See METHODOLOGY "Handoff inbox".

### No accessory commands

The minimal version provides only `/startcoord`. No `/coord-list`, `/coord-status`, `/coord-done`, `/coord-cancel`. A task's status is checked by reading the artifact (design log) — the single source of truth. Any reporting commands will be introduced later (future design log).

### Auto-detection of completion

When a task is completed (artifact with `Status: Implemented`), no explicit command is needed: the next `/startsession` in any involved sub will detect the change by reading the artifact via the filesystem. The copies of the JSON in the subs are opportunistically updated by `/startsession` with the verified statuses.

### Auto-archive

When ALL the tasks of a plan are completed, `/startsession` moves the file to `.plan/archived/<plan_id>.json` (best effort across all the involved subs via the filesystem).

---

## Verification checklist for the user

After Claude runs `/startcoord`, check:

- [ ] Did it do the preflight (active session, pwd)?
- [ ] Did it show the mode (interactive vs from-file)?
- [ ] (Interactive) Did it propose the plan_id, title, and current-sub context based on the active session?
- [ ] (Interactive) Did it stop at a checkpoint for each group of questions?
- [ ] Did it do the validation (sub paths exist, acyclic DAG, deps resolved, no collisions)?
- [ ] Did it show a preview of the JSON and ask for explicit confirmation?
- [ ] Did it write to ALL the involved subs (with best-effort mkdir)?
- [ ] Did it show a summary with ready tasks, waiting tasks, next steps?
- [ ] Did it NOT commit automatically?

If something is missing, Claude did not follow the command correctly.
