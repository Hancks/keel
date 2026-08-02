# Stop Shared Session Command

Rilascia tutti i lock per-file creati da questa sessione e riporta il proprio marker da `shared` a `exclusive`.

## Quando usarlo

- **A fine lavoro condiviso** quando si è usato `/startsharedsession`
- **PRIMA** di `/savesession`
- Quando il task parallelo è completato

Tutte le operazioni passano da `${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh`, auto-approvato.

---

## STEP OBBLIGATORI

### STEP 1: Elenca lock per-file attivi

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh status
```

Estrai dall'output JSON la lista `file_locks[]`. Il marker della sessione corrente (`type: shared`) ha già `lockedFiles` valorizzati — coincidono con i `.lock` per-file con `owner_uid` uguale al tuo UID.

**OUTPUT OBBLIGATORIO:**
```
🔒 Lock per-file attualmente attivi:
- [file1] → owner_uid: [uid]
- [file2] → owner_uid: [uid]
```

---

### STEP 2: Identifica i MIEI lock vs lock altrui

Recupera il PROPRIO `uid` dal contesto (annunciato da `/startsession`).

**OUTPUT OBBLIGATORIO:**
```
🔓 Lock da rilasciare (miei, owner_uid={uid}):
- [file1]
- [file2]

🔒 Lock di altre sessioni (NON toccare):
- [file3] (owner_uid: [altro-uid])
```

---

### STEP 3: Rilascia i miei lock e ripristina il marker → `exclusive`

Una sola invocazione atomica:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/lock.sh release --uid <uid>
```

Lo script:
- Itera su tutti i `.lock` per-file in `.locks/`
- Rimuove SOLO quelli con `owner_uid` uguale al tuo UID
- Aggiorna `.locks/session-<uid>.json`: `type: shared→exclusive`, `lockedFiles = []`

**OUTPUT OBBLIGATORIO:**
```
🔓 Lock rilasciati e marker ripristinato:
✅ OK: released [N] lock(s)
🔄 Marker: type shared→exclusive, lockedFiles=[]
```

---

### STEP 4: Conferma pulizia

```
✅ SESSIONE CONDIVISA CHIUSA — UID {uid}

🔓 [N] lock per-file rilasciati
🔒 [M] lock per-file di altre sessioni ancora attivi
🔄 Marker tornato a EXCLUSIVE
📂 Directory .locks/: contiene il mio session-{uid}.json + [M] lock altrui

Adesso puoi eseguire /savesession (rimuoverà il marker).
```
