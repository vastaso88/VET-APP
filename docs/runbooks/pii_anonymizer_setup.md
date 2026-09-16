# Setup anonimizzatore PII (Presidio)

L'anonimizzazione locale dei dati sensibili verso il provider LLM esterno ([docs/compliance/02_pii_anonymization.md](../compliance/02_pii_anonymization.md)) usa [Microsoft Presidio](https://microsoft.github.io/presidio/) con un modello spaCy italiano. Di default il backend è `noop` (nessuna anonimizzazione, pass-through) — va abilitato esplicitamente.

## Setup locale

```bash
uv sync --extra privacy
uv run python -m spacy download it_core_news_lg
```

I modelli spaCy non sono pacchetti PyPI normali: `spacy download` scarica il modello da un URL dedicato, per questo è un passo separato da `uv sync`.

## Abilitazione

Imposta nell'ambiente (`.env` o variabili di sistema):

```
PII_ANONYMIZER_BACKEND=presidio
```

Senza questo passo di setup, o se `presidio-analyzer`/`spacy` non sono installati, il container ricade automaticamente su `NoopPiiAnonymizer` fuori produzione (in produzione solleva un errore, per non far partire il servizio con anonimizzazione silenziosamente disattivata).

## CI

I workflow CI restano su `PII_ANONYMIZER_BACKEND=noop` (default) per non dover scaricare il modello spaCy ad ogni run. I test dedicati a `PresidioPiiAnonymizer` sono marcati skip se il modello non è disponibile nell'ambiente di test.
