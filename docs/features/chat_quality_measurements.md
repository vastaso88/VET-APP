# Misure della qualità della chat

Registro delle esecuzioni dello strumento `scripts/eval/chat_quality/run.py` (griglia
e metodo nel suo README) e delle misure di costo in token. I trascritti completi restano
sul PC di chi lancia la misura (`.local/chat_eval/`, non versionato); qui i numeri, così
chi lavora al progetto li trova senza rilanciare nulla.

Regole: le misure usano una chiave di un account Groq **separato** da quello di
produzione (`EVAL_LLM_API_KEY` nel `.env` locale, mai in chat né nel repository); anche
quell'account ha 200.000 token al giorno sul modello grande, quindi un giro per volta.
La chiave non serve su Vercel: lo strumento gira sul PC.

## 2026-10-14 — "rimandi-b29": rimando al veterinario dopo le build 29 e 32

Modello `openai/gpt-oss-120b`, 48 scenari (categorie caso, curiosità, sintomo, urgenza:
42 scenari; più 6 scenari referto entrati con la ripresa dell'esecuzione), 141.000 token
in due giri. Il modello leggero non esisteva ancora sull'account di prova
(`llama-3.1-8b-instant` assente: da qui il predefinito `openai/gpt-oss-20b`), quindi
classificatore d'urgenza e parole chiave sono andati a vuoto e le risposte sono quelle
del solo modello principale.

| misura | valore |
|---|---|
| scenari | 48 |
| risponde (0-2) | 1.83 |
| turni_attesa | 0.10 |
| ansia | 0.02 |
| gergo | 0.21 |
| naturale (0-2) | 1.77 |
| corretta (0-2) | 1.96 |
| esperto (0-2) | 1.96 |
| allarmi | 0.02 |
| tecnicismi | 0.23 |
| farmaci | 0 |
| caratteri (media) | 736 |
| nei_tempi | 42/45 |
| cita_referto | 6/6 |
| urgenza | 3/3 |
| evita_errori | 3/3 |
| rimando al veterinario | superfluo 9, mancante 1, appropriato 4, ammesso 13, nessuno 21 |

Confronto con il 6 ottobre ("quotidiano-prima", build 28) sui 9 scenari in comune
(caso e curiosità):

| misura | 6 ottobre | 14 ottobre |
|---|---|---|
| rimando superfluo | 6 | 4 |
| rimando mancante | 2 | 0 |
| rimando appropriato | 0 | 2 |
| nessun rimando | 1 | 3 |
| caratteri (media) | 643 | 827 |
| secondi per risposta | 0.71 | 2.84 |

Lettura: i rimandi mancanti sono spariti e quelli superflui calano, ma non a zero: 9
su 48 chiudono ancora con un invito al veterinario non necessario. Il tempo per risposta
è triplicato perché le due chiamate al modello leggero (classificatore e parole chiave)
sono in serie prima della risposta e in questa prova fallivano con un 404 dopo un giro
di rete ciascuna. Nella build 33 le due chiamate leggere e la ricerca delle fonti
girano in parallelo: con il modello finto a latenze fisse il turno passa da 2,30 s (in
serie) a 1,91 s, contro 1,50 s della sola risposta (`latency_probe.py`, dettagli in
`chat_free_tier_budget.md`). Da riverificare con il modello leggero attivo alla prossima
misura.

## 2026-10-14 — costo in token per risposta (senza provider)

`scripts/eval/chat_quality/token_budget.py`, tiktoken `o200k_base`, 80 turni degli
scenari, prima e dopo il lavoro "free tier" della build 32 (dettagli in
`chat_free_tier_budget.md`).

| misura | prima | dopo |
|---|---|---|
| token del prompt di sistema (mediana) | 1753 | 1313 |
| token in ingresso al modello principale per turno (mediana) | 2040 | 1485 |
| costo stimato di una risposta sul principale | 2540 | 1985 |
| risposte/giorno con i 200k del principale | 78 | 100 |
| risposte/giorno con principale + due riserve | 236 | 302 |
| conversazione lunga, 8° turno | 3589 | 2387 |

## 2026-10-06 — "quotidiano": casi ed curiosità di tutti i giorni (build 28)

10 scenari (cane e gatto), stesso modello. Prima/dopo la prima versione della regola
sul rimando (prompt v3): rimando superfluo 7 → 6, mancante 2 → 2, nessuno 1 → 2;
caratteri 651 → 767; allarmi 0 → 0.1. Da qui la build 29 (regola nel prompt più
rimozione deterministica delle chiusure rituali), misurata sopra.

## 2026-10-05 — prima esecuzione completa (build 22 → 23)

33 scenari (referti, pratica, profilo, sintomi, termini, urgenze). Prima/dopo la
riscrittura dei prompt e l'instradamento per tipo di richiesta:

| misura | prima | dopo |
|---|---|---|
| risponde (0-2) | 1.28 | 1.82 |
| turni_attesa | 0.39 | 0.09 |
| ansia | 0.28 | 0 |
| gergo | 0.45 | 0.33 |
| naturale (0-2) | 1.34 | 1.76 |
| corretta (0-2) | 1.76 | 1.97 |
| valori | 0.67 | 0.83 |
| tecnicismi | 0.88 | 0.64 |
| farmaci | 0.21 | 0 |
| caratteri (media) | 1087 | 803 |
| nei_tempi | 21/30 | 30/30 |
| cita_referto | 2/11 | 10/11 |
| onestà | 1/3 | 3/3 |
| urgenza | 1/3 | 3/3 |

Questa esecuzione fu fatta con la chiave di produzione ed esaurì la quota del giorno:
la chat dell'app rimase ferma per ore. Da allora la chiave di valutazione è separata e
ogni esecuzione ha un tetto di token.

## Da misurare

- Precisione del classificatore d'urgenza (66 frasi per lingua) e qualità del modello
  leggero su estrazione e domanda d'intervista, con il modello leggero attivo.
- I 6 scenari "pesci" non ancora coperti da "rimandi-b29" (tetto raggiunto).
- Effetto delle schede di specie e del riassunto per il veterinario.
