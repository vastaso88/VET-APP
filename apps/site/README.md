# Sito pubblico di Quokka (`apps/site`)

Sito statico in HTML/CSS puro: nessun framework, nessun JavaScript, nessun cookie, nessuna analisi, nessun font esterno. Serve per gli indirizzi che Google Play chiede (informativa privacy, termini, assistenza, cancellazione dell'account).

## Struttura

| Percorso | Cosa è |
|---|---|
| `it/…/index.html` | Pagine in italiano: home, `supporto`, `privacy`, `termini`, `cancellazione-account`, `avviso-ia`. **File generati**, vanno committati |
| `404.html`, `index.html`, `robots.txt` | Pagina non trovata, ingresso (rimanda a `/it/`), robots |
| `assets/style.css` | Stile. Colori = token di `apps/mobile_app/lib/design_system/tokens/app_colors.dart` |
| `vercel.json` | Header di sicurezza (CSP senza script, HSTS, nosniff, Referrer-Policy, …), redirect `/` → `/it/` |
| `tools/` | Generatore (`build.py`, `mdlite.py`, `pages_it.py`) e test in `tests/unit/test_site_release_check.py` |
| `.env.example` | Nomi (senza valori) delle variabili con i dati del titolare |

Privacy, termini e assistenza **non si scrivono qui**: sono impaginati da `docs/compliance/it/` (testi della sessione normativa). Home, cancellazione account e avviso IA stanno in `tools/pages_it.py`.

## Aggiornare le pagine

```bash
python apps/site/tools/build.py
```

Rilegge i testi in `docs/compliance/it/`, toglie l'intestazione di bozza e le «Note per il revisore», e riscrive l'HTML. Poi commit dei file generati. I segnaposto (`[TITOLARE]`, `[DATA]`, `[da verificare: …]`) compaiono evidenziati in giallo finché non vengono riempiti nei testi sorgente.

## Provare in locale

```bash
cd apps/site
python -m http.server 8765
```

Apri http://localhost:8765/it/ (i link sono assoluti: servi la cartella `apps/site` come radice).

## Pubblicare su Firebase Hosting (scelta attuale, dal 2026-11-27)

Vercel Hobby è solo per uso non commerciale, quindi il sito della società sta su Firebase Hosting (piano gratuito, progetto Firebase esistente, sito di Hosting `quokkapet`, configurazione in `firebase.json` con gli stessi header di `vercel.json`). Il build si fa sul computer, i dati del titolare stanno in un file fuori dal repository:

```bash
python apps/site/tools/build.py --release --partial --env-file .local/site/owner.env --out apps/site/dist
cd apps/site && npx firebase-tools deploy --only hosting --project vetapp-test2
```

`--partial` pubblica **solo le pagine pronte**: nessun segnaposto aperto e nessun link verso una pagina trattenuta (che sparisce anche da menu e schede della home). Home e piè di pagina devono essere pronti, altrimenti il build si ferma come prima. Le pagine trattenute sono elencate nell'output. Il pulsante di download compare quando `PLAY_STORE_URL` in `pages_it.py` non è vuoto. Dominio e verifica per Google Play: `PASSI_PROPRIETARIO.md`.

## Pubblicare su Vercel (alternativa, se un giorno si passa al piano Pro)

Il sito di produzione **non** è l'HTML committato (quello è sempre la bozza): lo costruisce Vercel a ogni deploy con `python3 tools/build.py --vercel --out dist` (è in `vercel.json`). In produzione è un build di pubblicazione: riempie i dati del titolare dalle variabili d'ambiente e **fallisce** se resta un solo segnaposto, così l'ultima versione buona resta online. Sugli altri rami fa una bozza con `noindex`.

1. Vercel → **Add New… → Project** → importa il repository GitHub.
2. **Project Name**: per esempio `quokka-site` (diverso dal progetto del backend).
3. **Root Directory**: `apps/site`. **Framework Preset**: *Other*. Lascia Build Command e Output Directory come propone `vercel.json`. In **Settings → General** controlla che sia attiva *Include source files outside of the Root Directory in the Build Step* (il generatore legge `docs/compliance/it/`).
4. **Production Branch**: `main`.
5. **Settings → Environment Variables** (ambiente *Production*): le variabili `QUOKKA_SITE_*` elencate in `.env.example`. I valori stanno solo lì, mai nel repository.
6. **Deploy**. Finché i testi hanno segnaposto aperti il deploy di produzione fallisce e nel log compare l'elenco di cosa manca: è voluto. Le anteprime (altri rami) si costruiscono in bozza.
7. Collegare il dominio: vedi `PASSI_PROPRIETARIO.md`.

Da verificare al primo deploy: che l'immagine di build di Vercel abbia `python3` (la usa solo la libreria standard). Se il build non parte per questo motivo, il deploy fallisce senza pubblicare nulla.

## Dati del titolare (mai nel repository)

I testi tengono i segnaposto (`[TITOLARE]`, `[SEDE]`, `[CF_PIVA]`, …). In un build di pubblicazione ogni `[NOME]` viene sostituito dal valore della variabile `QUOKKA_SITE_NOME`; ogni valore è una riga, senza `[ ] | ` * < >`. L'elenco dei nomi è in `.env.example`; il minimo da mostrare lo stabilisce la sessione Normativa. Per provare in locale senza scrivere nulla nel repository:

```bash
QUOKKA_SITE_TITOLARE="Esempio S.r.l." python apps/site/tools/build.py --release --out /tmp/prova
```

(si ferma elencando i segnaposto ancora aperti; con `--out` non tocca l'HTML committato).

## Prima di pubblicarlo davvero (bozza → definitivo)

Oggi tutto è in **modalità bozza**: ogni pagina ha `noindex` e `robots.txt` blocca i motori di ricerca, perché i testi legali hanno ancora segnaposto.

- [ ] Testi di `docs/compliance/it/` rivisti dal legale e senza segnaposto che non siano dati del titolare. Il controllo è automatico: `python apps/site/tools/build.py --release --out /tmp/prova` elenca ogni `[MAIUSCOLO]`, `[da verificare/decidere: …]`, `[in attesa del codice: …]` e ⚖️ ancora aperto (anche nel piè di pagina).
- [ ] Variabili `QUOKKA_SITE_*` impostate su Vercel (Production). Con l'elenco vuoto il build di produzione genera il sito senza banner di bozza, senza `noindex` e con `robots.txt` aperto.
- [ ] In Play Console: informativa = `https://quokkapet.net/it/privacy/`, eliminazione account = `https://quokkapet.net/it/cancellazione-account/`.
- [ ] Nell'app: sostituire la frase «L'informativa completa è in preparazione» con il link (vedi `docs/compliance/it/README.md`).

## Aggiungere una lingua

1. Copiare `tools/pages_it.py` in `tools/pages_en.py` e tradurlo (`LANG = "en"`); puntare `md` ai testi di `docs/compliance/<lingua>/`.
2. Aggiungere `"en"` a `LANGS` in `tools/build.py`.
3. Aggiornare il redirect di `/` in `vercel.json` se la lingua predefinita cambia.

## Sicurezza (coerente con `docs/security/`)

- CSP `default-src 'none'; style-src 'self'; img-src 'self'; frame-ancestors 'none'`: niente script, niente risorse esterne. Se un giorno servirà qualcosa di esterno (analisi, font), prima va aggiornata la CSP e, per le analisi, serve il banner di consenso (informativa §11).
- HSTS senza `preload`: attivarlo solo quando tutti i sottodomini di `quokkapet.net` sono su HTTPS.
- Niente segreti né dati personali reali nel repository (è pubblico).
