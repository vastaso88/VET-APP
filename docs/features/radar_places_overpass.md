# Vicino a me (già "Radar nei dintorni")

Pagina unica (`LocalEventsPage`, titolo "Vicino a me" dal 2026-10-04) che riunisce i luoghi per animali attorno alla Località dell'utente: servizi e cliniche. Gli eventi non ne fanno più parte: hanno una sezione propria dell'app, costruita da un'altra sessione; dominio e repository `local_activities` sono rimasti intatti per quella.

Origine: il motore di ricerca su OpenStreetMap (`overpass_places_source.py`) è stato scritto da Roberto sul branch `roberto`. Cache per zona, API e schermata sono stati costruiti su `Francesco` il 2026-10-03. Parere legale: `docs/compliance/06_radar_mappe_sponsorizzazioni.md`.

## Da dove arrivano i dati (dal 2026-10-04)

Il radar risponde dal nostro database. Due archivi aperti vengono importati periodicamente, fuori da Vercel, e uniti solo al momento della richiesta:

| Fonte | Tabella | Cosa porta | Import |
| --- | --- | --- | --- |
| Overture Maps Places | `radar_places_open` | veterinari, toelettature, negozi, pensioni, pet sitter, addestratori, allevamenti | `scripts/radar/import_overture_places.py` |
| OpenStreetMap | `radar_places_osm` | aree cani (con i dettagli) e le stesse categorie viste dai volontari | `scripts/radar/import_osm_places.py` |

`data_sources` registra per ogni fonte versione, licenza, attribuzione, data dell'import e area coperta. Dove l'import OSM copre la posizione dell'utente (tutta Italia dopo un import completo) Overpass non viene più chiamato mentre l'utente aspetta. Fuori da quell'area resta il vecchio percorso: cache per cella e, come ultima risorsa, Overpass in diretta.

Le due tabelle non vengono mai unite nel database: OpenStreetMap ha una licenza con obbligo di condivisione (ODbL), Overture no. L'unione avviene in memoria, per singola richiesta, con le regole di `packages/core/domain/radar_places/dedup.py` (campione di taratura: `docs/features/radar_dedup_sample.md`). Quando due fonti hanno lo stesso luogo resta una scheda con i dati di una sola fonte e l'indicazione "Presente anche in".

### Numeri dell'import (prova del 2026-10-04, senza scrittura)

- Overture, Italia: 30.549 righe delle categorie pet, 15.831 luoghi dopo soglia di confidenza 0,7, esclusione dei chiusi e doppioni interni. Veterinari 4.842, toelettature 3.182, negozi 5.251, allevamenti 1.198, addestratori 1.117, pensioni 158, pet sitter 83. Tempo: 3 minuti e 11 secondi.
- OpenStreetMap: una richiesta per regione. Lombardia 1.944 luoghi in 34 secondi, Molise 17 in 3 secondi. Italia intera stimata in 10-15 minuti, pause comprese.
- Spazio: circa 9 MB per Overture e una cifra simile per OSM, su 500 MB del piano gratuito Supabase.

### Come si esegue

Servono `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` nel file `.env` locale (mai nel repository).

```bash
uv run --with duckdb python scripts/radar/import_overture_places.py
```

```bash
uv run python scripts/radar/import_osm_places.py
```

Su un computer dove un antivirus intercetta le connessioni HTTPS (è il caso del PC del proprietario) servono due opzioni in più, altrimenti `uv` non riesce a scaricare i pacchetti e gli script non raggiungono Supabase. Comando usato per gli import in produzione del 2026-10-04:

```bash
uv run --system-certs --with truststore python -u scripts/radar/import_osm_places.py
```

Lo stesso vale per gli altri script della cartella (per Overture si aggiunge `--with duckdb`). Import in produzione del 2026-10-04: Overture 15.852 luoghi, OpenStreetMap Italia 8.069 (20 regioni su 20), Bologna 33, Torino 52, Milano 297.

Con `--dry-run` gli script contano senza scrivere. `.github/workflows/radar-places-import.yml` li esegue il 2 di ogni mese, una volta impostati i segreti `RADAR_SUPABASE_URL` e `RADAR_SUPABASE_SERVICE_ROLE_KEY` nel repository.

Ogni import sostituisce il contenuto della propria tabella, rispetta le esclusioni manuali di `radar_place_overrides` e, per Overture, aggiorna `docs/licenses/overture_places_release.md`. L'import OSM dichiara l'Italia coperta solo se tutte e venti le regioni sono andate a buon fine.

### Import OpenStreetMap per tutta l'Italia: come regge i server pubblici

`scripts/radar/import_osm_places.py` scarica una regione alla volta e si può rilanciare finché non ha finito:

- ogni regione scaricata resta in `.local/radar/osm/` (fuori da git) per 24 ore: un nuovo lancio scarica solo quelle che mancano;
- il server principale (`overpass-api.de`) concede a ogni indirizzo pochi posti e fa attendere dopo una richiesta pesante: lo script legge la sua pagina di stato, aspetta il tempo indicato e riprova fino a tre volte; i due server alternativi sono una seconda possibilità con attesa breve, e uno che non risponde non viene più interpellato in quel lancio;
- `--max-seconds` (480 di default) ferma il lancio in modo pulito con codice di uscita 3 e il messaggio "Riprendi rilanciando lo stesso comando";
- su Supabase non viene scritto nulla finché non ci sono tutte e 20 le regioni.

Prova senza scrittura del 2026-10-04 (`uv run --extra dev python -u scripts/radar/import_osm_places.py --dry-run`): due lanci, cioè una ripresa. Il primo, con la versione precedente della gestione dei server, ha scaricato 3 regioni e si è fermato al limite di tempo; il secondo ha scaricato le altre 17 in 7 minuti e mezzo. Totale 8.069 luoghi: 2.517 aree cani, 2.033 negozi, 1.891 veterinari, 1.014 allevamenti, 393 toelettature, 141 pensioni, 80 educatori.

Il flusso mensile su GitHub rilancia da solo lo script quando esce con codice 3 (fino a quattro volte).

#### Alternativa valutata: estratto Geofabrik (non implementata)

Geofabrik pubblica ogni giorno un file con tutta l'Italia di OpenStreetMap (`italy-latest.osm.pbf`, 2,24 GB al 2026-10-04). Si può leggere senza installazioni di sistema: la libreria `osmium` ha pacchetti pronti per Windows e Linux (circa 2 MB), quindi basterebbe `uv run --with osmium`.

- A favore: è un file statico, non dipende dalla disponibilità dei server Overpass e lo scaricamento si può riprendere.
- Contro: 2,24 GB da scaricare a ogni import contro circa 2 MB di risposte Overpass; per avere la posizione di aree e perimetri (le aree cani sono quasi tutte perimetri) bisogna far passare tutti i punti del file, con alcuni GB di memoria o un file d'appoggio su disco; tempi di elaborazione non misurati (stima: diversi minuti).
- Conclusione: finché l'import a riprese completa l'Italia in uno o due lanci, resta la strada più leggera. Geofabrik è la strada più affidabile se i server pubblici diventassero inutilizzabili: da realizzare solo in quel caso, dentro il flusso mensile su GitHub (rete e disco adeguati), non sul computer del proprietario.

### Nell'app

Ogni scheda indica la fonte ("Fonte: © Overture Maps Foundation — Places") e, se c'è, l'altra fonte che la conferma. Impostazioni → Info → **Fonti dati** elenca le fonti con licenza, versione e data dell'import. Le aree cani mostrano ciò che OpenStreetMap dichiara (recintata, illuminata, fondo, accesso, acqua, accessibilità): un dato assente non viene mostrato come "no".

## Segnala! e stelle delle aree cani

Parere e condizioni: `docs/compliance/07_contributi_utenti.md`. Niente foto, niente testo libero, niente conferme sì/no sui dettagli, nessuna valutazione di veterinari, negozi o altre attività.

### Cosa si può fare

- **Segnalare un luogo mancante**: categoria da elenco chiuso, nome dell'insegna (facoltativo solo per le aree cani), posizione scelta sulla mappa, indirizzo ricavato dalla posizione. Nessun campo note e nessun campo di contatto.
- **Segnalare un problema su un luogo esistente**: ha chiuso, è un doppione, la posizione è sbagliata.
- **Confermare o smentire** una segnalazione in attesa ("Confermo" / "Non è così").
- **Ritirare una propria segnalazione** finché è in attesa ("Ritira la mia segnalazione" nella scheda, con conferma): la segnalazione e i voti ricevuti vengono cancellati. Una segnalazione già confermata dagli altri non si può più ritirare.
- **Dare da 1 a 5 stelle a un'area cani pubblica**. Un voto per persona e area, modificabile. La scheda mostra il voto della community (media e numero di voti; sotto i 3 voti solo il numero, "1 voto · la media compare da 3 voti", così non si ricava il voto di una singola persona) e il proprio voto a stelle piene; dopo il voto la scheda resta aperta e lo mostra subito. Sono escluse le aree a pagamento o riservate ai clienti (`fee=yes`, `access=customers|private`).

Prima del primo contributo l'app mostra le regole d'uso e chiede di accettarle (consenso `contribution_rules`, versionato, revocabile dalle impostazioni dei consensi; non blocca l'uso dell'app). La versione in vigore è la v2 (2026-10-04, regola 5 riscritta per le aree cani): chi avesse accettato una versione precedente deve accettare di nuovo.

### Come appare

- Un luogo segnalato e non ancora confermato è visibile a tutti, ma distinto: marker vuoto con un "?", riga con "Segnalato dagli utenti · in attesa di conferma (2/5)", scheda con l'avviso e i due pulsanti.
- Una volta confermato compare come gli altri, con fonte "Segnalato dagli utenti VetApp".
- Un luogo confermato chiuso o doppione sparisce: entra in `radar_place_overrides`, che gli import e la lettura rispettano. La lettura toglie anche lo stesso luogo presente in un'altra fonte (stessa categoria entro 30 m).
- "Posizione sbagliata", una volta confermata, non ha effetti automatici: resta nella tabella per una correzione manuale.

### Regole di conferma

- Soglia: `RADAR_REPORT_CONFIRMATIONS` (5) conferme di persone diverse; `RADAR_REPORT_CLOSED_CONFIRMATIONS` (5) per "ha chiuso". Modificabili senza nuova build.
- Chi ha segnalato non conta e non può votare la propria segnalazione.
- Un voto per persona per segnalazione; si può cambiare finché la segnalazione è in attesa.
- Le smentite si sottraggono alle conferme. Quando le smentite superano le conferme di 3, la segnalazione decade.
- Segnalare di nuovo la stessa cosa (stesso luogo, oppure un mancante della stessa categoria entro 50 m) vale come conferma della segnalazione esistente.
- Limite: `RADAR_REPORT_DAILY_LIMIT` (5) segnalazioni al giorno per persona.
- Il nome viene rifiutato se contiene numeri di telefono, email, siti o insulti evidenti, o se supera 60 caratteri.
- Per le categorie che possono coincidere con un'abitazione (pensioni, pet sitter, addestratori) la posizione viene arrotondata a circa 500 m.

### Due comportamenti lasciati alla decisione del proprietario

Sono impostazioni lato server, quindi la scelta non richiede una nuova build. Decisione del proprietario al 2026-10-04: le segnalazioni di chiusura restano non visibili fino alla soglia (default confermato); le aree cani come luogo mancante sono ancora da decidere.

| Impostazione | Default | Effetto |
| --- | --- | --- |
| `RADAR_REPORT_SHOW_PENDING_CLOSURES` | `false` | Se `true`, un luogo segnalato come chiuso mostra a tutti "Segnalato come chiuso (2/5)" con i pulsanti. Se `false`, le segnalazioni di chiusura non sono visibili: ogni nuova segnalazione indipendente vale come conferma. |
| `RADAR_REPORT_PLACE_TYPES` | veterinari, toelettature, negozi, pensioni, aree cani | Categorie segnalabili come mancanti. |

Decisioni del proprietario (2026-10-04): le segnalazioni di chiusura restano non visibili fino alla soglia, come da parere legale; le aree cani **si possono** segnalare come mancanti, con le cautele qui sotto.

### Aree cani segnalate dagli utenti

Un'area cani segnalata può essere un prato privato o non esistere. Per questo, finché non raggiunge le 5 conferme:

- in elenco, sulla scheda e sulla mappa è distinta dalle altre e porta la dicitura "Segnalata dagli utenti, verifica che sia un'area pubblica (2/5)";
- non si può valutare con le stelle (né interfaccia né API);
- sulla scheda c'è l'azione **"Non è un'area pubblica? Scrivici"**, che apre un'email al contatto configurato (`SUPPORT_CONTACT_EMAIL`) con oggetto, nome, posizione e identificativo già compilati. Se il contatto non è configurato l'azione non compare.

La rimozione su richiesta, del proprietario del terreno o di un utente, è immediata e non aspetta le smentite della comunità:

```bash
uv run python scripts/radar/remove_reported_place.py --report-id <identificativo dell'email>
```

Lo script segna la segnalazione come respinta: l'area sparisce alla richiesta successiva. Con `--source` e `--source-id` rimuove invece un luogo di una fonte aperta, scrivendo in `radar_place_overrides`. Con `--dry-run` mostra cosa farebbe.

Regola 5 delle regole d'uso (v2): "Un'area cani mancante va segnalata solo se è pubblica e aperta al pubblico. Non segnalare proprietà private e non invitare altri a entrare in luoghi privati."

Se una richiesta di rimozione si rivela infondata, `--restore` insieme a `--report-id` riporta la segnalazione in attesa di conferma. Il registro delle richieste e delle decisioni, con la motivazione, è tenuto fuori dall'app (la casella del contatto); per i luoghi delle fonti aperte la motivazione resta nella colonna `reason` di `radar_place_overrides`.

### Interruttori (variabili d'ambiente del backend)

Tutti accesi di default: senza impostare nulla il comportamento è quello di sempre. Su Vercel una variabile cambiata vale dal deploy successivo.

| Variabile | Default | Spenta |
| --- | --- | --- |
| `RADAR_REPORTS_ENABLED` | `true` | Niente nuove segnalazioni né voti (risposta 503 `contributions_disabled`); i luoghi segnalati dagli utenti e i loro contatori non vengono più mostrati. |
| `RADAR_REPORT_CLOSED_ENABLED` | `true` | Solo il tipo "ha chiuso" non è più accettato né votabile, e le chiusure in attesa non vengono mostrate; gli altri tipi restano. |
| `RADAR_RATINGS_ENABLED` | `true` | Niente nuove stelle (503) e le stelle non vengono più mostrate. |
| `RADAR_OPEN_SOURCES` | `["*"]` | Elenco JSON delle fonti di `radar_places_open` da servire, per esempio `["overture","comune_milano"]`; `[]` nessuna. Vale anche per la pagina "Fonti dati". OpenStreetMap non dipende da questo interruttore. |

Spegnere non cancella nulla: riaccendendo, segnalazioni, voti e stelle ricompaiono. Le esclusioni già applicate (`radar_place_overrides`: chiusure e doppioni già confermati, rimozioni fatte a mano) restano in vigore anche a interruttori spenti, così una rimozione su richiesta non torna visibile.

L'app legge `GET /local-services/reports/options` (`enabled`, `report_kinds`, `ratings_enabled`, `missing_place_types`): la pagina "Segnala!" e l'elenco dei problemi segnalabili seguono il server senza una nuova build; le stelle spariscono perché il server non le invia più.

### Scadenza delle segnalazioni

Una segnalazione che entro 7 giorni non riceve nemmeno una conferma non viene più mostrata né accettata come base per conferme, e lo script di pulizia la cancella. Con almeno una conferma resta in attesa fino al numero richiesto. Chi segnala lo legge nel modulo, nel messaggio di invio e nella scheda ("Scade tra N giorni se nessuno conferma"). Il numero di giorni arriva all'app da `GET /local-services/reports/options` (`expiry_days`) e per ogni segnalazione da `expires_in_days`.

Ritiro: `DELETE /local-services/reports/{id}`, solo per chi l'ha fatta e solo finché è in attesa.

### Dati e identità

- Tabelle nostre: `radar_user_reports`, `radar_report_votes`, `radar_place_ratings`, `radar_place_overrides`. Nulla viene scritto verso OpenStreetMap né nelle tabelle delle fonti aperte.
- Chi segnala o vota è registrato solo come pseudonimo: HMAC-SHA256 dell'id utente con la chiave `RADAR_PSEUDONYM_KEY`, che sta solo nelle variabili d'ambiente del backend. Nel database non c'è l'id utente e non esiste una tabella di corrispondenza. Per trovare i contributi di un account (ad esempio alla sua cancellazione) si ricalcola lo pseudonimo.
- Se `RADAR_PSEUDONYM_KEY` non è impostata, la chiave viene derivata da `SUPABASE_SERVICE_ROLE_KEY` (HMAC con etichetta fissa `radar-contributions-v1`): i contributi funzionano senza una variabile in più. Limite: se la service key viene ruotata, gli pseudonimi cambiano e i voti già dati non sono più riconducibili alla stessa persona. Impostare la variabile dedicata resta la scelta consigliata. Senza nessuna delle due in produzione i contributi sono disattivati (risposta 503) e il radar funziona in sola lettura.
- RLS attiva senza policy: tutto passa dal backend. L'API non restituisce mai lo pseudonimo; a chi guarda dice solo il proprio voto e se la segnalazione è sua.
- Conservazione (`scripts/radar/cleanup_reports.py`, eseguito anche dal flusso mensile): segnalazioni che nessuno ha confermato nemmeno una volta eliminate dopo 7 giorni (`RADAR_REPORT_EXPIRY_DAYS`; il backend smette comunque di servirle a quella scadenza, senza dipendere dallo script), segnalazioni ancora in attesa eliminate dopo 90 giorni; 12 mesi dopo l'esito vengono cancellati i voti e lo pseudonimo di chi ha segnalato, restano i contatori.

### Cosa non è implementato

- Rilevazione automatica di gruppi di account nuovi che confermano insieme, ed età minima dell'account per segnalare una chiusura: l'API di autenticazione usata oggi non espone la data di creazione dell'account al servizio.
- Canale di contestazione per i titolari con verifica di partita IVA: oggi è l'indirizzo email dell'impostazione `SUPPORT_CONTACT_EMAIL`, mostrato in "Fonti dati" (se l'impostazione è vuota l'app non mostra alcun indirizzo); l'esito si applica a mano (riga in `radar_place_overrides` o cambio di stato della segnalazione).
- Filtro sui nomi di persona nel nome del luogo: c'è solo il filtro su contatti e insulti.
- Cancellazione dei contributi alla chiusura dell'account: la logica è possibile (pseudonimo ricalcolabile) ma non è collegata, perché l'app non ha ancora una funzione di cancellazione dell'account.

## Posizione

Al primo ingresso senza nessuna posizione nota, la pagina mostra una spiegazione ("VetApp usa la posizione del telefono solo mentre usi l'app") con due scelte: **Consenti**, che fa comparire la richiesta di sistema, salva la modalità "posizione attuale" e centra subito; **Scegli un indirizzo**, che apre le Impostazioni. Chi ha già una posizione salvata non rivede la spiegazione.

La pagina è centrata sulla Località scelta in Impostazioni: con "posizione attuale" prende una lettura GPS all'apertura (il permesso viene chiesto in quel momento) e ripiega sull'ultima salvata; con "residenza" usa quella. Non esiste una città predefinita: finché la posizione non è nota la pagina mostra il caricamento a tutta pagina (`PetLoader`), e se non c'è nessuna posizione mostra "Imposta una località" con il pulsante verso le Impostazioni.

Anche il primo risultato si attende con il caricamento a tutta pagina: mappa ed elenchi compaiono solo quando c'è una risposta.

## Fonti dei dati

| Sezione | Fonte | Note |
| --- | --- | --- |
| Servizi nella zona | OpenStreetMap (tutte le categorie tranne i veterinari) + `local_activities` senza data | |
| Cliniche e ambulatori | OpenStreetMap `amenity=veterinary` + `local_activities` senza data con categoria che contiene "ambulator", "veterin" o "clinic" | pensata per le urgenze |

## Controlli della pagina

- **Raggio** (5, 10, 25, 50 km): comanda sia la mappa sia la ricerca sul backend. Ogni raggio fa una richiesta, tenuta in memoria finché la pagina è aperta.
- **Categorie** a un tocco (Veterinari, Negozi, Aree cani, Toelettature, Pensioni): filtrano i dati già caricati, senza nuove richieste. Il pulsante "Filtri" con il suo pannello è stato tolto il 2026-10-04 (sul dispositivo non funzionava), e con lui il filtro per specie, che esisteva solo lì.
- **Categorie**: etichetta, icona e colore di ogni categoria sono definiti una sola volta in `radar_category.dart` e usati da liste, marker, filtri e legenda.
- **Mappa**: anteprima con cerchio del raggio e legenda; il pulsante in alto a destra apre la mappa a tutto schermo. Tutti i luoghi del raggio sono sulla mappa: quelli che si sovrapporrebbero diventano un marker numerato, che al tocco ingrandisce.
- **Servizi nella zona** è divisa per categoria, ognuna con il suo conteggio e i 3 più vicini. Un elenco unico per distanza nascondeva le categorie scarse (poche toelettature) sotto quelle abbondanti (centinaia di aree cani).

## Eventi

Tolti dalla pagina il 2026-10-04: niente sezione "In programma", niente categoria Eventi nei chip e sulla mappa, niente regola degli eventi nazionali sempre visibili. Dalla tabella `local_activities` la pagina legge ancora solo le righe senza data (servizi inseriti a mano), tra i servizi o tra le cliniche.

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

## Fonti aperte aggiuntive: la valutazione che ha portato all'import

### Prova su Overture Maps Places

Release `2026-09-23.1`, letta con DuckDB da `s3://overturemaps-us-west-2`, stesso cerchio di 10 km. Estrazione di tutti i 170.190 luoghi del riquadro in 65 secondi.

| Categoria | OSM | Overture (tutti) | Overture affidabili | Già in OSM | Nuovi | Totale unito |
| --- | --- | --- | --- | --- | --- | --- |
| Veterinari | 108 | 314 | 142 | 51 | 91 | 199 |
| Toelettature | 21 | 125 | 64 | 10 | 54 | 75 |
| Negozi | 90 | 383 | 209 | 65 | 144 | 234 |

Nota: i numeri dei negozi in questa tabella sono gonfiati. La prima estrazione cercava "pet_store" come parte del nome della categoria e includeva 86 negozi di tappeti (`carpet_store`). L'import usa il confronto esatto.

"Affidabili": `confidence >= 0.7`, non `permanently_closed`, dopo deduplica interna. "Già in OSM": un luogo OSM entro 120 m con una parola del nome in comune (o entro 30 m).

Qualità osservata:

- Telefono presente nel 93% dei veterinari e nel 98% delle toelettature (in OSM molto meno).
- Sotto 0,7 di confidenza ci sono voci sbagliate (una fiera classificata come veterinario, nomi di persone, indirizzi generici): la soglia serve.
- 14 veterinari su 314 sono marcati chiusi definitivamente e vanno esclusi.
- Aree cani: Overture ne ha 30, OSM 364. Per questa categoria OSM resta la fonte.
- Fonti dei record: BrightQuery, Meta, Microsoft, AllThePlaces, Foursquare. Licenze per record: CDLA-Permissive-2.0 per 963, CC0 per 8, Apache-2.0 per 6.
- 56 veterinari OSM non hanno riscontro in Overture: le due fonti si completano, nessuna sostituisce l'altra.

Foursquare Open Source Places non è stato provato direttamente: Overture ne include già una parte. Va valutato solo se dopo Overture restassero buchi.

### Controllo di qualità sui dati importati (2026-10-04, solo numeri)

Fatto sugli estratti locali (cartella `.local/`, fuori da git), per tutta l'Italia.

- **Unione delle due fonti**: veterinari OSM 1.891 + Overture 4.849 diventano 5.857 schede (883 doppioni uniti); toelettature 393 + 3.182 diventano 3.391; negozi 2.033 + 5.263 diventano 6.282. Le grafie diverse della stessa struttura (maiuscole, "Ambulatorio Veterinario Nome" contro il solo "Nome") vengono unite entro 120 m; i casi sono nei test con nomi sintetici. Restano separate 7 coppie di veterinari con nome compatibile ma distanti tra 120 e 300 m, e 1 coppia con nome fatto solo di parole generiche: scelta voluta, meglio un doppione che due strutture fuse.
- **Categoria sbagliata alla fonte**: in questa versione di Overture le categorie alternative sono quasi sempre vuote (319 righe su 30.549), quindi non c'è una "primaria contro alternativa" da ordinare: l'errore è nella primaria. L'import ora corregge i luoghi classificati "veterinario" il cui nome dichiara un altro mestiere e nulla di veterinario (`place_type_for` in `overture_mapping.py`): 104 righe (37 addestramento, 29 toelettature, 20 allevamenti, 10 pensioni, 8 negozi). Solo in uscita dalla categoria veterinari; vale dal prossimo import.
- **Voci che sono solo un nome di persona** tra i veterinari: stima, non conteggio esatto. La regola automatica "nessuna parola di attività nel nome" ne trova 324 su 5.857 (più 193 con titolo, tipo "Dott. Nome Cognome"); in un campione di 40 delle 324 poco più della metà erano davvero nome e cognome, le altre nomi di fantasia o attività di altro tipo. Ordine di grandezza: 170-190 voci con solo nome e cognome, più circa 190 con titolo. Nessuna regola applicata: decisione del proprietario.

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

### Aree cani dei Comuni: verifica (2026-10-04)

Controllo fatto interrogando i portali open data dei Comuni. Regola del parere legale: si importa solo con licenza IODL 2.0, CC BY 4.0, CC BY 3.0 Italia o CC0 accertata sulla pagina di chi pubblica, escluse icone e grafiche.

| Comune | Dataset | Aree | Licenza dichiarata | Formato | Aggiornato | Esito |
| --- | --- | --- | --- | --- | --- | --- |
| Bologna | `sgambatura_cani` (opendata.comune.bologna.it) | 33 | CC BY 4.0, con link alla licenza | JSON, GeoJSON (punto e perimetro) | 2026-09-14 | **Importato** |
| Torino | `aree-cani` (aperto.comune.torino.it) | 52 | CC BY 4.0 (link al testo 4.0 nella pagina) | CSV con coordinate, SHP | 2019-06-05 | **Importato**, con "dati del 2019" nell'attribuzione |
| Milano | `ds52_infogeo_aree_cani_localizzazione` (dati.comune.milano.it) | 297 (in 423 perimetri) | CC BY 4.0 nei metadati; la pagina cita CC BY 3.0 Italia per icone e aree tematiche del portale, che non usiamo | GeoJSON (perimetri), CSV | 2026-05-08 | **Importato** |
| Roma | "Aree ludiche per cani" (dati.comune.roma.it) | non contate | "Creative Commons Attribution", versione non indicata | ODS | 2020-03-24 | Non importato |
| Napoli | nessun dataset trovato | | | | | |
| Firenze, Genova | il portale non ha risposto alla ricerca | | | | | Da riprovare |

Milano è il caso che conta di più. Il file ha 423 perimetri, che corrispondono a 297 aree: un'area grande è disegnata con più perimetri che condividono lo stesso identificativo, e l'import ne fa una scheda sola. Nella prima versione di questa tabella avevo scritto "423 aree": erano i perimetri. In OpenStreetMap, nello stesso territorio, le aree cani sono 364; il confronto fatto perimetro per perimetro dava 166 perimetri su 423 senza un'area OSM entro 60 m. La licenza è stata accertata da MARKETING e NORMATIVA il 2026-10-04 (`docs/compliance/07_contributi_utenti.md`): CC BY 4.0 per i dati; CC BY 3.0 Italia, che riguarda icone e grafiche del portale, è comunque compatibile ma quelle parti non vengono usate.

Qualità: Bologna e Milano pubblicano i perimetri, Torino solo un punto. Nessuno dei dataset contiene recinzione, acqua o illuminazione: quei dettagli restano quelli di OpenStreetMap. Quando la stessa area è in OSM e nell'elenco del Comune (stessa area entro 60 m) resta una scheda sola; se OSM ha i dettagli vince OSM e il Comune compare come "Presente anche in".

Import: `uv run python scripts/radar/import_municipal_dog_parks.py` (anche nel flusso mensile). Ogni Comune è una fonte a sé in `data_sources`, con la propria attribuzione nella scheda e in "Fonti dati".

### Altre fonti italiane

Non è nota a chi scrive una banca dati nazionale delle strutture veterinarie pubblicata con licenza aperta e verificabile. Esistono elenchi pubblici consultabili (ad esempio l'anagrafe delle strutture veterinarie della FNOVI), ma senza una licenza di riuso accertata non vanno importati. Da verificare con una ricerca dedicata prima di contarci.

## Contribuire a OpenStreetMap: valutazione (non implementato)

**Decisione del proprietario, 2026-10-04: non si procede.** Resta solo come possibile idea di comunicazione per il futuro. Quanto segue è la valutazione che ha portato alla decisione; nulla di questa sezione è implementato.

Domanda del proprietario: l'app può aiutare a migliorare OpenStreetMap, anche come elemento di comunicazione? Pagine ufficiali lette il 2026-10-04: [Notes](https://wiki.openstreetmap.org/wiki/Notes), [API v0.6](https://wiki.openstreetmap.org/wiki/API_v0.6), [Automated Edits code of conduct](https://wiki.openstreetmap.org/wiki/Automated_Edits_code_of_conduct), [Import/Guidelines](https://wiki.openstreetmap.org/wiki/Import/Guidelines), [Organised Editing Guidelines](https://osmfoundation.org/wiki/Organised_Editing_Guidelines), [API Usage Policy](https://operations.osmfoundation.org/policies/api/).

### Cosa dicono le regole (verificato sulle pagine)

- **Note**: sono commenti geolocalizzati che i mappatori leggono e poi chiudono dopo aver corretto la mappa. L'API permette di crearle (`POST /api/0.6/notes`) anche senza account; una nota senza account viene rifiutata nelle zone sotto moderazione. La pagina Notes chiede esplicitamente di **non creare note automatiche**: le note devono essere una comunicazione tra persone.
- **Modifiche non riviste una per una** da chi le esegue (bot, script, import) ricadono nel codice di condotta sulle modifiche automatiche: vanno documentate in una pagina wiki e discusse prima con la comunità.
- **Import di dati esterni**: serve una licenza compatibile con ODbL, la discussione con la comunità locale e sul forum, e un account dedicato all'import.
- **Attività organizzate** (più persone coordinate da un'organizzazione): le linee guida chiedono una pagina wiki dell'attività con responsabile e contatto, l'avviso alla comunità interessata e risposte ai mappatori entro due giorni lavorativi. Non sono una policy vincolante, ma ignorarle può portare al blocco e all'annullamento delle modifiche.
- **API**: serve un User-Agent che identifichi app e versione; non si inviano dati personali; l'accesso può essere revocato in qualsiasi momento.

### Le tre strade

| Strada | Come funzionerebbe | Valutazione |
| --- | --- | --- |
| (a) Note inviate dall'app in automatico quando un luogo raggiunge 5 conferme | Il backend crea la nota senza che una persona la scriva | **No così com'è**: è proprio la "nota automatica" che la pagina Notes chiede di evitare. |
| (a-bis) Nota inviata da un utente, per sua scelta | Sulla scheda di un luogo confermato: "Segnala anche a OpenStreetMap". L'utente vede il testo, può modificarlo e la invia lui | **Praticabile**: resta una comunicazione tra persone. Volume basso per natura. |
| (b) Modifiche vere con l'account OSM dell'utente (accesso OAuth, come fanno gli editor per telefono) | L'utente accede con il proprio account OSM e l'app aggiunge o corregge l'oggetto a suo nome | Corretta nei principi, ma è un editor di mappe dentro l'app: schema dei tag, conflitti, annullamenti, responsabilità dell'utente per ogni modifica. Settimane di lavoro e supporto continuo. Da considerare solo più avanti. |
| (c) Account dell'app che carica le modifiche | Un unico account VetApp scrive in OSM i luoghi confermati | **Non è la via**: sono modifiche non riviste da chi le esegue, quindi automatiche; servirebbero documentazione, discussione preventiva e assenso della comunità, e resterebbe il rischio di blocco e annullamento. |

Supposizioni, non verificate sulle pagine: che la comunità italiana accolga bene un flusso di note da un'app nuova (va chiesto sul forum prima di partire); quante note al giorno siano tollerate (le pagine lette non indicano un numero).

### Vincoli di licenza

- Verso OSM può andare **solo ciò che creano i nostri utenti**, e solo se l'utente ha accettato esplicitamente che quel contributo sia pubblicato con licenza ODbL.
- **Mai** dati di Overture, dei Comuni o di altre fonti riversati in OSM: non sono nostri da rilicenziare, e sarebbe un import soggetto alle regole sopra.
- Mai telefoni o nomi di persone: la policy dell'API vieta di inviare dati personali, e le nostre regole d'uso già li escludono dalle segnalazioni.

### Raccomandazione

Partire, se si vuole, dalla sola strada (a-bis), con questi passi:

1. Aprire una discussione sul forum della comunità italiana di OpenStreetMap, descrivendo l'app e il flusso, **prima** di attivarlo. Creare la pagina wiki dell'attività con un contatto.
2. Account OSM dedicato per le note dell'app, e User-Agent che identifica app e versione. Le note senza account sono possibili ma non raggiungono le zone moderate e non permettono ai mappatori di rispondere a qualcuno.
3. Una nota solo per luoghi già confermati da 5 utenti, una sola volta per luogo, e sempre su azione dell'utente che la legge e la invia. Tetto giornaliero basso lato server.
4. Testo della nota: categoria, nome dell'insegna, "segnalato e confermato da utenti dell'app VetApp", nessun dato personale.
5. Nuovo punto nelle regole d'uso, con accettazione separata: "Se scegli di inviare una segnalazione a OpenStreetMap, il testo che invii è pubblicato su OpenStreetMap con licenza ODbL ed è visibile a tutti". Il consenso va chiesto al momento dell'invio, non una volta per tutte.

Comunicazione: si può dire "VetApp usa OpenStreetMap e aiuta a migliorarlo: gli utenti possono segnalare ai volontari i luoghi mancanti". Non "VetApp aggiorna OpenStreetMap": la mappa la aggiornano i volontari, e una promessa più larga del vero sarebbe notata proprio dalla comunità a cui ci si rivolge.

Stima per (a-bis): 2-3 giorni, più il tempo della discussione con la comunità, che non dipende da noi.

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
