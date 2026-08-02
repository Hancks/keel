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
hooklog() { printf '[%s] %s\n' "$(date -u +%FT%TZ 2>/dev/null)" "$1" >> "$HOOKLOG" 2>/dev/null || true; }

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
  if printf '%s' "$prompt" | grep -qiE '(^|[[:space:]])(segna|appunta|annota|ricorda|memorizza|nota|note|remember|jot|capture|remind)([[:space:]]|:|$)' 2>/dev/null; then
    seg="yes"
    mkdir -p "$DL" 2>/dev/null
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

cmd_hook_pretooluse() {
  local input fp
  input="$(cat)"
  if [ "$HAS_JQ" -eq 1 ]; then
    fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)"
  else
    fp="$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
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
  case "$fp" in
    */design-log/*|"") : ;;   # method bookkeeping or missing path → allowed
    *)
      if [ -f "$DL/FOCUS.md" ] && ! grep -qE '^[[:space:]]*- .*🔄' "$DL/FOCUS.md" 2>/dev/null; then
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

cmd_hook_stop() {
  cat >/dev/null 2>&1 || true
  [ -d "$DL" ] || exit 0
  local untriaged=0
  if [ -f "$DL/INBOX.md" ]; then
    untriaged="$(grep -cE '^[[:space:]]*- \[ \]' "$DL/INBOX.md" 2>/dev/null || true)"; untriaged=${untriaged:-0}
  fi
  hooklog "Stop (inbox_untriaged=$untriaged)"
  # auto-refresh of the cross-project dashboard: regenerate the HTML at end of turn (always fresh).
  # No args → uses the config (KEEL_DASHBOARD_ROOTS / dashboard.roots / cwd). Writes to <GLOBAL_DIR>/dashboard/.
  python3 "$PLUGIN_ROOT/scripts/dashboard.py" >/dev/null 2>&1 || true
  # BLOCKING sweep (FM2 "lose nothing"): do not end the turn with untriaged captures.
  # Anti-loop escape: the model may mark them DEFERRED ('- [ ]' → '- [>]') → they no longer count.
  if [ "${untriaged:-0}" -gt 0 ] 2>/dev/null; then
    local r="📥 Design-Log: ${untriaged} untriaged item(s) in design-log/INBOX.md. BEFORE ending: triage each one (move it → TODO.md/TO_FIX.md or trash it) OR, if a user decision is needed, mark it DEFERRED by changing '- [ ]' to '- [>]'. Then end."
    if [ "$HAS_JQ" -eq 1 ]; then
      jq -n --arg r "$r" '{decision:"block",reason:$r}' 2>/dev/null || true
    else
      python3 -c 'import json,sys;print(json.dumps({"decision":"block","reason":sys.argv[1]}))' "$r" 2>/dev/null || true
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
encode_path() { printf '%s' "${1//\//__}"; }
marker_path() { printf '%s/session-%s.json' "$LOCKS_DIR" "$1"; }
lock_path()   { printf '%s/%s.lock' "$LOCKS_DIR" "$(encode_path "$1")"; }

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
    local mf lf markers='[]' locks='[]'
    mf=$(ls "$LOCKS_DIR"/session-*.json 2>/dev/null || true)
    [ -n "$mf" ] && markers=$(jq -s . $mf 2>/dev/null || echo '[]')
    lf=$(ls "$LOCKS_DIR"/*.lock 2>/dev/null || true)
    [ -n "$lf" ] && locks=$(jq -s . $lf 2>/dev/null || echo '[]')
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
  local uid now host file
  uid=$(uuidgen); now=$(iso_now); host=$(hostname -s 2>/dev/null || hostname)
  file=$(marker_path "$uid")
  cat > "$file" <<EOF
{
  "uid": "$uid",
  "type": "exclusive",
  "startedAt": "$now",
  "host": "$host",
  "lockedFiles": []
}
EOF
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
    cat > "$lf" <<EOF
{ "owner_uid": "$uid", "file": "$f", "task": "shared session work", "createdAt": "$now" }
EOF
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
  cat > "$lf" <<EOF
{ "owner_uid": "$uid", "file": "$target", "task": "shared session work", "createdAt": "$now" }
EOF
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
  rm -f "$file"; printf 'OK: removed marker for uid %s\n' "$uid"
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

case "${1:-}" in
  guardian-block)        guardian_block ;;
  hook-sessionstart)     hooklog "SessionStart"; cmd_global_bootstrap >/dev/null 2>&1; guardian_block ;;
  hook-userpromptsubmit) cmd_hook_userpromptsubmit ;;
  hook-pretooluse)       cmd_hook_pretooluse ;;
  hook-posttooluse)      cmd_hook_posttooluse ;;
  hook-precompact)       cmd_hook_precompact ;;
  hook-stop)             cmd_hook_stop ;;
  learned-approve)       shift; cmd_learned_approve "$@" ;;
  learned-approve-clear) cmd_learned_approve_clear ;;
  global-dir)            cmd_global_dir ;;
  global-bootstrap)      cmd_global_bootstrap ;;
  detect-type)           detect_type; echo ;;
  north-star)            north_star ;;
  preflight)             cmd_preflight ;;
  status)                cmd_status ;;
  init)                  cmd_init ;;
  share)                 shift; cmd_share "$@" ;;
  add-file)              shift; cmd_add_file "$@" ;;
  release)               shift; cmd_release "$@" ;;
  end)                   shift; cmd_end "$@" ;;
  progress-check)        cmd_progress_check ;;
  method-check)          cmd_method_check ;;
  inbox-check)           cmd_inbox_check ;;
  focus-check)           cmd_focus_check ;;
  scaffold)              cmd_scaffold ;;
  *) echo "usage: lock.sh {guardian-block|hook-*|learned-approve[-clear]|global-dir|global-bootstrap|detect-type|north-star|preflight|status|init|share|add-file|release|end|progress-check|method-check|inbox-check|focus-check|scaffold}" >&2; exit 2 ;;
esac
