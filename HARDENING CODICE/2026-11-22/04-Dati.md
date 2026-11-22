# QUOKKA · Referente Dati

QUOKKA · 22 novembre 2026 · [Repository e revisione di riferimento](https://github.com/vastaso88/VET-APP/tree/5d79fbda5634486c5b87fc5ea916f327082a3ac0). La baseline è il commit `5d79fbda` di main. Il checkout locale MULTILANG-legacy-snapshot contiene modifiche preesistenti. Usare il commit indicato o dichiarare le differenze del ramo assegnato.

## Mandato da consegnare al modello

Prendi in carico gli ID assegnati, verifica i riscontri sulla revisione indicata e restituisci una proposta per ogni ID. **Il mandato attuale è di sola analisi.** I criteri di accettazione descrivono come verificare un eventuale refactor successivo. L’esecuzione delle modifiche richiede un mandato distinto. Usa strumenti a livello utente e fixture locali. Per questo lavoro non servono accessi amministrativi o dati di produzione.

Per ogni ID restituisci ramo e SHA, esito (confermato, superato, da correggere, in attesa di decisione), evidenza con file e simbolo, proposta, casi di test, risultato osservato e risultato atteso. Indica i confini dei file da modificare e ciò che serve al referente successivo. Se il lavoro è solo analitico, un test proposto va indicato come tale.

## Coordinamento

Tutti i prerequisiti delle schede assegnate sono interni al lotto. Trasmettere i risultati ai referenti di QK-11 (Chat), QK-21 (Web).

## Incarichi

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
