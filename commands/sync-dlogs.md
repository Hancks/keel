# Sync Design Logs Command

Safety net per sincronizzare i file quando Claude dimentica di aggiornarli.

## Quando usarlo

- Dopo che Claude completa un task ma non aggiorna i file
- Quando non sei sicuro se i file sono sincronizzati
- Prima di /savesession (come double-check)
- Dopo modifiche significative

---

## STEP OBBLIGATORI

### STEP 1: Analizza conversazione recente

Identifica:
- Task completati
- Decisioni prese
- File modificati
- Design log creati/aggiornati

**OUTPUT OBBLIGATORIO:**
```
🔍 Analisi conversazione:
- Task completati: [lista]
- Decisioni prese: [lista]
- File modificati: [lista]
- Design log coinvolti: [lista o "nessuno"]
```

---

### STEP 2: Verifica i file di tracking (split per-tipo)

Controlla se sono aggiornati. Il tracking è spezzato per tipo; `PROGRESS.md` è solo l'indice (vedi METHODOLOGY).

**Checklist da verificare:**
- [ ] `INBOX.md` triagato (nessuna richiesta grezza dimenticata)?
- [ ] `FOCUS.md` riflette l'obiettivo corrente (UNA sola 🔄 in corso)?
- [ ] In `DONE.md`/`FIXED.md` SOLO lavoro **validato** (implementato-non-validato → `TO_TEST.md` + `FOCUS.md` 🧪, BEHAVIORS R.16)?
- [ ] Task validati con What/How/Files/Notes e rimossi da TODO/TO_FIX/TO_TEST + FOCUS?
- [ ] Nuovi TODO/bug in `TODO.md`/`TO_FIX.md`?
- [ ] `DONE.md`/`FIXED.md` sotto ~400 righe (oltre → archivia in `progress.old.md`)?
- [ ] `PROGRESS.md` indice: "Last updated" + contatori + link corretti?
- [ ] Fallback: progetto non migrato (file split vuoti) → verifica la sezione DONE/TODO di `PROGRESS.md`

**OUTPUT OBBLIGATORIO:**
```
📊 Tracking:
✅ DONE.md/FIXED.md con What/How/Files
❌ Mancava entry per [task] in DONE.md → AGGIORNATO
✅ TODO.md/TO_FIX.md/TO_TEST.md aggiornati · PROGRESS.md indice in sync
```

Se qualcosa manca → AGGIORNALO e mostra ❌ → AGGIORNATO

---

### STEP 3: Verifica Design Log (se esiste)

**Checklist da verificare:**
- [ ] Implementation Results aggiornato?
- [ ] Implementation Plan spuntato?
- [ ] Status corretto?

**OUTPUT OBBLIGATORIO:**
```
📝 Design log [nome]:
✅ Implementation Results aggiornato
❌ Implementation Plan non spuntato → AGGIORNATO
✅ Status: Implementing
```

Se non c'è design log:
```
📝 Design log: nessuno coinvolto
```

---

### STEP 4: Verifica Session Log (se necessario)

**Checklist da verificare:**
- [ ] Sessione lunga (15+ scambi)?
- [ ] Nuove skill/procedure da documentare?
- [ ] Tentativi falliti da registrare?
- [ ] Preferenze utente scoperte?

**OUTPUT OBBLIGATORIO:**
```
📅 Session log:
⚠️ Sessione lunga (20+ scambi) - considera /savesession
✅ Nessun tentativo fallito da registrare
✅ Nessuna preferenza nuova
```

---

### STEP 5: Riepilogo finale

**OUTPUT OBBLIGATORIO:**
```
🔄 SYNC COMPLETATO

Aggiornamenti effettuati:
✅ Tracking (DONE/FIXED/TODO/TO_FIX/TO_TEST + PROGRESS indice) - [cosa aggiornato]
✅ design-log/[nome].md - [cosa aggiornato]
⏭️ Session log - già in sync

Totale: [X] file aggiornati, [Y] già in sync

⚠️ Suggerimento: [se necessario, es. "considera /savesession"]
```

Se tutto era già sincronizzato:
```
✅ TUTTO IN SYNC

Nessun aggiornamento necessario.

Ultimo aggiornamento:
- Tracking (PROGRESS.md indice + file split): [timestamp]
- Design log attivo: [nome o "nessuno"]
- Ultima sessione: [timestamp]
```

---

## Checklist di verifica per l'utente

Dopo che Claude esegue `/sync-dlogs`, verifica:

- [ ] Ha analizzato la conversazione?
- [ ] Ha verificato i file di tracking (DONE/FIXED/TODO/TO_FIX/TO_TEST + PROGRESS.md indice)?
- [ ] Ha verificato design log (se esiste)?
- [ ] Ha considerato session log?
- [ ] Ha mostrato riepilogo con ✅/❌?

Se manca qualcosa, Claude non ha seguito il comando correttamente.
