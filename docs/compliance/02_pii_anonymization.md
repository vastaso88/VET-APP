# Anonimizzazione dei dati sensibili (PII)

## Confine (deciso esplicitamente)

L'anonimizzazione si applica **al testo inviato al provider LLM esterno** (oggi Groq) e ai testi derivati che conserviamo per uso interno della chat o del team (trascrizione degli allegati, segnalazioni delle risposte). I dati inseriti dal proprietario nel database restano identificabili: servono per finalità di cura reale (storico clinico del pet). Non c'è anonimizzazione at-rest di quei dati — è una scelta deliberata, non una dimenticanza.

La retrieval delle evidenze (`_evidence_retriever.retrieve(...)`) usa il testo originale — è un servizio locale, non una chiamata esterna. Se in futuro diventasse un servizio esterno, questo confine andrebbe rivisto esplicitamente. La risposta del modello non viene anonimizzata: torna al client così com'è.

## Dove viene applicata

| Punto | Cosa passa dal filtro |
|---|---|
| [chat_orchestrator.py](../../packages/core/application/services/chat_orchestrator.py) `_anonymize_for_provider` | messaggio dell'utente, **turni precedenti della conversazione**, nome e note del pet, note dell'habitat, promemoria, riassunto della cartella clinica **nel prompt della risposta** (non nello stato della conversazione: vedi «Cosa NON copre»), messaggio e storico passati all'estrazione del "situation model" |
| [document_summarizer.py](../../packages/core/application/services/document_summarizer.py) | testo estratto da un PDF, prima di inviarlo al modello |
| [upload_chat_attachment.py](../../packages/core/application/services/upload_chat_attachment.py) | trascrizione di foto/PDF, prima di salvarla (è il testo che la chat rilegge in seguito) |
| [report_chat_response.py](../../packages/core/application/services/report_chat_response.py) | risposta segnalata e dettagli della segnalazione, prima di salvarli |

In tutti questi punti viene passato anche il **nome del proprietario** (`display_name` dell'account, letto dai metadati Supabase), così viene rimosso anche quando compare senza etichetta. Se coincide con il nome del pet non viene rimosso (cancellerebbe il nome di cui si sta parlando).

## Meccanismo

- Port: [`PiiAnonymizer`](../../packages/core/application/ports/pii_anonymizer.py).
- **Default: [`RuleBasedPiiAnonymizer`](../../packages/infrastructure/privacy/rule_based_pii_anonymizer.py)** (`PII_ANONYMIZER_BACKEND=rules`): regole deterministiche, nessuna dipendenza, gira anche su Vercel. Nessun testo lascia il processo durante questo passaggio.
- [`PresidioPiiAnonymizer`](../../packages/infrastructure/privacy/presidio_pii_anonymizer.py) (`PII_ANONYMIZER_BACKEND=presidio`): Presidio + spaCy italiano, solo dove sono installati ([setup](../runbooks/pii_anonymizer_setup.md)). Se manca, si ricade sulle regole, mai su "niente".
- [`NoopPiiAnonymizer`](../../packages/infrastructure/privacy/noop_pii_anonymizer.py) (`PII_ANONYMIZER_BACKEND=noop`): pass-through, rispettato **solo fuori produzione**. In produzione `noop` viene sostituito dalle regole.

## Cosa rimuove il filtro a regole

Email, telefoni italiani (cellulari e fissi, con o senza +39), codice fiscale, partita IVA, IBAN, URL e domini, indirizzi con numero civico (via/viale/piazza/corso… + civico, con CAP e comune se presenti), nomi preceduti da un'etichetta o un titolo ("Proprietario:", "Sig.", "Dott.ssa"…), nome e cognome del proprietario noti dall'account. Ogni valore è sostituito da un segnaposto (`[EMAIL]`, `[TELEFONO]`, `[INDIRIZZO]`, `[NOME]`…).

Non tocca mai: dosaggi, date, valori di laboratorio, pesi, numeri di microchip.

## Cosa NON copre (rischio residuo)

- Nomi di persona senza etichetta e non noti dall'account (es. il nome di un familiare o del veterinario scritto in mezzo a una frase): servirebbe un modello NER (Presidio).
- Indirizzi senza numero civico o scritti tutti in minuscolo; telefoni esteri o in formati insoliti.
- **Immagini e audio**: la foto di un referto inviata al modello di visione e l'audio inviato alla trascrizione partono così come sono; viene ripulito solo il testo che ne risulta.
- Il nome del proprietario è rimosso solo se l'account ha un `display_name`.
- **Il riassunto della cartella clinica nello stato della conversazione** (`SituationModel.known_medical_context`, salvato con la conversazione) è il testo originale, non filtrato (verificato il 2026-10-06). Lo ricevono così com'è due chiamate al fornitore esterno: l'estrazione del situation model (`situation_model_builder.py`, «Situation known so far») e il planner dell'intervista (`interview_planner.py`, «Case so far»). Il filtro è applicato solo al riassunto che entra nel prompt della risposta (`_medical_context_for_prompt`). Correzione proposta: anonimizzare il riassunto quando viene messo nello stato, in `chat_orchestrator.py` dove si costruisce `SituationModel(known_medical_context=...)` (due punti). Registro 08, punto 28.

È un livello di riduzione del rischio, non una garanzia assoluta.
