---
name: adversarial-review
description: Use at TWO moments, always. (1) When you have FINISHED a design / plan and are about to ask the user to approve it (e.g. closing the Design section of an /add-task, before the approval checkpoint) — run an adversarial critic that tries to demolish it FIRST. (2) When you have FINISHED implementing something and are about to declare it done — run a verifier + tester FIRST. Turns thesis (design/implementation) into antithesis (critique/verification) into synthesis (what survives). Addresses the loop-bug (FM4): un-confuted design and un-verified implementation are the reason real bugs accumulate.
---

# Adversarial review — tesi → antitesi → sintesi

Il cuore socratico del metodo: **niente si consegna alla prima stesura.** Due momenti, sempre.

## 1. Design chiuso → CONFUTA prima di chiedere l'approvazione

Quando hai finito di scrivere un Design/piano e stai per chiedere l'ok all'utente:

1. Lancia l'agent **`adversarial-critic`** sul design appena scritto (passagli il percorso del design log, o il testo del design + i requisiti/vincoli).
2. Il confutatore prova a **smontarlo**: assunzioni fragili, scenari in cui fallisce, cosa è dato per scontato, cosa manca. Non riscrive — attacca.
3. **Incorpora** la critica nel design (aggiorna Q&A / Trade-offs / Open questions; correggi o difendi ogni punto). Tesi (design) → antitesi (confutazione) → **sintesi** (design che regge).
4. **Solo ora** chiedi l'approvazione all'utente — presentando anche cosa il confutatore ha sollevato e come l'hai risolto.

> Vale per decisioni **di progettazione** significative (le decisioni vivono lì). Un fix banale (<3 file, ovvio) non richiede il giro.

## 2. Implementazione finita → VERIFICA + TESTA prima di dichiarare fatto

Quando hai finito di implementare e stai per dire «fatto» (o prima di muovere in DONE — lega R.16):

1. Lancia l'agent **`verifier`**: controlla che l'implementato rispetti **davvero i requisiti/il design**, punto per punto — non «compila = funziona».
2. Lancia l'agent **`tester`**: disegna ed esegue **scenari di prova** (incluso il caso limite / il what-if), legge l'output reale, confronta atteso vs reale.
3. Riporta l'esito (cosa regge / cosa no) **prima** di dichiarare fatto. Se qualcosa non regge → non è fatto: torna a sistemarlo. Ricorda che «fatto» = **validato dall'utente** (R.16), non «implementato».

## Perché (FM4)

Il loop-bug infinito nasce da implementazione **non verificata** + progettazione **non confutata** + nessun overseer. Questa skill mette confutazione e verifica **a monte**, sotto l'occhio del GUARDIAN (contesto/obiettivo/principi): così i bug veri non si accumulano. L'enforcement è **model-level** (questa skill ti obbliga ogni volta) — un hook shell non potrebbe né lanciare agenti né giudicare la qualità di un design.
