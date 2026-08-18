# bug-hunt-method — The bug-hunt methodology (keel)

> Canonical source of the methodology. Cited by `commands/bug-hunt.md` and `agents/bug-finder.md` (single source, not duplicated in the prompts).
> Two parts: **(A) 5 canonical lenses** (pattern-based) · **(B) functional-flow lenses** via the **expected-result method**.

---

## A) The 5 canonical lenses

Always offered. Each is a **way of looking** at the code for one family of defects:

1. **correctness** — does the logic really do what it promises? (inverted branches, wrong conditions, partial merge of results)
2. **robustness** — does it hold up under errors, edge cases, interruptions? (fail halfway, network down, empty/huge/malformed input, constant-value-that-changes, off-by-one, null/undefined, division by zero)
3. **security** — what's exposed, what can be forged? (unvalidated input, injection, secrets in plaintext, unsafe deserialization, path traversal, SSRF)
4. **permissions** — who can use what, and in the right context? (missing/bypassable authz, multi-tenant/user isolation, IDOR)
5. **data** — coherent and atomic writes? (loss/corruption, non-atomicity, state **derived** from a constant that can change instead of **recorded**, destructive migrations, races)

### Optional extras (non-bug — validated, not refuted)
- **dead-code** — functions/branches never reached (search for uses with Grep before declaring it dead).
- **efficiency** — **material** redundant work (hot path), not micro-optimizations.
- **requirements** — where the code violates an explicit requirements source.

---

## B) Functional-flow lenses — the expected-result method

The 5 lenses catch **known** families. The real **correctness** of a feature, though, is hunted better **by test**: take a functional flow and verify the code produces the behavior the requirements demand. Each **functional flow** becomes a lens of its own.

### A test's path
```
object        →  what you test (function / feature / technical aspect)
preconditions →  the state and input needed for the test to make sense
sequence      →  the steps to run, in order
EXPECTED      →  the result the functional requirements demand   ← derived from INTENT
OBTAINED      →  what the real code actually produces
```
**Bug rule:** `EXPECTED ≠ OBTAINED ⇒ BUG`. If you know/understand the functional spec you can derive the **expected**; you read the **obtained** from the code; the comparison reveals the defect.

### Where the flows come from (3 combined sources)
1. **Reading the design logs** (`design-log/*.md`, `PROJECT.md` NORTH_STAR, README, spec) — primary source of intent.
2. **From the code** — to reconstruct intent (names, types, contracts, comments, sibling code) **and** to read the obtained.
3. **Confirmation/integration with questions to the user** — the agent proposes the derived flows; the user confirms / integrates / cuts.

### Anchoring the expected (the rule that avoids the tautology)
The **expected** comes from **intent** (design-log / spec / user), **not** from the current behavior of the implementation under test. If you take what the code does *today* **as** the expected, you're certifying the bug as correct: the test proves itself right (fixture built on the code's own assumption).
- The code tells you *what it's meant to do* (intent) and *what it actually does* (obtained) — never to **define** the expected.
- When the expected rests **only** on an assumption derived from the code (no design-log/spec/user backing it) → **mark it "assumed, unverified"** in the report. A "clean" run does not prove the code is correct: it only proves it holds against the expecteds we managed to anchor.

---

## Operational notes
- **"Light"**: a few strong finders (Opus, one per lens/flow) + cheap refuters/validators (Fable, one per finding). Not hundreds of agents: cap the flows + narrow the scope.
- **Honest limit**: the hunt finds bugs with a **symptom readable now**. The class "a choice correct today that arms a trap tomorrow" (no current symptom) is blind to it — that lives in refutation-at-design-time (skill `adversarial-review`).
- **R.16**: the hunt **finds**; fixes are separate tasks. Nothing goes to DONE just because the hunt ran.
