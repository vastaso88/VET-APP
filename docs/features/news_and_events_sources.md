# Curiosità, fiere ed eventi: fonti, termini e come aggiungerne

Ultimo controllo delle fonti: **2026-10-21**. Ambito: Italia (linea principale). Il lavoro
per paese del ramo MULTILANG (PR #25) resta separato: qui il pubblico è la chiave `it`
(snapshot notizie) e le fonti sono dati, non codice, così un altro paese aggiunge le sue
senza toccare il resto.

## 1. Curiosità per i tuoi animali — `GET /news`

Il backend legge i feed RSS, classifica e filtra i titoli (`packages/core/domain/pet_news/`),
li unisce a quelli già in cache senza duplicati e tiene uno **snapshot condiviso** nella
tabella `pet_news_snapshots` (una riga per pubblico, oggi `it`). L'app legge solo da lì.

- **Cache**: Supabase (sopravvive ai riavvii serverless), TTL 120 minuti
  (`NEWS_CACHE_TTL_MINUTES`, 10–720). Il refresh avviene alla lettura, solo se la copia è
  scaduta. Se i feed non rispondono (o non restituiscono nulla di utile) si serve l'ultima
  copia valida (`"stale": true`) e non si riprova per 5 minuti per istanza.
- **Cosa si salva**: titolo, nome della testata, link, data. Niente testo dell'articolo,
  niente immagini (diritti delle foto): la card apre l'articolo sul sito originale.
- **Spegnere un feed senza deploy**: variabile `NEWS_DISABLED_FEEDS=oipa,dogalize`
  (chiavi in `packages/infrastructure/news/feeds.py`). Utile se un editore chiede di
  smettere.
- **Filtri**: fuori tema se non nomina un animale da compagnia; scartati i titoli con
  parole da ricetta/caccia/esperimenti/gioco (stessa lista di prima, ora lato server);
  specie ambigue (coniglio, cavia, rana, cavallo…) solo con contesto da animale domestico.

### Google News: NON usato (conclusione)
- `https://news.google.com/robots.txt` (controllato il 2026-10-21) ha `User-agent: * /
  Disallow: /` con eccezioni che non includono `/rss`.
- I Termini di servizio Google (in vigore dal 30 luglio 2026, https://policies.google.com/terms)
  vietano di «usare mezzi automatizzati per accedere ai contenuti dei servizi in violazione
  delle istruzioni leggibili dalle macchine», quindi un server che scarica `/rss/search` va
  contro il robots.txt. Fonti secondarie descrivono inoltre i feed Google News come pensati
  per uso personale/non commerciale, con obblighi di attribuzione.
- Anche rss2json.com (il proxy usato prima) restituiva 403 anti-bot. Conclusione: per
  un'app commerciale non è chiaro/permesso → **alternativa adottata: feed RSS che gli editori
  stessi pubblicano per essere ripresi**, senza Google in mezzo.

### Feed attivi (tutti controllati il 2026-10-21: RSS valido, `robots.txt` non li vieta)
| Chiave | Fonte | Feed | Natura | Frequenza lettura |
|---|---|---|---|---|
| petsblog | Petsblog | `petsblog.it/feed` | magazine cani/gatti | ogni ≤2 h (alla lettura) |
| amoreaquattrozampe | Amoreaquattrozampe | `amoreaquattrozampe.it/feed/` | magazine animali | idem |
| veterinari-it | Veterinari.it | `veterinari.it/feed` | community veterinaria | idem |
| dogalize | Dogalize | `dogalize.com/feed/` | magazine cani | idem |
| fnovi | FNOVI | `fnovi.it/rss.xml` | federazione ordini veterinari (ente) | idem |
| izsve | IZS delle Venezie | `izsvenezie.it/feed/` | istituto pubblico sanità animale | idem |
| oipa | OIPA Italia | `oipa.org/italia/feed/` | associazione protezione animali | idem |

Termini: nessuno dei siti dichiara nel feed una licenza restrittiva; i feed sono pubblicati
per la ripresa dei titoli. Usiamo il minimo (titolo + link + nome fonte, riconoscibile) con
un'identificazione chiara (`User-Agent: VetApp-NewsReader/1.0`). I termini d'uso completi dei
singoli siti non sono stati letti uno per uno: **rischio residuo basso e gestibile**
(`NEWS_DISABLED_FEEDS` + eventuale richiesta di rimozione). Non sono incluse ANSA (la
categoria animali non ha un feed dedicato), LifeGate (`/feed/` vietato dal robots.txt),
LAV/ENPA (il feed risponde HTML), greenMe (feed generalista).

Per aggiungere una fonte: una riga in `ITALIAN_FEEDS` (`feeds.py`), controllare robots.txt e
termini, aggiungere la riga a questa tabella. Per un altro paese: nuova chiave in
`FEEDS_BY_AUDIENCE` e `?audience=` nella rotta (oggi fissa a `it`).

## 2. Eventi (fiere e incontri pet-friendly)

Tutto converge nella tabella `events` (lettura pubblica RLS, scrittura solo service role) e
passa dalle **stesse regole** (`packages/infrastructure/events/curated_events.py`,
`packages/core/domain/events/rules.py`): link ufficiale obbligatorio, mai social/aggregatori,
nessun dato personale, `level` nazionale/internazionale solo con un documento.

| Canale | Cosa | Licenza/termini | Frequenza |
|---|---|---|---|
| File curati `scripts/events/curated/*.json` (tracciati) e `data/events/curated/*.json` (ignorati da git) | Eventi controllati a mano sul sito ufficiale dell'organizzatore (`verified_on`) | Fatti pubblici (date, luogo, link), testo scritto da noi | a ogni nuovo evento; import settimanale |
| `scripts/events/import_feeds.py` + `scripts/events/sources.json` | Calendari iCal pubblici di enti fiera/Comuni, con filtro per parole chiave | Per fonte, nel registro (`license`, `terms_url`, `checked_on`) | settimanale |
| "Segnala un evento" (app) → `event_submissions` → `scripts/events/moderate_submissions.py` | Proposte degli utenti, pubblicate solo dopo il controllo sul sito dell'organizzatore | Fatti sull'evento; autore mai mostrato | su richiesta |

### Fonti valutate e perché non sono attive
- **ENCI / ANFI (calendari espositivi)**: nessun feed iCal/RSS né condizione di riuso
  trovati (solo regolamenti PDF e pagine HTML): non si fa scraping senza un accordo. Via
  praticabile: eventi singoli nei file curati dalla pagina ufficiale, o richiesta scritta.
- **Eventbrite / Meetup / Facebook**: esclusi dalle regole del progetto (`BLOCKED_SOURCE_DOMAINS`).
- **Dati aperti dei Comuni (dati.gov.it)**: nessun dataset eventi con fiere/animali
  verificato come riusabile; il registro `sources.json` è pronto quando se ne trova uno.
- **Siti degli enti fiera** (Cremona, Bologna, Parma, Verona, Lario): i loro `/feed` sono
  notizie generiche senza date strutturate, non calendari: inutilizzabili per le date.
- **Esotika Pet Show**: nessun calendario machine-readable; le 3 edizioni di novembre 2026
  sono nei file curati, dalle pagine ufficiali.

### Aggiungere un calendario iCal
Voce in `scripts/events/sources.json` (`enabled: true` solo dopo aver letto i termini):
```json
{
  "key": "comune-esempio",
  "name": "Comune di Esempio",
  "url": "https://…/eventi.ics",
  "license": "CC BY 4.0 - Comune di Esempio",
  "terms_url": "https://…/note-legali",
  "checked_on": "2026-10-21",
  "keywords": ["cani", "gatti", "animali", "adozione"],
  "defaults": {"event_type": "other", "city": "Esempio", "province_code": "XX",
               "region": "Lombardia", "organizer_name": "Comune di Esempio",
               "page_url": "https://…/eventi"},
  "enabled": true
}
```
`python scripts/events/import_feeds.py --dry-run` mostra eventi validi e scartati prima di
scrivere. Livello sempre `local`; la descrizione del feed non viene copiata.

### Moderazione delle segnalazioni
```
uv run --with truststore python scripts/events/moderate_submissions.py list
uv run --with truststore python scripts/events/moderate_submissions.py approve <id> --link-checked
uv run --with truststore python scripts/events/moderate_submissions.py reject <id> --note "…"
```
Prima di `approve` aprire il link e verificare date e luogo; con un link social usare
`--source-url` con la pagina dell'organizzatore. Limite: 3 segnalazioni/giorno per utente
(429), solo utenti con accesso; `event_submissions` è cancellata con l'account.

## 3. SQL da eseguire (in `scripts/setup/supabase_schema.sql`, idempotente)
- `pet_news_snapshots` (cache notizie), `event_submissions` (coda moderazione): RLS attiva,
  senza policy → solo service role. Nessuna funzione SECURITY DEFINER nuova.
- Segreti per il workflow `events-import.yml`: gli stessi `RADAR_SUPABASE_URL` e
  `RADAR_SUPABASE_SERVICE_ROLE_KEY` già usati dal radar.
