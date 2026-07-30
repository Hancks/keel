# Keel

> The problem was never the prompt.

**Keel** keeps a Claude Code agent on course at scale — it inherits memory across sessions and projects, holds the big picture, draws out the real intent behind each task, verifies instead of trusting, and stays traceable even when it runs on its own. Enforced by **hooks** (harness-level) and **skills** (model-level), not by better prompts.

Having the most powerful model no longer sets anyone apart — everyone has it. What sets you apart is the method you govern it with. Keel gives a Claude Code agent what no model carries on its own: the memory of what you decided and why, the direction you're headed, the design each change lives in, the judgment to stop and **ask instead of guess**, and the rule that *"it compiles" is never "it's done."* It keeps work broken into living records — in progress, to do, done, broken — so neither you nor the agent carries the whole weight at once, and the context never collapses. And when the agent runs on its own, for hours, cost, decisions and responsibility stay legible **even with the screen off**.

Not better prompts — a process that holds.

## What's here (Phase 1)
- **GUARDIAN** — re-injects the project's north-star, current objective, and cardinal principles so the agent never loses the thread (at session start, when a new task begins, after a context compaction).
- **Lossless capture** — every "note this" is written down the moment it's said.
- **Hard-blocks** — edits are denied when there's no active session or no declared objective; a turn can't end while a request is left uncaptured.
- **Local dashboard** — a *"where are we"* view (objective / done / left) rendered from the project's own records, served locally, across projects.

## Try it
```
claude --plugin-dir /path/to/keel
```

## Structure
```
.claude-plugin/plugin.json
hooks/hooks.json     # SessionStart · UserPromptSubmit · PreToolUse · PostToolUse · PreCompact · Stop
scripts/             # hook logic + local dashboard generators
skills/              # guardian, task recognition
principi/            # cardinal principles: universal · per project-type · per project
```

> ⚠️ Early / experimental — Phase 1. Starting spark: Yoav Abrahami's design-log idea (Wix Engineering); this goes well beyond it.
