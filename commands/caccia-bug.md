---
description: Caccia-bug esplicita "light" — finder per lente (Opus) + confutatore/validatore per finding (Fable), motore Workflow, report triagato per impatto. On-demand.
---

# /caccia-bug — caccia-bug light (Design-Log v2 · Fase 2b)

Cerchi ciò che è **già rotto e visibile** nel codice, on-demand, con le lenti che scegli. Motore: pochi **finder forti** (Opus, uno per lente) + tanti **confutatori/validatori economici** (Fable 5, uno per segnalazione). Output: un **report triagato per impatto** su file + triage **voce-per-voce**.

> ⚠️ Limite onesto (dillo nel report): questa caccia trova solo bug con un **sintomo leggibile ora**. La classe «scelta corretta oggi che arma una trappola domani» (nessun sintomo attuale) le è **cieca** — quella vive nella **confutazione-in-progettazione** (skill `adversarial-review`), non qui. Un report pulito **non** dimostra che il codice è pulito.

Eseguito dall'agente **top-level** (che possiede il tool `Workflow`; i sub-agenti no). Invocare questo comando **è** l'autorizzazione a usare `Workflow`.

---

## STEP 1 — Scegli le lenti (menu)

Chiedi con **AskUserQuestion** (multiSelect) quali lenti attivare. Catalogo (una o più, anche non-bug):

| Lente | Cosa cerca | Modo |
|---|---|---|
| `correttezza` | logica che non fa ciò che promette | bug |
| `sicurezza` | injection, secret, input non validato, SSRF/path traversal | bug |
| `permessi` | authz mancante/aggirabile, isolamento, IDOR | bug |
| `dati` | perdita/corruzione, non-atomicità, stato derivato-vs-registrato | bug |
| `robustezza` | what-if: fallimento a metà, rete giù, input vuoto/enorme, valore-costante-che-cambia | bug |
| `codice-morto` | funzioni/branch mai raggiunti | validation |
| `efficienza` | lavoro ridondante materiale (hot path) | validation |
| `requisiti` | dove il codice viola la fonte-requisiti | validation |

Se l'utente ha passato lenti come argomenti (`$ARGUMENTS`), usale e salta il menu.

## STEP 2 — Bersaglio (default = diff corrente → file interi)

Default: le **modifiche correnti**. Ricava i file toccati e passali **interi** (non solo le righe del diff — il confutatore ha bisogno del contorno).

```
git rev-parse --is-inside-work-tree 2>/dev/null && \
  git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null
```

Guardie (fermati e chiedi PRIMA di procedere):
- **niente git** → non c'è un diff: chiedi se scandagliare una cartella/file indicati o «tutto il progetto».
- **diff vuoto** (branch pulito) → NON far girare i finder a vuoto (allucinerebbero): chiedi il bersaglio (path o «tutto»).
- **diff enorme** (molti file o >~2000 righe) → avvisa del costo-tempo e **chiedi conferma** o restringi.
- L'utente può sempre passare un path in `$ARGUMENTS` o dire «tutto» → in quel caso `targetFiles=[]` (intero progetto) o i path dati.

## STEP 3 — Modello di esposizione + fonte-requisiti

Il triage per impatto ha bisogno di sapere **che tipo di progetto è** (il GUARDIAN qui può essere vuoto su un codebase esterno):
1. Leggi `design-log/PROJECT.md` tra i marker `NORTH_STAR:START`/`NORTH_STAR:END`. Se c'è, deducine l'esposizione.
2. Altrimenti **chiedi** (AskUserQuestion): `servizio-con-utenti` / `libreria-o-API` / `CLI` / `interno`. Questo mappa l'impatto (per una libreria «rompe l'API pubblica/il consumatore»; per un servizio «un utente lo incontra nel flusso»; per una CLI «l'utente perde dati / il comando fallisce»).
3. Se tra le lenti c'è `requisiti`: individua una **fonte-requisiti** (NORTH_STAR / un file di spec / testo dell'utente). Se non esiste → **disattiva** la lente `requisiti` con avviso (non inventare requisiti).

## STEP 4 — Motore: verifica poi lancia

1. **Verifica** di avere il tool `Workflow` disponibile in questa sessione.
2. **Se sì** → lancialo col workflow bundlato:
   ```
   Workflow({
     scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/caccia-bug.js",
     args: { lenses, targetFiles, targetLabel, exposureModel, requirementsSource, maxPerLens: 12 }
   })
   ```
   (finder Opus per lente → dedup per file:righe → confutatore/validatore Fable effort-high per finding → conteggi. Riprende da rate-limit con `resumeFromRunId` se serve.)
3. **Se `Workflow` NON è disponibile** (gated/assente) → **fallback**: orchestra tu al top-level lo stesso pipeline con il tool `Agent` (un `bug-finder` per lente in parallelo → dedup → un `bug-refuter` per finding). ⚠️ Dichiara nel report che **senza `Workflow` non c'è resume da rate-limit** (una caccia lunga interrotta va rifatta).

Non far spawnare sub-agenti ai finder (non possono): il fan-out lo fai **tu**.

## STEP 5 — Report su file (PRIMA del triage interattivo)

Appena il motore ritorna, **scrivi subito** il report — così non si perde nulla al compattamento (FM2):
- Percorso: `design-log/caccia/YYYY-MM-DD-HH-MM.md` (ricava data/ora con `date +%Y-%m-%d-%H-%M`; crea la cartella se manca).
- Contenuto: intestazione (bersaglio, lenti, esposizione, conteggi grezze→dedup→confermati/scartati); i **confermati raggruppati per impatto** `A → B-pubblico → B-tecnico → C`, ognuno con `file:righe · scenario · evidenza del confutatore`; una sezione **scartati** (con il perché); il **disclaimer** falsi-negativi + «trappola-senza-sintomo fuori portata (sta in `adversarial-review`)»; un **«in una riga»** finale.

## STEP 6 — Triage voce-per-voce (Q4)

Nessuna scrittura automatica nel tracking. Presenta i **confermati** uno a uno (dal più alto impatto) e per ciascuno proponi la destinazione, l'utente conferma:
- **bug reale** → `design-log/TO_FIX.md` (con severità dall'impatto);
- **non-bug / miglioramento / idea** → `design-log/INBOX.md` (cattura grezza, R.15);
- **falso/irrilevante** → 🗑 (scartato con un perché).

Scrivi nel tracking **solo** ciò che l'utente conferma. Alla fine: breve riepilogo (quanti in TO_FIX / INBOX / cestino) + link al file report.

---

## Note
- **Costo/scala («light»)**: light = **NON lanciare centinaia di agenti**. Finder **Opus** (uno per lente, pochi) + confutatori **Fable** (uno per finding, cap `maxPerLens: 12`) + **scope limitato** (path caldi, non «tutto il progetto» su codebase grandi). Molte lenti × tutto-il-progetto = salasso: **restringi il bersaglio** e avvisa del costo prima.
- **R.16**: la caccia trova; le fix sono task a parte. Nulla va in DONE per aver girato la caccia.
