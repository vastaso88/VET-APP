# QUOKKA · Piano di refactor distribuibile a più LLM

QUOKKA · 22 novembre 2026 · [Repository e revisione di riferimento](https://github.com/vastaso88/VET-APP/tree/5d79fbda5634486c5b87fc5ea916f327082a3ac0). La baseline è il commit `5d79fbda` di main. Il checkout locale MULTILANG-legacy-snapshot contiene modifiche preesistenti. Usare il commit indicato o dichiarare le differenze del ramo assegnato.

**27 compiti, sei referenti tecnici e un verificatore indipendente.** Inviare a ogni modello il file del suo ruolo e gli ID da prendere in carico. Ogni scheda specifica problema, mandato, punti di ingresso e prova di accettazione. Questo rapporto comprende tutte le schede. Nel pacchetto è incluso anche l’audit da cui derivano.

## Distribuzione

| Fascicolo | Incarichi |
|---|---|
| [Mobile](01-Mobile.md) | QK-01, QK-02, QK-09, QK-10, QK-22, QK-24 |
| [Chat](02-Chat.md) | QK-03, QK-04, QK-11, QK-12, QK-19 |
| [API](03-API.md) | QK-05, QK-18, QK-20 |
| [Dati](04-Dati.md) | QK-06, QK-07, QK-08 |
| [Pulizia](05-Pulizia.md) | QK-13, QK-14, QK-15, QK-23, QK-26 |
| [Web](06-Web.md) | QK-16, QK-17, QK-21, QK-25 |
| [Verifica](07-Verifica.md) | QK-27 |

## Priorità e dipendenze

Partire da QK-01, QK-03, QK-05 e QK-06, che hanno perimetri indipendenti e benefici verificabili con contatori. Segue QK-04 per il riepilogo. QK-07 merita priorità quando le directory superano la prima finestra di risultati del provider. Le ondate organizzano un’eventuale integrazione. Le analisi in sola lettura possono iniziare in parallelo. Il verificatore prepara la baseline prima dell’ondata 1 e consegna il giudizio finale nell’ondata 7.

| Ondata | Compiti e referente |
|---|---|
| 1 | QK-01 (Mobile), QK-03 (Chat), QK-05 (API), QK-06 (Dati), QK-13 (Pulizia), QK-16 (Web) |
| 2 | QK-02 (Mobile), QK-04 (Chat), QK-07 (Dati), QK-14 (Pulizia), QK-17 (Web), QK-18 (API) |
| 3 | QK-08 (Dati), QK-09 (Mobile), QK-15 (Pulizia), QK-25 (Web) |
| 4 | QK-10 (Mobile), QK-11 (Chat), QK-20 (API), QK-21 (Web), QK-23 (Pulizia) |
| 5 | QK-12 (Chat), QK-22 (Mobile), QK-26 (Pulizia) |
| 6 | QK-19 (Chat), QK-24 (Mobile) |
| 7 | QK-27 (Verifica) |

**File condivisi.** Dati passa a Chat l’adapter Supabase dopo QK-08. Mobile consegna a Chat il contratto dei profili prima di QK-12. Pulizia consegna il container ad API dopo QK-14. Dati passa a Web le query admin prima di QK-21. Prima di intervenire su file condivisi, ricontrollare sul ramo di destinazione le PR [#60](https://github.com/vastaso88/VET-APP/pull/60) e [#65](https://github.com/vastaso88/VET-APP/pull/65). Per QK-18 basta consegnare al responsabile di prodotto l’analisi della decisione: l’eventuale attivazione delle notifiche è un incarico distinto.

**Baseline verificata.** Il riepilogo legge due volte conversazione e animale. POST /pets risolve due volte l’identità. Con 100 segnalazioni sintetiche sono state osservate 101 letture. Sono passati 61 test backend mirati e i controlli GitHub per Flutter, qualità Python e admin. Il guadagno di latenza su dispositivo e in produzione resta da misurare. [CI di riferimento](https://github.com/vastaso88/VET-APP/actions/runs/45004683986)

## Mandato da consegnare al modello

Prendi in carico gli ID assegnati, verifica i riscontri sulla revisione indicata e restituisci una proposta per ogni ID. **Il mandato attuale è di sola analisi.** I criteri di accettazione descrivono come verificare un eventuale refactor successivo. L’esecuzione delle modifiche richiede un mandato distinto. Usa strumenti a livello utente e fixture locali. Per questo lavoro non servono accessi amministrativi o dati di produzione.

Per ogni ID restituisci ramo e SHA, esito (confermato, superato, da correggere, in attesa di decisione), evidenza con file e simbolo, proposta, casi di test, risultato osservato e risultato atteso. Indica i confini dei file da modificare e ciò che serve al referente successivo. Se il lavoro è solo analitico, un test proposto va indicato come tale.

## Schede operative

### QK-01 · Eliminare il preload clinico scartato

**Referente** Mobile · **Ondata** 1 · **Prerequisiti** nessuno.

**Evidenza.** Lo splash attende loadRecords() e ne scarta il risultato. La schermata esegue una nuova lettura.

**Compito.** Rimuovere il lavoro dal preload e lasciare la prima lettura al controller. Conservare l’attesa minima prevista dallo splash.

**Criteri di accettazione.** Con un repository contatore, apertura Home senza cartella = 0 letture cliniche dal preload. Apertura cartella = dati visibili. Salvataggio e retry aggiornano ancora la lista.

**Sorgenti di partenza.** [app_preloader.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/app/splash/app_preloader.dart) · [medical_records_repository.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/medical_records/data/medical_records_repository.dart) · [medical_records_controller.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/medical_records/presentation/medical_records_controller.dart) · [splash_page_test.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/test/widget/splash_page_test.dart)

### QK-02 · Condividere i profili fra Home e chat

**Referente** Mobile · **Ondata** 2 · **Prerequisiti** QK-01.

**Evidenza.** PetDemoStore legge pet_profiles mentre ChatDemoStore chiama GET /pets per ottenere ID e nomi.

**Compito.** Esporre la mappa dei profili sincronizzati per proprietario. Condividere la richiesta in corso e distinguere una lista veramente vuota da un caricamento fallito.

**Criteri di accettazione.** Una sola lettura remota dei profili durante l’avvio normale. Provare due animali omonimi, offline, logout durante il caricamento e accesso con un secondo account.

**Sorgenti di partenza.** [app_preloader.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/app/splash/app_preloader.dart) · [chat_demo_store.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/chat/data/chat_demo_store.dart) · [chat_remote_data_source.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/chat/data/chat_remote_data_source.dart) · [pet_demo_store.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/pets/data/pet_demo_store.dart)

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

### QK-05 · Risolvere l’identità una volta per richiesta

**Referente** API · **Ondata** 1 · **Prerequisiti** nessuno.

**Evidenza.** POST /pets risolve due volte l’identità. Con Supabase ciascuna risoluzione chiama auth.get_user.

**Compito.** Inventariare handler e dipendenze che ripetono la validazione. Condividere la sola identità verificata entro la richiesta. Iniziare dalle route animali e Mercatino.

**Criteri di accettazione.** Sul percorso POST /pets riuscito, 1 validazione del token. Provare richieste concorrenti di due utenti, sessione revocata, età, consensi, abbonamento e percorsi di recupero. Elencare le route coperte.

**Sorgenti di partenza.** [subscription.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/dependencies/subscription.py) · [marketplace.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/dependencies/marketplace.py) · [pets.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/pets.py) · [age_guarded_auth_provider.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/auth/age_guarded_auth_provider.py) · [supabase_auth_provider.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/auth/supabase_auth_provider.py)

### QK-06 · Caricare in blocco la coda di moderazione

**Referente** Dati · **Ondata** 1 · **Prerequisiti** nessuno.

**Evidenza.** 100 segnalazioni producono 1 lettura di elenco e 100 lookup, anche quando gli ID si ripetono.

**Compito.** Implementare il recupero per ID distinti negli adapter utilizzati. Proiettare i campi richiesti dalla coda.

**Criteri di accettazione.** Con 100 righe al massimo 2 letture di dati. Con coda vuota 0 lookup conversazioni. Confrontare ordine, titolo, soggetto e conversazioni mancanti.

**Sorgenti di partenza.** [marketplace_messaging.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/marketplace_messaging.py) · [marketplace_messaging_repository.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/ports/marketplace_messaging_repository.py) · [supabase_marketplace_messaging.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/persistence/supabase/supabase_marketplace_messaging.py) · [test_marketplace_messages_api.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/integration/test_marketplace_messages_api.py)

### QK-07 · Paginare le directory admin alla fonte

**Referente** Dati · **Ondata** 2 · **Prerequisiti** QK-06.

**Evidenza.** Le pagine utenti enumerano gli account Auth e le località. La directory animali filtra dopo una singola lettura potenzialmente troncata.

**Compito.** Progettare una proiezione accessibile solo agli amministratori. Applicare ricerca, filtri, ordinamento stabile e pagina prima del trasferimento. Trattare esplicitamente il conteggio per paese.

**Criteri di accettazione.** Con dataset sintetico oltre una finestra del provider, trovare un record nell’ultima pagina. Totali e filtri esatti, nessuna riga duplicata fra pagine, accesso ordinario rifiutato. Consegnare prima/dopo di righe trasferite.

**Passaggio di consegne.** Confrontare le modifiche delle PR #60 e #65 prima di operare su admin_users.py.

**Sorgenti di partenza.** [admin_users.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/admin_users.py) · [admin_pets.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/admin_pets.py) · [user_reports.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/admin/user_reports.py) · [test_admin_users.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/integration/test_admin_users.py)

### QK-08 · Limitare geograficamente la ricerca annunci

**Referente** Dati · **Ondata** 3 · **Prerequisiti** QK-07.

**Evidenza.** Il backend scarica gli annunci attivi e applica distanza e categoria in memoria.

**Compito.** Spingere categoria e pre-filtro geografico nella query, mantenere la distanza esatta per i bordi e conservare esclusioni di visibilità.

**Criteri di accettazione.** Con candidati oltre il limite del provider, gli annunci nel raggio restano completi e ordinati. Provare confine nazionale, raggio limite e venditori nascosti. Registrare quanti candidati raggiungono Python.

**Sorgenti di partenza.** [list_nearby_listings.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/list_nearby_listings.py) · [supabase_repositories.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/persistence/supabase/supabase_repositories.py) · [test_list_nearby_listings.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_list_nearby_listings.py)

### QK-09 · Contare i media della galleria in blocco

**Referente** Mobile · **Ondata** 3 · **Prerequisiti** QK-02.

**Evidenza.** Ogni cartella costruita scarica e ordina i metadati di tutti i media per visualizzare due contatori.

**Compito.** Caricare i conteggi per animale e tipo con una richiesta per il gruppo. Verificare visibilità per proprietario e supporto alle vecchie righe.

**Criteri di accettazione.** Per 10 animali, 1 richiesta di conteggio e 0 richieste di liste complete per le didascalie. Verificare zero media, solo video, vecchie foto e apertura di una cartella.

**Sorgenti di partenza.** [gallery_folders_page.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/pets/presentation/pages/gallery_folders_page.dart) · [pet_photo_repository.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/pets/data/pet_photo_repository.dart)

### QK-10 · Sospendere il polling del Mercatino coperto

**Referente** Mobile · **Ondata** 4 · **Prerequisiti** QK-09.

**Evidenza.** Badge e pagina delle conversazioni avviano timer ogni 60 secondi. La pagina coperta resta montata.

**Compito.** Far dipendere il polling dalla visibilità della route e dallo stato dell’app. Allineare il badge al rientro e gestire il logout durante una lettura.

**Criteri di accettazione.** Con orologio simulato e navigazione elenco → dettaglio → indietro, 0 poll dal widget coperto e aggiornamento dopo il rientro. Verificare background e ripresa.

**Sorgenti di partenza.** [marketplace_messages_button.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/marketplace/presentation/widgets/marketplace_messages_button.dart) · [marketplace_conversations_page.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/marketplace/presentation/pages/marketplace_conversations_page.dart) · [marketplace_messages_test.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/test/marketplace/marketplace_messages_test.dart)

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

### QK-13 · Ritirare la scrittura dell’ultima scheda

**Referente** Pulizia · **Ondata** 1 · **Prerequisiti** nessuno.

**Evidenza.** Il cambio scheda salva un intero che al riavvio viene convertito in 0.

**Compito.** Rendere esplicito il controllo di accesso recente per proprietario. Rimuovere la scrittura a ogni cambio scheda.

**Criteri di accettazione.** 0 scritture dell’indice navigando. Vecchie preferenze leggibili, apertura Home corretta, scadenza accesso e ripristino di bozze e stack verificati.

**Sorgenti di partenza.** [warm_start_store.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/app/launch/warm_start_store.dart) · [home_shell_page.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/app/shell/home_shell_page.dart) · [splash_page.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/app/splash/splash_page.dart) · [warm_start_store_test.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/test/app/warm_start_store_test.dart)

### QK-14 · Verificare e ritirare otto factory scollegate

**Referente** Pulizia · **Ondata** 2 · **Prerequisiti** QK-13.

**Evidenza.** Senza chiamanti trovati le factory get_user_location_service, set_user_location_service, start_walk_service, record_route_point_service, end_walk_service, list_walks_service, create_local_activity_service e list_nearby_activities_service.

**Compito.** Per ciascuna registrare chiamanti, test, eventuale consumo esterno noto e decisione. Limitare il primo intervento alle factory confermate.

**Criteri di accettazione.** Matrice con 8 esiti motivati. Smoke test dell’inizializzazione, test passeggiate, posizione e attività locali. Verificare che export e cancellazione continuino ad accedere ai dati.

**Sorgenti di partenza.** [container.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/bootstrap/container.py) · [test_walk_lifecycle.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_walk_lifecycle.py) · [supabase_account_eraser.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/persistence/supabase/supabase_account_eraser.py)

### QK-15 · Ritirare cinque simboli Flutter privi di consumatori

**Referente** Pulizia · **Ondata** 3 · **Prerequisiti** QK-01, QK-14.

**Evidenza.** I candidati sono PetMetricChip, PetActionButton, RoundedSurface, LoadingAnimation e loadRecordById. Quest’ultimo usa il primo record come fallback per un ID assente.

**Compito.** Verificare singolarmente usi, export e test sul commit assegnato. Eliminare soltanto i simboli confermati.

**Criteri di accettazione.** Cinque decisioni per simbolo. Flutter analyze e test interessati passano. Splash e profili conservano i componenti ancora usati.

**Sorgenti di partenza.** [pet_sections.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/pets/presentation/widgets/pet_sections.dart) · [pets_scaffold.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/pets/presentation/widgets/pets_scaffold.dart) · [loading_animation.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/app/splash/loading_animation.dart) · [medical_records_repository.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/medical_records/data/medical_records_repository.dart)

### QK-16 · Ritirare le vecchie azioni admin di restrizione

**Referente** Web · **Ondata** 1 · **Prerequisiti** nessuno.

**Evidenza.** Le azioni restrictMarketplaceUser e liftMarketplaceRestriction sono sostituite dal flusso UserActions con anteprima e conferma.

**Compito.** Verificare azioni e due wrapper HTTP, poi ritirare quelli orfani dal portale. Tenere distinta la compatibilità degli endpoint HTTP.

**Criteri di accettazione.** Typecheck e build admin. Provare restrizione e revoca dalla scheda utente e dal caso di moderazione, con anteprima e conferma.

**Sorgenti di partenza.** [actions.ts](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/app/moderation/actions.ts) · [marketplace-restrict-form.tsx](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/components/marketplace-restrict-form.tsx) · [admin-api.ts](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/lib/admin-api.ts) · [user-actions.tsx](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/components/user-actions.tsx)

### QK-17 · Allineare il contratto billing del sito

**Referente** Web · **Ondata** 2 · **Prerequisiti** QK-16.

**Evidenza.** Il tipo web richiede prezzi e flag ereditati. La risposta corrente espone store_subscription e plan_source. Restano stili della precedente UI.

**Compito.** Derivare o restringere il tipo ai campi effettivamente letti. Cercare anche le classi composte dinamicamente prima di rimuovere CSS.

**Criteri di accettazione.** Provare account trial, piano attivo, scaduto e stato indisponibile con risposte rappresentative dell’API. Eseguire typecheck e build di apps/website.

**Sorgenti di partenza.** [api.ts](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/website/lib/api.ts) · [page.tsx](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/website/app/account/page.tsx) · [globals.css](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/website/app/globals.css) · [get_or_create_subscription.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/get_or_create_subscription.py)

### QK-18 · Determinare il destino delle notifiche di cancellazione

**Referente** API · **Ondata** 2 · **Prerequisiti** QK-05.

**Evidenza.** due_waiting_notice ha test ma non emerge un chiamante di produzione nel repository.

**Compito.** Solo analisi. Incrociare calendario, requisiti e scheduler. Esplicitare cosa manca per usarlo e chi decide se collegarlo o ritirarlo.

**Criteri di accettazione.** Consegnare una nota con riferimenti e decisione richiesta al responsabile di prodotto. Stato finale ammesso: in attesa di decisione. Nessun invio email.

**Sorgenti di partenza.** [notices.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/domain/account_deletion/notices.py) · [test_deletion_notices.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_deletion_notices.py) · [lifecycle.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/lifecycle.py)

### QK-19 · Estrarre la preparazione della risposta naturale

**Referente** Chat · **Ondata** 6 · **Prerequisiti** QK-12.

**Evidenza.** L’orchestratore ha 4.728 righe. _generate_natural_answer ne occupa 576.

**Compito.** Registrare il comportamento attuale con provider finti. Estrarre prima la preparazione della risposta. Valutare il recupero fonti in un secondo diff isolato.

**Criteri di accettazione.** Confrontare output deterministici, ordine e numero delle chiamate per urgenza, consensi, risposta breve, cache, errori e fallback. Nessuna inferenza esterna nei test.

**Sorgenti di partenza.** [chat_orchestrator.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/chat_orchestrator.py) · [natural_answer_prompt.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/application/services/natural_answer_prompt.py) · [test_chat_orchestrator.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_chat_orchestrator.py)

### QK-20 · Dividere la composizione dei servizi

**Referente** API · **Ondata** 4 · **Prerequisiti** QK-14, QK-18.

**Evidenza.** Il container concentra in 1.810 righe wiring di billing, chat, persistenza e modalità di test.

**Compito.** Dopo la pulizia delle factory, estrarre un gruppo per volta partendo dal meno accoppiato. Preservare get_container(), override, inizializzazione lazy e durata di cache e client.

**Criteri di accettazione.** Confrontare configurazioni in-memory e Supabase tramite fake. Testare reset del container, riuso delle istanze previste e contratti delle factory pubbliche.

**Passaggio di consegne.** Coordinare con le modifiche di pricing nella PR #65.

**Sorgenti di partenza.** [container.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/bootstrap/container.py)

### QK-21 · Separare router e client admin per funzione

**Referente** Web · **Ondata** 4 · **Prerequisiti** QK-07, QK-16, QK-17, QK-25.

**Evidenza.** Il router principale ha 1.620 righe e il client admin 1.191. Router specializzati importano helper privati dal principale.

**Compito.** Estrarre prima dipendenze comuni e poi separare cruscotto, moderazione e ingestion in passaggi verificabili. Migrare il client mantenendo gli import pubblici utilizzati.

**Criteri di accettazione.** Confrontare metodi e path OpenAPI prima/dopo. Provare autorizzazioni, paginazione, scheduler e durata cache cruscotto. Typecheck e build admin.

**Passaggio di consegne.** Ricontrollare PR #60 e #65. Coordinare con Dati prima di spostare helper condivisi.

**Sorgenti di partenza.** [admin.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/admin.py) · [admin_users.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/admin_users.py) · [admin-api.ts](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/lib/admin-api.ts)

### QK-22 · Suddividere le pagine dei promemoria

**Referente** Mobile · **Ondata** 5 · **Prerequisiti** QK-10.

**Evidenza.** Lista, calendario, form e dettaglio occupano lo stesso file di 2.416 righe.

**Compito.** Separare lista/calendario, form condiviso da creazione e modifica, e dettaglio. Preservare gli import pubblici usati dalle route.

**Criteri di accettazione.** Creazione, modifica, completamento, cancellazione, ricorrenze e cambio ora verificati. Stessi refresh per azione e nessun raddoppio del form.

**Sorgenti di partenza.** [reminders_pages.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/reminders/presentation/pages/reminders_pages.dart) · [reminders_dst_test.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/test/reminders/reminders_dst_test.dart)

### QK-23 · Unificare il mapping degli intenti scientifici

**Referente** Pulizia · **Ondata** 4 · **Prerequisiti** QK-15.

**Evidenza.** I quattro adapter implementano lo stesso _domain_from_intent.

**Compito.** Spostare la sola funzione comune in un punto condiviso del sottosistema retrieval.

**Criteri di accettazione.** Test parametrico dei quattro intenti noti e del fallback general su tutti gli adapter. Parser, URL e formati specifici dei provider conservano il comportamento.

**Sorgenti di partenza.** [crossref_evidence_retriever.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/llm/retrieval/crossref_evidence_retriever.py) · [europe_pmc_evidence_retriever.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/llm/retrieval/europe_pmc_evidence_retriever.py) · [openalex_evidence_retriever.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/llm/retrieval/openalex_evidence_retriever.py) · [pubmed_evidence_retriever.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/llm/retrieval/pubmed_evidence_retriever.py)

### QK-24 · Condividere il selettore di coordinate

**Referente** Mobile · **Ondata** 6 · **Prerequisiti** QK-22.

**Evidenza.** Le schermate condividono 35 righe per mappa, attribuzione e segnaposto.

**Compito.** Estrarre un widget con posizione iniziale e callback sul centro. Lasciare salvataggio, validazione e invio nelle schermate proprietarie.

**Criteri di accettazione.** Verificare centro iniziale, movimento, coordinate confermate, annullamento e attribuzione visibile in entrambi i flussi.

**Sorgenti di partenza.** [report_missing_place_page.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/nearby_places/presentation/pages/report_missing_place_page.dart) · [location_picker_page.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/settings/presentation/pages/location_picker_page.dart)

### QK-25 · Condividere i valori specie e intento

**Referente** Web · **Ondata** 3 · **Prerequisiti** QK-17.

**Evidenza.** I form di scheduling e discovery ripetono i valori di specie e intenti.

**Compito.** Estrarre dati comuni e mantenere nei due form i rispettivi default, etichette e gestori.

**Criteri di accettazione.** Confrontare valori e payload di ogni opzione in entrambi i form, eseguire typecheck admin.

**Sorgenti di partenza.** [page.tsx](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/app/jobs/page.tsx) · [scientific-discovery-panel.tsx](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/components/scientific-discovery-panel.tsx)

### QK-26 · Evitare la divergenza della migrazione billing

**Referente** Pulizia · **Ondata** 5 · **Prerequisiti** QK-23.

**Evidenza.** I due percorsi contengono lo stesso blob Git. La copia è documentata.

**Compito.** Indicare la migrazione come fonte e verificare automaticamente la copia richiesta dal setup.

**Criteri di accettazione.** Controllo locale che passa con i file identici e fallisce su una copia di prova alterata. Nessuna modifica a migrazioni già applicate e nessun accesso a database remoto.

**Sorgenti di partenza.** [store_billing.sql](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/scripts/setup/store_billing.sql) · [20261121180000_store_billing.sql](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/supabase/migrations/20261121180000_store_billing.sql) · [01_architettura_abbonamenti.md](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/docs/billing/01_architettura_abbonamenti.md)

### QK-27 · Validare l’integrazione e misurare il risultato

**Referente** Verifica · **Ondata** 7 · **Prerequisiti** QK-19, QK-20, QK-21, QK-24, QK-25, QK-26.

**Evidenza.** La baseline ha 61 test mirati superati e conteggi applicativi. Latenza reale e byte richiedono una misura separata.

**Compito.** Predisporre la baseline prima della prima ondata. Ripetere sugli stessi casi dopo ogni gruppo integrato e compilare un registro degli ID con prove e regressioni.

**Criteri di accettazione.** Per ogni ID registrare accettato, da correggere, superato o in attesa, con SHA e motivazione. Confrontare query e payload; per latenza annotare dispositivo, numero di campioni, p50/p95 e avvio caldo/freddo. Dichiarare le misure indisponibili.

**Passaggio di consegne.** Il referente può preparare i casi subito. Il giudizio integrato segue tutti i lotti.

**Sorgenti di partenza.** [test_send_chat_message_retry.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_send_chat_message_retry.py) · [test_conversation_titles_and_summary.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_conversation_titles_and_summary.py) · [test_admin_users.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/integration/test_admin_users.py) · [test_marketplace_messages_api.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/integration/test_marketplace_messages_api.py) · [ci.yml](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/.github/workflows/ci.yml)
