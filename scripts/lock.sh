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
#   hook-pretooluse         PreToolUse (Edit|Write): guardie hard-block (R.1 · R.17 · FM9 LEARNED).
#   learned-approve         FM9: scrive il marker di conferma che SBLOCCA la scrittura sui LEARNED.
#   learned-approve-clear   FM9: azzera il marker di conferma.
#   detect-type             Stampa software|non-software (da PROJECT.md). [helper di test]
#   north-star              Stampa il blocco NORTH_STAR estratto da PROJECT.md. [helper di test]

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DL="$PROJECT_DIR/design-log"
HOOKLOG="$PROJECT_DIR/.claude-designlog-hooks.log"
# Memoria globale cross-progetto: dir risolta da env KEEL_GLOBAL_DIR (default ~/.claude-method).
# Portabilità (Fase 4): chi non ha questa dir NON deve rompersi — le feature che la usano la
# bootstrappano (subcommand global-bootstrap, chiamato silenziosamente a SessionStart) o
# degradano a solo-locale se non è creabile.
GLOBAL_DIR="${KEEL_GLOBAL_DIR:-$HOME/.claude-method}"
# Marker di sessione + lock per-file del progetto corrente (usati dai comandi orchestratori).
LOCKS_DIR="$PROJECT_DIR/.locks"
# FM9: marker di conferma per la scrittura sui LEARNED (nonce + file approvati + scadenza).
LEARNED_MARKER="$PROJECT_DIR/.locks/learned-write-approved.json"

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

# FM9 — la scrittura su LEARNED è consentita SOLO se esiste un marker di conferma
# valido (non scaduto) che include il file bersaglio. Fail-safe: in ogni dubbio
# (marker assente/scaduto/illeggibile, python3 mancante) → NON approvato → deny.
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

# Scrive il marker di conferma FM9. Da chiamare SOLO dopo l'OK esplicito dell'utente
# sulla classificazione proposta dal distillatore. TTL default 30 min.
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
  echo "✅ learned-approve: ${#files[@]} file approvati per ${ttl} min → $LEARNED_MARKER"
}

cmd_learned_approve_clear() { rm -f "$LEARNED_MARKER" 2>/dev/null; echo "🧹 learned-approve azzerato"; }

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
  # (v) FM9 — scrittura sui LEARNED (locale + globale) consentita SOLO con conferma esplicita.
  case "$fp" in
    */design-log/LEARNED.md|*/LEARNED_GLOBAL/*)
      if ! learned_approved "$fp"; then
        deny "Design-Log (R.14/FM9): scrittura su LEARNED bloccata senza conferma. Fai proporre la classificazione dal distillatore (agent learned-distiller), falla CONFERMARE all'utente, poi sblocca con: lock.sh learned-approve \"$fp\". In dubbio la memoria NON si scrive."
      fi
      hooklog "PreToolUse ${fp##*/} (LEARNED, conferma OK) → ALLOW"
      exit 0
      ;;
  esac
  # (vi) Fase 2a — un design-log NON si marca "Approved/Implemented" senza una sezione
  # "## Antitesi": il rito di confutazione (agent adversarial-critic) non è saltabile in
  # silenzio. La skill giudica la qualità; questo hook garantisce che il rito ci sia.
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
        if ! printf '%s' "$newtext" | grep -qE '^#{2,}[[:space:]]*Antitesi' \
           && ! grep -qE '^#{2,}[[:space:]]*Antitesi' "$fp" 2>/dev/null; then
          deny "Design-Log (Fase 2a): stai marcando questo design 'Approved/Implemented' ma manca la sezione '## Antitesi'. Fai girare il confutatore (agent adversarial-critic), scrivi antitesi + sintesi nel design log, POI marca lo stato."
        fi
      fi
      ;;
  esac
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
  # auto-refresh del dashboard cross-progetto: rigenera l'HTML a fine turno (sempre fresco).
  # Nessun arg → usa la config (KEEL_DASHBOARD_ROOTS / dashboard.roots / cwd). Scrive in <GLOBAL_DIR>/dashboard/.
  python3 "$PLUGIN_ROOT/scripts/dashboard.py" >/dev/null 2>&1 || true
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

# --- Memoria globale cross-progetto: risoluzione + bootstrap (Fase 4, portabilità) ---
cmd_global_dir() { printf '%s\n' "$GLOBAL_DIR"; }

# Idempotente: crea lo scheletro della memoria globale se manca. Non sovrascrive file
# esistenti. Degrado graceful: se la dir non è creabile → avviso su stderr + exit 0
# (la feature userà solo la memoria LOCALE del progetto, design-log/LEARNED.md).
cmd_global_bootstrap() {
  local dir="$GLOBAL_DIR"
  if ! mkdir -p "$dir/LEARNED_GLOBAL" 2>/dev/null; then
    echo "⚠️ keel: impossibile creare $dir — memoria globale disattivata (resta solo design-log/LEARNED.md)." >&2
    return 0
  fi
  if [ ! -f "$dir/LEARNED_GLOBAL.md" ]; then
    cat > "$dir/LEARNED_GLOBAL.md" <<'EOF'
# LEARNED_GLOBAL — Index / Manifest

> Memoria condivisa cross-progetto del metodo (keel). Letta a inizio sessione; scritta SOLO
> tramite il distiller + conferma esplicita (hard-block FM9). Un file per **dominio** in
> `LEARNED_GLOBAL/`.

## Criterio di routing (PRINCIPIO vs FATTO)

Una voce sta qui SOLO se è un **PRINCIPIO universale** di *come si lavora / come si costruisce*
(vero sempre, indipendente dal tool). Ogni **FATTO/gotcha specifico** di un tool/API/progetto è
**LOCALE** (`<progetto>/design-log/LEARNED.md`) — le memorie locali si recuperano cross-progetto.
Riuso quasi-nullo → cestino. Regola secca: **GLOBAL = principio · LOCAL = fatto specifico.**

## Domini

- `general.md` — SEMPRE: metodo/workflow/debugging/comunicazione (cross-dominio)
- `preferenze.md` — SEMPRE: preferenze utente trasversali a tutti i progetti
- `software-general.md` — git/bash/tooling/build/architettura cross-repo/ML/ffmpeg
- `software-apple.md` — Swift/SwiftUI/iOS/macOS/Xcode/AVFoundation
- `software-web.md` — JS/TS/Next/React/Node/Python-backend/DB/auth/SaaS/cloud
- `design.md` — UX/visivo/prodotto

Caricamento condizionale per stack: sempre index + `general` + `preferenze`; i domini
software/design solo se pertinenti allo stack del progetto.
EOF
  fi
  local d
  for d in general preferenze software-general software-apple software-web design; do
    [ -f "$dir/LEARNED_GLOBAL/$d.md" ] || printf '# LEARNED_GLOBAL — %s\n\n> Principi universali del dominio «%s». Per ora vuoto: le voci le aggiunge il distiller (proposta + conferma).\n\n### Pattern Tecnici\n\n### Errori da Non Ripetere\n\n### Soluzioni Riutilizzabili\n' "$d" "$d" > "$dir/LEARNED_GLOBAL/$d.md"
  done
  # seed della config multi-root del dashboard (commentata): l'utente la popola quando vuole.
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
# Comandi orchestratori (standalone) — marker di sessione, gate del metodo,
# scaffolding di un progetto nuovo. Portati dal metodo comando-based e resi
# self-contained nel plugin (niente ~/.claude-method: i file-metodo vivono qui).
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

# Scaffolding STANDALONE: crea la struttura design-log/ di un progetto nuovo.
# I file-metodo (BEHAVIORS/METHODOLOGY) sono SYMLINK al plugin → niente ~/.claude-method.
# Gli altri file per-progetto sono creati da template SOLO se mancano (idempotente).
cmd_scaffold() {
  local DLD="$DL"
  mkdir -p "$DLD/sessions" "$DLD/issues" 2>/dev/null
  ln -sfn "$PLUGIN_ROOT/design-log/BEHAVIORS.md"   "$DLD/BEHAVIORS.md"
  ln -sfn "$PLUGIN_ROOT/design-log/METHODOLOGY.md" "$DLD/METHODOLOGY.md"
  [ -f "$DLD/PROJECT.md" ] || printf '# Project\n\n> Descrivi qui cos'\''è questo progetto, lo scopo, lo stack, l'\''architettura.\n> `/startsession` su PROJECT.md vuoto attiva il Project Discovery Mode.\n\n[Vuoto]\n' > "$DLD/PROJECT.md"
  [ -f "$DLD/BEHAVIORS_LOCAL.md" ] || printf '# Behaviors Local\n\n> Regole comportamentali specifiche di questo progetto. Lette ogni sessione insieme a BEHAVIORS.md.\n\n---\n\n## Regole Comportamentali\n\n[Vuoto]\n' > "$DLD/BEHAVIORS_LOCAL.md"
  [ -f "$DLD/PROJECT_UPDATES.md" ] || printf '# Project Updates\n\n> Contesto/convenzioni/decisioni operative specifici del progetto.\n\n---\n\n## Contesto / Convenzioni del Progetto\n\n[Vuoto]\n' > "$DLD/PROJECT_UPDATES.md"
  [ -f "$DLD/FOCUS.md" ] || printf '# 🎯 FOCUS — Obiettivo corrente\n\n> Letto per PRIMO ogni sessione. Le poche cose in volo ORA. UNA sola 🔄 in corso per volta.\n> Stati: 🔄 in corso · 🧪 implementato, da validare · ⏸️ in coda.\n\n## In volo\n\n*(vuoto)*\n' > "$DLD/FOCUS.md"
  [ -f "$DLD/INBOX.md" ] || printf '# 📥 INBOX — Cattura grezza (da triagiare)\n\n> Tutto ciò che l'\''utente dice "segna" entra QUI subito, prima di agire.\n\n## Da triagiare\n\n*(vuoto)*\n' > "$DLD/INBOX.md"
  [ -f "$DLD/PROGRESS.md" ] || printf '# Project Progress (indice)\n\n> Last updated: scaffold\n\n## Stato rapido\n- 🎯 Obiettivo corrente → [FOCUS.md](./FOCUS.md) · 📥 → [INBOX.md](./INBOX.md)\n- 📋 TODO aperti: 0 → [TODO.md](./TODO.md)\n- 🐛 Bug: 0 → [TO_FIX.md](./TO_FIX.md)\n- 🧪 Da validare: 0 → [TO_TEST.md](./TO_TEST.md)\n- ✅ → [DONE.md](./DONE.md) · 🔧 → [FIXED.md](./FIXED.md)\n- 🗄️ → [progress.old.md](./progress.old.md)\n\n## Quick Links\n- [PROJECT.md](./PROJECT.md) · [Sessions](./sessions/) · [Issues](./issues/_INDEX.md)\n' > "$DLD/PROGRESS.md"
  [ -f "$DLD/TODO.md" ]     || printf '# TODO - Da fare\n\n### 🔴 High Priority\n\n### 🟡 Medium Priority\n\n### 🟢 Low Priority / Ideas\n' > "$DLD/TODO.md"
  [ -f "$DLD/TO_FIX.md" ]   || printf '# TO_FIX - Bug da fixare\n\n### 🔴 CRITICO\n\n### 🟡 MEDIA\n\n### 🟢 BASSA\n' > "$DLD/TO_FIX.md"
  [ -f "$DLD/TO_TEST.md" ]  || printf '# TO_TEST - Implementato, da validare\n' > "$DLD/TO_TEST.md"
  [ -f "$DLD/DONE.md" ]     || printf '# DONE - Lavoro completato (recente)\n' > "$DLD/DONE.md"
  [ -f "$DLD/FIXED.md" ]    || printf '# FIXED - Bug risolti (recente)\n' > "$DLD/FIXED.md"
  [ -f "$DLD/progress.old.md" ] || printf '# Progress Archive\n\n> Archivio entry DONE/FIXED vecchie.\n' > "$DLD/progress.old.md"
  [ -f "$DLD/LEARNED.md" ]  || printf '# Learned - Memoria di Apprendimento (locale)\n\n> Conoscenza tecnica specifica di questo progetto. Letta a ogni /startsession.\n\n## Pattern Tecnici\n\n## Errori da Non Ripetere\n\n## Preferenze Utente\n\n## Soluzioni Riutilizzabili\n' > "$DLD/LEARNED.md"
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
