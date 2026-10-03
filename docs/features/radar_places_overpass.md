# Radar nei dintorni

Pagina unica (`LocalEventsPage`, titolo "Radar nei dintorni") che riunisce tutto ciò che riguarda gli animali attorno alla Località dell'utente: eventi, servizi e cliniche.

Origine: il motore di ricerca su OpenStreetMap (`overpass_places_source.py`) è stato scritto da Roberto sul branch `roberto`. Cache per zona, API e schermata sono stati costruiti su `Francesco` il 2026-10-03. Parere legale: `docs/compliance/06_radar_mappe_sponsorizzazioni.md`.

## Fonti dei dati

| Sezione | Fonte | Note |
| --- | --- | --- |
| In programma | tabella `local_activities` (righe con `starts_at`) | eventi nel raggio più gli eventi nazionali |
| Servizi nella zona | OpenStreetMap (tutte le categorie tranne i veterinari) + `local_activities` senza data | |
| Cliniche e ambulatori | OpenStreetMap `amenity=veterinary` + `local_activities` senza data con categoria che contiene "ambulator", "veterin" o "clinic" | pensata per le urgenze |

## Controlli della pagina

- **Raggio** (5, 10, 25, 50 km): comanda sia la mappa sia la ricerca sul backend. Ogni raggio fa una richiesta, tenuta in memoria finché la pagina è aperta.
- **Filtri rapidi** per categoria (Veterinari, Negozi, Aree cani, Eventi, Toelettature, Pensioni) e pulsante **Filtri** con distanza, categorie (multi) e specie (multi). Categorie e specie filtrano i dati già caricati, senza nuove richieste.
- **Specie**: nasconde i luoghi dedicati esplicitamente ad altre specie. Un luogo che non dichiara specie resta sempre visibile. Le specie arrivano dai tag OSM `animal_boarding`, `animal_breeding`, `animal_training`, `pets`; le aree cani valgono "cane". Gli eventi non hanno questo dato e non vengono mai nascosti.
- **Categorie**: etichetta, icona e colore di ogni categoria sono definiti una sola volta in `radar_category.dart` e usati da liste, marker, filtri e legenda.
- **Mappa**: anteprima con cerchio del raggio e legenda; il pulsante in alto a destra apre la mappa a tutto schermo.

## Eventi nazionali

Un evento compare sempre, qualunque sia il raggio, se la sua `category` contiene la parola `nazionale` (ad esempio `fiera nazionale`). È una convenzione sul campo testuale esistente: non richiede colonne nuove.

### Inserire eventi

La tabella `local_activities` sul database nuovo è vuota. Gli eventi si inseriscono dall'editor SQL di Supabase con questo modello, dopo aver verificato date e luogo sul sito ufficiale dell'organizzatore:

```sql
insert into public.local_activities
    (id, kind, title, description, category, latitude, longitude, address_label, starts_at, ends_at, source)
values
    ('fiera-<slug>-<anno>', 'event', '<Nome della fiera>', '<descrizione breve, con il sito ufficiale>',
     'fiera nazionale', <lat>, <lon>, '<Quartiere fieristico, Città>',
     '<AAAA-MM-GG>T09:00:00+02:00', '<AAAA-MM-GG>T19:00:00+02:00', 'seeded')
on conflict (id) do nothing;
```

Per un evento locale basta una `category` senza "nazionale" (ad esempio `fiera`, `vaccinazioni`, `adozioni`).

Non sono stati inseriti eventi reali: le date trovate in rete per le fiere 2026-2027 non erano verificabili con certezza, e un evento con data sbagliata è peggio di una sezione vuota. Candidati da verificare: Quattrozampeinfiera (più città), Petsfestival (Cremona), esposizioni ENCI. Fonte stabile da valutare in seguito: un feed curato a mano dal team, oppure le segnalazioni degli utenti già previste dal dominio (`source = 'user_submitted'`).

## Backend

`GET /local-services/places?latitude=..&longitude=..&radius_km=..[&place_type=..][&per_type_limit=..]`, con il token dell'utente.

1. Il raggio richiesto sceglie un gradino della scala in `packages/core/domain/coverage/models.py`.
2. La posizione viene agganciata a una cella della griglia di quel gradino.
3. Se la cella è in cache ed è valida, la risposta arriva da Supabase.
4. Altrimenti il backend interroga Overpass attorno al **centro della cella**, salva i luoghi e segna la cella valida per `RADAR_FRESHNESS_TTL_HOURS` (7 giorni).
5. I luoghi vengono filtrati per distanza dalla posizione reale, ordinati, e limitati a `per_type_limit` per categoria (default 40).

| Raggio servito | Cella | Raggio importato (circa) | Tempo del primo import (Milano) |
| --- | --- | --- | --- |
| fino a 10 km | 0,05° | 14 km | 3-13 s |
| fino a 25 km | 0,10° | 32 km | circa 10 s |
| fino a 50 km | 0,20° | 64 km | circa 20 s |

Il raggio importato è calcolato: raggio servito più la distanza massima tra un punto della cella e il suo centro, che dipende dalla latitudine.

Scelte e conseguenze:

- La cache è **condivisa per zona**, non per utente. Raggi ampi usano celle più grandi, quindi meno import distinti.
- Overpass riceve solo il centro della cella, mai la posizione di un utente. Il backend riceve la posizione esatta per ordinare per distanza reale, ma non la salva: in cache finisce solo la chiave della cella.
- Il limite per categoria evita che le categorie abbondanti (aree cani) facciano sparire quelle scarse (cliniche).
- Se l'aggiornamento di una cella scaduta fallisce, vengono serviti i dati precedenti con `coverage.status = "stale"` e l'app lo dice all'utente.
- Non esiste e non va aggiunto un endpoint di export o elenco completo della cache (vedi "Licenza").
- La chiave della cella contiene una versione (`radar:v2:...`): cambiare la forma dei dati in cache richiede solo di alzarla.

### Server Overpass

I server pubblici sono gratuiti e condivisi. Comportamento osservato il 2026-10-03:

- `overpass-api.de` concede 2 richieste contemporanee per indirizzo IP e risponde 429 per alcune decine di secondi dopo richieste pesanti. Il backend aspetta e riprova sullo stesso server (6, 14, 22 secondi) prima di passare ai server di riserva.
- I server di riserva (`OVERPASS_FALLBACK_URLS`) non hanno risposto dalla rete di sviluppo. Il mirror `maps.mail.ru` è stato rimosso.
- Tempo totale massimo per un import: 60 secondi. L'app aspetta fino a 75.

Su Vercel l'indirizzo IP è condiviso con altri clienti, quindi i 429 possono essere più frequenti che in sviluppo. Prima di un lancio pubblico serve un'istanza Overpass propria o un estratto OSM importato periodicamente.

`OVERPASS_USER_AGENT` identifica l'app con il suo indirizzo web. In produzione va impostato con un contatto tecnico reale, come chiede la policy d'uso di Overpass.

### Categorie importate

| Tag OSM | Tipo | Categoria in app |
| --- | --- | --- |
| `amenity=veterinary` | `veterinary` | Veterinari |
| `shop=pet` | `shop` | Negozi |
| `leisure=dog_park` | `dog_park` | Aree cani (nome predefinito "Area cani" se manca) |
| `shop=pet_grooming` | `grooming` | Toelettature |
| `amenity=animal_boarding` | `hotel` | Pensioni |
| `amenity=animal_training` | `school` | Addestramento |
| `office=pet_sitting`, `craft=dog_walker` | `pet_sitting` | Pet sitter |
| `amenity=animal_breeding` | `breeder` | Allevamenti |

### Dati

Tabelle in `scripts/setup/supabase_schema.sql`: `radar_coverage_cells` (una riga per cella importata) e `radar_places_cache` (i luoghi, con `opening_hours` e `species`). RLS attiva senza policy: le legge e scrive solo il backend con la service-role key.

## Urgenze: cosa la pagina non fa

- Non calcola "aperto adesso" e non offre un filtro "urgenze" o "24 ore": gli orari OSM non sono verificati. Vengono mostrati come dichiarati ("Orari indicati: ...").
- L'ordine è sempre per distanza. Non deve mai dipendere da un pagamento.
- Sopra l'elenco delle cliniche e nella scheda di ogni clinica c'è l'avviso di telefonare prima di partire.

## Sponsorizzazioni di "Cliniche e ambulatori": valutazione

Ipotesi del proprietario: rendere la sezione indicizzabile o sponsorizzabile. **Non è implementato.** Questa è la valutazione tecnica; quella legale è in `docs/compliance/06_radar_mappe_sponsorizzazioni.md`. Decidere se consentire contenuti a pagamento spetta al proprietario.

### Licenza dei dati OpenStreetMap (ODbL)

- **Attribuzione**: "© OpenStreetMap contributors" deve restare visibile su ogni vista che mostra dati OSM (mappa, scheda del luogo, eventuali export).
- **Share-alike**: chi distribuisce un database derivato da OSM deve rilasciarlo con la stessa licenza. Mostrare risultati limitati e filtrati dentro l'app è un "produced work" e non fa scattare l'obbligo; un endpoint di export o una copia scaricabile della cache sì. Per questo la route serve solo risultati limitati per distanza e categoria.
- **Dati propri separati**: i contenuti scritti dal team o da un inserzionista (descrizione, foto, orari verificati, offerta) non diventano ODbL se restano in tabelle proprie e vengono solo accostati al luogo OSM al momento della lettura. Se venissero scritti dentro `radar_places_cache`, la distinzione si perderebbe.

### Separazione tecnica consigliata

- Tabella propria, ad esempio `sponsor_listings`: `id`, `osm_source_external_id` (ad esempio `node/123`), contenuti dell'inserzionista, `valid_from`, `valid_until`, stato di verifica.
- Composizione al momento della richiesta: il backend legge i luoghi dalla cache e vi affianca le schede sponsorizzate con lo stesso identificativo OSM. Nessuna scrittura verso `radar_places_cache` né verso OpenStreetMap.
- Etichetta **"Sponsorizzato"** sempre visibile su riga, marker e scheda, distinta dall'attribuzione OSM.
- Le schede sponsorizzate vanno in un riquadro separato dall'elenco per distanza, che resta invariato. In un contesto di urgenza un ordinamento a pagamento sarebbe scorretto verso l'utente e rischioso per chi lo propone.
- "Indicizzabile" (pagine pubbliche per i motori di ricerca) è un secondo tema: pagine pubbliche generate dai soli dati OSM somigliano alla ridistribuzione di un database derivato. Sono sostenibili solo le pagine dei luoghi con contenuto proprio, verificato con il titolare.

### Policy d'uso dei servizi

- **Overpass**: vietato l'uso intensivo dei server pubblici; un servizio commerciale con sponsor deve avere un'istanza propria.
- **Tile**: `tile.openstreetmap.org` è usato direttamente dalla mappa del radar e da quella delle passeggiate. La policy non ne permette l'uso da app commerciali con traffico significativo: prima del lancio pubblico serve un fornitore di tile a pagamento o un server proprio.

## Codice

- Dominio: `packages/core/domain/radar_places`, `packages/core/domain/coverage`
- Servizi: `list_nearby_radar_places.py`, `request_radar_places_ingestion.py`
- Sorgente: `packages/infrastructure/radar_places/overpass_places_source.py`
- Route: `apps/api/routes/local_services.py`
- Flutter: `apps/mobile_app/lib/features/nearby_places/` (dominio, repository, categorie, mappa, filtri, scheda) e `features/local_events/presentation/pages/local_events_page.dart`

## Non portato dal branch `roberto`

- Provider Google Places, registry e orchestrator: dipendevano da file mai arrivati nel repository.
- `/local-services/events` e `/local-services/venues`: eventi e strutture restano su `local_activities`.
- Il pulsante "anteprima sviluppo" del login: conteneva credenziali demo nel codice.
- `supabase_security_hardening.sql`: riguarda tabelle e funzioni `billing_*` e `ai.*` che non fanno parte dello schema di questo repository.
