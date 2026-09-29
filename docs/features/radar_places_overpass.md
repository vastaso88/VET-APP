# Radar places: OpenStreetMap / Overpass

The radar places engine can use OpenStreetMap through an Overpass API interpreter as a low-cost
source for nearby pet services. The source plugs into the existing Supabase-backed coverage and
ingestion job flow, so the app does not query Overpass on every map opening.

## Runtime provider

Set:

```text
RADAR_PLACES_PROVIDER=openstreetmap_overpass
RADAR_SEARCH_RADIUS_KM=10
RADAR_INGESTION_RADIUS_KM=10
RADAR_FRESHNESS_TTL_HOURS=168
OVERPASS_BASE_URL=https://overpass-api.de/api/interpreter
OVERPASS_TIMEOUT_SECONDS=25
OVERPASS_MAX_RADIUS_KM=10
OVERPASS_USER_AGENT=VET-APP/1.0
```

`OVERPASS_USER_AGENT` should be changed in production to a value that identifies the deployed
application and, where appropriate, a project contact.

Google Places remains available by setting `RADAR_PLACES_PROVIDER=google_places`. Google-backed
runtime coverage is still limited to 1 km per ingestion request by the current provider contract.

## Cache and refresh behaviour

The existing radar coverage tables in Supabase remain the cache boundary:

1. `/local-services/places` resolves the geographic coverage key.
2. Fresh coverage is served from Supabase without calling the external provider.
3. Empty or stale coverage creates an ingestion job.
4. The Overpass source runs only for that refresh job and persists normalized places in
   `radar_places`.
5. Coverage is marked fresh for `RADAR_FRESHNESS_TTL_HOURS`; the default Overpass configuration
   uses seven days.
6. The protected `/local-services/places/refresh` endpoint can force a refresh when required.

This keeps external traffic bounded while preserving the current API and Flutter map contract.

## OSM categories currently imported

The first implementation maps these OpenStreetMap tags to VET APP radar types:

| OSM tag | VET APP type |
| --- | --- |
| `amenity=veterinary` | `veterinary` |
| `shop=pet_grooming` | `grooming` |
| `shop=pet` | `shop` |
| `amenity=animal_training` | `school` |
| `office=pet_sitting` | `pet_sitting` |
| `craft=dog_walker` | `pet_sitting` |
| `amenity=animal_breeding` | `breeder` |
| `amenity=animal_boarding` | `hotel` |

The mapper keeps the raw OSM element in `source_payload`, stores the OSM object URL as
`source_url`, and reads address, website, phone and opening-hours metadata when those tags are
available.

## Current scope

Coverage still uses the repository's existing radius-based, owner-scoped cache model. This is a
safe first vertical implementation because it does not require a database migration and it keeps
current RLS rules intact. A later scalability step can move the cache to shared geographic cells
(e.g. H3) so users in the same area reuse the same imported records instead of maintaining
owner-specific copies.
