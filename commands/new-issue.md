# New Issue Command

Crea una nuova issue in `design-log/issues/`.

## Usage

```
/new-issue [type] [title]
```

Dove:
- `type`: bug | enhancement | review
- `title`: Titolo breve descrittivo

Esempi:
```
/new-issue bug Login fallisce su mobile
/new-issue enhancement Aggiungere dark mode
/new-issue review Verificare performance query
```

---

## STEP OBBLIGATORI

### STEP 1: Verifica struttura

**OUTPUT OBBLIGATORIO:**
```
📁 Verifica struttura:
✅ design-log/issues/ esiste
✅ design-log/issues/_INDEX.md esiste
```

Se manca qualcosa, crealo:
```
❌ design-log/issues/ non esiste → CREATA
❌ _INDEX.md non esiste → CREATO
```

---

### STEP 2: Parse o chiedi dettagli

Se type/title forniti:
```
📋 Issue:
- Tipo: [bug/enhancement/review]
- Titolo: [titolo]
```

Se non forniti, chiedi:
```
❓ Che tipo di issue?
- 🐛 bug - Qualcosa non funziona
- ✨ enhancement - Miglioramento
- 👀 review - Da verificare

❓ Qual è il titolo?
```

---

### STEP 3: Chiedi severity/priority

Per bug:
```
❓ Severity?
- 🔴 critical - Sistema inutilizzabile
- 🟠 major - Feature importante rotta
- 🟡 minor - Problema minore, workaround esiste
- ⚪ trivial - Cosmetico
```

Per enhancement/review:
```
❓ Priority?
- 🔴 high
- 🟡 medium
- 🟢 low
```

---

### STEP 4: Determina prossimo ID

Conta file esistenti per determinare ID.

**OUTPUT OBBLIGATORIO:**
```
🔢 ID assegnato:
- Tipo: [BUG/ENH/REV]
- Numero: [NNN]
- ID completo: [TYPE]-[NNN]
```

---

### STEP 5: Chiedi descrizione

```
❓ Descrivi l'issue in dettaglio:
- Cosa succede? (per bug)
- Cosa vuoi ottenere? (per enhancement)
- Cosa va verificato? (per review)
```

---

### STEP 6: Crea file issue

Crea `design-log/issues/{TYPE}-{NNN}-{slug}.md`

**OUTPUT OBBLIGATORIO:**
```
📝 Issue creata:
✅ File: design-log/issues/[TYPE]-[NNN]-[slug].md

Contenuto:
- Titolo: [titolo]
- Tipo: [tipo]
- Severity/Priority: [livello]
- Status: in-progress
- Descrizione: [breve]
```

---

### STEP 7: Aggiorna _INDEX.md

Aggiungi riga alla tabella e aggiorna stats.

**OUTPUT OBBLIGATORIO:**
```
📊 _INDEX.md aggiornato:
✅ Nuova riga aggiunta alla tabella
✅ Stats aggiornate: In Progress [N]
```

---

### STEP 8: Riepilogo finale

**OUTPUT OBBLIGATORIO:**
```
✅ ISSUE CREATA

[TYPE]-[NNN]: [Titolo]

📁 File: design-log/issues/[TYPE]-[NNN]-[slug].md
📊 Severity/Priority: [livello]
📋 Status: in-progress

Prossimi passi:
- Lavorare sull'issue
- Quando risolto, aggiornare Solution e chiudere
```

---

## Issue Auto-Detection

Claude deve rilevare automaticamente potenziali issue durante la conversazione.

### Quando suggerire

1. **User menziona bug:**
   - "Non funziona...", "C'è un errore...", "Ho trovato un problema..."

2. **User suggerisce miglioramento:**
   - "Sarebbe bello se...", "Possiamo migliorare...", "Dovremmo ottimizzare..."

3. **User menziona verifica:**
   - "Dobbiamo controllare...", "Verifichiamo...", "Rivediamo..."

4. **Claude trova problema:**
   - Comportamento inaspettato, test failure, edge case

### Formato suggerimento

```
🔍 Ho notato qualcosa che potrebbe essere un'issue:
- Tipo: [bug/enhancement/review]
- Descrizione: [breve]

Vuoi che crei un'issue? (sì/no)
```

---

## Checklist di verifica per l'utente

Dopo che Claude esegue `/new-issue`, verifica:

- [ ] Ha verificato la struttura?
- [ ] Ha chiesto tipo e titolo (se non forniti)?
- [ ] Ha chiesto severity/priority?
- [ ] Ha assegnato ID corretto?
- [ ] Ha chiesto descrizione?
- [ ] Ha creato il file?
- [ ] Ha aggiornato _INDEX.md?
- [ ] Ha mostrato riepilogo finale?

Se manca qualcosa, Claude non ha seguito il comando correttamente.
