---
name: debug-sistematico
description: "Use when something is BROKEN or not behaving as expected — a bug, a failed test, a crash, a wrong output, 'it doesn't work' — BEFORE proposing or trying any fix. Forces the systematic protocol (instrument/observe the real flow, design tests/scenarios, run and READ the real output, diff expected vs actual, only then hypothesize and fix) instead of blind trial-and-error, writes an auditable Debug-log (expected vs actual), and after repeated failed fixes stops to consult the project LEARNED and question the architecture. This is the method's own debugging discipline (self-contained), tied to the project principi/GUARDIAN — not a generic reminder."
---

# Debug sistematico — non a tentoni (FM5)

> Il momento in cui **applichi** attivamente il principio cardine di debugging (`principi/software.md`, re-iniettato dal GUARDIAN). Il principio è il *cosa*; questa skill è il *fallo adesso, in quest'ordine, e lascia traccia*.

**Legge di ferro:** non cambiare codice per «provare» finché non hai **visto** dove il flusso reale diverge da quello atteso. Un fix prima dell'osservazione è trial-and-error cieco — l'anti-pattern che genera i loop-bug (FM4/FM5).

## Quando parte
Su **bug / test fallito / crash / output sbagliato / «non funziona» / comportamento inatteso**, **prima** di proporre o tentare qualunque fix. NON su un'iterazione normale (typo, path sbagliato, tweak-e-rilancia ovvio): lì non serve il rito.

## Confine con le altre skill (non sovrapporsi)
- `adversarial-review` → agente **`tester`**: verifica che un'implementazione *finita* rispetti i requisiti («compila ≠ funziona»), **prima** di dichiarare fatto. È a valle di un lavoro **che sembra riuscito**.
- **questa skill** → interviene quando qualcosa è **rotto** e va **diagnosticato**. Se durante il verify/test emerge un fallimento reale → si passa **di qui**.

## Il protocollo (in quest'ordine)

1. **Osserva il flusso reale — con lo strumento giusto** (passo condizionale, NON «alza i log» a prescindere):
   - flusso instrumentabile (funzioni, richieste, stato) → **alza i log al MAX** nei punti sospetti;
   - problema di **performance** → profiler/tracing, non log;
   - **UI/visuale** → screenshot/registrazione dello stato reale;
   - **config/build** → l'output reale del tool (build/lint/type-check), letto per intero;
   - **heisenbug / timing** → strumento che non altera il timing (contatori, tracce a basso costo);
   - riproducibile **solo in prod** → cattura lì (log/telemetria), non fingere in locale.
   L'obiettivo è **vedere la realtà**, con qualunque mezzo la mostri.

2. **Disegna il test / gli scenari** che riproducono il fallimento — incluso il caso limite e il **what-if** (input vuoto/enorme/malformato, passo a metà, rete giù). Scrivi l'**atteso** per ognuno *prima* di eseguire.

3. **Esegui e LEGGI l'output reale** — mai «verde» a memoria. Cattura numeri/errori/log veri (redirigi su file e leggi `$?` subito se una pipe può mascherare l'esito).

4. **Confronta atteso vs reale**, riga per riga, e **isola il punto** in cui divergono. È lì il bug, non dove immaginavi.

5. **Solo ora** forma l'ipotesi, applica **un** fix, e **ri-esegui** il test del passo 2 per confermare (e che non abbia rotto altro).

## Debug-log (OBBLIGATORIO — è ciò che rende il rito auditabile)
Scrivi una traccia — nel design log del task o in una nota `design-log/debug/…` — che chiunque possa rileggere. Minimo:
```
## Debug-log — <sintomo> (<data>)
- Osservato con: <log / profiler / screenshot / build-output>
- Atteso: <cosa doveva succedere>
- Reale: <cosa succede davvero, con evidenza: file:riga / output / valore>
- Punto di divergenza: <dove>
- Ipotesi → fix → esito della ri-verifica
```
Senza questo, «protocollo seguito» e «ho armeggiato finché è passato» sono indistinguibili — e il principio cardine è **«non perdere nulla: scrivi prima di agire»** (`core.md`). La traccia sopravvive al compattamento.

## Dopo ~2 fix falliti sullo stesso punto → FERMATI
Non insistere a caso (è il modo più veloce di bruciare tempo e fiducia):
1. **Consulta la memoria**: cerca in `LEARNED.md` (locale) e nei `LEARNED_GLOBAL/` di dominio un pattern già noto — spesso il bug (o un suo gemello) è già documentato.
2. **Scendi di astrazione**: alza ancora i log / vai un livello sotto (API → filesystem → protocollo grezzo), col mezzo più economico che isola la variabile.
3. **Cerca fuori**: forum autorevoli (issue del progetto/framework, Stack Overflow, doc ufficiale) — molte API hanno quirk non documentati ma noti.
4. **Al 3° fallimento**, non è più un fix: **metti in discussione l'architettura/l'assunzione** e parlane con l'utente. Una causa dedotta per esclusione **non è provata**: testala col mezzo più economico prima di agire su soluzioni grosse.

## Ramo non-software (stub — da consolidare)
> Gemello dello stub `principi/non-software.md` (ancora placeholder): quando sarà riempito, allineare qui.
Per un fallimento senza «log» (un documento sbagliato, una pipeline di ricerca, un output non-codice): il cuore resta **atteso vs reale**. **Isola la variabile** (cambia una cosa per volta), **misura** sul dato reale rappresentativo, **confronta** con ciò che ti aspettavi, e traccia lo stesso Debug-log.

## Onestà sul livello di enforcement
Questa è una **skill model-level**: ti *obbliga* nel momento, ma non è un blocco d'ambiente. La confutazione-in-progettazione (FM4) ha meritato anche un hard-block (`lock.sh`) perché l'invariante è verificabile da script; qui il «hai davvero seguito il protocollo?» non lo è, e il «blocco dopo 2 fix» resta un'idea futura (un hook shell non sa contare i fix sullo stesso punto). Rischio accettato consapevolmente — non nascosto.
