# Legislative watch

Job settimanale ([.github/workflows/legislative-watch.yml](../../../.github/workflows/legislative-watch.yml)) che controlla un piccolo elenco di fonti ufficiali (oggi: testo consolidato dell'AI Act su EUR-Lex, pagina "Intelligenza Artificiale" del Garante Privacy — vedi `SOURCES` in [legislative_watch.py](../../../packages/infrastructure/compliance/legislative_watch.py)) e confronta il contenuto scaricato con l'ultimo snapshot salvato in `snapshots/`.

Se il contenuto è cambiato, viene generato un report datato in `reports/` con il diff testuale e, se disponibile un token, viene aperta una issue GitHub con lo stesso contenuto.

**Il job si ferma al rilevare e segnalare.** Non modifica mai codice, configurazione o comportamento dell'app: capire se un cambiamento normativo richiede un intervento nel prodotto resta una decisione umana. Il diff testuale grezzo è la scelta deliberata per l'MVP — nessuna sintesi automatica del contenuto legale tramite LLM in questa iterazione.

## Test manuale

Trigger manuale da GitHub Actions (tab Actions → "Legislative Watch" → "Run workflow"), oppure in locale:

```bash
uv run python -m packages.infrastructure.compliance.legislative_watch --no-issue
```

Una seconda esecuzione immediata non deve produrre alcun report (idempotenza). Per simulare un cambiamento, modifica manualmente un file in `snapshots/` e rilancia.
