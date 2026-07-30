#!/usr/bin/env bash
# design-log-method — GUARDIAN + lossless hook logic (Fase 1)
# Bundled plugin script. Robusto per costruzione: gli hook non devono MAI far
# crashare la sessione → niente `set -e`; ogni lettura opzionale è guardata;
# i punti d'ingresso hook escono 0.
#
# Subcommands:
#   guardian-block          Assembla Tier1(core)+Tier2(tipo)+Tier3(NORTH_STAR)+obiettivo FOCUS -> stdout.
#   hook-sessionstart       SessionStart: stampa guardian-block su stdout (iniettato nel contesto).
#   hook-userpromptsubmit   UserPromptSubmit: cattura "segna" -> INBOX; re-inietta il guardian su /add-task.
#   detect-type             Stampa software|non-software (da PROJECT.md). [helper di test]
#   north-star              Stampa il blocco NORTH_STAR estratto da PROJECT.md. [helper di test]

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DL="$PROJECT_DIR/design-log"
HOOKLOG="$PROJECT_DIR/.claude-designlog-hooks.log"

if command -v jq >/dev/null 2>&1; then HAS_JQ=1; else HAS_JQ=0; fi

# Log osservabile: ogni hook che scatta lascia una riga (ora UTC) → il test verifica QUI.
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
  echo "=== 🧭 GUARDIAN — tieni SEMPRE presente (contesto · obiettivo · principi) ==="
  echo
  if [ -f "$PLUGIN_ROOT/principi/core.md" ]; then cat "$PLUGIN_ROOT/principi/core.md"; echo; fi
  if [ "$type" = "software" ]; then
    if [ -f "$PLUGIN_ROOT/principi/software.md" ]; then cat "$PLUGIN_ROOT/principi/software.md"; echo; fi
  else
    if [ -f "$PLUGIN_ROOT/principi/non-software.md" ]; then cat "$PLUGIN_ROOT/principi/non-software.md"; echo; fi
  fi
  local ns; ns="$(north_star)"
  if [ -n "$ns" ]; then echo "## 🎯 NORTH_STAR — questo progetto"; echo "$ns"; echo; fi
  if [ -f "$DL/FOCUS.md" ]; then
    local fl; fl="$(grep -m1 -E '^[[:space:]]*- .*🔄' "$DL/FOCUS.md" 2>/dev/null)"
    if [ -n "$fl" ]; then echo "## 🔄 Obiettivo corrente (FOCUS)"; echo "$fl"; fi
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
  if printf '%s' "$prompt" | grep -qiE '(^|[[:space:]])segna([[:space:]]|:|$)' 2>/dev/null; then
    seg="yes"
    mkdir -p "$DL" 2>/dev/null
    [ -f "$DL/INBOX.md" ] || printf '# 📥 INBOX — Cattura grezza (da triagiare)\n\n## Da triagiare\n\n' > "$DL/INBOX.md"
    # togli il placeholder *(vuoto)* se presente, altrimenti resta accanto alle catture
    if grep -qE '^[[:space:]]*\*\(vuoto\)\*[[:space:]]*$' "$DL/INBOX.md" 2>/dev/null; then
      grep -vE '^[[:space:]]*\*\(vuoto\)\*[[:space:]]*$' "$DL/INBOX.md" > "$DL/INBOX.md.tmp" 2>/dev/null && mv "$DL/INBOX.md.tmp" "$DL/INBOX.md"
    fi
    local today oneline; today="$(date +%Y-%m-%d 2>/dev/null)"; oneline="$(printf '%s' "$prompt" | tr '\n' ' ')"
    printf -- '- [ ] [%s] (cattura "segna") %s\n' "$today" "$oneline" >> "$DL/INBOX.md"
    ctx="✅ Cattura-segna: la richiesta è GIÀ stata scritta in design-log/INBOX.md dall'hook (R.15). NON riscriverla tu — è già catturata. Trattala SOLO come voce da triagiare (non da fare adesso)."
  fi
  # NB: il refresh del guardian a inizio-task NON è più qui (lo slash-command /add-task
  # viene espanso → l'hook non vede la stringa). Lo gestisce la skill `guardian` (model-level)
  # + gli hook SessionStart / SessionStart-compact.
  local preview; preview="$(printf '%s' "$prompt" | tr '\n' ' ' | cut -c1-70 2>/dev/null)"
  hooklog "UserPromptSubmit (segna=$seg) «${preview}»"
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
  # Enforce SOLO su progetti serviti dal metodo (esiste design-log/).
  [ -d "$DL" ] || { hooklog "PreToolUse (no design-log) → ALLOW"; exit 0; }
  # (i) R.1 — marker di sessione obbligatorio.
  if ! ls "$PROJECT_DIR"/.locks/session-*.json >/dev/null 2>&1; then
    deny "Design-Log (R.1): nessuna sessione attiva in .locks/. Esegui /startsession prima di modificare file."
  fi
  # (iii) R.17 — lavoro FUORI da design-log/ richiede un obiettivo in corso in FOCUS.
  case "$fp" in
    */design-log/*|"") : ;;   # bookkeeping del metodo o path assente → consentito
    *)
      if [ -f "$DL/FOCUS.md" ] && ! grep -qE '^[[:space:]]*- .*🔄' "$DL/FOCUS.md" 2>/dev/null; then
        deny "Design-Log (R.17): nessun obiettivo in corso in FOCUS.md. Porta il lavoro in FOCUS (o usa /add-task) prima di implementare."
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
  # snapshot lossless dell'obiettivo corrente PRIMA che il compattamento tagli
  if [ -f "$DL/FOCUS.md" ]; then
    { printf '\n[%s] pre-compact (fullness=%s%%)\n' "$(date -u +%FT%TZ 2>/dev/null)" "${pct:-?}"
      grep -m1 -E '^[[:space:]]*- .*🔄' "$DL/FOCUS.md" 2>/dev/null || true
    } >> "$DL/.precompact-snapshot.md" 2>/dev/null || true
  fi
  if [ "$HAS_JQ" -eq 1 ]; then
    jq -n --arg m "🧭 Compattamento imminente (${pct:-?}%): il GUARDIAN si re-inietterà dopo. Valuta /savesession se hai lavoro non salvato." '{systemMessage:$m}' 2>/dev/null || true
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
  # auto-update del cruscotto: rigenera l'HTML a fine turno (sempre fresco).
  python3 "$PLUGIN_ROOT/scripts/cruscotto.py" "$PROJECT_DIR" >/dev/null 2>&1 || true
  # sweep BLOCCANTE (FM2 «non perdere nulla»): non chiudere il turno con catture non triagiate.
  # Escape anti-loop: il modello può marcarle RINVIATE ('- [ ]' → '- [>]') → non contano più.
  if [ "${untriaged:-0}" -gt 0 ] 2>/dev/null; then
    local r="📥 Design-Log: ${untriaged} voce/i non triagiata/e in design-log/INBOX.md. PRIMA di terminare: triaga ognuna (spostala → TODO.md/TO_FIX.md o cestina) OPPURE, se serve una decisione dell'utente, marcala RINVIATA cambiando '- [ ]' in '- [>]'. Poi termina."
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
  # Refresh GUARDIAN alla CREAZIONE di un nuovo design-log DATATO (= task partito).
  # Solo tool Write (creazione), non Edit → una sola iniezione per nuovo task.
  case "$fp" in
    */design-log/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md)
      if [ "$tname" = "Write" ]; then
        hooklog "PostToolUse (nuovo design-log: ${fp##*/}) → GUARDIAN refresh"
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

case "${1:-}" in
  guardian-block)        guardian_block ;;
  hook-sessionstart)     hooklog "SessionStart"; guardian_block ;;
  hook-userpromptsubmit) cmd_hook_userpromptsubmit ;;
  hook-pretooluse)       cmd_hook_pretooluse ;;
  hook-posttooluse)      cmd_hook_posttooluse ;;
  hook-precompact)       cmd_hook_precompact ;;
  hook-stop)             cmd_hook_stop ;;
  detect-type)           detect_type; echo ;;
  north-star)            north_star ;;
  *) echo "usage: lock.sh {guardian-block|hook-sessionstart|hook-userpromptsubmit|hook-pretooluse|hook-posttooluse|hook-precompact|hook-stop|detect-type|north-star}" >&2; exit 2 ;;
esac
