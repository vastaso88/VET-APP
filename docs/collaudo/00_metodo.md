# Collaudo di Quokka: metodo

*Rete di collaudo approvata dal proprietario il 22/11/2026 (piano dell'Orchestratore). Questo
documento descrive come si prova; le regole operative per i tester sono nelle skill
`.claude/skills/collaudo-utente/` e `.claude/skills/collaudo-estetica/`.*

## Chi prova

- **«Collaudo app»** coordina: prepara il gemello e gli attrezzi, guida i tester, riproduce ogni
  difetto prima di mostrarlo, riempie la pagina «Collaudo Quokka».
- **17 utenti di prova** (`col-…`): 9 funzionali (uno sull'emulatore Android), 2 villain, 6 di
  estetica. Schede in `docs/collaudo/persone/`; dati e copertura in
  `scripts/collaudo/persone.json` (le schede dei villain sono fuori dal repository).
- Regola di copertura: ogni gruppo di specie e ogni funzione hanno almeno **2 utenti
  funzionali** (`python -m scripts.collaudo.persone`; un test lo controlla). Le specie ruotano a
  ogni giro.

## Dove si prova: il gemello online

- Ramo Vercel `collaudo` del server + progetto Supabase di prova separato + chiave Anthropic
  «prove». **Mai la produzione**: gli attrezzi leggono il gemello solo da nomi propri
  (`COLLAUDO_*`) e si rifiutano di partire se l'indirizzo è quello di produzione o quello del
  backend normale.
- Account solo sintetici `col-…@example.com`, piano **Pro**, password generate e tenute fuori
  dal repository.
- Il server del gemello gira con `ENVIRONMENT=production`, come la produzione (stesso CORS,
  niente `/docs`, nessun interruttore di prova): il gemello si riconosce solo dal controllo
  prima di partire, dove entra un account che esiste soltanto lì.
- Proprio perché gira come la produzione, nelle variabili del ramo `collaudo` devono mancare (o
  essere di prova): SMTP ed `EMAIL_FROM` (nessuna e-mail vera, nemmeno verso example.com),
  chiavi di notifiche push, credenziali degli store (`BILLING_STORE_ENVIRONMENT=sandbox`),
  `ADMIN_EMAILS` e `DEVELOPER_EMAILS` reali. L'app di collaudo si costruisce senza
  `CRASH_REPORTING` né `SENTRY_DSN` (Cybersicurezza, 22/11).
- L'app di collaudo (web o APK dell'emulatore) si costruisce **sempre** con indirizzo e chiave
  del gemello (`scripts/collaudo/build_collaudo.py`, punto di avvio `lib/main_collaudo.dart`):
  senza valori, una build Flutter punta alla produzione. `gemello.py build <cartella|apk>`
  rifiuta una build che contiene un progetto vietato o non contiene il gemello. La build non
  lascia mai il PC (contiene una password sintetica).
- Prima di un giro, per ogni tester: `client.py <chat> prepara` (Termini, Privacy ed età, come
  l'iscrizione nell'app), tranne chi prova proprio consensi ed età.
- Siti esterni (deciso dall'Orchestratore il 22/11): il gemello (il nostro Vercel, ramo
  `collaudo`, e il nostro Supabase di prova) è nostro, quindi le chiamate dei tester sono esenti
  da robots, termini e pausa di 10 secondi. Restano il nome «Quokka…» in ogni richiesta e un
  registro per giro (`tempi.jsonl`). Gli host esterni veri (Overpass, Nominatim, fonti RSS),
  chiamati dal server del gemello, seguono la regola normale.
- Tetto di spesa del modello sul gemello: **3 € al giorno**. Se un giro lo raggiunge, le ondate
  rimaste passano al giorno dopo: non è un difetto dell'app.
- Avvertenze su ogni risultato: avvio a freddo più lento che in produzione; database quasi vuoto
  (ricerche più veloci); conferma e-mail spenta (l'iscrizione non si giudica).

## Attrezzi (`scripts/collaudo/`)

| File | A cosa serve |
|---|---|
| `config.py` | dove sta il gemello, rifiuto della produzione |
| `gemello.py` | schema in un file, confronto dei nomi, account Pro, azzeramento, controllo prima di partire |
| `client.py` | le chiamate dei tester (server e database come l'app), tempi, tempo di lettura, segnalazioni |
| `segnalazioni.py` | formato di una segnalazione |
| `lettura.py` | tempo di lettura per lingua (parole al minuto, studio IReST 2012) |
| `riassunto.py` | unisce segnalazioni e tempi, toglie i doppioni, prepara schede e riassunto |
| `persone.json`, `persone.py` | le 17 persone e la matrice di copertura |
| `build_collaudo.py` | build dell'app di collaudo, sempre sul gemello, con registro del commit |
| `servi_web.py`, `ponte.py` | serve la build web su `http://localhost:8080` (solo questo PC) e inoltra `/api/*` all'API del gemello aggiungendo il codice di bypass delle anteprime Vercel, che così non entra mai in una build. Web: `API_BASE_URL=http://localhost:8080/api` (stessa origine). Emulatore: `http://10.0.2.2:8080/api` con APK costruito in modalità `--profile`, l'unica in cui Android permette http, e solo verso 10.0.2.2. Supabase resta diretto. Il ponte aggiunge pochi millisecondi: il cronometro misura il server anche direttamente dagli script |
| `chrome.py`, `schermate.py`, `bozza_png.py` | fotografie a misura di telefono (390×844, chiaro e scuro) con il Chrome già installato; solo indirizzi locali; bozze HTML «dopo» in immagini |

## Come va un giro (solo dopo il VIA del proprietario)

1. Si riattiva il gemello se è in pausa e si porta il ramo `collaudo` al commit da provare.
   `gemello.py azzera`, poi `gemello.py controllo`: se un controllo fallisce, il giro non parte.
2. Il cronometro (`col-marco-cronometro`) gira da solo il percorso fisso di 20 passi, poi tre
   ondate: 5 funzionali (con l'emulatore), poi 3 funzionali e i 2 villain, poi i 6 di estetica.
3. Ogni tester scrive `rapporto.md` e `segnalazioni.jsonl` in `.local/collaudo/giro-N/<chat>/`.
4. Il coordinamento riproduce ogni difetto, lancia `riassunto.py`, riempie la pagina: 15 schede
   in evidenza, le altre sotto «Altre».
5. Il proprietario decide dalla pagina (Accetto / No / Ne parliamo). **Il silenzio non vale sì.**
   Le schede accettate diventano compiti in `COLLAUDO/<data>/`; quelle sugli abusi restano in
   `.local/` finché il buco non è chiuso.

## Scala di gravità

| Gravità | Significato |
|---|---|
| Bloccante | non si può usare, dati persi o visti da altri, rischio per l'animale, testo legale sbagliato |
| Grave | funziona male o informa in modo sbagliato; tempi oltre la regola dei 20 s |
| Fastidio | funziona ma confonde, è lento, passi inutili |
| Ritocco | parole, ordine, piccoli dettagli |

## Formato

- `segnalazioni.jsonl`: una riga JSON per problema (campi in `scripts/collaudo/segnalazioni.py`),
  scritta solo con `client.py segnala`. Una risposta giudicata sbagliata porta una fonte della
  biblioteca locale o «senza fonte, da verificare».
- `rapporto.md`: 5 cose buone, 5 da sistemare, cosa cambierei, numeri, note per il giro dopo.
- `tempi.jsonl` e `risposte.jsonl`: scritti dagli attrezzi, mai a mano.

## Cosa resta fuori

- Pagamenti degli store: 5 minuti sul telefono vero, a cura del proprietario o di Rob.
- Nessun sito esterno per i tester; nessun numero di telefono in nessun testo; nessuna «corsia
  d'urgenza».
