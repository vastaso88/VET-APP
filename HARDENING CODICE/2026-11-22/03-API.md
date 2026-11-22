# QUOKKA · Referente API

QUOKKA · 22 novembre 2026 · [Repository e revisione di riferimento](https://github.com/vastaso88/VET-APP/tree/5d79fbda5634486c5b87fc5ea916f327082a3ac0). La baseline è il commit `5d79fbda` di main. Il checkout locale MULTILANG-legacy-snapshot contiene modifiche preesistenti. Usare il commit indicato o dichiarare le differenze del ramo assegnato.

## Mandato da consegnare al modello

Prendi in carico gli ID assegnati, verifica i riscontri sulla revisione indicata e restituisci una proposta per ogni ID. **Il mandato attuale è di sola analisi.** I criteri di accettazione descrivono come verificare un eventuale refactor successivo. L’esecuzione delle modifiche richiede un mandato distinto. Usa strumenti a livello utente e fixture locali. Per questo lavoro non servono accessi amministrativi o dati di produzione.

Per ogni ID restituisci ramo e SHA, esito (confermato, superato, da correggere, in attesa di decisione), evidenza con file e simbolo, proposta, casi di test, risultato osservato e risultato atteso. Indica i confini dei file da modificare e ciò che serve al referente successivo. Se il lavoro è solo analitico, un test proposto va indicato come tale.

## Coordinamento

Il coordinatore fornisce gli esiti esterni di QK-14 (Pulizia, Verificare e ritirare otto factory scollegate). Trasmettere i risultati ai referenti di QK-27 (Verifica).

## Incarichi

### QK-05 · Risolvere l’identità una volta per richiesta

**Referente** API · **Ondata** 1 · **Prerequisiti** nessuno.

**Evidenza.** POST /pets risolve due volte l’identità. Con Supabase ciascuna risoluzione chiama auth.get_user.

**Compito.** Inventariare handler e dipendenze che ripetono la validazione. Condividere la sola identità verificata entro la richiesta. Iniziare dalle route animali e Mercatino.

**Criteri di accettazione.** Sul percorso POST /pets riuscito, 1 validazione del token. Provare richieste concorrenti di due utenti, sessione revocata, età, consensi, abbonamento e percorsi di recupero. Elencare le route coperte.

**Sorgenti di partenza.** [subscription.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/dependencies/subscription.py) · [marketplace.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/dependencies/marketplace.py) · [pets.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/pets.py) · [age_guarded_auth_provider.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/auth/age_guarded_auth_provider.py) · [supabase_auth_provider.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/infrastructure/auth/supabase_auth_provider.py)

### QK-18 · Determinare il destino delle notifiche di cancellazione

**Referente** API · **Ondata** 2 · **Prerequisiti** QK-05.

**Evidenza.** due_waiting_notice ha test ma non emerge un chiamante di produzione nel repository.

**Compito.** Solo analisi. Incrociare calendario, requisiti e scheduler. Esplicitare cosa manca per usarlo e chi decide se collegarlo o ritirarlo.

**Criteri di accettazione.** Consegnare una nota con riferimenti e decisione richiesta al responsabile di prodotto. Stato finale ammesso: in attesa di decisione. Nessun invio email.

**Sorgenti di partenza.** [notices.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/core/domain/account_deletion/notices.py) · [test_deletion_notices.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_deletion_notices.py) · [lifecycle.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/apps/api/routes/lifecycle.py)

### QK-20 · Dividere la composizione dei servizi

**Referente** API · **Ondata** 4 · **Prerequisiti** QK-14, QK-18.

**Evidenza.** Il container concentra in 1.810 righe wiring di billing, chat, persistenza e modalità di test.

**Compito.** Dopo la pulizia delle factory, estrarre un gruppo per volta partendo dal meno accoppiato. Preservare get_container(), override, inizializzazione lazy e durata di cache e client.

**Criteri di accettazione.** Confrontare configurazioni in-memory e Supabase tramite fake. Testare reset del container, riuso delle istanze previste e contratti delle factory pubbliche.

**Passaggio di consegne.** Coordinare con le modifiche di pricing nella PR #65.

**Sorgenti di partenza.** [container.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/packages/bootstrap/container.py)
