# QUOKKA · Referente Chat

QUOKKA · 22 novembre 2026 · [Repository e revisione di riferimento](https://github.com/vastaso88/VET-APP/tree/5d79fbda5634486c5b87fc5ea916f327082a3ac0). La baseline è il commit `5d79fbda` di main. Il checkout locale MULTILANG-legacy-snapshot contiene modifiche preesistenti. Usare il commit indicato o dichiarare le differenze del ramo assegnato.

## Mandato da consegnare al modello

Prendi in carico gli ID assegnati, verifica i riscontri sulla revisione indicata e restituisci una proposta per ogni ID. **Il mandato attuale è di sola analisi.** I criteri di accettazione descrivono come verificare un eventuale refactor successivo. L’esecuzione delle modifiche richiede un mandato distinto. Usa strumenti a livello utente e fixture locali. Per questo lavoro non servono accessi amministrativi o dati di produzione.

Per ogni ID restituisci ramo e SHA, esito (confermato, superato, da correggere, in attesa di decisione), evidenza con file e simbolo, proposta, casi di test, risultato osservato e risultato atteso. Indica i confini dei file da modificare e ciò che serve al referente successivo. Se il lavoro è solo analitico, un test proposto va indicato come tale.

## Coordinamento

Il coordinatore fornisce gli esiti esterni di QK-02 (Mobile, Condividere i profili fra Home e chat), QK-08 (Dati, Limitare geograficamente la ricerca annunci). Trasmettere i risultati ai referenti di QK-27 (Verifica).

## Incarichi

### QK-03 · Riutilizzare la lettura fra replay e invio

**Referente** Chat · **Ondata** 1 · **Prerequisiti** nessuno.

**Evidenza.** Misurati due list_by_pet per una nuova chat con client_message_id e due get per un nuovo messaggio in una chat esistente.

**Compito.** Caricare i candidati una volta e passarli al controllo replay e al caricamento. Distinguere replay già salvato e duplicati simultanei.

**Criteri di accettazione.** Nei due casi misurati ridurre da 2 a 1 la lettura interessata. Il retry di un risultato salvato restituisce lo stesso ID e genera 0 chiamate aggiuntive al modello. Documentare e testare il comportamento concorrente.

**Sorgenti di partenza.** [send_chat_message.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/send_chat_message.py) · [conversation_repository.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/ports/conversation_repository.py) · [test_send_chat_message_retry.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_send_chat_message_retry.py)

### QK-04 · Caricare una volta i dati del riepilogo

**Referente** Chat · **Ondata** 2 · **Prerequisiti** QK-03.

**Evidenza.** Su un riepilogo riuscito sono state contate due letture della conversazione e due del profilo animale.

**Compito.** Spostare nel servizio caricamento, controllo proprietario e dati necessari per anonimizzare il prompt. Preservare lingua, quote e consenso.

**Criteri di accettazione.** Sul percorso valido 1 lettura conversazione e 1 animale. Verificare conversazione estranea, assente e vuota, testo anonimizzato e documenti ammessi.

**Sorgenti di partenza.** [conversations.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/conversations.py) · [vet_summary.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/vet_summary.py) · [test_conversation_titles_and_summary.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_conversation_titles_and_summary.py)

### QK-11 · Limitare il recupero delle chat recenti V2

**Referente** Chat · **Ondata** 4 · **Prerequisiti** QK-03, QK-08.

**Evidenza.** Con CHAT_ANSWER_V2 attivo, il backend carica le conversazioni dell’animale prima di sceglierne al massimo due nelle ultime 72 ore.

**Compito.** Introdurre una lettura limitata per proprietario e animale che escluda la conversazione corrente. Verificare la data effettiva nei record storici e i filtri sui messaggi privi di consenso.

**Criteri di accettazione.** Con flag spento 0 letture di quel contesto. Con flag acceso equivalenza su conversazioni recenti, scadute, vuote e legacy. Misurare numero di righe e byte acquisiti.

**Sorgenti di partenza.** [send_chat_message.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/send_chat_message.py) · [conversation_repository.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/ports/conversation_repository.py) · [supabase_repositories.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/persistence/supabase/supabase_repositories.py)

### QK-12 · Separare elenco e dettaglio della cronologia

**Referente** Chat · **Ondata** 5 · **Prerequisiti** QK-02, QK-04, QK-11.

**Evidenza.** Flutter scarica tutti i messaggi della cronologia nel precaricamento. Gli attuali client consumano il formato completo.

**Compito.** Aggiungere un elenco leggero paginato e il caricamento dei messaggi all’apertura. Definire ordinamento e cursore stabili, risposta legacy e comportamento dopo rinomina o cancellazione.

**Criteri di accettazione.** La Home non scarica i corpi dei messaggi nel nuovo percorso. Verificare due pagine, un titolo legacy, accesso per proprietario e un vecchio client. Registrare byte e numero di richieste prima/dopo.

**Passaggio di consegne.** Il referente Chat possiede anche gli adattamenti Flutter della cronologia. Mobile verifica logout e cambio account.

**Sorgenti di partenza.** [conversations.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/conversations.py) · [list_conversations.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/list_conversations.py) · [supabase_repositories.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/persistence/supabase/supabase_repositories.py) · [chat_demo_store.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/chat/data/chat_demo_store.dart) · [chat_remote_data_source.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/chat/data/chat_remote_data_source.dart)

### QK-19 · Estrarre la preparazione della risposta naturale

**Referente** Chat · **Ondata** 6 · **Prerequisiti** QK-12.

**Evidenza.** L’orchestratore ha 4.728 righe. _generate_natural_answer ne occupa 576.

**Compito.** Registrare il comportamento attuale con provider finti. Estrarre prima la preparazione della risposta. Valutare il recupero fonti in un secondo diff isolato.

**Criteri di accettazione.** Confrontare output deterministici, ordine e numero delle chiamate per urgenza, consensi, risposta breve, cache, errori e fallback. Nessuna inferenza esterna nei test.

**Sorgenti di partenza.** [chat_orchestrator.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/chat_orchestrator.py) · [natural_answer_prompt.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/natural_answer_prompt.py) · [test_chat_orchestrator.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_chat_orchestrator.py)
