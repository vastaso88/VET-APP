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
2. `uv run --system-certs --with truststore python scripts/radar/import_osm_places.py --country DE --dry-run` e controllare i conteggi per regione (un'area con 0 elementi viene rifiutata: il codice area potrebbe essere sbagliato; vedi §6).
3. Lo stesso senza `--dry-run`. Se si ferma per il limite di tempo (codice di uscita 3) o per un server occupato, rilanciare lo stesso comando: le regioni già scaricate non vengono richieste di nuovo.
4. `uv run --system-certs --with duckdb --with truststore python scripts/radar/import_overture_places.py --country DE --list-categories` (solo lettura: controlla che nessuna categoria "pet" del paese manchi al mapping), poi `--dry-run`, poi l'import vero.
5. `GET /local-services/countries` deve dare `complete` per il paese.

Garanzie degli script:

- `--country` obbligatorio per i paesi nuovi (default IT: i comandi di prima funzionano come prima).
- **Si sostituiscono solo le righe del paese importato** (`country`): importare la Germania non cancella l'Italia. Cancellare "ciò che il lancio non ha visto" avviene solo a import completo.
- **Riprendibili**: OSM tiene ogni regione in `.local/radar/osm/` (24 h, `--cache-hours` per paesi lunghi come gli USA); Overture tiene il paese in `.local/radar/overture/` (stessa durata). Niente si scrive su Supabase finché tutte le regioni sono presenti.
- **Limiti di rate**: una richiesta alla volta, `--pause-seconds` (5 s) tra le regioni, attesa dello stato del server principale Overpass, due mirror come riserva, un `User-Agent` che nomina l'app, `--max-seconds` per fermarsi in modo pulito. Nessuno scraping di siti: solo Overpass (OSM) e il file pubblico Overture su S3.
- Import parziale (`--regions ...`): scrive le righe, aggiorna `osm_regions`, ma **non** dichiara il paese coperto.

## 3. Stime prima di importare

Calibrate sull'Italia, unico paese misurato (8.069 luoghi OSM, 15.831 Overture dopo i filtri, ~9 MB per fonte, 20 regioni OSM in 10-15 minuti, Overture in 3 min 11 s). Le altre cifre sono **stime** (±50%): il primo `--dry-run` di ogni paese le sostituisce con una misura. Tabella generata da `uv run python scripts/radar/estimate_countries.py` (costanti in `packages/infrastructure/radar_places/country_estimates.py`).

| Paese | Regioni OSM | Luoghi Overture | Luoghi OSM | MB Overture | MB OSM | MB totale | Tempo Overture (min) | Tempo OSM (min) | Richieste Overpass (min-max) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| 🇮🇹 IT (misurato) | 20 | 15.831 | 8.069 | 9 | 9 | 18 | 3-4 | 10-15 | 20-220 |
| 🇬🇧 GB | 4 | 28.000 | 22.000 | 17 | 24 | 41 | 2-4 | 10-30 | 4-44 |
| 🇺🇸 US | 51 | 130.000 | 90.000 | 77 | 99 | 176 | 20-45 | 45-150 | 51-561 |
| 🇦🇺 AU | 8 | 11.000 | 12.000 | 6 | 13 | 20 | 6-12 | 8-20 | 8-88 |
| 🇩🇪 DE | 16 | 30.000 | 38.000 | 18 | 42 | 60 | 2-4 | 12-20 | 16-176 |
| 🇫🇷 FR | 13 | 26.000 | 22.000 | 15 | 24 | 40 | 3-5 | 10-18 | 13-143 |
| 🇪🇸 ES | 19 | 20.000 | 12.000 | 12 | 13 | 25 | 3-5 | 12-20 | 19-209 |

Come leggerla:

- **Spazio**: ~590 byte per riga Overture e ~1,1 KB per riga OSM (tabella più indice di posizione, dall'Italia). **Tutti e sette i paesi: ~378 MB su 500 MB del piano free di Supabase**, che contiene già tutto il resto dell'app (pet, chat, foto sono nello storage, ma le tabelle contano). Gli Stati Uniti da soli sono 176 MB. Con tutti i paesi serve probabilmente il piano Pro (25 USD/mese): da decidere prima degli USA.
- **Tempo**: l'Overture scala con l'area letta (USA: tre rettangoli, il più lento); OSM con il numero di regioni (~36 s a regione, con pausa) più i ritiri quando Overpass rifiuta una regione intera e la richiede una categoria alla volta (fino a 11 richieste per regione: colonna "max").
- **Richieste**: solo Overpass conta. Il massimo è teorico; la policy pubblica ammette ben più di 561 richieste al giorno, ma sono su server condivisi: meglio un paese per volta, mai in parallelo con un altro import.
- **Costo**: dati gratuiti (OSM, Overture); costa solo lo spazio Supabase (sopra) e il tempo del PC. Rinfresco: OSM mensile come per l'Italia; Overture a ogni release (trimestrale).

**Ordine consigliato** (più semplice e utile prima):

1. 🇩🇪 Germania: OSM molto ricco, poche richieste, 60 MB.
2. 🇫🇷 Francia: 40 MB, regioni leggere.
3. 🇪🇸 Spagna: 25 MB.
4. 🇬🇧 Regno Unito: 41 MB; l'Inghilterra intera può essere rifiutata da Overpass e va per categoria (previsto, più lento).
5. 🇦🇺 Australia: 20 MB; regioni vaste e poco dense, ma leggere.
6. 🇺🇸 Stati Uniti per ultimi: 176 MB, 51 regioni (usare `--cache-hours 168 --max-seconds 3000` e rilanciare), e solo dopo aver deciso il piano Supabase.

Se il lancio in lingua inglese è prima di quello in tedesco, Regno Unito e Australia passano in testa: l'ordine segue le lingue pronte, non la tecnica.

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

- I codici area `ISO3166-2` delle quattro nazioni britanniche (`GB-ENG`, `GB-SCT`, `GB-WLS`, `GB-NIR`) e dei territori australiani/stati USA nel tag OSM: l'import rifiuta una regione con 0 elementi proprio per scoprire un codice sbagliato; se capita su una regione davvero vuota (Ceuta, Melilla, DC) rilanciare con `--allow-empty`.
- I nomi delle categorie Overture dei paesi nuovi: `--list-categories` li elenca; aggiungere a `OVERTURE_CATEGORIES` ciò che manca (es. tassonomia britannica/statunitense diversa).

## 7. Difetti noti e decisioni per il proprietario

1. **Spazio Supabase**: ~378 MB di dati radar per i sette paesi su 500 MB del piano free. Decidere il piano prima degli USA.
2. **Apache-2.0 (Foursquare) in Overture**: serve conservare l'avviso di copyright; oggi mostriamo solo "© Overture Maps Foundation — Places". Da far valutare alla sessione legale; il testo Apache-2.0 va aggiunto in `docs/licenses/`.
3. **Import "tutto o niente" per paese**: un paese diventa `complete` solo quando tutte le sue regioni sono state scaricate in un lancio; per gli USA (51 stati) la cache va tenuta più a lungo (`--cache-hours`). Non esiste una copertura per singolo stato.
4. **Rettangoli ai confini**: vedi §1; si risolve con la rete di sicurezza ma l'avviso di copertura può essere sbagliato di pochi chilometri.
5. **Sei paesi con un solo import OSM ciascuno**: l'aggiornamento mensile è manuale, come per l'Italia.
6. **Nomi mostrati**: i luoghi senza nome in OSM restano col nome generico salvato nel database (nella lingua del paese), non tradotto nella lingua dell'app.
7. **Tile delle mappe**: la mappa usa i tile pubblici di OSM (avviso di flutter_map nei test): con più paesi e più utenti va rivista la policy dei tile (https://operations.osmfoundation.org/policies/tiles); non toccata qui.
8. **Domande**: l'ordine di import (§3) va bene o segue le lingue pronte? Piano Supabase Pro sì/no? Il Regno Unito include l'Irlanda del Nord (sì, come `GB-NIR`)? Territori d'oltremare francesi (esclusi) e Porto Rico/altri territori USA (esclusi)?
