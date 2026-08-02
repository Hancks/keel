## 🛠️ Principles — Tier 2a: SOFTWARE projects

- **Systematic debugging (not by trial and error).** If something doesn't work: turn the logs up to the MAX → design tests → design scenarios → run → verify the flow by reading the logs → analyze the differences between expected and actual. No blind trial-and-error.
- **Development with goal verification.** Every implementation is paired with a verification that checks it really does what's needed — not just that it "compiles". "It compiles ≠ it works": trace the flows.
- **Test planning (light).** Before/alongside the implementation, define the few tests that prove the behavior. A light version of test-driven: a few tests that matter, not total coverage.
- **Model and test validation.** Data/models are validated on **real representative** input; integration fixtures are **captured from the real service**, not written from the code's assumption (a test that proves itself right proves nothing).
- **Refutation of assumptions at design time.** Every significant design goes through a refuter that tries to **dismantle its assumptions** before implementing (this is where loop-bugs are born: prevent them upstream).
