# Save Session Command

Salva il contesto della sessione corrente e sincronizza TUTTI i documenti della metodologia.

## Quando usarlo

- Conversazione lunga (15+ scambi)
- Prima di terminare la sessione
- Prima di cambiare contesto
- Dopo milestone importante
- Dopo debugging complesso

---

## STEP OBBLIGATORI

### STEP 1: Ri-leggi METHODOLOGY.md

Rileggi `design-log/METHODOLOGY.md` per rinfrescare la memoria su cosa devi fare.

**OUTPUT OBBLIGATORIO:**
```
📖 METHODOLOGY.md riletto
```

---

### STEP 1.5: 🧹 Sweep di completezza + triage INBOX (FORZANTE — BEHAVIORS R.15)

> Esiste perché il problema #1 del metodo è "richieste perse tra i turni": una cosa detta e non scritta sparisce. Qui, prima di chiudere, si **garantisce** che ogni richiesta della sessione sia atterrata in un file e che `INBOX.md` non resti pieno.

#### 1.5a: Sweep di completezza (rileggi la sessione)

Riscorri la conversazione di QUESTA sessione dall'inizio ed **estrai ogni cosa che l'utente ha chiesto, proposto o detto "segna"** — anche le minime, anche quelle non ancora fatte. Per ognuna verifica che sia tracciata in un file (`INBOX.md`, `TODO.md`, `TO_FIX.md`, `FOCUS.md`, o già chiusa in `DONE.md`/`FIXED.md`/`TO_TEST.md`).

Se qualcosa è **solo nella chat e in nessun file** → scrivilo ORA (INBOX se grezzo/non triagato, TODO/TO_FIX se è già lavoro chiaro). NON chiudere la sessione con richieste vive solo nella conversazione.

#### 1.5b: Triage INBOX (bloccante)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh inbox-check
```

Se `inbox_untriaged > 0`: **triaga ogni voce** di `INBOX.md` — per ognuna decidi `→ TODO.md` (con priorità), `→ TO_FIX.md` (bug), o `🗑 scartata` (con un perché). Una voce portata nel lavoro corrente va anche in `FOCUS.md`.

> **Regola «il triage SPOSTA» (2026-07-14)**: la voce triagata si **TRASFERISCE** nel file di destinazione (con provenienza, es. `(da INBOX, YYYY-MM-DD)`) e **si cancella da INBOX**. VIETATO annotarla sul posto: niente `- [x]`, niente «✅ fatto/triagiato → …» lasciati dentro INBOX. A fine triage `INBOX.md` contiene SOLO l'eventuale non-triagato rinviato esplicitamente dall'utente; altrimenti torna vuoto (`*(vuoto)*`). — È il pattern che il 2026-07-14 aveva trasformato INBOX in un ginepraio: il disegno era giusto, la regola era prosa non forzata.

Se `inbox_residue > 0` (dall'output di `inbox-check`): dentro INBOX ci sono righe che NON sono catture aperte `- [ ]` (voci spuntate, annotazioni, prosa) = **residui di triage-sul-posto** di sessioni passate → **spostali ORA** nel file giusto (TO_TEST/TODO/TO_FIX/DONE, con provenienza) e cancellali da INBOX.

⚠️ **Non procedere a STEP 2 con `inbox_untriaged > 0` o `inbox_residue > 0`**, a meno che l'utente non chieda esplicitamente di rinviare voci specifiche (in tal caso restano in INBOX con nota, e SOLO quelle).

**OUTPUT OBBLIGATORIO:**
```
🧹 Sweep completezza: [N richieste della sessione verificate] · [M scritte ora perché solo-in-chat | tutte già tracciate]
📥 Triage INBOX: [K voci SPOSTATE → TODO/TO_FIX/🗑 | INBOX già vuota] · [R residui spostati | nessun residuo] · inbox-check finale: inbox_untriaged=0 · inbox_residue=0
```

---

### STEP 2: Sync documenti (logica sync-dlogs)

Analizza la conversazione e sincronizza TUTTI i documenti.

#### 2a: Analizza conversazione

Identifica: task completati, decisioni prese, file modificati, design log coinvolti.

#### 2b: Verifica e aggiorna i file di tracking (split per-tipo)

Il tracking è **spezzato per tipo** (vedi METHODOLOGY "Il ciclo di vita del lavoro"). `PROGRESS.md` è solo un **indice leggero**; le voci vivono nei file split. **Distingui implementato da validato (BEHAVIORS R.16)** e instrada così:

- **Implementato ma NON validato** (build verde, l'utente non l'ha ancora visto) → la voce va in `TO_TEST.md` e resta in `FOCUS.md` con stato `🧪 da validare`. **NON** scriverlo in `DONE.md`/`FIXED.md`.
- **Validato** (l'utente l'ha visto funzionare in questa sessione) → SOLO ora entry ricca (What/How/Files/Notes) in `DONE.md`; se era un bug → `FIXED.md`. **Rimuovi la voce** da `TODO.md`/`TO_FIX.md`/`TO_TEST.md`.
- **Nuovo task aperto** → `TODO.md` (con priorità 🔴/🟡/🟢); bug nuovo → `TO_FIX.md`.
- **Refresh `FOCUS.md`**: la voce validata esce; se l'obiettivo corrente si libera, promuovi la prossima `⏸️` a `🔄`. FOCUS deve restare corto e veritiero.
- **Multisessione — traccia la provenienza in `FOCUS.md` (BEHAVIORS R.9)**: se questa sessione è girata **in parallelo** ad altre — cioè a `/startsession` c'erano già altri marker in `.locks/` (Caso B/C), oppure questa sessione era `shared`, oppure `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status` mostra **ora** altri marker attivi oltre al tuo — allora sessioni diverse scrivono **lo stesso `FOCUS.md` senza vedersi**, quindi:
  1. **Tagga OGNI voce** che scrivi o aggiorni in `FOCUS.md` con la sessione di provenienza, in coda alla voce: `— ⟨sessione {uid-corto} · {YYYY-MM-DD}⟩` (l'`{uid}` è il tuo, annunciato a `/startsession`; il session log di STEP 4 riporta lo stesso UID, così è rintracciabile). Senza il tag non si capisce da quale sessione arriva l'indicazione.
  2. Metti (o lascia, se un'altra sessione parallela l'ha già messo) **in cima a `FOCUS.md`**, su una riga sola, il marcatore esplicito:
     `> ⚠️ MULTISESSIONE {YYYY-MM-DD}: questa tornata ha avuto sessioni in parallelo — /startsession deve leggere TUTTE le sessioni di questa data (non solo l'ultima per nome).`
  3. **Ciclo di vita del marcatore**: marcatore + tag restano finché il lavoro parallelo non è **consolidato**. La prima `/savesession` **mono-sessione** successiva (nessun altro marker attivo) che rilegge e riconcilia `FOCUS.md` **rimuove** il marcatore e i tag ormai inutili. _(Questa clausola-3 è un'aggiunta di igiene, non richiesta esplicitamente: serve solo a non lasciare il marcatore in FOCUS per sempre.)_
- **Archiviazione a soglia**: se `DONE.md` o `FIXED.md` supera **~400 righe**, sposta le entry più **vecchie** in `progress.old.md`.
- Aggiorna `PROGRESS.md` (solo: "Last updated" + contatori TODO/bug/test + link). NIENTE entry-log in PROGRESS.md.

Checklist:
- [ ] "Last updated" di PROGRESS.md corrente + contatori aggiornati?
- [ ] In `DONE.md`/`FIXED.md` SOLO lavoro **validato** dall'utente (l'implementato-non-validato è in `TO_TEST.md` + `FOCUS.md` `🧪`)?
- [ ] Voci validate rimosse da `TODO.md`/`TO_FIX.md`/`TO_TEST.md` e da `FOCUS.md`?
- [ ] `FOCUS.md` aggiornato (UNA sola `🔄 in corso`, voci chiuse rimosse)?
- [ ] Nuovi TODO/bug instradati in `TODO.md`/`TO_FIX.md`?
- [ ] `DONE.md`/`FIXED.md` sotto ~400 righe (oltre → archiviati in `progress.old.md`)?
- [ ] File split mancanti (incl. `FOCUS.md`/`INBOX.md`) → creati da template (vedi METHODOLOGY)?

> Retro-compatibilità: se il progetto ha ancora `PROGRESS.md` monolitico (file split vuoti), questa è la sessione in cui inizia la migrazione organica: scrivi le NUOVE voci nei file split. Lo storico già in PROGRESS.md NON va spostato a forza.

#### 2b-bis: 🌿 POTA di FOCUS.md (FORZANTE — regola 2026-07-14 «FOCUS si pota a ogni chiusura»)

> Esiste perché FOCUS, se si APPENDE e basta, diventa un secondo TODO e smette di focalizzare (incidente 2026-07-14: FOCUS ginepraio; diagnosi condivisa con l'utente: il disegno era giusto, la regola era prosa non forzata). Qui la condizione è verificata da **script** e l'azione è **bloccante**.

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh focus-check
```

Leggi `focus_lines` / `focus_bloat` (soglia `focus_bloat_threshold`, default 40 righe):

- **`focus_bloat=no`** → FOCUS entro soglia. Rifinisci comunque (è la pota ordinaria del 2b): le voci chiuse/validate ESCONO (lo storico scende nel **session log** di STEP 4), resta UNA sola `🔄 in corso` + le voci in volo/da validare essenziali.
- **`focus_bloat=yes`** → ⛔ **POTA OBBLIGATORIA prima di procedere**: sposta nel session log (STEP 4) tutto lo storico e le voci già tracciate altrove (TO_TEST/TODO/DONE — in FOCUS basta il puntatore, non il racconto); in FOCUS restano SOLO l'obiettivo corrente + le voci in volo. Poi **ri-esegui `focus-check`**: deve dare `focus_bloat=no`. NON proseguire a STEP 3 con `focus_bloat=yes`.
- **Eccezione multisessione**: se `FOCUS.md` è lockato da un'altra sessione attiva, la pota si **RIMANDA** con nota esplicita nel session log («FOCUS non potabile: lockato da {uid}») — la farà la prima `/savesession` mono-sessione (stessa logica del marcatore MULTISESSIONE, punto 3 sopra).

**OUTPUT OBBLIGATORIO:**
```
🌿 Pota FOCUS: focus_lines=[N] · focus_bloat=[no | yes → potato, re-check: focus_lines=[M], focus_bloat=no] · [K voci scese nel session log | nessuna da spostare | RIMANDATA: FOCUS lockato da {uid}]
```

#### 2c: Verifica e aggiorna Design Log (se esiste)

Checklist:
- [ ] Implementation Results aggiornato?
- [ ] Implementation Plan spuntato?
- [ ] Status corretto?

#### 2d: Verifica e aggiorna issues/_INDEX.md (se necessario)

Checklist:
- [ ] Nuove issue create durante la sessione?
- [ ] Status issue aggiornati?

**OUTPUT OBBLIGATORIO:**
```
🔄 Sync documenti:
✅ Tracking - DONE.md/FIXED.md: [N entry] · TODO.md/TO_FIX.md/TO_TEST.md: [N] · PROGRESS.md indice: [aggiornato | in sync] · progress.old.md: [N archiviate | -]
✅ Design log [nome] - [aggiornato | gia' in sync | nessuno]
✅ Issues - [aggiornato | gia' in sync]
```

Se qualcosa era fuori sync, mostra cosa e' stato corretto:
```
❌ DONE.md - mancava entry per [task] → AGGIORNATO
❌ DONE.md - oltre ~400 righe → [N] entry vecchie spostate in progress.old.md
```

---

### STEP 3: Estrai apprendimenti/regole emerse, classifica, instrada

Rifletti sulla sessione e identifica TUTTE le nuove regole comportamentali e lezioni tecniche emerse.

Chiediti:
- Ho scoperto un pattern tecnico riutilizzabile?
- Ho fatto un errore che non devo ripetere?
- Ho scoperto una preferenza dell'utente?
- Ho trovato una soluzione a un problema che potrebbe ripresentarsi?
- È emersa una regola comportamentale nuova (su come Claude deve comportarsi)?

Se ci sono entry, **classificale** e **instradale** secondo BEHAVIORS Regola 14. **NON scrivere mai in BEHAVIORS.md o METHODOLOGY.md.**

#### 3a: Classificazione automatica

Per ogni entry, applica euristica:

**Locale vs Globale — PRINCIPIO vs FATTO:**
- **Globale (cross-progetto)** SOLO se l'entry è un **PRINCIPIO universale di *come si lavora / come si costruisce***, vero sempre per natura e indipendente dal tool/progetto (es. «se non funziona non risolvere a caso: alza i log e traccia il flusso, atteso vs reale»; «compila ≠ funziona»; «verifica, non assumere»; «una causa dedotta per esclusione va testata col mezzo più economico»).
- **Locale al progetto** se l'entry è un **FATTO/gotcha specifico** — anche se "tecnicamente generale / riusabile":
  - Contiene path/nomi propri/integrazioni/convenzioni del progetto, OPPURE
  - È un fatto su una singola API/tool/libreria (es. «`hooks/hooks.json` di un plugin si auto-carica»; il quirk di una singola libreria) — **un fatto specifico resta locale anche se lo useranno più progetti**: le memorie locali si **recuperano** cross-progetto quando servono.
- **Cestino (non si scrive)** se l'entry è a riuso quasi-nullo: un incidente irripetibile, troppo specifico per ripresentarsi.
- **Default conservativo: locale** se incerto.
- ⚠️ **NON usare il conteggio «≥2 progetti»** (criterio fallace, abbandonato 2026-07-30): il numero di progetti non rende nulla globale. Regola secca: **GLOBAL = principio · LOCAL = fatto specifico**.

**Tipo (per entry locali):**
- **Regola comportamentale** (su come Claude deve comportarsi nel progetto) → `BEHAVIORS_LOCAL.md`
- **Contesto/convenzione/decisione operativa** (workflow, naming, deploy, tensioni architetturali, scope modificato) → `PROJECT_UPDATES.md`
- **Lezione tecnica/pattern** (su come funziona qualcosa nel progetto, incl. gotcha niche mono-progetto) → `LEARNED.md`

**Dominio (per entry globali) → un FILE in `~/.claude-method/LEARNED_GLOBAL/`** (dal 2026-06-05; si sceglie per tipo di conoscenza, non per progetto di origine):
- Swift/iOS/macOS/Catalyst/AVFoundation/Xcode/StoreKit → `software-apple.md`
- web/backend/JS/TS/Next/React/Astro/Node/Python-backend/DB/auth/SaaS/cloud → `software-web.md`
- git/bash/tooling/build/architettura cross-repo/ML-OCR/ffmpeg/cross-language → `software-general.md`
- estetica/UX/spacing/contrasto/typography/controlli → `design.md`
- analisi/citazioni/letteratura/dataset → `research.md` (crearlo se non esiste)
- stile/voce/audience/editing → `writing.md` (crearlo se non esiste)
- workflow/metodo/comunicazione/lavoro-con-agenti cross-domain → `general.md`
- preferenze utente **trasversali a tutti i progetti** → `preferenze.md` (NON preferenze di un solo progetto/suite)

**Sotto-sezione (dentro il file dominio):**
- `### Pattern Tecnici` — pattern riusabile
- `### Errori da Non Ripetere` — anti-pattern, errore già fatto
- `### Soluzioni Riutilizzabili` — soluzione completa a problema ricorrente
(`general.md`/`preferenze.md`/`design.md` possono avere meno sotto-sezioni; seguire la struttura esistente del file.)

#### 3b: Mostra classificazione e chiedi conferma

**OUTPUT OBBLIGATORIO:**
```
📝 Nuove regole/lezioni emerse in questa sessione:

1. [LOCALE/Comportamentale] "<testo entry>"
   → BEHAVIORS_LOCAL.md / Regole Comportamentali

2. [LOCALE/Contesto] "<testo entry>"
   → PROJECT_UPDATES.md / Contesto / Convenzioni del Progetto

3. [GLOBALE/software-web/Errori da Non Ripetere] "<testo entry>"
   → ~/.claude-method/LEARNED_GLOBAL/software-web.md / Errori da Non Ripetere

4. [LOCALE/Lezione tecnica] "<testo entry>"
   → LEARNED.md / Pattern Tecnici

Confermi questa classificazione? (sì / correggi: numero → nuovo target)
```

**Se nessuna entry**:
```
🧠 Nessun nuovo apprendimento o regola emersi in questa sessione.
```

#### 3c: Aspetta conferma e scrivi

🛑 **CHECKPOINT** — non procedere finché l'utente non conferma o corregge.

Dopo conferma, scrivi ogni entry nel file giusto, sezione giusta.

**OUTPUT OBBLIGATORIO:**
```
✍️  Entry scritte:
✅ BEHAVIORS_LOCAL.md: 1 entry in Regole Comportamentali
✅ PROJECT_UPDATES.md: 1 entry in Contesto / Convenzioni del Progetto
✅ LEARNED.md: 1 entry in Pattern Tecnici
✅ ~/.claude-method/LEARNED_GLOBAL/software-web.md: 1 entry in Errori da Non Ripetere
```

**MAI scrivere in BEHAVIORS.md o METHODOLOGY.md.** Se durante la sessione l'utente ha esplicitamente chiesto modifiche al metodo (BEHAVIORS o METHODOLOGY del meta-progetto), quelle vanno fatte come task esplicito (`/add-task`), non da `/savesession`.

---

### STEP 4: Crea session log

Genera timestamp formato `YYYY-MM-DD-HH-MM`.
Crea file `design-log/sessions/[timestamp].md` con la struttura completa (vedi METHODOLOGY.md).

**OUTPUT OBBLIGATORIO:**
```
📝 Session log creato:
✅ File: design-log/sessions/[timestamp].md
```

---

### STEP 5: Rimuovi marker di sessione

Identifica e rimuovi il marker creato da QUESTA sessione in `/startsession`. Tutte le operazioni passano da `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`, auto-approvato.

#### 5a: Identifica il proprio UID

L'UID è stato annunciato da `/startsession` di questa stessa conversazione (Caso A o B di STEP 0.5). Recuperalo dal contesto.

**Se non lo trovi nel contesto** (es. conversazione compattata o read-only mode):
- Esegui `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status` per vedere i marker presenti (con `host` + `startedAt`)
- Chiedi all'utente: "Quale è il tuo? (oppure 'nessuno' se eri in read-only mode)"
- Aspetta risposta prima di procedere

#### 5b: Verifica stato del marker e rimuovilo

Prima di rimuovere, esegui `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status` e leggi il tuo marker. Se `type` è ancora `shared` o `lockedFiles` non è vuoto:
⚠️ **ATTENZIONE**: sostituisci `{uid}` con l'UID reale PRIMA di lanciare il comando. `rm -f` fallisce silenziosamente se il file non esiste — quindi un `{uid}` letterale non darebbe errore ma non rimuoverebbe nulla. Usa la variabile espansa e **verifica** la rimozione.

```bash
# Sostituisci MYUID con il tuo UID reale (lo hai annunciato in /startsession)
MYUID="IL-TUO-UID-REALE"
MARKER=".locks/session-${MYUID}.json"

if [ ! -f "${MARKER}" ]; then
  echo "⚠️ MARKER NON TROVATO: ${MARKER} — verifica UID corretto"
  ls .locks/
  exit 1
fi

rm "${MARKER}"

# Verifica post-rm
if [ -f "${MARKER}" ]; then
  echo "❌ RIMOZIONE FALLITA: ${MARKER} esiste ancora"
  exit 1
fi

echo "✅ Marker rimosso: ${MARKER}"
```

**Se il comando stampa `⚠️ MARKER NON TROVATO` o `❌ RIMOZIONE FALLITA`**, fermati e segnala all'utente — NON passare al STEP 7 con output di successo fake.

**Se eri in READ-ONLY MODE** (Caso C di startsession): NON rimuovere nulla — non hai creato marker.

**Se eri in SHARED MODE**: l'utente dovrebbe aver già eseguito `/stopsharedsession` prima di `/savesession`. Se trovi ancora `lockedFiles` non vuoti nel tuo marker, segnalalo:
```
⚠️ Marker ancora SHARED con file lockati: [...]
   Eseguire /stopsharedsession PRIMA di /savesession.
```
**FERMATI e segnala all'utente.**

Altrimenti rimuovi:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh end <uid>
```

**Se eri in READ-ONLY MODE** (Caso C di startsession): NON eseguire `end` — non hai creato marker.

#### 5c: Includi UID nel session log

Nel session log creato a STEP 4, aggiungi in cima (dopo l'header):
```markdown
**Session UID**: {uid}
**Marker type at close**: {exclusive | shared | read-only}
```
Così rileggendo i log si capisce se in quel periodo c'erano sessioni concorrenti.

**OUTPUT OBBLIGATORIO:**
```
🔓 Marker rimosso: .locks/session-{uid}.json
   (oppure: ⏭️  Read-only mode — nessun marker da rimuovere)
```

---

### STEP 6: Riepilogo finale

**OUTPUT OBBLIGATORIO:**
```
✅ SESSIONE SALVATA

🆔 UID: {uid} — marker rimosso ({exclusive|shared|read-only})
📁 Session log: design-log/sessions/[timestamp].md
🔄 Sync: [N] documenti aggiornati, [M] gia' in sync
✍️  Entry instradate:
   - BEHAVIORS_LOCAL.md: [N] entry
   - PROJECT_UPDATES.md: [N] entry
   - LEARNED.md (locale): [N] entry
   - ~/.claude-method/LEARNED_GLOBAL/<dominio>.md: [N] entry

Contenuto salvato:
- Active skills: [lista breve]
- Next steps: [primo step]

Per riprendere, usa /startsession (leggera' la sessione piu' recente per nome,
BEHAVIORS, BEHAVIORS_LOCAL, LEARNED locale, LEARNED_GLOBAL e PROJECT_UPDATES automaticamente).
```

**Promemoria importante:** se hai aggiornato un file nella dir globale (`$GLOBAL_DIR/LEARNED_GLOBAL/` — risolta da `lock.sh global-dir`, default `~/.claude-method`, override `KEEL_GLOBAL_DIR`) **e** quella dir è un repo git, considera di committare e pushare:
```bash
GLOBAL_DIR="$(${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh global-dir)"
cd "$GLOBAL_DIR" && git rev-parse --git-dir >/dev/null 2>&1 && git add . && git commit -m "Update LEARNED_GLOBAL: <breve descrizione>" && git push
```
(La dir auto-bootstrappata dallo standalone potrebbe **non** essere un repo git: in tal caso niente commit, i file restano solo su disco. Il push richiede un remote configurato.)

---

## Template Session Log (Riferimento)

Il file deve contenere queste sezioni (vedi METHODOLOGY.md per dettagli):

1. **Session Summary** - Cosa e' stato fatto
2. **CRITICAL SECTIONS**:
   - Active Skills & Methodologies
   - Procedure State
   - What We Tried That Didn't Work
   - User Preferences Discovered
3. **Context Snapshot**:
   - Currently Working On
   - Key Decisions Made
   - Problems Encountered
4. **Handoff Notes**:
   - Immediate Next Steps
   - Blockers / Waiting On
   - Don't Forget
5. **Files Modified This Session**

---

## Checklist di verifica per l'utente

Dopo che Claude esegue `/savesession`, verifica:

- [ ] Ha riletto METHODOLOGY.md?
- [ ] Ha fatto lo sweep di completezza (ogni richiesta della sessione finita in un file) e triagato `INBOX.md` **SPOSTANDO** le voci fuori (fino a `inbox_untriaged=0` **e** `inbox_residue=0` — niente annotazioni «✅ fatto» lasciate dentro)?
- [ ] Ha scritto in DONE/FIXED SOLO lavoro **validato** dall'utente (implementato-non-validato → TO_TEST + FOCUS 🧪)?
- [ ] Ha eseguito la **pota di FOCUS** (2b-bis): `focus_bloat=no` al re-check (o pota RIMANDATA con nota perché FOCUS era lockato da un'altra sessione)?
- [ ] Ha aggiornato `FOCUS.md` (voci chiuse rimosse, UNA sola 🔄 in corso, storico sceso nel session log)?
- [ ] Ha instradato le voci nei file split (DONE/FIXED/TODO/TO_FIX/TO_TEST) e aggiornato PROGRESS.md indice + contatori?
- [ ] Ha archiviato in progress.old.md se DONE.md/FIXED.md superavano ~400 righe?
- [ ] Ha sincronizzato design log (se esiste)?
- [ ] Ha sincronizzato issue (se necessario)?
- [ ] Ha estratto le entry, mostrato la classificazione, e chiesto conferma?
- [ ] Ha instradato le entry in BEHAVIORS_LOCAL.md / PROJECT_UPDATES.md / LEARNED.md / il file dominio giusto in LEARNED_GLOBAL/ secondo la classificazione confermata (criterio PRINCIPIO vs FATTO: globale solo i principi universali, i fatti specifici restano locali)?
- [ ] **NON ha scritto in BEHAVIORS.md o METHODOLOGY.md**?
- [ ] Ha creato il session log con tutte le sezioni?
- [ ] Ha rimosso il marker `.locks/session-{uid}.json` (o spiegato perché no, read-only)?
- [ ] Ha mostrato riepilogo finale (incluso conteggio entry per file)?

Se manca qualcosa, Claude non ha seguito il comando correttamente.
