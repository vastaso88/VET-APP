# Anonimizzazione dei dati sensibili (PII)

## Confine (deciso esplicitamente)

L'anonimizzazione si applica **al testo inviato al provider LLM esterno** (oggi Anthropic come modello principale, quando è attivo, e Groq di riserva, per le immagini e per la trascrizione vocale) e ai testi derivati che conserviamo per uso interno della chat o del team (trascrizione degli allegati, segnalazioni delle risposte). I dati inseriti dal proprietario nel database restano identificabili: servono per finalità di cura reale (storico clinico del pet). Non c'è anonimizzazione at-rest di quei dati — è una scelta deliberata, non una dimenticanza.

La ricerca delle evidenze (`_evidence_retriever.retrieve(...)`) chiama servizi esterni di letteratura (Europe PMC, PubMed, Crossref, OpenAlex): riceve solo le parole chiave ricavate dal testo anonimizzato o, se non ci sono, il testo anonimizzato (dal 2026-11-08; prima ripiegava sulle parole originali). Il controllo di pertinenza e i recuperi locali continuano a usare il testo originale, senza uscire dal processo. La risposta del modello non viene anonimizzata: torna al client così com'è.

## Dove viene applicata

| Punto | Cosa passa dal filtro |
|---|---|
| [chat_orchestrator.py](../../packages/core/application/services/chat_orchestrator.py) `_anonymize_for_provider` | messaggio dell'utente, **turni precedenti della conversazione**, nome e note del pet, note dell'habitat, promemoria, riassunto della cartella clinica (nel prompt della risposta e quando entra nello stato della conversazione), messaggio e storico passati all'estrazione del "situation model", risposta alla domanda di consenso (quando passa dal modello leggero), testo di ricerca nelle evidenze |
| [document_summarizer.py](../../packages/core/application/services/document_summarizer.py) | testo estratto da un PDF, prima di inviarlo al modello |
| [upload_chat_attachment.py](../../packages/core/application/services/upload_chat_attachment.py) | trascrizione di foto/PDF, prima di salvarla (è il testo che la chat rilegge in seguito) |
| [groq_image_analyzer.py](../../packages/infrastructure/vision/groq_image_analyzer.py) | l'immagine parte intera, non filtrabile; il prompt chiede al modello di omettere nomi, indirizzi, telefoni e numeri di microchip o di identificazione dalla lettura, che poi passa dal filtro in `upload_chat_attachment.py` |
| [speech_to_text.py](../../apps/api/routes/speech_to_text.py) | l'audio parte intero verso la trascrizione e non viene salvato; il testo trascritto torna al client e passa dal filtro quando viene inviato come messaggio in chat |
| [report_chat_response.py](../../packages/core/application/services/report_chat_response.py) | risposta segnalata e dettagli della segnalazione, prima di salvarli |

In tutti questi punti viene passato anche il **nome del proprietario** (`display_name` dell'account, letto dai metadati Supabase), così viene rimosso anche quando compare senza etichetta. Se coincide con il nome del pet non viene rimosso (cancellerebbe il nome di cui si sta parlando).

## Meccanismo

- Port: [`PiiAnonymizer`](../../packages/core/application/ports/pii_anonymizer.py).
- **Default: [`RuleBasedPiiAnonymizer`](../../packages/infrastructure/privacy/rule_based_pii_anonymizer.py)** (`PII_ANONYMIZER_BACKEND=rules`): regole deterministiche, nessuna dipendenza, gira anche su Vercel. Nessun testo lascia il processo durante questo passaggio.
- [`PresidioPiiAnonymizer`](../../packages/infrastructure/privacy/presidio_pii_anonymizer.py) (`PII_ANONYMIZER_BACKEND=presidio`): Presidio + spaCy italiano, solo dove sono installati ([setup](../runbooks/pii_anonymizer_setup.md)). Se manca, si ricade sulle regole, mai su "niente".
- [`NoopPiiAnonymizer`](../../packages/infrastructure/privacy/noop_pii_anonymizer.py) (`PII_ANONYMIZER_BACKEND=noop`): pass-through, rispettato **solo fuori produzione**. In produzione `noop` viene sostituito dalle regole.

## Cosa rimuove il filtro a regole

Email, telefoni italiani (cellulari e fissi, con o senza +39), codice fiscale, partita IVA, IBAN, URL e domini, indirizzi con numero civico (via/viale/piazza/corso… + civico, con CAP e comune se presenti), nomi preceduti da un'etichetta o un titolo ("Proprietario:", "Sig.", "Dott.ssa"…), nome e cognome del proprietario noti dall'account. Ogni valore è sostituito da un segnaposto (`[EMAIL]`, `[TELEFONO]`, `[INDIRIZZO]`, `[NOME]`…).

Non tocca mai: dosaggi, date, valori di laboratorio, pesi. Il **numero di microchip** invece viene sempre sostituito con `[MICROCHIP]` (decisione del proprietario, 2026-11-08): attraverso l'anagrafe identifica il proprietario, e alla risposta non serve. Vale in chat, nel riepilogo per il veterinario, nel testo estratto da documenti e foto, nella cache delle risposte e nelle ricerche nelle banche dati scientifiche. Resta fuori solo ciò che il filtro non può toccare: i pixel di una foto e la voce di un messaggio vocale (vedi sotto).

## Cosa NON copre (rischio residuo)

- Nomi di persona senza etichetta e non noti dall'account (es. il nome di un familiare o del veterinario scritto in mezzo a una frase): servirebbe un modello NER (Presidio).
- Indirizzi senza numero civico o scritti tutti in minuscolo; telefoni esteri o in formati insoliti.
- **Immagini e audio**: la foto di un referto inviata al modello di visione e l'audio inviato alla trascrizione partono così come sono; viene ripulito solo il testo che ne risulta. L'informativa lo dice agli utenti e consiglia di coprire i dati personali prima di inviare una foto (`it/02_informativa_privacy_it.md`, §6).
- Il nome del proprietario è rimosso solo se l'account ha un `display_name`.

È un livello di riduzione del rischio, non una garanzia assoluta.
