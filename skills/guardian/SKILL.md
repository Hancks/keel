---
name: guardian
description: Use BEFORE any significant decision or implementation, and especially when STARTING or SWITCHING a task (e.g. after /add-task) or resuming after a break/compaction — to verify it aligns with the project's NORTH_STAR (essence + invariants), the current FOCUS objective, and the cardinal principles. Catches hyper-focusing on the immediate sub-task while forgetting the overarching goal (e.g. building a feature while forgetting the project is a SaaS sold to clients).
---

# Guardian — coerenza con contesto / obiettivo / principi

Prima di una decisione significativa o di implementare, FERMATI e verifica:

1. **NORTH_STAR** — la decisione rispetta l'essenza del progetto e i suoi invarianti? (es. se è un SaaS multi-tenant, la feature rispetta multi-tenancy e fatturazione?)
2. **FOCUS** — stai lavorando sull'obiettivo 🔄 corrente o stai divagando? Una feature alla volta (R.17).
3. **Principi cardine** — done=validato · verifica avversariale · non-perdere-nulla (+ i principi del tipo di progetto: per software, debugging sistematico e verifica degli obiettivi).

Se la decisione contraddice uno di questi: **NON procedere alla cieca** — segnala la tensione all'utente e riallinea. Il GUARDIAN (iniettato dagli hook) tiene questi elementi sempre in contesto; questa skill è il momento in cui li **usi attivamente** per giudicare.
