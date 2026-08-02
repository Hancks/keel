# Stop Coord Command

Closes / finalizes a cross-project coordination plan created with `/startcoord`. It is the **symmetric bookend** of `/startcoord`: it reconciles the task state from the **artifacts** (source of truth), **syncs all the copies** `.plan/<plan_id>.json` in the involved subs in one shot, produces a **closing report**, and **archives** the plan if complete (or on request / with `--cancel`).

## Why it exists (the gap it fills)

`/startsession` updates **only the current sub's copy** opportunistically and auto-archives only when *all* the tasks are `completed`. There was no explicit action to:
- **align ALL the copies** in the subs in one shot (without having to open a session in each),
- **close/abandon** a plan that will NOT reach `completed` via artifact (cancelled/superseded),
- produce a readable **closing picture** (who finished, what remains and whose turn it is) at the end of a coordination push.

`/stopcoord` does NOT invent states: it **deduces them from the artifacts** as `/startsession` does (missing→pending, `Draft`/`Implementing`→in_progress, `Implemented`→completed). The only "manual" state is `--cancel`.

## When to use

- You have finished YOUR part of a cross-project initiative (e.g. the producer finished their tasks) and want to propagate the real state to all the subs + leave a clean handoff to the consumers.
- You want to **abandon** a plan that will no longer happen (`--cancel`).
- You want an on-demand cross-sub status report without running `/startsession` in every sub.

---

## Usage

```
/stopcoord [<plan_id>] [--cancel "<reason>"] [--archive]
```

Examples:
```
/stopcoord                              # if there is a single active plan it uses it; otherwise it asks
/stopcoord mca-v3-content-engine        # explicit plan: reconcile + sync + report (+ archive if complete)
/stopcoord <id> --archive               # force archiving even if not all completed
/stopcoord <id> --cancel "superseded by a new design"   # abandon the plan (archive with a cancelled marker)
```

---

## MANDATORY STEPS

### STEP 0: Preflight

```bash
ls -1 .plan/*.json 2>/dev/null            # active plans in the current sub
ls -1 .locks/session-*.json 2>/dev/null | wc -l   # active session
```

**MANDATORY OUTPUT:**
```
🔧 Preflight:
✅ Active session · pwd = <current sub>
✅ Active plans: <list of plan_id>   (or ⛔ no plan → STOP)
```

If no active plan in the current sub → STOP (nothing to close here).

### STEP 1: Resolve the target plan

- `<plan_id>` passed → use it.
- No arg + **a single** active plan → use it.
- No arg + **N>1** plans → list them and **ask which one** (🛑 checkpoint).

Load `.plan/<plan_id>.json` from the current sub.

**MANDATORY OUTPUT:** `🎯 Plan: <plan_id> — <title> (<N> tasks across <M> subs)`

### STEP 2: Reconcile from artifacts (source of truth)

For EACH task in `tasks[]`:
1. Artifact path = `<task.sub_path>/<task.artifact>`.
2. Read (if it exists) and deduce the `status`:
   - file absent → `pending`
   - header `Status: Draft` / `Status: Implementing` → `in_progress`
   - header `Status: Implemented` → `completed`
3. For `pending` tasks, evaluate the `depends_on`: for each dep, read the dep's artifact in its `sub_path` → satisfied if `Status: Implemented`. All satisfied → **🟢 ready**; otherwise **⏳ blocked** (note which deps are missing).

Update `status` in memory (+ `started_at`/`completed_at` if missing, using `date -u +%Y-%m-%dT%H:%M:%SZ`). **Constraint:** all the `sub_path`s must be reachable via the local filesystem; for unreachable subs, keep the previous state and flag it.

> With `--cancel "<reason>"`: skip the fine deduction, mark the plan `cancelled` (top-level field `cancelled: {reason, at, by_uid}`) and the non-`completed` tasks as `cancelled`.

**MANDATORY OUTPUT:**
```
🔄 Reconcile from artifacts:
✅ completed: <ids> · 🔄 in_progress: <ids> · 🟢 ready: <ids> · ⏳ blocked: <ids (deps)>
[unreachable subs: <list> — state unchanged]
```

### STEP 3: Sync ALL the copies

Write the reconciled JSON to **every** reachable `<sub_path>/.plan/<plan_id>.json` (`mkdir -p .plan` best-effort). All the copies become identical and authoritative. Do **NOT** commit (the user decides that).

**MANDATORY OUTPUT:**
```
💾 Sync copies:
✅ <sub_path_1>/.plan/<plan_id>.json … (✅/❌ per sub)
```

### STEP 4: Archive (conditional)

- All tasks `completed`, **or** `--archive`, **or** `--cancel` → move `.plan/<plan_id>.json` → `.plan/archived/<plan_id>.json` in every reachable sub.
- Otherwise → leave the plan **active** with the reconciled state (the consumers keep seeing it).

**MANDATORY OUTPUT:** `📦 Archive: [archived in <N> subs | not archived — <K> tasks still open]`

### STEP 5: Closing report + handoff

**MANDATORY OUTPUT:**
```
✅ STOPCOORD — <plan_id>

📊 Final state:
  ✅ <id>: <title> (sub) — completed
  🔄 <id>: in_progress
  🟢 <id>: ready — next: cd <sub_path> and open Claude (or /startsession there flags it)
  ⏳ <id>: blocked by <dep ids> (sub)

🤝 Handoff: <who has to move now and where> (e.g. "PianoTutor: pt-consume 🟢 ready").
🗒️  If you leave instructions for a sub, write them in its inbox: `<sub>/.plan/inbox/YYYY-MM-DD-from-<origin>.md` (convention — its `/startsession` flags them). NOT in `design-log/`.
📦 Plan: [active with updated state | archived | cancelled: <reason>]

NOTE: no automatic commit — you commit the updated `.plan/` copies yourself.
```

---

## Operational notes

- **No invented states**: `/stopcoord` deduces from the artifacts (like `/startsession`). The only exception is `--cancel`, which is an explicit user decision.
- **Idempotent**: re-running it reconciles again; if in the meantime an artifact moved to `Implemented`, the state advances.
- **Difference from `/startsession`**: this aligns **all** the cross-sub copies in one shot + closes/abandons + reports; `/startsession` syncs only the current sub and auto-archives only on total completion.
- **Non-destructive**: the archive *moves* the JSON to `.plan/archived/`, it does not delete it. The artifacts (the truth) remain.

---

## Verification checklist for the user

- [ ] Preflight (session + active plan) shown?
- [ ] Target plan resolved (asked if ambiguous)?
- [ ] Reconcile from the artifacts (no invented states)?
- [ ] Sync of ALL the copies in the reachable subs?
- [ ] Archive only if complete / `--archive` / `--cancel`?
- [ ] Closing report with ready/blocked + handoff?
- [ ] NO automatic commit?
