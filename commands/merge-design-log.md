# Merge Design-Log Command

Merge un branch sul target (default `main`) gestendo correttamente i file condivisi del design-log per evitare conflitti rumorosi e perdita di entry.

## Quando usarlo

Quando hai sviluppato una feature/release su un branch separato che ha modificato:
- `design-log/PROGRESS.md`
- `design-log/LEARNED.md`
- `design-log/issues/_INDEX.md`
- (eventualmente) `design-log/BEHAVIORS.md`, `PROJECT.md`, `METHODOLOGY.md`

E ora vuoi mergiare quel branch sul target senza:
- Conflitti merge "stupidi" sui file sezionati
- Perdita di entry DONE/TODO/Pattern/Errori
- Inquinamento permanente della history del source-branch (che resta vivo per altri bugfix fino al rilascio)

---

## Usage

```
/merge-design-log <source-branch> [--into <target>]
/merge-design-log --resume <source-branch>
```

Esempi:
```
/merge-design-log release-2.x
/merge-design-log feature/login --into develop
/merge-design-log release-2.x --resume          # ripresa dopo conflitti reali
```

Default `--into`: `main`.

---

## Cosa fa (modello mentale)

1. Sul source: sposta i file sezionati in `design-log/branches/<source>/` e committa "isolate"
2. Checkout target → `git merge <source>` (porta su target il commit "isolate" + tutti i commit della feature, niente conflitto sui file isolati)
3. Sul target: fonde le entry da `branches/<source>/...` dentro i file di main (sync-from-branch), committa "sync"
4. Sul source: `git reset --hard <pre-isolate-sha>` → il commit "isolate" sparisce, file ai path originali, history pulita ex-ante

Risultato:
- **Source branch**: ex-ante (file ai path originali, nessun commit di plumbing)
- **Target branch**: storia esplicita del merge + cartella `branches/<source>/` come archivio permanente

---

## STEP OBBLIGATORI

### STEP 0: Preflight

Verifica precondizioni.

```bash
git status --short
git rev-parse --verify <source-branch>
git rev-parse --verify <target-branch>
git rev-parse <source-branch>   # memorizza pre-isolate-sha
```

**OUTPUT OBBLIGATORIO:**
```
🔧 Preflight:
✅ Working tree pulito
✅ Source branch <source> esiste
✅ Target branch <target> esiste
🔖 Pre-isolate SHA: <abbrev>
```

Se working tree NON è pulito → STOP, chiedi all'utente di committare/stash prima di rilanciare.

---

### STEP 1: Detect file da isolare

Il comando isola SEMPRE: `PROGRESS.md`, `LEARNED.md`, `issues/_INDEX.md`.

Isola CONDIZIONALMENTE (se modificati su <source> rispetto a <target>): `BEHAVIORS.md`, `PROJECT.md`, `METHODOLOGY.md`.

Detect via:
```bash
git diff --name-only <target>...<source> -- design-log/BEHAVIORS.md design-log/PROJECT.md design-log/METHODOLOGY.md
```

**OUTPUT OBBLIGATORIO:**
```
📋 File da isolare:
  Sempre:
  ✅ design-log/PROGRESS.md
  ✅ design-log/LEARNED.md
  ✅ design-log/issues/_INDEX.md
  Conditional (modificati su <source>):
  ✅ design-log/PROJECT.md (sì) | ⏭️ (no)
  ✅ design-log/BEHAVIORS.md (sì) | ⏭️ (no)
  ✅ design-log/METHODOLOGY.md (sì) | ⏭️ (no)
```

---

### STEP 2: Detect collisione `branches/<source>/`

Se `design-log/branches/<source>/` esiste già su <target> (es. da merge precedente con stesso nome branch ricreato) → usa suffisso timestamp.

```bash
git ls-tree --name-only <target> design-log/branches/ | grep -x "design-log/branches/<source>"
```

**OUTPUT OBBLIGATORIO:**
```
📂 Destinazione archivio:
✅ design-log/branches/<source>/
  oppure
⚠️ design-log/branches/<source>/ esiste già su <target> → uso design-log/branches/<source>-YYYY-MM-DD-HH-MM/
```

Memorizza `BRANCH_DEST` (path effettivo).

---

### STEP 3: Pre-merge isolation (sul source)

Sul source-branch:
1. Copia i file branch nei `<BRANCH_DEST>/...` (preserva la versione branch come archivio)
2. Sovrascrivi i file in posizione originale con la versione del target (`git checkout <target> -- <file>`). Questo evita che il `git merge` cancelli/sostituisca i file di target — al merge, target ha già la sua versione e `<BRANCH_DEST>/` è solo un'aggiunta.
3. Committa "isolate"

```bash
git checkout <source>
mkdir -p <BRANCH_DEST>
mkdir -p <BRANCH_DEST>/issues

# 1) Copia versione branch nell'archivio (non git mv: il file resta anche in posizione originale)
cp design-log/PROGRESS.md <BRANCH_DEST>/PROGRESS.md
cp design-log/LEARNED.md <BRANCH_DEST>/LEARNED.md
cp design-log/issues/_INDEX.md <BRANCH_DEST>/issues/_INDEX.md
git add <BRANCH_DEST>/PROGRESS.md <BRANCH_DEST>/LEARNED.md <BRANCH_DEST>/issues/_INDEX.md

# Conditional (solo se identificati a STEP 1)
cp design-log/BEHAVIORS.md <BRANCH_DEST>/BEHAVIORS.md
cp design-log/PROJECT.md <BRANCH_DEST>/PROJECT.md
cp design-log/METHODOLOGY.md <BRANCH_DEST>/METHODOLOGY.md
git add <BRANCH_DEST>/BEHAVIORS.md <BRANCH_DEST>/PROJECT.md <BRANCH_DEST>/METHODOLOGY.md

# 2) Sovrascrivi i file in posizione originale con la versione di target
#    (così il merge sarà pulito: target ha le sue versioni, source ha le stesse + l'archivio nuovo)
git checkout <target> -- design-log/PROGRESS.md design-log/LEARNED.md design-log/issues/_INDEX.md
# Conditional (solo se identificati a STEP 1)
git checkout <target> -- design-log/BEHAVIORS.md design-log/PROJECT.md design-log/METHODOLOGY.md

# 3) Commit
git commit -m "isolate design-log for merge into <target>"
```

**Perché `cp` + `git checkout target --` invece di `git mv`?**
Con `git mv`, il merge porta su target lo stato post-isolate (file SPOSTATI), facendo sparire i file di target dalla loro posizione originale. Con la strategia "copia + sovrascrivi": dopo l'isolate, su <source> i file in posizione originale sono uguali a quelli di target → il merge applica solo l'aggiunta di `<BRANCH_DEST>/` (zero modifiche ai file in posizione originale di target).

**OUTPUT OBBLIGATORIO:**
```
🔀 Isolation completata:
✅ Copiati N file in <BRANCH_DEST>/
✅ File in posizione originale sostituiti con versione di <target>
✅ Commit "isolate design-log for merge into <target>"
🔖 Isolate SHA: <abbrev>
```

---

### STEP 4: Merge sul target

```bash
git checkout <target>
git merge <source>
```

**OUTPUT OBBLIGATORIO (caso success):**
```
🤝 Merge eseguito:
✅ git merge <source> → <target>
✅ Merge commit: <abbrev>
```

**Caso CONFLITTI REALI** (su file applicativi, non design-log):
```
⛔ CONFLITTI REALI rilevati su:
  - <file1>
  - <file2>
  ...

Risolvi manualmente, poi:
  git add <file1> <file2>
  git commit
  /merge-design-log --resume <source>

(Il sync-from-branch verrà eseguito dopo la risoluzione.)
```
STOP — non procedere oltre. Aspetta la riesecuzione con `--resume`.

---

### STEP 5: Sync-from-branch (sul target)

Per ogni file in `<BRANCH_DEST>/` applica la logica corretta.

#### 5a: PROGRESS.md (entry-based)

Per la sezione `## ✅ DONE`:
- Estrai dal file branch tutte le entry. Header pattern: `### YYYY-MM-DD - <Title>`.
- Per ogni entry, cerca match esatto su `### YYYY-MM-DD - <Title>` in target.
- Se NON presente → inserisci in target mantenendo ordine cronologico inverso (più recenti in cima sotto `## ✅ DONE`).

Per la sezione `## 📋 TODO` (subsection 🔴/🟡/🟢):
- Pattern: `#### <Title>` o `#### ~~<Title>~~ ✅ FATTO`.
- Per ogni TODO branch, cerca match su `#### <Title>` (ignorando ~~) in target.
- Se NON presente → append in fondo alla stessa subsection di priorità.

Aggiorna in target:
- `> Last updated:` al più recente tra branch e target
- `> Last session:` al più recente tra branch e target

#### 5b: LEARNED.md (line-based)

Sezioni: `## Pattern Tecnici`, `## Errori da Non Ripetere`, `## Preferenze Utente`, `## Soluzioni Riutilizzabili`.

Per ogni sezione:
- Pattern entry: riga che inizia con `- **<key>**: <body>`
- Per ogni riga del branch, match esatto in target.
- Se NON presente → append in fondo alla stessa sezione, preceduto al primo append da:
  ```
  <!-- merged from branch <source> on YYYY-MM-DD -->
  ```

Aggiorna `> Ultimo aggiornamento:` al più recente.

#### 5c: _INDEX.md (rebuild totale)

Scansiona `design-log/issues/*.md` (esclusi `_INDEX.md`).
Per ogni file leggi: tipo, severity/priority, status, created, title.
Ricostruisci le tabelle `## 🐛 Bugs`, `## ✨ Enhancements`, `## 👀 Reviews` + sezione `## Quick Stats` + `## Recent Activity`.

#### 5d: BEHAVIORS / PROJECT / METHODOLOGY (warning manuale)

Se isolati a STEP 1 → NON applicare merge automatico. Lascia il file di target intatto e segnala:

```
⚠️ <file> modificato sul branch ma NON mergeato automaticamente.
   Versione branch in: <BRANCH_DEST>/<file>
   Merge manuale richiesto. Apri il file e integra a mano.
```

#### 5e: Commit del sync

```bash
git add design-log/PROGRESS.md design-log/LEARNED.md design-log/issues/_INDEX.md
git commit -m "sync design-log entries from branch <source>"
```

**OUTPUT OBBLIGATORIO:**
```
🔄 Sync-from-branch completato:
✅ PROGRESS.md: N entry DONE aggiunte, M TODO aggiunti
✅ LEARNED.md: K righe aggiunte (con marker)
✅ issues/_INDEX.md: rebuild da issues/ (X issue indicizzate)
⚠️ J file con merge manuale richiesto (vedi sopra)
✅ Commit "sync design-log entries from branch <source>"
🔖 Sync SHA: <abbrev>
```

---

### 🛑 STEP 6: WARNING + reset del source

Mostra l'avviso PRIMA di procedere col reset.

**OUTPUT OBBLIGATORIO:**
```
🛑 RESET DEL SOURCE — CONFERMA RICHIESTA

Sto per resettare <source> a <pre-isolate-sha> (rimuovendo "isolate" dalla history).
Questo riporta i file ai path originali (ex-ante) e mantiene la history del source pulita.

⚠️ ATTENZIONE: se <source> è già pushato sul remote, dopo il reset servirà:
   git push --force origin <source>

Se più persone lavorano sullo stesso branch, il force-push richiede coordinamento.

Procedere col reset? (sì/no)
- sì  → reset + ritorno al target
- no  → fine: il commit "isolate" resta nella history di <source> (variante "rumorosa")
```

**NON procedere finché l'utente non conferma.**

Su CONFERMA:
```bash
git checkout <source>
git reset --hard <pre-isolate-sha>
git checkout <target>
```

**OUTPUT (dopo reset):**
```
🔁 Reset del source completato:
✅ <source> ora a <pre-isolate-sha> (ex-ante)
✅ Tornato a <target>

⚠️ Ricorda: se <source> era pushato, esegui:
   git push --force origin <source>
```

Su RIFIUTO:
```bash
git checkout <target>
```

**OUTPUT:**
```
⏭️  Reset saltato. <source> mantiene il commit "isolate" nella history.
✅ Tornato a <target>
```

---

### STEP 7: Riepilogo finale

**OUTPUT OBBLIGATORIO:**
```
✅ MERGE-DESIGN-LOG COMPLETATO

📂 Source: <source>
📂 Target: <target>
📁 Archivio permanente: <BRANCH_DEST>/

🔄 Sync automatico:
- PROGRESS.md: N DONE + M TODO aggiunti
- LEARNED.md: K righe aggiunte
- issues/_INDEX.md: rebuild da X issue

⚠️ Merge manuale richiesto su:
- <file1> (vedi <BRANCH_DEST>/<file1>)
- ...

🌿 Source dopo merge:
  ✅ ex-ante (resettato)
  oppure
  ⏭️ commit "isolate" mantenuto

Prossimi passi:
- Verifica i file con merge manuale (se ci sono)
- (Se source pushato e resettato) git push --force origin <source>
- (Se necessario) push del target: git push origin <target>
```

---

## Modalità --resume

Quando il merge automatico (STEP 4) trova conflitti reali su file applicativi:

1. Lo script si ferma a STEP 4 con istruzioni
2. L'utente risolve i conflitti, fa `git add` e `git commit`
3. L'utente lancia `/merge-design-log --resume <source>`

`--resume` salta STEP 0-4 (assume già su <target> con merge committato) e riparte da STEP 5 (sync-from-branch).

**Verifiche pre-resume**:
```bash
git status --short                                # deve essere pulito (post-commit del merge)
git rev-parse --abbrev-ref HEAD                   # deve essere <target>
ls design-log/branches/<source>/                  # deve esistere (lasciato dall'isolation)
```

Se uno dei check fallisce → STOP + diagnosi.

---

## Checklist di verifica per l'utente

Dopo che Claude esegue `/merge-design-log`, verifica:

- [ ] Ha mostrato preflight (working tree pulito, branch esistenti, pre-isolate SHA)?
- [ ] Ha mostrato la lista dei file da isolare (sempre + conditional)?
- [ ] Ha gestito eventuale collisione di `branches/<source>/` con suffisso timestamp?
- [ ] Ha fatto isolation con `git mv` e commit "isolate"?
- [ ] Ha eseguito `git merge` sul target (e in caso di conflitti reali, ha STOPpato con istruzioni resume)?
- [ ] Ha eseguito sync-from-branch automatico per PROGRESS, LEARNED, _INDEX?
- [ ] Ha segnalato (con WARNING) i file con merge manuale richiesto (BEHAVIORS/PROJECT/METHODOLOGY)?
- [ ] Ha commitato il sync su target?
- [ ] Ha mostrato WARNING + chiesto conferma PRIMA del reset del source?
- [ ] (Se confermato) Ha fatto reset del source + ricordato che serve `git push --force` se il branch era pushato?
- [ ] Ha mostrato riepilogo finale con archivio + prossimi passi?

Se manca qualcosa, Claude non ha seguito il comando correttamente.
