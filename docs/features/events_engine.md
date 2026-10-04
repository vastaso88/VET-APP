# Motore eventi ("In programma" del Radar nei dintorni): analisi e progetto

Data: 2026-10-03. Solo ricerca e progettazione: nessun codice scritto, nessun evento inserito.
Contesto: la sezione "In programma" di `LocalEventsPage` oggi legge `local_activities` ed è vuota (vedi `docs/features/radar_places_overpass.md`, sezioni "Eventi nazionali" e "Inserire eventi").

> **Natura del documento.** Analisi tecnica e di prodotto, non un parere legale. I punti marcati **⚖️** vanno rivisti da NORMATIVA o da un avvocato. In ogni tabella di fonti la colonna "Stato" distingue **V** (verificato da me il 2026-10-03 aprendo la fonte), **P** (parziale: visto solo in un riassunto di ricerca o in una parte) e **S** (supposto, non verificato).

## 0. Sintesi

- **Una classificazione ufficiale esiste, ma non è unica.** Per le fiere: le leggi regionali sul sistema fieristico e i criteri della Conferenza delle Regioni (2002) distinguono **internazionale, nazionale, regionale, locale**; la qualifica è attribuita dalla Regione (locale: dal Comune) e ha soglie numeriche. Per le esposizioni canine: l'ENCI distingue **Internazionali (CACIB FCI), Nazionali (CAC), Regionali, Raduni, Speciali di razza**. Per i gatti: calendario FIFe/ANFI con esposizioni internazionali, campionato nazionale e mostre regionali. **"Provinciale" non esiste come qualifica ufficiale**: sarebbe una nostra regola.
- **Proposta**: cinque livelli (locale, provinciale, regionale, nazionale, internazionale) assegnati solo con una *base documentata* (campo `level_basis`); senza documento il livello resta "locale". Visibilità: locale entro il raggio scelto, provinciale entro 50 km, regionale entro 150 km o stessa regione, nazionale e internazionale sempre (in un riquadro "Grandi eventi", con finestre temporali diverse).
- **Modello dati**: tabella `events` con una riga per edizione, `event_sources` per la provenienza, ricerca con latitudine/longitudine + riquadro (come il radar), **senza PostGIS** all'inizio (poche migliaia di righe).
- **Fonti**: il materiale più utile e più gratuito sono i **calendari fieristici regionali** (Lombardia e Piemonte verificati, con qualifica per ogni fiera e fiere pet reali dentro), i **calendari ENCI e ANFI** (completi ma senza licenza di riuso: serve il permesso scritto) e l'**inserimento curato** dal proprietario. I feed turistici open data (Umbria, Firenze) sono validi tecnicamente ma quasi privi di eventi pet. Adozioni, open day, microchip day e passeggiate **non hanno alcuna fonte centrale**: arrivano solo da contributi.
- **Fase A (5-6 giorni)** è rilasciabile senza nessuna fonte automatica: schema, ricerca, livelli, caricamento curato da file nel repository.

## 1. Tassonomia degli eventi pet in Italia

Le colonne "Frequenza" e "Chi organizza" sono, salvo dove c'è una nota di fonte, **conoscenza generale non verificata** (S). Il codice è il valore proposto per `event_type`.

| Codice | Tipo | Pubblico | Frequenza tipica | Chi organizza | Note e fonti |
| --- | --- | --- | --- | --- | --- |
| `pet_fair` | Fiere per il pubblico dedicate agli animali (stand, prodotti, spettacoli) | Famiglie, proprietari | 1-2 giorni, per città; circuiti itineranti | Società fieristiche, enti fiera, agenzie | **V**: Quattrozampeinfiera (BolognaFiere Cosmoprof, 5 tappe tra ott. 2026 e apr. 2027), Petsfestival (Cremona, 17-18/10/2026), "PET in FIERA" (Pavia, 16-17/05/2026) |
| `trade_fair` | Fiere professionali (B2B) | Operatori, veterinari | Annuali o biennali | Grandi quartieri fieristici | **V** (da riassunto di ricerca e sito ufficiale): Zoomark International, Bologna, 11-13/05/2027, biennale, "trade". **Non per il pubblico**: non mostrare nell'elenco generale |
| `dog_show` | Esposizioni canine: internazionali (CACIB), nazionali (CAC), regionali, speciali di razza | Allevatori, espositori, appassionati | Decine di date l'anno, a distanza minima di 150 km tra internazionali, nazionali e raduni | Comitati organizzatori (gruppi cinofili, club di razza) con riconoscimento ENCI | **V**: regolamento ENCI art. 2-5 |
| `breed_gathering` | Raduni di razza | Proprietari della razza | Annuale per razza | Società specializzate (club di razza) con regolamento approvato ENCI | **V**: ENCI art. 2 lett. d |
| `cat_show` | Esposizioni feline (internazionali FIFe, campionato nazionale, regionali) | Allevatori, appassionati | Una ogni 15 giorni al massimo in Italia | Comitati con riconoscimento ANFI | **V**: norme tecniche ANFI (almeno 15 giorni tra una e l'altra); esempio: esposizione internazionale a Genova 11-12/10/2025 con patrocinio ANFI (da ricerca) |
| `work_trial` | Prove di lavoro (caccia, pastorizia, ricerca e soccorso, tartufo, corse di levrieri) | Conduttori, appassionati | Calendario annuale | Gruppi cinofili, società specializzate | **V**: calendario prove ENCI (tipologie viste) |
| `dog_sport` | Sport cinofili: agility, obedience, rally-o, flyball, dog dancing, mondioring, canicross, bikejoring | Praticanti, spettatori | Gare di circuito, spesso nel fine settimana | ENCI per le discipline riconosciute; per il canicross, secondo una fonte generica (Wikipedia, da riverificare), CSEN e il circuito privato FISC | **V** per ENCI; **P** per canicross |
| `adoption_day` | Giornate di adozione | Chi vuole adottare | Frequenti, locali, spesso nel weekend | Canili, gattili, ENPA, LAV, OIPA e simili, associazioni locali | **P**: sezioni ENPA in "170 piazze" intorno al 4 ottobre; nessun calendario centrale |
| `shelter_open_day` | Open day di canili e gattili | Cittadini, scuole | Alcune volte l'anno | Gestori dei rifugi | **P**: ad esempio open day della Casa degli Animali LAV nella Giornata mondiale degli animali (4 ottobre) |
| `microchip_day` | Microchip day, controlli gratuiti | Proprietari | Sporadici, locali | ASL, Comuni, ordini dei veterinari, associazioni | **S**: nessuna fonte verificata |
| `vaccination_campaign` | Campagne vaccinali e antirabbiche comunali | Proprietari | Ricorrenti, stagionali | ASL, Comuni | **S** |
| `group_walk` | Passeggiate di gruppo con i cani | Proprietari | Spesso ricorrenti (settimanali o mensili) | Gruppi informali, associazioni, Comuni | **S**. Richiede ricorrenza |
| `course_seminar` | Corsi e seminari: educazione, primo soccorso veterinario, comportamento | Proprietari | Ciclici | Educatori, associazioni, veterinari, enti di formazione | **S** |
| `market` | Mercatini e mostre scambio | Pubblico | Mensili o stagionali | Associazioni, pro loco | **S** |
| `charity_event` | Eventi benefici (raccolte, cene, camminate) | Pubblico | Locali, irregolari | Associazioni di tutela | **S** |
| `vet_conference` | Convegni veterinari | Professionisti | Annuali | Società scientifiche | **P**: congresso SCIVAC Rimini 4-6/06/2027 da riassunto di ricerca. Professionale: escluso salvo sessioni aperte al pubblico |
| `aquarium_expo` | Acquariofilia (mostre, mostre scambio) | Appassionati | Alcune l'anno | Associazioni acquariofile | **S** |
| `reptile_expo` | Terraristica ed esotici | Appassionati | Alcune l'anno, con fiere dedicate | Organizzatori privati, associazioni | **S**. Valutare con attenzione: vendita di animali esotici |
| `bird_show` | Ornitologia: mostre, mostre scambio, campionato italiano | Ornicoltori, pubblico | Stagionale (inverno) | FOI (sotto la confederazione mondiale COM) e circoli locali | **P**: FOI organizza sotto l'egida della COM; "Sagra regionale degli uccelli" di Almenno San Salvatore (BG) nel calendario fiere lombardo 2026 **V** |
| `equestrian` | Eventi equestri (fiere e concorsi) | Pubblico, cavalieri | Annuali | Enti fiera, federazioni | **V**: Fieracavalli Verona 5-8/11/2026, 128ª edizione (da riassunto di ricerca); "Travagliatocavalli" nel calendario nazionale lombardo 2026 **V**. Pertinenza da decidere (sezione 7) |
| `other` | Altro | | | | Valvola di sfogo: da evitare in produzione |

`species` (array): `dog`, `cat`, `bird`, `fish`, `reptile`, `small_mammal`, `horse`, `exotic`; vuoto = tutte le specie. Si aggancia al filtro Specie del radar, che oggi non può filtrare gli eventi.

Nota: nei calendari fieristici regionali **non esiste un settore "animali" affidabile**. Nel calendario nazionale lombardo 2026, Petsfestival ha codice settore "3" come altre fiere non pet; "PET in FIERA" ha "1" come una fiera di merci e bestiame. L'individuazione delle fiere pet richiede quindi parole chiave nel nome (pet, animali, cani, gatti, cavalli, uccelli...) più revisione manuale (**V**: letti i due file PDF).

## 2. Classificazione di importanza e portata

### 2.1 Cosa esiste già (classificazioni ufficiali)

| Ambito | Classificazione ufficiale | Chi la attribuisce | Fonte | Stato |
| --- | --- | --- | --- | --- |
| **Fiere** (qualsiasi settore) | Internazionale, nazionale, regionale, locale ("le manifestazioni fieristiche sono qualificate internazionali, nazionali, regionali o locali"). Internazionale e nazionale: attribuite o revocate dalla Regione; locale: dal Comune. Criteri: consistenza e provenienza geografica di espositori e visitatori, dimensioni di mercato, idoneità del quartiere, rilievo promozionale, esiti delle edizioni precedenti | Regione (locale: Comune) | L.R. Emilia-Romagna 12/2000 art. 5 ([testo](https://edizionieuropee.it/LAW/HTML/109/er3_07_20.html)); ricerca generica per altre Regioni | **V** per Emilia-Romagna; **P** per le altre |
| Fiere: soglie numeriche | **Internazionale**: nelle ultime due edizioni almeno il 15% degli espositori esteri da almeno 10 Paesi (o 5 extra UE), oppure almeno l'8% di visitatori esteri, oppure almeno il 4% di visitatori extra UE. **Nazionale**: più della metà di espositori o visitatori da almeno 6 regioni diverse da quella ospitante (con deroghe: 10% espositori esteri o 5% visitatori esteri). La qualifica decade dopo due edizioni consecutive senza i requisiti. Una proposta di intesa Stato-Regioni del 2014 riporta soglie diverse per l'internazionale (15% espositori o 8% visitatori esteri con dati autocertificati; 10% e 5% con dati certificati da organismo accreditato ACCREDIA) | Conferenza delle Regioni | Documento del 24 ottobre 2002 ([testo](https://regione.lazio.it/sites/default/files/documentazione/SVI_Intesa_24_10_2002.pdf)); proposta 2014 ([testo](https://www.regioni.it/download/conferenze/326634/)) | **V** (il testo del 2014 è una *proposta*; che sia stata approvata così non l'ho verificato) |
| Calendari fieristici | Le Regioni li approvano ogni anno (Lombardia: decreto entro il 31 luglio; Piemonte 2026: 10 internazionali, 48 nazionali, 50 regionali, 140 locali) | Regioni | [Lombardia](https://www.regione.lombardia.it/attivita-produttive-imprese/fiere), [Piemonte](https://www.regione.piemonte.it/web/temi/sviluppo/commercio/calendario-fieristico-regionale) | **V** |
| **Esposizioni canine** | Per titoli rilasciabili: **Internazionali** (certificati validi per i campionati internazionali FCI: CACIB), **Nazionali** (certificati per i campionati italiani: CAC), **Regionali** (mai CAC); **Raduni** (indetti da associazioni specializzate); **Speciali di razza** (concesse dalle società specializzate, dentro un'esposizione nazionale o internazionale). L'ENCI non autorizza internazionali, nazionali e raduni a meno di 150 km l'uno dall'altro. FCI: una sola CACIB per sesso, razza e varietà; internazionali nello stesso giorno solo a 300 km di distanza; Esposizione Mondiale e di Sezione (continentale) come vertice | ENCI (calendario approvato dal Consiglio direttivo su proposta dei Consigli cinofili regionali) e FCI | Regolamento generale manifestazioni canine ENCI (copia 2008, in vigore dal 2009, art. 2-5, [PDF](https://anmvioggi.it/media/files/REGOLAMENTO%20ENCI%20MANIFESTAZIONI%20CANINE.pdf)); regolamento FCI ospitato da ENCI ([PDF](https://www.enci.it/media/3239/regolamento-esposizioni-canine.pdf)); la pagina del [calendario ENCI](https://www.enci.it/manifestazioni-ed-eventi/calendario-esposizioni) usa gli stessi filtri (Internazionali, Nazionali, Regionali, Speciali, Raduni) | **V**. Rischio: la copia del regolamento è del 2008; i filtri attuali del sito ne confermano la struttura ma non ho letto una versione più recente |
| **Esposizioni feline** | Calendario internazionale FIFe a cui ANFI armonizza le date; titoli CACIB e CAPIB nei campionati internazionali; ANFI: almeno 15 giorni tra una esposizione e l'altra; sul sito ANFI compaiono esposizioni internazionali, "Campionato nazionale" ed esposizioni in varie città | ANFI, FIFe | Norme tecniche ANFI ([PDF](https://www.anfitalia.it/files/144/Norme-Tecniche-Expo/288/Norme-Tecniche-delle-Mostre-ed-Esposizioni.pdf)); [calendario ANFI](https://www.anfitalia.it/eventi-expo/eventi-calendario-expo); [regole FIFe](https://fifeweb.org/app/uploads/2023/11/show_rules_en.pdf) | **V** per ANFI; **P** per FIFe (solo riassunto) |
| Sport cinofili, prove | Il calendario prove ENCI riporta il titolo (CAC, CACIT, internazionale, mondiale) per ogni prova | ENCI | [calendario prove](https://www.enci.it/manifestazioni-ed-eventi/calendario-prove) | **V** |
| Adozioni, open day, microchip, passeggiate, corsi | **Nessuna classificazione ufficiale.** Sono eventi locali per natura, salvo le campagne nazionali di un ente (es. giornata di un'associazione in molte piazze) | | | **S** |

### 2.2 Scala proposta

Il livello descrive la **portata** (da quanto lontano ha senso venire), non la qualità. I livelli ufficiali sono quattro; **"provinciale" è un'aggiunta nostra**, assegnata solo con la regola indicata.

| Livello | Valore | Criteri oggettivi (basta uno, nell'ordine di affidabilità) |
| --- | --- | --- |
| Internazionale | `international` | (1) Fiera con qualifica internazionale nel calendario regionale, o che rispetta le soglie del 2002. (2) Esposizione canina ENCI "Internazionale" con CACIB FCI, Esposizione Mondiale o di Sezione FCI. (3) Esposizione felina FIFe internazionale. (4) Campionato mondiale della COM (ornitologia) |
| Nazionale | `national` | (1) Fiera con qualifica nazionale nel calendario regionale. (2) Esposizione ENCI "Nazionale" (CAC); campionato italiano di una disciplina riconosciuta; raduno di razza organizzato dalla società specializzata nazionale. (3) Campionato nazionale ANFI. (4) Campagna nazionale di un ente organizzata in più città con unico evento principale |
| Regionale | `regional` | (1) Fiera con qualifica regionale. (2) Esposizione ENCI "Regionale". (3) Esposizione felina ANFI regionale. (4) Evento organizzato da un ente regionale (Consiglio cinofilo regionale, sezione regionale di una federazione) |
| Provinciale | `provincial` | **Regola nostra**: evento il cui organizzatore è un ente provinciale (Delegazione ENCI provinciale, ASL, sezione provinciale di un'associazione, Provincia o Città metropolitana) oppure con bacino dichiarato dalla fonte come provinciale. Mai assegnato in automatico |
| Locale | `local` | Fiera con qualifica locale (assegnata dal Comune); evento comunale; evento di un singolo canile, gattile, negozio, club. **Valore predefinito** quando non c'è una base documentata |

Ogni evento riporta anche `level_basis`, con valori: `official_qualification` (calendario regionale o di federazione), `federation_title` (CACIB, CAC, FIFe), `declared_metrics` (numeri di espositori o visitatori verificati sul sito dell'organizzatore), `organizer_claim` (l'organizzatore si definisce "internazionale"), `curated` (scelta motivata del curatore), `default`.

Regole di assegnazione:
1. Con `official_qualification` o `federation_title` il livello è quello ufficiale.
2. Con `organizer_claim` il livello è **limitato a regionale** finché non si trova un documento. Il motivo: "internazionale" è una parola di marketing molto usata dagli organizzatori.
3. Con `declared_metrics` si applicano le soglie del 2002 (sopra) ai numeri dichiarati e si segna la fonte nella nota di curatela.
4. Se l'evento è una tappa di un circuito (es. Quattrozampeinfiera, 5 città), ogni tappa ha il suo livello: la qualifica è attribuita per singola manifestazione dalla Regione che la ospita. **Non ho trovato Quattrozampeinfiera Milano nei due elenchi lombardi 2026 che ho letto** (3° aggiornamento regionale e 2° nazionale), quindi oggi il suo livello resterebbe provvisorio. Causa non verificata.
5. Un evento nazionale non diventa per questo "importante" per tutti: per questo nella ricerca il livello comanda la **visibilità**, non l'ordinamento.

Non uso numeri di espositori o visitatori come criterio principale perché sono quasi sempre autodichiarati; vanno nel campo `declared_attendance` (facoltativo) solo come informazione.

### 2.3 Regola di visibilità

`R` è il raggio scelto dall'utente nel radar (5, 10, 25, 50 km). Il raggio dell'utente è sempre un minimo: un evento entro `R` si vede sempre, qualunque livello.

| Livello | Si mostra se | Finestra nel futuro | Dove |
| --- | --- | --- | --- |
| Locale | distanza ≤ `R` | 60 giorni | "In programma" |
| Provinciale | distanza ≤ max(`R`, 50 km) | 90 giorni | "In programma" |
| Regionale | stessa regione dell'utente **oppure** distanza ≤ max(`R`, 150 km) | 150 giorni | "In programma" |
| Nazionale | sempre | 270 giorni | riquadro "Grandi eventi" |
| Internazionale | sempre | 365 giorni | riquadro "Grandi eventi" |

Note:
- I valori sono parametri lato server (come le soglie di Segnala!, `RADAR_REPORT_*`), modificabili senza una nuova build: ad esempio `EVENTS_PROVINCIAL_KM`, `EVENTS_REGIONAL_KM`, `EVENTS_WINDOW_DAYS_<LIVELLO>`.
- La condizione "stessa regione" richiede di sapere la regione dell'utente. Fase A: solo soglie in chilometri. Fase B: regione ricavata dal comune più vicino alla posizione, con la tabella dei comuni ISTAT con coordinate del centro (la licenza dei confini ISTAT va verificata: **non verificata**).
- "Sempre" non vuol dire senza limiti: un evento nazionale in Sicilia mostrato a un utente di Milano senza un limite temporale riempirebbe la pagina. Il riquadro "Grandi eventi" ha un massimo di voci (suggerito 10) e un interruttore "Solo vicino a me" che applica anche a loro il raggio.
- Gli eventi `audience = 'professional'` (fiere B2B, congressi) non compaiono nell'elenco generale.

## 3. Motore di ricerca

### 3.1 Modello dati

Una riga di `events` è una **edizione** (una data concreta in un luogo). Le serie annuali o periodiche stanno in `event_series`. Lo schema segue le convenzioni esistenti: RLS attiva senza policy e accesso solo dal backend con la service-role key.

```sql
create table if not exists public.event_series (
    id uuid primary key default gen_random_uuid(),
    name text not null,                    -- "Petsfestival"
    organizer_name text,
    recurrence_rrule text,                 -- RFC 5545, solo per ricorrenze regolari (Fase C)
    recurrence_exdates date[] not null default '{}',
    created_at timestamptz not null default now()
);

create table if not exists public.events (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,             -- "petsfestival-cremona-2026"
    series_id uuid references public.event_series(id),
    edition_label text,                    -- "12ª edizione", opzionale
    title text not null,
    description text,                      -- breve, scritto da noi (niente testo copiato)
    event_type text not null,              -- codici della sezione 1
    level text not null default 'local',   -- local|provincial|regional|national|international
    level_basis text not null default 'default',
    audience text not null default 'public',        -- public|professional
    species text[] not null default '{}',           -- vuoto = tutte
    starts_on date not null,
    ends_on date not null,
    starts_at timestamptz,                 -- facoltativi (orari noti)
    ends_at timestamptz,
    is_free boolean,                       -- null = non noto
    venue_name text,
    address_label text,
    latitude double precision,
    longitude double precision,
    location_precision text not null default 'exact',  -- exact|comune|none
    comune_istat text,                     -- 6 cifre: prime 3 = provincia
    province_istat text,                   -- 3 cifre
    province_code text,                    -- sigla, per l'etichetta
    region_istat text,                     -- 2 cifre
    organizer_name text,                   -- solo enti e società, mai persone fisiche
    organizer_kind text,                   -- federation|club|municipality|asl|shelter|association|fair_operator|company
    source_url text not null,              -- pagina ufficiale dell'evento o dell'organizzatore
    source text not null,                  -- chiave in data_sources (es. 'curated', 'regione_lombardia_fiere')
    license text not null,                 -- licenza o base d'uso dichiarata della fonte
    status text not null default 'draft',  -- draft|published|cancelled|postponed|rejected
    verification_status text not null default 'unverified',   -- unverified|verified
    verified_by text,                      -- owner|automatic|community|organizer
    last_verified_at timestamptz,
    declared_attendance integer,           -- solo informativo
    fingerprint text,                      -- per la deduplica (3.5)
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (ends_on >= starts_on),
    check (location_precision = 'none' or (latitude is not null and longitude is not null))
);

-- Provenienza: un evento può avere più fonti, la scheda mostra quella a priorità più alta.
create table if not exists public.event_sources (
    id uuid primary key default gen_random_uuid(),
    event_id uuid not null references public.events(id) on delete cascade,
    source text not null,                  -- data_sources.id
    source_event_id text,                  -- id nella fonte, se esiste
    source_url text not null,
    license text not null,
    priority smallint not null default 50, -- federazione 90, organizzatore 80, calendario regionale 70, comunità 30
    fetched_at timestamptz not null default now(),
    content_hash text,
    unique (source, source_event_id)
);
```

`data_sources` (già esistente) registra per ogni fonte licenza, attribuzione e data dell'ultimo import, come per il radar. Le fonti con attribuzione obbligatoria (CC BY) compaiono in Impostazioni → Info → Fonti dati.

Perché `events` e non `local_activities`: `local_activities` mescola servizi ed eventi, ha un solo campo `category` di testo libero (oggi la convenzione "contiene `nazionale`" è l'unico modo per avere un livello) e non ha luogo amministrativo, specie, stato di verifica né provenienza. I servizi senza data restano lì; la pagina smette di leggere gli eventi da quella tabella. `isNationalActivity` nel client verrà sostituita dal campo `level`.

Accesso: **endpoint del backend**, non lettura diretta di Supabase dal client (come oggi fa `LocalActivitiesRepository`). Motivi: applicare le regole di visibilità in un solo posto e non offrire una copia scaricabile dell'archivio (rilevante per le licenze, sezione 5).

### 3.2 Ricerca

`GET /events` con token utente, come `/local-services/places`:

| Parametro | Significato |
| --- | --- |
| `latitude`, `longitude`, `radius_km` | Ricerca per raggio. Applica la tabella di visibilità della sezione 2.3 |
| `scope` | `nearby` (predefinito: regole di visibilità), `region` (con `region_istat`), `province` (con `province_istat`), `national` (solo nazionali e internazionali, qualunque luogo) |
| `from`, `to` | Periodo. Predefinito: oggi, fino alla finestra del livello |
| `species` (multi), `types` (multi), `levels` (multi) | Filtri |
| `order` | `date` (predefinito), `distance`, `importance` |
| `limit`, `cursor` | Paginazione (cursore su data e id) |

Risposta: eventi con `distance_km` (se la posizione è nota), `level`, `level_basis`, `verification_status`, `last_verified_at`, fonte e link. Mai l'identità di chi ha segnalato.

Ricerca per raggio: riquadro in latitudine e longitudine (come il radar) e poi distanza esatta (haversine) in Python sui risultati. Ricerca per provincia o regione: uguaglianza su `province_istat` e `region_istat`. Nazionale: filtro sul livello, senza posizione. Per specie: `species = '{}' or species && :list`. Per periodo: `ends_on >= :from and starts_on <= :to`.

### 3.3 PostGIS oppure latitudine/longitudine

**Raccomandazione: latitudine, longitudine e riquadro, senza PostGIS** nelle fasi A e B.
- Il volume è piccolo: nell'ordine delle migliaia di righe l'anno (il solo Piemonte ha 248 fiere nel 2026, di cui poche pet). Una scansione con indice su date costa meno di un millisecondo di più.
- È lo stesso schema del radar (`radar_places_osm`, `radar_places_open`), con la stessa logica di distanza già testata in `list_nearby_radar_places.py`.
- Meno dipendenze per i test in memoria, che oggi non hanno un database spaziale.
- PostGIS esiste su Supabase e si attiva dal pannello Estensioni, con `geography(Point)`, indice GiST e `ST_DWithin` ([guida Supabase](https://supabase.com/docs/guides/database/extensions/postgis)); non ho verificato limiti del piano gratuito su questa estensione. Conviene solo se si superano decine di migliaia di righe o servono poligoni (eventi itineranti, percorsi).

### 3.4 Indici consigliati

```sql
create index if not exists events_active_idx on public.events (ends_on, starts_on) where status = 'published';
create index if not exists events_level_idx on public.events (level, starts_on) where status = 'published';
create index if not exists events_position_idx on public.events (latitude, longitude) where status = 'published';
create index if not exists events_region_idx on public.events (region_istat, starts_on) where status = 'published';
create index if not exists events_province_idx on public.events (province_istat, starts_on) where status = 'published';
create index if not exists events_species_idx on public.events using gin (species);
-- deduplica (richiede l'estensione pg_trgm, disponibile su Supabase):
create index if not exists events_title_trgm_idx on public.events using gin (title gin_trgm_ops);
```

Un indice parziale con `ends_on >= current_date` non è possibile (`current_date` non è immutabile): il filtro sulle date resta nella query.

### 3.5 Ordinamento

| Ordine | Regola | Quando |
| --- | --- | --- |
| `date` (predefinito) | `starts_on`, poi distanza, poi livello decrescente | Elenco "In programma" |
| `distance` | distanza, poi data | Utente che cerca "il più vicino" |
| `importance` | livello decrescente, poi data, poi distanza | Riquadro "Grandi eventi" |

Il livello non entra mai in un ordinamento a pagamento: nessuna sponsorizzazione in v1 (stessa regola di `docs/compliance/06_radar_mappe_sponsorizzazioni.md`).

### 3.6 Eventi passati e ricorrenti

- **Passati**: restano nella tabella e non compaiono (`ends_on < oggi`). Servono per ricostruire le serie e per sapere quando è prevista la prossima edizione. Conservazione 24 mesi, poi pulizia dal flusso mensile (come `scripts/radar/cleanup_reports.py`).
- **Edizioni annuali**: una riga per edizione, legate da `series_id`. Un'edizione futura **si pubblica solo con data confermata da una fonte**: la serie può ricordare al curatore "edizione 2027 non ancora annunciata", ma l'app non mostra date dedotte.
- **Ricorrenze regolari** (passeggiata ogni domenica): Fase C. `recurrence_rrule` nella serie; il backend espande le occorrenze della finestra richiesta in memoria con `dateutil.rrule` (nessun job), tenendo conto di `recurrence_exdates`. In Fase A una passeggiata ricorrente si inserisce come righe separate.
- **Annullati o rinviati**: `status = 'cancelled'` o `'postponed'` e l'evento resta visibile con l'etichetta, se la fonte lo dice.
- **Verifica periodica**: ogni evento pubblicato va ricontrollato 30 giorni prima dell'inizio (script che elenca quelli con `last_verified_at` più vecchio). In app compare sempre "Verifica sul sito dell'organizzatore" e la data dell'ultima verifica.

### 3.7 Deduplica dello stesso evento da fonti diverse

L'identità di un evento è: **sovrapposizione delle date + stesso luogo + titolo simile**.

1. `fingerprint` = `starts_on` + comune (o coordinate arrotondate a 0,01°) + titolo normalizzato (minuscole, senza accenti, senza anno, ordinali tipo "68^", parole generiche "fiera", "edizione", "festival", "esposizione").
2. Candidato doppione se: intervalli di date che si sovrappongono, distanza ≤ 2 km oppure stesso comune, e somiglianza del titolo (`similarity()` di `pg_trgm`) ≥ 0,5. Il valore va tarato su un campione, come è stato fatto per i luoghi (`docs/features/radar_dedup_sample.md`).
3. **Fusione automatica** solo se oltre alla somiglianza c'è lo stesso dominio nel `source_url` oppure lo stesso organizzatore. Negli altri casi il candidato va in una coda di revisione (`event_duplicate_candidates`) e decide il curatore.
4. Si fonde aggiungendo una riga in `event_sources`, **senza sovrascrivere**. I campi dell'evento canonico vengono dalla fonte con priorità più alta; per le date vince la fonte più vicina all'organizzatore (federazione, organizzatore) su calendari terzi, e un conflitto sulle date mette l'evento in `unverified`.
5. Un evento rifiutato dal curatore resta come `rejected` con la sua `source`, in modo che l'import successivo non lo riproponga (stesso schema di `radar_place_overrides`).

## 4. Fonti dati

### 4.1 Sintesi per priorità

| Priorità | Fonte | Perché |
| --- | --- | --- |
| 1 | **Inserimento curato** (file nel repository + script) | Zero dipendenze legali, qualità massima, subito |
| 2 | **Calendari fieristici regionali** (Lombardia, Piemonte, poi le altre) | Qualifica ufficiale per ogni fiera; atti pubblici |
| 3 | **ENCI e ANFI** (esposizioni, raduni, prove) | Il nucleo del mondo cinofilo e felino; dopo permesso scritto |
| 4 | **Siti delle fiere pet principali** | Conferma date e luoghi; solo per verifica e link |
| 5 | **Contributi di utenti e organizzatori** | L'unica via per adozioni, open day, microchip day, passeggiate |
| 6 | Feed turistici open data (Umbria, Firenze) | Licenza aperta ma pochissimi eventi pet |

### 4.2 Fonti verificate o parzialmente verificate

| Fonte | URL | Formato | Licenza o termini | Copertura | Affidabilità | Sforzo | Stato |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **ENCI, calendario esposizioni** | https://www.enci.it/manifestazioni-ed-eventi/calendario-esposizioni | Pagina HTML con filtri tipo (Internazionali, Nazionali, Regionali, Speciali, Raduni), mese, anno (2023-2027), razza per i raduni; pulsante di stampa. Per ogni voce: tipo, luogo, provincia, date, comitato organizzatore, contatti, note, razze. **Nessun iCal né RSS trovato** | Nota di copyright generica: testi, loghi e design "coperti dalla legge sul Diritto d'Autore"; chi invia materiale a ENCI le attribuisce diritti illimitati. **Riuso del calendario non permesso né vietato esplicitamente: va chiesto per iscritto** ⚖️ | Tutta Italia, tutte le esposizioni riconosciute | Alta (fonte ufficiale). Avviso del sito: le speciali compaiono solo dopo la ratifica delle giurie | Medio: scraping HTML, ma **non senza permesso** | **V** |
| **ENCI, calendario prove** | https://www.enci.it/manifestazioni-ed-eventi/calendario-prove | HTML con filtro per tipo di prova (agility, obedience, rally-o, flyball, dog dancing, mondioring, prove di caccia, pastorizia, ricerca) e anno | Come sopra | Tutta Italia; titoli CAC, CACIT, internazionale, mondiale | Alta | Medio, stesso permesso | **V** |
| **ENCI, portale Gestione Eventi** | https://show.enci.it | Iscrizioni, cataloghi, risultati; pagine di dettaglio per evento (`/Show/Details/<id>`) | Avviso su foto e riprese ai partecipanti; nessun termine di riuso | Eventi con iscrizioni online | Alta | Alto, e inutile se si ottiene l'accordo su enci.it | **V** |
| **ANFI, calendario esposizioni** | https://www.anfitalia.it/eventi-expo/eventi-calendario-expo | Elenco HTML: titolo e data, con pagina di dettaglio | "Copyright © 2005-2026 ANFI"; nessuna licenza di riuso | Esposizioni feline in Italia | Alta | Basso (poche voci l'anno), dopo permesso | **V** |
| **FCI** (CACIB) | https://www.fci.be | Il regolamento FCI dice che la FCI "stabilisce e pubblica il calendario" delle esposizioni con CACIB | Non verificata | Esposizioni internazionali nel mondo | Alta | Non valutato | **P** (calendario non aperto) |
| **FIFe** | https://fifeweb.org | Calendario delle esposizioni | Non verificata | Mondo | Alta | Non valutato | **P** |
| **Calendario fiere Regione Lombardia** | https://www.regione.lombardia.it/attivita-produttive-imprese/fiere | PDF (Excel stampato) di decreti, in tre allegati (internazionali, nazionali, regionali), con aggiornamenti numerati nel corso dell'anno. Colonne: città, nome, data inizio, data fine, codice settore, organizzatore e contatti. **La qualifica è data dall'allegato** | **Nessuna licenza dichiarata** nella pagina. Gli atti ufficiali delle amministrazioni sono esclusi dal diritto d'autore (art. 5 L. 633/1941) e i dati pubblicati senza licenza sono aperti per impostazione predefinita (art. 52 c. 2 CAD): da confermare ⚖️ | Lombardia, tutti i settori. **Contiene fiere pet reali**: Petsfestival, Cremona, 17-18/10/2026 (nazionale); PET in FIERA, Pavia, 16-17/05/2026 (regionale); Sagra regionale degli uccelli, Almenno San Salvatore, 09/08/2026 (regionale); Travagliatocavalli, Travagliato, 30/04-03/05/2026 (nazionale) | Alta per le date ufficiali; l'elenco è aggiornato per decreto, non in tempo reale. Non c'è un settore "animali": serve filtro per parole chiave nel nome | Medio-alto: PDF a righe sfalsate, indirizzi e telefoni dell'organizzatore nello stesso blocco; estraibile con `pdftotext -layout` e controllo manuale | **V** (letti due PDF 2026) |
| **Calendario fiere Regione Piemonte** | https://www.regione.piemonte.it/commercio/fiere | PDF del calendario più un motore di ricerca con filtri per tipo (fiere o sagre), qualifica (locale, regionale, nazionale, internazionale), provincia, mese. Le sintesi riportano anche una mappa nel geoportale | Licenza **non dichiarata** nelle pagine che ho letto; una sintesi parla di esportazione e documentazione della licenza, **non confermata** | Piemonte: 2026 con 10 internazionali, 48 nazionali, 50 regionali, 140 locali, più 247 sagre | Alta; avviso: dati soggetti a modifiche per motivi organizzativi | Medio (HTML ricercabile, possibile export da verificare) | **P** |
| **Calendario fiere Regione Veneto** | https://www.regione.veneto.it/web/attivita-produttive/calendario-fieristico-regionale | Solo PDF, aggiornato il 12/05/2026 (qualifiche internazionale, nazionale, locale) | Nessuna licenza indicata | Veneto | Alta | Medio (PDF); fiere pet non cercate | **P** |
| Regione Toscana, calendario fiere | https://dati.toscana.it/dataset/rt-calfiere2018 | JSON | **CC BY-SA** (con condivisione alle stesse condizioni) | Solo anno **2018** | Obsoleto | Non conviene | **V** |
| Altre Regioni (Emilia-Romagna, Lazio, Campania, Sicilia...) | Esistono calendari e atti (es. calendario fieristico nazionale compilato dalla Conferenza delle Regioni) | PDF | Non verificata | | | Da fare regione per regione | **S** |
| Conferenza delle Regioni, "calendario fiere internazionali" | `calendariofiereinternazionali.it` (indicato nella proposta del 2014) | Sito web | Non verificata; non ho controllato che esista ancora | Fiere internazionali | | | **S** |
| **Open data Umbria, Eventi e manifestazioni** | https://dati.regione.umbria.it/dataset/eventi-e-manifestazioni | CSV, JSON, GeoJSON, RDF, KML (IT, DE, EN); ~5,7 MB; titolo, descrizione, date, latitudine, longitudine, comune, codice ISTAT, indirizzo | **CC BY 4.0** | Umbria, eventi turistici generici | Dichiarato aggiornato ogni giorno, ma la pagina mostra "ultima modifica" febbraio 2023: **da controllare**. Non ho cercato eventi pet | Basso tecnicamente, resa bassa per i pet | **V** (licenza e formati) |
| **Open data Firenze, Eventi a Firenze** | https://opendata.comune.fi.it/page_dataset_show?id=eventi-a-firenze | CSV, GeoJSON, SHP, API CKAN; eventi dei prossimi 30 giorni, aggiornamento giornaliero | **CC BY 4.0** | Firenze. Prova del 03/10/2026: **134 eventi, nessuno dedicato agli animali** (6 corrispondenze di parole chiave, tutte falsi positivi: musei, teatro) | Alta per ciò che contiene | Basso | **V** |
| Open data Puglia, Eventi in Puglia | https://dati.puglia.it/ckan/dataset/eventi-in-puglia | CSV, XML, ODS | Italian Open Data License 2.0 | Puglia; ultima modifica del dataset indicata: 12/12/2019 | **Obsoleto** | Non conviene | **V** |
| Siti delle fiere | https://www.quattrozampeinfiera.it ; https://www.petsfestival.eu ; https://www.fieracavalli.it ; https://www.zoomark.it | HTML | Copyright dell'organizzatore (es. "© BolognaFiere Cosmoprof"); nessun feed iCal | Le fiere principali | Alta (fonte primaria della data) | Solo per verifica manuale e link | **V** per il sito Quattrozampeinfiera e Zoomark; **P** per gli altri |

Date lette sul sito ufficiale Quattrozampeinfiera il 2026-10-03 (organizzatore BolognaFiere Cosmoprof): Milano (Parco Esposizioni Novegro) 3-4/10/2026; Torino (Scalo Eventi) 14-15/11/2026; Roma (Fiera Roma) 13-14/02/2027; Padova (Padova Fiere) 6-7/03/2027; Napoli (Mostra d'Oltremare) 10-11/04/2027. **Una ricerca web riportava un calendario diverso per il 2026** (tappe a Roma, Napoli, Torino e Milano in altre date): il programma cambia, quindi ogni data va ricontrollata il giorno in cui si inserisce l'evento. Per questo non ho inserito nulla.

### 4.3 Fonti che sconsiglio

- **Facebook, Instagram, Eventbrite, Meetup, aggregatori commerciali di eventi e sagre**: termini d'uso restrittivi (supposti, non letti), nessun riuso permesso, API incerte. Un'unica fonte di questo tipo apre il rischio contrattuale descritto in 5.2.
- **Il vecchio percorso OSM**: gli eventi non sono un dato OpenStreetMap; non ci sono tag affidabili.

### 4.4 Inserimento manuale curato dal proprietario

Il percorso più semplice e più sicuro per la Fase A.
- **Come**: file `data/events/curated/*.yaml` nel repository (fatti pubblici: titolo, date, luogo, ente organizzatore, link ufficiale; **nessun dato personale**, nessun telefono né email) e script `scripts/events/import_curated.py` che valida (data, tipo, livello con base, `source_url` obbligatorio, `last_verified_at`) e scrive su Supabase con `on conflict` sullo `slug`. Revisione tramite pull request.
- **Alternativa a costo zero**: Supabase Studio (editor di tabella): rapido ma senza validazioni. Utile per correzioni.
- **Pannello**: una piccola pagina nell'app, riservata alla lista degli sviluppatori già esistente, per aggiungere e correggere eventi. Fase C: non serve per partire.
- **Pro**: qualità alta, nessuna licenza da negoziare. **Contro**: copre poco e dipende da una persona. Con 30-60 eventi l'anno (le fiere pet e le esposizioni principali) è sostenibile; per le esposizioni ENCI di tutta Italia servono le fonti della Fase B.

### 4.5 Segnalazione degli utenti ("Segnala!") con conferma di comunità

Il meccanismo del radar (5 conferme, pseudonimi, limite di 5 segnalazioni al giorno, nessun testo libero, regole d'uso accettate, vedi `docs/features/radar_places_overpass.md`) si adatta solo in parte agli eventi.
- **Tipi proposti**: "Evento mancante" (tipo da elenco chiuso, titolo breve, date, posizione scelta sulla mappa), "Evento annullato o rinviato", "Data sbagliata". Specie da elenco.
- **Differenze rispetto ai luoghi**:
  1. Un evento è a tempo: cinque conferme che arrivano dopo l'evento non servono. La conferma di "esiste" è difficile per chi non ha una fonte in mano.
  2. Il rischio è diverso: eventi falsi, truffe, **adozioni o vendita di animali presentate come eventi** ⚖️, pubblicità mascherata.
  3. Il nostro parere sui contributi (`docs/compliance/07_contributi_utenti.md`) esclude testo libero, link e contatti. Un evento ha invece bisogno del **link alla fonte**: va chiesto un nuovo parere a NORMATIVA su un campo URL (consentito solo se il dominio non è un social network, e salvato come dato dell'evento, non di chi segnala).
- **Raccomandazione**: le segnalazioni **non pubblicano da sole**. Entrano in una coda di revisione del curatore, che verifica sulla fonte; le 5 conferme servono solo come segnale di priorità. Un evento approvato mostra "Segnalato dagli utenti, verificato da VetApp". Chi segnala resta pseudonimo (stessa chiave HMAC `RADAR_PSEUDONYM_KEY`).
- Rimane l'opzione "pubblica dopo 5 conferme" per gli eventi locali, con etichetta "in attesa di conferma" come per i luoghi: è la linea di Segnala!, ma con i rischi sopra. Decisione del proprietario (sezione 7).

### 4.6 Invio da parte degli organizzatori

Modulo web (non nell'app) con: ente, email di contatto (verificata con un link, **non pubblicata**), tipo, date, luogo, link al sito ufficiale. Moderazione prima della pubblicazione; per gli enti ENCI e ANFI la verifica avviene confrontando con i loro calendari. Etichetta "Inserito dall'organizzatore". Serve un'informativa (dati di contatto dell'organizzatore) e un limite alle richieste. Non è una sponsorizzazione e non dà priorità in elenco.

## 5. Aspetti legali in breve ⚖️

Non sono un legale: i punti che seguono sono cose da verificare, in ordine di importanza.

### 5.1 Diritti su calendari e banche dati

- **Fatti** (nome, data e luogo di un evento) non sono opere protette dal diritto d'autore; lo sono i **testi e le immagini** che li descrivono. Per questo la descrizione di ogni evento va scritta da noi e non copiata.
- **Diritto sui generis del costitutore** (art. 102-bis L. 633/1941, direttiva 96/9/CE): protegge chi fa un investimento rilevante per *ottenere, verificare o presentare* i dati, contro l'estrazione o il reimpiego di tutta o di una parte sostanziale. La Corte di giustizia (sentenze 9 novembre 2004 su calendari di partite e di corse: C-46/02, C-203/02 e altre) ha escluso che l'investimento per **creare** i dati, come il calendario di un campionato, sia protetto ([comunicato della Corte](https://curia.europa.eu/en/actu/communiques/cp04/aff/cp040089en.pdf)). I calendari delle federazioni, che *decidono* date e luoghi, sono un caso vicino: il rischio sul diritto sui generis è probabilmente basso, ma **non certo**. Un aggregatore che investe per raccogliere e verificare quegli stessi dati (un sito di eventi) è invece più protetto. Un utilizzo "non sostanziale" e ripetuto di piccole parti non è comunque un'autorizzazione generale.
- **Atti di pubbliche amministrazioni**: i testi degli atti ufficiali dello Stato e delle amministrazioni non sono protetti dal diritto d'autore (art. 5 L. 633/1941) e i dati pubblicati senza licenza si intendono aperti (art. 52 c. 2 CAD, [commento](https://brocardi.it/codice-dell-amministrazione-digitale/capo-v/sezione-i/art52.html)), salvo i dati personali. I calendari fieristici regionali sono approvati con decreto: questa è la fonte più solida sul piano del riuso. Va confermato caso per caso (alcune pagine indicano licenze o riserve proprie).

### 5.2 Scraping e termini d'uso

- Anche quando non esiste un diritto sul database, il sito può vietare l'estrazione **per contratto** nei suoi termini d'uso: la sentenza Ryanair (C-30/14, 2015, [commento](https://portolano.it/news/ecj-clarifies-database-directive-scope-in-screen-scraping-case)) riconosce questa possibilità per le banche dati non protette. Il rischio non è solo di diritto d'autore.
- L'eccezione di *text and data mining* (art. 70-ter e 70-quater L. 633/1941, d.lgs. 177/2021) riguarda l'analisi automatica per generare informazioni, **non** la pubblicazione di contenuti; e per usi commerciali il titolare può escluderla con una riserva leggibile da una macchina. Non la considero una base per pubblicare calendari altrui.
- Se si fa scraping: rispettare `robots.txt`, identificarsi con User-Agent e contatto (come `OVERPASS_USER_AGENT`), limitare le richieste, scaricare al massimo una volta al giorno o alla settimana, conservare solo fatti e link.
- **ENCI**: la nota di copyright riserva i diritti e non offre una licenza di riuso. Prima di qualsiasi import, **chiedere per iscritto** a ENCI e ad ANFI l'autorizzazione a riportare data, luogo, tipo e link al loro calendario, con citazione della fonte. Una bozza di richiesta posso prepararla io; la firma e l'invio spettano al proprietario. Senza permesso: solo link e inserimento curato dei singoli eventi più rilevanti, verificati sul sito dell'organizzatore.

### 5.3 Nomi, loghi, link

- Nomi di fiere e di enti come **testo** per identificare l'evento: generalmente accettabile come uso descrittivo e leale (art. 21 codice della proprietà industriale, da verificare). **Niente loghi, immagini, locandine né foto** copiate dai siti.
- Non lasciar intendere un accordo o un patrocinio con ENCI, ANFI, ENPA o con una fiera: dicitura "Fonte" e link, nessun badge che somigli a un marchio. Un evento "sponsorizzato" nel radar significherebbe pubblicità (vedi 06).
- Link alla fonte: obbligatorio per modello (`source_url`). Il rinvio a una pagina pubblica non è in sé una violazione.
- Esonero di responsabilità sull'esattezza di date e luoghi: "Verifica sul sito dell'organizzatore"; mostrare `last_verified_at`.

### 5.4 Dati personali

- I PDF regionali riportano nello stesso blocco telefono, email e talvolta il nome di una persona fisica (ditta individuale). **Non copiare i contatti**: si salvano solo la denominazione dell'ente o della società e il link ufficiale.
- Il repository è pubblico: i file `data/events/curated/` e le tabelle di esempio contengono solo fatti pubblici.
- Per contributi e organizzatori: pseudonimo come per Segnala! (HMAC), email di verifica non pubblicata, conservazione limitata, informativa aggiornata.

### 5.5 Sicurezza degli animali

Eventi di adozione, vendita (mostre scambio, terraristica) e microchip: pubblicare solo se l'organizzatore è un ente identificabile (rifugio, associazione registrata, ASL, Comune) o una fiera in un calendario ufficiale. Evitare eventi che sono in sostanza vendita di animali da parte di privati ⚖️.

## 6. Piano in fasi

Le stime sono in giorni di sviluppo (±30%) e non comprendono il tempo del proprietario per raccogliere o approvare gli eventi.

### Fase A: minima rilasciabile (5-6 giorni)

- Migrazione `events` + `event_sources` + tabella `istat_comuni` (codici, province, regioni, sigla; centro del comune facoltativo) con script di import da file ISTAT (0,5-1 giorno).
- Dominio, repository (in memoria e Supabase), servizio `list_events` con le regole di visibilità della 2.3, route `GET /events`, test unitari e di integrazione (2 giorni).
- Flutter: sezione "In programma" che legge il nuovo endpoint; riquadro "Grandi eventi"; badge del livello e dell'ultima verifica; filtro specie e tipo; scheda con link alla fonte; stato vuoto onesto mantenuto (2 giorni).
- `data/events/curated/` + `scripts/events/import_curated.py` con validazione e dry-run (0,5-1 giorno).
- Aggiornamento di `radar_places_overpass.md` e testo "Fonti dati" in app (0,5 giorno).
- **Cosa serve dal proprietario**: (1) approvare livelli e regole di visibilità (sezione 7); (2) fornire o approvare una prima lista di 20-40 eventi con link ufficiale, oppure autorizzarmi a prepararla dai calendari verificati (sezione 4.2) per la sua revisione; (3) decidere se includere equestre e professionali; (4) confermare il contatto per le segnalazioni di errore (oggi l'indirizzo di supporto indicato in "Fonti dati"); (5) inviare la richiesta di permesso a ENCI e ANFI (non blocca la Fase A).

### Fase B: fonti automatiche (6-9 giorni)

- Parser dei calendari regionali: Lombardia (PDF) e Piemonte (HTML o export), 1,5-2 giorni ciascuno; ogni altra Regione 1 giorno più la verifica della licenza.
- Filtro per parole chiave e coda di revisione: nessun evento pubblicato senza approvazione del curatore (1-2 giorni; un piccolo comando o una pagina di revisione).
- Importatori ENCI e ANFI: 1-1,5 giorni, **solo dopo il permesso scritto**.
- Deduplica con `pg_trgm`, `event_duplicate_candidates` e taratura su un campione (2 giorni).
- Regione dell'utente dal comune più vicino per la regola "stessa regione" (1 giorno).
- GitHub Action: import mensile come per il radar, più un controllo settimanale dei prossimi 30 giorni; verifica a 30 giorni dall'inizio (0,5 giorno).
- **Cosa serve dal proprietario**: l'esito della richiesta a ENCI e ANFI; la scelta delle Regioni da coprire per prime (suggerisco quelle dei primi utenti); una persona che revisioni la coda (stima: 30 minuti a settimana); nessun costo (GitHub Actions e Supabase gratuiti: poche migliaia di righe sono pochi MB su 500).

### Fase C: contributi e ricorrenze (7-10 giorni)

- "Segnala un evento" riusando la struttura di Segnala! (tabella `event_user_reports`, pseudonimi, limiti, regole d'uso), con coda di revisione e priorità per numero di conferme (3-4 giorni).
- Modulo per gli organizzatori con email verificata (2 giorni).
- Pannello di inserimento e correzione nell'app per gli sviluppatori (1-2 giorni).
- Serie e ricorrenze regolari con `rrule` e promemoria dell'app ("aggiungi ai promemoria", se desiderato) (1-2 giorni).
- **Cosa serve dal proprietario**: nuovo parere di NORMATIVA (campo URL, dati degli organizzatori, informativa, regole d'uso aggiornate, canale di contestazione dei titolari); decisione sulla pubblicazione automatica o solo moderata (sezione 7); testo del modulo per gli organizzatori.

## 7. Decisioni del proprietario

| # | Decisione | Raccomandazione |
| --- | --- | --- |
| 1 | Quanti livelli | Cinque valori, ma dichiarare che "provinciale" è una scelta nostra e si assegna solo per ente organizzatore provinciale. Alternativa: solo i quattro ufficiali, più semplice da spiegare |
| 2 | Regole di visibilità (km e finestre della 2.3) | Provinciale 50 km, regionale 150 km o stessa regione, nazionale e internazionale sempre in "Grandi eventi" con massimo 10 voci. Parametri modificabili dal server |
| 3 | Livello senza documento | Mai oltre "regionale" per autodichiarazioni; "locale" se non c'è base |
| 4 | Fiere professionali (B2B) e congressi veterinari | Esclusi dall'elenco pubblico (campo `audience`); eventualmente un filtro "Professionale" in futuro |
| 5 | Eventi equestri e di altre specie (acquari, terraristica, uccelli) | Includere acquariofilia e ornitologia solo se in calendari ufficiali; equestre fuori dalla v1 (non è il cuore pet-owner), tipo già previsto nello schema |
| 6 | Fonte della Fase A | Inserimento curato da file nel repository, con revisione tramite PR; niente scraping |
| 7 | Permesso a ENCI e ANFI | Inviare la richiesta scritta ora (preparo io la bozza); intanto solo link agli eventi principali |
| 8 | Calendari regionali | Importarli con revisione manuale, partendo da Lombardia e Piemonte; confermare con NORMATIVA la base (atti pubblici, art. 52 CAD) |
| 9 | Segnalazioni degli utenti | Coda di revisione con le conferme come priorità; pubblicazione automatica con 5 conferme solo per eventi locali e solo dopo il parere sul campo URL |
| 10 | Invio dagli organizzatori | Sì, in Fase C, moderato, senza priorità in elenco |
| 11 | Sponsorizzazione o evidenza a pagamento di eventi | No nella v1 (coerenza con 06) |
| 12 | Conservazione degli eventi passati | 24 mesi, poi cancellazione dal flusso mensile |
| 13 | Verifica periodica | Controllo a 30 giorni dall'inizio per ogni evento pubblicato; l'app mostra sempre "Verifica sul sito dell'organizzatore" e la data |
| 14 | PostGIS | No: latitudine, longitudine e riquadro come il radar; rivalutare sopra le decine di migliaia di righe |
| 15 | Tipi di evento ammessi senza fonte ufficiale (passeggiate, corsi, mercatini, benefici) | Ammessi solo dalla Fase C, con moderazione. Adozioni e vendita di animali solo da enti identificabili |
| 16 | Parere legale esterno | Una revisione mirata dei punti ⚖️ della sezione 5 prima della Fase B (riuso dei calendari, termini d'uso, uso dei nomi) |

## 8. Cosa non ho verificato

- Versione attuale del regolamento ENCI (letta una copia 2008 ospitata da ANMVI; i filtri attuali del sito la confermano); regolamento FIFe e calendari FCI e FIFe (solo riassunti di ricerca).
- Licenza o permesso di riuso di ENCI, ANFI, Piemonte, Veneto e Lombardia: nessuna dichiarata; le conclusioni su CAD e art. 5 sono giuridiche e da confermare.
- Se la proposta di intesa Stato-Regioni del 2014 sia stata approvata con quelle soglie; esistenza attuale di `calendariofiereinternazionali.it`.
- Presenza di fiere pet nei calendari di Veneto, Emilia-Romagna, Lazio, Campania e delle altre Regioni; motivo dell'assenza di Quattrozampeinfiera Milano dai due elenchi lombardi 2026.
- Dati su Fieracavalli (5-8/11/2026), SCIVAC Rimini (4-6/06/2027), Zoomark (11-13/05/2027), Petsfestival (organizzatore): da riassunti di ricerca e, per Petsfestival, dal calendario lombardo; non dai siti ufficiali di ciascuno.
- Canicross (CSEN e FISC): citati da una fonte generica; FOI e COM: solo da riassunti.
- Esistenza di calendari centralizzati per adozioni, open day, microchip day, campagne vaccinali delle ASL: non trovati, non cercati sui siti delle singole ASL.
- Licenza dei confini e dell'elenco dei comuni ISTAT; frequenza reale di aggiornamento del feed dell'Umbria; l'esportazione del motore di ricerca del Piemonte.
- Termini d'uso delle piattaforme commerciali di eventi (Eventbrite, Meetup, Facebook): supposti.
