# Start Shared Session Command

Dichiara i file che questa sessione intende modificare e crea lock per evitare conflitti con sessioni parallele. Cambia il proprio marker di sessione da `exclusive` a `shared`.

## Quando usarlo

- Quando ci sono **2+ sessioni Claude in parallelo** sullo stesso repo
- **PRIMA** di modificare qualsiasi file
- Dopo `/startsession`, prima di scrivere codice

**Pre-requisito:** `/startsession` ha già creato un marker `.locks/session-{uid}.json` di tipo `exclusive`. Recupera l'UID dal contesto della conversazione.

Tutte le operazioni passano da `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`, auto-approvato. Niente prompt di permission ad ogni step.

---

## STEP OBBLIGATORI

### STEP 1: Identifica i file da toccare

Analizza il task assegnato e identifica TUTTI i file che potresti modificare.

**OUTPUT OBBLIGATORIO:**
```
📋 File che intendo modificare:
1. [path/to/file1.tsx]
2. [path/to/file2.ts]
...
```

---

### STEP 2: Verifica lock esistenti

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status
```

Estrai dall'output JSON la lista `file_locks[]` e confronta con i file da toccare. Se trovi un lock con `owner_uid` diverso dal tuo su un file che ti serve:

```
🔒 CONFLITTO: [file] è lockato da owner_uid [altro-uid]
⛔ NON posso modificare questo file finché il lock non viene rimosso.
```

**FERMATI e segnala all'utente.** NON procedere.

Se nessun conflitto:
```
✅ Nessun conflitto — tutti i file sono liberi
```

---

### STEP 3: Crea i lock per-file e flippa il marker a `shared`

Una sola invocazione atomica:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh share --uid <uid> <file1> <file2> ...
```

Lo script:
- Verifica nuovamente conflitti (se un altro UID ha lockato uno dei file → exit 3 con errore)
- Crea `.locks/<path-encoded>.lock` per ogni file (naming: `path/to/file.ext` → `path__to__file.ext.lock`, estensione preservata)
- Aggiorna `.locks/session-<uid>.json`: `type: exclusive→shared`, `lockedFiles = [file1, file2, ...]`

Schema dei lock per-file creati:
```json
{
  "owner_uid": "<uid>",
  "file": "<path>",
  "task": "shared session work",
  "createdAt": "<ISO 8601 UTC>"
}
```

**OUTPUT OBBLIGATORIO:**
```
🔒 Lock creati e marker aggiornato:
✅ OK: shared with [N] file(s)
   • [file1] → .locks/[lockfile1]
   • [file2] → .locks/[lockfile2]

🔄 Marker: type exclusive→shared, lockedFiles=[N]
```

---

### STEP 4: Mostra riepilogo

```
🔐 SESSIONE CONDIVISA ATTIVA — UID {uid}

📋 File lockati da me:
- [file1]
- [file2]

⚠️ Regole:
- NON modificare file lockati da altre sessioni (controlla `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status`)
- Prima di toccare un file non previsto, verifica e crea il lock con `add-file`
- A fine lavoro condiviso, eseguire /stopsharedsession PRIMA di /savesession

Procedo con l'implementazione?
```

---

### 🛑 STEP 5: FERMATI - Aspetta conferma

**NON procedere finché l'utente non conferma.**

---

## Aggiungere file durante la sessione

Se durante il lavoro scopri di dover toccare un file non previsto:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh add-file --uid <uid> <file>
```

Lo script:
- Verifica conflitti (file già lockato da altro UID → exit 3)
- Se libero: crea `.locks/<path-encoded>.lock` E appende a `lockedFiles` del marker
- Se già lockato da te stesso: no-op idempotente, ritorna OK

**OUTPUT:**
```
🔒 Lock aggiuntivo: [file]
   ✅ OK: added [file]
🔄 Marker: lockedFiles += [file]
```

---

## Note

- I file `.locks/` sono in `.gitignore` — non vengono committati
- Ogni sessione è responsabile dei PROPRI lock (identificati per `owner_uid`)
- Se una sessione crasha senza /stopsharedsession, i lock restano — l'utente li rimuove manualmente con `rm .locks/*.lock` (NON i `session-*.json` di altri se non sono orfani)
