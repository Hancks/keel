#!/usr/bin/env bash
# keel — GUARDIAN + lossless hook logic (Phase 1)
# Bundled plugin script. Robust by construction: hooks must NEVER crash the
# session → no `set -e`; every optional read is guarded; hook entry points exit 0.
#
# Subcommands:
#   guardian-block          Assemble Tier1(core)+Tier2(type)+Tier3(NORTH_STAR)+FOCUS objective -> stdout.
#   hook-sessionstart       SessionStart: print guardian-block to stdout (injected into the context).
#   hook-userpromptsubmit   UserPromptSubmit: capture a "note" verb -> INBOX; re-inject the guardian on /add-task.
#   hook-pretooluse         PreToolUse (Edit|Write): hard-block guards (R.1 · R.17 · FM9 LEARNED).
#   learned-approve         FM9: writes the confirmation marker that UNLOCKS writes to the LEARNED files.
#   learned-approve-clear   FM9: clears the confirmation marker.
#   detect-type             Print software|non-software (from PROJECT.md). [test helper]
#   north-star              Print the NORTH_STAR block extracted from PROJECT.md. [test helper]

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DL="$PROJECT_DIR/design-log"
HOOKLOG="$PROJECT_DIR/.claude-designlog-hooks.log"
# Cross-project global memory: dir resolved from env KEEL_GLOBAL_DIR (default ~/.claude-method).
# Portability: whoever lacks this dir must NOT break — the features that use it bootstrap it
# (subcommand global-bootstrap, called silently at SessionStart) or degrade to local-only if
# it cannot be created.
GLOBAL_DIR="${KEEL_GLOBAL_DIR:-$HOME/.claude-method}"
# Session marker + per-file locks for the current project (used by the orchestrator commands).
LOCKS_DIR="$PROJECT_DIR/.locks"
# FM9: confirmation marker for writing to the LEARNED files (nonce + approved files + expiry).
LEARNED_MARKER="$PROJECT_DIR/.locks/learned-write-approved.json"

if command -v jq >/dev/null 2>&1; then HAS_JQ=1; else HAS_JQ=0; fi

# Observable log: every hook that fires leaves a line (UTC time) → tests check HERE.
# Only in projects served by the method (design-log/ exists): keel is installed at user scope,
# so its hooks also fire in plain directories (e.g. $HOME) — they must leave no trace there.
hooklog() {
  [ -d "$DL" ] || return 0
  printf '[%s] %s\n' "$(date -u +%FT%TZ 2>/dev/null)" "$1" >> "$HOOKLOG" 2>/dev/null || true
}

# Capture verbs (bilingual). Override with KEEL_CAPTURE_VERBS: a '|'-separated list
# (e.g. "segna|annota|remember"), or "off" to disable the hook capture entirely.
KEEL_DEFAULT_CAPTURE_VERBS='segna|appunta|annota|ricorda|memorizza|nota|note|remember|jot|capture|remind'
CAPTURE_VERBS="${KEEL_CAPTURE_VERBS:-$KEEL_DEFAULT_CAPTURE_VERBS}"

project_md() {
  if [ -f "$DL/PROJECT.md" ]; then printf '%s' "$DL/PROJECT.md"
  elif [ -f "$PROJECT_DIR/PROJECT.md" ]; then printf '%s' "$PROJECT_DIR/PROJECT.md"
  fi
}

detect_type() {
  local pm; pm="$(project_md)"
  if [ -n "$pm" ] && grep -qiE 'swift|swiftui|ios|macos|xcode|typescript|javascript|node\.?js|react|next\.?js|astro|python|golang|rust|kotlin|java|c\+\+|backend|frontend|database|sql|bash|shell|cli|npm|cargo|api|framework|build' "$pm" 2>/dev/null; then
    printf 'software'
  else
    printf 'non-software'
  fi
}

north_star() {
  local pm; pm="$(project_md)"
  [ -n "$pm" ] || return 0
  awk '/<!-- NORTH_STAR:START -->/{f=1;next} /<!-- NORTH_STAR:END -->/{f=0} f' "$pm" 2>/dev/null
}

guardian_block() {
  local type; type="$(detect_type)"
  echo "=== 🧭 GUARDIAN — always keep in mind (context · objective · principles) ==="
  echo
  if [ -f "$PLUGIN_ROOT/principi/core.md" ]; then cat "$PLUGIN_ROOT/principi/core.md"; echo; fi
  if [ "$type" = "software" ]; then
    if [ -f "$PLUGIN_ROOT/principi/software.md" ]; then cat "$PLUGIN_ROOT/principi/software.md"; echo; fi
  else
    if [ -f "$PLUGIN_ROOT/principi/non-software.md" ]; then cat "$PLUGIN_ROOT/principi/non-software.md"; echo; fi
  fi
  local ns; ns="$(north_star)"
  if [ -n "$ns" ]; then echo "## 🎯 NORTH_STAR — this project"; echo "$ns"; echo; fi
  if [ -f "$DL/FOCUS.md" ]; then
    local fl; fl="$(grep -m1 -E '^[[:space:]]*- .*🔄' "$DL/FOCUS.md" 2>/dev/null)"
    if [ -n "$fl" ]; then echo "## 🔄 Current objective (FOCUS)"; echo "$fl"; fi
  fi
}

read_prompt() {
  local input; input="$(cat)"
  if [ "$HAS_JQ" -eq 1 ]; then
    printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null
  else
    printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("prompt",""))
except Exception: pass' 2>/dev/null
  fi
}

emit_additional_context() {
  local ctx="$1"
  if [ "$HAS_JQ" -eq 1 ]; then
    jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
  else
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":sys.argv[1]}}))' "$ctx"
  fi
}

cmd_hook_userpromptsubmit() {
  local prompt; prompt="$(read_prompt)"
  local ctx="" seg="no"
  # Bilingual capture trigger: the user can say it in Italian or English.
  # Capture ONLY in projects already served by the method (design-log/ exists). Creating
  # design-log/ here would silently turn any directory (e.g. $HOME) into a keel project and
  # arm the PreToolUse hard-blocks + the Stop-hook backlog scan there. Scaffolding stays
  # explicit (/startsession).
  if [ -d "$DL" ] && [ "$CAPTURE_VERBS" != "off" ] \
     && printf '%s' "$prompt" | grep -qiE "(^|[[:space:]])(${CAPTURE_VERBS})([[:space:]]|:|\$)" 2>/dev/null; then
    seg="yes"
    [ -f "$DL/INBOX.md" ] || printf '# 📥 INBOX — Raw capture (to triage)\n\n## To triage\n\n' > "$DL/INBOX.md"
    # drop the *(empty)* placeholder if present, otherwise it stays next to the captures
    if grep -qE '^[[:space:]]*\*\(empty\)\*[[:space:]]*$' "$DL/INBOX.md" 2>/dev/null; then
      grep -vE '^[[:space:]]*\*\(empty\)\*[[:space:]]*$' "$DL/INBOX.md" > "$DL/INBOX.md.tmp" 2>/dev/null && mv "$DL/INBOX.md.tmp" "$DL/INBOX.md"
    fi
    local today oneline; today="$(date +%Y-%m-%d 2>/dev/null)"; oneline="$(printf '%s' "$prompt" | tr '\n' ' ')"
    printf -- '- [ ] [%s] (capture) %s\n' "$today" "$oneline" >> "$DL/INBOX.md"
    ctx="✅ Capture: the request has ALREADY been written to design-log/INBOX.md by the hook (R.15). Do NOT rewrite it — it is already captured. Treat it ONLY as an item to triage (not to do right now)."
  fi
  # NB: the start-of-task guardian refresh is NOT here anymore (the /add-task slash-command is
  # expanded → the hook never sees the string). The `guardian` skill handles it (model-level)
  # plus the SessionStart / SessionStart-compact hooks.
  local preview; preview="$(printf '%s' "$prompt" | tr '\n' ' ' | cut -c1-70 2>/dev/null)"
  hooklog "UserPromptSubmit (capture=$seg) «${preview}»"
  [ -n "$ctx" ] && emit_additional_context "$ctx"
  exit 0
}

deny() {
  local r="$1"
  hooklog "PreToolUse → DENY ($r)"
  if [ "$HAS_JQ" -eq 1 ]; then
    jq -n --arg r "$r" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  else
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$r"
  fi
  exit 0
}

# FM9 — a write to a LEARNED file is allowed ONLY if a valid (non-expired) confirmation marker
# exists and includes the target file. Fail-safe: on any doubt (marker missing/expired/unreadable,
# python3 absent) → NOT approved → deny.
learned_approved() {
  local target="$1"
  [ -f "$LEARNED_MARKER" ] || return 1
  python3 - "$LEARNED_MARKER" "$target" <<'PY' 2>/dev/null
import json, sys, os, time
try:
    m = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
try:
    if float(m.get("expires_at", 0)) < time.time():
        sys.exit(1)
except Exception:
    sys.exit(1)
def norm(p):
    try: return os.path.realpath(p)
    except Exception: return p
target = norm(sys.argv[2])
files = [norm(f) for f in m.get("files", [])]
sys.exit(0 if target in files else 1)
PY
}

# Writes the FM9 confirmation marker. Call ONLY after the user's explicit OK on the
# classification proposed by the distiller. Default TTL 30 min.
cmd_learned_approve() {
  local ttl=30; local -a files=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --ttl) ttl="${2:-30}"; shift 2 ;;
      *)     files+=("$1"); shift ;;
    esac
  done
  [ "${#files[@]}" -gt 0 ] || { echo "usage: lock.sh learned-approve <file...> [--ttl <min>]" >&2; exit 2; }
  mkdir -p "$PROJECT_DIR/.locks" 2>/dev/null
  python3 - "$LEARNED_MARKER" "$ttl" "${files[@]}" <<'PY'
import json, sys, os, time, uuid
marker = sys.argv[1]; ttl = float(sys.argv[2]); files = [os.path.realpath(f) for f in sys.argv[3:]]
json.dump({"nonce": uuid.uuid4().hex, "files": files,
          "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
          "expires_at": time.time() + ttl * 60}, open(marker, "w"))
PY
  echo "✅ learned-approve: ${#files[@]} file(s) approved for ${ttl} min → $LEARNED_MARKER"
}

cmd_learned_approve_clear() { rm -f "$LEARNED_MARKER" 2>/dev/null; echo "🧹 learned-approve cleared"; }

focus_has_flag() {
  local sid="${1:-}" uid tfocus
  grep -qE '^[[:space:]]*- .*🔄' "$DL/FOCUS.md" 2>/dev/null && return 0
  [ -n "$sid" ] || return 1
  uid="$(cmd_resolve_uid "$sid")"
  [ -n "$uid" ] || return 1
  tfocus="$LOCKS_DIR/session-$uid/work/FOCUS.md"
  [ -f "$tfocus" ] && grep -qE '^[[:space:]]*- .*🔄' "$tfocus" 2>/dev/null
}

cmd_hook_pretooluse() {
  local input fp sid
  input="$(cat)"
  if [ "$HAS_JQ" -eq 1 ]; then
    fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)"
    sid="$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)"
  else
    fp="$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception: pass' 2>/dev/null)"
    sid="$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("session_id",""))
except Exception: pass' 2>/dev/null)"
  fi
  # Enforce ONLY on projects served by the method (design-log/ exists).
  [ -d "$DL" ] || { hooklog "PreToolUse (no design-log) → ALLOW"; exit 0; }
  # (i) R.1 — session marker required.
  if ! ls "$PROJECT_DIR"/.locks/session-*.json >/dev/null 2>&1; then
    deny "Design-Log (R.1): no active session in .locks/. Run /startsession before editing files."
  fi
  # (v) FM9 — writing to the LEARNED files (local + global) allowed ONLY with explicit confirmation.
  case "$fp" in
    */design-log/LEARNED.md|*/LEARNED_GLOBAL/*)
      if ! learned_approved "$fp"; then
        deny "Design-Log (R.14/FM9): write to a LEARNED file blocked without confirmation. Have the distiller (agent learned-distiller) propose the classification, get the user to CONFIRM it, then unlock with: lock.sh learned-approve \"$fp\". When in doubt, memory is NOT written."
      fi
      hooklog "PreToolUse ${fp##*/} (LEARNED, confirmed OK) → ALLOW"
      exit 0
      ;;
  esac
  # (vi) Phase 2a — a design-log is NOT marked "Approved/Implemented" without a
  # "## Antithesis" section: the refutation ritual (agent adversarial-critic) cannot be
  # silently skipped. The skill judges quality; this hook guarantees the ritual happened.
  case "$fp" in
    */design-log/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md)
      local newtext
      if [ "$HAS_JQ" -eq 1 ]; then
        newtext="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""' 2>/dev/null)"
      else
        newtext="$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    ti=json.load(sys.stdin).get("tool_input",{}); print(ti.get("content") or ti.get("new_string") or "")
except Exception: pass' 2>/dev/null)"
      fi
      if printf '%s' "$newtext" | grep -qE 'Status:[^A-Za-z]*(Approved|Implemented)'; then
        if ! printf '%s' "$newtext" | grep -qE '^#{2,}[[:space:]]*Antithesis' \
           && ! grep -qE '^#{2,}[[:space:]]*Antithesis' "$fp" 2>/dev/null; then
          deny "Design-Log (Phase 2a): you are marking this design 'Approved/Implemented' but the '## Antithesis' section is missing. Run the refuter (agent adversarial-critic), write antithesis + synthesis in the design log, THEN set the status."
        fi
      fi
      ;;
  esac
  # (iii) R.17 — work OUTSIDE design-log/ requires a current objective in FOCUS.
  # Enforcement unchanged (fires if the canonical FOCUS exists); the 🔄 may live in the canonical
  # or — for a shared session — in the session temp (focus_has_flag reads temp+canonical, fix R1).
  case "$fp" in
    */design-log/*|"") : ;;   # method bookkeeping or missing path → allowed
    *)
      if [ -f "$DL/FOCUS.md" ] && ! focus_has_flag "$sid"; then
        deny "Design-Log (R.17): no current objective in FOCUS.md. Bring the work into FOCUS (or use /add-task) before implementing."
      fi
      ;;
  esac
  hooklog "PreToolUse ${fp##*/} → ALLOW"
  exit 0
}

cmd_hook_precompact() {
  local input pct; input="$(cat)"; pct=""
  if [ "$HAS_JQ" -eq 1 ]; then pct="$(printf '%s' "$input" | jq -r '.context_fullness.percentage // ""' 2>/dev/null)"; fi
  hooklog "PreCompact (fullness=${pct:-?}%)"
  # lossless snapshot of the current objective BEFORE compaction cuts it
  if [ -f "$DL/FOCUS.md" ]; then
    { printf '\n[%s] pre-compact (fullness=%s%%)\n' "$(date -u +%FT%TZ 2>/dev/null)" "${pct:-?}"
      grep -m1 -E '^[[:space:]]*- .*🔄' "$DL/FOCUS.md" 2>/dev/null || true
    } >> "$DL/.precompact-snapshot.md" 2>/dev/null || true
  fi
  if [ "$HAS_JQ" -eq 1 ]; then
    jq -n --arg m "🧭 Compaction imminent (${pct:-?}%): the GUARDIAN will re-inject afterward. Consider /savesession if you have unsaved work." '{systemMessage:$m}' 2>/dev/null || true
  fi
  exit 0
}

# backlog-scan — surface the backlog IN THE CODE (Q2/G, keel #1): TODO/FIXME/KEEL: markers
# → design-log/.code-backlog.md as file:line. "done" = removing the comment in the diff (no separate
# tracking). Only projects served by the method (design-log/ exists). Bounded so it does not weigh on
# the turn (R5): excludes on vcs/vendor/build + cap; code scan → excludes design-log/ (bookkeeping).
cmd_backlog_scan() {
  [ -d "$DL" ] || return 0
  local out="$DL/.code-backlog.md" cap=200 tmp
  tmp=$(mktemp 2>/dev/null) || return 0
  grep -rInE 'TODO|FIXME|KEEL:' "$PROJECT_DIR" \
    --exclude-dir=.git --exclude-dir=.locks --exclude-dir=node_modules \
    --exclude-dir=design-log --exclude-dir=reports --exclude-dir=dist \
    --exclude-dir=build --exclude-dir=.next --exclude-dir=vendor \
    --exclude-dir=.venv --exclude-dir=target 2>/dev/null \
    | sed "s#^${PROJECT_DIR}/##" > "$tmp" 2>/dev/null || true
  local n; n=$(grep -c '' "$tmp" 2>/dev/null || true); n=${n:-0}
  { printf '# 🧩 Backlog in the code (surface) — TODO / FIXME / KEEL:\n'
    printf '> Regenerated by the Stop-hook at end of turn. "done" = remove the comment in the diff. %s markers.\n\n' "$n"
    if [ "$n" -eq 0 ]; then
      printf '*(no markers in the code)*\n'
    else
      head -n "$cap" "$tmp"
      if [ "$n" -gt "$cap" ]; then
        printf '\n… +%s more beyond the cap of %s (full grep: TODO/FIXME/KEEL: in the repo).\n' "$((n-cap))" "$cap"
      fi
    fi
  } > "$out.tmp" 2>/dev/null && mv "$out.tmp" "$out" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  echo "backlog=$n"
}

cmd_hook_stop() {
  cat >/dev/null 2>&1 || true
  [ -d "$DL" ] || exit 0
  local untriaged=0
  if [ -f "$DL/INBOX.md" ]; then
    untriaged="$(grep -cE '^[[:space:]]*- \[ \]' "$DL/INBOX.md" 2>/dev/null || true)"; untriaged=${untriaged:-0}
  fi
  # .plan/inbox/ — incoming cross-project handoff notes: they surface EVERY turn (quasi-live),
  # not only at /startsession (fix F, keel #1). The *.md glob does NOT enter archived/ → excluded.
  local plan_notes=0 plan_list="" nf
  if [ -d "$PROJECT_DIR/.plan/inbox" ]; then
    shopt -s nullglob
    for nf in "$PROJECT_DIR"/.plan/inbox/*.md; do plan_notes=$((plan_notes+1)); plan_list="$plan_list ${nf##*/}"; done
    shopt -u nullglob
  fi
  hooklog "Stop (inbox_untriaged=$untriaged plan_notes=$plan_notes)"
  # auto-refresh of the cross-project dashboard: regenerate the HTML at end of turn (always fresh).
  # No args → uses the config (KEEL_DASHBOARD_ROOTS / dashboard.roots / cwd). Writes to <GLOBAL_DIR>/dashboard/.
  local dash_out; dash_out="$(python3 "$PLUGIN_ROOT/scripts/dashboard.py" 2>/dev/null | tail -1)"
  # If the local report server is registered for THIS project: keep the served dashboard copy
  # fresh and regenerate the reports/ index — so any "update" left in the folder (user↔method
  # communication) shows up on its own at the end of the turn.
  if [ -f "$PROJECT_DIR/reports/.server.json" ]; then
    [ -n "$dash_out" ] && [ -f "$dash_out" ] && cp "$dash_out" "$PROJECT_DIR/reports/dashboard.html" 2>/dev/null || true
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" "$PLUGIN_ROOT/scripts/serve-reports.sh" reindex >/dev/null 2>&1 || true
  fi
  # backlog in the code (surface, Q2/G): regenerate design-log/.code-backlog.md. Bounded → non-blocking (R5).
  cmd_backlog_scan >/dev/null 2>&1 || true
  # BLOCKING sweep (FM2 "lose nothing"): do not end the turn with untriaged captures.
  # Anti-loop escape: the model may mark them DEFERRED ('- [ ]' → '- [>]') → they no longer count.
  # Precedence: the INBOX block (blocking) wins; otherwise the .plan/inbox notes surface as a
  # NON-blocking systemMessage (only one JSON emission possible on stdout).
  if [ "${untriaged:-0}" -gt 0 ] 2>/dev/null; then
    local r="📥 Design-Log: ${untriaged} untriaged item(s) in design-log/INBOX.md. BEFORE ending: triage each one (move it → TODO.md/TO_FIX.md or trash it) OR, if a user decision is needed, mark it DEFERRED by changing '- [ ]' to '- [>]'. Then end."
    if [ "$HAS_JQ" -eq 1 ]; then
      jq -n --arg r "$r" '{decision:"block",reason:$r}' 2>/dev/null || true
    else
      python3 -c 'import json,sys;print(json.dumps({"decision":"block","reason":sys.argv[1]}))' "$r" 2>/dev/null || true
    fi
  elif [ "$plan_notes" -gt 0 ] 2>/dev/null; then
    local pm="📬 Design-Log: ${plan_notes} handoff note(s) in .plan/inbox/:${plan_list}. Read them and take them into account; after consuming them, archive into .plan/inbox/archived/."
    if [ "$HAS_JQ" -eq 1 ]; then
      jq -n --arg m "$pm" '{systemMessage:$m}' 2>/dev/null || true
    else
      python3 -c 'import json,sys;print(json.dumps({"systemMessage":sys.argv[1]}))' "$pm" 2>/dev/null || true
    fi
  fi
  exit 0
}

cmd_hook_posttooluse() {
  local input tname fp
  input="$(cat)"
  if [ "$HAS_JQ" -eq 1 ]; then
    tname="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)"
    fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)"
  else
    tname="$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_name",""))
except Exception: pass' 2>/dev/null)"
    fp="$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception: pass' 2>/dev/null)"
  fi
  [ -d "$DL" ] || exit 0
  # Refresh the GUARDIAN when a new DATED design-log is CREATED (= a task started).
  # Only the Write tool (creation), not Edit → one injection per new task.
  case "$fp" in
    */design-log/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md)
      if [ "$tname" = "Write" ]; then
        hooklog "PostToolUse (new design-log: ${fp##*/}) → GUARDIAN refresh"
        local blk; blk="$(guardian_block)"
        if [ "$HAS_JQ" -eq 1 ]; then
          jq -n --arg c "$blk" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}' 2>/dev/null || true
        else
          python3 -c 'import json,sys;print(json.dumps({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":sys.argv[1]}}))' "$blk" 2>/dev/null || true
        fi
      fi
      ;;
  esac
  exit 0
}

# --- Cross-project global memory: resolution + bootstrap (portability) ---
cmd_global_dir() { printf '%s\n' "$GLOBAL_DIR"; }

# Idempotent: creates the global-memory skeleton if missing. Does not overwrite existing
# files. Graceful degrade: if the dir cannot be created → warning on stderr + exit 0
# (the feature will use only the project's LOCAL memory, design-log/LEARNED.md).
cmd_global_bootstrap() {
  local dir="$GLOBAL_DIR"
  if ! mkdir -p "$dir/LEARNED_GLOBAL" 2>/dev/null; then
    echo "⚠️ keel: cannot create $dir — global memory disabled (only design-log/LEARNED.md remains)." >&2
    return 0
  fi
  if [ ! -f "$dir/LEARNED_GLOBAL.md" ]; then
    cat > "$dir/LEARNED_GLOBAL.md" <<'EOF'
# LEARNED_GLOBAL — Index / Manifest

> Shared cross-project memory of the method (keel). Read at session start; written ONLY
> through the distiller + explicit confirmation (hard-block FM9). One file per **domain** in
> `LEARNED_GLOBAL/`.

## Routing criterion (PRINCIPLE vs FACT)

An entry belongs here ONLY if it is a **universal PRINCIPLE** of *how you work / how you build*
(always true, tool-independent). Every **specific FACT/gotcha** of a tool/API/project is **LOCAL**
(`<project>/design-log/LEARNED.md`) — local memories are recalled cross-project when needed.
Near-zero reuse → trash. Blunt rule: **GLOBAL = principle · LOCAL = specific fact.**

## Domains

- `general.md` — ALWAYS: method/workflow/debugging/communication (cross-domain)
- `preferences.md` — ALWAYS: user preferences across all projects
- `software-general.md` — git/bash/tooling/build/cross-repo architecture/ML/ffmpeg
- `software-apple.md` — Swift/SwiftUI/iOS/macOS/Xcode/AVFoundation
- `software-web.md` — JS/TS/Next/React/Node/Python-backend/DB/auth/SaaS/cloud
- `design.md` — UX/visual/product

Conditional loading by stack: always the index + `general` + `preferences`; the software/design
domains only if relevant to the project's stack.
EOF
  fi
  local d
  for d in general preferences software-general software-apple software-web design; do
    [ -f "$dir/LEARNED_GLOBAL/$d.md" ] || printf '# LEARNED_GLOBAL — %s\n\n> Universal principles for the "%s" domain. Empty for now: entries are added by the distiller (proposal + confirmation).\n\n### Technical Patterns\n\n### Mistakes Not to Repeat\n\n### Reusable Solutions\n' "$d" "$d" > "$dir/LEARNED_GLOBAL/$d.md"
  done
  # seed the dashboard multi-root config (commented): the user fills it in when they want.
  if [ ! -f "$dir/dashboard.roots" ]; then
    cat > "$dir/dashboard.roots" <<'EOF'
# keel dashboard — one path per line: a ROOT to scan, or an explicit PROJECT dir (has design-log/).
# Blank lines and lines starting with '#' are ignored; ~ and $VARS are expanded.
# With no entries here (and no $KEEL_DASHBOARD_ROOTS set), the dashboard shows the current directory.
# Example:
#   ~/Projects
#   ~/work/my-app
EOF
  fi
  printf '%s\n' "$dir"
}

# ============================================================================
# Orchestrator commands (standalone) — session marker, method gates,
# scaffolding of a new project. Ported from the command-based method and made
# self-contained in the plugin (no ~/.claude-method: the method files live here).
# ============================================================================

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
ensure_locks() { mkdir -p "$LOCKS_DIR" 2>/dev/null || true; }
# INJECTIVE path→lock-name encoding (fix bug-batch 2026-08-19: the old '/'→'__' collided
# ('src/a.md' and 'src__a.md' → same lock). Percent-encoding of '%' and '/' is reversible/collision-free.
encode_path() { local p="${1//%/%25}"; printf '%s' "${p//\//%2F}"; }
marker_path() { printf '%s/session-%s.json' "$LOCKS_DIR" "$1"; }
lock_path()   { printf '%s/%s.lock' "$LOCKS_DIR" "$(encode_path "$1")"; }
by_claude_path() { printf '%s/by-claude/%s' "$LOCKS_DIR" "$1"; }

# STABLE start-id of a pid (process start-time): tells a live pid apart from a RECYCLED one
# (anti-recycling, F2). ps -o lstart works on macOS and Linux; if absent → empty (degrades to
# kill -0 only).
proc_start_id() {
  local pid="${1:-}"; [ -n "$pid" ] || return 0
  ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//'
}
# alive AND (start_id empty OR matches) → the marker's process is still the real one.
proc_is_alive_matching() {
  local pid="${1:-}" sid="${2:-}" cur
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [ -n "$sid" ] || return 0
  cur=$(proc_start_id "$pid"); [ "$cur" = "$sid" ]
}

require_uid() {
  if [ -z "${1:-}" ]; then echo "ERROR: --uid required" >&2; exit 2; fi
  if [ ! -f "$(marker_path "$1")" ]; then
    echo "ERROR: marker not found for uid '$1'" >&2; exit 2
  fi
}

marker_set_shared() {
  local file="$1"; shift
  if [ "$HAS_JQ" -eq 1 ]; then
    local files_json; files_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    jq --argjson lf "$files_json" '.type="shared" | .lockedFiles=$lf' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    python3 - "$file" "$@" <<'PY'
import json,sys
p=sys.argv[1]; files=sys.argv[2:]; m=json.load(open(p))
m['type']='shared'; m['lockedFiles']=files; json.dump(m,open(p,'w'),indent=2)
PY
  fi
}
marker_append_locked_file() {
  local file="$1" target="$2"
  if [ "$HAS_JQ" -eq 1 ]; then
    jq --arg f "$target" '.lockedFiles += [$f]' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    python3 - "$file" "$target" <<'PY'
import json,sys
p,t=sys.argv[1],sys.argv[2]; m=json.load(open(p))
m.setdefault('lockedFiles',[]).append(t); json.dump(m,open(p,'w'),indent=2)
PY
  fi
}
marker_set_exclusive() {
  local file="$1"
  if [ "$HAS_JQ" -eq 1 ]; then
    jq '.type="exclusive" | .lockedFiles=[]' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    python3 - "$file" <<'PY'
import json,sys
p=sys.argv[1]; m=json.load(open(p)); m['type']='exclusive'; m['lockedFiles']=[]; json.dump(m,open(p,'w'),indent=2)
PY
  fi
}
marker_get_field() {
  local file="$1" field="$2"
  if [ "$HAS_JQ" -eq 1 ]; then jq -r ".${field} // \"\"" "$file"
  else python3 - "$file" "$field" <<'PY'
import json,sys
p,f=sys.argv[1],sys.argv[2]; m=json.load(open(p))
v=m.get(f,''); print(v if not isinstance(v,(list,dict)) else json.dumps(v))
PY
  fi
}

cmd_preflight() { if [ "$HAS_JQ" -eq 1 ]; then echo "jq:OK"; else echo "jq:MISSING"; fi; }

cmd_status() {
  ensure_locks
  if [ "$HAS_JQ" -eq 1 ]; then
    # Array with nullglob + QUOTED expansion: a lock/marker with a SPACE in the name won't break jq
    # (fix bug-batch 2026-08-19: `jq -s . $lf` unquoted → word-splitting → file_locks=[] falsely).
    local markers='[]' locks='[]' mfa lfa
    shopt -s nullglob; mfa=( "$LOCKS_DIR"/session-*.json ); lfa=( "$LOCKS_DIR"/*.lock ); shopt -u nullglob
    [ ${#mfa[@]} -gt 0 ] && markers=$(jq -s . "${mfa[@]}" 2>/dev/null || echo '[]')
    [ ${#lfa[@]} -gt 0 ] && locks=$(jq -s . "${lfa[@]}" 2>/dev/null || echo '[]')
    jq -n --argjson m "$markers" --argjson l "$locks" '{markers:$m,file_locks:$l}'
  else
    python3 - "$LOCKS_DIR" <<'PY'
import json,glob,sys,os
d=sys.argv[1]; markers=[]; locks=[]
for f in sorted(glob.glob(os.path.join(d,"session-*.json"))):
    try: markers.append(json.load(open(f)))
    except: pass
for f in sorted(glob.glob(os.path.join(d,"*.lock"))):
    try: locks.append(json.load(open(f)))
    except: pass
print(json.dumps({"markers":markers,"file_locks":locks},indent=2))
PY
  fi
}

cmd_init() {
  ensure_locks
  local uid now host file name="" sid pid startid
  while [ $# -gt 0 ]; do case "$1" in --name) name="${2:-}"; shift 2 ;; *) shift ;; esac; done
  local mtype="exclusive"
  if [ -n "$name" ]; then
    mtype="shared"   # the NAME is the signal of a parallel/shared session
    # ATOMIC name claim (mkdir is atomic on a local FS, same-host linchpin) → never two colliding sessions
    mkdir -p "$LOCKS_DIR/names" 2>/dev/null || true
    if ! mkdir "$LOCKS_DIR/names/$name" 2>/dev/null; then echo "ERROR: name '$name' already claimed" >&2; exit 3; fi
  fi
  uid=$(uuidgen); now=$(iso_now); host=$(hostname -s 2>/dev/null || hostname)
  sid="${CLAUDE_CODE_SESSION_ID:-}"; pid="${CLAUDE_PID:-}"; startid=$(proc_start_id "$pid")
  file=$(marker_path "$uid")
  # ATOMIC write (tmp+mv): a marker is never truncated even if the turn is interrupted mid-way.
  cat > "$file.tmp" <<EOF
{
  "uid": "$uid",
  "type": "$mtype",
  "name": "$name",
  "claude_session_id": "$sid",
  "pid": "$pid",
  "start_id": "$startid",
  "startedAt": "$now",
  "host": "$host",
  "lockedFiles": []
}
EOF
  mv "$file.tmp" "$file"
  # O(1) pointer session_id -> uid: hooks locate THEIR OWN temp without scanning the markers.
  if [ -n "$sid" ]; then
    mkdir -p "$LOCKS_DIR/by-claude" 2>/dev/null || true
    printf '%s' "$uid" > "$(by_claude_path "$sid").tmp" && mv "$(by_claude_path "$sid").tmp" "$(by_claude_path "$sid")"
  fi
  printf '%s\n' "$uid"
}

cmd_share() {
  local uid="" files=()
  while [ $# -gt 0 ]; do case "$1" in --uid) uid="$2"; shift 2 ;; *) files+=("$1"); shift ;; esac; done
  require_uid "$uid"
  [ ${#files[@]} -gt 0 ] || { echo "ERROR: at least one file required" >&2; exit 2; }
  ensure_locks
  local now; now=$(iso_now)
  local f lf owner
  for f in "${files[@]}"; do
    lf=$(lock_path "$f")
    if [ -f "$lf" ]; then owner=$(marker_get_field "$lf" "owner_uid"); [ "$owner" != "$uid" ] && { echo "ERROR: $f already locked by $owner" >&2; exit 3; }; fi
  done
  for f in "${files[@]}"; do
    lf=$(lock_path "$f")
    cat > "$lf.tmp" <<EOF
{ "owner_uid": "$uid", "file": "$f", "task": "shared session work", "createdAt": "$now" }
EOF
    mv "$lf.tmp" "$lf"   # atomic write: a concurrent reader never sees partial JSON
  done
  marker_set_shared "$(marker_path "$uid")" "${files[@]}"
  printf 'OK: shared with %d file(s)\n' "${#files[@]}"
}

cmd_add_file() {
  local uid="" target=""
  while [ $# -gt 0 ]; do case "$1" in --uid) uid="$2"; shift 2 ;; *) target="$1"; shift ;; esac; done
  require_uid "$uid"; [ -n "$target" ] || { echo "ERROR: file required" >&2; exit 2; }
  ensure_locks
  local lf now owner; lf=$(lock_path "$target"); now=$(iso_now)
  if [ -f "$lf" ]; then owner=$(marker_get_field "$lf" "owner_uid"); [ "$owner" != "$uid" ] && { echo "ERROR: $target already locked by $owner" >&2; exit 3; }; echo "OK: already self-locked"; return 0; fi
  cat > "$lf.tmp" <<EOF
{ "owner_uid": "$uid", "file": "$target", "task": "shared session work", "createdAt": "$now" }
EOF
  mv "$lf.tmp" "$lf"   # atomic write: a concurrent reader never sees partial JSON
  marker_append_locked_file "$(marker_path "$uid")" "$target"
  printf 'OK: added %s\n' "$target"
}

cmd_release() {
  local uid=""
  while [ $# -gt 0 ]; do case "$1" in --uid) uid="$2"; shift 2 ;; *) shift ;; esac; done
  require_uid "$uid"; ensure_locks
  local removed=0 owner; shopt -s nullglob
  for lf in "$LOCKS_DIR"/*.lock; do owner=$(marker_get_field "$lf" "owner_uid"); [ "$owner" = "$uid" ] && { rm -f "$lf"; removed=$((removed+1)); }; done
  shopt -u nullglob
  marker_set_exclusive "$(marker_path "$uid")"
  printf 'OK: released %d lock(s)\n' "$removed"
}

cmd_end() {
  local uid="${1:-}"; [ -n "$uid" ] || { echo "ERROR: uid required" >&2; exit 2; }
  local file; file=$(marker_path "$uid")
  [ -f "$file" ] || { echo "WARN: marker not found (already removed?)" >&2; return 0; }
  local sid name; sid=$(marker_get_field "$file" "claude_session_id"); name=$(marker_get_field "$file" "name")
  # release the uid's per-file .lock BEFORE removing the marker (fix bug-batch [A]: without this they
  # stay orphaned and irrecoverable, blocking share/add-file forever; reap won't take them because the
  # marker is already gone).
  local lf owner; shopt -s nullglob
  for lf in "$LOCKS_DIR"/*.lock; do owner=$(marker_get_field "$lf" "owner_uid"); [ "$owner" = "$uid" ] && rm -f "$lf"; done
  shopt -u nullglob
  rm -f "$file"
  [ -n "$sid" ] && rm -f "$(by_claude_path "$sid")"
  [ -n "$name" ] && rmdir "$LOCKS_DIR/names/$name" 2>/dev/null
  printf 'OK: removed marker for uid %s\n' "$uid"
}

# reap-orphans: removes markers whose process is no longer alive (dead pid, or RECYCLED pid =
# different start_id). Same-host (linchpin 2026-08-19): a marker with a live pid + matching start_id
# is a REAL session, even if parked at a checkpoint for hours → NEVER reap. Old-schema markers
# (no pid) → not reap-able (compat): skip.
cmd_reap_orphans() {
  ensure_locks
  local reaped=0 mf pid sid uid claudesid nm lf owner
  shopt -s nullglob
  for mf in "$LOCKS_DIR"/session-*.json; do
    pid=$(marker_get_field "$mf" "pid")
    [ -n "$pid" ] || continue
    sid=$(marker_get_field "$mf" "start_id")
    proc_is_alive_matching "$pid" "$sid" && continue
    uid=$(marker_get_field "$mf" "uid")
    claudesid=$(marker_get_field "$mf" "claude_session_id")
    nm=$(marker_get_field "$mf" "name")
    rm -f "$mf"
    [ -n "$claudesid" ] && rm -f "$(by_claude_path "$claudesid")"
    [ -n "$nm" ] && rmdir "$LOCKS_DIR/names/$nm" 2>/dev/null
    for lf in "$LOCKS_DIR"/*.lock; do [ -e "$lf" ] || continue; owner=$(marker_get_field "$lf" "owner_uid"); [ "$owner" = "$uid" ] && rm -f "$lf"; done
    reaped=$((reaped+1))
  done
  shopt -u nullglob
  echo "reaped=$reaped"
}

# resolve-uid <claude_session_id>: uid of that session's marker (O(1) pointer; fallback scan).
cmd_resolve_uid() {
  local sid="${1:-}"; [ -n "$sid" ] || return 0
  local p; p="$(by_claude_path "$sid")"
  if [ -f "$p" ]; then cat "$p"; return 0; fi
  local mf; shopt -s nullglob
  for mf in "$LOCKS_DIR"/session-*.json; do
    if [ "$(marker_get_field "$mf" "claude_session_id")" = "$sid" ]; then marker_get_field "$mf" "uid"; shopt -u nullglob; return 0; fi
  done
  shopt -u nullglob
}

# session-advise [<name>]: advises /startsession on the start mode (reaps first, then decides on the LIVE ones).
# verdict: EXCLUSIVE | READ_ONLY | SHARED_NAMED | SHARED_ADOPT | SHARED_ASK | BLOCKED_BY_EXCLUSIVE
cmd_session_advise() {
  ensure_locks
  cmd_reap_orphans >/dev/null 2>&1
  local want="${1:-}" mf typ nm has_excl=0 shared_names=()
  shopt -s nullglob
  for mf in "$LOCKS_DIR"/session-*.json; do
    typ=$(marker_get_field "$mf" "type"); nm=$(marker_get_field "$mf" "name")
    [ "$typ" = "exclusive" ] && has_excl=1
    [ "$typ" = "shared" ] && [ -n "$nm" ] && shared_names+=("$nm")
  done
  shopt -u nullglob
  if [ -n "$want" ]; then
    [ "$has_excl" -eq 1 ] && { echo "verdict=BLOCKED_BY_EXCLUSIVE"; echo "name=$want"; return 0; }
    echo "verdict=SHARED_NAMED"; echo "name=$want"; return 0
  fi
  local n_live; n_live=$(ls "$LOCKS_DIR"/session-*.json 2>/dev/null | wc -l | tr -d ' ')
  [ "${n_live:-0}" -eq 0 ] && { echo "verdict=EXCLUSIVE"; return 0; }
  [ "$has_excl" -eq 1 ] && { echo "verdict=READ_ONLY"; return 0; }
  # only shared sessions live → infer the name from free sprint slots (sprint-<X>.txt with no live shared <X>)
  local slot base s taken free=()
  shopt -s nullglob
  for slot in "$PROJECT_DIR"/sprint-*.txt; do
    base=$(basename "$slot" .txt); base=${base#sprint-}
    taken=0; for s in "${shared_names[@]}"; do [ "$s" = "$base" ] && taken=1; done
    [ "$taken" -eq 0 ] && free+=("$base")
  done
  shopt -u nullglob
  if [ "${#free[@]}" -eq 1 ]; then echo "verdict=SHARED_ADOPT"; echo "name=${free[0]}"; return 0; fi
  echo "verdict=SHARED_ASK"; return 0
}

# sprint-file [<name>]: name of the sprint file for this session (sprint-<name>.txt | sprint.txt).
cmd_sprint_file() {
  local name="${1:-}"
  if [ -n "$name" ]; then printf 'sprint-%s.txt\n' "$name"; else printf 'sprint.txt\n'; fi
}

# METHOD files contended in a shared session (NOT the project/code files, which stay on .lock).
METHOD_FILES="FOCUS.md TODO.md TO_FIX.md TO_TEST.md INBOX.md"

# shared-begin <uid>: BASE snapshot of the canonical + a work copy for a shared session.
# Without a base (snapshot at start) PRUNES/deletes could not be represented in the 3-way (fix F3).
cmd_shared_begin() {
  local uid="${1:-}"; [ -n "$uid" ] || { echo "ERROR: uid required" >&2; exit 2; }
  ensure_locks
  local d="$LOCKS_DIR/session-$uid" f
  mkdir -p "$d/base" "$d/work"
  for f in $METHOD_FILES; do
    if [ -f "$DL/$f" ]; then cp "$DL/$f" "$d/base/$f"; cp "$DL/$f" "$d/work/$f"
    else : > "$d/base/$f"; : > "$d/work/$f"; fi
  done
  echo "shared-begin OK: $d"
}

# shared-convert <uid> --name <name>: IN-SESSION conversion of an exclusive marker → shared+named
# (used by /startsharedsession). ATOMIC name claim (mkdir, before touching the marker) +
# type→shared + name=<name> (atomic write tmp+mv) + base/work snapshot of the method files.
cmd_shared_convert() {
  local uid="" name=""
  while [ $# -gt 0 ]; do case "$1" in --name) name="${2:-}"; shift 2 ;; *) uid="${uid:-$1}"; shift ;; esac; done
  [ -n "$uid" ]  || { echo "ERROR: uid required" >&2; exit 2; }
  [ -n "$name" ] || { echo "ERROR: --name <name> required" >&2; exit 2; }
  ensure_locks
  local file; file="$(marker_path "$uid")"
  [ -f "$file" ] || { echo "ERROR: marker not found for uid $uid" >&2; exit 2; }
  # ATOMIC name claim BEFORE touching the marker (mkdir atomic on a local FS, same-host linchpin)
  mkdir -p "$LOCKS_DIR/names" 2>/dev/null || true
  if ! mkdir "$LOCKS_DIR/names/$name" 2>/dev/null; then echo "ERROR: name '$name' already claimed" >&2; exit 3; fi
  if [ "$HAS_JQ" -eq 1 ]; then
    jq --arg n "$name" '.type="shared" | .name=$n' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    python3 - "$file" "$name" <<'PY'
import json,sys
p=sys.argv[1]; name=sys.argv[2]; m=json.load(open(p))
m['type']='shared'; m['name']=name; json.dump(m,open(p,'w'),indent=2)
PY
  fi
  cmd_shared_begin "$uid" >/dev/null
  echo "shared-convert OK: uid=$uid name=$name"
}

# merge-method <uid>: merges a shared session's method files into the canonical via 3-way
# (git merge-file work base canonical). Safeguards (2nd refutation pass):
#  - on CONFLICT the canonical is NOT touched (stays theirs); the merge-with-markers goes to .conflicts/ (fix F3a).
#  - a mkdir micro-lock serializes the read-merge-write of two simultaneous /savesession (fix F3b).
#  - atomic write tmp+mv; git absent → graceful skip, the edits stay in the work copy (fix F3c).
cmd_merge_method() {
  local uid="${1:-}"; [ -n "$uid" ] || { echo "ERROR: uid required" >&2; exit 2; }
  ensure_locks
  local d="$LOCKS_DIR/session-$uid"
  [ -d "$d/work" ] || { echo "merged=0"; echo "conflicts=0"; echo "note=not-shared-or-no-work"; return 0; }
  if ! command -v git >/dev/null 2>&1; then echo "merged=0"; echo "conflicts=0"; echo "note=git-absent-work-preserved"; return 0; fi
  local lk="$LOCKS_DIR/merge.lock" tries=0
  while ! mkdir "$lk" 2>/dev/null; do tries=$((tries+1)); [ "$tries" -gt 100 ] && break; sleep 0.05 2>/dev/null || true; done
  local merged=0 conflicts=0 f base work canon rc cdir stamp
  cdir="$DL/.conflicts"; stamp=$(iso_now | tr ':' '-')
  for f in $METHOD_FILES; do
    base="$d/base/$f"; work="$d/work/$f"; canon="$DL/$f"
    [ -f "$work" ] || continue
    [ -f "$base" ]  || : > "$base"
    [ -f "$canon" ] || : > "$canon"
    git merge-file "$work" "$base" "$canon" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
      cp "$work" "$canon.tmp" && mv "$canon.tmp" "$canon"; merged=$((merged+1))
    else
      # conflict (rc>0) or error: do NOT touch the canonical; persist the merge-with-markers
      mkdir -p "$cdir" 2>/dev/null; cp "$work" "$cdir/$stamp-$f" 2>/dev/null
      conflicts=$((conflicts+1))
    fi
  done
  rmdir "$lk" 2>/dev/null
  rm -rf "$d/base" "$d/work"
  echo "merged=$merged"; echo "conflicts=$conflicts"
  [ "$conflicts" -gt 0 ] && echo "conflicts_dir=$cdir"
}

# reg-check <session-log>: gate 1A — verifies the PRESENCE of the "Execution log" block.
# (Honest: it forces presence, not the truth of the content — see the design log Antithesis.)
cmd_reg_check() {
  local f="${1:-}"
  [ -f "$f" ] || { echo "verdict=NO_LOG"; return 0; }
  if grep -qiE '^#{1,4}[[:space:]]*Execution log' "$f" 2>/dev/null; then echo "verdict=REG_PRESENT"; else echo "verdict=REG_MISSING"; fi
}

# ensure_gitignore <entry...>: appends the missing entries to $PROJECT_DIR/.gitignore, idempotent and
# NEWLINE-SAFE (guarantees a trailing \n BEFORE appending → never concatenates onto the last line,
# the class of bug found in the 2026-08-19 hunt on bootstrap-project.sh).
ensure_gitignore() {
  local gi="$PROJECT_DIR/.gitignore" e
  [ -f "$gi" ] || : > "$gi"
  if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi" 2>/dev/null)" ]; then printf '\n' >> "$gi"; fi
  for e in "$@"; do grep -qxF "$e" "$gi" 2>/dev/null || printf '%s\n' "$e" >> "$gi"; done
}

# recover-temps: JANITOR (fix F/R2) — recovers ORPHAN work/ temps (crashed shared session: the
# .locks/session-<uid>/ dir exists but the marker does not) by merging them into the canonical via
# 3-way merge (reuses cmd_merge_method), so un-merged edits are not lost. Call it at /startsession
# AFTER the reap. Skips temps of LIVE sessions (marker present).
cmd_recover_temps() {
  ensure_locks
  local recovered=0 d uid
  shopt -s nullglob
  for d in "$LOCKS_DIR"/session-*/; do
    d="${d%/}"; uid="${d##*/session-}"
    [ -f "$LOCKS_DIR/session-$uid.json" ] && continue   # LIVE session → don't touch
    [ -d "$d/work" ] || continue
    cmd_merge_method "$uid" >/dev/null 2>&1
    rmdir "$d" 2>/dev/null || true
    recovered=$((recovered+1))
  done
  shopt -u nullglob
  echo "recovered_temps=$recovered"
}

cmd_progress_check() {
  local P="$DL/PROGRESS.md" threshold=250
  [ -f "$P" ] || { echo "verdict=PROGRESS_MISSING"; return 0; }
  local plines rich has_work
  plines=$(wc -l < "$P" | tr -d ' ')
  rich=$(grep -c '^### ' "$P" 2>/dev/null || true); rich=${rich:-0}
  if grep -qE '^## (DONE|TODO|TO_FIX|TO_TEST)\b' "$P" 2>/dev/null; then has_work=yes; else has_work=no; fi
  _real_lines() { local f="$1" n; [ -f "$f" ] || { printf '0'; return; }
    n=$(grep -vE '^[[:space:]]*($|#|>|-{3,}|\|)' "$f" 2>/dev/null | grep -cE '[^[:space:]]' || true); printf '%s' "${n:-0}"; }
  local done_real todo_real split_pop monolith=no verdict
  done_real=$(_real_lines "$DL/DONE.md"); todo_real=$(_real_lines "$DL/TODO.md")
  if [ "$done_real" -ge 5 ] || [ "$todo_real" -ge 3 ]; then split_pop=yes; else split_pop=no; fi
  if [ "$has_work" = "yes" ] && [ "$rich" -ge 3 ]; then monolith=yes; fi
  if [ "$monolith" = "yes" ] && [ "$plines" -gt "$threshold" ]; then verdict=MIGRATE_REQUIRED
  elif [ "$monolith" = "yes" ]; then verdict=MONOLITH_SMALL; else verdict=MIGRATED; fi
  echo "verdict=$verdict"; echo "progress_lines=$plines"; echo "progress_entries=$rich"
  echo "progress_has_work_sections=$has_work"; echo "split_populated=$split_pop"; echo "threshold=$threshold"
}

cmd_method_check() {
  local missing=""
  [ -f "$DL/INBOX.md" ] || missing="$missing INBOX.md"
  [ -f "$DL/FOCUS.md" ] || missing="$missing FOCUS.md"
  if [ -n "$missing" ]; then echo "verdict=METHOD_MIGRATE"; echo "missing=${missing# }"; else echo "verdict=METHOD_OK"; fi
}

cmd_inbox_check() {
  local F="$DL/INBOX.md"
  [ -f "$F" ] || { echo "inbox_present=no"; echo "inbox_untriaged=0"; return 0; }
  local n resid
  n=$(grep -cE '^[[:space:]]*- \[ \]' "$F" 2>/dev/null || true); n=${n:-0}
  echo "inbox_present=yes"; echo "inbox_untriaged=$n"
  resid=$(grep -vE '^[[:space:]]*$|^[[:space:]]*#|^[[:space:]]*>|^[[:space:]]*\*\(|^[[:space:]]*- \[ \]' "$F" 2>/dev/null | grep -c . || true); resid=${resid:-0}
  echo "inbox_residue=$resid"
}

cmd_focus_check() {
  local F="$DL/FOCUS.md"
  [ -f "$F" ] || { echo "verdict=FOCUS_MISSING"; echo "focus_items=0"; return 0; }
  local n; n=$(grep -cE '^[[:space:]]*- ' "$F" 2>/dev/null || true); n=${n:-0}
  if [ "$n" -ge 1 ]; then echo "verdict=FOCUS_OK"; else echo "verdict=FOCUS_EMPTY"; fi
  echo "focus_items=$n"
  local lines threshold="${FOCUS_BLOAT_THRESHOLD:-40}" bloat=no
  lines=$(wc -l < "$F" 2>/dev/null | tr -d '[:space:]'); lines=${lines:-0}
  [ "$lines" -gt "$threshold" ] && bloat=yes
  echo "focus_lines=$lines"; echo "focus_bloat=$bloat"; echo "focus_bloat_threshold=$threshold"
}

# STANDALONE scaffolding: creates the design-log/ structure of a new project.
# The method files (BEHAVIORS/METHODOLOGY) are SYMLINKS to the plugin → no ~/.claude-method.
# The other per-project files are created from templates ONLY if missing (idempotent).
cmd_scaffold() {
  local DLD="$DL"
  mkdir -p "$DLD/sessions" "$DLD/issues" 2>/dev/null
  # runtime state gitignored (standalone: a stranger who scaffolds gets the right ignores right away)
  ensure_gitignore ".locks/" "design-log/.conflicts/" "design-log/.code-backlog.md" "design-log/.precompact-snapshot.md" ".claude-designlog-hooks.log"
  ln -sfn "$PLUGIN_ROOT/design-log/BEHAVIORS.md"   "$DLD/BEHAVIORS.md"
  ln -sfn "$PLUGIN_ROOT/design-log/METHODOLOGY.md" "$DLD/METHODOLOGY.md"
  [ -f "$DLD/PROJECT.md" ] || printf '# Project\n\n> Describe here what this project is, its purpose, the stack, the architecture.\n> `/startsession` on an empty PROJECT.md triggers Project Discovery Mode.\n\n[Empty]\n' > "$DLD/PROJECT.md"
  [ -f "$DLD/BEHAVIORS_LOCAL.md" ] || printf '# Behaviors Local\n\n> Behavioral rules specific to this project. Read every session together with BEHAVIORS.md.\n\n---\n\n## Behavioral Rules\n\n[Empty]\n' > "$DLD/BEHAVIORS_LOCAL.md"
  [ -f "$DLD/PROJECT_UPDATES.md" ] || printf '# Project Updates\n\n> Project-specific context/conventions/operational decisions.\n\n---\n\n## Project Context / Conventions\n\n[Empty]\n' > "$DLD/PROJECT_UPDATES.md"
  [ -f "$DLD/FOCUS.md" ] || printf '# 🎯 FOCUS — Current objective\n\n> Read FIRST every session. The few things in flight NOW. Only ONE 🔄 in progress at a time.\n> States: 🔄 in progress · 🧪 implemented, to validate · ⏸️ queued.\n\n## In flight\n\n*(empty)*\n' > "$DLD/FOCUS.md"
  [ -f "$DLD/INBOX.md" ] || printf '# 📥 INBOX — Raw capture (to triage)\n\n> Anything the user says to capture goes HERE right away, before acting.\n\n## To triage\n\n*(empty)*\n' > "$DLD/INBOX.md"
  [ -f "$DLD/PROGRESS.md" ] || printf '# Project Progress (index)\n\n> Last updated: scaffold\n\n## Quick status\n- 🎯 Current objective → [FOCUS.md](./FOCUS.md) · 📥 → [INBOX.md](./INBOX.md)\n- 📋 Open TODOs: 0 → [TODO.md](./TODO.md)\n- 🐛 Bugs: 0 → [TO_FIX.md](./TO_FIX.md)\n- 🧪 To validate: 0 → [TO_TEST.md](./TO_TEST.md)\n- ✅ → [DONE.md](./DONE.md) · 🔧 → [FIXED.md](./FIXED.md)\n- 🗄️ → [progress.old.md](./progress.old.md)\n\n## Quick Links\n- [PROJECT.md](./PROJECT.md) · [Sessions](./sessions/) · [Issues](./issues/_INDEX.md)\n' > "$DLD/PROGRESS.md"
  [ -f "$DLD/TODO.md" ]     || printf '# TODO - To do\n\n### 🔴 High Priority\n\n### 🟡 Medium Priority\n\n### 🟢 Low Priority / Ideas\n' > "$DLD/TODO.md"
  [ -f "$DLD/TO_FIX.md" ]   || printf '# TO_FIX - Bugs to fix\n\n### 🔴 CRITICAL\n\n### 🟡 MEDIUM\n\n### 🟢 LOW\n' > "$DLD/TO_FIX.md"
  [ -f "$DLD/TO_TEST.md" ]  || printf '# TO_TEST - Implemented, to validate\n' > "$DLD/TO_TEST.md"
  [ -f "$DLD/DONE.md" ]     || printf '# DONE - Completed work (recent)\n' > "$DLD/DONE.md"
  [ -f "$DLD/FIXED.md" ]    || printf '# FIXED - Fixed bugs (recent)\n' > "$DLD/FIXED.md"
  [ -f "$DLD/progress.old.md" ] || printf '# Progress Archive\n\n> Archive of old DONE/FIXED entries.\n' > "$DLD/progress.old.md"
  [ -f "$DLD/LEARNED.md" ]  || printf '# Learned - Learning memory (local)\n\n> Technical knowledge specific to this project. Read at every /startsession.\n\n## Technical Patterns\n\n## Mistakes Not to Repeat\n\n## User Preferences\n\n## Reusable Solutions\n' > "$DLD/LEARNED.md"
  [ -f "$DLD/issues/_INDEX.md" ] || printf '# Issues Index\n\n> Stats: 🔴 0 | 🟡 0 | ✅ 0 | ❌ 0\n\n## 🐛 Bugs\n\n*No bugs yet*\n\n## ✨ Enhancements\n\n*No enhancements yet*\n' > "$DLD/issues/_INDEX.md"
  echo "scaffold OK: $DLD"
}

# sprint.txt freshness gate — see /savesession 2b-ter and /startsession STEP 5.
# The sprint auto-started by /startsession MUST be pruned at every /savesession;
# prose alone got skipped (R.1), so this makes it script-verified (UID-based),
# like progress-check/focus-check. sprint-mark stamps the current session's UID;
# sprint-check compares it to the most recent session log's UID (mismatch=STALE).
cmd_sprint_mark() {
  local uid="${1:-}"
  [ -n "$uid" ] || { echo "ERROR: uid argument required" >&2; exit 2; }
  # File parameterized by name (sprint-<name>.txt) + PROJECT_DIR-relative (never cwd-dependent).
  local F="$PROJECT_DIR/${2:-sprint.txt}"
  [ -f "$F" ] || { echo "verdict=SPRINT_ABSENT"; return 0; }
  local stamp tmp; stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ); tmp=$(mktemp)
  grep -vE '^# sprint-pruned-(uid|at):' "$F" > "$tmp" 2>/dev/null || true
  # ATOMIC write tmp+mv (fix bug-batch 2026-08-19: `{ ...; } > "$F"` truncated the original before
  # rewriting → interruption = empty/partial sprint, data lost).
  { cat "$tmp"; printf '\n# sprint-pruned-uid: %s\n# sprint-pruned-at: %s\n' "$uid" "$stamp"; } > "$F.tmp" && mv "$F.tmp" "$F"
  rm -f "$tmp"
  echo "verdict=SPRINT_MARKED"; echo "sprint_pruned_uid=$uid"; echo "sprint_pruned_at=$stamp"
}

cmd_sprint_check() {
  # File parameterized by name (sprint-<name>.txt) + PROJECT_DIR-relative (never cwd-dependent).
  local F="$PROJECT_DIR/${1:-sprint.txt}"
  [ -f "$F" ] || { echo "verdict=SPRINT_ABSENT"; return 0; }
  local marker_uid last_log last_uid
  marker_uid=$(grep -m1 -E '^# sprint-pruned-uid:' "$F" 2>/dev/null | sed -E 's/^# sprint-pruned-uid:[[:space:]]*//' | tr -d '[:space:]' || true)
  last_log=$(ls -1 "$DL"/sessions/[0-9]*.md 2>/dev/null | sort | tail -1 || true)
  [ -n "$last_log" ] || { echo "verdict=SPRINT_NO_BASELINE"; echo "sprint_marker_uid=${marker_uid:-none}"; return 0; }
  last_uid=$(grep -m1 -E '^\*\*Session UID\*\*:' "$last_log" 2>/dev/null | sed -E 's/^\*\*Session UID\*\*:[[:space:]]*//' | tr -d '[:space:]' || true)
  if [ -n "$marker_uid" ] && [ "$marker_uid" = "$last_uid" ]; then echo "verdict=SPRINT_FRESH"; else echo "verdict=SPRINT_STALE"; fi
  # FRESH/STALE = only "did the last session prune?" (UID match); neither verifies items are still OPEN (user may close them OUT OF SESSION → no new session log → UID still matches → FRESH forever). Always reconcile + confirm user/external items (startsession STEP 5A). (2026-08-05)
  echo "reconcile=REQUIRED"; echo "fresh_means=last_session_pruned_only"
  echo "sprint_marker_uid=${marker_uid:-none}"; echo "last_session_uid=${last_uid:-none}"; echo "last_session_log=${last_log:-none}"
}

case "${1:-}" in
  guardian-block)        guardian_block ;;
  hook-sessionstart)     hooklog "SessionStart"; cmd_global_bootstrap >/dev/null 2>&1; guardian_block ;;
  hook-userpromptsubmit) cmd_hook_userpromptsubmit ;;
  hook-pretooluse)       cmd_hook_pretooluse ;;
  hook-posttooluse)      cmd_hook_posttooluse ;;
  hook-precompact)       cmd_hook_precompact ;;
  hook-stop)             cmd_hook_stop ;;
  backlog-scan)          cmd_backlog_scan ;;
  learned-approve)       shift; cmd_learned_approve "$@" ;;
  learned-approve-clear) cmd_learned_approve_clear ;;
  global-dir)            cmd_global_dir ;;
  global-bootstrap)      cmd_global_bootstrap ;;
  detect-type)           detect_type; echo ;;
  north-star)            north_star ;;
  preflight)             cmd_preflight ;;
  status)                cmd_status ;;
  init)                  shift; cmd_init "$@" ;;
  reap)                  cmd_reap_orphans ;;
  resolve-uid)           shift; cmd_resolve_uid "$@" ;;
  session-advise)        shift; cmd_session_advise "$@" ;;
  sprint-file)           shift; cmd_sprint_file "$@" ;;
  shared-begin)          shift; cmd_shared_begin "$@" ;;
  merge-method)          shift; cmd_merge_method "$@" ;;
  shared-convert)        shift; cmd_shared_convert "$@" ;;
  recover-temps)         cmd_recover_temps ;;
  reg-check)             shift; cmd_reg_check "$@" ;;
  share)                 shift; cmd_share "$@" ;;
  add-file)              shift; cmd_add_file "$@" ;;
  release)               shift; cmd_release "$@" ;;
  end)                   shift; cmd_end "$@" ;;
  progress-check)        cmd_progress_check ;;
  method-check)          cmd_method_check ;;
  inbox-check)           cmd_inbox_check ;;
  focus-check)           cmd_focus_check ;;
  sprint-check)          shift; cmd_sprint_check "$@" ;;
  sprint-mark)           shift; cmd_sprint_mark "$@" ;;
  scaffold)              cmd_scaffold ;;
  *) echo "usage: lock.sh {guardian-block|hook-*|learned-approve[-clear]|global-dir|global-bootstrap|detect-type|north-star|preflight|status|init|share|add-file|release|end|progress-check|method-check|inbox-check|focus-check|scaffold}" >&2; exit 2 ;;
esac
