# Scritture dirette dell'app e regole del piano: inventario e proposta

Data: 2026-11-09 (Francesco 02f449d). Stato: **proposta, niente costruito**.
Registro dei rischi: R28.

## Il problema in parole semplici

Le regole del piano (limite di animali, «solo lettura» dopo la prova) sono
controllate dal backend. Molte scritture però l'app le fa **direttamente sul
database Supabase**, con la chiave pubblica e il token dell'utente. Lì le regole
RLS controllano solo che la riga sia dell'utente (`owner_id = auth.uid()`), non
il piano. Quindi:

- con l'app normale, chi ha finito la prova continua a creare animali, voci di
  cartella, promemoria, passeggiate, pesate e a caricare foto;
- con l'app normale si superano i limiti di animali del piano, perché l'app crea
  i pet scrivendo su `pet_profiles` e non passa da `POST /pets` (che il limite lo
  controlla, `create_pet_profile.py`);
- con un client modificato si fa tutto questo anche se l'app un giorno lo
  impedisse a schermo.

Non è una fuga di dati di altri: nessuno legge o scrive righe altrui. È un modo
di usare il servizio senza pagare e oltre i limiti, con costi di archiviazione.

## 1. Inventario delle scritture dirette (app Flutter, chiave publishable)

| Tabella / bucket | Operazioni dirette | Dove nell'app | Regola che sfugge |
| --- | --- | --- | --- |
| `pet_profiles` | upsert, update, delete | `pets/data/pet_demo_store.dart:293, 299, 327`; `pets/data/pet_photo_repository.dart:338` (foto profilo) | **limite animali per piano**; solo lettura dopo la prova |
| `clinical_events` | upsert, update, delete | `medical_records/data/medical_records_repository.dart:192-277` | solo lettura dopo la prova |
| `pet_conditions` | upsert, delete | `medical_records/data/pet_conditions_repository.dart:55, 82` | solo lettura dopo la prova |
| `reminders` | upsert, delete | `reminders/data/reminders_repository.dart:285-314` (`POST /reminders` esiste ma l'app non lo usa per tutto) | solo lettura dopo la prova |
| `dog_walks` | upsert, update, delete | `dog_walks/data/dog_walks_repository.dart:177-301` | solo lettura dopo la prova |
| `pet_weight_measurements` | insert, update, delete | `monitoring/data/weight_measurements_repository.dart:109-135` | solo lettura dopo la prova |
| `pet_photos` (righe) | insert, update, delete | `pets/data/pet_photo_repository.dart:295-347` | solo lettura dopo la prova |
| bucket `pet-photos` | upload, remove | `pet_photo_repository.dart:273`, `account/data/profile_photo_repository.dart:49` | solo lettura dopo la prova; **costo di archiviazione** (fino a 20 MB a file) |
| bucket `marketplace-photos` | upload, remove | `marketplace/data/listing_photo_store.dart:58` | foto caricate anche se l'annuncio poi è rifiutato dal backend (file orfani) |
| `user_locations` | upsert | `location/data/location_repository.dart:46` | nessuna regola di piano significativa (consiglio: esente) |
| `local_activities` | upsert | `local_activities/data/local_activities_repository.dart:42` | solo lettura dopo la prova (contenuto pubblico) |
| `marketplace_listing_reports` | insert | `marketplace/data/listing_reports_repository.dart:39` | strumento di sicurezza: deve restare aperto (c'è già `marketplace_reports_via_backend.sql`) |
| `marketplace_listings` | delete | `marketplace/data/marketplace_repository.dart:392` | nessuna: inserimento e modifica già solo dal backend dopo `marketplace_lock_writes.sql`; cancellare il proprio annuncio deve restare possibile |

Precondizione per qualunque soluzione: **`scripts/setup/subscriptions_lock_writes.sql`**
(oggi l'utente può anche scriversi da solo il piano o allungare la prova, R24).

## 2. Le strade possibili

### A. Controllo nel database (policy restrittive + trigger)

Una funzione `public.caller_can_write()` (security definer, `search_path`
fisso) legge la riga di `subscriptions` di chi chiama e dice «sì» se c'è un
piano o la prova è aperta (senza riga: prova calcolata da `auth.users.created_at`
+ 14 giorni). Su ogni tabella dell'inventario si aggiunge una policy
**restrittiva** `for insert` e `for update` `to authenticated` che la richiede.
Le **cancellazioni restano libere** (diritto alla cancellazione, pulizia dei
propri dati). Un trigger `before insert` su `pet_profiles` conta gli animali
dell'utente (con un lock per utente contro due inserimenti simultanei) e rifiuta
oltre `max_pets` del piano. Stesse policy su `storage.objects` per il bucket
`pet-photos` (solo `insert`).

Le due eccezioni che oggi vivono solo nel backend vanno portate nel database:
- **piano di test** (`SUBSCRIPTION_TEST_PLAN=pro` durante il test pubblico):
  una tabella di configurazione a una riga, impostata dal proprietario con una
  riga SQL, letta dalla funzione;
- **lista sviluppatori** (oggi e-mail in una variabile Vercel): una tabella
  `access_overrides(owner_id)` riempita dal backend (service role) quando un
  account della lista chiama `/subscription/status`.

I numeri dei limiti non si scrivono a mano: uno script (come
`gen_animal_policy.py`) genera la SQL da `limits.py` e un test fallisce se le
due copie divergono. Gli errori escono con un codice preciso
(`subscription_required`, `pet_limit_reached`) che l'app può tradurre.

- **Pro**: protegge subito anche le app già installate e i client modificati;
  nessuna rotta nuova; lavoro piccolo (uno script SQL generato + test).
- **Contro**: la regola esiste in due posti (mitigato dalla generazione e dal
  test); due tabelle di supporto; i rifiuti arrivano all'app come errori di
  Postgres.
- **Cosa rompe nelle app installate**: durante il test pubblico, con il piano di
  test impostato su Pro, quasi nulla (solo chi supera 8 animali). Quando il
  piano di test si toglie, a chi ha finito la prova le scritture vengono
  rifiutate: le app di oggi trattano l'errore come «non sincronizzato» (il dato
  resta sul telefono con l'etichetta, `pet_demo_store.dart`) e non dicono il
  perché. Serve una build che traduca i due codici in un messaggio e porti al
  paywall; finché non c'è, l'utente vede dati «non sincronizzati».

### B. Spostare le scritture nel backend (come per il Mercatino)

Ogni scrittura passa da una rotta FastAPI che applica piano, limiti, proprietà e
lunghezze; poi si tolgono le policy di insert/update dirette.

- **Pro**: una sola fonte delle regole (Python), messaggi tradotti, validazione
  degli input e test «utente B» in un posto solo; coerente con la regola di
  progetto.
- **Contro**: lavoro grande prima del lancio (rotte nuove per cartella, malattie,
  promemoria completi, passeggiate, pesate, righe foto, posizione, attività;
  caricamento foto tramite URL firmato dal backend); l'app oggi lavora
  «prima sul telefono, poi sincronizza» e diventerebbe dipendente dal backend
  (latenze e avvii a freddo di Vercel).
- **Cosa rompe nelle app installate**: appena si tolgono le policy dirette, le
  build vecchie non riescono più a salvare nulla. Serve una versione minima
  obbligatoria (blocco «aggiorna l'app») prima di togliere le policy.

## 3. Raccomandazione

**A subito, B gradualmente.**

1. Prima del test pubblico: `subscriptions_lock_writes.sql`, poi lo script
   generato della strada A con il piano di test impostato su Pro (nessun
   effetto visibile durante il test, ma il database è già chiuso) e una build
   che traduca `subscription_required` / `pet_limit_reached`.
2. Prima di togliere il piano di test (pagamenti veri): verificare la build con
   i messaggi in circolazione.
3. Dopo il lancio: spostare nel backend una scrittura alla volta, quando la
   funzione relativa viene toccata, a partire da `pet_profiles` (la rotta
   `POST /pets` con il limite esiste già); per ultima la rimozione delle policy
   dirette, dietro una versione minima obbligatoria.

Decisioni che servono al proprietario: cosa resta permesso dopo la prova oltre
alla cancellazione (consiglio: lettura e cancellazione; niente nuovi dati né
modifiche); se `user_locations` resta esente (consiglio: sì, non ha valore di
piano); se le foto già caricate oltre la prova restano o si puliscono.
