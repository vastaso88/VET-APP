# Handoff a UI/UX: integrare le fondamenta mappe nel prodotto

Richiesto dall'utente (2026-09-19): le fondamenta di dominio/backend/data-layer per le tre feature "gestione mappe" sono pronte e verificate (vedi `docs/maps/README.md` per lo stato completo). Questo documento distribuisce come l'utente vuole che le tre feature vengano integrate nelle schermate reali, con la superficie (classi/servizi) che questa sessione mette a disposizione.

**Verifica**: 248 test Python passati (mypy e ruff puliti su tutto `packages/`), 12 test Flutter passati, `flutter analyze` pulito, rotta demo `/demo/maps` (`apps/mobile_app/lib/app/preview/maps_demo_page.dart`) mostra una mappa `flutter_map` reale con marker/percorso dai dati seed delle tre feature — un riferimento concreto di come usare i pacchetti mappa già aggiunti.

## 1. Passeggiate con il cane → dentro la scheda del singolo pet

L'utente vuole questa feature **dentro la pagina/profilo di ciascun animale**, non come tab/sezione globale.

- Stato: `apps/mobile_app/lib/features/dog_walks/data/active_walk_controller.dart` (`ActiveWalkController`) gestisce già l'intero ciclo start/GPS/stop; consuma uno `Stream<Coordinates>` iniettato (in produzione, quello di `GeolocatorLocationSampler` in `features/location/data/device_location_service.dart`).
- `packages/core/domain/dog_walk/models.py:evaluate_badges` calcola i badge **per pet** (non per owner): un "prima passeggiata" a pet, soglie 10/50/100 km e 10/30/100 uscite a pet.
- **Badge/animazioni**: per capire quali badge sono "appena sbloccati" (per triggerare l'animazione), confronta `evaluate_badges(sessioni_prima_del_walk)` con `evaluate_badges(sessioni_dopo_il_walk)` — la differenza è l'insieme di badge nuovi. Nessun evento/flag dedicato esiste ancora nel dominio: se preferite un modello diverso (es. un evento esplicito emesso da `EndWalkService`), è una modifica piccola e localizzata, fatecelo sapere.
- **Notifiche push — infrastruttura non ancora esistente**: nessun pacchetto Firebase/FCM/flutter_local_notifications è presente nel progetto (verificato). Serve deciso: quale servizio (Firebase Cloud Messaging è lo standard cross-platform), chi lo implementa/configura (progetto Firebase, permessi, backend trigger). Non bloccante per il resto: l'animazione in-app può funzionare da subito senza push; la push è un livello aggiuntivo.

## 2. "Cosa c'è in zona" → widget in home, espandibile

L'utente vuole: un'anteprima predisposta in home; al tap si espande nei dettagli, incluso il programma per i giorni/mesi futuri; serve una ricerca "indicizzata" per raggio.

- Stato: `ListNearbyActivitiesService` (Python) e `LocalActivitiesRepository.loadActiveActivities()` + filtro `haversine_distance_km` (Flutter) **coprono già la ricerca per raggio** — a questa scala (deciso nel piano) non serve un indice geospaziale vero e proprio (PostGIS), il filtro Python/Dart lato client è sufficiente. Se il volume di attività crescerà molto, questo è il punto da rivedere per un indice lato DB.
- `LocalActivity` ha già `startsAt`/`endsAt`: raggruppare per "prossimi giorni/mesi" è puro lavoro di presentazione (sort/group by data), nessun nuovo campo di dominio serve.
- Non toccato: `local_events_page.dart` (placeholder attuale) — potete sostituirlo o crearne uno nuovo, a vostra scelta.

## 3. Mercatino dell'usato → interno + eventuale aggregazione esterna

- **Scambio interno tra utenti (P2P)**: pronto. `CreateListingService`/`MarketplaceRepository` fuzzano già la posizione (300-800m, deterministico) prima di salvare — mai la posizione esatta. `ReportListingService` rimuove automaticamente un annuncio dopo 3 segnalazioni da reporter distinti.
- **"O da app esterne se si riesce"**: qui l'utente ha lasciato una condizionale ("se si riesce"), non un requisito fermo. Aggregare annunci da piattaforme esterne (es. Subito.it, Facebook Marketplace, eBay) è una questione separata e non banale: richiede API ufficiali (spesso a pagamento o non disponibili per terzi), termini di servizio da rispettare, e probabilmente un adapter/infrastruttura di importazione dedicata — non è qualcosa che si aggiunge incidentalmente alla UI del mercatino interno. Raccomandazione: trattarlo come ricerca/fase 2 separata, non bloccante per lanciare lo scambio interno.

## Cosa resta aperto (non deciso da questa sessione)

- Notifiche push (vedi sopra) — nuova infrastruttura, non solo integrazione.
- Aggregazione marketplace da fonti esterne — richiede ricerca prodotto/legale a parte.
- Nome definitivo del toggle "posizione attuale vs residenza" (copy UI, vedi `docs/settings/01_brainstorm.md`).
- Fonte dati eventi reali oltre al seed/user-submitted (es. API terze) — annotato ma non deciso in `01_localita_fondamenta_condivise.md`.

## Vincolo di ownership

Questa sessione ha costruito solo dominio/servizi/repository/schema — non schermate né navigazione (`home_shell_page.dart` non toccato). L'integrazione UI, l'animazione dei badge, il widget home e le eventuali nuove voci di navigazione sono a cura vostra.
