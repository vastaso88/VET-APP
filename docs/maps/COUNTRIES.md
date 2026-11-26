# Servizi per animali: un radar per paese

Stato: codice pronto, **nessun import lanciato** (li lancia l'Orchestratore). Paesi: Italia (già in produzione), Regno Unito, Stati Uniti, Australia, Germania, Francia, Spagna.

## 1. Come funziona la copertura

Il registro dei paesi è `packages/core/domain/geo/countries.py`: codice ISO, bandiera, lingua, rettangoli geografici e regioni OpenStreetMap (codici ISO 3166-2). Un paese si aggiunge solo lì.

| Paese | Bandiera | Lingua | Regioni OSM | Formato indirizzo |
| --- | --- | --- | ---: | --- |
| Italia IT | 🇮🇹 | it | 20 regioni | `Via Roma 12, 20100 Milano` |
| Regno Unito GB | 🇬🇧 | en | 4 nazioni (England, Scotland, Wales, Northern Ireland) | `10 Downing Street, London SW1A 2AA` |
| Stati Uniti US | 🇺🇸 | en | 51 (50 stati + DC) | `12 Main St, Springfield, IL 62704` |
| Australia AU | 🇦🇺 | en | 8 (stati e territori) | `12 George St, Sydney NSW 2000` |
| Germania DE | 🇩🇪 | de | 16 Länder | `Musterstraße 12, 10115 Berlin` |
| Francia FR | 🇫🇷 | fr | 13 regioni metropolitane (Corsica inclusa, oltremare escluso) | `12 rue de la Paix, 75002 Paris` |
| Spagna ES | 🇪🇸 | es | 19 comunità/città autonome | `Calle Mayor 12, 28013 Madrid` |

**Livelli di copertura** (`packages/core/domain/coverage/country_coverage.py`), esposti dall'API in `context.coverage_level` di `GET /local-services/places` e, per tutti i paesi, da `GET /local-services/countries`:

| Livello | Quando | Cosa vede l'utente |
| --- | --- | --- |
| `complete` | import OSM del paese completo (tutte le regioni in un lancio) | nessun avviso; risposta dal nostro database |
| `partial` | importato solo Overture, o solo alcune regioni OSM | avviso "dati ancora in preparazione" con la bandiera del paese; il resto arriva dalla cache live |
| `live` | paese supportato, nulla importato | stesso avviso; solo cache live per cella (Overpass in diretta, più lenta) |
| `unsupported` | fuori dai sette paesi | avviso "il radar non copre ancora questo paese": si vede solo ciò che OSM conosce, senza altri controlli |

La tabella `radar_country_coverage` (una riga per paese) sostituisce la vecchia dichiarazione "Italia coperta" (un solo rettangolo in `data_sources`, che resta scritto per l'Italia per le versioni vecchie del backend). La riga dell'Italia viene ricavata da `data_sources` dalla migrazione SQL.

**Rettangoli grossolani.** Servono solo a scegliere il paese. Vicino ai confini un punto può cadere nel rettangolo sbagliato (Dublino è in quello del Regno Unito, Calais in quello britannico). Rete di sicurezza: se in un paese `complete` l'area cercata non ha **nessun** luogo (né OSM né Overture), si usa il percorso live come per un paese non coperto. Per l'Italia il comportamento non cambia.

L'app mostra l'avviso in `local_events_page.dart` (stringhe `localEventsCoverageLimited` / `localEventsCoverageUnsupported`, in it/en/es).

## 2. Import (sempre da lanciare a mano, mai in produzione da questa sessione)

Ordine dei passi per un paese, es. Germania:

1. Una volta: applicare le nuove parti di `scripts/setup/supabase_schema.sql` (colonna `country` su `radar_places_osm` e `radar_places_open`, tabella `radar_country_coverage`, riga dell'Italia ricavata da `data_sources`). **Prima** dell'import: gli script scrivono `country`.
2. **OpenStreetMap dall'estratto Geofabrik** (dal 26/11/2026; robots.txt e pagina d'uso di download.geofabrik.de ammettono i programmi): `uv run --system-certs --extra radar-import --with truststore python scripts/radar/import_osm_places.py --country DE --pbf-dir E:/tmp/radar_paesi/pbf --dry-run`. Scarica una volta l'estratto del paese (una richiesta registrata) in una cartella **fuori dal repository**, lo legge con pyosmium in tre passate senza indice delle posizioni (memoria sotto 2 GB per ogni paese) e conta i luoghi con la stessa mappatura delle vecchie risposte Overpass. `--delete-pbf` cancella l'estratto dopo la lettura.
3. Lo stesso senza `--dry-run` (riusa gli elementi già letti per `--cache-hours`, default 24; `--refresh` rilegge).
4. `uv run --system-certs --extra radar-import --with truststore python scripts/radar/import_overture_places.py --country DE --release <release> --list-categories` (solo lettura: controlla che nessuna categoria "pet" del paese manchi al mapping), poi `--dry-run`, poi l'import vero.
5. `GET /local-services/countries` deve dare `complete` per il paese.

Garanzie degli script:

- `--country` obbligatorio per i paesi nuovi (default IT).
- **Si sostituiscono solo le righe del paese importato** (`country`): importare la Germania non cancella l'Italia.
- **Paese completo solo con l'estratto letto per intero**: gli elementi si salvano in `.local/radar/osm_pbf/<CC>.json` con `"complete": true` solo a lettura finita, e solo un file così si importa; allora si cancellano le righe che l'import non ha visto e il paese viene dichiarato coperto. I luoghi fuori dai rettangoli del paese (oltremare francese, sconfinamenti) si scartano. Overture tiene il paese in `.local/radar/overture/` (24 h).
- **Richieste**: una alla volta, almeno 10 s tra due richieste allo stesso host, anche tra un lancio e il successivo, un `User-Agent` che nomina l'app (`QuokkaImport/1.0`, anche per DuckDB). Solo file pubblici: l'estratto Geofabrik e il file Overture su S3.
- **Registro delle richieste**: ogni richiesta a un host esterno finisce in `.local/radar/requests.log` (ora UTC, nome, indirizzo senza query, esito; per DuckDB una riga per file, metodo ed esito con il numero di richieste). Un 403 o 429 ferma l'host per sempre (`.local/radar/host_fermati.json`, codice di uscita 4): nessuna riprova, nessun altro server "per passare". `--cache-dir` sposta cache e registro (per lanciare da un worktree e tenere tutto nel checkout principale).
- overpass-api.de non si usa: il suo robots.txt lo vieta ai programmi (elenco permanente in `packages/shared/config/external_hosts.py`, valido per backend e script). Gli import non usano più nessun server Overpass.
- **Produzione**: gli script del radar si rifiutano di parlare con il progetto Supabase di produzione senza `--allow-production` (il `.env` locale punta alla produzione). Per il gemello di collaudo si impostano `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` con i suoi valori.
- DuckDB legge il file Overture con molte richieste parziali in parallelo: la pausa di 10 s non si applica dentro una query (il registro le conta).

## 3. Misure (26/11/2026)

Tutti i paesi tranne gli Stati Uniti misurati con dry run, senza scrivere: **Overture** release `2026-11-18.0` con le categorie aggiunte il 26/11 (Italia: import di ottobre, prima di quelle categorie); **OSM** dall'estratto Geofabrik del paese. I MB sono luoghi × byte per riga misurati sulle tabelle italiane (~590 byte Overture, ~1,1 KB OSM), perché un dry run non scrive. Il tempo OSM è download più lettura: dipende dalla linea (Germania: 50 minuti di download, Francia 7, per file simili). Tabella generata da `uv run python scripts/radar/estimate_countries.py` (costanti in `packages/infrastructure/radar_places/country_estimates.py`).

| Paese | Regioni OSM | Luoghi Overture | Luoghi OSM | MB Overture | MB OSM | MB totale | Tempo Overture (min) | Tempo OSM (min) | Estratto Geofabrik (MB) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: |
| 🇮🇹 IT (misurato) | 20 | 15.831 | 8.679 | 9 | 10 | 19 | 3-4 | 5 | 2.256 |
| 🇬🇧 GB (misurato) | 4 | 37.586 | 8.368 | 22 | 9 | 31 | 7 | 6 | 2.292 |
| 🇺🇸 US (stima) | 51 | 130.000 | 90.000 | 77 | 99 | 176 | 20-45 | 45-150 | ? |
| 🇦🇺 AU (misurato) | 8 | 9.697 | 3.395 | 6 | 4 | 9 | 1 | 2 | 978 |
| 🇩🇪 DE (misurato) | 16 | 21.335 | 13.467 | 13 | 15 | 27 | 8 | 54 | 4.891 |
| 🇫🇷 FR (misurato) | 13 | 14.755 | 9.691 | 9 | 11 | 19 | 10 | 12 | 5.122 |
| 🇪🇸 ES (misurato) | 19 | 12.045 | 6.915 | 7 | 8 | 15 | 18 | 3 | 1.506 |

**Lettura degli estratti** (pyosmium 4.3.2, tre passate, sotto `heavy.sh`): IT 107 s, ES 78 s, GB 124 s, DE 273 s, FR 322 s, AU 64 s; memoria massima ~1,9 GB per tutti (non cresce col file). Per l'Italia 8.679 luoghi contro gli 8.069 dell'import Overpass di ottobre: stessa mappatura, dati più recenti. Per l'Australia la stessa lettura con l'indice delle posizioni in memoria dava gli stessi 3.395 luoghi con 3,4 GB, e con l'indice su disco ci metteva 32 minuti: per questo l'indice è stato tolto.

Righe Overture grezze (categorie pet, prima dei filtri, con le categorie aggiunte il 26/11): DE 53.687, FR 35.278, ES 21.853, GB 67.040, AU 15.034. Il tempo Overture dipende soprattutto dalla linea (ES 18 min contro GB 7 min, con meno dati): letture con 4 thread, timeout 120 s, nessuna riprova.

**Categorie Overture aggiunte il 26/11/2026** (dopo `--list-categories`, release `2026-11-18.0`): `dog_park` → aree cani (GB 1.127, AU 849, DE 287, ES 169, FR 79: i doppioni con le aree OSM si uniscono), `pet_hospice` → veterinari (GB 61), `animal_or_pet_service` (DE 2.418, FR 2.147, ES 1.540, GB 7.880, AU 1.866) e `pet_care_service` (DE 400, GB 383, FR 53, ES 33) → pet sitter, salvo un nome che dichiara un solo altro mestiere (toelettatura, negozio, pensione, addestramento, allevamento, rifugio), che vince; mai promossi a veterinario dal solo nome. **Restano fuori** perché nessun tipo del radar li descrive senza ingannare: cimiteri e crematori per animali, cure olistiche, fisioterapia, trasporto, foto, assicurazioni, caffè con animali; le categorie cavallo (`horse_*`) per la decisione del proprietario del 25/11. `carpet_*`, `hot_dog_restaurant`, `veterans_*` sono falsi positivi della ricerca per nome. Conteggi misurati con un nuovo download (`--refresh`, dry run, 26/11):

| Paese | Luoghi prima | Luoghi con le nuove categorie | In più | di cui aree cani |
| --- | ---: | ---: | ---: | ---: |
| DE | 19.558 | 21.335 | +1.777 | 95 |
| FR | 13.509 | 14.755 | +1.246 | 35 |
| ES | 11.042 | 12.045 | +1.003 | 59 |
| GB | 31.763 | 37.586 | +5.823 | 811 |
| AU | 8.314 | 9.697 | +1.383 | 540 |

Come leggerla:

- **Spazio**: **tutti e sette i paesi ~297 MB su 500 MB del piano free di Supabase**; Italia e i cinque paesi senza gli USA ~120 MB (misurati), che si aggiungono a tutto il resto dell'app (pet, chat, foto sono nello storage, ma le tabelle contano). Gli Stati Uniti (stima) sono 176 MB da soli: da decidere il piano prima degli USA.
- **Disco e rete per OSM**: gli estratti dei sei paesi sono ~17 GB da scaricare (uno alla volta, cancellati dopo la lettura); nessun server condiviso interrogato a ogni regione.
- **Costo**: dati gratuiti (OSM, Overture); costa solo lo spazio Supabase (sopra) e il tempo del PC. Rinfresco: OSM mensile (Italia nel workflow mensile, §2); Overture a ogni release.

**Ordine consigliato**: con i dati misurati l'ordine segue le lingue pronte, non la tecnica: tutti i cinque paesi stanno insieme in ~100 MB. Gli 🇺🇸 Stati Uniti restano per ultimi, dopo aver deciso il piano Supabase.

## 4. Licenze e attribuzione (verificate il 2026-10-14)

- **OpenStreetMap**: ODbL 1.0. Attribuzione "© OpenStreetMap contributors" con link a https://www.openstreetmap.org/copyright. Vale per ogni paese. Le tabelle OSM restano separate da quelle Overture (condivisione allo stesso modo); l'unione avviene in memoria, per richiesta; l'API non ha mai un'esportazione in blocco (il risultato è un'"opera prodotta"). Nulla cambia con i nuovi paesi.
- **Overture Places**: **non** una licenza unica. Per sorgente, secondo la pagina di attribuzione di Overture (https://docs.overturemaps.org/attribution/): CDLA-Permissive-2.0 (Meta, Microsoft e altri), Apache-2.0 (Foursquare, con avviso di copyright da conservare, vedi il NOTICE linkato lì), CC0-1.0 (AllThePlaces). Il manifest `docs/licenses/overture_places_release.md` (Italia) e `overture_places_release_<CC>.md` (gli altri paesi) elencano le licenze dei record realmente importati. Testo CDLA in `docs/licenses/CDLA-Permissive-2.0.txt`. Per Apache-2.0 manca ancora il testo in `docs/licenses/` e l'avviso Foursquare: vedi §7.
- **Dove compare l'attribuzione nell'app**: pagina "Fonti dati" (`data_sources_page.dart`, catalogo fisso in `radar_data_source.dart`, visibile anche offline), riga della fonte nella scheda del luogo (`radar_place_sheet.dart`), attribuzione "OpenStreetMap contributors" sotto ogni mappa (`radar_map.dart`, `report_missing_place_page.dart`, `location_picker_page.dart`). Uguale per tutti i paesi.
- **Nominatim** (indirizzi): policy https://operations.osmfoundation.org/policies/nominatim/: massimo 1 richiesta al secondo, User-Agent che identifica l'app, niente autocompletamento, nessun geocoding in blocco. L'app geocodifica **un solo indirizzo quando la persona conferma il modulo** (e un reverse per la posizione scelta sulla mappa): resta ben sotto. Il parametro `countrycodes` limita la ricerca al paese scritto (e a un solo paese, così "Via Roma" non finisce altrove). Se in futuro si geocodificasse in blocco o a ogni tasto, serve un provider a pagamento o un'istanza propria.

## 5. Indirizzi, categorie, Segnala!

- **Formato indirizzo**: una sola funzione per lato. Backend `format_address` (`packages/core/domain/geo/address_format.py`, usata dai luoghi OSM); app `formatAddress` (`lib/features/location/domain/address_format.dart`, usata dal geocoder e dal reverse geocoder). Stessi casi di prova nei due test. Lo stato USA/Australia è il codice a 2-3 lettere (da `ISO3166-2-lvl4` di Nominatim, es. `US-IL` → `IL`); un nome esteso ("Illinois") si mostra com'è. Paese sconosciuto: ordine europeo (via numero, CAP città).
- **Categorie**: i selettori OSM sono già indipendenti dal paese (`amenity=veterinary`, `shop=pet`, `shop=pet_grooming`, `amenity=animal_boarding|animal_training|animal_breeding|animal_shelter`, `office=pet_sitting`, `craft=dog_walker`, `leisure=dog_park`); Overture usa la tabella `OVERTURE_CATEGORIES` (veterinari, pronto soccorso `emergency_pet_hospital` e `animal_hospital` → veterinari). Le correzioni di una categoria Overture sbagliata dal nome (toelettatura/allevamento/negozio/pensione/rifugio archiviati come veterinario) ora capiscono IT, EN, DE, FR, ES (`packages/core/domain/radar_places/labels.py`); il verso opposto resta volutamente prudente. L'OSM `emergency=yes` è salvato tra i dettagli del luogo. Il nome generico di un luogo senza nome è nella lingua del paese (inglese fuori dai sette).
- **Deduplica tra fonti**: parole generiche del mestiere e prefissi telefonici internazionali dei sei paesi aggiunti (senza, due cliniche "City Veterinary Clinic" e "Park Veterinary Clinic" vicine sarebbero state unite).
- **Segnala! e voti**: nessuna dipendenza dall'Italia. Le segnalazioni e le stelle si basano su posizione e id del luogo, non sul paese; il filtro parolacce vale in IT/EN/DE/FR/ES, accetta lettere accentate di ogni lingua e riconosce i suffissi di siti .uk/.de/.fr/.es/.eu/.au; un'area cani segnalata senza nome prende il nome generico del paese. I messaggi d'errore del backend sono ancora in italiano e si traducono nell'app (`localized_backend_message`).

## 6. Da verificare al primo lancio (non posso farlo da qui: niente rete nei test)

- Le regioni OSM (`ISO3166-2`) non servono più all'import: si legge l'estratto del paese intero; restano nel registro per la riga di copertura (`osm_regions`).
- Le categorie Overture dei paesi nuovi sono state controllate il 26/11 con `--list-categories` (§3); per gli USA va rifatto.

## 7. Difetti noti e decisioni per il proprietario

1. **Spazio Supabase**: ~297 MB di dati radar per i sette paesi su 500 MB del piano free (sei paesi misurati il 26/11, USA stimati; senza gli USA ~120 MB). Decidere il piano prima degli USA.
2. **Apache-2.0 (Foursquare) in Overture**: serve conservare l'avviso di copyright; oggi mostriamo solo "© Overture Maps Foundation — Places". Da far valutare alla sessione legale; il testo Apache-2.0 va aggiunto in `docs/licenses/`.
3. **Import "tutto o niente" per paese**: un paese diventa `complete` solo quando il suo estratto è stato letto per intero. Per gli USA l'estratto Geofabrik è uno per stato: va deciso come unirli prima di importarli.
4. **Rettangoli ai confini**: vedi §1; si risolve con la rete di sicurezza ma l'avviso di copertura può essere sbagliato di pochi chilometri.
5. **Rinfresco OSM**: il workflow mensile rinfresca solo l'Italia (estratto Geofabrik); gli altri cinque paesi si rinfrescano a mano.
6. **Nomi mostrati**: i luoghi senza nome in OSM restano col nome generico salvato nel database (nella lingua del paese), non tradotto nella lingua dell'app.
7. **Tile delle mappe**: la mappa usa i tile pubblici di OSM (avviso di flutter_map nei test): con più paesi e più utenti va rivista la policy dei tile (https://operations.osmfoundation.org/policies/tiles); non toccata qui.
8. **Domande**: l'ordine di import (§3) va bene o segue le lingue pronte? Piano Supabase Pro sì/no? Il Regno Unito include l'Irlanda del Nord (sì, come `GB-NIR`)? Territori d'oltremare francesi (esclusi) e Porto Rico/altri territori USA (esclusi)?
