# 🧠 COMPORTAMENTI DA SEGUIRE INDEROGABILMENTE - Leggi PRIMA di fare qualsiasi cosa

> Ultimo aggiornamento: 2026-05-07

Questo file contiene regole comportamentali che Claude FUTURO deve assolutamente rispettare.

---

## REGOLE CRITICHE

### 1. Tu NON segui la metodologia automaticamente
- Hai dimostrato empiricamente che salti passaggi se non sei forzato
- Non illuderti di "aver imparato" - ogni sessione parti da zero

### 2. Quando l'utente chiede di implementare qualcosa
- ❌ NON partire a implementare direttamente
- ❌ NON chiedere "Procedo?"
- ✅ SUGGERISCI: "Questo task richiede /add-task. Posso eseguirlo?"

### 3. /add-task funziona perché ti FORZA
- Senza di esso, salterai: design log, domande, approvazione
- CON esso, hai gli step davanti e li segui uno per uno
- È l'unico modo per garantire che segui la metodologia

### 4. Se l'utente dice "procedi" o "fai X"
1. FERMATI
2. Chiediti: "È un task significativo? Serve /add-task?"
3. Se SÌ → suggerisci /add-task
4. Se NO (task banale < 3 file) → procedi

### 5. Il principio fondamentale
**"Non fidarti di te stesso. Usa i comandi che ti forzano."**


### Regola 6: Fare ESATTAMENTE quello che l'utente dice, non varianti
- **Se l'utente dice di fare X, FAI X. Non una variante. Non qualcosa di simile. X.**

###Regola 7: NON estendere lo scope — solo quello che è stato chiesto
- **Se l'utente elenca X e Y, fai SOLO X e Y. Non Z anche se ti sembra coerente.**

###Regola 8: - Dopo aver scritto il codice, RILEGGERE il codice
- **Verificare PUNTO PER PUNTO che ogni richiesta dell'utente sia implementata**

### Regola 9. Sessioni parallele — LOCK obbligatorio
- `/startsession` crea SEMPRE un marker `.locks/session-{uid}.json` (di default `exclusive`).
- Se all'avvio trovi un marker `exclusive` di un'altra sessione → **READ-ONLY MODE**: non modifichi nessun file.
- Se all'avvio trovi solo marker `shared` → entri normale ma NON tocchi i file presenti nell'unione dei `lockedFiles`.
- Quando ci sono 2+ sessioni Claude sullo stesso repo e devi modificare file: **SEMPRE** usare `/startsharedsession` (cambia il tuo marker da `exclusive` a `shared` e crea i `.lock` per-file).
- **NON** modificare file con `.lock` di proprietà di un altro `owner_uid` — FERMATI e segnala.
- Prima di aggiungere un file non previsto durante il lavoro: verificare lock con `ls .locks/*.lock`.
- A fine lavoro condiviso: **SEMPRE** eseguire `/stopsharedsession` PRIMA di `/savesession`.
- `/savesession` rimuove il proprio marker `session-{uid}.json`.
- Se trovi un marker o lock orfano (sessione crashata): segnala all'utente, NON rimuoverlo tu.

### Regola 10. Symlink: Glob NON li trova, usa ls
- Il tool `Glob` non rileva i symlink in generale
- Per verificare l'esistenza di un symlink: usa `Bash` con `ls -la path/to/symlink`
- NON tentare di ricreare un symlink senza prima verificare con `ls -la`
- NON usare `Glob` come prova che un file non esiste se potrebbe essere un symlink
- Storia: questa regola era nata per il symlink `sessions/latest.md`, eliminato nel 2026-05-06 (vedi design log F3). La regola resta valida per qualunque altro symlink futuro.

### Regola 11. Estensioni si discutono insieme, non si applicano unilateralmente
- Quando emergono nuove idee o estensioni mentre si lavora a un task, NON applicarle d'iziativa. L'utente deve controllare scope e timing delle estensioni, anche se sembrano coerenti col task in corso.

### Regola 12. Merge multi-branch del design-log — usa `/merge-design-log`
- Quando devi mergiare un branch (es. `release-2.x`, `feature/login`) sul target (default `main`), NON usare `git merge` diretto: i file `PROGRESS.md`, `LEARNED.md`, `issues/_INDEX.md` generano conflitti rumorosi e perdita di entry.
- Usa SEMPRE `/merge-design-log <source> [--into <target>]`: gestisce l'isolation, il merge, il sync-from-branch automatico e il reset del source per mantenere la history pulita.
- Il comando avvisa se serve `git push --force` (quando il source era pushato): coordinare con altri se il branch è condiviso.
- In caso di conflitti REALI su file applicativi: il comando si ferma → risolvi manualmente → `git add` + `git commit` → rilancia con `/merge-design-log --resume <source>`.
- Per BEHAVIORS / PROJECT / METHODOLOGY modificati sul branch: il comando NON merge automatico, ma segnala con WARNING. Vanno mergeati a mano dalla copia in `design-log/branches/<source>/`.

### Regola 13. Coordinazione cross-progetto — usa `/startcoord`, niente comandi manuali per `completed`
- Quando un'iniziativa attraversa più sub-progetti, NON pianificare a mente o con appunti sparsi: usa `/startcoord` da una sessione attiva nel sub originator. Crea un piano DAG visibile da ogni `/startsession` nei sub coinvolti.
- Il completamento dei task è **auto-detection da artifact**: nessun comando manuale (`/coord-done` non esiste). Un task è `completed` se e solo se il suo design log artifact ha `Status: Implemented`.
- Le copie del JSON `.plan/<plan_id>.json` nei vari sub sono cache opportunistiche. Se sospetti divergenze tra copie, l'artifact è la fonte di verità — cancella la copia disallineata e rilancia `/startsession` (rebuild opportunistico dalla artifact).
- Vincolo: tutti i `sub_path` devono essere accessibili via filesystem locale dalla macchina dove esegui `/startsession`.
- `.plan/` è committata (default). Se vuoi un piano "private" gitignored, è una scelta del progetto, non default.

### Regola 14. /savesession NON scrive in BEHAVIORS o METHODOLOGY — classifica e instrada
- BEHAVIORS.md e METHODOLOGY.md contengono SOLO regole/metodologia **generali** del metodo. Vengono **sovrascritte agli update** del metodo. Nessuna sessione deve infilare lì regole specifiche del progetto: andrebbero perse al primo update.
- Quando in una sessione emerge una nuova regola comportamentale o lezione tecnica, `/savesession` la **classifica** e la instrada nel file giusto:
  - **Regola comportamentale locale al progetto** (come Claude deve comportarsi in questo progetto) → `design-log/BEHAVIORS_LOCAL.md`
  - **Contesto/convenzione/decisione operativa locale al progetto** (workflow, naming, deploy, tensioni architetturali, scope modificato) → `design-log/PROJECT_UPDATES.md`
  - **Lezione globale (cross-progetto) — un PRINCIPIO universale**: SOLO se è un **principio di *come si lavora / come si costruisce*, vero sempre per natura** (es. «se non funziona non risolvere a caso: alza i log e traccia il flusso, atteso vs reale»; «compila ≠ funziona»; «verifica, non assumere») → il file dominio giusto in `~/.claude-method/LEARNED_GLOBAL/` (`general.md`, `preferenze.md`, `software-general.md`, `software-apple.md`, `software-web.md`, `design.md`). Si sceglie il file per **tipo di conoscenza**, non per progetto di origine. Vedi l'index `~/.claude-method/LEARNED_GLOBAL.md` per criterio e mappa.
  - **Lezione tecnica locale al progetto** → `design-log/LEARNED.md`. **Ci va OGNI fatto/gotcha specifico** di un tool/API/progetto — **anche se "tecnicamente generale / riusabile"** (es. «`hooks/hooks.json` di un plugin si auto-carica», il quirk di una singola API): un *fatto* specifico resta locale, e le memorie locali si **recuperano** cross-progetto quando servono (non serve globalizzarle per riuso). **Regola secca: GLOBAL = principio · LOCAL = fatto specifico. Il conteggio «≥2 progetti» è FALLACE e NON si usa** (mille progetti identici non rendono nulla globale).
- L'auto-classificazione è **proposta da Claude** e **confermata dall'utente**. Default conservativo: locale. Voci a riuso quasi-nullo (1 incidente irripetibile): non si scrivono.
- Edit manuale di BEHAVIORS o METHODOLOGY è riservato all'evoluzione del **metodo stesso** (meta-progetto), non a singole sessioni di progetto.
- Storia: regola introdotta 2026-05-07 (`PROJECT_LOCAL.md` unico file locale). 2026-05-11 split: regole → `BEHAVIORS_LOCAL.md`, contesto → `PROJECT_UPDATES.md`. **2026-06-05: `LEARNED_GLOBAL.md` (file unico) → cartella `LEARNED_GLOBAL/` con file per dominio + caricamento condizionale per stack** (design log `2026-06-05-learned-global-scalable.md`). **2026-07-30: criterio di classificazione CORRETTO — da «asticella alta = utile a ≥2 progetti» (fallace, causa ricorrente di over-globalizzazione) a «GLOBAL = principio universale · LOCAL = fatto specifico»** (correzione dell'utente; il conteggio di progetti non ha valore e le memorie locali si recuperano cross-progetto).

### Regola 15. Cattura-all'istante — scrivi PRIMA di agire
- Ogni richiesta dell'utente, **anche minima**, va **scritta in un file PRIMA di metterti a lavorare**. La memoria della conversazione NON è affidabile: una cosa detta e non scritta subito è persa.
- Quando l'utente dice **"segna"** (o butta lì un'idea grezza/convulsiva) → va in **`design-log/INBOX.md`**, NON in `TODO.md`. `TODO.md` è la **lista ufficiale curata**; `INBOX.md` è la cattura grezza da triagiare dopo.
- Se è già pianificazione chiara e prioritizzabile → direttamente in `TODO.md` (o `TO_FIX.md` se è un bug).
- Vietato rispondere "ok lo faccio/me lo ricordo" senza prima scriverlo. La **cattura** è in tempo reale; il **triage** (INBOX→TODO/TO_FIX/🗑) può essere batch (a `/add-task`, on-demand, e obbligatorio a `/savesession`).
- Storia: introdotta 2026-06-24 (design log `2026-06-24-rafforzamento-metodo.md`). Vedi METHODOLOGY "Il ciclo di vita del lavoro".

### Regola 16. Done = validato, non implementato
- `tsc`/build/test verdi = **implementato**, NON "fatto". Una voce entra in `DONE.md`/`FIXED.md` **solo dopo che l'utente l'ha vista funzionare** (validazione "a video").
- Una feature implementata ma non ancora validata vive in **`TO_TEST.md`** (+ stato `🧪 da validare` in `FOCUS.md`), **mai** in `DONE.md`.
- MAI dichiarare un task chiuso, né scriverlo in DONE/FIXED, sulla prova di sola compilazione. Rafforza il principio "Non fidarti di te stesso. Verifica." e la lezione "MAI dichiarare verde senza leggere l'output".
- Alla validazione: muovi in DONE/FIXED **e rimuovi la voce** da TODO/TO_FIX/TO_TEST e da FOCUS (così TODO resta una lista viva, non un cimitero).

### Regola 17. Una feature alla volta + FOCUS-first
- **`FOCUS.md` si legge per PRIMO** a ogni sessione (lo fa `/startsession`) e il lavoro parte **da lì**, non dal backlog di `TODO.md` né dall'ultimo messaggio in chat.
- In `FOCUS.md` c'è **UNA sola** voce `🔄 in corso` per volta: si porta a **validata** prima di aprirne un'altra. Le altre restano `⏸️ in coda` o `🧪 da validare`.
- `FOCUS.md` deve restare **corto** (l'obiettivo di adesso): se gonfia come il TODO, ha smesso di focalizzare.
- Storia: introdotta 2026-06-24 (design log `2026-06-24-rafforzamento-metodo.md`).


## COME USARE QUESTO FILE

1. /startsession DEVE leggere questo file
2. /startsession DEVE mostrare queste regole nel riepilogo
3. **NON aggiungere qui regole/lezioni emerse durante una sessione**: usa la classificazione di `/savesession` (Regola 14) → BEHAVIORS_LOCAL.md (regole locali) / PROJECT_UPDATES.md (contesto locale) / LEARNED.md (lezioni locali) / `LEARNED_GLOBAL/<dominio>.md` (cross-progetto: un PRINCIPIO universale, non un fatto specifico).

---

## STORICO APPRENDIMENTI

### 2026-01-22 - Sessione di debugging metodologia
- **Scoperto:** Claude non legge automaticamente i file all'inizio
- **Scoperto:** Claude non segue la metodologia se non forzato
- **Soluzione:** Creati /startsession e /add-task obbligatori
- **Regola derivata:** Suggerire sempre /add-task per task significativi
