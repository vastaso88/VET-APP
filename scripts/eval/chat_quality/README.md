# Valutazione della qualità della chat

Conversazioni vere con il modello vero, su animali e referti inventati, valutate con una
griglia scritta. Serve a confrontare la chat prima e dopo una modifica, o un fornitore di
modelli con un altro.

Non è parte della suite di test (`pytest` non lo esegue) e non tocca Supabase, account
reali o produzione: il backend gira in memoria con un utente finto. Solo il modello è reale.

## Prima di usarlo: una chiave dedicata

Le prove **non devono usare la chiave di produzione**. Il 5 ottobre 2026 due esecuzioni
complete sulla chiave condivisa hanno esaurito il tetto giornaliero del provider e fermato
la chat dell'app per ore.

1. Crea una chiave su un **conto del provider separato** da quello di produzione. I limiti
   di Groq sono per conto (organizzazione) e per modello: una seconda chiave dello stesso
   conto consuma la stessa quota.
2. Aggiungila al file `.env` locale (mai nel repository):

   ```
   EVAL_LLM_API_KEY=...
   ```

Senza `EVAL_LLM_API_KEY`, o se è uguale a `LLM_API_KEY`, lo strumento si ferma e spiega
perché. La chiave non viene mai stampata.

**Eccezione controllata**: `--allow-production-key` usa `LLM_API_KEY` quando manca la
chiave dedicata, ma solo con un `--max-tokens` esplicito, non superiore a quanto resta del
tetto di 40.000 token al giorno. Il consumo è annotato chiamata per chiamata in
`.local/chat_eval/production_key_usage.json`, quindi conta anche se l'esecuzione si
interrompe; prima di ogni chiamata viene stimato il costo massimo (prompt più intera
risposta) e, se supererebbe il tetto, la chiamata non parte. Pensata per un sottoinsieme
rappresentativo, non per un giro completo.

## Confrontare un altro fornitore (es. OpenAI)

Lo strumento parla il protocollo "chat completions" compatibile OpenAI. Per misurare un
altro fornitore basta impostare, nel `.env` o nell'ambiente:

```
EVAL_LLM_BASE_URL=https://.../v1
EVAL_LLM_MODEL=<nome del modello>
EVAL_LLM_API_KEY=<chiave di quel fornitore>
```

Poi `run --label <etichetta>` e `compare` con l'esecuzione di riferimento. Il giudice usa lo
stesso modello in prova: per un confronto equo tra due fornitori conviene far rigiudicare
entrambe le esecuzioni con lo stesso modello (`rejudge <etichetta> --all` con le variabili
del modello giudice impostate).

## Tetto di spesa

Ogni esecuzione si ferma da sola a `--max-tokens` (predefinito: 40.000 token). Quello che
ha fatto fino a lì è salvato e si riprende con `--resume`.

Ordini di grandezza misurati il 6 ottobre 2026: una conversazione a un turno senza giudice
costa circa 1.500-1.900 token; con il giudice circa 2.500-3.000; un'esecuzione completa
(79 scenari) con giudice circa 200.000. Il piano gratuito di Groq concede 200.000 token al
giorno per modello.

I token del modello di visione non sono contati: servono solo la prima volta, per leggere le
due scansioni di prova, poi la lettura resta in `.local/chat_eval/analysis_cache.json`.

## Comandi

```bash
uv run python scripts/eval/chat_quality/run.py run --label prima
```

```bash
uv run python scripts/eval/chat_quality/run.py run --label dopo --max-tokens 100000
```

```bash
uv run python scripts/eval/chat_quality/run.py compare prima dopo
```

Opzioni di `run`:

| Opzione | Effetto |
|---|---|
| `--only id1,id2` | solo alcuni scenari (il modo consigliato per provare una modifica) |
| `--resume` | continua un'esecuzione interrotta, saltando gli scenari già fatti |
| `--no-judge` | solo misure meccaniche: dimezza circa le chiamate |
| `--evidence in_memory` | salta la ricerca nella letteratura esterna |
| `--max-tokens N` | tetto di token dell'esecuzione |
| `--allow-production-key` | vedi sopra |

Altri comandi: `rejudge <label>` ripete il giudizio dove manca (`--all` ovunque);
`rescore <label>` ricalcola le misure meccaniche senza chiamare il modello.

Con un antivirus che intercetta HTTPS: `uv run --with truststore python ...`.

Risultati in `.local/chat_eval/<label>/` (`results.json`, `transcripts.md`): cartella mai
inclusa nel repository.

## La griglia

| Misura | Cosa dice | Chi la calcola |
|---|---|---|
| risponde (0-2) | risponde a ciò che è stato chiesto | giudice |
| turni_attesa | risposte di sole domande prima della prima utile | giudice |
| nei_tempi | risposta utile entro il turno previsto dallo scenario | giudice |
| ansia (0-2) | 0 tranquillo, 2 allarmante | giudice |
| gergo (0-2) | termini tecnici non spiegati | giudice |
| naturale (0-2) | suona come una persona, non come un modulo | giudice |
| corretta (0-2) | corretta di massima sul piano clinico | giudice |
| esperto (0-2) | risponde da esperto senza delegare | giudice |
| rimando | veterinario nominato: appropriato / superfluo / mancante / nessuno | meccanica |
| cita_referto | dice di aver letto il referto, dove serve | meccanica |
| valori (0-1) | quota dei valori chiave del referto citati | meccanica |
| allarmi | parole spaventose non usate dall'utente | meccanica |
| tecnicismi | termini tecnici senza spiegazione | meccanica |
| farmaci | farmaci non nominati né dall'utente né dai documenti | meccanica |
| onesta | dice chiaramente cosa non può leggere, dove serve | meccanica |
| urgenza | le urgenze vere sono scalate subito | meccanica |
| caratteri | lunghezza media di una risposta | meccanica |
| chiamate | chiamate al modello per risposta | misurata |
| secondi | tempo per produrre una risposta | misurata |

Il giudice è lo stesso modello che scrive le risposte: i suoi voti servono a confrontare due
esecuzioni, non sono un voto assoluto. Il "rimando" è deciso dal codice in base a quanto lo
scenario dichiara (`vet_referral`): non dipende dal giudice.

## Dati di prova

- `scenarios.py`: animali (`PETS`) e conversazioni (`SCENARIOS`) su referti, domande
  pratiche, sintomi e urgenze.
- `scenarios_everyday.py`: per ogni tipo di animale (cane, gatto, coniglio, roditore,
  uccello, rettile, pesce) tre casi concreti e tre curiosità, con l'attesa sul rimando al
  veterinario.
- `fixtures/referti/`: i referti. Il `.txt` è la fonte; `.pdf` e `.jpg` sono generati da
  `make_fixtures.py` (`uv run --with pillow python scripts/eval/chat_quality/make_fixtures.py`).

Tutto è inventato: nessuna persona reale, clinica dichiaratamente fittizia. Chi aggiunge
dati deve mantenere questa regola.
