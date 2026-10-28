# Consenso per l'accesso alla cartella clinica da parte della chat

Riguarda la feature descritta in spec v3 §18/§36: prima che l'assistente consulti le informazioni cliniche già registrate per un pet (visite, esami, vaccinazioni), l'owner deve dare un consenso esplicito, per animale (non per singola conversazione), revocabile in qualsiasi momento. Implementazione: [packages/core/domain/medical_record/models.py](../../packages/core/domain/medical_record/models.py) (`MedicalRecordConsentRecord`, con `version` che fissa il testo esatto visto dall'utente al momento della decisione).

## Testo approvato

Fonte di verità per il testo esatto e la versione corrente: [packages/core/domain/medical_record/consent_text.py](../../packages/core/domain/medical_record/consent_text.py) (`CONSENT_TEXT_IT`, `CURRENT_VERSION`). Questo documento non duplica il testo per evitare che le due copie divergano. Esiste una sola copia letterale, nell'app: [medical_record_consent_card.dart](../../apps/mobile_app/lib/features/pets/presentation/widgets/medical_record_consent_card.dart) (`_approvedConsentText`). Il test `tests/unit/test_consent_texts_match_behaviour.py` verifica che coincida con quella del backend.

**Versione corrente: v3 (2026-10-14).** La v2 (2026-10-06) corresse la v1.

## Rettifica del 2026-10-06: la v1 prometteva più di quanto il sistema facesse

La v1 (approvata il 2026-09-17) diceva che l'assistente usa «solo le informazioni rilevanti per la domanda in corso, mai l'intera cartella». Quell'approvazione fu data sul testo, senza verificare che cosa riceve davvero la chat. Il codice non seleziona per rilevanza: l'errore è emerso nel giro di test del 2026-10-06 ed è stato verificato leggendo il codice.

### Cosa riceve la chat con il consenso attivo (verificato il 2026-10-06)

| Caso | Cosa viene letto | Limiti | Codice |
|---|---|---|---|
| Ogni risposta | Le tre voci più recenti: titolo, data, descrizione e testo letto dai documenti allegati. Non è una selezione per rilevanza | 3 voci; 1.200 caratteri di testo per documento | `MedicalRecordContextRetriever.summarize_for_pet`, `MAX_DOCUMENT_SUMMARY_CHARS` |
| «Spiegami questo esame» | I documenti che riguardano la richiesta (per tipo di esame o valore), altrimenti i più recenti, con il testo letto dal file | 2 documenti; 3.500 caratteri ciascuno | `documents_for_pet`, `select_for_request`, `MAX_EXPLAINED_DOCUMENTS`, `MAX_EXPLAINED_DOCUMENT_CHARS` |
| Domande di chiarimento (intervista) | Lo stesso riepilogo delle tre voci, tenuto nello stato della conversazione (`SituationModel.known_medical_context`) | come sopra | `chat_orchestrator.py` |
| Senza consenso, o dopo la revoca | Solo il numero dei documenti presenti: né titoli né contenuto | | `_medical_context_for_prompt` |

Destinatario: il fornitore esterno di IA che scrive la risposta (oggi Groq). Il riepilogo resta anche nello stato della conversazione salvato da VetApp.

### Che cosa dice la v2

Quanti documenti legge e quali dati (titolo, data, descrizione, testo dei documenti, solo l'inizio di quelli molto lunghi), che non sceglie solo ciò che serve alla domanda, che il testo va al fornitore esterno di IA, che VetApp lo usa solo per rispondere, e che la revoca vale per le richieste successive. Non dichiara anonimizzazione: non è garantita (vedi sotto e [02](02_pii_anonymization.md)). La v2 vale per i consensi dati da ora in poi: `SetMedicalRecordConsentService` registra la versione corrente a ogni decisione.

### Che cosa dice la v3 (2026-10-14, «Cartella clinica per categorie»)

Ogni voce ha una categoria (visita, esame, vaccino, terapia, documento) e la data dell'evento; la chat le riceve entrambe insieme al titolo. In più la chat legge le malattie pregresse ancora in corso (solo nome e data di inizio, al massimo cinque: `MAX_ONGOING_CONDITIONS`); terapia, note e allegati delle patologie, e le note delle voci, non partono. Le «Domande di chiarimento» ricevono lo stesso riepilogo esteso. Un consenso dato con la v2 non vale più (`effective_decision`: versione diversa = «non deciso»): l'interruttore della scheda risulta spento e la chat richiede la decisione sul testo nuovo prima di leggere qualcosa; nel frattempo vede solo il numero dei documenti.

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
