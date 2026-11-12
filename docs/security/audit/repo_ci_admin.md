# Audit passivo — storia git, CI e admin portal (vastaso88/VET-APP)

Data: 2026-10-26. Worktree: `C:\Users\syste\Documents\VetApp\.claude\worktrees\security-audit-cdfeea` (HEAD = origin/main = origin/Francesco = `d950b51`).
Metodo: solo comandi git in lettura (`git rev-list --all`, `git grep` su tutti i 403 commit raggiungibili dai 34 rami remoti, `git show`, `git diff`, `git log`). Nessun servizio live interrogato, nessuna credenziale usata, nessun file modificato. `npm audit` NON eseguito (vedi B6).

Legenda gravità: Critica / Alta / Media / Bassa / Info.

---

## Sintesi

- Nessun segreto "forte" (chiave `sb_secret_`, JWT `service_role`, `gsk_`, `AIza…`, chiave privata, stringa Postgres con password, password keystore, `.env`, `.jks`, `key.properties`, `google-services.json`, service account) è mai stato committato in nessun ramo.
- Una **password di un account demo reale** è hardcoded su due rami pubblici (`origin/roberto`, `origin/MOTORE-ANAMNESI`), mai su main/Francesco. È l'unica chiave da ruotare.
- Gli indirizzi e-mail personali dei tre sviluppatori (= allowlist admin) sono nella storia di main e in un test attuale.
- CI: nessun `pull_request_target`, nessuna injection di input non fidato in `run:`; i rischi sono di hardening (action non pinnate a SHA, un workflow che pusha direttamente su `main`, nessun lockfile, nessun Dependabot).
- Admin portal: la decisione "è admin" è **server-side nel backend FastAPI** (JWT verificato via Supabase + allowlist e-mail); nessun segreto nel browser, nessun `NEXT_PUBLIC_` sensibile, nessun middleware/API route. Manca una configurazione di security header (CSP/frame-ancestors).

---

## Parte A — Storia git e CI

### A1. Password dell'account demo "founder" hardcoded su rami pubblici — **Media**

**Dove**
- `apps/mobile_app/lib/features/auth/presentation/pages/login_page.dart:27-34` su `origin/roberto` (tip `5784ab3`, 2026-10-02, autore erykwest). Introdotta in `eb57945` (2026-09-29, "feat: restore development preview entry on Vercel"), presente in tutti i 9 commit del ramo da lì in poi (`eb57945`, `b4f3611`, `77e9100`, `08d7b73`, `fcc5be9`, `5578dd7`, `ded090c`, `36d188f`, `5784ab3`).
- `apps/mobile_app/lib/shared/config/app_runtime_config_loader.dart:51` e `apps/mobile_app/test/widget/app_bootstrap_routing_test.dart:83` su `origin/MOTORE-ANAMNESI` (tip `6b9e9d0`, 2026-04-01). Presente dal commit `7208005` (2026-03-28) in 10 commit del ramo.
- Rami contenenti la stringa: **solo** `origin/roberto` e `origin/MOTORE-ANAMNESI`. **Mai** in `origin/main`, `origin/Francesco`, `MULTILANG`, `ml/*`, `feature/admin-*`, `fix/admin-*`, `hotfix-*`, `codex/*`, `tmp-crossrepo-check*`.

**Valori (mascherati)**
- e-mail: `demo-fou…p.ai` (`demo-founder-01@…`, dominio `vetapp.ai`)
- password: `<password-demo-mascherata>` (15 caratteri, default di `String.fromEnvironment('DEMO_FOUNDER_PASSWORD', …)`)

**Problema**
Su `origin/roberto` la pagina di login ha un pulsante "Apri anteprima sviluppo" (`_openDevelopmentPreview`, riga ~115-140) che chiama `signInWithPassword` con queste credenziali di default. Inoltre `apps/mobile_app/scripts/vercel_build_flutter_web.sh:55-61` (stesso ramo) passa `DEMO_FOUNDER_EMAIL` / `DEMO_FOUNDER_PASSWORD` come `--dart-define`: in una build web Flutter i dart-define finiscono **in chiaro nel bundle JavaScript pubblico**. Il commit `36d188f` ("default mobile auth to canonical Supabase") punta il ramo al progetto Supabase canonico (`ywbuz…`), quindi l'account demo — se esiste nel progetto di produzione — è raggiungibile con quelle credenziali.

**Impatto in parole semplici**
Chiunque legga il repo (è pubblico) o il JS di una eventuale deploy Vercel del ramo `roberto` conosce e-mail e password di un account reale dell'app. Può entrare, vedere/modificare i dati di quell'account e consumare quota LLM (Groq) come utente autenticato. Non dà accesso admin (l'allowlist admin è per e-mail e questa e-mail non vi compare), né al database degli altri utenti (RLS a parte, da verificare separatamente).

**Correzione consigliata**
1. Supabase Dashboard → Authentication → Users: se `demo-founder-01@vetapp.ai` esiste, **eliminarlo** o resettarne la password (e disattivarlo se non serve).
2. Se su Vercel (progetto web del ramo roberto / preview) esistono le env `DEMO_FOUNDER_EMAIL` / `DEMO_FOUNDER_PASSWORD`, rimuoverle; eliminare le deploy preview di quel ramo.
3. Rimuovere i default hardcoded da `login_page.dart` e `app_runtime_config_loader.dart` (default vuoto + pulsante nascosto se vuoto) oppure cancellare i rami `roberto` e `MOTORE-ANAMNESI` dal remoto una volta integrato ciò che serve. La storia pubblica non è bonificabile in modo affidabile (fork/cache): la rotazione al punto 1 è l'unica misura efficace.

### A2. E-mail personali degli sviluppatori (= allowlist admin) committate — **Bassa**

**Dove**
- `packages/shared/config/settings.py:31` al commit `d0b033e` (2026-09-27, "Add first-run flow, subscription/trial gate…"): `developer_emails` con default `["<sviluppatore-1@…>", "<titolare@…>", "<sviluppatore-3@…>"]` (tutti `@<dominio-personale>`). Rimosso lo stesso giorno in `513dfa0` ("Move developer allowlist emails out of source into env-only config"). `d0b033e` è antenato di **main, Francesco e di tutti gli altri 30 rami**: resta nella storia pubblica.
- Ancora presenti sul tip di main: `tests/unit/test_subscription.py:17` e `:66` (le due e-mail reali usate come fixture), `packages/shared/config/settings.py:242` (`support_contact_email` default `<titolare@…>`, probabilmente voluto come contatto pubblico).

**Problema**: non sono segreti, ma `apps/api/routes/admin.py:72-75` usa `ADMIN_EMAILS` **o, in fallback, `DEVELOPER_EMAILS`** come allowlist admin: chi legge il repo sa esattamente quali account Supabase danno accesso al backoffice e alla funzione sviluppatore (bypass trial). Il README dell'admin portal afferma "No personal email address is committed to source control": non è più vero per la storia e per il test.

**Impatto**: bersaglio preciso per phishing / credential stuffing / tentativo di reset password sui tre account.

**Correzione**: attivare MFA sugli account Supabase di quei tre indirizzi (o usare account admin dedicati, non le gmail personali); sostituire le e-mail reali nel test con `dev1@example.com`; impostare `ADMIN_EMAILS` esplicitamente in Vercel (non affidarsi al fallback su `DEVELOPER_EMAILS`).

### A3. Nessun altro segreto nella storia — **Info**

Scansione di tutti i 403 commit per: `sb_secret_`, `eyJhbGciOi` (qualsiasi JWT, incl. `service_role`), `Bearer eyJ`, `gsk_…`, `AIza…`, `-----BEGIN`, `postgres://`/`postgresql://` con password, `storePassword`/`keyPassword`, `ghp_`, `xox[bp]-`, `sk-…`, `password=`, `passwd`, `secret=`, `token=`, `api_key=`, `Demo1234`: **zero** occorrenze reali. Le uniche righe sono riferimenti a variabili d'ambiente (`System.getenv("ANDROID_KEYSTORE_PASSWORD")`, `keystoreProperties.getProperty("storePassword")` in `build.gradle.kts`), fixture di test (`test-store-password`), e il fake locale `apps/mobile_app/lib/features/auth/data/fake_auth_remote_data_source.dart:21-24` (`demo@vetapp.local` / `VETAPP`: data source in memoria usato solo quando `SUPABASE_URL` è vuoto, non è un account reale).

File sensibili mai committati in nessun ramo: `.env`, `.env.*`, `*.jks`, `*.keystore`, `key.properties`, `local.properties`, `google-services.json`, `serviceAccount*.json`, `firebase*.json`, `production.env.json`, `.vercel/`, `.p12`, `.pem`. Esiste solo `apps/mobile_app/production.env.example.json` (placeholder `<chiave-publishable>`).

La chiave `sb_publishable_t5vFAehg…Fh5m` e l'URL `https://ywbuzgwbkrmkukkpysbz.supabase.co` compaiono in chiaro (`apps/admin_portal/lib/admin-api.ts:372,379` e nel client Flutter): sono pubbliche per design, **non è un finding**.

### A4. Ramo `origin/roberto` — note specifiche

- Tip `5784ab3` (2026-10-02), 10 commit non in main (merge-base `4284db4`); diff vs main: 15 file.
- Credenziali demo: vedi A1 (`login_page.dart`, `vercel_build_flutter_web.sh`). Nessuna occorrenza di `Demo1234`. `scripts/setup/seed_demo_supabase.py` è identico nel comportamento a main: legge `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` da `.env`, nessuna credenziale in chiaro.
- `scripts/setup/supabase_security_hardening.sql` (63 righe) esiste **solo su roberto** (commit `fcc5be9`), non su main; `docs/runbooks/supabase_setup.md:63` dello stesso ramo ne prescrive l'applicazione. Contenuto SQL non valutato qui (revisione separata).
- `packages/shared/config/settings.py` su roberto: `supabase_db_password` (`SUPABASE_DB_PASSWORD`) solo come campo env, default vuoto.

### A5. Workflow GitHub Actions (`.github/workflows/`, tip di `origin/main`)

Gli altri rami hanno solo versioni più vecchie/sottoinsiemi degli stessi file (nessun workflow aggiuntivo). I workflow `schedule` girano solo sul ramo di default (`main`).

| Workflow | Trigger | `permissions` | Secrets usati | Push/commit | Note |
|---|---|---|---|---|---|
| `ci.yml` | `push` (main, MULTILANG), `pull_request`, `workflow_dispatch` (inputs `distribute_firebase`, `build_number`, `release_notes`) | `contents: read` | solo nel job `firebase_distribution`: `TEST_SUPABASE_PUBLISHABLE_KEY`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | no | job Firebase condizionato a `workflow_dispatch` + `github.ref == refs/heads/MULTILANG` + `environment: firebase-testing`; gli input arrivano a `run:` **via `env:`**, non interpolati → nessuna script injection; `prepare_firebase_build.py` scrive i file privati con `chmod 600` e li cancella in `if: always()` |
| `lint-and-test.yml` | `workflow_dispatch` | **assente** (eredita il default del repo) | nessuno | no | vedi A5.3 |
| `admin-scheduler.yml` | `schedule` ogni ora, `workflow_dispatch` | `contents: read` | `RADAR_SUPABASE_SERVICE_ROLE_KEY` (usato solo per derivare `sha256("vetapp-admin-scheduler:"+key)`) | no | chiama `POST https://vet-app-psi-nine.vercel.app/admin/scheduler/tick` (URL hardcoded); il backend confronta l'hash con `hmac.compare_digest` (`admin.py:1099-1105`) |
| `events-import.yml` | `schedule` lun 05:00, `workflow_dispatch` | `contents: read` | `RADAR_SUPABASE_URL`, `RADAR_SUPABASE_SERVICE_ROLE_KEY` | no (scrive su Supabase) | |
| `radar-places-import.yml` | `schedule` mensile, `workflow_dispatch` | `contents: read` | idem | no (scrive su Supabase) | |
| `legislative-watch.yml` | `schedule` lun 06:00, `workflow_dispatch` | **`contents: write`, `issues: write`** | `GITHUB_TOKEN` | **sì: `git push` diretto sul ramo corrente (main)** | vedi A5.1 |
| `translation-drafts.yml` | `push` (main, MULTILANG, path filter), `workflow_dispatch` | `contents: read` | `DEEPL_API_KEY` | no | artifact `translation-drafts-<sha>` 14 gg: contiene solo bozze di traduzione |

Verificati e **non presenti**: `pull_request_target`, `${{ github.event.pull_request.title/body }}`, `${{ github.head_ref }}` o altri input non fidati dentro `run:`; artifact contenenti segreti. Le PR da fork girano `ci.yml` senza segreti (i tre job `flutter`/`quality`/`admin_portal` non ne usano; `firebase_distribution` non è raggiungibile da una PR).

#### A5.1 `legislative-watch.yml` committa e pusha direttamente su `main` — **Media**
**Dove**: `.github/workflows/legislative-watch.yml:8-10, 28-34`.
**Problema**: il bot (`GITHUB_TOKEN` con `contents: write`) esegue `packages.infrastructure.compliance.legislative_watch` (scarica contenuti da siti esterni) e committa `docs/compliance/legislative-watch` con `git push` sul ramo di default, senza PR né revisione. `issues: write` permette anche di aprire issue.
**Impatto**: contenuto scaricato da terzi entra nel ramo di produzione (da cui Vercel fa deploy) senza occhio umano; se la branch protection non blocca i push del token, il workflow è un canale di scrittura su `main` non revisionato. Nessun segreto esposto.
**Correzione**: far aprire una PR al bot (es. `peter-evans/create-pull-request` pinnata a SHA) invece del push diretto; oppure limitare `permissions` al minimo e verificare su GitHub che la branch protection di `main` richieda PR anche per le GitHub Apps ("da verificare su GitHub").

#### A5.2 Action di terze parti su tag mutabili, non su SHA — **Bassa**
**Dove**: tutti i workflow: `actions/checkout@v4`, `actions/setup-python@v5`, `actions/setup-node@v4`, `actions/setup-java@v4`, `actions/upload-artifact@v4`, `subosito/flutter-action@v2`, `astral-sh/setup-uv@v5`.
**Impatto**: un tag può essere spostato su codice malevolo (è successo nel 2025 a `tj-actions/changed-files`); nei job con segreti (`firebase_distribution`, import Supabase, DeepL) l'action compromessa leggerebbe la service-role key, il keystore e il service account Firebase.
**Correzione**: pinnare a commit SHA completo con commento di versione; aggiungere Dependabot per `github-actions` (vedi A5.5).

#### A5.3 `lint-and-test.yml` senza blocco `permissions` — **Bassa**
**Dove**: `.github/workflows/lint-and-test.yml` (solo `workflow_dispatch`, nessun segreto).
**Impatto**: il `GITHUB_TOKEN` riceve i permessi di default del repository (potenzialmente write-all se l'impostazione non è stata ristretta). Il job non li usa, ma un'action compromessa potrebbe.
**Correzione**: aggiungere `permissions: contents: read`; in Settings → Actions impostare "Read repository contents permission" come default ("da verificare su GitHub").

#### A5.4 Nessun lockfile versionato — **Media** (supply chain / riproducibilità)
**Dove**: `.gitignore:17` ignora `uv.lock`; `apps/admin_portal/` non ha `package-lock.json`; `ci.yml:91-92` esegue `npm install` e `uv sync` senza lock.
**Impatto**: ogni run di CI e ogni build Vercel risolve versioni transitive diverse; un pacchetto compromesso o una regressione entra senza che nessuno l'abbia revisionata; `npm audit` non è nemmeno eseguibile (vedi B6).
**Correzione**: togliere `uv.lock` dal `.gitignore` e committarlo; generare e committare `package-lock.json`; in CI usare `npm ci` e `uv sync --frozen`.

#### A5.5 Nessun Dependabot/Renovate — **Bassa**
Nessun `.github/dependabot.yml` né `renovate.json` in nessun ramo. Aggiungere Dependabot per `github-actions`, `npm` (`/apps/admin_portal`), `pip`/`uv` e `pub`.

#### A5.6 Artifact APK pubblici — **Info**
`ci.yml:57-60` carica `vetapp-test-apk` (debug, flavor prod) a ogni push/PR e `vetapp-multilang-release-<n>` (release firmata, 7 giorni). Su repo pubblico gli artifact sono scaricabili da qualunque utente GitHub loggato. Contengono solo configurazione pubblica (URL Supabase + publishable key); nessun segreto. Da sapere, non da correggere.

#### A5.7 Branch protection — **da verificare su GitHub**
Non osservabile dal repo: richiesta PR + review su `main`/`Francesco`, status check obbligatori (`CI / quality`, `flutter`, `admin_portal`), divieto di force-push, se le GitHub Apps/bot possono bypassare (rilevante per A5.1).

### A6. `.gitignore` — **Bassa**

Coperti: `.env`, `.env.*`, `.env*`, `.vercel/`, `/data/`, `.local/`; Android: `key.properties`, `**/*.jks`, `**/*.keystore`, `/local.properties`. Nessun `.vercel/`, `build/`, `.next/`, `node_modules/` committato su main.
Non coperti: `apps/mobile_app/production.env.json` (il file reale corrispondente a `production.env.example.json`, con la chiave publishable: innocuo, ma conviene ignorarlo), `google-services.json`, `dart-defines.json`, `*.p12`/`*.pem`/`*.p8`, `apps/admin_portal/.env.local` (coperto da `.env*` solo se il pattern è valutato in sottocartella: sì, è senza slash iniziale, quindi vale ovunque). Aggiungere le righe mancanti.

---

## Parte B — Admin portal (`apps/admin_portal`, Next.js, progetto Vercel `vet-app-34xp`) e backend `/admin`

### B1. Architettura dell'autenticazione — **Info (corretta)**

- **Login** (`app/login/actions.ts:24-87`, server action `"use server"`): il form POSTa e-mail/password al server Next; il server chiama `POST {SUPABASE_URL}/auth/v1/token?grant_type=password` con header `apikey = publishable` (`lib/admin-api.ts:375-381`), poi `GET {VET_API_BASE_URL}/admin/me` con `Authorization: Bearer <access_token>`. Solo se il backend risponde 200 l'access token viene messo in un cookie `vet_admin_access_token` **httpOnly, `secure` in produzione, `SameSite=Lax`, `path=/`, `maxAge` 1h** (`actions.ts:77-84`). La password non viene mai salvata né loggata; gli errori sono ricondotti a codici fissi (`?error=invalid|forbidden|…`, `login/page.tsx:6-14`).
- **Decisione "admin"**: **server-side, nel backend**. `apps/api/routes/admin.py:78-89` `_require_admin()`: (1) legge `ADMIN_EMAILS`, in fallback `DEVELOPER_EMAILS` (`:72-75`); lista vuota → **503 fail-closed**; (2) `auth_provider.get_current_user()` → `SupabaseAuthProvider.get_current_user()` (`packages/infrastructure/auth/supabase_auth_provider.py:84-100`) che prende il Bearer dal contesto (`apps/api/main.py:50-63`) e lo **verifica presso Supabase** con `admin_client.auth.get_user(token)` (token scaduto/malformato → `AuthenticationError`); (3) confronta l'e-mail (lowercase) con l'allowlist, altrimenti **403**. Tutti i 17 endpoint `/admin/*` chiamano `_require_admin()` (18 occorrenze, verificate riga per riga: 339, 345, 466, 536, 595, 625, 681, 766, 832, 942, 948, 974, 988, 1017, 1172, 1180, 1307). L'unica eccezione è `POST /admin/scheduler/tick` (`:1108`) protetto da `_require_scheduler_token` (`:1099-1105`, sha256 della service-role key + `hmac.compare_digest`).
- **Un utente normale dell'app può chiamare gli endpoint admin?** No: riceve 403 ("Admin access required"). Il JWT è valido ma l'e-mail non è in allowlist. Il client non ha alcun ruolo nella decisione.
- **Lato Next.js**: ogni pagina/azione chiama `requireAdminSession()` (`admin-api.ts:455-459`) che riesegue `/admin/me` lato server; le mutazioni passano da `authenticatedAdminRequest` che reinoltra il cookie come Bearer al backend (`:419-440`). Nessuna route handler `app/api/*`, nessun `middleware.ts`, nessun componente client con fetch diretta a Supabase. Le server action Next hanno il controllo Origin integrato (CSRF).

### B2. Nessun segreto esposto al browser — **Info (corretto)**

`grep` su tutto `apps/admin_portal` (main e gli 8 rami `feature/admin-*`, `fix/admin-*`): nessun `service_role`, `sb_secret`, `localStorage`; le uniche variabili `NEXT_PUBLIC_*` sono `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (pubbliche per design, e comunque lette solo lato server). Variabili server-only: `VET_API_BASE_URL`, `ADMIN_SUPABASE_URL`, `ADMIN_SUPABASE_PUBLISHABLE_KEY`, `NODE_ENV`. Nessun `dangerouslySetInnerHTML`, nessun `eval`. Il README dichiara "no browser-side service-role access": confermato dal codice.

### B3. Operazioni admin disponibili e requisiti

Tutte richiedono JWT Supabase valido + e-mail in allowlist (B1); tutte richiedono `PERSISTENCE_BACKEND=supabase` (`_admin_client`, `admin.py:92-103`, altrimenti 503) e usano la **service-role key** lato backend.

| Endpoint | Cosa fa | Dati personali toccati |
|---|---|---|
| `GET /admin/me` | identità admin | — |
| `GET /admin/overview` | metriche (utenti, pet, conversazioni, radar, moderazione, scrape) | conteggi; elenca tutti gli utenti Auth via `auth.admin.list_users` (fino a 100.000) per contarli |
| `GET /admin/moderation`, `GET /admin/moderation/{queue}/{id}` | code radar / chat / marketplace | testo delle risposte segnalate, annunci marketplace, id proprietari |
| `POST /admin/moderation/chat|radar|marketplace/{id}` | risolve/conferma/rigetta segnalazioni; **rimuove o ripristina annunci** | sì (scrittura) |
| `GET /admin/geographic` | sorgenti, celle di copertura e **fino a 500 utenti con e-mail + lat/long + indirizzo** (`admin.py:764-826`) | **sì: e-mail e posizione** |
| `POST /admin/geographic/preview` / `execute` | ingestione radar OSM su un punto (raggio ≤ 50 km) | — |
| `GET /admin/jobs` | storico job | — |
| `GET/POST /admin/schedules`, `POST /admin/schedules/{id}` | crea/abilita/disabilita/esegue/cancella schedulazioni (geographic/scientific) | — |
| `GET /admin/scientific`, `POST /admin/scientific/discover` / `ingest` | ricerca/ingestione evidenze scientifiche | — |
| `POST /admin/scheduler/tick` | esegue le schedulazioni scadute (chiamato da GitHub Actions) | — |

Non esistono endpoint admin di cancellazione utenti, lettura conversazioni per utente o modifica account.

### B4. `next.config.ts` senza security header — **Bassa**
**Dove**: `apps/admin_portal/next.config.ts` (solo `reactStrictMode: true`).
**Problema**: nessun `headers()` → nessuna `Content-Security-Policy`, `frame-ancestors`/`X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`; `Strict-Transport-Security` dipende da Vercel.
**Impatto**: il backoffice può essere incorniciato in un iframe di terzi (clickjacking sulle azioni di moderazione) e manca la difesa in profondità contro XSS. Non c'è XSS nota (React escapa, niente `dangerouslySetInnerHTML`).
**Correzione**: aggiungere `headers()` con `frame-ancestors 'none'` (o `X-Frame-Options: DENY`), `Referrer-Policy: no-referrer`, una CSP minima (`default-src 'self'`, Leaflet richiede `img-src` per le tile e `style-src` inline → valutare `nonce`), `Permissions-Policy: geolocation=()`.

### B5. Backend: `AUTH_BACKEND` di default `bootstrap` senza guardia in produzione — **Media** (hardening)
**Dove**: `packages/shared/config/settings.py:42` (`auth_backend` default `"bootstrap"`), `packages/bootstrap/container.py:542-561` (`BootstrapAuthProvider` quando non è `"supabase"`), `packages/infrastructure/auth/bootstrap_auth_provider.py:17-22` (ritorna sempre `demo-user` / `demo@vetapp.local` **senza leggere alcun token**), `settings.py:282-345` (`validate_backend_configuration` non impone `AUTH_BACKEND=supabase` quando `ENVIRONMENT=production` o `PERSISTENCE_BACKEND=supabase`).
**Impatto in parole semplici**: se in Vercel la variabile `AUTH_BACKEND` venisse rimossa o scritta male, l'API in produzione accetterebbe **qualsiasi** richiesta come utente `demo-user` (tutti gli utenti condividerebbero lo stesso profilo e i suoi dati). Gli endpoint `/admin/*` resterebbero protetti solo perché `demo@vetapp.local` non è nell'allowlist. Oggi presumibilmente è configurato correttamente (il portale funziona), ma è una singola variabile d'ambiente a separare "sicuro" da "aperto".
**Correzione**: in `validate_backend_configuration` aggiungere: se `environment == "production"` (o `persistence_backend == "supabase"`) allora `auth_backend` deve essere `"supabase"`, altrimenti `ValueError` all'avvio (fail-closed). Stessa cosa per il fallback silenzioso `ModuleNotFoundError → BootstrapAuthProvider` fuori produzione (`container.py:557-559`).

### B6. Dipendenze `package.json` — **Info / non verificabile**
- `next 16.3.8`, `react`/`react-dom 19.3.0`, `leaflet 1.9.4`; dev: `typescript 7.0.2`, `@types/*`. Versioni esatte (senza `^`).
- **CVE-2025-29927** (bypass middleware, < 15.2.3 / < 14.2.25): **non applicabile** — versione 16.x e **nessun `middleware.ts`** nel portale; l'autorizzazione è nelle pagine/azioni server e nel backend.
- `npm audit --omit=dev` **non eseguito**: nel worktree non esistono né `node_modules` né `package-lock.json` (non installare era un vincolo dell'audit). Dopo aver committato un lockfile (A5.4) eseguire `npm ci && npm audit --omit=dev` e aggiungere Dependabot.

### B7. Altre osservazioni sul portale — **Bassa**
- **Logout non revoca il token** (`actions.ts:89-93` cancella solo il cookie): un token copiato resta valido fino a scadenza (≤ 1h). Accettabile; per rigore chiamare `POST /auth/v1/logout` di Supabase o `auth.admin.sign_out`.
- **`/admin/geographic` restituisce e-mail + coordinate** di fino a 500 utenti a ogni apertura della pagina "Data → Geographic": minimizzazione dati (mostrare solo conteggi/cluster; e-mail solo su richiesta esplicita) e assicurarsi che Vercel/Next non logghino i payload.
- **URL di produzione hardcoded come fallback** (`admin-api.ts:363, 372`): non è un segreto, ma se `VET_API_BASE_URL` manca il portale parla con la prod senza che nessuno lo noti; preferibile fallire se la variabile non è impostata.
- **Allowlist admin = fallback su `DEVELOPER_EMAILS`** (`admin.py:74`): chi è "developer" (bypass trial) è automaticamente admin. Impostare `ADMIN_EMAILS` esplicito e separato.
- **Nessuna CORS in produzione** (`main.py:38-47`): corretto per il portale (server-to-server) — il client Flutter web deve quindi essere same-origin o avere la propria configurazione; non è un problema di sicurezza.
- **Scheduler token** = sha256 della service-role key inviato in header: se un log di Vercel/GitHub lo registra, chi lo ottiene può solo far scattare le schedulazioni già definite (nessuna lettura/scrittura arbitraria). Bassa; in alternativa usare un secret dedicato `ADMIN_SCHEDULER_TOKEN`.

---

## Chiavi da ruotare

| Segreto | Dove vive / dove si ruota | Perché |
|---|---|---|
| Password dell'account `demo-founder-01@vetapp.ai` (`<password-demo-mascherata>`) | **Supabase Dashboard** (progetto canonico `ywbuz…`) → Authentication → Users: eliminare o resettare password + disattivare; **Vercel** (progetto web/preview del ramo roberto) → rimuovere env `DEMO_FOUNDER_EMAIL` / `DEMO_FOUNDER_PASSWORD` se presenti | Hardcoded in chiaro su rami pubblici `origin/roberto` e `origin/MOTORE-ANAMNESI` (A1); bakeata nel JS di eventuali deploy web di quei rami. La storia pubblica non è bonificabile. |
| Nessun'altra chiave | — | Nella storia completa (403 commit, 34 rami) **non** risultano esposti: `SUPABASE_SERVICE_ROLE_KEY`/`sb_secret_`, JWT, `LLM_API_KEY` (Groq `gsk_`), Google `AIza`, token Firebase/Vercel, CARTO, `DEEPL_API_KEY`, password keystore Android, keystore `.jks`, service account Firebase, stringhe DB Postgres. Nessuna rotazione richiesta da questa evidenza. |

Rotazioni **non richieste ma consigliate per igiene** (nessuna evidenza di esposizione): nessuna. Misure preventive al posto delle rotazioni: MFA sui tre account gmail dell'allowlist admin (A2); pin a SHA delle action (A5.2) perché i job con segreti (`RADAR_SUPABASE_SERVICE_ROLE_KEY`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `ANDROID_KEYSTORE_*`, `DEEPL_API_KEY`) dipendono dalla loro integrità.

---

## Elenco riepilogativo per gravità

| # | Gravità | Finding |
|---|---|---|
| A1 | Media | Password account demo reale hardcoded su `origin/roberto` e `origin/MOTORE-ANAMNESI` (mai su main/Francesco) |
| A5.1 | Media | `legislative-watch.yml` pusha contenuti esterni direttamente su `main` con `contents: write` |
| A5.4 | Media | Nessun lockfile (`uv.lock` ignorato, `package-lock.json` assente): build non riproducibili, `npm audit` impossibile |
| B5 | Media | `AUTH_BACKEND` default `bootstrap` senza guardia in produzione: una env mancante apre l'API come utente demo |
| A2 | Bassa | E-mail personali degli sviluppatori (= allowlist admin) nella storia di main e in `tests/unit/test_subscription.py` |
| A5.2 | Bassa | Action di terze parti su tag mutabili (`@v4`, `@v2`…) nei job con segreti |
| A5.3 | Bassa | `lint-and-test.yml` senza `permissions:` |
| A5.5 | Bassa | Nessun Dependabot/Renovate |
| A6 | Bassa | `.gitignore` non copre `production.env.json`, `google-services.json`, `dart-defines.json`, `*.p12/*.pem` |
| B4 | Bassa | Admin portal senza CSP / `frame-ancestors` / Referrer-Policy |
| B7 | Bassa | Logout senza revoca token; `/admin/geographic` espone e-mail+posizione di 500 utenti; fallback URL prod hardcoded; admin = fallback su developer |
| A3, A4, A5.6, B1, B2, B3, B6 | Info | Nessun segreto forte nella storia; auth admin server-side corretta; nessun segreto lato browser; CVE-2025-29927 non applicabile |
| A5.7 | da verificare su GitHub | Branch protection di `main`/`Francesco`, permessi di default del `GITHUB_TOKEN`, chi può lanciare `workflow_dispatch` |
