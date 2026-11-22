# QUOKKA · Referente Pulizia

QUOKKA · 22 novembre 2026 · [Repository e revisione di riferimento](https://github.com/vastaso88/VET-APP/tree/5d79fbda5634486c5b87fc5ea916f327082a3ac0). La baseline è il commit `5d79fbda` di main. Il checkout locale MULTILANG-legacy-snapshot contiene modifiche preesistenti. Usare il commit indicato o dichiarare le differenze del ramo assegnato.

## Mandato da consegnare al modello

Prendi in carico gli ID assegnati, verifica i riscontri sulla revisione indicata e restituisci una proposta per ogni ID. **Il mandato attuale è di sola analisi.** I criteri di accettazione descrivono come verificare un eventuale refactor successivo. L’esecuzione delle modifiche richiede un mandato distinto. Usa strumenti a livello utente e fixture locali. Per questo lavoro non servono accessi amministrativi o dati di produzione.

Per ogni ID restituisci ramo e SHA, esito (confermato, superato, da correggere, in attesa di decisione), evidenza con file e simbolo, proposta, casi di test, risultato osservato e risultato atteso. Indica i confini dei file da modificare e ciò che serve al referente successivo. Se il lavoro è solo analitico, un test proposto va indicato come tale.

## Coordinamento

Il coordinatore fornisce gli esiti esterni di QK-01 (Mobile, Eliminare il preload clinico scartato). Trasmettere i risultati ai referenti di QK-20 (API), QK-27 (Verifica).

## Incarichi

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

### QK-23 · Unificare il mapping degli intenti scientifici

**Referente** Pulizia · **Ondata** 4 · **Prerequisiti** QK-15.

**Evidenza.** I quattro adapter implementano lo stesso _domain_from_intent.

**Compito.** Spostare la sola funzione comune in un punto condiviso del sottosistema retrieval.

**Criteri di accettazione.** Test parametrico dei quattro intenti noti e del fallback general su tutti gli adapter. Parser, URL e formati specifici dei provider conservano il comportamento.

**Sorgenti di partenza.** [crossref_evidence_retriever.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/llm/retrieval/crossref_evidence_retriever.py) · [europe_pmc_evidence_retriever.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/llm/retrieval/europe_pmc_evidence_retriever.py) · [openalex_evidence_retriever.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/llm/retrieval/openalex_evidence_retriever.py) · [pubmed_evidence_retriever.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/llm/retrieval/pubmed_evidence_retriever.py)

### QK-26 · Evitare la divergenza della migrazione billing

**Referente** Pulizia · **Ondata** 5 · **Prerequisiti** QK-23.

**Evidenza.** I due percorsi contengono lo stesso blob Git. La copia è documentata.

**Compito.** Indicare la migrazione come fonte e verificare automaticamente la copia richiesta dal setup.

**Criteri di accettazione.** Controllo locale che passa con i file identici e fallisce su una copia di prova alterata. Nessuna modifica a migrazioni già applicate e nessun accesso a database remoto.

**Sorgenti di partenza.** [store_billing.sql](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/scripts/setup/store_billing.sql) · [20261121180000_store_billing.sql](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/supabase/migrations/20261121180000_store_billing.sql) · [01_architettura_abbonamenti.md](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/docs/billing/01_architettura_abbonamenti.md)
