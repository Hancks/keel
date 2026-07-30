## 🛠️ Principi — Tier 2a: progetti SOFTWARE

- **Debugging sistematico (non a tentoni).** Se qualcosa non funziona: alza al MAX i log → disegna test → disegna scenari → esegui → verifica il flusso leggendo i log → analizza le differenze tra atteso e reale. Niente trial-and-error cieco.
- **Sviluppo con verifica degli obiettivi.** Ogni implementazione è accoppiata a una verifica che controlla che faccia davvero ciò che serve — non solo che "compili". «Compila ≠ funziona»: traccia i flussi.
- **Pianificazione test (light).** Prima/insieme all'implementazione, definisci i pochi test che dimostrano il comportamento. Versione leggera del test-driven: pochi test che contano, non copertura totale.
- **Validazione dei modelli e con test.** Dati/modelli si validano su input **reali rappresentativi**; le fixture d'integrazione si **catturano dal servizio reale**, non si scrivono dall'assunzione del codice (un test che si dà ragione da solo non prova nulla).
- **Confutazione delle assunzioni in progettazione.** Ogni design significativo passa da un confutatore che prova a **smontarne le assunzioni** prima di implementare (è qui che nascono i loop-bug: prevenirli a monte).
