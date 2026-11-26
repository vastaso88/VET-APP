# Eventi curati

Gli eventi veri stanno in `data/events/curated/` (cartella locale, non nel repository: `/data/` è ignorata da git). I seed finti stanno qui, nel repository.

- `curated/<PAESE>.json` (es. `IT.json`, `GB.json`): eventi **veri**, verificati sul sito ufficiale dell'organizzatore. Importati con `scripts/events/import_curated.py`. Un file per paese, evento con `"country"` (assente = `IT`).
- `examples/<PAESE>.json`: eventi **FINTI** per provare l'elenco in ciascun paese. Non si importano in produzione (`--allow-examples` solo per un database di prova).

Regole di validazione: `packages/infrastructure/events/curated_events.py` (regioni per paese in `packages/core/domain/events/regions.py`). `latitude` e `longitude` (facoltative, insieme) mostrano l'evento anche a chi abita entro 30 km in un altro paese. Contesto: `docs/features/events_engine.md`, `docs/i18n/NOTIZIE_EVENTI_MERCATINO.md`.

## Coordinate dal comune (tabelle `gazetteer/`)

Un evento senza `latitude`/`longitude` riceve all'import quelle del suo comune: `city` + `province_code` in Italia, `city` + `region` negli altri paesi (accenti e maiuscole non contano). Nome non trovato o ambiguo = nessuna coordinata e una riga `COORD` che lo dice; le coordinate scritte nel file vincono sempre. Sono le coordinate del comune, non del luogo dell'evento: bastano per il raggio di 30 km.

Le tabelle `gazetteer/<PAESE>.tsv` vengono dal tema «divisions» di Overture Maps (località, dati da OpenStreetMap, licenza **ODbL 1.0**: attribuzione «© OpenStreetMap contributors, Overture Maps Foundation» in testa a ogni file; le tabelle sono un database derivato con la stessa licenza). Si rigenerano con `build_gazetteer.py --country IT` (DuckDB, stesso accesso e stesso registro delle richieste del radar, `.local/radar/requests.log`). Comuni senza sigla: le province sarde della riforma 2025 (si usa la regione).

Per ora nel repository c'è solo `IT.tsv`. Le tabelle degli altri paesi si generano quando arriva il primo evento vero di quel paese: fuori dall'Italia si confronta solo nome e regione, e un comune che manca nella tabella potrebbe prendere le coordinate di un omonimo della stessa regione. Al primo import di quel paese si controllano a mano le righe `COORD`.
