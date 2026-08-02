---
description: "Explicit \"light\" bug hunt — one finder per lens (Opus) + one refuter/validator per finding (Fable), Workflow engine, report triaged by impact. On-demand."
---

# /bug-hunt — light bug hunt (Design-Log v2 · Phase 2b)

You look for what is **already broken and visible** in the code, on-demand, with the lenses you choose. Engine: a few **strong finders** (Opus, one per lens) + many **cheap refuters/validators** (Fable 5, one per finding). Output: a **report triaged by impact** on file + **item-by-item** triage.

> ⚠️ Honest limit (say it in the report): this hunt only finds bugs with a **symptom readable now**. The class "a choice that's correct today but arms a trap tomorrow" (no current symptom) is **blind** to it — that one lives in **refutation-at-design-time** (skill `adversarial-review`), not here. A clean report does **not** prove the code is clean.

Run by the **top-level** agent (which owns the `Workflow` tool; sub-agents don't). Invoking this command **is** the authorization to use `Workflow`.

---

## STEP 1 — Choose the lenses (menu)

Ask with **AskUserQuestion** (multiSelect) which lenses to enable. Catalog (one or more, including non-bug):

| Lens | Looks for | Mode |
|---|---|---|
| `correctness` | logic that doesn't do what it promises | bug |
| `security` | injection, secrets, unvalidated input, SSRF/path traversal | bug |
| `permissions` | missing/bypassable authz, isolation, IDOR | bug |
| `data` | loss/corruption, non-atomicity, derived-vs-recorded state | bug |
| `robustness` | what-if: fail halfway, network down, empty/huge input, constant-value-that-changes | bug |
| `dead-code` | functions/branches never reached | validation |
| `efficiency` | material redundant work (hot path) | validation |
| `requirements` | where the code violates the requirements source | validation |

If the user passed lenses as arguments (`$ARGUMENTS`), use them and skip the menu.

## STEP 2 — Target (default = current diff → whole files)

Default: the **current changes**. Derive the touched files and pass them **whole** (not just the diff lines — the refuter needs the surrounding context).

```
git rev-parse --is-inside-work-tree 2>/dev/null && \
  git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null
```

Guards (stop and ask BEFORE proceeding):
- **no git** → there's no diff: ask whether to scan a given folder/file or "the whole project".
- **empty diff** (clean branch) → do NOT run the finders on nothing (they'd hallucinate): ask for the target (path or "everything").
- **huge diff** (many files or >~2000 lines) → warn about the time cost and **ask for confirmation** or narrow it down.
- The user can always pass a path in `$ARGUMENTS` or say "everything" → in that case `targetFiles=[]` (whole project) or the given paths.

## STEP 3 — Exposure model + requirements source

Impact triage needs to know **what kind of project this is** (the GUARDIAN may be empty on an external codebase):
1. Read `design-log/PROJECT.md` between the `NORTH_STAR:START`/`NORTH_STAR:END` markers. If present, infer the exposure from it.
2. Otherwise **ask** (AskUserQuestion): `user-facing service` / `library-or-API` / `CLI` / `internal`. This maps impact (for a library "breaks the public API / the consumer"; for a service "a user hits it in the flow"; for a CLI "the user loses data / the command fails").
3. If `requirements` is among the lenses: find a **requirements source** (NORTH_STAR / a spec file / the user's text). If none exists → **disable** the `requirements` lens with a warning (don't invent requirements).

## STEP 4 — Engine: verify then launch

1. **Verify** that the `Workflow` tool is available in this session.
2. **If yes** → launch it with the bundled workflow:
   ```
   Workflow({
     scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/bug-hunt.js",
     args: { lenses, targetFiles, targetLabel, exposureModel, requirementsSource, maxPerLens: 12 }
   })
   ```
   (Opus finder per lens → dedup by file:lines → Fable effort-high refuter/validator per finding → counts. Resumes from a rate-limit with `resumeFromRunId` if needed.)
3. **If `Workflow` is NOT available** (gated/absent) → **fallback**: orchestrate the same pipeline yourself at the top level with the `Agent` tool (one `bug-finder` per lens in parallel → dedup → one `bug-refuter` per finding). ⚠️ State in the report that **without `Workflow` there's no resume from a rate-limit** (a long interrupted hunt has to be redone).

Don't let the finders spawn sub-agents (they can't): the fan-out is done by **you**.

## STEP 5 — Report on file (BEFORE the interactive triage)

As soon as the engine returns, **write the report immediately** — so nothing is lost at compaction (FM2):
- Path: `design-log/bug-hunt/YYYY-MM-DD-HH-MM.md` (get date/time with `date +%Y-%m-%d-%H-%M`; create the folder if missing).
- Content: header (target, lenses, exposure, counts raw→dedup→confirmed/rejected); the **confirmed grouped by impact** `A → B-public → B-technical → C`, each with `file:lines · scenario · refuter's evidence`; a **rejected** section (with the why); the false-negative **disclaimer** + "the trap-without-symptom is out of scope (it lives in `adversarial-review`)"; a final **"in one line"**.

## STEP 6 — Item-by-item triage (Q4)

No automatic writes to the tracking. Present the **confirmed** ones one by one (highest impact first) and for each propose the destination; the user confirms:
- **real bug** → `design-log/TO_FIX.md` (with severity from the impact);
- **non-bug / improvement / idea** → `design-log/INBOX.md` (raw capture, R.15);
- **false/irrelevant** → 🗑 (dropped with a why).

Write to the tracking **only** what the user confirms. At the end: a short summary (how many in TO_FIX / INBOX / trash) + a link to the report file.

---

## Notes
- **Cost/scale ("light")**: light = do **NOT** launch hundreds of agents. **Opus** finders (one per lens, few) + **Fable** refuters (one per finding, cap `maxPerLens: 12`) + **limited scope** (hot paths, not "the whole project" on large codebases). Many lenses × whole-project = a bloodbath: **narrow the target** and warn about the cost first.
- **R.16**: the hunt finds; the fixes are separate tasks. Nothing goes to DONE just because the hunt ran.
