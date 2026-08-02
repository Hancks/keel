# Stop Coord Command

Chiude / finalizza un piano di coordinamento cross-progetto creato con `/startcoord`. È il **bookend simmetrico** di `/startcoord`: riconcilia lo stato dei task dagli **artifact** (fonte di verità), **sincronizza tutte le copie** `.plan/<plan_id>.json` nei sub coinvolti in un solo colpo, produce un **report di chiusura**, e **archivia** il piano se completo (o su richiesta / con `--cancel`).

## Perché esiste (gap che colma)

`/startsession` aggiorna **solo la copia del sub corrente** in modo opportunistico e auto-archivia solo quando *tutti* i task sono `completed`. Mancava un'azione esplicita per:
- **allineare TUTTE le copie** nei sub in un colpo (senza dover aprire una sessione in ognuno),
- **chiudere/abbandonare** un piano che NON arriverà a `completed` via artifact (cancellato/superato),
- produrre un **quadro di chiusura** leggibile (chi ha finito, cosa resta e a chi tocca) a fine di una spinta di coordinamento.

`/stopcoord` NON inventa stati: li **deduce dagli artifact** come fa `/startsession` (missing→pending, `Draft`/`Implementing`→in_progress, `Implemented`→completed). L'unico stato "manuale" è `--cancel`.

## Quando usarlo

- Hai chiuso la TUA parte di un'iniziativa cross-progetto (es. il produttore ha finito i suoi task) e vuoi propagare lo stato reale a tutti i sub + lasciare un handoff pulito ai consumer.
- Vuoi **abbandonare** un piano che non si farà più (`--cancel`).
- Vuoi un report di stato cross-sub on-demand senza girare `/startsession` in ogni sub.

---

## Usage

```
/stopcoord [<plan_id>] [--cancel "<motivo>"] [--archive]
```

Esempi:
```
/stopcoord                              # se c'è un solo plan attivo lo usa; altrimenti chiede
/stopcoord mca-v3-content-engine        # plan esplicito: reconcile + sync + report (+ archive se completo)
/stopcoord <id> --archive               # forza l'archiviazione anche se non tutti completed
/stopcoord <id> --cancel "superato da nuovo design"   # abbandona il piano (archivia con marker cancelled)
```

---

## STEP OBBLIGATORI

### STEP 0: Preflight

```bash
ls -1 .plan/*.json 2>/dev/null            # plan attivi nel sub corrente
ls -1 .locks/session-*.json 2>/dev/null | wc -l   # sessione attiva
```

**OUTPUT OBBLIGATORIO:**
```
🔧 Preflight:
✅ Sessione attiva · pwd = <sub corrente>
✅ Plan attivi: <list di plan_id>   (oppure ⛔ nessun plan → STOP)
```

Se nessun plan attivo nel sub corrente → STOP (niente da chiudere qui).

### STEP 1: Risolvi il plan target

- `<plan_id>` passato → usalo.
- Nessun arg + **un solo** plan attivo → usalo.
- Nessun arg + **N>1** plan → elenca e **chiedi quale** (🛑 checkpoint).

Carica `.plan/<plan_id>.json` dal sub corrente.

**OUTPUT OBBLIGATORIO:** `🎯 Plan: <plan_id> — <title> (<N> task su <M> sub)`

### STEP 2: Reconcile da artifact (fonte di verità)

Per OGNI task in `tasks[]`:
1. Path artifact = `<task.sub_path>/<task.artifact>`.
2. Leggi (se esiste) e deduci lo `status`:
   - file assente → `pending`
   - header `Status: Draft` / `Status: Implementing` → `in_progress`
   - header `Status: Implemented` → `completed`
3. Per i task `pending`, valuta le `depends_on`: per ogni dep, leggi l'artifact del dep nel suo `sub_path` → soddisfatta se `Status: Implemented`. Tutte soddisfatte → **🟢 ready**; altrimenti **⏳ blocked** (annota quali dep mancano).

Aggiorna in memoria `status` (+ `started_at`/`completed_at` se mancanti, usando `date -u +%Y-%m-%dT%H:%M:%SZ`). **Vincolo:** tutti i `sub_path` devono essere raggiungibili via filesystem locale; per i sub non raggiungibili, mantieni lo stato pregresso e segnalalo.

> Con `--cancel "<motivo>"`: salta la deduzione fine, marca il piano `cancelled` (campo top-level `cancelled: {reason, at, by_uid}`) e i task non-`completed` come `cancelled`.

**OUTPUT OBBLIGATORIO:**
```
🔄 Reconcile da artifact:
✅ completed: <ids> · 🔄 in_progress: <ids> · 🟢 ready: <ids> · ⏳ blocked: <ids (deps)>
[sub non raggiungibili: <list> — stato invariato]
```

### STEP 3: Sync di TUTTE le copie

Scrivi il JSON riconciliato in **ogni** `<sub_path>/.plan/<plan_id>.json` raggiungibile (`mkdir -p .plan` best-effort). Tutte le copie diventano identiche e autoritative. **NON** committare (lo decide l'utente).

**OUTPUT OBBLIGATORIO:**
```
💾 Sync copie:
✅ <sub_path_1>/.plan/<plan_id>.json … (✅/❌ per sub)
```

### STEP 4: Archive (condizionale)

- Tutti i task `completed`, **oppure** `--archive`, **oppure** `--cancel` → sposta `.plan/<plan_id>.json` → `.plan/archived/<plan_id>.json` in ogni sub raggiungibile.
- Altrimenti → lascia il piano **attivo** con lo stato riconciliato (i consumer continuano a vederlo).

**OUTPUT OBBLIGATORIO:** `📦 Archive: [archiviato in <N> sub | non archiviato — <K> task ancora aperti]`

### STEP 5: Report di chiusura + handoff

**OUTPUT OBBLIGATORIO:**
```
✅ STOPCOORD — <plan_id>

📊 Stato finale:
  ✅ <id>: <title> (sub) — completed
  🔄 <id>: in_progress
  🟢 <id>: ready — prossimo: cd <sub_path> e apri Claude (oppure /startsession lì lo segnala)
  ⏳ <id>: blocked da <dep ids> (sub)

🤝 Handoff: <chi deve muoversi ora e dove> (es. "PianoTutor: pt-consume 🟢 ready").
🗒️  Se lasci istruzioni a un sub, scrivile nella sua inbox: `<sub>/.plan/inbox/YYYY-MM-DD-da-<origine>.md` (convenzione — il suo `/startsession` le segnala). NON in `design-log/`.
📦 Piano: [attivo con stato aggiornato | archiviato | cancellato: <motivo>]

NOTA: nessun commit automatico — committa tu le copie `.plan/` aggiornate.
```

---

## Note operative

- **Niente stati inventati**: `/stopcoord` deduce dagli artifact (come `/startsession`). L'unica eccezione è `--cancel`, che è una decisione esplicita dell'utente.
- **Idempotente**: rilanciarlo riconcilia di nuovo; se nel frattempo un artifact è passato a `Implemented`, lo stato avanza.
- **Differenza da `/startsession`**: questo allinea **tutte** le copie cross-sub in un colpo + chiude/abbandona + report; `/startsession` sincronizza solo il sub corrente e auto-archivia solo a completamento totale.
- **Non distruttivo**: l'archive *sposta* il JSON in `.plan/archived/`, non lo cancella. Gli artifact (verità) restano.

---

## Checklist di verifica per l'utente

- [ ] Preflight (sessione + plan attivo) mostrato?
- [ ] Plan target risolto (chiesto se ambiguo)?
- [ ] Reconcile dagli artifact (non stati inventati)?
- [ ] Sync di TUTTE le copie nei sub raggiungibili?
- [ ] Archive solo se completo / `--archive` / `--cancel`?
- [ ] Report di chiusura con ready/blocked + handoff?
- [ ] NESSUN commit automatico?
