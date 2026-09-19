# Località: fondamenta condivise e le tre feature mappe

Risolve le domande aperte lasciate in `docs/settings/01_brainstorm.md` ("Località: filtro geografico per news ed eventi") e descrive il design effettivamente costruito per le tre idee del brainstorm "gestione mappe": passeggiate con il cane, mercatino dell'usato geolocalizzato, attività/eventi nei dintorni.

## Vincolo di ownership

Questo lavoro copre solo **dominio, servizi applicativi, schema Supabase e data/domain layer Flutter** — non le schermate di produzione né la navigazione reale (`apps/mobile_app/lib/app/shell/home_shell_page.dart`), che restano di competenza della sessione "UI/UX e funzionalità base". L'unica eccezione è una rotta demo nascosta (`/demo/maps`, non collegata a nessun bottone reale) usata per verificare che le tre feature funzionino davvero.

## Decisioni tecniche

- **Mappa**: `flutter_map` (^8.3.2) + tile OpenStreetMap, non `google_maps_flutter` (supporto Flutter Web incerto, serve API key/fatturazione).
- **Geolocalizzazione**: `geolocator` (^14.0.2 — non 14.0.3+, che entra in conflitto con il vincolo `win32` di `share_plus` già in pubspec). Nessun `permission_handler`: `geolocator` gestisce già permessi cross-platform da solo.
- **Passi**: nessun package `pedometer` (solo Android/iOS, l'app è web-first). `estimate_steps` stima i passi dalla distanza GPS, dichiaratamente una stima.
- **Coordinate nel DB**: colonne `double precision` semplici (niente PostGIS) — sufficiente alla scala attuale.
- **Fuzzing privacy**: mai per passeggiate (private) o attività (luoghi pubblici); sempre per gli annunci del mercatino — offset polare deterministico 300-800m seminato dall'id dell'annuncio (`fuzz_coordinates` in `packages/core/domain/geo/models.py`), mai la coordinata esatta persistita.
- **Moderazione**: contatore segnalazioni da reporter distinti + soglia (`REPORT_COUNT_AUTO_REMOVE_THRESHOLD = 3`) che rimuove automaticamente mercatino/attività. Nessuna coda di moderazione umana per l'MVP.

## Fondazione "Località"

- `packages/core/domain/geo/models.py`: `Coordinates` (validata), `haversine_distance_km` (usata da mercatino e attività per il filtro "vicino a me"), `fuzz_coordinates`, `UserLocation` (una riga per owner, `mode: current_position|home_residence`).
- `packages/core/application/services/{set_user_location,get_user_location}.py`.
- Flutter, `apps/mobile_app/lib/features/location/`: `domain/coordinates.dart` (`Coordinates`, `LocationMode`, `LocationSource`, `UserLocationPreference`), `data/location_preference_store.dart` (cache locale via `shared_preferences`, stesso pattern di `LayoutSettingsStore`), `data/location_repository.dart` (sync con la tabella `user_locations`, stesso pattern di `RemindersRepository`), `data/device_location_service.dart` (wrapper su `geolocator` dietro l'interfaccia iniettabile `LocationSampler`, per testabilità senza GPS reale).
- Il nome definitivo del toggle "posizione attuale vs residenza" resta una scelta di copy della UI — il dominio modella solo l'enum `mode`.

## Passeggiate con il cane

`packages/core/domain/dog_walk/models.py`: `WalkSession`, `RoutePoint` (route come JSONB, stesso stile di `conversations.messages`), `estimate_steps`. Servizi: `start_walk`, `record_route_point` (distanza cumulativa via haversine, non ricalcolata da zero ad ogni punto), `end_walk`, `list_walks`.

**`evaluate_badges`** — deciso collaborativamente con l'utente (non pre-progettato, come da intento originale "idea da sviluppare"):
- Un badge "prima passeggiata" **per singolo pet**, non una volta sola sull'owner (due cani hanno progressi indipendenti).
- Soglie di distanza cumulativa per pet: 10 / 50 / 100 km (`DISTANCE_BADGE_THRESHOLDS_KM`).
- Soglie di numero di uscite per pet: 10 / 30 / 100 (`WALK_COUNT_BADGE_THRESHOLDS`).
- Nessun vincolo di specie: `StartWalkService` resta aperto a qualunque pet (non solo cani), per scelta esplicita dell'utente.

Flutter: `apps/mobile_app/lib/features/dog_walks/` — `domain/walk_session.dart`, `data/dog_walks_repository.dart`, `data/active_walk_controller.dart` (consuma uno `Stream<Coordinates>` iniettato, per testabilità senza `geolocator` reale).

## Mercatino dell'usato

`packages/core/domain/marketplace/models.py`: `MarketplaceListing`, `ListingReport`. Servizi: `create_listing` (fuzza la posizione prima di salvare — l'unico punto in cui esiste la coordinata esatta), `list_nearby_listings`, `report_listing` (soglia segnalazioni distinte).

Non-goal espliciti: nessuna coda di moderazione umana, nessuna scansione immagini, nessuna messaggistica/pagamento in-app — è una bacheca annunci, non una piattaforma transazionale.

Flutter: `apps/mobile_app/lib/features/marketplace/`.

## Attività/Eventi nei dintorni

`packages/core/domain/local_activity/models.py`: `LocalActivity` (`kind: event|service`, copre sia eventi che servizi tipo "Cerca il vet"; posizione mai fuzzata). MVP: contenuti utente + un piccolo seed hardcoded (`packages/infrastructure/persistence/demo_seed.py`, `apps/mobile_app/lib/features/local_activities/data/local_activities_repository.dart`). Nessuna fonte dati esterna integrata — decisione di prodotto futura.

Questo è esattamente ciò che aspetta il placeholder `_MapPlaceholder` in `apps/mobile_app/lib/features/local_events/presentation/pages/local_events_page.dart` (non modificato in questo lavoro).

## Schema Supabase

Estende `scripts/setup/supabase_schema.sql`: `user_locations`, `dog_walks`, `marketplace_listings` + `marketplace_listing_reports`, `local_activities`. Da notare: `marketplace_listings` e `local_activities` sono le **prime tabelle dello schema con lettura pubblica** (`select using (true)`) — tutte le precedenti sono owner-scoped. La sicurezza sta nel fuzzing lato servizio per il mercatino, non nella RLS.

## Demo harness

Rotta nascosta `AppRouter.mapsDemo = '/demo/maps'` → `apps/mobile_app/lib/app/preview/maps_demo_page.dart`: renderizza una mappa `flutter_map` reale con marker/polyline dai dati seed delle tre feature. Non collegata a nessuna nav reale. Verificabile anche via `apps/mobile_app/test/widget/maps_demo_test.dart`.
