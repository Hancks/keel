# Start Session Command

Carica il contesto del progetto all'inizio di ogni sessione.

## QUESTO COMANDO È OBBLIGATORIO

L'utente DEVE invocare `/startsession` all'inizio di ogni sessione.
Se non lo fa, Claude DEVE chiederlo prima di fare qualsiasi altra cosa.

---

## STEP OBBLIGATORI

### STEP 0: Preflight `jq`

Tutte le operazioni sui marker passano dallo script `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`. Lo script usa `jq` come tool primario con fallback `python3` interno (silenzioso, niente prompt aggiuntivi). Il preflight verifica solo lo stato di `jq`. *(Nota permessi: un plugin non può auto-approvarsi i Bash. Per evitare i prompt su ogni invocazione di `lock.sh`, l'utente aggiunge un allow-rule nel proprio settings — vedi README «Permissions» — o approva «don't ask again» al primo prompt.)*

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh preflight
```

OUTPUT:
```
🔧 Preflight: jq:OK
```
Oppure, se manca:
```
🔧 Preflight: jq:MISSING
⚠️  jq non in PATH. Si consiglia: brew install jq
   Continuo col fallback python3 interno.
```

---

### STEP 0.4: Memoria globale — risolvi + auto-bootstrap (standalone, NON blocca)

keel è **standalone**: la memoria globale cross-progetto (`LEARNED_GLOBAL.md` index + cartella `LEARNED_GLOBAL/`) vive in una dir **risolta da `lock.sh`** — default `~/.claude-method`, override con l'env `KEEL_GLOBAL_DIR`. A differenza del vecchio metodo command-based, qui la dir **NON è un pre-requisito bloccante**: se manca viene **auto-creata** (index + 6 domini); se non è creabile (FS read-only / permessi), keel **degrada a solo-locale** e prosegue.

Il bootstrap gira già silenziosamente all'avvio (hook `SessionStart` → `global-bootstrap`). Qui lo si esegue **esplicito e idempotente**, e si risolve la dir da usare nel resto della sessione (letture/scritture LEARNED_GLOBAL):

```bash
GLOBAL_DIR="$(${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh global-dir)"
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh global-bootstrap
test -f "$GLOBAL_DIR/LEARNED_GLOBAL.md" && echo "global:OK ($GLOBAL_DIR)" || echo "global:LOCAL-ONLY"
```

**Se OK:**
```
🌍 Preflight global: $GLOBAL_DIR OK (auto-bootstrap idempotente · override: KEEL_GLOBAL_DIR)
```

**Se LOCAL-ONLY (degrado previsto, NON un errore):**
```
🌍 Preflight global: dir globale non creabile ($GLOBAL_DIR) → keel prosegue in SOLO-LOCALE
   (memoria cross-progetto disattivata per questa sessione; il resto del metodo funziona)
```

**Prosegui in ENTRAMBI i casi.** Nel resto del comando, dove compare `~/.claude-method/LEARNED_GLOBAL/…`, intendi **`$GLOBAL_DIR/LEARNED_GLOBAL/…`** (la dir risolta qui sopra). Solo-locale = degrado, non stop.

---

### STEP 0.5: Sentinel di sessione (lock cooperativo)

Verifica e crea il marker che identifica questa sessione. Serve a sapere — anche da altre sessioni Claude attive sullo stesso repo — che cosa sta succedendo. Va eseguito **PRIMA** di qualsiasi altra operazione di lettura/scrittura sul progetto.

#### 0.5a: Censisci marker esistenti

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status
```

Restituisce JSON `{markers: [...], file_locks: [...]}`. Schema di ogni marker:
```json
{
  "uid": "...",
  "type": "exclusive" | "shared",
  "startedAt": "ISO 8601 UTC",
  "host": "...",
  "lockedFiles": []
}
```

`.locks/` vive nella **root del repo** (NON in `design-log/`) ed è in `.gitignore`. Lo script lo crea automaticamente se manca.

#### 0.5b: Decidi modalità in base ai marker trovati

**Caso A — Nessun marker presente:**
Crea il proprio marker `exclusive`:
```bash
# SESSION_UID, non UID: in zsh UID è read-only → `UID=$(...)` crasha (bad math expr) e non cattura
SESSION_UID=$(${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh init); echo "$SESSION_UID"
```

OUTPUT:
```
🟢 Nessuna sessione attiva — creo marker EXCLUSIVE
✅ .locks/session-{uid}.json
🆔 UID: {uid}
```

**Caso B — Solo marker `shared` esistenti:**
Calcola l'unione dei `lockedFiles` di tutti i marker shared + dei file `.lock` per-file (dal JSON di `lock.sh status`).

OUTPUT:
```
🔄 [N] sessione/i SHARED attiva/e:
  • UID xxx (host yyy, started zzz) — files: a, b
  • UID www (host kkk, started qqq) — files: c
🔒 File lockati (unione): a, b, c

Creo comunque il MIO marker EXCLUSIVE (per entrare in modalità shared
serve esplicito /startsharedsession).
⚠️ NON modifico nessun file presente nell'unione dei lockati.
```
Poi crea il marker come nel Caso A:
```bash
# SESSION_UID, non UID: in zsh UID è read-only → `UID=$(...)` crasha (bad math expr) e non cattura
SESSION_UID=$(${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh init); echo "$SESSION_UID"
```

**Caso C — Almeno un marker `exclusive` (oltre a eventuali shared):**
⛔ Un'altra sessione esclusiva è già attiva. NON creare alcun marker.

OUTPUT:
```
⛔ SESSIONE ESCLUSIVA GIÀ ATTIVA — entro in READ-ONLY MODE
Marker rilevato:
  • UID xxx (host yyy, started zzz, type: exclusive)

⚠️ Per il resto di questa sessione:
  • NON creo un marker mio
  • NON modifico ALCUN file (no Edit/Write/Bash con effetti)
  • Posso solo leggere, spiegare, rispondere

Se sai che la sessione è orfana (Claude crashato), rimuovi
manualmente il marker e riavvia /startsession:
  rm .locks/session-{uid}.json
```

#### 0.5c: Memorizza il proprio UID nella conversazione

Annota e **ribadisci nel riepilogo finale (STEP 4)** il PROPRIO `uid`. Serve a:
- `/savesession` per rimuovere il marker giusto (`lock.sh end <uid>`)
- `/startsharedsession` / `/stopsharedsession` per modificare il proprio `lockedFiles` (passato come `--uid <uid>`)

---

### STEP 1: Verifica struttura COMPLETA

**Scaffold (standalone keel):** se `design-log/` **non esiste** (progetto nuovo mai inizializzato con keel), esegui PRIMA:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh scaffold
```
Crea l'intera struttura `design-log/` — i file-metodo `BEHAVIORS.md`/`METHODOLOGY.md` come **symlink al plugin** (niente `~/.claude-method`) + tutti i template per-progetto (FOCUS/INBOX/TODO/TO_FIX/TO_TEST/DONE/FIXED/progress.old/PROGRESS/PROJECT/BEHAVIORS_LOCAL/PROJECT_UPDATES/LEARNED/issues). Idempotente. Poi prosegui con la verifica sotto.

Verifica che esistano TUTTE queste directory e file.
Se qualcosa manca, CREALO (per `PROJECT_UPDATES.md`, `BEHAVIORS_LOCAL.md`, `FOCUS.md`, `INBOX.md` crea con template vuoto — vedi METHODOLOGY "Template dei file split").

Per `FOCUS.md`/`INBOX.md` la verifica è scriptata (migrazione organica, idempotente):
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh method-check
```
- `verdict=METHOD_OK` → entrambi presenti, prosegui.
- `verdict=METHOD_MIGRATE` → **crea i file mancanti** dal template (FOCUS = `## In volo` + `*(vuoto)*`; INBOX = `## Da triagiare` + `*(vuoto)*`), poi prosegui. La presenza dei file È il marker di migrazione.

**Checklist da verificare:**
- `design-log/`
- `design-log/sessions/`
- `design-log/issues/`
- `design-log/PROJECT.md`
- `design-log/PROJECT_UPDATES.md` ← contesto/convenzioni/decisioni operative specifici del progetto (creato vuoto se manca)
- `design-log/BEHAVIORS_LOCAL.md` ← regole comportamentali specifiche del progetto (creato vuoto se manca)
- `design-log/FOCUS.md` ← 🎯 obiettivo corrente (creato da template se manca — migrazione organica)
- `design-log/INBOX.md` ← 📥 cattura grezza (creato da template se manca — migrazione organica)
- `design-log/PROGRESS.md` ← indice leggero (contatori + link ai file split)
- `design-log/TODO.md` / `TO_FIX.md` / `TO_TEST.md` ← lavoro corrente (creati da template se mancano)
- `design-log/DONE.md` / `FIXED.md` ← completato recente (creati da template se mancano)
- `design-log/progress.old.md` ← archivio storico (creato vuoto se manca)
- `design-log/METHODOLOGY.md`
- `design-log/BEHAVIORS.md` ← CRITICO: regole comportamentali generali
- `design-log/LEARNED.md` ← memoria locale del progetto
- `design-log/issues/_INDEX.md`
- almeno un file `design-log/sessions/YYYY-MM-DD-HH-MM.md` (la sessione più recente per nome)

**OUTPUT OBBLIGATORIO:**
```
📁 Verifica struttura:
✅ design-log/
✅ design-log/sessions/
✅ design-log/issues/
✅ PROJECT.md
✅ PROJECT_UPDATES.md
✅ BEHAVIORS_LOCAL.md
✅ FOCUS.md · INBOX.md (method-check: [METHOD_OK | METHOD_MIGRATE → creati])
✅ PROGRESS.md (indice)
✅ TODO.md · TO_FIX.md · TO_TEST.md · DONE.md · FIXED.md · progress.old.md (split tracking)
✅ METHODOLOGY.md
✅ BEHAVIORS.md
✅ LEARNED.md
✅ issues/_INDEX.md
✅ sessions/[file più recente per nome]
```

Se qualcosa manca, mostra:
```
❌ [file/cartella] → CREATO
```

---

### STEP 1.7: 🚦 GATE migrazione/lettura tracking (FORZANTE — non skippabile)

> Questo gate esiste perché la regola "leggi il TODO fino in fondo" come semplice prosa veniva saltata (vedi `BEHAVIORS.md` Regola 1: *"non segui la metodologia se non sei forzato"*). Incidente reale 2026-06-02: PROGRESS.md monolitico da 1022 righe, lette solo le prime 170, `## TODO` in coda (riga 936) saltato. Qui la condizione è verificata da **script** e l'azione è **BLOCCANTE**, non affidata alla buona volontà.

Esegui:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh progress-check
```

Interpreta il campo `verdict`:

- **`verdict=MIGRATED`** → tracking già split. Procedi: in STEP 3 leggerai `TODO.md` · `TO_FIX.md` · `TO_TEST.md` **per intero**.
- **`verdict=PROGRESS_MISSING`** → progetto nuovo/senza PROGRESS. Procedi (STEP 1 ha creato i template).
- **`verdict=MONOLITH_SMALL`** → `PROGRESS.md` è monolitico ma piccolo (≤ `threshold` righe). NON serve migrare ora, MA in STEP 3 **leggi `PROGRESS.md` PER INTERO** (Done e Todo stanno lì; il Todo può essere in coda). Suggerisci all'utente la migrazione quando comodo.
- **`verdict=MIGRATE_REQUIRED`** → ⛔ **STOP. Migrazione OBBLIGATORIA prima di continuare.** È un monolite grande (> `threshold` righe) che tiene il lavoro corrente in coda: leggerlo solo in cima fa saltare il TODO. **NON** proseguire a STEP 2+ e **NON** produrre il riepilogo STEP 4 finché non hai migrato.

  Procedura di migrazione (eseguila **TU**, con giudizio — non esiste auto-slicer affidabile per formati eterogenei):
  1. **Leggi `PROGRESS.md` PER INTERO**, a blocchi con offset (file grande → una sola Read si tronca). Devi vedere ogni sezione, incluso il `## TODO` in fondo.
  2. Spezza in (conserva OGNI voce — niente perdite; verifica contando le entry `### ` prima/dopo):
     - `DONE.md` ← voci `### <data>` di lavoro completato **recente**.
     - `progress.old.md` ← voci completate **più vecchie** (archivio storico).
     - `FIXED.md` ← bug risolti (`✅ RISOLTO …`).
     - `TO_FIX.md` ← bug ancora **aperti**.
     - `TO_TEST.md` ← "da validare a runtime".
     - `TODO.md` ← tutto il **lavoro da fare** (sezione `## TODO`, priorità 🔴/🟡/🟢). **È il file a priorità di lettura.**
     - `PROGRESS.md` ← riscrivilo come **indice leggero**: contatori + link ai file split + "Stato rapido" + Quick Links.
  3. **Ri-esegui `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh progress-check`**: deve dare `verdict=MIGRATED`. Solo allora prosegui.

**OUTPUT OBBLIGATORIO:**
```
🚦 Gate tracking: verdict=[…] · PROGRESS.md [N] righe · split_populated=[yes|no]
[se MIGRATE_REQUIRED] → migrazione eseguita: DONE([N]) · progress.old([N]) · FIXED([N]) · TO_FIX([N]) · TO_TEST([N]) · TODO([N]); re-check ⇒ MIGRATED ✅
[altrimenti] → nessuna migrazione necessaria
```

---

### STEP 1.8: 🎯 FOCUS-first + INBOX surface (BEHAVIORS R.15/R.17)

> `FOCUS.md` (obiettivo corrente) si legge **per PRIMO** — il lavoro parte da lì, non dal backlog né dall'ultimo messaggio in chat. `INBOX.md` può contenere richieste catturate ma non ancora triagate da sessioni precedenti: vanno **fatte emergere** subito.

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh focus-check
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh inbox-check
```

- **`focus-check`**:
  - `verdict=FOCUS_OK` → **leggi `FOCUS.md` PER INTERO** ora. È la base del riepilogo (STEP 4) e del "prossimo passo".
  - `verdict=FOCUS_EMPTY` → FOCUS esiste ma è vuoto: nessun obiettivo corrente fissato. Nel riepilogo proponi di popolarlo (dal primo 🔴 di TODO).
  - `verdict=FOCUS_MISSING` → STEP 1 doveva crearlo; crealo ora da template, poi prosegui.
  - Leggi anche `focus_lines`/`focus_bloat` (regola 2026-07-14 «FOCUS si pota»): se `focus_bloat=yes` (oltre `focus_bloat_threshold`, default 40 righe) → **segnala nel riepilogo** «⚠️ FOCUS oltre soglia ([N] righe) → va potato: lo forza `/savesession` (STEP 2b-bis)». A inizio sessione NON si riscrive FOCUS (si legge); la pota è compito della chiusura.
- **`inbox-check`**: se `inbox_untriaged > 0`, **leggi `INBOX.md`** e tieni quelle voci pronte da segnalare nel riepilogo (vanno triagate, non dimenticate). Se `inbox_residue > 0` (righe che non sono catture aperte: voci spuntate, annotazioni «✅ fatto»): sono **residui di triage-sul-posto** — regola 2026-07-14 «il triage SPOSTA» — segnalali nel riepilogo: andranno SPOSTATI nel file giusto al prossimo triage (`/savesession` lo forza).
- **Rilevazione MULTISESSIONE (BEHAVIORS R.9)**: mentre leggi `FOCUS.md`, controlla se contiene il marcatore `⚠️ MULTISESSIONE {data}` (lo scrive `/savesession` quando la tornata ha avuto sessioni **in parallelo** che scrivono lo stesso FOCUS senza vedersi). **Se c'è**: l'ultima sessione **per nome** NON basta e può nascondere il lavoro/handoff più importante (es. è una demo chiusa 20 min dopo la sessione che conta) → **memorizza le date indicate** e in **STEP 3 leggi TUTTE le sessioni di quelle date**, non solo l'ultima. I tag `⟨sessione … · {data}⟩` sulle singole voci di FOCUS dicono da quale sessione viene ciascuna indicazione.

**OUTPUT OBBLIGATORIO:**
```
🎯 FOCUS: [obiettivo corrente — voce 🔄 in corso, oppure "vuoto"] (focus-check: [FOCUS_OK|FOCUS_EMPTY|FOCUS_MISSING→creato] · [N] righe[ · ⚠️ oltre soglia → pota a /savesession])
📥 INBOX: [N] voci non triagiate [→ elenco breve] (oppure: vuota) [· ⚠️ [R] residui annotati da SPOSTARE al prossimo triage]
🧵 MULTISESSIONE: [rilevato marcatore per {date} → in STEP 3 leggo TUTTE le sessioni di quelle date | nessun marcatore, leggo solo l'ultima per nome]
```

---

### STEP 2: Leggi BEHAVIORS + BEHAVIORS_LOCAL + LEARNED locale + LEARNED_GLOBAL + PROJECT_UPDATES

Leggi SEMPRE questi cinque file per primi (ordine importante):

1. `design-log/BEHAVIORS.md` — regole comportamentali generali del metodo
2. `design-log/BEHAVIORS_LOCAL.md` — regole comportamentali specifiche di questo progetto
3. `design-log/LEARNED.md` — memoria di apprendimento locale del progetto
4. **Memoria globale cross-progetto** in `~/.claude-method/LEARNED_GLOBAL/` (dal 2026-06-05 è una cartella per dominio, NON più un file unico):
   - SEMPRE: `~/.claude-method/LEARNED_GLOBAL.md` (index/manifest) + `LEARNED_GLOBAL/general.md` + `LEARNED_GLOBAL/preferenze.md`
   - CONDIZIONALE (in base al Tech Stack di PROJECT.md, letto a STEP 2.5/3): carica SOLO i file dominio pertinenti — `software-apple.md` (Swift/iOS/macOS), `software-web.md` (web/backend/cloud), `software-general.md` (qualsiasi codice/git/bash/build), `design.md` (UX/visuale), `research.md`/`writing.md` se esistono. La mappa stack→domini è nell'index.
   - Poiché lo stack si conosce solo dopo PROJECT.md, leggi ORA index + general + preferenze; carica i domini condizionali **subito dopo** aver letto PROJECT.md (STEP 2.5/3). Un progetto non-software carica solo index + general + preferenze.
5. `design-log/PROJECT_UPDATES.md` — contesto/convenzioni/decisioni operative specifici di questo progetto (può essere vuoto, è ok)

**OUTPUT OBBLIGATORIO:**
```
📖 File base letti:
✅ BEHAVIORS.md ([N] righe) ← REGOLE COMPORTAMENTALI GENERALI
✅ BEHAVIORS_LOCAL.md ([N] righe) ← REGOLE COMPORTAMENTALI LOCALI [oppure: VUOTO]
✅ LEARNED.md ([N] righe) ← MEMORIA LOCALE
✅ LEARNED_GLOBAL.md (index) + general.md + preferenze.md ← MEMORIA GLOBALE (sempre)
✅ LEARNED_GLOBAL/<domini condizionali>.md ← caricati per stack: [elenco, es. software-apple] [oppure: solo sempre-caricati]
✅ PROJECT_UPDATES.md ([N] righe) ← CONTESTO/CONVENZIONI/DECISIONI OPERATIVE LOCALI [oppure: VUOTO]
```

---

### STEP 2.5: 🔍 GATE - Leggi PROJECT.md e valuta se vuoto

Leggi `design-log/PROJECT.md` e VALUTA se contiene informazioni reali sul progetto.

**PROJECT.md è considerato VUOTO se:**
- Non esiste
- Esiste ma ha 0 righe di contenuto
- Esiste ma contiene SOLO: titolo (`# ...`), placeholder (`[...]`), template non compilato, commenti, righe vuote
- Non ci sono almeno 2 righe con contenuto informativo reale che descrivano il progetto

**OUTPUT OBBLIGATORIO:**
```
🔍 Valutazione PROJECT.md:
📄 Stato: [POPOLATO | VUOTO]
```

**Se POPOLATO** → vai a STEP 3 (flusso normale)
**Se VUOTO** → vai a STEP P1 (Project Discovery Mode) ⚠️ IL FLUSSO NORMALE SI INTERROMPE

---

## 🔍 PROJECT DISCOVERY MODE

> Questo blocco si attiva SOLO se PROJECT.md è vuoto.
> Il flusso normale di /startsession è INTERROTTO fino al completamento.

### STEP P1: Analizza il repository

Esamina la directory del progetto per capire se esiste già codice/contenuto.

**Criteri per "progetto esistente":**
- Ci sono file sorgente (*.py, *.js, *.ts, *.swift, *.go, *.rs, *.java, *.c, *.cpp, etc.)
- Ci sono file di progetto (package.json, Cargo.toml, requirements.txt, Makefile, *.xcodeproj, etc.)
- Ci sono asset, documenti, configurazioni significative
- Qualsiasi struttura di progetto riconoscibile OLTRE ai file del design-log system

**Criteri per "progetto nuovo":**
- La directory contiene SOLO i file del design-log system (.claude/, design-log/, CLAUDE.md)
- Nessun file sorgente, nessuna struttura di progetto

**OUTPUT OBBLIGATORIO:**
```
🔍 Analisi repository:
📂 Tipo: [PROGETTO ESISTENTE | PROGETTO NUOVO]
📄 Evidenze: [elenco breve di cosa è stato trovato o "solo file design-log"]
```

**Se PROGETTO ESISTENTE** → vai a STEP E1
**Se PROGETTO NUOVO** → vai a STEP N1

---

### Ramo A: PROGETTO ESISTENTE

#### STEP E1: Analisi profonda

Claude deve raggiungere una comprensione sufficiente a gestire il progetto IN AUTONOMIA.

**Analizzare IN PROFONDITÀ:**

1. **Struttura directory** - layout cartelle, organizzazione moduli
2. **Stack tecnologico** - linguaggi, framework, dipendenze (da package manager, config files)
3. **Architettura** - pattern (MVC, MVVM, microservizi, etc.), entry point, flusso dati
4. **Codice sorgente** - leggere i file principali, capire la logica core, i modelli dati, le API
5. **Configurazioni** - build system, CI/CD, env, database
6. **Test** - framework test, copertura, come eseguirli
7. **Documentazione esistente** - README, commenti, doc inline

**Se il progetto è grande (>50 file sorgente):**
Usare Agent per parallelizzare l'analisi in sub-task:
- Agent 1: struttura + dipendenze + config
- Agent 2: architettura + codice core + modelli dati
- Agent 3: test + docs + build system

**OUTPUT OBBLIGATORIO:**
```
🔬 Analisi profonda completata:

📂 **Struttura**: [descrizione layout]
🛠️ **Stack**: [linguaggi, framework, dipendenze principali]
🏗️ **Architettura**: [pattern, moduli principali, flusso dati]
📝 **Codice core**: [file principali e loro ruolo]
⚙️ **Config/Build**: [come si builda, si esegue, si deploya]
🧪 **Test**: [framework, come eseguirli]
📖 **Docs**: [documentazione trovata]
```

---

#### STEP E2: Presenta deduzioni

Mostra all'utente cosa ha dedotto e chiedi conferma.

**OUTPUT OBBLIGATORIO:**
```
🧠 Ecco cosa ho dedotto dal progetto:

📂 **Nome progetto**: [dedotto o da confermare]
🎯 **Scopo**: [cosa fa il progetto, che problema risolve]
👥 **Target**: [a chi è destinato]
🛠️ **Stack tecnologico**: [elenco completo]
🏗️ **Architettura**: [descrizione pattern e organizzazione]
📋 **Funzionalità principali**:
   1. [feature 1]
   2. [feature 2]
   3. [feature N]

📊 **Stato attuale del progetto**:
   - [cosa sembra completato]
   - [cosa sembra in corso]
   - [cosa sembra mancante o da fare]

❓ **Domande/dubbi**:
   - [cosa non è chiaro dall'analisi]
   - [dove servono chiarimenti]
```

---

#### 🛑 STEP E3: FERMATI - Chiedi conferma

**OUTPUT OBBLIGATORIO:**
```
🛑 CHECKPOINT - CONFERMA DEDUZIONI

Le deduzioni sopra sono corrette? Correggimi dove sbaglio.
In particolare conferma:
- Scopo del progetto
- Target
- Funzionalità principali
- Stato attuale

Eventuali correzioni o integrazioni?
```

**NON procedere finché l'utente non conferma o corregge.**

---

#### STEP E4: Popola file

Dopo conferma, scrivi:
- **PROJECT.md** - compilato con tutte le informazioni confermate
- **PROGRESS.md** - con DONE (lavoro già fatto dedotto) e TODO (cose da fare dedotte), solo se confermati

**OUTPUT OBBLIGATORIO:**
```
📝 File aggiornati:
✅ PROJECT.md - compilato ([N] righe)
✅ PROGRESS.md - aggiornato con [N] DONE e [N] TODO dedotti
```

**→ Vai a STEP 3 (riprendi flusso normale)**

---

### Ramo B: PROGETTO NUOVO

#### STEP N1: Domande guidate

Claude pone domande adattive per definire il progetto. Set minimo, ma Claude DEVE aggiungere domande contestuali in base al tipo di progetto che emerge.

**OUTPUT OBBLIGATORIO:**
```
🆕 Nuovo progetto! Ho bisogno di alcune informazioni per partire.

❓ Domande:

1. **Scopo**: Cosa deve fare questo progetto? Che problema risolve?
2. **Target**: A chi è destinato? (utenti finali, sviluppatori, team interno, etc.)
3. **Funzionalità principali**: Quali sono le feature core che vuoi?
4. **Tecnologia**: Hai preferenze su linguaggio/framework? Vincoli tecnici?
5. **Interfaccia**: Serve un'interfaccia utente? Di che tipo? (web, mobile, CLI, desktop, nessuna)
6. **Vincoli**: Deadline, dipendenze esterne, integrazioni con altri sistemi?
```

Claude DEVE aggiungere domande extra se il contesto lo richiede. Esempi:
- Se l'utente menziona "app mobile" → domande su piattaforma (iOS/Android/cross), design system
- Se menziona "API" → domande su autenticazione, rate limiting, documentazione
- Se menziona "gioco" → domande su genere, piattaforma, engine
- Se non è un progetto software → domande sulla natura specifica (ricerca, documentazione, design, etc.)

---

#### 🛑 STEP N2: FERMATI - Aspetta risposte

**OUTPUT OBBLIGATORIO:**
```
🛑 CHECKPOINT

Attendo le tue risposte. Rispondi come preferisci - anche in forma libera,
non devi seguire la numerazione.
```

**NON procedere finché l'utente non risponde.**

---

#### STEP N3: Popola file

Dopo le risposte, Claude:
1. Riassume ciò che ha capito e chiede conferma rapida
2. Dopo conferma, scrive:
   - **PROJECT.md** - compilato con tutte le informazioni
   - **PROGRESS.md** - con TODO iniziale basato sulle funzionalità descritte

**OUTPUT OBBLIGATORIO:**
```
📝 File creati:
✅ PROJECT.md - compilato ([N] righe)
✅ PROGRESS.md - piano iniziale con [N] TODO
```

**→ Vai a STEP 3 (riprendi flusso normale)**

---

## FLUSSO NORMALE (continua dopo STEP 2.5 o dopo Discovery)

### STEP 3: Leggi file rimanenti

Leggi i file restanti nell'ordine specificato:

1. `design-log/PROJECT.md` - (ri-leggi se appena popolato dalla discovery)
2. **Stato del progresso (split per-tipo)**:
   - `design-log/PROGRESS.md` (indice: contatori + link)
   - `design-log/TODO.md`, `TO_FIX.md`, `TO_TEST.md` - lavoro corrente — **LEGGILI PER INTERO** (priorità, bug aperti, da testare). `TODO.md` è il file a **priorità di lettura**.
   - `design-log/DONE.md`, `FIXED.md` - completato recente (NON leggere `progress.old.md`: è archivio, solo on-demand)
   - **NOTA (post-GATE STEP 1.7):** la migrazione del monolite è già stata gestita dal gate. Qui può residuare solo `verdict=MONOLITH_SMALL` (monolite piccolo non migrato): in quel caso leggi `PROGRESS.md` **PER INTERO** — Done e Todo stanno lì, il Todo può essere in coda. **MAI** leggere solo la parte alta di un PROGRESS.md monolitico né dedurre lo stato dalla sola testa del file.
3. **Sessione/i più recente/i** - Di norma risolvi l'ultima con `ls -1 design-log/sessions/[0-9]*.md | sort | tail -1` e leggila. **MA se STEP 1.8 ha rilevato il marcatore `⚠️ MULTISESSIONE {data}` in `FOCUS.md`** (sessioni in parallelo su quella tornata, che scrivono lo stesso FOCUS senza vedersi): **NON fermarti all'ultima per nome** — leggi **TUTTE** le sessioni di quella/e data/e: `ls -1 design-log/sessions/{data}-*.md`. L'ultima per nome può essere una sessione parallela minore (es. una demo) e nascondere la sessione con il lavoro/handoff più importante. Incrocia i tag `⟨sessione …⟩` di FOCUS con l'`**Session UID**` in cima a ciascun session log per capire chi ha scritto cosa.
4. `design-log/METHODOLOGY.md` - Come lavorare
5. `design-log/issues/_INDEX.md` - Issue aperte

**OUTPUT OBBLIGATORIO:**
```
📖 File letti:
✅ PROJECT.md ([N] righe)
✅ Tracking - PROGRESS.md indice ([N]) · TODO/TO_FIX/TO_TEST ([N]/[N]/[N]) · DONE/FIXED ([N]/[N])
   (oppure, se non migrato: ✅ PROGRESS.md monolitico ([N] righe) ← FALLBACK, file split vuoti)
✅ sessions/[file/i letto/i] ([N] righe) ← ultima per nome, oppure TUTTE le sessioni della/e data/e se FOCUS segnala ⚠️ MULTISESSIONE
✅ METHODOLOGY.md ([N] righe)
✅ issues/_INDEX.md ([N] righe)
```

---

### STEP 3.5: Plan awareness (`.plan/`)

Verifica eventuali piani di coordinamento cross-progetto attivi nel sub corrente.

#### 3.5a: Crea `.plan/` se non esiste

```bash
mkdir -p .plan .plan/inbox
```
Best effort. Se `.plan/` esisteva già (anche vuota), `mkdir -p` non fa nulla. `.plan/inbox/` è la cartella delle note di handoff cross-progetto in arrivo (vedi 3.5f).

#### 3.5b: Lista plan attivi

```bash
ls -1 .plan/*.json 2>/dev/null
```

Esclude `.plan/archived/`.

**OUTPUT OBBLIGATORIO:**
```
📋 Plan attivi:
✅ <N> plan trovati: <list di plan_id>
   oppure
⏭️ Nessun plan attivo (zero overhead)
```

Se nessun plan → salta a STEP 4.

#### 3.5c: Per ogni plan, classifica i task del sub corrente

Per ogni `.plan/<plan_id>.json`:
1. Carica il JSON.
2. Identifica i task con `sub_path` = pwd assoluto del sub corrente. Per il match, normalizza i path (resolve simlink, no trailing slash).
3. Per ogni task del sub corrente:
   - **completed**: status = "completed" → mostra ✅
   - **in_progress**: status = "in_progress" → mostra 🔄 (suggerisci ripresa via design log artifact)
   - **pending**: verifica le dipendenze. Per ogni `dep_id` in `depends_on`:
     a. Trova il task con quell'`id` in `tasks[]` (anche se in altro sub)
     b. Path dell'artifact: `<dep.sub_path>/<dep.artifact>`
     c. Leggi il design log artifact (se esiste)
     d. Cerca header `Status: Implemented` (o `Status:** Implemented**`)
     e. Se trovato → la dipendenza è soddisfatta
   - Se TUTTE le dipendenze soddisfatte → 🟢 ready
   - Se almeno una non soddisfatta → ⏳ blocked (mostra quali)
4. Aggiorna opportunisticamente la copia locale del plan con gli status verificati (write idempotente di `<sub_path>/.plan/<plan_id>.json` con `status` e `started_at`/`completed_at` aggiornati). Se il task del sub corrente ha l'artifact con `Status: Implemented`, marca `completed` (con `completed_at`); se l'artifact esiste ma è `Implementing`/`Draft`, marca `in_progress` (con `started_at`).

#### 3.5d: Auto-archive

Se per il plan TUTTI i task (di tutti i sub, non solo del corrente) risultano `completed` (verificato via artifact, anche cross-sub):
1. Sposta `.plan/<plan_id>.json` in `.plan/archived/<plan_id>.json` nel sub corrente
2. Best-effort: tenta lo spostamento anche negli altri `sub_path` raggiungibili via filesystem locale
3. Output:
```
📦 Plan <plan_id> tutti i task completed → archiviato in .plan/archived/
```

#### 3.5e: Output del riepilogo plan

Per ogni plan attivo (non archiviato dopo 3.5d):
```
📊 Plan: <plan_id> — <title>
  Task in questo sub:
  ✅ <id_a>: <title> — completed
  🔄 <id_b>: <title> — in_progress (artifact: <path>)
  🟢 <id_c>: <title> — pronto (no deps pending)
  ⏳ <id_d>: <title> — bloccato da: <id_x> (sub <sub_x>)
```

#### 3.5f: Inbox handoff (`.plan/inbox/`)

Le note di handoff cross-progetto **in arrivo** vivono in `.plan/inbox/*.md` (convenzione 2026-06-07 — posto unico e prevedibile accanto ai plan, NON in `design-log/`). Elencale:
```bash
ls -1 .plan/inbox/*.md 2>/dev/null   # esclude .plan/inbox/archived/
```

**OUTPUT OBBLIGATORIO:**
```
📬 Inbox handoff: <N> note → <lista nomi file>
   (oppure: ⏭️ Inbox vuota)
```

Se ci sono note, **leggile** (sono brevi e indirizzate a questo sub) e tienine conto nel riepilogo (STEP 4) e nel prossimo passo suggerito. Una nota già consumata va spostata in `.plan/inbox/archived/` (best-effort) per non risegnalarla alle sessioni future.

---

### STEP 4: Genera riepilogo

Mostra all'utente che hai CAPITO il contesto.

**OUTPUT OBBLIGATORIO:**
```
🧠 **REGOLE COMPORTAMENTALI GENERALI** (da BEHAVIORS.md):
- [regola 1 critica]
- [regola 2 critica]
- [regola 3 critica]

📌 **REGOLE COMPORTAMENTALI LOCALI** (da BEHAVIORS_LOCAL.md):
- [regola comportamentale locale 1]
- [regola comportamentale locale 2]
- (se BEHAVIORS_LOCAL è vuoto: "⏭️ Nessuna regola comportamentale locale specifica per questo progetto")

🗂️ **CONTESTO / CONVENZIONI / DECISIONI OPERATIVE** (da PROJECT_UPDATES.md):
- [convenzione / decisione operativa 1]
- [convenzione / decisione operativa 2]
- (se PROJECT_UPDATES è vuoto: "⏭️ Nessun contesto locale specifico")

💡 **APPRENDIMENTI CHIAVE** (da LEARNED.md locale):
- [apprendimento 1 rilevante]
- [apprendimento 2 rilevante]

🌍 **APPRENDIMENTI GLOBALI RILEVANTI** (dai file dominio caricati in `~/.claude-method/LEARNED_GLOBAL/`):
- [apprendimento globale 1, dai domini pertinenti allo stack]
- [apprendimento globale 2]
- (mostra max 3-5 voci più rilevanti dai file dominio effettivamente caricati per questo progetto; indica anche quali domini sono stati caricati, es. "domini: general + preferenze + software-apple")

🆔 **Sessione**: UID `{uid}` — type `{exclusive|shared|read-only}` — marker `.locks/session-{uid}.json`

📂 **Progetto**: [nome e breve descrizione da PROJECT.md]
🛠️ **Stack**: [tecnologie da PROJECT.md]

🎯 **Obiettivo corrente (FOCUS.md)**: [voce `🔄 in corso` + criterio di "fatto" — oppure "nessuno fissato, da popolare"]
📥 **INBOX da triagiare**: [N voci → elenco breve | vuota]

📊 **Stato attuale**:
- Ultima sessione: [data dalla sessione piu' recente]
- Ultimo lavoro: [cosa dalla sessione piu' recente]
- Issue aperte: [numero da _INDEX.md]
- Prossima priorità: **[la voce `🔄 in corso` di FOCUS.md; se FOCUS è vuoto, il primo item 🔴 di TODO.md]** (post-GATE il tracking è migrato; se `MONOLITH_SMALL`, dal `## TODO` di `PROGRESS.md` letto PER INTERO). ⚠️ Il lavoro parte da FOCUS (R.17), non dallo "Stato rapido" né dall'ultimo messaggio in chat.

📝 **Dall'ultima sessione**:
- [punto chiave 1 da Handoff Notes]
- [punto chiave 2 da Handoff Notes]

📊 **Plan cross-progetto attivi** (da STEP 3.5, se presenti):
- <plan_id>: <N> task in questo sub (<N_done> completed, <N_progress> in_progress, <N_ready> pronti, <N_blocked> bloccati)
- (se nessun plan: omettere questa riga)

📬 **Inbox handoff** (da `.plan/inbox/`, se presenti):
- [nome nota]: [1 riga di sintesi + mittente]
- (se inbox vuota: omettere questa riga)

🎯 **Prossimo passo suggerito**: [azione specifica basata su TODO, Handoff, Inbox e Plan task pronti]
```

---

### 🛑 STEP 5: sprint.txt — se ESISTE parti in AUTOMATICO; se NON esiste, aspetta conferma

###STEP 5A: ESISTE SPRINT FILE → AUTO-START (NON si chiede conferma):

Se esiste un file `sprint.txt`, **leggilo per intero**.

Se contiene item, **parti SUBITO con l'esecuzione, SENZA chiedere conferma**: organizza il piano di esecuzione e lavora come se gli item fossero una richiesta inserita dall'utente via console (crea/aggiorna i file che devi aggiornare, applica la metodologia, procedi). L'auto-start è il comportamento **voluto**: la presenza di `sprint.txt` È già l'autorizzazione a partire.

⚠️ **NON** applicare qui il checkpoint di STEP 5B: con `sprint.txt` presente NON si aspetta conferma. (Se un singolo item richiede `/add-task` perché i requisiti non sono chiari, applica quella cerimonia per QUEL item — ma non fermare l'intero sprint.)

**OUTPUT OBBLIGATORIO:**
```
Procedo con lo sprint
```
Poi **procedi immediatamente** con il primo item (nessuna attesa di conferma).


Se non esiste il file sprint.txt allora:

###STEP 5B: NON ESISTE SPRINT FILE:
**OUTPUT OBBLIGATORIO:**
```
Procedo con [azione suggerita] o preferisci altro?
```

**NON procedere finché l'utente non conferma.**

---

## Differenza da /resumesession

| Comando | Scopo | Quando usarlo |
|---------|-------|---------------|
| `/startsession` | Carica sempre la sessione piu' recente per nome + auto-discovery se PROJECT vuoto | SEMPRE all'inizio |
| `/resumesession [file]` | Carica sessione specifica | Quando vuoi riprendere una sessione passata |

---

## Checklist di verifica per l'utente

Dopo che Claude esegue `/startsession`, verifica:

- [ ] Ha eseguito STEP 0 (preflight `jq`) e STEP 0.4 (risolto `$GLOBAL_DIR` via `lock.sh global-dir` + auto-bootstrap idempotente; degrado a solo-locale se non creabile, **senza bloccare**)?
- [ ] Ha eseguito STEP 0.5 (sentinel) e mostrato lo stato dei marker `.locks/`?
- [ ] Ha annunciato il PROPRIO UID (o ha dichiarato READ-ONLY MODE se non l'ha creato)?
- [ ] Ha mostrato la checklist della struttura (incluso PROJECT_UPDATES.md e BEHAVIORS_LOCAL.md)?
- [ ] Ha eseguito STEP 1.7 (gate `lock.sh progress-check`) e, se `MIGRATE_REQUIRED`, migrato PROGRESS.md nei file split (re-check `MIGRATED`) PRIMA di proseguire?
- [ ] Ha eseguito STEP 1.8 (`method-check`/`focus-check`/`inbox-check`), letto `FOCUS.md` per primo e fatto emergere le voci `INBOX.md` non triagiate — segnalando anche `focus_bloat=yes` (FOCUS oltre soglia → pota a /savesession) e gli eventuali `inbox_residue` (annotati-sul-posto da SPOSTARE)?
- [ ] Ha letto PER INTERO TODO.md/TO_FIX.md/TO_TEST.md e tratto la "Prossima priorità" da FOCUS (poi TODO), non dallo Stato rapido?
- [ ] Ha letto BEHAVIORS.md, BEHAVIORS_LOCAL.md, LEARNED.md, ~/.claude-method/LEARNED_GLOBAL.md e PROJECT_UPDATES.md?
- [ ] Ha valutato se PROJECT.md è vuoto o popolato?
- [ ] (Se vuoto) Ha analizzato il repo o fatto domande per nuovo progetto?
- [ ] (Se vuoto) Si è fermato a chiedere conferma delle deduzioni/risposte?
- [ ] (Se vuoto) Ha popolato PROJECT.md e PROGRESS.md dopo conferma?
- [ ] Ha mostrato quante righe ha letto per ogni file?
- [ ] Ha mostrato un riepilogo con regole comportamentali, regole locali, apprendimenti locali e globali?
- [ ] Si è fermato ad aspettare conferma finale?

Se manca qualcosa, Claude non ha seguito il comando correttamente.
