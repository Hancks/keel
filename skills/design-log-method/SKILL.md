---
name: design-log-method
description: Use when the user asks to implement, build, add, change, or fix something non-trivial (touches ~3+ files, is a new feature, or involves an architectural decision), OR when the user asks to capture a quick note (a "note"/"segna" verb). Ensures significant work never bypasses the Design-Log process, even as sessions grow long.
---

# Design-Log method — recognition and routing

When you recognize a **significant task** (≥3 files, a new feature, an architectural decision):
- Do NOT start implementing directly. **Propose `/add-task`**: "This task needs /add-task. Shall I run it?" — it is the forcing mechanism (design-log + Q&A + approval, BEHAVIORS R.2).
- Trivial task (<3 files, obvious fix) → proceed.

When the user asks to **capture something** (a "note"/"segna" verb): the capture into `INBOX.md` is already done by the `UserPromptSubmit` hook; just check that it happened and treat it as **to triage**, not as "to do right now".

This skill counters **FM8**: as the session grows the `/add-task` proposal tends to decay. Recognizing the significant task is model-level and **must not decay**: it re-activates on every relevant request.
