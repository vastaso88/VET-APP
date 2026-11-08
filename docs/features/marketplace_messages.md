# Messaggi del Mercatino

Decisione del proprietario del 2026-11-07: i contatti del Mercatino passano da
messaggi dentro l'app, non da un campo telefono o da un'e-mail schermata. Un
compratore scrive al venditore di un annuncio e nessuno dei due conosce numero,
e-mail o id dell'altro.

## Decisioni del proprietario (2026-11-07)

1. **Conservazione**: una conversazione si cancella 6 mesi dopo l'ultimo messaggio se
   l'annuncio è chiuso, comunque dopo 12 mesi, mai finché ha una segnalazione aperta.
2. **Anti-spam**: al massimo 10 nuove conversazioni al giorno per persona; le risposte non
   contano.
3. **Venditore senza piano**: nessuno può aprire una conversazione nuova con lui. L'annuncio
   mostra una frase neutra («Per questo annuncio non è possibile scrivere.»), uguale a quella
   per un annuncio chiuso o un blocco: non rivela se il venditore paga. Le conversazioni già
   aperte restano leggibili.
4. **Blocco dal Mercatino da parte del team**: dal portale il team può tenere fuori una
   persona (niente annunci nuovi, niente modifiche, niente messaggi) con un motivo e la data,
   e annullare il blocco. La persona legge il motivo e la data nella sua lingua, mai la nota
   del team; può ancora leggere, segnalare e cancellare i propri annunci.
5. **Notifiche push**: non ora, dopo il test con il pubblico.

## Decisioni del proprietario (2026-11-08)

21. **Conversazione segnalata dopo la cancellazione di un account** (parere
    `docs/compliance/10_pareri_dal_2026_11_06.md` §2.3, 7 condizioni): si tiene solo se la
    segnalazione è aperta o accolta, e solo quella conversazione. L'id di chi cancella diventa
    `deleted-buyer` o `deleted-seller` in conversazione, messaggi e segnalazione; vale anche se
    cancella chi ha segnalato. Da quel momento la vede solo il team: all'altra persona sparisce
    dall'app, come senza la segnalazione. Si cancella appena la segnalazione è respinta, oppure
    12 mesi dopo la decisione. Ogni lettura e decisione del team resta in
    `marketplace_moderation_access_log` (24 mesi). Nel portale il dettaglio mostra fino a quando
    la si tiene e chi l'ha guardata.
22. **Contatti nei messaggi privati: permessi**; negli annunci pubblici restano vietati. Testi
    della sessione Normativa (`docs/compliance/11_esclusioni_responsabilita.md` §4): frase sopra
    «Pubblica annuncio», pagina «Come funziona il Mercatino» (icona «i» nella barra del Mercatino
    e di ogni conversazione), avviso fisso in testa a ogni conversazione, riga «Annuncio di un
    privato» sotto il prezzo.
23. **«Se la conversazione viene segnalata, il team di Quokka può leggerla.»**: nell'avviso
    fisso, in 5 lingue.
24. **Segnalare un annuncio: consentito a tutti**, anche senza piano; senza piano non si può
    fare altro (niente conversazioni nuove: 402).

## Regole

| Regola | Dove |
| --- | --- |
| Una conversazione per annuncio e compratore; nasce col primo messaggio del compratore, quindi il venditore non può scrivere per primo | `services/marketplace_messaging.py`, indice unico in SQL |
| Solo testo, massimo 1000 caratteri, nessun allegato | `domain/marketplace/messaging.py` (`MESSAGE_MAX_LENGTH`) |
| Massimo 10 nuove conversazioni in 24 ore per compratore; le risposte non contano | `domain/subscription/limits.py` (`MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY`) |
| Scrivere richiede un piano (402); leggere, segnare come letto, bloccare e segnalare no: sono dati propri e strumenti di sicurezza | `routes/marketplace_messages.py` |
| Annuncio venduto, rimosso, nascosto o cancellato, oppure chiusura dal team: conversazione leggibile, non scrivibile (409) | `_closure` nel servizio |
| Chi non partecipa riceve 404, come per un id inesistente; un blocco subito appare come conversazione chiusa | servizio; test «utente B» in `tests/integration/test_marketplace_messages_api.py` |
| Avviso fisso in testa alla conversazione, anche prima del primo messaggio: Quokka non è parte dell'accordo, contatti sotto la propria responsabilità, non pagare in anticipo, il team può leggere una conversazione segnalata | `widgets/messages_safety_notice.dart` |
| Il testo non va nei log né verso provider esterni e non è mai interpretato come HTML o link | backend e `marketplace_conversation_page.dart` |
| Nessuna conversazione nuova con un venditore che non potrebbe rispondere (senza piano o tenuto fuori dal team); la risposta è identica a quella per un annuncio non disponibile | `_can_start` nel servizio; `owner_can_write_on_marketplace` in `container.py` |
| Chi è tenuto fuori dal team riceve 403 `marketplace_restricted` (motivo e data) su pubblicazione, modifica e messaggi; l'altra persona vede solo «conversazione chiusa» | `raise_if_restricted`, `dependencies/marketplace.py` |

## Rotte (tutte con `get_current_user()`)

| Metodo e percorso | Serve a | Piano |
| --- | --- | --- |
| `POST /marketplace/listings/{id}/conversations` | primo messaggio o seguito, dal compratore | sì |
| `GET /marketplace/listings/{id}/conversation` | la propria conversazione su quell'annuncio, o `null`, e `can_start` | no |
| `GET /marketplace/restriction` | il proprio eventuale blocco da parte del team (motivo e data) | no |
| `GET /marketplace/conversations` | elenco e totale non letti | no |
| `GET /marketplace/conversations/unread-count` | solo il numero, per la busta | no |
| `GET /marketplace/conversations/{id}` | conversazione e ultimi 200 messaggi | no |
| `POST /marketplace/conversations/{id}/messages` | nuovo messaggio | sì |
| `POST /marketplace/conversations/{id}/read` | segna come letti | no |
| `POST`, `DELETE /marketplace/conversations/{id}/block` | blocca, sblocca l'altra persona | no |
| `POST /marketplace/conversations/{id}/report` | segnala (un solo motivo a scelta, nessun testo libero) | no |

Moderazione, solo per gli amministratori e nel portale: `GET /admin/moderation/marketplace_messages`,
`GET` e `POST /admin/moderation/marketplace_messages/{id}` (azioni `close_conversation`,
`dismiss_report`, `reopen_report`); `GET` e `POST /admin/moderation/marketplace_restrictions`,
`POST /admin/moderation/marketplace_restrictions/{owner_id}/lift` per tenere fuori una persona o
farla rientrare. Il team legge i messaggi solo di una conversazione segnalata
e l'app lo dice nella finestra di segnalazione.

## Dati

Tabelle in `scripts/setup/marketplace_messages.sql` (stesso blocco in `supabase_schema.sql`).
Si legge e si scrive solo dal backend: `anon` e `authenticated` non hanno privilegi, perché una
lettura diretta mostrerebbe l'id dell'altra persona.

- **Cancellazione dell'account**: sparisce l'intera conversazione, anche con le risposte
  dell'altra persona, che possono citare i dati di chi cancella.
- **Esportazione**: conversazioni e messaggi di entrambi, con l'id dell'altra persona sempre
  `null`; solo i blocchi fatti, non quelli subiti.
- **Conservazione (decisa)**: 6 mesi dall'ultimo messaggio se l'annuncio è chiuso, 12 mesi
  comunque, mai con una segnalazione aperta; un blocco del team annullato da più di 12 mesi si
  cancella. La esegue `marketplace_messages_cleanup()` ogni notte con pg_cron.
- **Blocco del team**: tabella `marketplace_user_restrictions`. Anche scrivendo direttamente
  nella tabella degli annunci con la propria sessione, una policy restrittiva lo impedisce
  (`marketplace_caller_is_restricted()`, che risponde solo su chi chiama).

## Avvisi

Oggi non ci sono notifiche push: il numero sulla busta si aggiorna all'apertura e ogni minuto con
il Mercatino aperto, la conversazione ogni 20 secondi. Le push arrivano dopo il test con il pubblico
(decisione del 2026-11-07).
