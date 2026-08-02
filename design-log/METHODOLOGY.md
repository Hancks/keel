# Design-Log Methodology - Guida Completa

> Questo file contiene la metodologia dettagliata. Per le istruzioni essenziali, vedi `CLAUDE.md` nella root.

## Overview

Questo progetto usa la **Design-Log Methodology** (ispirata a [Wix Engineering](https://www.wix.engineering/post/why-i-stop-prompting-and-start-logging-the-design-log-methodology)). Claude non è solo un coder, ma un **partner nel processo architetturale**.

## Core Principles

1. **Design Before You Implement**: Un design log deve essere creato e approvato PRIMA di scrivere codice.

2. **Immutable History**: Una volta iniziata l'implementazione, la sezione "Design" è FROZEN. Le modifiche vanno in "Implementation Results".

3. **The Socratic Method**: Per informazioni mancanti, FAI DOMANDE nel design log. Non assumere, chiedi.

4. **Traceable Implementation**: Se devii dal piano, documenta PERCHÉ in "Implementation Results".

---

## Struttura Completa delle Cartelle

```
./design-log/
├── PROJECT.md                          # Overview del progetto (stabile)
├── FOCUS.md                            # 🎯 Obiettivo corrente — letto per PRIMO ogni sessione
├── INBOX.md                            # 📥 Cattura grezza ("segna"), da triagiare
├── PROGRESS.md                         # Indice leggero → punta ai file sotto
├── TODO.md                             # Cose da fare (feature, miglioramenti) — backlog curato
├── TO_FIX.md                           # Bug da fixare
├── TO_TEST.md                          # IMPLEMENTATO ma non validato (attende l'occhio dell'utente)
├── DONE.md                             # Lavoro VALIDATO (recente)
├── FIXED.md                            # Bug VALIDATI (recente)
├── progress.old.md                     # Archivio sessioni vecchie
├── METHODOLOGY.md                      # Questo file
├── BEHAVIORS.md                        # Regole comportamentali per Claude
├── LEARNED.md                          # Competenze tecniche riutilizzabili
├── sessions/                           # Log delle sessioni
│   └── YYYY-MM-DD-HH-MM.md            # Sessioni (la più recente per nome è "latest")
├── issues/                             # Issue tracking
│   ├── _INDEX.md                       # Indice issue
│   └── {TYPE}-{NNN}-{slug}.md         # Singole issue
└── YYYY-MM-DD-feature-name.md          # Design decisions (immutabili dopo approvazione)
```

**Nota sulla struttura progress (split per-tipo):**
- `PROGRESS.md` è solo un **indice leggero**: header + contatori (TODO aperti, bug aperti, ultima sessione) + link ai file sotto. NON contiene più entry-log corpose.
- Il lavoro è suddiviso in file separati per tipo: `TODO.md` / `TO_FIX.md` / `TO_TEST.md` (lavoro corrente) e `DONE.md` / `FIXED.md` (completato recente, con entry ricche What/How/Files/Notes).
- `progress.old.md` è l'**archivio**: quando `DONE.md` o `FIXED.md` superano **~400 righe**, le entry più vecchie vengono spostate qui (mantiene i file di lavoro sotto il limite pratico di lettura di Claude).
- **Sempre attivo**: `/savesession` e `/add-task` instradano direttamente le voci nei file split (non in PROGRESS.md). Vedi sezione "Dopo Ogni Task".
- **Perché lo split** (motivo originale): impedire che un singolo file di progress cresca oltre il limite di lettura di Claude in una tool call (PROGRESS monolitico >~500-1500 righe → si tronca → `/startsession` perde pezzi).
- **Retro-compatibilità (lettura)**: `/startsession` legge i file split; se sono assenti o vuoti fa **fallback su `PROGRESS.md`** (progetti non ancora migrati continuano a funzionare e migrano organicamente al primo `/savesession`).
- **GATE forzante di migrazione (STEP 1.7 di `/startsession`)**: la retro-compatibilità sopra è *prosa* e veniva saltata (Claude legge solo la testa di un PROGRESS monolitico → perde il `## TODO` in coda; incidente 2026-06-02). Per renderla non-skippabile, `/startsession` esegue `.claude/scripts/lock.sh progress-check` che restituisce un `verdict` machine-readable: `MIGRATED` / `MONOLITH_SMALL` (leggi PROGRESS per intero) / `MIGRATE_REQUIRED` (⛔ migrazione **bloccante** verso i file split prima di proseguire, con re-check `MIGRATED` a conferma) / `PROGRESS_MISSING`. La detection è nello script (impossibile da falsare); lo slicing in file resta a Claude (serve giudizio per classificare le voci). Soglia monolite: `> 250` righe con sezioni `## DONE/TODO/TO_FIX` e ≥3 entry `### `.

**Nota sui design log attivi:** I file `YYYY-MM-DD-feature-name.md` con Status diverso da "Implemented" sono design in corso e vanno letti durante `/startsession` per mantenere contesto sulle decisioni architetturali in progress.

---

## Il ciclo di vita del lavoro (pipeline) — `INBOX → … → DONE`

> Introdotto 2026-06-24 (design log `2026-06-24-rafforzamento-metodo.md` nel meta-progetto). Nasce per tre debolezze reali: richieste perse tra i turni, TODO gonfio illeggibile, "implementato" scambiato per "fatto". Ogni voce di lavoro ha **una sola casa per volta**; lo spostamento tra le case è il flusso qui sotto.

```
   richiesta dell'utente / "segna X"
        │  ① CATTURA  — istantanea, PRIMA di agire           (BEHAVIORS R.15)
        ▼
   INBOX.md            grezzo, non ordinato
        │  ② TRIAGE  — a /add-task · su "go" a un task · on-demand · /savesession (bloccante)
        ├──────────────► 🗑 cestino (scartato con un perché)
        ▼
   TODO.md / TO_FIX.md   backlog completo, prioritizzato (🔴🟡🟢)
        │  ③ porto nel lavoro corrente
        ▼
   FOCUS.md            obiettivo ORA: poche voci, UNA sola 🔄 in corso   (BEHAVIORS R.17)
        │  implemento (tsc/build verde = IMPLEMENTATO, NON "fatto")
        ▼
   TO_TEST.md          implementato, attende l'occhio dell'utente
        │  ④ l'utente valida a video ✅                       (BEHAVIORS R.16)
        ▼
   DONE.md / FIXED.md   VALIDATO = fatto davvero
        │  archiviazione a ~400 righe
        ▼
   progress.old.md
```

### Tabella lifecycle (cosa contiene · quando ENTRA · quando/dove ESCE)

| File | Cosa contiene | Quando ENTRA una voce | Quando/dove ESCE |
|------|---------------|------------------------|------------------|
| `INBOX.md` | richieste/idee grezze appena catturate | appena l'utente chiede qualcosa o dice **"segna"** — *istantaneo, prima di agire* | al **triage** → `TODO`/`TO_FIX` o 🗑 |
| `FOCUS.md` | obiettivo corrente: poche voci in volo, **1 `🔄` in corso** | quando porto una voce di `TODO` nel lavoro attivo | quando la feature è **validata** (la chiusura va in `DONE`) |
| `TODO.md` | backlog completo prioritizzato | dal triage di `INBOX` o pianificazione diretta | quando entra in `FOCUS` (lavoro) o è validata → `DONE`; **rimozione forzata** alla chiusura |
| `TO_FIX.md` | bug aperti | triage / scoperta bug | quando fixato **e validato** → `FIXED` |
| `TO_TEST.md` | **implementato ma NON validato** (attende l'utente) | quando una feature/fix è implementata (build verde) e serve l'occhio dell'utente | quando l'utente valida → `DONE`/`FIXED`; la voce esce |
| `DONE.md` | feature **VALIDATE** | **solo dopo** validazione utente | archiviazione a ~400 righe → `progress.old` |
| `FIXED.md` | bug **VALIDATI** | **solo dopo** validazione utente | archiviazione → `progress.old` |
| `progress.old.md` | archivio storico | quando `DONE`/`FIXED` > ~400 righe | mai (archivio) |

### Le tre regole che reggono la pipeline (vedi BEHAVIORS.md)

- **Cattura-all'istante (R.15)**: ogni richiesta si **scrive prima di agire**. "segna" → `INBOX.md`. Vietato "me lo ricordo".
- **Done = validato (R.16)**: `tsc`/build verde = *implementato*, non *fatto*. In `DONE`/`FIXED` si entra **solo** dopo che l'utente l'ha visto funzionare (passaggio da `TO_TEST`).
- **Una feature alla volta + FOCUS-first (R.17)**: `FOCUS.md` si legge per primo; una sola voce `🔄 in corso` fino a validata.

### Testare = validare

`TO_TEST.md` **non** è più "da testare su device": è lo stato *"implementato, l'utente non l'ha ancora visto"*. Quando l'utente valida, la voce esce e confluisce in `DONE`/`FIXED`. **Non esiste** un file "TESTED" separato (sarebbe un altro file da svuotare).

---

## Template: PROJECT.md

```markdown
# [Project Name]

## Vision
What is this project? What problem does it solve? One paragraph max.

## Tech Stack
- Language: [e.g., TypeScript, Python]
- Framework: [e.g., Next.js, FastAPI]
- Database: [e.g., PostgreSQL, MongoDB]
- Other: [e.g., Redis, Docker]

## Architecture Overview
Brief description of how the system is organized.

## Key Directories
/src          - Main source code
/tests        - Test files
/docs         - Documentation

## Conventions
- Naming: [e.g., camelCase for functions, PascalCase for classes]
- Testing: [e.g., Jest, pytest]
- Git: [e.g., conventional commits]

## Getting Started
How to run the project locally (brief commands).
```

---

## Template: PROGRESS.md (indice leggero)

`PROGRESS.md` NON contiene più le entry-log: è solo un indice con contatori e link ai file split.

```markdown
# Project Progress (indice)

> Last updated: YYYY-MM-DD HH:MM
> Last session: [link to session file]

## Stato rapido
- 📋 TODO aperti: N → [TODO.md](./TODO.md)
- 🐛 Bug da fixare: N → [TO_FIX.md](./TO_FIX.md)
- 🧪 Da testare: N → [TO_TEST.md](./TO_TEST.md)
- ✅ Completato recente → [DONE.md](./DONE.md) · 🔧 Bug risolti → [FIXED.md](./FIXED.md)
- 🗄️ Archivio storico → [progress.old.md](./progress.old.md)

## Open Questions
- [ ] Question 1

## Quick Links
- [PROJECT.md](./PROJECT.md) · [Sessions](./sessions/) (la piu' recente per nome) · [Issues](./issues/_INDEX.md)
```

### Template dei file split

`FOCUS.md` (obiettivo corrente — letto per PRIMO ogni sessione):
```markdown
# 🎯 FOCUS — Obiettivo corrente

> Letto per PRIMO ogni sessione. Le poche cose in volo ORA. UNA sola 🔄 in corso per volta.
> Stati: 🔄 in corso · 🧪 implementato, da validare · ⏸️ in coda. "Fatto" = validato dall'utente a video.

## In volo
- 🔄 [feature] — criterio di fatto: [come si vede che funziona] — [link TODO/design log]
- ⏸️ [feature in coda]
```

`INBOX.md` (cattura grezza — "segna"):
```markdown
# 📥 INBOX — Cattura grezza (da triagiare)

> Tutto ciò che l'utente dice "segna", o chiede al volo, entra QUI subito, prima di agire.
> NON è la lista ufficiale: si triaga (→ TODO/TO_FIX o 🗑) a /add-task, on-demand, e a /savesession.

## Da triagiare
- [ ] [richiesta/idea grezza] (segnato: YYYY-MM-DD)
```

`TODO.md` (feature/miglioramenti):
```markdown
# TODO - Da fare

### 🔴 High Priority
#### [Task Name]
**What:** What needs to be done
**Why:** Why it's important
**How (proposed):** Initial thoughts
**Design log:** Link or "Needs design"

### 🟡 Medium Priority
### 🟢 Low Priority / Ideas
```

`TO_FIX.md` (bug aperti):
```markdown
# TO_FIX - Bug da fixare

### 🔴 CRITICO
### 🟡 MEDIA
### 🟢 BASSA
```

`TO_TEST.md` (implementato, da validare — l'utente non l'ha ancora visto):
```markdown
# TO_TEST - Implementato, da validare
- [ ] [cosa l'utente deve vedere funzionare] (da: [task/sessione/feature in FOCUS])
```

`DONE.md` (completato recente) e `FIXED.md` (bug risolti recenti) — entry ricche:
```markdown
# DONE - Lavoro completato (recente)

### [Date] - [Feature/Task Name]
**What:** Brief description
**How:** Technical approach, key decisions
**Files:** List of files created/modified
**Design log:** [Link if exists]
**Notes:** Gotchas, learnings
```

`progress.old.md` (archivio): stesso formato di DONE/FIXED, riceve le entry più vecchie quando DONE.md/FIXED.md superano ~400 righe.

---

## Template: Design Log

Per nuove feature o modifiche significative, crea `YYYY-MM-DD-feature-name.md`:

```markdown
# [Feature/Decision Name]

> Created: YYYY-MM-DD
> Status: Draft | Approved | Implementing | Implemented
> Author: [Human/Claude]

## Background
Context and motivation. Why this is needed now.

## Problem
Clear statement of what needs to be solved.

## Questions and Answers

> Use Socratic method: Ask questions, don't guess!

**Q:** [Question]
**A:** [Answer - keep both permanently]

## Design

> This section is FROZEN once implementation begins.

### Overview
High-level approach.

### Detailed Design
- Include specific file paths
- Include type signatures
- Include validation rules

## Implementation Plan

- [ ] Step 1: [description]
- [ ] Step 2: [description]
- [ ] Step 3: [description]

## Trade-offs

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| A | ... | ... | Chosen/Rejected |
| B | ... | ... | Chosen/Rejected |

**Rationale:** [Why this approach]

## Implementation Results

> Add notes here DURING implementation. Never modify Design section.

### [Date] - Notes
- Deviated from plan because: [reason]
- Discovered issue: [description]
- Actual files created: [list]
```

---

## Template: Session Log

Salva in `sessions/YYYY-MM-DD-HH-MM.md`:

```markdown
# Session Log: YYYY-MM-DD HH:MM

## Session Summary
One paragraph: goal and achievement.

---

## CRITICAL SECTIONS - What Compaction Loses

### Active Skills & Methodologies
1. **[Skill Name]**
   - Purpose: [what it does]
   - Key principles: [2-3 bullet points]
   - Current usage: [how we're applying it]

### Procedure State
**[Procedure Name]** (X/Y completed):
- [x] Step 1
- [x] Step 2
- [ ] Step 3 <- CURRENT STEP
- [ ] Step 4

### What We Tried That Didn't Work
- **[Attempt]**: [Why it failed] -> [What we did instead]

### User Preferences Discovered
- [Preference]: [Context/example]

---

## Context Snapshot

### Currently Working On
- Feature/task: [current task]
- File(s): [files being edited]
- Branch: [git branch]

### Key Decisions Made This Session
1. **[Decision]**: [WHY not just what]

### Problems Encountered & Resolutions
- **[Problem]**: [Resolution or status]

---

## Handoff Notes

### Immediate Next Steps
1. [Specific actionable step]

### Blockers / Waiting On
- [ ] [Blocker]

### Don't Forget
- [Critical detail]

---

## Files Modified This Session
- [path] - [description]
```

---

## Issue Tracking

### Tipi di Issue
- `bug` - Qualcosa non funziona
- `enhancement` - Miglioramento a feature esistente
- `review` - Qualcosa da verificare

### Severity (bug) / Priority (altri)
- Bug: critical -> major -> minor -> trivial
- Enhancement/Review: high -> medium -> low

### Status
- `in-progress` - In lavorazione
- `blocked` - Bloccato (specificare perché)
- `closed` - Completato (documentare soluzione)
- `rejected` - Non si fa (specificare perché)

### Template Issue

```markdown
# [{TYPE}-{NNN}] {Title}

> Type: bug | enhancement | review
> Severity/Priority: [level]
> Status: in-progress | blocked | closed | rejected
> Created: YYYY-MM-DD

## Description
[description]

## Context
Discovered during: [session/context]

## Steps to Reproduce (for bugs)
1. ...
2. ...

**Expected:**
**Actual:**

## Solution

### Approach
[how it was solved]

### Changes Made
[files modified]

### Related
[links to design logs, commits]
```

---

## Quality Checklists

### PROJECT.md
- [ ] Vision clear in one paragraph
- [ ] Tech stack complete
- [ ] Key directories explained
- [ ] Conventions documented

### PROGRESS.md (indice) + file split
- [ ] "Last updated" current
- [ ] PROGRESS.md è un indice leggero (contatori + link), non contiene entry-log corpose
- [ ] `FOCUS.md` riflette l'obiettivo corrente (UNA sola voce 🔄 in corso) ed è aggiornato
- [ ] `INBOX.md` triagato (nessuna voce grezza dimenticata)
- [ ] Solo lavoro **validato** in `DONE.md`/`FIXED.md` (l'implementato-non-validato sta in `TO_TEST.md`/`FOCUS.md`)
- [ ] Completed work in `DONE.md`/`FIXED.md` with How/Files
- [ ] TODOs in `TODO.md` have proposed approaches; bug in `TO_FIX.md`; implementato-da-validare in `TO_TEST.md`
- [ ] `DONE.md`/`FIXED.md` sotto ~400 righe (oltre → archiviare in `progress.old.md`)
- [ ] Priorities clear · Reference to latest session

### Design Logs
- [ ] Background explains WHY
- [ ] Problem specific and clear
- [ ] Q&A has actual questions/answers
- [ ] Design includes file paths
- [ ] Implementation Plan has checkable items
- [ ] Status accurate

### Session Logs
- [ ] Summary captures goal/achievement
- [ ] Key decisions documented with reasoning
- [ ] Next steps specific and actionable
- [ ] Files modified listed

---

## Project Discovery Mode

Quando `/startsession` trova PROJECT.md vuoto, si attiva il **Project Discovery Mode** che interrompe il flusso normale.

### Criterio "PROJECT.md vuoto"
- Non esiste
- Esiste ma ha solo titolo, placeholder, template non compilato
- Nessuna riga con contenuto informativo reale sul progetto

### Due scenari

**Progetto esistente** (ci sono file sorgente, package manager, struttura riconoscibile):
1. Analisi profonda: struttura, stack, architettura, codice core, config, test, docs
2. Per progetti grandi (>50 file): parallelizzare con Agent
3. Presentare deduzioni (natura, scopo, target, stack, architettura, stato)
4. Chiedere conferma/correzioni
5. Dopo conferma: popolare PROJECT.md e PROGRESS.md

**Progetto nuovo** (solo file design-log nella directory):
1. Domande guidate: scopo, target, funzionalità, tech, UI/UX, vincoli
2. Domande contestuali aggiuntive in base alle risposte
3. Dopo risposte e conferma: popolare PROJECT.md e PROGRESS.md

Dopo la discovery, il flusso normale di /startsession riprende.

Dettagli completi: vedi `.claude/commands/startsession.md`

---

## Sistema Lock di Sessione (`.locks/`)

> Cooperative locking file-based per gestire 2+ sessioni Claude in parallelo sullo stesso repo.

### Entry point unico: `.claude/scripts/lock.sh`

Tutte le operazioni sui lock passano da uno script bash committato `.claude/scripts/lock.sh`. Lo script usa `jq` come tool primario con fallback `python3` interno (per non bloccare se `jq` manca). È auto-approvato in `.claude/settings.json` con la singola permission `Bash(.claude/scripts/lock.sh:*)` — nessun prompt durante `/startsession` e fratelli.

Sub-comandi:

| Sub-comando | Effetto |
|---|---|
| `preflight` | Stampa `jq:OK` o `jq:MISSING` (con avviso). Eseguito a inizio `/startsession`. |
| `status` | Stampa JSON `{markers: [...], file_locks: [...]}` con tutto lo stato corrente. |
| `init` | Crea marker `exclusive`. Stampa il nuovo UID su stdout. |
| `share --uid <uid> <file1> [<file2>...]` | Flip `exclusive→shared` + crea `.lock` per-file. Refusa se uno dei file è già lockato da altri. |
| `add-file --uid <uid> <file>` | Append di un file al marker shared attivo + crea `.lock`. Idempotente se già self-owned. |
| `release --uid <uid>` | Rimuove i propri `.lock` per-file + flip `shared→exclusive`. |
| `end <uid>` | Rimuove `.locks/session-<uid>.json`. |

### Due livelli di lock

1. **Marker di sessione** — `.locks/session-{uid}.json`
   Identifica una sessione Claude attiva. Creato da `lock.sh init` (chiamato da `/startsession`), rimosso da `lock.sh end <uid>` (chiamato da `/savesession`).
   Schema:
   ```json
   {
     "uid": "uuid-v4",
     "type": "exclusive | shared",
     "startedAt": "ISO 8601 UTC",
     "host": "hostname",
     "lockedFiles": []
   }
   ```

2. **Lock per-file** — `.locks/<path-encoded>.lock`
   Dichiara intenzione di modificare un file specifico. Creato da `lock.sh share` o `lock.sh add-file` (chiamati da `/startsharedsession`), rimosso da `lock.sh release` (chiamato da `/stopsharedsession`).
   Naming: `path/to/file.ext` → `path__to__file.ext.lock` (mantiene estensione originale).
   Schema JSON: `{ owner_uid, file, task, createdAt }`.

### Stati possibili

| Marker presenti | `type` | Comportamento `/startsession` |
|---|---|---|
| Nessuno | — | Crea proprio marker `exclusive`, procede normale |
| Tutti `shared` | shared | Segnala + crea proprio marker `exclusive` (READ + non tocca file in `lockedFiles` union) |
| Almeno uno `exclusive` | exclusive | **READ-ONLY MODE** — non crea marker, non modifica nulla |

### Ciclo vita completo

```
/startsession          → lock.sh preflight + lock.sh status + lock.sh init  (exclusive)
/startsharedsession    → lock.sh share --uid <uid> <files...>               (flip a shared + lock per-file)
... lavoro ...
/stopsharedsession     → lock.sh release --uid <uid>                        (rimuove lock + flip a exclusive)
/savesession           → lock.sh end <uid>                                  (rimuove marker)
```

### Posizione

`.locks/` vive nella **root del repo**, NON in `design-log/`. È in `.gitignore`. Lo script lo crea automaticamente se manca.

### Recupero da crash

Se una sessione crasha senza chiamare `/savesession` o `/stopsharedsession`, marker e lock restano orfani. Solo l'utente li rimuove (Claude segnala, non agisce):
```bash
rm .locks/session-{uid-orfano}.json
rm .locks/*.lock   # solo se sicuri non ci sono sessioni attive
```

### Dipendenze

- `jq` (consigliato): `brew install jq` su macOS. Nativo su `/usr/bin/jq` su macOS recenti.
- Fallback `python3` interno: usato automaticamente se `jq` manca. Stesso comportamento, leggermente più lento.

Dettagli completi: vedi i quattro command file in `.claude/commands/` e lo script in `.claude/scripts/lock.sh`.

---

## Multi-branch + Merge design-log

Quando si lavora su branch separati (es. `release-2.x`, `feature/login`), i file condivisi del design-log generano conflitti merge rumorosi se mergeati con `git merge` standard. Il comando `/merge-design-log` orchestra un flusso che evita questo problema.

### Categorie di file

| Categoria | File | Strategia |
|-----------|------|-----------|
| Sezionati (sync auto) | `PROGRESS.md`, `LEARNED.md`, `issues/_INDEX.md` | Pre-merge isolation → sync-from-branch automatico |
| Narrativi (warning manuale) | `BEHAVIORS.md`, `PROJECT.md`, `METHODOLOGY.md` | Pre-merge isolation SE modificati → segnalazione, merge manuale |
| Naturalmente non collidenti | `sessions/*.md`, `YYYY-MM-DD-*.md` | Nessun trattamento (timestamp/slug unici) |

### Flusso del comando `/merge-design-log <source> [--into <target>]`

1. **Preflight**: working tree pulito, branch esistenti, memorizza `pre-isolate-sha` del source
2. **Detect**: file da isolare (sempre + conditional via `git diff --name-only target...source -- design-log/`)
3. **Isolation** (sul source): `git mv` dei file in `design-log/branches/<source>/`, commit "isolate"
4. **Merge** (sul target): `git merge <source>`. Se conflitti reali su file applicativi → STOP + istruzioni `--resume`
5. **Sync-from-branch** (sul target):
   - PROGRESS.md: insert entry DONE per data, append TODO mancanti per titolo
   - LEARNED.md: append righe nuove con marker `<!-- merged from branch <source> on YYYY-MM-DD -->`
   - issues/_INDEX.md: rebuild totale da `design-log/issues/*.md`
   - Per BEHAVIORS/PROJECT/METHODOLOGY: WARNING + merge manuale dall'archivio
   - Commit "sync design-log entries from branch <source>"
6. **Reset del source** (con conferma esplicita): `git reset --hard <pre-isolate-sha>` → source torna ex-ante (history pulita). AVVISO: serve `git push --force` se il branch era pushato.
7. **Ritorno al target**.

### Risultato

- **Source branch**: ex-ante, file ai path originali, nessun commit di plumbing nella history. Resta vivo per altri bugfix fino al rilascio.
- **Target branch**: storia esplicita del merge (commit "isolate" nel merge + commit "sync") + cartella `design-log/branches/<source>/` come archivio permanente.
- Collisione: se `branches/<source>/` esiste già → suffisso timestamp `branches/<source>-YYYY-MM-DD-HH-MM/`.

### Modalità `--resume`

Dopo conflitti reali su file applicativi a STEP 4: l'utente risolve manualmente, fa `git add` + `git commit`, e lancia `/merge-design-log --resume <source>`. Il comando salta isolation/merge e riparte dal sync.

Dettagli completi: `.claude/commands/merge-design-log.md`.

---

## Coordinazione cross-progetto (`.plan/`)

Quando un'iniziativa attraversa più progetti (sub) distinti che usano il design-log system, `/startcoord` permette di formalizzare il piano DAG cross-progetto e renderlo visibile a ogni `/startsession` nei sub coinvolti.

### Modello

- L'utente lancia `/startcoord` da una **sessione attiva in un sub qualunque** (l'originator). Niente padre orchestrator pre-dedicato.
- Claude usa il contesto della sessione corrente per fare proposte intelligenti durante il Q&A interactive.
- Il comando scrive `.plan/<plan_id>.json` in tutti i `sub_path` coinvolti.
- Tutte le copie sono inizialmente identiche e post-creazione sono **pari**: nessuna è "master".
- Lavoro post-creazione: l'utente è libero (sequenziale chiudendo/aprendo sessioni nei sub, parallelo aprendo più sessioni Claude in sub diversi, mix).

### Cartella `.plan/`

Ogni sub che usa il sistema ha la cartella `.plan/` (analoga a `.locks/`):
- Vuota → nessun plan attivo (zero overhead in `/startsession`)
- Con file `*.json` → plan attivi (carica e classifica)
- Con `archived/` → plan completati (ignorati da `/startsession`)

`.plan/` è creata best-effort da `/startsession`. Il contenuto è committato (default).

### Inbox handoff (`.plan/inbox/`) — convenzione 2026-06-07

Le note di **handoff cross-progetto** (un sub che scrive a un altro: "ecco cosa devi fare", requisiti, sblocchi) vivono in **`.plan/inbox/`** del sub **destinatario**, NON in `design-log/` (dov'erano difficili da trovare). Posto unico e prevedibile, accanto ai `.plan/*.json` del coord.

- **Dove**: `<sub-destinatario>/.plan/inbox/`.
- **Naming**: un file `.md` per nota, `YYYY-MM-DD-da-<sub-origine>.md` (es. `2026-06-07-da-ocrscore.md`).
- **Chi scrive**: chiunque mandi un handoff (manualmente, o `/startcoord` / `/stopcoord` quando lasciano istruzioni a un sub) lo mette nell'inbox del destinatario.
- **Chi legge**: `/startsession` (STEP 3.5f) elenca `.plan/inbox/*.md` e segnala le note nel riepilogo. Le note consumate si spostano in `.plan/inbox/archived/` per non risegnalarle.
- **Git**: committato con `.plan/` (default).

### Schema del plan

```json
{
  "plan_id": "monorepo-2026-q2",
  "title": "...",
  "created_at": "ISO 8601 UTC",
  "originator_host": "...",
  "originator_uid": "...",
  "originator_sub_path": "/abs/path/to/sub-dove-e-stato-creato",
  "tasks": [
    {
      "id": "core-1",
      "sub_path": "/abs/path/to/core",
      "title": "...",
      "status": "pending|in_progress|completed",
      "artifact": "design-log/<file>.md",
      "depends_on": ["..."],
      "started_at": null,
      "completed_at": null
    }
  ]
}
```

### Auto-detection del completamento

Il completamento di un task NON richiede comandi manuali. La transizione `pending → in_progress → completed` è dedotta da `/startsession` leggendo il design log artifact:
- Artifact non esiste → task pending
- Artifact esiste con `Status: Draft` o `Implementing` → in_progress
- Artifact con `Status: Implemented` → completed

Le copie del JSON nei sub sono cache opportunistiche aggiornate dalle sessioni che le toccano. La fonte di verità è sempre il design log artifact.

### Verifica delle dipendenze

Quando `/startsession` valuta un task pending del sub corrente, per ogni `dep_id` in `depends_on` legge l'artifact dichiarato nel `sub_path` del dependency (filesystem cross-sub), e cerca `Status: Implemented`. Se TUTTE le dipendenze sono soddisfatte → task pronto. Altrimenti → task bloccato (mostra quali dep sono ancora pending).

### Auto-archive

Quando TUTTI i task di un plan risultano `completed` (tutti gli artifact `Implemented`), `/startsession` sposta `.plan/<plan_id>.json` in `.plan/archived/<plan_id>.json` (best-effort su tutti i sub raggiungibili).

### Vincoli

- Tutti i `sub_path` devono essere accessibili via filesystem locale dal sub che esegue `/startsession`.
- Setup distribuiti (sub su macchine diverse) NON supportati in F2 minimale.

Dettagli completi: `.claude/commands/startcoord.md`.

---

## Workflow Completo

### Ricevendo un Task

0. **CATTURA PRIMA (R.15)**: qualsiasi cosa l'utente chieda — anche minima — va **scritta prima di agire**. Se è "segna" o un'idea grezza → `INBOX.md`. Se è pianificazione già chiara → `TODO.md`. Mai tenerla solo "a mente".

1. Il task è in `TODO.md` (o appena triagato da `INBOX.md`)?
   - Sì: verifica se esiste design log
   - No: aggiungilo alla priorità appropriata

2. Serve un design log?
   - Cambio piccolo (< 3 file): procedi direttamente
   - Cambio significativo: crea design log PRIMA

   Quando inizi davvero a lavorarci, **portalo in `FOCUS.md`** (`🔄 in corso`) — una sola voce in corso per volta (R.17).

3. Per design logs:
   - Crea draft con Background, Problem, Questions
   - FAI domande (Socratic method)
   - Aspetta risposte utente
   - Completa Design
   - Ottieni approvazione
   - POI implementa

### Dopo Ogni Task

1. File di tracking (split per-tipo — SEMPRE attivo). **Distingui implementato da validato (R.16):**
   - **Implementato ma non ancora validato** (build verde, l'utente non l'ha visto) → la voce va in `TO_TEST.md` e resta in `FOCUS.md` con stato `🧪 da validare`. **NON** in DONE.
   - **Validato** (l'utente l'ha visto funzionare) → SOLO ora muovi in `DONE.md` (entry ricca What/How/Files/Notes); se era un bug → `FIXED.md`. **Rimuovi la voce** da `TODO.md`/`TO_FIX.md`/`TO_TEST.md` e da `FOCUS.md`.
   - **Archiviazione**: se `DONE.md` o `FIXED.md` supera ~400 righe, sposta le entry più vecchie in `progress.old.md`
   - Aggiorna `FOCUS.md` (la voce chiusa esce; se libera, promuovi la prossima `⏸️` a `🔄`)
   - Aggiorna `PROGRESS.md` (solo indice: contatori + link, niente entry-log)
   - Aggiorna timestamp

2. Design log (se esiste):
   - Spunta item completati in Implementation Plan
   - Aggiungi note in Implementation Results
   - Aggiorna Status

3. Session log (se necessario):
   - Sessione lunga (15+ scambi)?
   - Milestone importante completata?
   - Stai per cambiare contesto?

---

## Pattern Locale/Globale — File fondamentali, locali e globali

> Introdotto 2026-05-07. Vedi design log `2026-05-07-local-global-pattern.md`.

Il sistema distingue sei "tipi" di file di personalizzazione, organizzati su tre piani: **fondamentali del metodo** (sovrascritti agli update), **locali al progetto** (persistono cross-update), **globali cross-progetto** (vivono fuori dai repo).

### Tabella delle responsabilità

| File | Vita | Cosa contiene | Aggiornato da | Sovrascritto agli update? |
|------|------|---------------|---------------|---------------------------|
| `BEHAVIORS.md` | In ogni progetto, symlink al meta | SOLO regole comportamentali **generali** del metodo | Solo meta-progetto via release | **SÌ** |
| `METHODOLOGY.md` | In ogni progetto, symlink al meta | SOLO metodologia **generale** del metodo | Solo meta-progetto via release | **SÌ** |
| `BEHAVIORS_LOCAL.md` | In ogni progetto | Regole comportamentali **specifiche del progetto** (come Claude deve comportarsi qui) | `/savesession` (classifica locale) o utente | NO |
| `PROJECT_UPDATES.md` | In ogni progetto | **Contesto/convenzioni/decisioni operative** specifici del progetto (workflow, naming, deploy, tensioni architetturali, scope modificato) | `/savesession` (classifica locale) o utente | NO |
| `LEARNED.md` | In ogni progetto | Conoscenza tecnica **specifica del progetto** (incl. gotcha niche di-una-sola-API usati da un solo progetto) | `/savesession` (classifica locale) o utente | NO |
| `~/.claude-method/LEARNED_GLOBAL/` (cartella) | Repo globale fuori dai progetti | **PRINCIPI universali** di come-si-lavora/costruisce (NON fatti specifici), **un file per dominio**; `/startsession` carica solo i domini pertinenti allo stack | `/savesession` (classifica globale) o utente | NO (vive fuori) |

### Regola fondamentale: `/savesession` non scrive in BEHAVIORS/METHODOLOGY

Vedi BEHAVIORS Regola 14. Quando in una sessione emerge una nuova regola/lezione, `/savesession` la classifica e la instrada nel file giusto:
- Regola **comportamentale locale al progetto** (su come Claude deve comportarsi) → `BEHAVIORS_LOCAL.md`
- **Contesto/convenzione/decisione operativa** locale al progetto → `PROJECT_UPDATES.md`
- Lezione **globale (un PRINCIPIO universale di come-si-lavora/costruisce)** → il file dominio giusto in `~/.claude-method/LEARNED_GLOBAL/` (vedi criterio PRINCIPIO-vs-FATTO sotto)
- Lezione tecnica **locale al progetto** (ogni fatto/gotcha specifico di un tool/API/progetto) → `LEARNED.md`

L'auto-classificazione è proposta da Claude e confermata dall'utente. Default conservativo: locale. **Criterio PRINCIPIO vs FATTO**: nel globale va solo un *principio* universale di *come si lavora/costruisce*; ogni *fatto* specifico (tool/API/progetto) è locale — anche se "riusabile" (le memorie locali si recuperano cross-progetto). Il conteggio «≥2 progetti» è **fallace** e non si usa.

### Esempi di classificazione

| Esempio di regola/lezione | Dove va | Perché |
|---------------------------|---------|--------|
| "Questo è un sotto-progetto di X, parent in `../../`, non duplicare info" | `BEHAVIORS_LOCAL.md` / Regole Comportamentali | Regola comportamentale specifica del progetto |
| "Quando parli di feature X, sempre verificare modulo Y" | `BEHAVIORS_LOCAL.md` / Regole Comportamentali | Regola comportamentale specifica del progetto |
| "main = branch della prossima versione; release/X.Y = parcheggio" | `PROJECT_UPDATES.md` / Contesto/Convenzioni | Convenzione operativa del progetto |
| "Tensione architetturale meta-vs-centralizzato — Modello 1 attuale, Modello 3 escape hatch" | `PROJECT_UPDATES.md` / Contesto/Convenzioni | Decisione operativa / contesto architetturale |
| «se non funziona, non a caso: alza i log e traccia il flusso, atteso vs reale» | `LEARNED_GLOBAL/general.md` / Errori | **PRINCIPIO** universale di debugging, vero sempre |
| «compila ≠ funziona: traccia i flussi prima di dire fatto» | `LEARNED_GLOBAL/software-general.md` / Soluzioni | **PRINCIPIO** di come-si-costruisce, indipendente dal tool |
| «`git mv` non funziona per pre-merge isolation» | `LEARNED.md` locale del progetto | **FATTO** su un tool (git): specifico → locale, anche se "riusabile" (si recupera cross-progetto) |
| «`AVAudioUnitSampler` ignora onChannel» | `LEARNED.md` locale di quell'app | **FATTO** su una singola API → locale |
| «rendi le operazioni idempotenti per gestire la consegna doppia» (webhook) | `LEARNED_GLOBAL/software-web.md` / Soluzioni | **PRINCIPIO** di come-si-costruisce un webhook sicuro (il dettaglio del codice `23505` sta nella voce locale del progetto) |
| «Knob rotanti scomodi per valori precisi → preferire slider» | `LEARNED_GLOBAL/design.md` / Pattern Tecnici | **PRINCIPIO** UX, vale a prescindere dal framework |
| «Non committare settings.local.json» | `LEARNED_GLOBAL/preferenze.md` | Preferenza trasversale a TUTTI i progetti |
| "L'utente preferisce tab a dropdown in questo progetto" | `PROJECT_UPDATES.md` / Contesto | UX di un progetto specifico → locale |

### Repo globale `~/.claude-method/`

Repo dedicato **richiesto** dal metodo:
- Path **hardcoded**: `~/.claude-method/`
- `/startsession` di OGNI progetto verifica esistenza all'avvio. Se manca → **errore bloccante**, sessione interrotta finché il setup non è completo.
- Setup multi-postazione via `git clone` (vedi README dentro il repo)
- Contiene: `LEARNED_GLOBAL.md` (index/manifest) + cartella `LEARNED_GLOBAL/` (file per dominio) + `README.md`

**Struttura `LEARNED_GLOBAL/` (un file per dominio, dal 2026-06-05):**
```
LEARNED_GLOBAL.md          ← index: spiega split, criterio, cosa caricare quando (SEMPRE letto)
LEARNED_GLOBAL/
├── general.md             ← SEMPRE caricato (cross-domain: metodo, workflow, agenti)
├── preferenze.md          ← SEMPRE caricato (preferenze utente trasversali)
├── software-general.md    ← condizionale (git/bash/tooling/architettura/ML/ffmpeg)
├── software-apple.md      ← condizionale (Swift/iOS/macOS/Catalyst/AVFoundation/Xcode)
├── software-web.md        ← condizionale (web/backend/DB/auth/SaaS/cloud)
└── design.md              ← condizionale (UX/visivo/controlli)
```
Ogni file dominio contiene `### Pattern Tecnici`, `### Errori da Non Ripetere`, `### Soluzioni Riutilizzabili`.

**Caricamento per stack**: `/startsession` legge SEMPRE l'index + `general` + `preferenze`, e SOLO i domini condizionali pertinenti allo stack dichiarato in `PROJECT.md` (mapping nell'index). Obiettivo: un progetto web non legge le regole Apple e viceversa. `software-general` NON è sempre-caricato — un progetto può non essere software affatto; si carica solo se contiene codice/scripting/build. La mappa completa stack→domini vive nell'index `LEARNED_GLOBAL.md`.

### Cosa NON modificare manualmente

- `BEHAVIORS.md` e `METHODOLOGY.md` di un progetto: sono symlink al meta-progetto, sovrascritti agli update. Edit manuale non sopravvive al prossimo update.
- Per cambiare il metodo: lavora sul meta-progetto (Claude Persistent Memory System) o su StartingKit, fai release, propaga.
- Per cambiare comportamenti del singolo progetto: usa `BEHAVIORS_LOCAL.md` (regole) o `PROJECT_UPDATES.md` (contesto/convenzioni).

---

## LEARNED.md (locale) vs LEARNED_GLOBAL/ — Cosa scrivere e dove

La distinzione è **PRINCIPIO vs FATTO**: una lezione va in `~/.claude-method/LEARNED_GLOBAL/` **solo se è un PRINCIPIO universale** di *come si lavora / come si costruisce* (vero sempre per natura, indipendente dal tool/progetto). Ogni **fatto/gotcha specifico** (una singola API/tool/libreria/progetto) resta **locale** — anche se "tecnicamente generale / riusabile": le memorie locali si **recuperano** cross-progetto quando servono. Il conteggio «≥2 progetti» è **fallace** e abbandonato (2026-07-30). Tutto il resto resta locale (o non si scrive).

### ✅ VA in LEARNED locale del progetto
- Pattern specifici del codebase del progetto (es. "il modulo X usa pattern Y per Z")
- **Ogni FATTO/gotcha specifico** di un tool/API/libreria/progetto — **anche se "tecnicamente generale / riusabile"** (es. "`AVAudioUnitSampler` si comporta così"; "`hooks/hooks.json` di un plugin si auto-carica"; "`git mv` rompe la pre-merge isolation"). Un *fatto* specifico è locale: si **recupera** cross-progetto quando serve, non serve globalizzarlo.
- Convenzioni di test e configurazioni hardcoded del progetto

### ✅ VA in LEARNED_GLOBAL/<dominio> (SOLO principi universali di come-si-lavora/costruisce)
- **Principi di metodo/debugging/verifica** veri sempre (es. «alza i log e traccia il flusso, atteso vs reale»; «compila ≠ funziona»; «verifica, non assumere») → `general.md` / `software-general.md`
- **Principi di come-si-costruisce** indipendenti dal tool (es. «rendi le operazioni idempotenti per gestire la consegna doppia»; «design PRIMA di codice per protocolli complessi») → dominio pertinente
- **Principi UX/di prodotto** cross-framework (es. «knob scomodi per valori precisi → slider») → `design.md`
- Si classifica per **tipo di conoscenza** (dominio), non per progetto di origine

### ❌ NON VA in LEARNED (né in LEARNED_GLOBAL)
- Regole/decisioni di business o di prodotto ("preset Advanced ha priorità", "bordone slider appare solo se attivo")
- Comportamento specifico di una feature, valori hardcoded del progetto
- Preferenze utente/UX di UN progetto ("l'utente vuole tab qui") → `PROJECT_UPDATES.md`
- Regole comportamentali per Claude → `BEHAVIORS_LOCAL.md` (se locali) o BEHAVIORS.md (solo metodo, via meta)
- Voci a bassissimo riuso (1 incidente irripetibile) → cestino, non si scrivono

**Test rapido (PRINCIPIO vs FATTO):**
- "È un **PRINCIPIO di come-si-lavora/costruisce**, vero sempre e indipendente dal tool — o un **FATTO** su un tool/API/progetto specifico?" Principio → `LEARNED_GLOBAL/<dominio>`. Fatto specifico → `LEARNED.md` locale (anche se "riusabile"). Riuso quasi-nullo → cestino.
- "Questa è una regola di comportamento per Claude?" Locale → `BEHAVIORS_LOCAL.md`. Generale (metodo) → solo via meta-progetto.
- In quale **dominio**? Apple/Swift → `software-apple.md`; web/backend → `software-web.md`; git/bash/tooling/architettura → `software-general.md`; UX/visivo → `design.md`; metodo/workflow → `general.md`; preferenza trasversale → `preferenze.md`.

---

## Il Principio Fondamentale

**"Non fidarti di Claude. Verifica."**

Ogni comando ha:
1. **Step OBBLIGATORI** - ORDINI, non suggerimenti
2. **Output VISIBILE** - checklist che l'utente vede
3. **Checkpoint** - punti dove Claude si FERMA e aspetta
