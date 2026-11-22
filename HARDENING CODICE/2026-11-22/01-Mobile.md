# QUOKKA · Referente Mobile

QUOKKA · 22 novembre 2026 · [Repository e revisione di riferimento](https://github.com/vastaso88/VET-APP/tree/5d79fbda5634486c5b87fc5ea916f327082a3ac0). La baseline è il commit `5d79fbda` di main. Il checkout locale MULTILANG-legacy-snapshot contiene modifiche preesistenti. Usare il commit indicato o dichiarare le differenze del ramo assegnato.

## Mandato da consegnare al modello

Prendi in carico gli ID assegnati, verifica i riscontri sulla revisione indicata e restituisci una proposta per ogni ID. **Il mandato attuale è di sola analisi.** I criteri di accettazione descrivono come verificare un eventuale refactor successivo. L’esecuzione delle modifiche richiede un mandato distinto. Usa strumenti a livello utente e fixture locali. Per questo lavoro non servono accessi amministrativi o dati di produzione.

Per ogni ID restituisci ramo e SHA, esito (confermato, superato, da correggere, in attesa di decisione), evidenza con file e simbolo, proposta, casi di test, risultato osservato e risultato atteso. Indica i confini dei file da modificare e ciò che serve al referente successivo. Se il lavoro è solo analitico, un test proposto va indicato come tale.

## Coordinamento

Tutti i prerequisiti delle schede assegnate sono interni al lotto. Trasmettere i risultati ai referenti di QK-12 (Chat), QK-15 (Pulizia), QK-27 (Verifica).

## Incarichi

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

### QK-22 · Suddividere le pagine dei promemoria

**Referente** Mobile · **Ondata** 5 · **Prerequisiti** QK-10.

**Evidenza.** Lista, calendario, form e dettaglio occupano lo stesso file di 2.416 righe.

**Compito.** Separare lista/calendario, form condiviso da creazione e modifica, e dettaglio. Preservare gli import pubblici usati dalle route.

**Criteri di accettazione.** Creazione, modifica, completamento, cancellazione, ricorrenze e cambio ora verificati. Stessi refresh per azione e nessun raddoppio del form.

**Sorgenti di partenza.** [reminders_pages.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/reminders/presentation/pages/reminders_pages.dart) · [reminders_dst_test.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/test/reminders/reminders_dst_test.dart)

### QK-24 · Condividere il selettore di coordinate

**Referente** Mobile · **Ondata** 6 · **Prerequisiti** QK-22.

**Evidenza.** Le schermate condividono 35 righe per mappa, attribuzione e segnaposto.

**Compito.** Estrarre un widget con posizione iniziale e callback sul centro. Lasciare salvataggio, validazione e invio nelle schermate proprietarie.

**Criteri di accettazione.** Verificare centro iniziale, movimento, coordinate confermate, annullamento e attribuzione visibile in entrambi i flussi.

**Sorgenti di partenza.** [report_missing_place_page.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/nearby_places/presentation/pages/report_missing_place_page.dart) · [location_picker_page.dart](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/mobile_app/lib/features/settings/presentation/pages/location_picker_page.dart)
