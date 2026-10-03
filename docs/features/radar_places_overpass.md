# Radar luoghi: servizi per animali da OpenStreetMap

Sezione "Servizi per animali" della pagina "Eventi nei dintorni": veterinari, toelettature, negozi, addestratori, pet sitter, allevamenti e pensioni attorno all'utente, presi da OpenStreetMap tramite Overpass.

Origine: il motore di ricerca (`overpass_places_source.py`) è stato scritto da Roberto sul branch `roberto`. Il resto (cache per zona, API, schermata) è stato costruito su `Francesco` il 2026-10-03 per unificare il lavoro su `main`.

## Flusso

1. L'app chiama `GET /local-services/places?latitude=..&longitude=..&radius_km=..` con il token dell'utente. La posizione è quella della Località (`resolveReferenceLocation`).
2. Il backend aggancia la posizione a una cella di una griglia fissa (0,05°, circa 5,5 × 3,9 km).
3. Se la cella è già stata importata ed è ancora valida, risponde dalla cache in Supabase.
4. Altrimenti interroga Overpass attorno al **centro della cella**, salva i luoghi e segna la cella valida per `RADAR_FRESHNESS_TTL_HOURS`.
5. Filtra per distanza dalla posizione reale dell'utente, ordina e restituisce.

Conseguenze di questo disegno:

- La cache è **condivisa per zona**, non per utente: il secondo utente nella stessa cella non genera chiamate a Overpass.
- Overpass non riceve mai la posizione esatta di un utente, solo il centro della cella.
- Se l'aggiornamento di una cella scaduta fallisce, vengono serviti i dati vecchi (`coverage.status = "stale"`). Senza nessun dato in cache la route risponde con errore del provider.

## Raggi

| Impostazione | Default | Significato |
| --- | --- | --- |
| `RADAR_SEARCH_RADIUS_KM` | 10 | Raggio massimo servito all'app |
| `RADAR_INGESTION_RADIUS_KM` | 15 | Raggio importato attorno al centro della cella |
| `OVERPASS_MAX_RADIUS_KM` | 15 | Tetto per una singola richiesta a Overpass |

Il raggio di import deve superare quello di ricerca di almeno 3,5 km (distanza massima tra un utente e il centro della sua cella), altrimenti il bordo del raggio di ricerca resta scoperto.

L'app offre anche 25 e 50 km per gli eventi: per i servizi mostra la nota "disponibili entro 10 km".

## Server Overpass

I server pubblici sono gratuiti e condivisi, e rispondono spesso 429/504 sotto carico. Il backend prova in ordine `OVERPASS_BASE_URL` e poi `OVERPASS_FALLBACK_URLS`, entro un tempo totale di 40 secondi.

`OVERPASS_USER_AGENT` in produzione va impostato a un valore che identifichi l'app e un contatto, come richiesto dalla policy d'uso di Overpass.

Con molti utenti i server pubblici non bastano: le alternative sono un'istanza Overpass propria o un estratto OSM importato periodicamente.

## Categorie importate

| Tag OSM | Tipo VET APP |
| --- | --- |
| `amenity=veterinary` | `veterinary` |
| `shop=pet_grooming` | `grooming` |
| `shop=pet` | `shop` |
| `amenity=animal_training` | `school` |
| `office=pet_sitting`, `craft=dog_walker` | `pet_sitting` |
| `amenity=animal_breeding` | `breeder` |
| `amenity=animal_boarding` | `hotel` |

## Dati

Tabelle in `scripts/setup/supabase_schema.sql`: `radar_coverage_cells` (una riga per cella importata) e `radar_places_cache` (i luoghi). RLS attiva senza policy: le legge e scrive solo il backend con la service-role key.

I dati sono © OpenStreetMap contributors (licenza ODbL): l'attribuzione è mostrata sulla mappa e nella scheda del luogo e non va rimossa.

## Codice

- Dominio: `packages/core/domain/radar_places`, `packages/core/domain/coverage`
- Servizi: `list_nearby_radar_places.py`, `request_radar_places_ingestion.py`
- Sorgente: `packages/infrastructure/radar_places/overpass_places_source.py`
- Route: `apps/api/routes/local_services.py`
- Flutter: `apps/mobile_app/lib/features/nearby_places/`, integrato in `features/local_events/presentation/pages/local_events_page.dart`

## Non portato dal branch `roberto`

- Provider Google Places, registry e orchestrator: dipendevano da file mai arrivati nel repository.
- `/local-services/events` e `/local-services/venues`: eventi e strutture restano su `local_activities`.
- Il pulsante "anteprima sviluppo" del login: conteneva credenziali demo nel codice.
- `supabase_security_hardening.sql`: riguarda tabelle e funzioni `billing_*` e `ai.*` che non fanno parte dello schema di questo repository.
