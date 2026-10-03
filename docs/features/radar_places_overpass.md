# Radar nei dintorni

Pagina unica (`LocalEventsPage`, titolo "Radar nei dintorni") che riunisce tutto ciò che riguarda gli animali attorno alla Località dell'utente: eventi, servizi e cliniche.

Origine: il motore di ricerca su OpenStreetMap (`overpass_places_source.py`) è stato scritto da Roberto sul branch `roberto`. Cache per zona, API e schermata sono stati costruiti su `Francesco` il 2026-10-03. Parere legale: `docs/compliance/06_radar_mappe_sponsorizzazioni.md`.

## Posizione

Al primo ingresso senza nessuna posizione nota, la pagina mostra una spiegazione ("VetApp usa la posizione del telefono solo mentre usi l'app") con due scelte: **Consenti**, che fa comparire la richiesta di sistema, salva la modalità "posizione attuale" e centra subito; **Scegli un indirizzo**, che apre le Impostazioni. Chi ha già una posizione salvata non rivede la spiegazione.

La pagina è centrata sulla Località scelta in Impostazioni: con "posizione attuale" prende una lettura GPS all'apertura (il permesso viene chiesto in quel momento) e ripiega sull'ultima salvata; con "residenza" usa quella. Non esiste una città predefinita: finché la posizione non è nota la pagina mostra il caricamento a tutta pagina (`PetLoader`), e se non c'è nessuna posizione mostra "Imposta una località" con il pulsante verso le Impostazioni.

Anche il primo risultato si attende con il caricamento a tutta pagina: mappa ed elenchi compaiono solo quando c'è una risposta.

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
- **Mappa**: anteprima con cerchio del raggio e legenda; il pulsante in alto a destra apre la mappa a tutto schermo. Tutti i luoghi del raggio sono sulla mappa: quelli che si sovrapporrebbero diventano un marker numerato, che al tocco ingrandisce.
- **Servizi nella zona** è divisa per categoria, ognuna con il suo conteggio e i 3 più vicini. Un elenco unico per distanza nascondeva le categorie scarse (poche toelettature) sotto quelle abbondanti (centinaia di aree cani).

## Eventi nazionali

Un evento compare sempre, qualunque sia il raggio, se la sua `category` contiene la parola `nazionale` (ad esempio `fiera nazionale`). È una convenzione sul campo testuale esistente: non richiede colonne nuove.

### Inserire eventi

La tabella `local_activities` sul database nuovo è vuota, e con un backend configurato l'app non mostra mai i dati demo (restano solo per l'anteprima senza backend e per i test): la sezione dice che non ci sono eventi. Gli eventi si inseriscono dall'editor SQL di Supabase con questo modello, dopo aver verificato date e luogo sul sito ufficiale dell'organizzatore:

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
- Il limite per categoria (`per_type_limit`: l'app chiede 400 entro 10 km, 150 entro 25, 80 entro 50) tiene limitata la risposta. I veterinari non vengono mai troncati.
- Un luogo con la categoria ma senza nome non viene scartato: riceve un nome generico ("Veterinario", "Toelettatura", "Area cani").
- Overpass è l'ultima risorsa, non il percorso normale. Prima di importare, il backend usa qualunque import valido che copra già la richiesta: la cella del raggio chiesto, poi quelle dei raggi più ampi.
- Se l'import serve ma fallisce, viene servito ciò che c'è in cache per la zona: i dati scaduti (`coverage.status = "stale"`) oppure quelli di un raggio più stretto (`"partial"`, con `search_radius_km` ridotto). L'app lo dice all'utente. Solo una zona mai importata da nessuno può dare errore (502).
- Non esiste e non va aggiunto un endpoint di export o elenco completo della cache (vedi "Licenza").
- La chiave della cella contiene una versione (`radar:v2:...`): cambiare la forma dei dati in cache richiede solo di alzarla.

### Server Overpass

I server pubblici sono gratuiti e condivisi. Comportamento osservato il 2026-10-03:

- `overpass-api.de` concede 2 richieste contemporanee per indirizzo IP e risponde 429 per alcune decine di secondi dopo richieste pesanti. Il backend aspetta e riprova sullo stesso server (5 e 10 secondi) prima di passare ai server di riserva.
- Overpass accetta una query solo se il tempo che dichiara è compatibile con il carico del momento. Per questo il tempo dichiarato cresce con il raggio (15 s per 14 km, 39 s per 64 km) invece di chiedere sempre il massimo configurato.
- In produzione, il 2026-10-03, le richieste dai server Vercel hanno ricevuto un errore da Overpass (risposta 502 del backend subito dopo la lettura della cache, nessuna scrittura). Ogni tentativo fallito ora viene scritto nei log (`Overpass attempt failed on ...`), così il tipo di errore è leggibile da `vercel logs`.
- I server di riserva (`OVERPASS_FALLBACK_URLS`) non hanno risposto dalla rete di sviluppo. Il mirror `maps.mail.ru` è stato rimosso.
- Tempo totale massimo per un import: 40 secondi. L'app aspetta fino a 55 e, se la zona è ancora in preparazione (502/503/504), riprova da sola dopo 8 e 15 secondi prima di mostrare l'errore con "Riprova".

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

## Copertura misurata (Milano, 10 km dal Duomo, 2026-10-03)

| Categoria | In OpenStreetMap | Di cui senza nome | Mostrati prima | Mostrati ora |
| --- | --- | --- | --- | --- |
| Veterinari | 108 | 22 | 40 | 108 |
| Toelettature | 21 | 1 | 20 | 21 |
| Negozi | 90 | 3 | 40 | 90 |
| Pensioni | 6 | 0 | 6 | 6 |
| Aree cani | 364 | 347 | 40 | 364 |

"Prima": limite di 40 per categoria e luoghi senza nome scartati (tranne le aree cani).

Le toelettature non erano zero nei dati: erano 20, ma in fondo a un elenco ordinato per distanza che ne mostrava 6. Il limite vero però è la fonte: OpenStreetMap a Milano ne conosce 21.

Cercare per nome (`name ~ "toelett"`, `name ~ "veterinar"`) non è praticabile su Overpass: le query vanno in timeout dopo 76-88 secondi anche limitate a negozi e servizi. Tra i 90 negozi già importati, uno solo ha "toelett" o "grooming" nel nome: il guadagno sarebbe trascurabile.

## Fonti aperte aggiuntive: valutazione (non implementato)

### Prova su Overture Maps Places

Release `2026-09-23.1`, letta con DuckDB da `s3://overturemaps-us-west-2`, stesso cerchio di 10 km. Estrazione di tutti i 170.190 luoghi del riquadro in 65 secondi.

| Categoria | OSM | Overture (tutti) | Overture affidabili | Già in OSM | Nuovi | Totale unito |
| --- | --- | --- | --- | --- | --- | --- |
| Veterinari | 108 | 314 | 142 | 51 | 91 | 199 |
| Toelettature | 21 | 125 | 64 | 10 | 54 | 75 |
| Negozi | 90 | 383 | 209 | 65 | 144 | 234 |

"Affidabili": `confidence >= 0.7`, non `permanently_closed`, dopo deduplica interna. "Già in OSM": un luogo OSM entro 120 m con una parola del nome in comune (o entro 30 m).

Qualità osservata:

- Telefono presente nel 93% dei veterinari e nel 98% delle toelettature (in OSM molto meno).
- Sotto 0,7 di confidenza ci sono voci sbagliate (una fiera classificata come veterinario, nomi di persone, indirizzi generici): la soglia serve.
- 14 veterinari su 314 sono marcati chiusi definitivamente e vanno esclusi.
- Aree cani: Overture ne ha 30, OSM 364. Per questa categoria OSM resta la fonte.
- Fonti dei record: BrightQuery, Meta, Microsoft, AllThePlaces, Foursquare. Licenze per record: CDLA-Permissive-2.0 per 963, CC0 per 8, Apache-2.0 per 6.
- 56 veterinari OSM non hanno riscontro in Overture: le due fonti si completano, nessuna sostituisce l'altra.

Foursquare Open Source Places non è stato provato direttamente: Overture ne include già una parte. Va valutato solo se dopo Overture restassero buchi.

### Architettura proposta

1. Script `scripts/import_overture_places.py` (DuckDB), eseguito in locale o da una GitHub Action mensile, mai su Vercel. Scarica i luoghi delle categorie pet per l'Italia, applica soglia di confidenza ed esclusione dei chiusi.
2. Tabella propria `radar_places_open`: `source`, `source_id`, `place_type`, `name`, `latitude`, `longitude`, `address_label`, `phone`, `website_url`, `confidence`, `license`, `release`, `imported_at`. Tabella `data_sources` con licenza, attribuzione e versione di ogni fonte. RLS senza policy, come la cache OSM.
3. Unione **solo in lettura**: il servizio legge i luoghi OSM della cella e quelli aperti nel raggio, scarta i doppioni (stessa categoria, entro 120 m, nome compatibile) e restituisce ogni scheda con la sua fonte. Nessuna tabella unita salvata.
4. Scheda del luogo con attribuzione della fonte e data dello snapshot.
5. Effetto collaterale utile: per veterinari, toelettature e negozi la risposta non dipende più da Overpass in tempo reale. Overpass resta per aree cani e come complemento.

Vincoli dal parere di MARKETING e NORMATIVA (`docs/compliance/06_radar_mappe_sponsorizzazioni.md`, addendum 2026-10-03):

- Uso commerciale e conservazione ammessi per entrambe le fonti, senza obbligo di rilascio: nessuna ha share-alike.
- Nessun database combinato salvato che contenga dati OSM: l'unione resta in lettura.
- Per le urgenze non fondere telefono e orari di due fonti senza certezza: nel dubbio, due schede separate.
- Ditte individuali con nome e cellulare personali sono dati personali: servono valutazione del legittimo interesse, informativa e una lista di rimozione che l'import rispetti.
- Salvare nel repository i testi di licenza della release importata.

Stima: 2-3 giorni di lavoro (script, tabelle, unione con deduplica, attribuzione, test). Rischi: doppioni non riconosciuti, attività chiuse non marcate, dati personali delle ditte individuali.

### Perché non Google Places

- Oltre le soglie gratuite si paga a richiesta, e un radar che cerca per categoria in ogni zona le supera presto.
- I termini vietano di conservare i risultati (salvo l'identificativo del luogo): niente cache condivisa, ogni apertura sarebbe una richiesta a pagamento.
- I risultati vanno mostrati su una mappa Google, non su quella attuale basata su OpenStreetMap.
- Non possono essere uniti in un nostro archivio con altre fonti.
- Il progetto resterebbe dipendente da prezzi e condizioni decisi da un solo fornitore.

### Altre fonti italiane

Non è nota a chi scrive una banca dati nazionale delle strutture veterinarie pubblicata con licenza aperta e verificabile. Esistono elenchi pubblici consultabili (ad esempio l'anagrafe delle strutture veterinarie della FNOVI), ma senza una licenza di riuso accertata non vanno importati. Da verificare con una ricerca dedicata prima di contarci.

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
