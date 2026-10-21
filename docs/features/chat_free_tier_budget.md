# Chat sul free tier di Groq: misura, budget e degrado graziosa

Build 32 (2026-10-14). Decisione dell'utente: la chat resta su Groq gratuito. Il free
tier conta i token **al giorno e per modello, per tutta l'organizzazione** (non per
chiave): il 2026-10-05 una sola esecuzione della valutazione ha esaurito la quota e la
chat di produzione ha risposto "servizio non disponibile" per ore. Da questa build la
struttura è fatta per restare dentro la quota di proposito, non per fortuna.

Fonti pubbliche (console.groq.com/docs/rate-limits, 2026-10; da confermare nella pagina
dei limiti dell'account): `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `qwen/qwen3.8-27b`
≈ 200.000 token/giorno, 8.000/minuto, 1.000 richieste/giorno ciascuno. `llama-3.1-8b-instant`
(≈ 500.000/giorno nelle fonti pubbliche) NON è nel catalogo dell'account gratuito di
valutazione creato il 2026-10-14: il modello leggero predefinito è quindi
`openai/gpt-oss-20b`. Il prompt caching è attivo di default sui modelli `openai/gpt-oss-*`
(prefisso stabile, parti variabili dopo; i token in cache compaiono in
`usage.prompt_tokens_details.cached_tokens`).

## 1. Misura

Ogni chiamata al modello passa da `InstrumentedLLMClient`
(`packages/core/application/services/llm_usage_recorder.py`) e produce:

- una riga di log strutturato `llm_usage {...}` con modello, classe (`main`/`light`),
  scopo, token in/out/in cache, durata, esito (`ok`, `length` = risposta troncata,
  `rate_limited`, `error`); mai il testo;
- una riga nella tabella `llm_usage` e l'aggiornamento atomico di `llm_usage_daily`
  (totali per giorno e modello), tramite la funzione SQL `llm_usage_add`.

Gli scopi: `answer`, `answer_retry`, `general_answer`, `situation_model`,
`interview_question`, `evidence_synthesis`, `evidence_query`, `urgency_classifier`,
`consent_interpretation`, `document_summary`, `vet_summary`.

Il costo di una risposta senza chiamare il provider:
`scripts/eval/chat_quality/token_budget.py` (modello finto, conteggio con tiktoken
`o200k_base` quando importabile, altrimenti stima a caratteri). Esecuzione:

```bash
uv run --system-certs --with tiktoken --with truststore python -c "import truststore; truststore.inject_into_ssl(); import runpy, sys; sys.argv=['token_budget.py','--label','dopo']; runpy.run_path('scripts/eval/chat_quality/token_budget.py', run_name='__main__')"
```

(`truststore` serve solo su questa macchina, dove il download del tokenizer passa dai
certificati di sistema.) `--compare prima dopo` confronta due esecuzioni.

### Prima / dopo (80 turni degli scenari di valutazione, tiktoken)

| misura | prima | dopo |
|---|---|---|
| token del prompt di sistema (mediana) | 1753 | 1313 |
| token in ingresso al modello principale per turno (mediana) | 2040 | 1485 |
| idem, 90° percentile | 2547 | 2079 |
| token sul modello leggero per turno (mediana) | 0 | 373 |
| costo stimato di una risposta sul principale (prompt + ~350 di risposta + ~150 di ragionamento) | 2540 | 1985 |
| risposte/giorno sostenibili con i 200k del principale | 78 | 100 |
| risposte/giorno con le tre quote da 200k (principale + due riserve) | 236 | 302 |
| conversazione lunga, 8° turno, token in ingresso | 3589 | 2387 |
| curiosità, token in ingresso (mediana) | 1932 | 1344 |

Le curiosità in produzione costano meno ancora: la stessa domanda dalla seconda volta in
24 ore non chiama il modello (sezione 6). Il modello leggero ha una quota propria da
200k: 373 token per turno sono ~530 turni al giorno.

## 2. Il lavoro leggero sul modello piccolo

`LLMGenerationRequest.model_class` vale `main` o `light`. `GroqLLMClient` tiene due catene:
`LLM_MODEL` → `LLM_FALLBACK_MODELS` e `LLM_MODEL_LIGHT` (default `openai/gpt-oss-20b`)
→ `LLM_LIGHT_FALLBACK_MODELS` (default `qwen/qwen3.8-27b`). Un modello che l'account
non ha (404) viene saltato per il resto della giornata e la riserva subentra. Sul leggero: estrazione
del situation model e domanda dell'intervista (quando il ciclo è attivo),
interpretazione del consenso solo quando le frasi fisse non decidono (e vale solo un
"sì"/"no" esplicito: l'incertezza resta "non concesso"), parole chiave inglesi per la
ricerca fonti, classificatore d'urgenza. `LLM_MODEL_LIGHT=""` rimette tutto sul
principale. I titoli restano deterministici (nessuna chiamata).

## 3. Il secondo guardiano

`UrgencyClassifier` (`urgency_classifier.py`): dopo le liste fisse (che restano il
pavimento) e prima della risposta, il modello leggero legge il messaggio in qualsiasi
lingua e risponde `{"level": emergency|maybe|normal, "category": ...}` con un prompt
corto, JSON forzato, `max_tokens` 60 e timeout di 6 s (`URGENCY_CLASSIFIER_TIMEOUT_SECONDS`).

- `emergency` → lo stesso testo fisso di triage delle liste (`safety_flags`
  `classifier:<categoria>`);
- `maybe` con una categoria che ha una domanda di chiarimento → quella domanda, poi la
  risoluzione abituale (fail-closed);
- `maybe` senza domanda, `normal`, timeout, errore o JSON illeggibile → risposta normale,
  con log. Non gira sui convenevoli.

La misura di precisione (66 frasi per lingua) richiede la chiave di valutazione.

## 4. Meno token per risposta

- Prompt di sistema compattato (stesse regole, −25%); le frasi che i test fissano sono
  intatte. È la parte stabile e identica tra utenti: il prefisso che Groq può mettere in
  cache. Tutto ciò che varia (animale, storia, data, documenti) sta nel messaggio utente.
- Al massimo `LLM_PROMPT_MAX_SOURCES` (2) fonti, estratti tagliati a
  `LLM_PROMPT_SOURCE_CHARS` (300).
- Storia: ultimi `LLM_HISTORY_RECENT_MESSAGES` (6) messaggi, ciascuno tagliato a
  `LLM_HISTORY_MESSAGE_CHARS` (400); i più vecchi come una riga di argomenti.
- `max_tokens` della risposta: `LLM_ANSWER_MAX_TOKENS` (450; +150 per i referti; 300 per
  i convenevoli). Ai modelli `openai/gpt-oss-*` il client aggiunge
  `LLM_REASONING_HEADROOM_TOKENS` (350) perché il ragionamento consuma lo stesso budget.
  L'esito `length` nel ledger dice quante risposte restano troncate: se cresce, alzare.
- La rigenerazione quando la risposta è fatta solo di domande resta (scopo
  `answer_retry`, così si misura quanto accade).

## 5. Budget giornaliero e degrado graziosa

`LlmBudget` (`llm_budget.py`), condiviso tra le istanze serverless tramite Supabase:

- budget per modello da `LLM_DAILY_TOKEN_BUDGETS` (default: le cifre pubbliche), altrimenti
  `LLM_DEFAULT_DAILY_TOKEN_BUDGET`;
- da `LLM_BUDGET_RESERVE_SHARE` (80%) del budget il modello passa in coda alla catena: le
  riserve vanno prima; al 100% è saltato fino al reset (mezzanotte UTC del contatore);
- un 429 "per day" di Groq segna il modello esaurito **per tutte le istanze**, fino al
  "try again in …" del messaggio di Groq; un 429 al minuto fa solo scattare la riserva
  (entrambi verificati nei test);
- quando nessun modello della catena può rispondere: "In questo momento l'assistente è
  molto richiesto e ha esaurito le risposte disponibili per oggi. Riprova tra circa 2
  ore..." (`mode` `quota_exhausted`), non un errore;
- `CHAT_DAILY_MESSAGE_LIMIT_PER_USER` (20; 0 = nessun limite) messaggi per utente che
  arrivano al modello; oltre: "Per oggi hai usato tutti i 20 messaggi..." (`mode`
  `user_limit_reached`). `DEVELOPER_EMAILS` esenti. Le risposte fisse (emergenze, dosaggi,
  due animali) vengono prima del controllo e non sono mai rifiutate né contate.

Il tempo di attesa è relativo ("tra circa 2 ore e 20 minuti"): niente fusi orari da
indovinare lato server.

## 6. Cache delle risposte

Solo per una curiosità generale sulla specie, prima domanda della conversazione, senza
allegati, senza nome dell'animale, senza possessivi/pronomi/riferimenti al momento,
senza numeri (`answer_cache.py`). La domanda normalizzata (minuscole, senza accenti,
punteggiatura e convenevoli) + specie + lingua è la chiave; la risposta vive
`CHAT_ANSWER_CACHE_TTL_HOURS` (24) in `chat_answer_cache`. La domanda in cache viene
generata **senza i dati dell'animale** (solo la specie), così vale per tutti. Badge e
contratto invariati (`ai_generated` true, provider/modello di chi l'ha generata). Sintomi
e casi personali non entrano mai.

## SQL e variabili

`scripts/setup/supabase_schema.sql` (in coda, idempotente; lo esegue l'utente): tabelle
`llm_usage`, `llm_usage_daily`, `chat_user_daily_usage`, `chat_answer_cache`; funzioni
`llm_usage_add`, `chat_user_daily_usage_add`, `chat_answer_cache_hit`. Senza le tabelle il
backend continua a funzionare: il ledger fallisce in modo silenzioso (log) e il budget
usa solo ciò che vede la singola istanza.

Nuove variabili (tutte con default): `LLM_MODEL_LIGHT`, `LLM_LIGHT_FALLBACK_MODELS`,
`LLM_ANSWER_MAX_TOKENS`, `LLM_REASONING_HEADROOM_TOKENS`, `LLM_PROMPT_MAX_SOURCES`,
`LLM_PROMPT_SOURCE_CHARS`, `LLM_HISTORY_RECENT_MESSAGES`, `LLM_HISTORY_MESSAGE_CHARS`,
`LLM_DAILY_TOKEN_BUDGETS`, `LLM_DEFAULT_DAILY_TOKEN_BUDGET`, `LLM_BUDGET_RESERVE_SHARE`,
`CHAT_DAILY_MESSAGE_LIMIT_PER_USER`, `URGENCY_CLASSIFIER_ENABLED`,
`URGENCY_CLASSIFIER_TIMEOUT_SECONDS`, `EVIDENCE_QUERY_NORMALIZER_ENABLED`,
`CHAT_ANSWER_CACHE_ENABLED`, `CHAT_ANSWER_CACHE_TTL_HOURS`.

## Aperto

- Le cifre dei budget sono quelle pubbliche: vanno confermate nella console e, se diverse,
  messe in `LLM_DAILY_TOKEN_BUDGETS`. Il contatore nostro usa il giorno UTC; le finestre
  di Groq sono mobili di 24 ore per modello: il "try again in" di Groq corregge la
  differenza quando arriva un 429.
- Qualità del modello leggero sull'estrazione, sulla domanda d'intervista e la precisione
  del classificatore (66 frasi per lingua): da misurare con `EVAL_LLM_API_KEY`.
- Se i token del prefisso in cache contino per intero nel limite giornaliero: si vede dal
  campo `cached_prompt_tokens` nel ledger dopo qualche giorno.
