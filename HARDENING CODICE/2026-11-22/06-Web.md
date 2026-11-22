# QUOKKA · Referente Web

QUOKKA · 22 novembre 2026 · [Repository e revisione di riferimento](https://github.com/vastaso88/VET-APP/tree/5d79fbda5634486c5b87fc5ea916f327082a3ac0). La baseline è il commit `5d79fbda` di main. Il checkout locale MULTILANG-legacy-snapshot contiene modifiche preesistenti. Usare il commit indicato o dichiarare le differenze del ramo assegnato.

## Mandato da consegnare al modello

Prendi in carico gli ID assegnati, verifica i riscontri sulla revisione indicata e restituisci una proposta per ogni ID. **Il mandato attuale è di sola analisi.** I criteri di accettazione descrivono come verificare un eventuale refactor successivo. L’esecuzione delle modifiche richiede un mandato distinto. Usa strumenti a livello utente e fixture locali. Per questo lavoro non servono accessi amministrativi o dati di produzione.

Per ogni ID restituisci ramo e SHA, esito (confermato, superato, da correggere, in attesa di decisione), evidenza con file e simbolo, proposta, casi di test, risultato osservato e risultato atteso. Indica i confini dei file da modificare e ciò che serve al referente successivo. Se il lavoro è solo analitico, un test proposto va indicato come tale.

## Coordinamento

Il coordinatore fornisce gli esiti esterni di QK-07 (Dati, Paginare le directory admin alla fonte). Trasmettere i risultati ai referenti di QK-27 (Verifica).

## Incarichi

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

### QK-25 · Condividere i valori specie e intento

**Referente** Web · **Ondata** 3 · **Prerequisiti** QK-17.

**Evidenza.** I form di scheduling e discovery ripetono i valori di specie e intenti.

**Compito.** Estrarre dati comuni e mantenere nei due form i rispettivi default, etichette e gestori.

**Criteri di accettazione.** Confrontare valori e payload di ogni opzione in entrambi i form, eseguire typecheck admin.

**Sorgenti di partenza.** [page.tsx](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/app/jobs/page.tsx) · [scientific-discovery-panel.tsx](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/components/scientific-discovery-panel.tsx)

### QK-21 · Separare router e client admin per funzione

**Referente** Web · **Ondata** 4 · **Prerequisiti** QK-07, QK-16, QK-17, QK-25.

**Evidenza.** Il router principale ha 1.620 righe e il client admin 1.191. Router specializzati importano helper privati dal principale.

**Compito.** Estrarre prima dipendenze comuni e poi separare cruscotto, moderazione e ingestion in passaggi verificabili. Migrare il client mantenendo gli import pubblici utilizzati.

**Criteri di accettazione.** Confrontare metodi e path OpenAPI prima/dopo. Provare autorizzazioni, paginazione, scheduler e durata cache cruscotto. Typecheck e build admin.

**Passaggio di consegne.** Ricontrollare PR #60 e #65. Coordinare con Dati prima di spostare helper condivisi.

**Sorgenti di partenza.** [admin.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/admin.py) · [admin_users.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/admin_users.py) · [admin-api.ts](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/admin_portal/lib/admin-api.ts)
