# Add Task Command

FORZA l'uso della metodologia Design-Log per ogni nuovo task.

## Perché questo comando esiste

Claude ha ammesso: "Se non me lo avessi chiesto, non avrei seguito la metodologia."

Questo comando FORZA il comportamento corretto. Non è opzionale.

## Usage

```
/add-task "descrizione del task"
```

Esempio:
```
/add-task "Aggiungere autenticazione JWT"
```

---

## STEP OBBLIGATORI

### STEP 1: Verifica se esiste già

Cerca in `TODO.md` (e `TO_FIX.md` se è un bug) se il task è già presente. Fallback: se il progetto non è migrato (file split vuoti), cerca in `PROGRESS.md`.

**Glance a `INBOX.md`** (BEHAVIORS R.15): la richiesta potrebbe essere già stata catturata lì da un "segna" precedente. Se sì, questo `/add-task` la sta **triagando** — toglila da `INBOX.md` quando la porti in TODO/FOCUS. Coglil'occasione per triagare anche eventuali altre voci INBOX correlate.

**OUTPUT OBBLIGATORIO:**
```
🔍 Verifica task esistente:
✅ Cercato in TODO.md / TO_FIX.md / INBOX.md (fallback PROGRESS.md se non migrato)
📋 Risultato: [NON TROVATO | TROVATO in [file/sezione] | GIÀ IN INBOX → triago]
```

Se TROVATO, chiedi:
```
Questo task sembra già esistere in [file].
Vuoi:
A) Lavorare su quello esistente
B) Crearne uno nuovo comunque
```

---

### STEP 2: Valuta complessità

**OUTPUT OBBLIGATORIO:**
```
📊 Valutazione complessità:
- File coinvolti (stima): [numero]
- Tipo: [semplice | significativo]
- Richiede design log: [SÌ | NO]
```

**Criteri:**
- **Semplice** (NO design log): < 3 file, fix ovvio, nessuna decisione architetturale
- **Significativo** (SÌ design log): >= 3 file, nuova feature, decisioni da prendere

Se **NO** → salta a STEP 9 (implementa direttamente)
Se **SÌ** → continua con STEP 3

---

### STEP 3: Crea design log

Crea file: `design-log/YYYY-MM-DD-[slug].md`

**OUTPUT OBBLIGATORIO:**
```
📝 Design log creato:
✅ File: design-log/[nome-file].md
```

---

### STEP 4: Scrivi Background e Problem

Compila le sezioni iniziali del design log.

**OUTPUT OBBLIGATORIO:**
```
📄 Sezioni compilate:
✅ Background - [1-2 frasi di riepilogo]
✅ Problem - [1-2 frasi di riepilogo]
```

---

### STEP 5: Scrivi domande (Metodo Socratico)

NON assumere. Fai DOMANDE su tutto ciò che non è chiaro.

**OUTPUT OBBLIGATORIO:**
```
❓ Domande per te:

Q1: [domanda specifica]
Q2: [domanda specifica]
Q3: [domanda specifica]
...
```

Minimo 2 domande. Se non ci sono domande, spiega perché:
```
❓ Nessuna domanda: [spiegazione del perché tutto è chiaro]
```

---

### 🛑 STEP 6: FERMATI - Aspetta risposte

**OUTPUT OBBLIGATORIO:**
```
🛑 CHECKPOINT

Attendo le tue risposte alle domande prima di procedere.
Non procederò finché non rispondi.
```

**NON procedere finché l'utente non risponde.**

---

### STEP 7: Completa Design

Dopo le risposte, aggiorna il design log:
- Compila sezione Q&A con risposte
- Scrivi sezione Design
- Definisci Implementation Plan

**OUTPUT OBBLIGATORIO:**
```
📐 Design completato:
✅ Q&A compilato con risposte
✅ Sezione Design scritta
✅ Implementation Plan: [N] step definiti
```

---

### 🛑 STEP 8: FERMATI - Chiedi approvazione

**OUTPUT OBBLIGATORIO:**
```
🛑 CHECKPOINT - APPROVAZIONE RICHIESTA

Design completato: design-log/[nome-file].md

Riepilogo:
- [punto chiave 1 del design]
- [punto chiave 2 del design]
- [punto chiave 3 del design]

Implementation Plan:
1. [step 1]
2. [step 2]
3. [step 3]
...

Approvi l'implementazione? (sì/no)
```

**NON procedere finché l'utente non dice "sì", "approvato", "ok", "procedi" o simile.**

---

### STEP 9: Implementa

Solo DOPO approvazione esplicita (o se task semplice senza design log).

**Prima di scrivere**: porta questo task in `FOCUS.md` come `🔄 in corso` (BEHAVIORS R.17 — una sola voce in corso per volta; se ce n'è già una, mettila `⏸️` o concludila prima). Annota il **criterio di "fatto"** (come l'utente vedrà che funziona).

**OUTPUT OBBLIGATORIO (durante implementazione):**
```
🎯 Portato in FOCUS.md: 🔄 [task] — criterio di fatto: [...]
🔨 Implementazione in corso:
✅ [file creato/modificato] - [cosa]
✅ [file creato/modificato] - [cosa]
...
```

---

### STEP 10: Aggiorna i file di tracking (split per-tipo) — done = validato (R.16)

⚠️ **Distingui implementato da validato (BEHAVIORS R.16).** `tsc`/build verde NON è "fatto".

- **Implementato ma NON validato** (tu hai finito di scrivere, l'utente non l'ha ancora visto funzionare) → la voce va in `TO_TEST.md` e resta in `FOCUS.md` con stato `🧪 da validare`. **NON** in `DONE.md`. Il task NON è chiuso.
- **Validato in questa stessa sessione** (l'utente l'ha visto funzionare) → SOLO ora:
  - Entry ricca (What/How/Files/Notes) in `DONE.md` (o `FIXED.md` se era un bug)
  - Rimuovi il task da `TODO.md`/`TO_FIX.md`/`TO_TEST.md` e da `FOCUS.md`
  - Se `DONE.md`/`FIXED.md` supera ~400 righe → archivia le entry vecchie in `progress.old.md`
- Aggiorna i contatori + "Last updated" in `PROGRESS.md` (indice)
- Fallback: se il progetto non è migrato, aggiorna la sezione DONE di `PROGRESS.md`

**OUTPUT OBBLIGATORIO:**
```
📊 Tracking aggiornato:
[se validato] ✅ Entry in DONE.md (o FIXED.md) · rimosso da TODO/TO_FIX/TO_TEST + FOCUS
[se solo implementato] 🧪 In TO_TEST.md + FOCUS.md (🧪 da validare) — NON chiuso, attende validazione utente
✅ PROGRESS.md indice + contatori aggiornati · Timestamp: [nuovo timestamp]
```

---

### STEP 11: Aggiorna design log (se esiste)

**OUTPUT OBBLIGATORIO:**
```
📝 Design log aggiornato:
✅ Implementation Plan: tutti gli step spuntati
✅ Status: Implemented
✅ Implementation Results: note aggiunte
```

---

## Riepilogo finale

**OUTPUT OBBLIGATORIO:**
```
✅ TASK COMPLETATO

📋 Task: [descrizione]
📝 Design log: [path o "non richiesto"]
📁 File modificati: [numero]
📊 Tracking: DONE.md/FIXED.md + TODO.md/TO_FIX.md + PROGRESS.md indice aggiornati

Prossimo passo suggerito: [da TODO.md — o PROGRESS.md TODO se non migrato]
```

---

## Checklist di verifica per l'utente

Dopo che Claude esegue `/add-task`, verifica:

- [ ] Ha verificato se il task esisteva già?
- [ ] Ha valutato la complessità?
- [ ] (Se significativo) Ha creato un design log?
- [ ] (Se significativo) Ha fatto domande?
- [ ] (Se significativo) Si è fermato ad aspettare risposte?
- [ ] (Se significativo) Ha chiesto approvazione esplicita?
- [ ] Ha portato il task in `FOCUS.md` (🔄 in corso) prima di implementare?
- [ ] Ha rispettato done=validato (R.16): in DONE/FIXED solo se l'utente ha validato; altrimenti TO_TEST + FOCUS 🧪?
- [ ] Ha aggiornato i file di tracking alla fine (DONE.md/FIXED.md + TODO.md/TO_FIX.md + PROGRESS.md indice)?
- [ ] Ha aggiornato il design log alla fine (se esiste)?

Se manca qualcosa, Claude non ha seguito il comando correttamente.
