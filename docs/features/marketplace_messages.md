# Messaggi del Mercatino

Decisione del proprietario del 2026-11-07: i contatti del Mercatino passano da
messaggi dentro l'app, non da un campo telefono o da un'e-mail schermata. Un
compratore scrive al venditore di un annuncio e nessuno dei due conosce numero,
e-mail o id dell'altro.

## Decisioni del proprietario (2026-11-07)

1. **Conservazione**: una conversazione si cancella 6 mesi dopo l'ultimo messaggio se
   l'annuncio è chiuso, comunque dopo 12 mesi, mai finché ha una segnalazione aperta
   (confermata il 2026-11-23; l'8 novembre il codice era passato a contare dalla chiusura).
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
    6 mesi dopo la decisione (12 fino al 2026-11-23). Ogni lettura e decisione del team resta in
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

## Decisione del proprietario (2026-11-25)

25. **Contatti e codici nei messaggi: un avviso, mai un blocco. Caratteri nascosti: si tolgono**
    (F27).

Scelte di realizzazione (proposta, non decisioni del proprietario):

- L'avviso compare mentre si scrive, prima dell'invio, e sotto l'ultimo messaggio della
  conversazione che ha un contatto o un codice, scritto o ricevuto. Contatti: telefono, e-mail,
  link, profilo social. Codici: di verifica, PIN, password, CVV, anche solo chiesti. Carte e IBAN
  contano come numeri; date, orari, prezzi e CAP no.
- Regole fisse nel server (`domain/marketplace/message_text.py`), le stesse nell'app
  (`message_caution.dart`), casi comuni in `tests/fixtures/marketplace_message_caution_cases.json`.
  Niente è salvato e niente va a un fornitore: la risposta porta solo `caution`, sì o no.
- Il server toglie larghezza zero, direzione del testo, controlli e riempitivi vuoti prima di
  salvare e prima di mostrare, anche al team e anche nei messaggi già salvati. Quello che si vede
  non cambia: gli emoji restano interi e `<b>` resta testo. Un messaggio di soli caratteri nascosti
  è vuoto (400). L'esportazione dei propri dati riporta il testo come è salvato.

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
| Caratteri nascosti tolti prima di salvare e di mostrare; contatto o codice → `caution` nel messaggio, mai un rifiuto | `domain/marketplace/message_text.py`; `_clean`, `_message_view` e `detail` nel servizio |
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
  dell'altra persona, che possono citare i dati di chi cancella. Resta solo, per il team, una
  conversazione con una segnalazione aperta o accolta (decisione 21).
- **Esportazione**: conversazioni e messaggi di entrambi, con l'id dell'altra persona sempre
  `null`; solo i blocchi fatti, non quelli subiti.
- **Conservazione (decisa il 2026-11-07, confermata il 2026-11-23: come promettono i testi)**:
  6 mesi dall'ultimo messaggio se l'annuncio è chiuso (venduto) o cancellato, 12 mesi dall'ultimo
  messaggio comunque, mai con una segnalazione aperta; la chiusura della conversazione da parte
  del team non conta (precisazione dell'Orchestratore, 2026-11-23). Decisioni B e C del
  proprietario (2026-11-23 sera, riferite dall'Orchestratore): dopo una segnalazione decisa,
  accolta o respinta, la conversazione resta ancora 6 mesi per un riesame, anche oltre i 6 e i 12
  (`review_months`); un annuncio tolto (`removed`, `removed_policy`) si può ripristinare, quindi
  non conta come chiuso finché non viene cancellato, e i 12 mesi valgono anche per lui; quando si
  cancella un annuncio tolto dal team (`removed_policy`) le sue conversazioni mai segnalate vanno
  con lui (trigger `marketplace_listing_10_drop_conversations`); con un account eliminato una
  conversazione con segnalazione accolta resta 6 mesi dopo la decisione (prima 12); un blocco
  del team si cancella 12 mesi dopo che è finito, annullato o scaduto. La esegue
  `marketplace_messages_cleanup()` ogni notte con pg_cron; la regola è nella migrazione
  `20261123100000_marketplace_messages_retention.sql`. Per aggiornare un database esistente si
  lancia solo quella, dopo che i testi pubblicati dicono B e C.
- **Blocco del team**: tabella `marketplace_user_restrictions`. Anche scrivendo direttamente
  nella tabella degli annunci con la propria sessione, una policy restrittiva lo impedisce
  (`marketplace_caller_is_restricted()`, che risponde solo su chi chiama).

## Avvisi

Oggi non ci sono notifiche push: il numero sulla busta si aggiorna all'apertura e ogni minuto con
il Mercatino aperto, la conversazione ogni 20 secondi. Le push arrivano dopo il test con il pubblico
(decisione del 2026-11-07).

## Solo privati (decisione del proprietario, 2026-11-09)

A ogni pubblicazione e modifica di un annuncio una casella obbligatoria, mai preselezionata:
«Dichiaro di vendere come privato, non nell'ambito di un'attività commerciale o professionale.»
(testi della Normativa, `docs/compliance/11_esclusioni_responsabilita.md` §4). Senza, il backend
risponde 400 `private_seller_declaration_required`; con, salva sull'annuncio data
(`private_seller_declared_at`) e versione del testo (`private_seller_declaration_version`,
oggi `2026-11-09`). Le due colonne si vedono solo nei propri annunci. SQL:
`scripts/setup/marketplace_private_sellers.sql` (stesso blocco in `supabase_schema.sql`), con due
policy restrittive per chi scrive direttamente nella tabella. Le app già installate non mandano la
dichiarazione: dopo il deploy non possono pubblicare finché non si aggiornano.

## Farmaci, cibo e integratori (decisioni del proprietario, 2026-11-23)

Regole e testi: `docs/compliance/24_regole_del_mercatino_v1.md` (v2). Le parole stanno solo nel
backend; l'app mostra ciò che il server risponde.

| Caso | Che cosa succede | Dove |
| --- | --- | --- |
| Farmaco o prodotto con principi attivi inequivocabile (collare, pipetta, spray o compresse antipulci, shampoo medicato, marchi) | rifiutato, niente viene salvato | `content_policy.py` |
| Cibo, mangimi, snack, integratori | avviso 1 e casella, poi **pubblicato subito** | `content_review.py` |
| Parole ambigue da sole («antipulci», «antiparassitario», «shampoo») | avviso 2 e casella, poi **pubblicato subito** | `content_review.py` |
| Accessori senza queste parole | niente | |

- **Conferma**: 400 `content_confirmation_required` con `fix.value` (`food`, `active_substance`) e
  `fix.terms` (parole trovate); l'app ripete la richiesta con `content_confirmations`. Si chiede di
  nuovo quando cambiano testo, categoria o foto, non per il solo prezzo. Senza la riga della
  conferma salvata l'annuncio non va online.
- **Team**: `GET /admin/moderation/listing_reviews`, `GET` e `POST .../{id}` con `checked`,
  `removed` (motivo obbligatorio: `food`, `supplement`, `medicine`, `other`) o `restored` (riesame
  accolto). 409 se l'annuncio è cambiato dopo che l'amministratore lo ha aperto. Nel portale:
  sezione «Listings to check» e pagina con le parole evidenziate. Se nessuno interviene, resta.
- **Chi vende**: `GET /marketplace/listings/mine` e pagina «I miei annunci»: stato e, se tolto,
  motivo, data, parole trovate e come chiedere il riesame. Mai la coda, la nota o chi ha deciso.
- **Dati**: `scripts/setup/marketplace_content_review.sql` (stesso blocco in `supabase_schema.sql`):
  `marketplace_listing_reviews` (si cancella con l'annuncio o l'account),
  `marketplace_listing_decision_log` (senza id di chi vende e senza testo) e il bucket privato
  `marketplace-photos-held`. **Va eseguito prima del deploy.**
- **Foto e tempi** (`services/removed_listings.py`): quando il team toglie un annuncio le foto
  passano dal bucket pubblico a quello privato (il team le vede con un link di 10 minuti) e
  tornano se il riesame è accolto. Il lavoro orario `POST /admin/lifecycle/prune-removed-listings`
  riprova gli spostamenti falliti, cancella annuncio e foto 6 mesi dopo la decisione (183 giorni),
  subito dopo le foto di un annuncio che chi vende ha cancellato, e il registro dopo 24 mesi (730).
  Si toccano solo file nella cartella di chi vende; una foto mostrata anche da un altro suo
  annuncio online resta pubblica. Un link già aperto può restare nella cache della rete per il
  tempo fissato da Supabase.
- Le app già installate non hanno le caselle: un annuncio con quelle parole si pubblica solo dopo
  l'aggiornamento (leggono la frase del server). Gli annunci già online non vengono toccati.

### Annunci nascosti o tolti dopo le segnalazioni (Regole v2, punto 6)

| Caso | Stato | Che cosa vede chi vende (`removal` in `GET /marketplace/listings/mine`) |
| --- | --- | --- |
| Tre segnalazioni aperte di persone diverse | `removed`, finché il team non decide | `kind: reports` e il **giorno** (mai l'ora né ciò che le persone hanno scritto, per non far riconoscere chi ha segnalato) |
| Tolto dal team, da una coda o dall'altra | `removed_policy` | `kind: team`, motivo scelto dal team, data, parole trovate se c'era una conferma |
| Regola automatica sugli animali | `removed_policy` senza decisione | `kind: rule`, `sells_animals`, data |

- Nella coda delle segnalazioni «Remove listing» registra la stessa decisione della coda dei
  controlli (motivo per chi vende, registro senza il suo id, 6 mesi); «Restore listing» la annulla.
- Le foto di ogni annuncio nascosto escono dal bucket pubblico; tornano se l'annuncio torna. Solo
  gli annunci **tolti dal team** si cancellano dopo 6 mesi.
- Una segnalazione nuova non cambia lo stato di un annuncio già tolto dal team, quelle respinte non
  contano e il conteggio non riscrive più tutta la riga dell'annuncio.
- SQL: `scripts/setup/marketplace_hidden_ads.sql`, dopo `marketplace_content_review.sql`.

### Foto degli annunci (K23, 2026-11-23)

1. L'app carica la foto nella cartella di chi vende (`<id>/<...>/<...>.jpg`).
2. Quando l'annuncio si pubblica o cambia, e solo dopo tutti i controlli e le conferme, il backend
   copia le foto nuove in `published/<id annuncio>/` (JPEG verificato, senza metadati), salva
   l'annuncio e cancella gli originali e le foto tolte. Se qualcosa fallisce le copie si cancellano e
   l'annuncio resta com'era: mai metà delle foto.
3. Agli altri si mostrano solo le copie di quell'annuncio. Chi vende
   vede anche le proprie foto vecchie, per non perderle in una modifica.
4. `DELETE /marketplace/listings/{id}` toglie subito annuncio e foto. Le app già installate cancellano
   la riga da sole: le copie le toglie il lavoro orario, che toglie anche quelle senza annuncio (dopo
   un'ora) e i caricamenti mai pubblicati (dopo 24 ore).
5. Cancellazione account: copie pubbliche e private di ogni annuncio. Esportazione: le foto degli
   annunci visibili sono dietro i loro indirizzi, quelle degli annunci nascosti hanno un link firmato.

**Freno del lavoro orario**: i file non hanno una copia di sicurezza. Un file che una riga può
intendere non si cancella mai (conta il percorso, non l'indirizzo); se i file senza annuncio sono più
di 50, più del 10% (oltre 5) o tutti, non se ne cancella nessuno e il lavoro risponde 500 con i
conteggi. Dopo aver guardato, si ripete con `?allow_leftovers=<numero>`.

**Se cambia l'indirizzo di Supabase** (`SUPABASE_URL`): prima di riaprire il Mercatino si riscrivono
i collegamenti in `photo_urls` degli annunci e dei controlli. Il lavoro orario dà l'allarme solo
finché nessun annuncio è al nuovo indirizzo: dal primo annuncio nuovo tace, e le foto di un annuncio
vecchio nascosto dopo non verrebbero spostate.

**Annunci già pubblicati**: fino alla copia gli altri non ne vedono le foto. La fa
`scripts/maintenance/publish_marketplace_photos.py` (senza `--apply` conta soltanto), un annuncio alla
volta, e aggiorna anche le righe dei controlli.

### Note di rilascio delle Regole v2

1. In produzione, nell'ordine: conteggio `marketplace_external_photos.sql`,
   `marketplace_content_review.sql`, `marketplace_hidden_ads.sql`,
   `marketplace_published_photos.sql`, la migrazione di Cybersicurezza sui tempi dei messaggi
   (punto 7), la copia delle foto vecchie (prima il conteggio, poi `--apply`), poi il deploy.
2. **`MARKETPLACE_RULES_REQUIRED` si accende solo dopo quella migrazione**: prima il punto 7
   direbbe una cosa che il database non fa.
3. Chi ha accettato la v1 accetta di nuovo.
4. I testi ES, DE e FR delle Regole sono passati da Revisione traduzioni, non da un madrelingua.
5. Dopo il deploy, una seconda volta la copia delle foto: prende gli annunci pubblicati nel mezzo.
