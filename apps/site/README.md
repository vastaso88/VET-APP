# Sito pubblico di Quokka (`apps/site`)

Sito statico in HTML/CSS puro: nessun framework, nessun JavaScript, nessun cookie, nessuna analisi, nessun font esterno. Serve per gli indirizzi che Google Play chiede (informativa privacy, termini, assistenza, cancellazione dell'account).

## Struttura

| Percorso | Cosa è |
|---|---|
| `it/…/index.html` | Pagine in italiano: home, `supporto`, `privacy`, `termini`, `cancellazione-account`, `avviso-ia`. **File generati**, vanno committati |
| `404.html`, `index.html`, `robots.txt` | Pagina non trovata, ingresso (rimanda a `/it/`), robots |
| `assets/style.css` | Stile. Colori = token di `apps/mobile_app/lib/design_system/tokens/app_colors.dart` |
| `vercel.json` | Header di sicurezza (CSP senza script, HSTS, nosniff, Referrer-Policy, …), redirect `/` → `/it/` |
| `tools/` | Generatore (`build.py`, `mdlite.py`, `pages_it.py`). Non viene pubblicato (`.vercelignore`) |

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

## Pubblicare su Vercel

1. Vercel → **Add New… → Project** → importa il repository GitHub di VetApp.
2. **Project Name**: per esempio `quokka-site` (diverso dal progetto del backend).
3. **Root Directory**: `apps/site`. **Framework Preset**: *Other*. Build Command, Output Directory e Install Command: vuoti. Vercel pubblica la cartella così com'è.
4. **Production Branch**: `main`. Niente variabili d'ambiente.
5. **Deploy**. Controlla l'indirizzo `*.vercel.app` provvisorio.
6. Collegare il dominio: Project → **Settings → Domains** → aggiungi `quokka.pet` e `www.quokka.pet`. Vercel mostra i record DNS da inserire presso il registrar (di solito un record `A` per `quokka.pet` e un `CNAME` per `www`). Se il DNS è su Cloudflare, i record vanno su "solo DNS" (nuvola grigia).
7. Dopo qualche minuto il certificato HTTPS è automatico.

## Prima di pubblicarlo davvero (bozza → definitivo)

Oggi tutto è in **modalità bozza**: ogni pagina ha `noindex` e `robots.txt` blocca i motori di ricerca, perché i testi legali hanno ancora segnaposto.

- [ ] Segnaposto riempiti nei testi di `docs/compliance/it/` e testi rivisti dal legale. Controllo: `grep -rn "<mark>" apps/site/it` deve restituire solo ciò che è voluto (idealmente niente).
- [ ] In `tools/build.py` mettere `DRAFT = False`, rilanciare `build.py` e committare.
- [ ] Titolare nel piè di pagina (`UI["footer_owner"]` in `tools/pages_it.py`): obbligo di legge, dati reali solo nel testo pubblicato, mai nel repository.
- [ ] Indirizzo di contatto confermato dal proprietario (`CONTACT_EMAIL` in `tools/pages_it.py`).
- [ ] In Play Console: informativa = `https://quokka.pet/it/privacy/`, eliminazione account = `https://quokka.pet/it/cancellazione-account/`.
- [ ] Nell'app: sostituire la frase «L'informativa completa è in preparazione» con il link (vedi `docs/compliance/it/README.md`).

## Aggiungere una lingua

1. Copiare `tools/pages_it.py` in `tools/pages_en.py` e tradurlo (`LANG = "en"`); puntare `md` ai testi di `docs/compliance/<lingua>/`.
2. Aggiungere `"en"` a `LANGS` in `tools/build.py`.
3. Aggiornare il redirect di `/` in `vercel.json` se la lingua predefinita cambia.

## Sicurezza (coerente con `docs/security/`)

- CSP `default-src 'none'; style-src 'self'; img-src 'self'; frame-ancestors 'none'`: niente script, niente risorse esterne. Se un giorno servirà qualcosa di esterno (analisi, font), prima va aggiornata la CSP e, per le analisi, serve il banner di consenso (informativa §11).
- HSTS senza `preload`: attivarlo solo quando tutti i sottodomini di `quokka.pet` sono su HTTPS.
- Niente segreti né dati personali reali nel repository (è pubblico).
