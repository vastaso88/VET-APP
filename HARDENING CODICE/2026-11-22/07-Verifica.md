# QUOKKA · Referente Verifica

QUOKKA · 22 novembre 2026 · [Repository e revisione di riferimento](https://github.com/vastaso88/VET-APP/tree/5d79fbda5634486c5b87fc5ea916f327082a3ac0). La baseline è il commit `5d79fbda` di main. Il checkout locale MULTILANG-legacy-snapshot contiene modifiche preesistenti. Usare il commit indicato o dichiarare le differenze del ramo assegnato.

## Mandato da consegnare al modello

Prendi in carico gli ID assegnati, verifica i riscontri sulla revisione indicata e restituisci una proposta per ogni ID. **Il mandato attuale è di sola analisi.** I criteri di accettazione descrivono come verificare un eventuale refactor successivo. L’esecuzione delle modifiche richiede un mandato distinto. Usa strumenti a livello utente e fixture locali. Per questo lavoro non servono accessi amministrativi o dati di produzione.

Per ogni ID restituisci ramo e SHA, esito (confermato, superato, da correggere, in attesa di decisione), evidenza con file e simbolo, proposta, casi di test, risultato osservato e risultato atteso. Indica i confini dei file da modificare e ciò che serve al referente successivo. Se il lavoro è solo analitico, un test proposto va indicato come tale.

## Coordinamento

Il coordinatore fornisce gli esiti esterni di QK-19 (Chat, Estrarre la preparazione della risposta naturale), QK-20 (API, Dividere la composizione dei servizi), QK-21 (Web, Separare router e client admin per funzione), QK-24 (Mobile, Condividere il selettore di coordinate), QK-25 (Web, Condividere i valori specie e intento), QK-26 (Pulizia, Evitare la divergenza della migrazione billing). Consegnare il riepilogo al coordinatore.

## Incarichi

### QK-27 · Validare l’integrazione e misurare il risultato

**Referente** Verifica · **Ondata** 7 · **Prerequisiti** QK-19, QK-20, QK-21, QK-24, QK-25, QK-26.

**Evidenza.** La baseline ha 61 test mirati superati e conteggi applicativi. Latenza reale e byte richiedono una misura separata.

**Compito.** Predisporre la baseline prima della prima ondata. Ripetere sugli stessi casi dopo ogni gruppo integrato e compilare un registro degli ID con prove e regressioni.

**Criteri di accettazione.** Per ogni ID registrare accettato, da correggere, superato o in attesa, con SHA e motivazione. Confrontare query e payload; per latenza annotare dispositivo, numero di campioni, p50/p95 e avvio caldo/freddo. Dichiarare le misure indisponibili.

**Passaggio di consegne.** Il referente può preparare i casi subito. Il giudizio integrato segue tutti i lotti.

**Sorgenti di partenza.** [test_send_chat_message_retry.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_send_chat_message_retry.py) · [test_conversation_titles_and_summary.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/unit/test_conversation_titles_and_summary.py) · [test_admin_users.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/integration/test_admin_users.py) · [test_marketplace_messages_api.py](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/tests/integration/test_marketplace_messages_api.py) · [ci.yml](https://github.com/vastaso88/VET-APP/blob/5d79fbda5634486c5b87fc5ea916f327082a3ac0/.github/workflows/ci.yml)
