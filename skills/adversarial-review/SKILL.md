---
name: adversarial-review
description: "Use at TWO moments, always. (1) When you have FINISHED a design / plan and are about to ask the user to approve it (e.g. closing the Design section of an /add-task, before the approval checkpoint) — run an adversarial critic that tries to demolish it FIRST. (2) When you have FINISHED implementing something and are about to declare it done — run a verifier + tester FIRST. Turns thesis into antithesis into synthesis (what survives). Addresses the loop-bug FM4; un-confuted design and un-verified implementation are the reason real bugs accumulate."
---

# Adversarial review — thesis → antithesis → synthesis

The Socratic core of the method: **nothing ships on the first draft.** Two moments, always.

## 1. Design closed → REFUTE before asking for approval

When you have finished writing a Design/plan and are about to ask the user for the OK:

1. Run the **`adversarial-critic`** agent on the design you just wrote (pass it the path of the design log, or the design text + the requirements/constraints).
2. The refuter tries to **tear it apart**: fragile assumptions, scenarios where it fails, what is taken for granted, what is missing. It doesn't rewrite — it attacks.
3. **Incorporate** the critique into the design (update Q&A / Trade-offs / Open questions; fix or defend each point). Thesis (design) → antithesis (refutation) → **synthesis** (a design that holds).
4. **Only now** ask the user for approval — presenting also what the refuter raised and how you resolved it.

> Applies to significant **design** decisions (that is where the decisions live). A trivial fix (<3 files, obvious) doesn't need the round.

## 2. Implementation finished → VERIFY + TEST before declaring it done

When you have finished implementing and are about to say "done" (or before moving it to DONE — ties into R.16):

1. Run the **`verifier`** agent: it checks that what was implemented **really meets the requirements/design**, point by point — not "it compiles = it works".
2. Run the **`tester`** agent: it designs and runs **test scenarios** (including the edge case / the what-if), reads the real output, compares expected vs actual.
3. Report the outcome (what holds / what doesn't) **before** declaring it done. If something doesn't hold → it isn't done: go back and fix it. Remember that "done" = **validated by the user** (R.16), not "implemented".

## Why (FM4)

The endless loop-bug is born from **unverified** implementation + **unconfuted** design + no overseer. This skill puts refutation and verification **upstream**, under the eye of the GUARDIAN (context/objective/principles): so real bugs don't accumulate. The enforcement is **model-level** (this skill forces you every time) — a shell hook could neither launch agents nor judge the quality of a design.
