# Consenso per l'accesso alla cartella clinica da parte della chat

Riguarda la feature descritta in spec v3 §18/§36: prima che l'assistente consulti le informazioni cliniche già registrate per un pet (visite, esami, vaccinazioni), l'owner deve dare un consenso esplicito, per animale (non per singola conversazione), revocabile in qualsiasi momento. Implementazione: [packages/core/domain/medical_record/models.py](../../packages/core/domain/medical_record/models.py) (`MedicalRecordConsentRecord`, con `version` che fissa il testo esatto visto dall'utente al momento della decisione).

## Testo approvato

Fonte di verità per il testo esatto e la versione corrente: [packages/core/domain/medical_record/consent_text.py](../../packages/core/domain/medical_record/consent_text.py) (`CONSENT_TEXT_IT`, `CURRENT_VERSION`) — questo documento non duplica il testo per evitare che le due copie divergano; descrive solo perché è stato approvato così.

Il testo proposto in `v1-draft` è stato rivisto (2026-09-17) e approvato senza modifiche sostanziali: comunica chiaramente lo scopo ("darti un consiglio più preciso"), lo scope minimo del trattamento ("solo le informazioni rilevanti per la domanda in corso, mai l'intera cartella" — data minimization esplicita), e la revocabilità. È coerente con l'obbligo di consenso informato (GDPR art. 7) per il trattamento dei dati collegati al pet e con la trasparenza IA già stabilita in [01_ai_disclosure.md](01_ai_disclosure.md). Chi possiede il codice può rimuovere il suffisso `-draft` dalla versione.

## Punto aperto per chi implementa l'uso effettivo del contesto clinico nel prompt

Ad oggi (verificato leggendo `chat_orchestrator.py` il 2026-09-17) il riepilogo clinico recuperato (`known_medical_context`) influenza solo il punteggio di copertura e le domande dell'intervista — **non** viene ancora inserito nel testo inviato al modello LLM per generare la risposta finale. Quando verrà effettivamente iniettato nel prompt (`LLMGenerationRequest.user_prompt`), dovrà passare per lo stesso confine di anonimizzazione già applicato a `message`/`pet_name` (vedi [02_pii_anonymization.md](02_pii_anonymization.md)) — le note cliniche possono contenere dettagli identificativi (nomi, riferimenti a persone) più facilmente di un messaggio breve. Segnalato alla sessione che possiede `ChatOrchestrator`; da verificare insieme quando quel pezzo viene costruito.
