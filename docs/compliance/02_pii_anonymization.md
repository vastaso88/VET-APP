# Anonimizzazione dei dati sensibili (PII)

## Confine (deciso esplicitamente)

L'anonimizzazione si applica **solo al testo inviato al provider LLM esterno** (oggi Groq), non ai dati salvati internamente. Nel database interno i dati restano identificabili: servono per finalità di cura reale (richiamare il cliente, storico clinico del pet). Non c'è anonimizzazione at-rest in questa iterazione — è una scelta deliberata, non una dimenticanza.

In [chat_orchestrator.py](../../packages/core/application/services/chat_orchestrator.py), il testo libero dell'utente (`message`) e il nome del pet (`pet_name`, potenzialmente un nome di persona in casi limite) passano per `_anonymize_for_provider(...)` prima di entrare in `LLMGenerationRequest.user_prompt`. La retrieval delle evidenze (`_evidence_retriever.retrieve(...)`) usa invece il testo originale — è un servizio locale, non una chiamata esterna, quindi non rientra nel confine dell'anonimizzazione. Se in futuro la retrieval diventasse un servizio esterno, questo confine andrebbe rivisto esplicitamente, non esteso implicitamente. La risposta del modello (`result.answer`) non viene mai anonimizzata: torna identificabile al client e al database.

## Meccanismo

- Port: [`PiiAnonymizer`](../../packages/core/application/ports/pii_anonymizer.py) — stesso pattern di `LLMClient`.
- Adapter di default: [`NoopPiiAnonymizer`](../../packages/infrastructure/privacy/noop_pii_anonymizer.py) (pass-through) — usato quando `PII_ANONYMIZER_BACKEND=noop` (default), inclusi test e CI.
- Adapter locale reale: [`PresidioPiiAnonymizer`](../../packages/infrastructure/privacy/presidio_pii_anonymizer.py), basato su [Microsoft Presidio](https://microsoft.github.io/presidio/) + un modello spaCy italiano. Gira interamente offline: nessun testo lascia il processo durante questo passaggio. Attivabile con `PII_ANONYMIZER_BACKEND=presidio` dopo il setup descritto in [docs/runbooks/pii_anonymizer_setup.md](../runbooks/pii_anonymizer_setup.md).

## Cosa viene rilevato (e cosa no)

Presidio, tramite il modello spaCy italiano, riconosce automaticamente nomi di persona (NER), email, numeri di telefono generici, e altre entità comuni. Formati italiani specifici (es. codice fiscale) richiedono pattern dedicati registrati in `PresidioPiiAnonymizer._build_italian_recognizers()`.

**Disclaimer sul rischio residuo**: il riconoscimento NLP è probabilistico, non una garanzia assoluta. Un nome scritto in modo insolito, un numero di telefono in un formato non standard, o un riferimento indiretto possono non essere rilevati. Questo meccanismo riduce il rischio di esposizione di PII al provider esterno, non lo elimina; è un livello di difesa aggiuntivo, non l'unico.
