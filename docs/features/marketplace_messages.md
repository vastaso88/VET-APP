# Messaggi del Mercatino

Decisione del proprietario del 2026-11-07: i contatti del Mercatino passano da
messaggi dentro l'app, non da un campo telefono o da un'e-mail schermata. Un
compratore scrive al venditore di un annuncio e nessuno dei due conosce numero,
e-mail o id dell'altro.

## Regole

| Regola | Dove |
| --- | --- |
| Una conversazione per annuncio e compratore; nasce col primo messaggio del compratore, quindi il venditore non può scrivere per primo | `services/marketplace_messaging.py`, indice unico in SQL |
| Solo testo, massimo 1000 caratteri, nessun allegato | `domain/marketplace/messaging.py` (`MESSAGE_MAX_LENGTH`) |
| Massimo 10 nuove conversazioni in 24 ore per compratore; le risposte non contano | `domain/subscription/limits.py` (`MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY`) |
| Scrivere richiede un piano (402); leggere, segnare come letto, bloccare e segnalare no: sono dati propri e strumenti di sicurezza | `routes/marketplace_messages.py` |
| Annuncio venduto, rimosso, nascosto o cancellato, oppure chiusura dal team: conversazione leggibile, non scrivibile (409) | `_closure` nel servizio |
| Chi non partecipa riceve 404, come per un id inesistente; un blocco subito appare come conversazione chiusa | servizio; test «utente B» in `tests/integration/test_marketplace_messages_api.py` |
| Avviso «non condividere dati personali e non pagare in anticipo» sempre in testa alla conversazione, anche prima del primo messaggio | `widgets/messages_safety_notice.dart` |
| Il testo non va nei log né verso provider esterni e non è mai interpretato come HTML o link | backend e `marketplace_conversation_page.dart` |

## Rotte (tutte con `get_current_user()`)

| Metodo e percorso | Serve a | Piano |
| --- | --- | --- |
| `POST /marketplace/listings/{id}/conversations` | primo messaggio o seguito, dal compratore | sì |
| `GET /marketplace/listings/{id}/conversation` | la propria conversazione su quell'annuncio, o `null` | no |
| `GET /marketplace/conversations` | elenco e totale non letti | no |
| `GET /marketplace/conversations/unread-count` | solo il numero, per la busta | no |
| `GET /marketplace/conversations/{id}` | conversazione e ultimi 200 messaggi | no |
| `POST /marketplace/conversations/{id}/messages` | nuovo messaggio | sì |
| `POST /marketplace/conversations/{id}/read` | segna come letti | no |
| `POST`, `DELETE /marketplace/conversations/{id}/block` | blocca, sblocca l'altra persona | no |
| `POST /marketplace/conversations/{id}/report` | segnala (un solo motivo a scelta, nessun testo libero) | no |

Moderazione, solo per gli amministratori e nel portale: `GET /admin/moderation/marketplace_messages`,
`GET` e `POST /admin/moderation/marketplace_messages/{id}` (azioni `close_conversation`,
`dismiss_report`, `reopen_report`). Il team legge i messaggi solo di una conversazione segnalata
e l'app lo dice nella finestra di segnalazione.

## Dati

Tabelle in `scripts/setup/marketplace_messages.sql` (stesso blocco in `supabase_schema.sql`).
Si legge e si scrive solo dal backend: `anon` e `authenticated` non hanno privilegi, perché una
lettura diretta mostrerebbe l'id dell'altra persona.

- **Cancellazione dell'account**: sparisce l'intera conversazione, anche con le risposte
  dell'altra persona, che possono citare i dati di chi cancella.
- **Esportazione**: conversazioni e messaggi di entrambi, con l'id dell'altra persona sempre
  `null`; solo i blocchi fatti, non quelli subiti.
- **Conservazione (proposta)**: 6 mesi dall'ultimo messaggio se l'annuncio è chiuso, 12 mesi
  comunque, mai con una segnalazione aperta. La esegue `marketplace_messages_cleanup()` ogni
  notte con pg_cron.

## Avvisi

Oggi non ci sono notifiche push: il numero sulla busta si aggiorna all'apertura e ogni minuto con
il Mercatino aperto, la conversazione ogni 20 secondi. Proposta: aggiungere le push subito dopo il
test con il pubblico e prima del lancio, perché senza avviso chi vende non sa di avere un messaggio
se non riapre il Mercatino.
