# Resume Session Command

Carica una sessione SPECIFICA (diversa dalla più recente).

## Differenza da /startsession

| Comando | Cosa carica | Quando usarlo |
|---------|-------------|---------------|
| `/startsession` | Sempre la sessione piu' recente per nome | SEMPRE all'inizio |
| `/resumesession [file]` | Sessione specifica | Per riprendere sessione passata |

## Usage

```
/resumesession [nome-file-sessione]
```

Esempi:
```
/resumesession 2026-01-20-23-15
/resumesession 2026-01-21-00-38.md
```

---

## STEP OBBLIGATORI

### STEP 1: Lista sessioni disponibili

Se l'utente non specifica un file, mostra le sessioni disponibili.

**OUTPUT OBBLIGATORIO:**
```
📁 Sessioni disponibili:

| File | Data | Summary |
|------|------|---------|
| 2026-01-21-00-38.md | 2026-01-21 | [prima riga del summary] |
| 2026-01-20-23-50.md | 2026-01-20 | [prima riga del summary] |
| ... | ... | ... |

Quale sessione vuoi caricare?
```

---

### STEP 2: Verifica file esiste

**OUTPUT OBBLIGATORIO:**
```
🔍 Verifica sessione:
✅ File trovato: design-log/sessions/[nome].md
```

Se non trovato:
```
❌ File non trovato: design-log/sessions/[nome].md

Sessioni disponibili:
[lista]
```

---

### STEP 3: Leggi sessione specificata

Leggi il file della sessione richiesta.

**OUTPUT OBBLIGATORIO:**
```
📖 Sessione caricata:
✅ design-log/sessions/[nome].md ([N] righe)
```

---

### STEP 4: Mostra contesto della sessione

**OUTPUT OBBLIGATORIO:**
```
📅 **Sessione**: [nome file]

📝 **Summary**:
[contenuto Session Summary]

📊 **Stato al momento della sessione**:
- Working on: [da Currently Working On]
- Procedure state: [da Procedure State]

🎯 **Handoff Notes di quella sessione**:
- [punto 1 da Immediate Next Steps]
- [punto 2]

⚠️ **Nota**: Questa è una sessione passata, non latest.
Per verificare lo stato attuale, usa /startsession.
```

---

### 🛑 STEP 5: FERMATI - Aspetta istruzioni

**OUTPUT OBBLIGATORIO:**
```
Sessione [nome] caricata.

Vuoi:
A) Continuare da dove questa sessione si era interrotta
B) Solo consultare questa sessione e tornare alla piu' recente
C) Altro

Cosa preferisci?
```

**NON procedere finché l'utente non risponde.**

---

## Checklist di verifica per l'utente

Dopo che Claude esegue `/resumesession`, verifica:

- [ ] Ha mostrato le sessioni disponibili (se non specificato)?
- [ ] Ha verificato che il file esiste?
- [ ] Ha mostrato il contenuto della sessione?
- [ ] Ha avvisato che è una sessione passata?
- [ ] Si è fermato ad aspettare istruzioni?

Se manca qualcosa, Claude non ha seguito il comando correttamente.
