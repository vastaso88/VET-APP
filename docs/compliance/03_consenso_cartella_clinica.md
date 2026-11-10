# Consenso per l'accesso alla cartella clinica da parte della chat

> **Parere della sessione normativa (2026-11-08).** Il testo v4 (note della scheda e promemoria) è giusto nella sostanza. Il bump era necessario, perché il v3 non diceva che anche note e promemoria partono per il fornitore, e contare i consensi v3 come «non deciso» è corretto: il consenso vale per ciò che la persona ha letto (artt. 4(11) e 7 GDPR). Restano due imprecisioni, da correggere in una v5. Il bump lo decide il proprietario: fa rifare il consenso a tutti gli iscritti, e costa meno prima del pubblico che dopo.
>
> 1. **Finalità.** «Quokka lo usa solo per risponderti» non nomina il riepilogo per il veterinario (`vet_summary.py`), che manda al fornitore le stesse note con lo stesso consenso. Rischio basso, perché il riepilogo nasce da una richiesta della persona, ma il testo dice «solo». Scrivere «Quokka lo usa solo per risponderti e per preparare il riepilogo per il veterinario che puoi chiedere».
> 2. **Destinatario.** «Il fornitore esterno» è singolare e non dice dove. Dal 2026-11-07 i fornitori sono due, Anthropic come principale e Groq di riserva, entrambi con elaborazione negli Stati Uniti; per Anthropic la regione non è fissabile all'UE (`docs/security/06_inventario_dati_fornitori.md`). Il trasferimento si regge su uno strumento degli artt. 45–46 GDPR (per Anthropic le SCC nel DPA, da verificare la certificazione DPF), non sul consenso, e va scritto nell'informativa; nel consenso basta dire dove vanno i dati. Nella scheda: «Ciò che legge viene inviato al fornitore esterno di intelligenza artificiale che scrive la risposta» → «Ciò che legge viene inviato ai fornitori esterni di intelligenza artificiale che scrivono la risposta, con server negli Stati Uniti». Nella domanda in chat (`INLINE_QUESTION_IT`): «e le invierò al servizio di intelligenza artificiale che scrive la risposta» → «e le invierò ai servizi di intelligenza artificiale che scrivono la risposta, con server negli Stati Uniti».
>
> **Da non cambiare.** «Legge anche le note…» è il verbo giusto: con il consenso acceso note e promemoria partono sempre (`send_chat_message.py`, blocco «R25, option A»). Se si uniformano i verbi del testo, si uniformano verso l'indicativo, non verso «può leggere».
>
> **Quando.** Prima di attivare Anthropic in produzione, che secondo l'inventario è ancora da attivare (chiave, DPA, verifica DPF), e comunque prima del test con il pubblico. Fino ad allora il v4 resta in uso. Ogni modifica al testo passa da questa sessione e tocca le cinque lingue (`petsConsentFullText` nelle ARB, `consent_request` in `localization.py`), la domanda in chat e il test `test_consent_texts_match_behaviour.py`. **Testo v5 pronto il 2026-11-10:** vedi «Che cosa dirà la v5» più sotto.

Riguarda la feature descritta in spec v3 §18/§36: prima che l'assistente consulti le informazioni cliniche già registrate per un pet (visite, esami, vaccinazioni), l'owner deve dare un consenso esplicito, per animale (non per singola conversazione), revocabile in qualsiasi momento. Implementazione: [packages/core/domain/medical_record/models.py](../../packages/core/domain/medical_record/models.py) (`MedicalRecordConsentRecord`, con `version` che fissa il testo esatto visto dall'utente al momento della decisione).

## Testo approvato

Fonte di verità per il testo esatto e la versione corrente: [packages/core/domain/medical_record/consent_text.py](../../packages/core/domain/medical_record/consent_text.py) (`CONSENT_TEXT_IT`, `CURRENT_VERSION`). Questo documento non duplica il testo per evitare che le due copie divergano. Esiste una sola copia letterale, nell'app: [medical_record_consent_card.dart](../../apps/mobile_app/lib/features/pets/presentation/widgets/medical_record_consent_card.dart) (`_approvedConsentText`). Il test `tests/unit/test_consent_texts_match_behaviour.py` verifica che coincida con quella del backend.

**Versione corrente: v4 (2026-11-07).** La v3 (2026-10-14) aggiunse categorie e malattie in corso; la v2 (2026-10-06) corresse la v1.

## Rettifica del 2026-10-06: la v1 prometteva più di quanto il sistema facesse

La v1 (approvata il 2026-09-17) diceva che l'assistente usa «solo le informazioni rilevanti per la domanda in corso, mai l'intera cartella». Quell'approvazione fu data sul testo, senza verificare che cosa riceve davvero la chat. Il codice non seleziona per rilevanza: l'errore è emerso nel giro di test del 2026-10-06 ed è stato verificato leggendo il codice.

### Cosa riceve la chat con il consenso attivo (verificato il 2026-10-06)

| Caso | Cosa viene letto | Limiti | Codice |
|---|---|---|---|
| Ogni risposta | Le tre voci più recenti: titolo, data, descrizione e testo letto dai documenti allegati. Non è una selezione per rilevanza | 3 voci; 1.200 caratteri di testo per documento | `MedicalRecordContextRetriever.summarize_for_pet`, `MAX_DOCUMENT_SUMMARY_CHARS` |
| «Spiegami questo esame» | I documenti che riguardano la richiesta (per tipo di esame o valore), altrimenti i più recenti, con il testo letto dal file | 2 documenti; 3.500 caratteri ciascuno | `documents_for_pet`, `select_for_request`, `MAX_EXPLAINED_DOCUMENTS`, `MAX_EXPLAINED_DOCUMENT_CHARS` |
| Domande di chiarimento (intervista) | Lo stesso riepilogo delle tre voci, tenuto nello stato della conversazione (`SituationModel.known_medical_context`) | come sopra | `chat_orchestrator.py` |
| Senza consenso, o dopo la revoca | Solo il numero dei documenti presenti: né titoli né contenuto | | `_medical_context_for_prompt` |

Destinatario: il fornitore esterno di IA che scrive la risposta (oggi Groq). Il riepilogo resta anche nello stato della conversazione salvato da Quokka.

### Che cosa dice la v2

Quanti documenti legge e quali dati (titolo, data, descrizione, testo dei documenti, solo l'inizio di quelli molto lunghi), che non sceglie solo ciò che serve alla domanda, che il testo va al fornitore esterno di IA, che Quokka lo usa solo per rispondere, e che la revoca vale per le richieste successive. Non dichiara anonimizzazione: non è garantita (vedi sotto e [02](02_pii_anonymization.md)). La v2 vale per i consensi dati da ora in poi: `SetMedicalRecordConsentService` registra la versione corrente a ogni decisione.

### Che cosa dice la v3 (2026-10-14, «Cartella clinica per categorie»)

Ogni voce ha una categoria (visita, esame, vaccino, terapia, documento) e la data dell'evento; la chat le riceve entrambe insieme al titolo. In più la chat legge le malattie pregresse ancora in corso (solo nome e data di inizio, al massimo cinque: `MAX_ONGOING_CONDITIONS`); terapia, note e allegati delle patologie, e le note delle voci, non partono. Le «Domande di chiarimento» ricevono lo stesso riepilogo esteso. Un consenso dato con la v2 non vale più (`effective_decision`: versione diversa = «non deciso»): l'interruttore della scheda risulta spento e la chat richiede la decisione sul testo nuovo prima di leggere qualcosa; nel frattempo vede solo il numero dei documenti.

### Che cosa dice la v4 (2026-11-07, registro rischi R25, opzione A)

Le note libere della scheda dell'animale («Diagnosi MBD lieve 2024») e i promemoria attivi, terapie comprese, sono informazioni sanitarie: dal 2026-11-07 partono verso il fornitore solo con questo consenso concesso sul testo corrente (`send_chat_message.py`: `notes` e `reminders_context` solo se `medical_record_consent is True`; `vet_summary.py`: le note del profilo nel riepilogo per il veterinario con la stessa regola). Prima partivano sempre, e il testo non lo diceva. La v4 aggiunge la frase «Legge anche le note che hai scritto nella scheda dell'animale e i promemoria attivi, terapie comprese», nelle cinque lingue (`petsConsentFullText` negli ARB) e nella domanda in chat (`consent_request`). Un consenso dato con la v3 non vale più (`effective_decision`): senza una nuova scelta non parte nulla di sanitario, né cartella né note né promemoria; restano disponibili nome, specie, razza, sesso, età e peso. Il suggerimento del campo note («dieta, farmaci o comportamento») resta invariato. Test: `test_notes_follow_record_consent.py`, `test_v4_names_the_profile_notes_and_the_reminders_in_every_language`.

### Che cosa dirà la v5 (testo pronto per il codice, 2026-11-10)

La v5 corregge le due imprecisioni del parere dell'8 novembre (finalità e destinatari) e dice in modo semplice che i dati vanno negli Stati Uniti. **Va in produzione insieme all'attivazione di Anthropic** (chiave creata, contratto firmato e archiviato), non prima: il testo nomina Anthropic, e finché risponde solo Groq sarebbe inesatto. Un consenso dato con la v4 non conta più (`effective_decision`): tutti decidono di nuovo, una volta sola.

**Scheda dell'animale (`CONSENT_TEXT_IT`, `petsConsentFullText`):**

> Per darti un consiglio più preciso, l'assistente può leggere la cartella clinica del tuo animale. Quando fai una domanda può leggere le tre voci più recenti, con titolo, categoria (visita, esame, vaccino, terapia o documento), data dell'evento, descrizione e testo dei documenti allegati, anche se non c'entrano con la domanda. Può leggere anche le malattie pregresse ancora in corso, con il nome e la data di inizio, al massimo cinque. Legge anche le note che hai scritto nella scheda dell'animale e i promemoria attivi, terapie comprese. Se chiedi di spiegare un esame, può leggere i documenti che lo riguardano, al massimo due. Di un documento molto lungo legge solo l'inizio. Ciò che legge viene inviato ai fornitori esterni di intelligenza artificiale che scrivono la risposta: Anthropic e, quando Anthropic non può rispondere, Groq. Sono società statunitensi e trattano i dati negli Stati Uniti, fuori dall'Unione europea: l'invio è vincolato da un contratto e protetto dalle garanzie che la legge europea prevede per questi trasferimenti. Prima dell'invio togliamo nomi, recapiti e altri dati che ti identificano, ma non possiamo riconoscerli tutti. Quokka lo usa solo per risponderti e per preparare il riepilogo per il veterinario che puoi chiedere. Puoi revocare il consenso in qualsiasi momento dalla scheda dell'animale o dalle Impostazioni: vale per le richieste successive.

**Domanda in chat (`INLINE_QUESTION_IT`, `consent_request`):**

> Vuoi che consulti la cartella clinica di {pet_name} per darti un consiglio più preciso? Leggerò le tre voci più recenti, compreso il testo dei documenti allegati, le malattie pregresse ancora in corso, le note della scheda e i promemoria attivi, terapie comprese, e le invierò ai servizi di intelligenza artificiale che scrivono la risposta: Anthropic e, di riserva, Groq, con server negli Stati Uniti. Puoi cambiare idea in qualsiasi momento dalla scheda di {pet_name}.

**Cosa cambia rispetto alla v4:** (a) i destinatari sono nominati e al plurale: Anthropic, e Groq quando Anthropic non può rispondere; (b) si dice che sono società statunitensi, che i dati escono dall'Unione europea e che l'invio è protetto da un contratto e dalle garanzie di legge; (c) si dice che prima dell'invio si tolgono nomi, recapiti e altri dati identificativi e che non si riconoscono tutti; (d) la finalità comprende il riepilogo per il veterinario. «Legge anche le note…» resta com'è: con il consenso acceso note e promemoria partono sempre.

**Perché il testo sia vero** (da verificare al momento dell'attivazione):

1. «trattano i dati negli Stati Uniti» vale se la regione è fissata con `inference_geo="us"` (parametro della richiesta; raccomandato, così c'è un solo paese da dichiarare). Se si lascia `global`, sostituire con «possono trattare i dati negli Stati Uniti e in altri paesi fuori dall'Unione europea».
2. «vincolato da un contratto e protetto dalle garanzie»: contratto sul trattamento dei dati accettato e archiviato (Anthropic: clausole contrattuali standard; Data Privacy Framework solo se la certificazione è verificata). Per Groq vale lo stesso, da verificare.
3. «togliamo nomi, recapiti…»: è il filtro `_anonymize_for_provider` (numeri di microchip compresi dall'8 novembre). Foto e voce non passano da Anthropic (restano su Groq) e il filtro non lavora su pixel e audio (it/02 §6).
4. «Groq quando Anthropic non può rispondere»: è la riserva automatica (modello non disponibile o budget esaurito).

**Per il codice (sessione Chat):** `CURRENT_VERSION = "v5"` in `consent_text.py` e `_currentConsentVersion = 'v5'` in `pet_demo_store.dart` (un test li tiene uguali); i due testi sopra in `CONSENT_TEXT_IT` e `INLINE_QUESTION_IT`, nelle ARB (`petsConsentFullText`) e in `localization.py` (`consent_request`) nelle cinque lingue, con traduzioni riviste dall'Orchestratore; docstring della v5. In `test_consent_texts_match_behaviour.py`: `v5` come versione corrente, le decisioni `v1`–`v4` non contano, e un nuovo controllo che scheda e domanda dicano «Anthropic» e «Stati Uniti» (la scheda anche «riepilogo per il veterinario»). Restano valide le frasi già verificate: «tre voci», «al massimo due», «al massimo cinque», «malattie pregresse ancora in corso», «note che hai scritto nella scheda», «promemoria attivi, terapie comprese», «intelligenza artificiale». L'istantanea dei testi italiani si aggiorna di proposito.

## Punti aperti

Nessuno bloccante (verificato nel codice il 2026-10-28). Chiusi dal lavoro della sessione Chat LLM interna dopo la rettifica del 2026-10-06:

1. **La domanda in chat** usa lo stesso testo del consenso (`INLINE_QUESTION_IT`, chiave `consent_request` in `localization.py`); il test `test_the_italian_chat_question_is_the_text_on_record` lo verifica.
2. **I consensi dati con una versione precedente non valgono più.** `effective_decision` (usata in `send_chat_message.py` e in `GET /pets/{pet_id}/medical-record-consent`) li tratta come «non deciso» e la chat richiede la decisione sul testo nuovo. Il test `test_the_app_reads_decisions_under_the_same_consent_version_as_the_backend` impedisce che app e backend leggano versioni diverse.
3. **Il riepilogo nello stato della conversazione** viene anonimizzato quando entra nello stato (`_anonymize_for_provider(record_summary, data)` nei due punti di `chat_orchestrator.py`). Il testo del consenso resta senza dichiarazione di anonimizzazione, perché il filtro a regole non riconosce tutto (vedi [02](02_pii_anonymization.md)).

## Alternativa: limitare i dati invece di descriverli

La scelta finale spetta al proprietario. La v2 e la v3 applicano la versione onesta: descrivono una lettura ampia. L'alternativa è ridurre ciò che si invia, in linea con la minimizzazione (art. 5(1)(c) GDPR):

- **Solo titoli, date e descrizioni** nel riepilogo di ogni risposta; il testo dei documenti solo quando l'utente chiede di spiegare un esame.
- **Scegliere per rilevanza** anche nel caso normale, come già avviene per «spiega l'esame».
- **Meno voci o meno caratteri** per documento.

Costi: la qualità delle risposte (un ciclo di antibiotico in corso o un valore di laboratorio cambiano la risposta) e il lavoro della sessione Chat LLM interna. Se si riduce la lettura, il testo va riscritto di conseguenza (v4) e potrà tornare a dire che si legge solo una parte. Ma solo quando la selezione esiste davvero, e il test `test_consent_texts_match_behaviour.py` va aggiornato insieme.

## Anonimizzazione

Dal 2026-09 il riepilogo clinico entra nel prompt della risposta, passando dal filtro (`_anonymize_for_provider`): il filtro predefinito è `RuleBasedPiiAnonymizer`. Il confine e i limiti sono descritti in [02_pii_anonymization.md](02_pii_anonymization.md). Il riepilogo passa dal filtro anche quando entra nello stato della conversazione (verificato il 2026-10-28). Il testo del consenso non dichiara anonimizzazione, perché il filtro a regole non riconosce tutto.
