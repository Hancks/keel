# Start Coord Command

Crea un piano di coordinamento cross-progetto: un DAG di task distribuiti su N sub-progetti che usano il design-log system. Scrive `.plan/<plan_id>.json` in tutti i sub coinvolti.

## Quando usarlo

Sei in una sessione Claude attiva (post `/startsession`) in un sub qualunque (es. `api/`). Mentre lavori, ti rendi conto che il task corrente si estende ad altri sub (es. "per fare questo endpoint serve prima cambio in core, poi qui, poi UI"). Da questa sessione lanci `/startcoord` per formalizzare il piano sfruttando il contesto già caricato.

Da quel momento, ogni `/startsession` in un sub coinvolto è plan-aware: ti dice "tocca a te", "aspetta che X finisca", "✅ già completato".

NON serve un orchestrator pre-dedicato. Il sub corrente è "originator" del plan (autorità per scrivere nei fratelli), ma post-creazione tutte le copie sono pari. Il completamento dei task è auto-detection da artifact (`Status: Implemented` nel design log).

---

## Usage

```
/startcoord [<plan_id>] [--from <path/to/template.json>]
```

Esempi:
```
/startcoord                              # Claude propone plan_id e parte interactive
/startcoord monorepo-2026-q2             # plan_id esplicito + interactive
/startcoord --from ~/plans/q2.json       # carica da template, skip Q&A
```

---

## Schema JSON del plan

```json
{
  "plan_id": "monorepo-2026-q2",
  "title": "Q2 monorepo migration: DB → API → UI",
  "created_at": "2026-05-07T20:00:00Z",
  "originator_host": "macbook-enzo",
  "originator_uid": "C716DC80-...",
  "originator_sub_path": "/Users/enzo/repos/api",
  "tasks": [
    {
      "id": "core-1",
      "sub_path": "/Users/enzo/repos/core",
      "title": "Migra schema DB a v2",
      "status": "pending",
      "artifact": "design-log/2026-05-07-db-migration.md",
      "depends_on": [],
      "started_at": null,
      "completed_at": null
    }
  ]
}
```

Note:
- `sub_path` = path **assoluto** filesystem
- `artifact` = path **relativo** al `sub_path` (= path Git-friendly)
- `depends_on` = lista di `id` di altri task
- `status` ∈ {pending, in_progress, completed}, transizione automatica via artifact (`/startsession` legge il design log e cerca `Status: Implemented`)

---

## STEP OBBLIGATORI

### STEP 0: Preflight

Verifica le precondizioni.

```bash
# Sessione attiva (presenza marker .locks/)
ls -1 .locks/session-*.json 2>/dev/null | wc -l
```

**OUTPUT OBBLIGATORIO:**
```
🔧 Preflight:
✅ Sessione attiva (marker .locks/session-{uid}.json presente)
✅ pwd = <sub corrente> = <path assoluto>
```

Se NESSUN marker → STOP, chiedi all'utente di eseguire prima `/startsession`.

---

### STEP 1: Scelta modalità

Determina la modalità in base agli argomenti.

**OUTPUT OBBLIGATORIO:**
```
🎯 Modalità: [INTERACTIVE | FROM-FILE]
🆔 Plan ID: [<plan_id> | da decidere via Q&A]
```

Se `--from <path>` → STEP 4 (validation), salta Q&A.
Altrimenti → STEP 2 (Q&A interactive).

---

### STEP 2: Q&A interactive

Sfrutta il contesto della sessione corrente per fare proposte intelligenti. Per ogni domanda, mostra una proposta basata sul contesto e lascia all'utente la possibilità di confermare/modificare.

**OUTPUT OBBLIGATORIO (esempio):**
```
❓ Domande per costruire il plan:

Q1: Plan ID
Proposta: monorepo-2026-q2 (basato sul contesto della sessione)
Confermi o vuoi cambiare?

Q2: Titolo descrittivo del plan
Proposta: "Q2 monorepo migration: DB → API → UI"
Confermi o vuoi cambiare?

Q3: Quanti sub-progetti coinvolti? (incluso il corrente)
[Aspetto risposta]

Q4 (per ogni sub): path assoluto + task title + artifact (design log path) + depends_on
Esempio per il sub corrente (proposta basata sulla sessione attiva):
  - sub_path: /Users/enzo/repos/api (← pwd)
  - task title: <dedotto dal design log/task corrente>
  - artifact: <dedotto>
  - depends_on: <vuoto o dedotto>

Per gli altri sub, chiedi all'utente uno alla volta.
```

**🛑 CHECKPOINT** dopo ogni gruppo di domande: aspetta risposta prima di continuare.

Al termine, costruisci la struttura JSON in memoria.

---

### STEP 3: (interactive only) Costruisci JSON

Dopo le risposte, monta il JSON con:
- `plan_id`, `title`, `created_at` (ISO 8601 UTC), `originator_host` (`hostname`), `originator_uid` (dal marker), `originator_sub_path` (= pwd assoluto)
- `tasks[]` come da Q4

**OUTPUT OBBLIGATORIO:**
```
🧱 Plan costruito:
✅ plan_id: <id>
✅ tasks: <N> totali su <M> sub
```

---

### STEP 4: Validation

Verifica:

1. **Sub paths esistono e usano design-log**:
   - Per ogni `sub_path`: `[ -d <sub_path>/design-log ]`
   - Se uno o più sub_path non sono validi → STOP + lista errori

2. **DAG senza cicli**:
   - Topological sort sui `depends_on`
   - Se ciclo rilevato → STOP + lista cicli

3. **Tutti gli `id` di `depends_on` esistono**:
   - Per ogni `dep_id` in ogni `depends_on`: cerca match in `tasks[].id`
   - Se mancante → STOP + lista mancanti

4. **Plan ID non collide**:
   - Per ogni `sub_path`: verifica che `<sub_path>/.plan/<plan_id>.json` NON esista già
   - Se collisione → chiedi all'utente: sovrascrivi (S/N) o cambia plan_id

**OUTPUT OBBLIGATORIO:**
```
🔍 Validation:
✅ Tutti i sub_path esistono e hanno design-log/
✅ DAG aciclico (topological order: <list>)
✅ Tutti i depends_on risolti
✅ Plan ID disponibile in tutti i sub
```

---

### STEP 5: Preview + Conferma

Mostra il JSON finale all'utente per conferma esplicita.

**OUTPUT OBBLIGATORIO:**
```
📄 Preview del plan da scrivere:

<JSON formattato indentato>

Verrà scritto in:
- <sub_path_1>/.plan/<plan_id>.json
- <sub_path_2>/.plan/<plan_id>.json
- ...

🛑 Confermi la scrittura? (sì/no)
```

**NON procedere finché l'utente non conferma.**

---

### STEP 6: Write

Per ogni `sub_path`:
1. Crea `<sub_path>/.plan/` se non esiste (`mkdir -p`)
2. Scrivi `<sub_path>/.plan/<plan_id>.json` con il contenuto del JSON

**NON committare** automaticamente. L'utente deciderà cosa committare e quando.

**OUTPUT OBBLIGATORIO:**
```
💾 Write:
✅ <sub_path_1>/.plan/<plan_id>.json (mkdir + write)
✅ <sub_path_2>/.plan/<plan_id>.json (mkdir + write)
...
```

Se uno o più write falliscono (es. permessi, disco pieno) → segnala chiaramente quali sub sono ok e quali no, e suggerisci recovery (`/startcoord --from <copia salvata>`).

---

### STEP 7: Riepilogo finale

**OUTPUT OBBLIGATORIO:**
```
✅ PLAN CREATO

📋 Plan ID: <plan_id>
📝 Titolo: <title>
📂 Originator: <pwd>
🌐 Sub coinvolti: <N>

📊 Task pronti (senza dipendenze pending):
🟢 <id_a>: <title> (sub: <sub_path_a>)
🟢 <id_b>: <title> (sub: <sub_path_b>)

⏳ Task con dipendenze (in attesa):
- <id_c>: dipende da <id_a>, <id_b>
- ...

🎯 Prossimi passi suggeriti:
- Per lavorare a <id_a>: cd <sub_path_a> e apri Claude
- Oppure resta qui se hai un task del sub corrente
```

---

## Note operative

### Sub corrente coinvolto vs no

Tipicamente il sub corrente È coinvolto nel plan (l'utente sta lavorando lì e ha avuto l'idea cross-progetto). Ma è ammissibile creare un plan che NON include il sub corrente (es. "lancio l'iniziativa da qui ma poi non ci lavoro più"). In quel caso, il sub corrente NON riceve `.plan/<plan_id>.json` (tranne se l'utente lo include esplicitamente).

### Modalità `--from`

Quando si usa `--from <path>`, il file JSON deve avere lo schema corretto. Il comando salta STEP 2-3, fa solo STEP 4 (validation) + STEP 5 (preview) + STEP 6 (write).

### Handoff via `.plan/inbox/` (convenzione 2026-06-07)

Se nel creare il plan vuoi lasciare istruzioni a un sub (es. "appena sblocco, ecco cosa consumi"), scrivile come nota `.md` nell'**inbox del destinatario**: `<sub-destinatario>/.plan/inbox/YYYY-MM-DD-da-<sub-origine>.md`. NON in `design-log/`. `/startsession` del destinatario le elenca e segnala (STEP 3.5f). Vedi METHODOLOGY "Inbox handoff".

### Niente comandi accessori

F2 minimale fornisce solo `/startcoord`. Niente `/coord-list`, `/coord-status`, `/coord-done`, `/coord-cancel`. Lo status di un task si verifica leggendo l'artifact (design log) — fonte di verità unica. Eventuali comandi di reporting verranno introdotti in F4 (design log futuro).

### Auto-detection del completamento

Quando un task viene completato (artifact con `Status: Implemented`), nessun comando esplicito serve: la prossima `/startsession` in qualunque sub coinvolto rileverà il cambiamento leggendo l'artifact via filesystem. Le copie del JSON nei sub vengono aggiornate opportunisticamente da `/startsession` con gli status verificati.

### Auto-archive

Quando TUTTI i task di un plan sono completed, `/startsession` sposta il file in `.plan/archived/<plan_id>.json` (best effort su tutti i sub coinvolti via filesystem).

---

## Checklist di verifica per l'utente

Dopo che Claude esegue `/startcoord`, verifica:

- [ ] Ha fatto preflight (sessione attiva, pwd)?
- [ ] Ha mostrato la modalità (interactive vs from-file)?
- [ ] (Interactive) Ha proposto plan_id, titolo, e contesto del sub corrente basandosi sulla sessione attiva?
- [ ] (Interactive) Si è fermato a checkpoint per ogni gruppo di domande?
- [ ] Ha fatto validation (sub paths esistono, DAG aciclico, deps risolti, no collisioni)?
- [ ] Ha mostrato preview del JSON e chiesto conferma esplicita?
- [ ] Ha scritto in TUTTI i sub coinvolti (con mkdir best-effort)?
- [ ] Ha mostrato riepilogo con task pronti, task in attesa, prossimi passi?
- [ ] NON ha committato automaticamente?

Se manca qualcosa, Claude non ha seguito il comando correttamente.
