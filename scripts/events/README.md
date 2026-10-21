# Eventi curati

Gli eventi veri stanno in `data/events/curated/` (cartella locale, non nel repository: `/data/` è ignorata da git). I seed finti stanno qui, nel repository.

- `curated/<PAESE>.json` (es. `IT.json`, `GB.json`): eventi **veri**, verificati sul sito ufficiale dell'organizzatore. Importati con `scripts/events/import_curated.py`. Un file per paese, evento con `"country"` (assente = `IT`).
- `examples/<PAESE>.json`: eventi **FINTI** per provare l'elenco in ciascun paese. Non si importano in produzione (`--allow-examples` solo per un database di prova).

Regole di validazione: `packages/infrastructure/events/curated_events.py` (regioni per paese in `event_regions.py`). Contesto: `docs/features/events_engine.md`, `docs/i18n/NOTIZIE_EVENTI_MERCATINO.md`.
