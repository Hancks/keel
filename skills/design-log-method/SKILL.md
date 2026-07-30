---
name: design-log-method
description: Use when the user asks to implement, build, add, change, or fix something non-trivial (touches ~3+ files, is a new feature, or involves an architectural decision), OR when the user says "segna". Ensures significant work never bypasses the Design-Log process, even as sessions grow long.
---

# Design-Log method — riconoscimento e instradamento

Quando riconosci un **task significativo** (≥3 file, nuova feature, decisione architetturale):
- NON partire a implementare direttamente. **Proponi `/add-task`**: «Questo task richiede /add-task. Lo eseguo?» — è il meccanismo forzante (design-log + Q&A + approvazione, BEHAVIORS R.2).
- Task banale (<3 file, fix ovvio) → procedi.

Quando l'utente dice **"segna …"**: la cattura in `INBOX.md` la fa già l'hook `UserPromptSubmit`; verifica solo che sia avvenuta e trattala come **da triagiare**, non come «da fare subito».

Questa skill contrasta **FM8**: con l'andare della sessione la proposta di `/add-task` tende a decadere. Il riconoscimento del task significativo è model-level e **non deve decadere**: si riattiva a ogni richiesta pertinente.
