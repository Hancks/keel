---
name: methodical-debugging
description: "Use when something is BROKEN or not behaving as expected — a bug, a failed test, a crash, a wrong output, 'it doesn't work' — BEFORE proposing or trying any fix. Forces the systematic protocol (instrument/observe the real flow, design tests/scenarios, run and READ the real output, diff expected vs actual, only then hypothesize and fix) instead of blind trial-and-error, writes an auditable Debug-log (expected vs actual), and after repeated failed fixes stops to consult the project LEARNED and question the architecture. This is the method's own debugging discipline (self-contained), tied to the project principi/GUARDIAN — not a generic reminder."
---

# Methodical debugging — not by trial and error (FM5)

> The moment when you actively **apply** the cardinal debugging principle (`principi/software.md`, re-injected by the GUARDIAN). The principle is the *what*; this skill is the *do it now, in this order, and leave a trace*.

**Iron law:** don't change code to "try something" until you have **seen** where the real flow diverges from the expected one. A fix before observation is blind trial-and-error — the anti-pattern that breeds loop-bugs (FM4/FM5).

## When it triggers
On a **bug / failed test / crash / wrong output / "it doesn't work" / unexpected behavior**, **before** proposing or trying any fix. NOT on a normal iteration (typo, wrong path, obvious tweak-and-rerun): there the ritual isn't needed.

## Boundary with the other skills (don't overlap)
- `adversarial-review` → the **`tester`** agent: verifies that a *finished* implementation meets the requirements ("it compiles ≠ it works"), **before** declaring it done. It sits downstream of work **that seems to have succeeded**.
- **this skill** → steps in when something is **broken** and needs to be **diagnosed**. If a real failure emerges during verify/test → you come **here**.

## The protocol (in this order)

1. **Observe the real flow — with the right instrument** (a conditional step, NOT "turn the logs up" regardless):
   - an instrumentable flow (functions, requests, state) → **turn the logs up to the MAX** at the suspect points;
   - a **performance** problem → profiler/tracing, not logs;
   - **UI/visual** → screenshot/recording of the real state;
   - **config/build** → the tool's real output (build/lint/type-check), read in full;
   - **heisenbug / timing** → an instrument that doesn't alter the timing (counters, low-cost traces);
   - reproducible **only in prod** → capture it there (logs/telemetry), don't fake it locally.
   The goal is to **see reality**, by whatever means shows it.

2. **Design the test / scenarios** that reproduce the failure — including the edge case and the **what-if** (empty/huge/malformed input, a step halfway, network down). Write the **expected** for each one *before* running.

3. **Run and READ the real output** — never "green" from memory. Capture real numbers/errors/logs (redirect to a file and read `$?` immediately if a pipe could mask the outcome).

4. **Compare expected vs actual**, line by line, and **isolate the point** where they diverge. That is where the bug is, not where you imagined it.

5. **Only now** form the hypothesis, apply **one** fix, and **re-run** the test from step 2 to confirm (and that it didn't break anything else).

## Debug-log (MANDATORY — this is what makes the ritual auditable)
Write a trace — in the task's design log or in a `design-log/debug/…` note — that anyone can re-read. At minimum:
```
## Debug-log — <symptom> (<date>)
- Observed with: <log / profiler / screenshot / build-output>
- Expected: <what should have happened>
- Actual: <what actually happens, with evidence: file:line / output / value>
- Divergence point: <where>
- Hypothesis → fix → outcome of the re-check
```
Without this, "protocol followed" and "I fiddled until it passed" are indistinguishable — and the cardinal principle is **"lose nothing: write before acting"** (`core.md`). The trace survives compaction.

## After ~2 failed fixes on the same spot → STOP
Don't keep guessing (it is the fastest way to burn time and trust):
1. **Consult the memory**: search `LEARNED.md` (local) and the `LEARNED_GLOBAL/` domains for a known pattern — often the bug (or a twin of it) is already documented.
2. **Go down a level of abstraction**: turn the logs up further / go one layer below (API → filesystem → raw protocol), with the cheapest means that isolates the variable.
3. **Search outside**: authoritative forums (project/framework issues, Stack Overflow, official docs) — many APIs have undocumented but well-known quirks.
4. **On the 3rd failure**, it is no longer a fix: **question the architecture/the assumption** and talk it over with the user. A cause deduced by elimination **is not proven**: test it with the cheapest means before acting on big solutions.

## Non-software branch (stub — to consolidate)
> Twin of the `principi/non-software.md` stub (still a placeholder): when it is filled in, align here.
For a failure without "logs" (a wrong document, a research pipeline, a non-code output): the core stays **expected vs actual**. **Isolate the variable** (change one thing at a time), **measure** on the real representative data, **compare** with what you expected, and write the same Debug-log.

## Honesty about the enforcement level
This is a **model-level skill**: it *forces* you in the moment, but it is not an environment block. Refutation-at-design-time (FM4) also earned a hard-block (`lock.sh`) because the invariant is script-verifiable; here "did you really follow the protocol?" is not, and the "block after 2 fixes" stays a future idea (a shell hook can't count the fixes on the same spot). A consciously accepted risk — not hidden.
