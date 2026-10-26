# Audit tecnico di sicurezza e protezione dati (2026-10-26)

Audit **passivo**: lettura del codice e della configurazione, più un controllo
di esposizione sul progetto Supabase reale eseguito **solo con la chiave
pubblica (publishable)** in sola lettura, senza alcuna credenziale riservata e
senza test intrusivi. Nessun dato personale è stato letto o stampato.

I report dettagliati per area (con file e riga per ogni rilievo) sono in
`docs/security/audit/`: `backend.md`, `flutter.md`, `llm.md`, `repo_ci_admin.md`.
Questo documento li riassume e dice, per ogni rilievo, **cosa è già stato
corretto** in questo ramo e cosa resta da fare e a chi.

Scala di gravità: **Critica** = accesso a dati di altri utenti o controllo
dell'app senza credenziali; **Alta** = un controllo di sicurezza aggirabile o
un singolo utente può bloccare il servizio; **Media** = difesa mancante che
serve in produzione; **Bassa** = igiene, minimizzazione, hardening.

Stato: ✅ corretto in questo ramo (con test) · 🗄️ SQL da eseguire dal
proprietario · 👤 azione del proprietario (dashboard, chiavi, contratti) ·
🧭 decisione di prodotto/legale · 🔧 da fare in una sessione di sviluppo.

## 1. Riepilogo: i rilievi più importanti

| ID | Gravità | Rilievo | Stato |
| --- | --- | --- | --- |
| BE-1 | Critica | `GET`/`PUT /pets/{id}` senza login e senza controllo di proprietà: chiunque, con l'id di un animale, ne leggeva e riscriveva il profilo (note, microchip, consenso) | ✅ |
| BE-2 | Critica | `POST /chat` accettava `pet_id` e `conversation_id` di altri utenti: un utente loggato leggeva l'intera chat altrui e faceva leggere al modello la cartella clinica di un animale non suo | ✅ |
| DB-2 | Alta | Conferma e-mail **disattivata** su Supabase (`mailer_autoconfirm = true`, verificato live): ci si registra con l'indirizzo di chiunque senza dimostrare di possederlo; con l'allowlist admin basata sull'e-mail era una via verso il backoffice | 👤 attivare "Confirm email"; ✅ lato backend admin/developer richiedono e-mail verificata |
| DB-1 | Alta | `marketplace_listings` leggibile **senza login** (policy `using (true)`, verificato live: 1 annuncio, con `owner_id`, posizione ~1 km, città) | 🔧 in correzione dalla sessione UI/UX; vedi §3 |
| BE-3 | Alta | Backend di autenticazione "demo" come default: se su Vercel mancava `AUTH_BACKEND` ogni richiesta era autenticata come utente demo | ✅ in produzione il backend ora **rifiuta di partire** senza `AUTH_BACKEND=supabase` e `PERSISTENCE_BACKEND=supabase` |
| LLM-1 | Alta | Il messaggio **grezzo, non anonimizzato** partiva verso Groq (USA) attraverso il normalizzatore della ricerca scientifica, contro il confine dichiarato nei documenti di compliance | ✅ |
| LLM-2 | Alta | Foto di referti e audio partono in chiaro verso Groq (USA); nessun contratto (DPA), impegno di non conservazione o di non addestramento documentato | 🧭 👤 vedi `06_inventario_dati_fornitori.md` |
| BE-4 | Alta | Nessun rate limiting; dettatura e allegati fuori dalla quota giornaliera: un solo account può esaurire il budget Groq per tutti | ✅ parziale (limite best-effort per client su login/signup/dettatura/allegati, limite 4 MB audio); 🔧 quota per utente su visione e dettatura |
| APP-1 | Alta | APK **debug** (debuggable, non offuscato, con credenziali di produzione) distribuiti ai tester secondo il runbook | ✅ runbook corretto; 🧭 togliere l'artefatto debug scaricabile dal workflow CI |
| APP-2 | Alta | "Resta connesso" deselezionato non onorato: la sessione Supabase restava su disco e l'app rientrava senza password | ✅ |
| REPO-1 | Media | Password di un account demo reale scritta nel codice sui rami pubblici `origin/roberto` e `origin/MOTORE-ANAMNESI` (mai su main/Francesco) | 👤 eliminare/reset dell'account demo, rimuovere le env `DEMO_FOUNDER_*` su Vercel, ripulire i rami |
| APP-3/4/5 | Media | Backup Android attivo (sessione e indirizzo di casa su Google Drive); al logout restavano posizione di casa, animali in memoria, passeggiata interrotta, widget, foto profilo del vecchio utente | ✅ |
| BE-12 | Media | Nessuna esportazione dei dati dell'utente (GDPR art. 20, portabilità) | 🔧 |
| REPO-4 / BE-11 | Media | Nessun lockfile (`uv.lock` è in `.gitignore`), dipendenze non bloccate: build non riproducibili, `pip-audit` non eseguibile | 👤 gestore git: `uv lock` e togliere `uv.lock` da `.gitignore`; Dependabot ✅ aggiunto |

Rilievi **positivi** da mantenere: JWT verificato lato server da Supabase a ogni
richiesta; RLS attiva su tutte le 35 tabelle dello schema e, dal controllo
live, nessuna tabella con dati personali restituisce righe senza login; bucket
`chat-attachments` e `pet-photos` privati e non elencabili; la descrizione
OpenAPI di PostgREST non è leggibile con la chiave publishable; upload allegati
robusti (4 MB, tipo dalla firma del file, metadati EXIF/PDF rimossi); nessuna
SSRF, nessun SQL costruito a mano, nessun `eval`/`pickle`; log senza dati
personali; nessun segreto nella storia git (403 commit, 34 rami) salvo REPO-1;
cancellazione account completa con test che enumera le tabelle; "admin" deciso
solo lato server; nessun `pull_request_target` né injection nei workflow.

## 2. Supabase (database, RLS, storage, auth)

### Controllo live di esposizione (chiave publishable, sola lettura)

Metodo: richiesta `HEAD` con `Prefer: count=exact` su ogni tabella dello schema
(script riutilizzabile: `scripts/security/check_anon_exposure.py`).

| Risultato | Tabelle |
| --- | --- |
| Esistono, RLS nega tutto ad anonimo (0 righe) | pet_profiles, conversations, clinical_events, pet_conditions, reminders, account_consents, subscriptions, user_locations, dog_walks, marketplace_listing_reports, chat_attachments, chat_response_reports, local_activities, chat_response_report_counters, radar_coverage_cells, radar_places_cache, pet_photos, data_sources, radar_places_osm, radar_places_open, radar_place_overrides, radar_user_reports, radar_report_votes, radar_place_ratings, admin_ingestion_schedules, llm_usage, llm_usage_daily, chat_user_daily_usage, chat_answer_cache, pet_weight_measurements, pet_news_snapshots, event_submissions, billing_subscriptions |
| Righe leggibili senza login | **marketplace_listings** (1 riga, 17 colonne tra cui `owner_id`) · events (5, voluto) · billing_plans (3, catalogo) |
| Privilegio revocato ad anonimo (401) | billing_founder_slots, billing_webhook_events (conferma che `supabase_security_hardening.sql` è stato applicato) |
| Tabella assente in produzione (404) | **radar_country_coverage** (prevista dallo schema: eseguire `supabase_schema.sql` aggiornato) |
| Bucket | lista bucket vuota per anonimo; radice pubblica dei tre bucket non elencabile |
| Auth | registrazione aperta, solo provider e-mail, **conferma e-mail disattivata** |

### Rilievi

| ID | Gravità | Rilievo | Stato |
| --- | --- | --- | --- |
| DB-1 | Alta | Annunci leggibili senza login con `owner_id` (uid Supabase del venditore) | 🔧 sessione UI/UX: policy `to authenticated` e colonna `owner_id` fuori dalla risposta all'app; `security_2026_10_26.sql` lascia volutamente il grant per non interferire |
| DB-2 | Alta | Conferma e-mail disattivata | 👤 Authentication → Providers → Email → Confirm email ON |
| DB-3 | Media | Il ruolo `anon` ha privilegi su tutte le tabelle: la difesa è affidata solo alle policy (una `using (true)` futura espone tutto) e l'esistenza delle tabelle è enumerabile | 🗄️ `scripts/setup/security_2026_10_26.sql` revoca i privilegi di anon (e di authenticated sulle tabelle solo-backend) e cambia i privilegi di default per le tabelle future |
| DB-4 | Media | `radar_country_coverage` manca in produzione: lo schema applicato è più vecchio dello script | 🗄️ rieseguire `supabase_schema.sql` |
| DB-5 | Bassa | `supabase_security_hardening.sql` (applicato il 2026-10-02) esisteva solo sul ramo `roberto` | ✅ copiato in `scripts/setup/` per documentare lo stato applicato |
| DB-6 | Bassa | Bucket `chat-attachments` senza limite di dimensione né tipi ammessi lato storage | 🗄️ nello stesso script: 5 MB, jpeg/png/webp/pdf |
| DB-7 | Bassa | Protezione password compromesse (HaveIBeenPwned) e 2FA degli account dashboard | 👤 |

Funzioni `security definer`: tutte con `set search_path` e `revoke … from
public, anon, authenticated` + `grant … to service_role` (ledger, cache,
segnalazioni); `set_updated_at` e le funzioni `ai.*` sistemate dall'hardening
del 2026-10-02. Service role usata solo nel backend e nei workflow GitHub
(secret). Nessun rilievo.

## 3. Backend FastAPI (`apps/api`, `packages/`)

Tabella completa delle 66 rotte con tipo di autenticazione e punto del
controllo di proprietà: `audit/backend.md`, appendice A.

| ID | Gravità | Rilievo | Stato |
| --- | --- | --- | --- |
| BE-1 | Critica | `GET`/`PUT /pets/{pet_id}` pubblici e senza proprietà | ✅ `routes/pets.py`, `get_pet_profile.py`, `update_pet_profile.py` (+ test) |
| BE-2 | Critica | `POST /chat` su pet/conversazione altrui | ✅ `send_chat_message.py` (+ 3 test) |
| BE-3 | Alta | Auth "bootstrap" di default senza guardia in produzione | ✅ `settings.py` (+ test) |
| BE-4 | Alta | Nessun rate limiting HTTP; dettatura/allegati fuori quota | ✅ `apps/api/rate_limit.py` (per token o IP, best-effort su serverless), limite 4 MB audio; 🔧 contatore per utente su visione/dettatura/riassunto (`LlmBudget.admit`) |
| BE-5 | Media | Corpo d'errore di Groq (quote, modelli, id richiesta) restituito al client (502) | ✅ messaggio fisso + `error_id`, dettaglio solo nel log |
| BE-6 | Media | Iniezione nel multipart verso Groq Whisper (filename/content-type con CR/LF) | ✅ `groq_speech_to_text_provider.py` (+ test) |
| BE-7 | Media | Admin/developer senza verifica che l'e-mail sia confermata; fallback admin = `DEVELOPER_EMAILS` | ✅ `email_verified` dal token (`email_confirmed_at`); 👤 impostare `ADMIN_EMAILS` esplicito su Vercel |
| BE-8 | Media | `/admin/geographic` espone e-mail + indirizzo + coordinate di 500 utenti; dettaglio moderazione esponeva lo pseudonimo del segnalante | ✅ pseudonimo escluso; 🧭 portale admin: solo conteggi per cella o coordinate arrotondate senza e-mail |
| BE-9 | Media | Token dello scheduler = sha256 della service-role key, non ruotabile | ✅ `ADMIN_SCHEDULER_SECRET` dedicato (fallback legacy finché non impostato); 👤 impostarlo su Vercel e nei secrets GitHub |
| BE-10 | Media | CORS `*` quando `ENVIRONMENT` manca; nessun header di sicurezza; `/docs` pubblico | ✅ in produzione CORS solo da `CORS_ALLOWED_ORIGINS`, header `nosniff`/`DENY`/`no-referrer`/HSTS/`no-store`, docs spenti |
| BE-11 | Media | Dipendenze non bloccate, `pip-audit` non eseguito (TLS locale) | 👤 `uv lock` + CI con `pip-audit`; ✅ Dependabot |
| BE-12 | Media | Nessuna esportazione dati (art. 20) | 🔧 `GET /account/export` JSON con sign-in recente |
| BE-13 | Bassa | Promemoria su animali altrui | ✅ |
| BE-14 | Bassa | Campi testo senza lunghezza massima | ✅ `schemas/pets.py`, `reminders.py`, `chat_response_reports.py`, `auth.py` |
| BE-15 | Bassa | E-mail personale del titolare come default di `SUPPORT_CONTACT_EMAIL` (repo pubblico) | ✅ default vuoto; 👤 **impostare `SUPPORT_CONTACT_EMAIL` su Vercel** (altrimenti l'app non mostra un contatto) |
| BE-16 | Bassa | `/marketplace/listings` espone `owner_id` dei venditori | 🔧 sessione marketplace |
| BE-17 | Bassa | `select-plan` assegna qualunque piano; `has_access` mai verificato in `/chat` | 🧭 quando arriva il pagamento |
| BE-18 | Bassa | Eccezioni non gestite → 500 con corpo di default; errori Supabase su login/signup → 500 | ✅ handler generico + login/signup rispondono 401/400 senza dettagli |
| BE-19 | Bassa | Service-role key grezza come salt degli pseudonimi | 🔧 `REPORTER_PSEUDONYM_SALT` dedicato (la rotazione orfana gli pseudonimi: pianificarla) |
| BE-20 | Bassa | `/conversations/{id}/summary` legge prima di controllare la proprietà (nessuna fuga) | 🔧 |

## 4. LLM / chat (Groq)

Tabella completa "dati inviati a Groq": `audit/llm.md` §1.5. In sintesi vanno
al provider: messaggio corrente e ultimi 6 messaggi (anonimizzati con le
regole), nome dell'animale, specie/razza/età/sesso/peso/condizione corporea,
note del proprietario (anonimizzate), promemoria, cartella clinica solo con
consenso per animale (anonimizzata), **byte delle foto** e **byte audio**.
Mai inviati: e-mail, id utente, telefono, posizione, microchip del profilo.

| ID | Gravità | Rilievo | Stato |
| --- | --- | --- | --- |
| LLM-1 | Alta | Messaggio grezzo al normalizzatore delle parole chiave | ✅ `chat_orchestrator.py` (+ test) |
| LLM-2 | Alta | Foto/audio in chiaro verso gli USA; termini Groq (DPA, retention zero, no training) non verificati; Presidio non attivo in produzione (filtro a regole) | 🧭 👤 prima del lancio: DPA/SCC Groq, attivare "Zero Data Retention"; valutare OCR o dettatura sul dispositivo |
| LLM-3 | Media | Microchip volutamente escluso dall'anonimizzazione | 🧭 sostituire con `[MICROCHIP]` salvo le ultime 3 cifre |
| LLM-4 | Media | Visione e dettatura fuori dal budget condiviso e dalla quota per utente | 🔧 (vedi BE-4) |
| LLM-5 | Media | Divieto di consigli terapeutici solo nel prompt: insistendo si ottengono farmaci e dosi | 🔧 sessione Chat: validatore della risposta (lista farmaci/dosi) |
| LLM-6 | Media | Testo estratto dagli allegati rientra nel prompt senza delimitatori (prompt injection persistente, oggi solo autolesiva) | 🔧 sessione Chat: delimitare e marcare come "dati, non istruzioni" |
| LLM-7 | Bassa | Classificatore d'urgenza manipolabile ma non decisivo (le liste fisse vincono); cache risposte: parole personali solo it/en; conversazioni e file senza scadenza; documenti PII non allineati | 🔧 |
| LLM-8 | Bassa | Avviso "stai parlando con un assistente automatico, non con un veterinario" assente dalla schermata chat (solo badge per messaggio e ToS): AI Act art. 50 dal 2 agosto 2026 | 🔧 sessione UI |

Prompt injection: i blocchi deterministici (emergenze, dosaggi) agiscono
**prima** del modello e non sono aggirabili dal testo; l'output JSON dei
classificatori è validato contro liste chiuse; nessun `eval`, nessun URL
seguito, nessun HTML renderizzato. Il system prompt è esfiltrabile ma non
contiene segreti.

## 5. App Flutter (Android, web)

| ID | Gravità | Rilievo | Stato |
| --- | --- | --- | --- |
| APP-1 | Alta | APK `--debug` ai tester (runbook e artefatto CI) | ✅ runbook; 🧭 workflow `ci.yml`: non pubblicare `app-prod-debug.apk` come artefatto |
| APP-2 | Alta | "Resta connesso" non onorato con Supabase | ✅ `remember_me_store.dart`: la scelta è applicata all'avvio successivo (sign-out locale) |
| APP-3 | Media | Backup Android attivo: sessione, indirizzo di casa, bozze su Google Drive e nei trasferimenti tra dispositivi | ✅ `allowBackup=false` + regole di esclusione (API ≤ 30 e ≥ 31) |
| APP-4 | Media | Logout incompleto (posizione di casa, widget, passeggiata interrotta, foto profilo) | ✅ `bootstrap.dart`, `LocationPreferenceStore.clear()`; residuo 🔧 PDF temporanei `referti_aperti` |
| APP-5 | Media | Animali del vecchio utente in memoria dopo il login di un altro | ✅ `PetDemoStore.reset()` |
| APP-6 | Media | Indirizzo di casa inviato in chiaro a Nominatim (OSM Foundation) direttamente dall'app | 🧭 dichiararlo nell'informativa o spostare la geocodifica nel backend |
| APP-7 | Media | Release firmata in silenzio con la chiave di debug se manca la chiave | ✅ build fallisce; `-PallowDebugSigning=true` per i test locali |
| APP-8 | Media | Web senza header di sicurezza | ✅ `vercel.json` (HSTS, nosniff, frame DENY, referrer, permissions); 🔧 CSP da testare con il renderer Flutter |
| APP-9 | Media | `CARTO_API_KEY` compilata nel binario e in query string (oggi non impostata) | 🧭 proxy nel backend se si attiva |
| APP-10 | Media | `ENVIRONMENT=production` non compilato nelle build CI | ✅ `prepare_firebase_build.py` (+ test) |
| APP-11 | Bassa | Nome `SUPABASE_SERVICE_ROLE_KEY` dichiarato nel client (inutilizzato) | ✅ rimosso |
| APP-12 | Bassa | Deep link `vetapp://auth-callback` (PKCE mitiga); receiver del widget esportato; nessun `--obfuscate`; `debugPrint` in release con dati di promemoria; coordinate in query string; uid nell'URL delle foto annunci; manca spiegazione prima dei permessi posizione/microfono; nessun limite client per foto | 🔧 |
| APP-13 | Bassa | Pacchetti aggiornabili (supabase_flutter 2.17→2.18, file_picker, permission_handler, image…) | 👤 Dependabot ✅; aggiornare a un rilascio |

Elenco dati per il modulo **Data safety** di Google Play: `audit/flutter.md`,
appendice A; permessi: appendice B.

## 6. Repository pubblico, CI, portale admin

| ID | Gravità | Rilievo | Stato |
| --- | --- | --- | --- |
| REPO-1 | Media | Password dell'account demo `demo-founder-01@…` nel codice di `origin/roberto` (dal 2026-09-29) e `origin/MOTORE-ANAMNESI` (dal 2026-03-28), anche compilata nel JS web da `--dart-define` | 👤 Supabase → Users: eliminare o resettare l'account; Vercel: rimuovere `DEMO_FOUNDER_*`; cancellare i rami dopo averne integrato il necessario. La storia pubblica non si bonifica: contano la rotazione e la rimozione |
| REPO-2 | Bassa | Tre e-mail personali degli sviluppatori (= allowlist admin via fallback) nella storia di main e in `tests/unit/test_subscription.py` | ✅ test con indirizzi fittizi; 👤 2FA su quei tre account Supabase/GitHub; `ADMIN_EMAILS` esplicito |
| REPO-3 | Media | `legislative-watch.yml` ha `contents: write` e fa push diretto su `main` di contenuti scaricati da siti esterni | 🔧 aprire una PR invece del push |
| REPO-4 | Media | Nessun lockfile (`uv.lock` ignorato, nessun `package-lock.json`) | 👤 gestore git |
| REPO-5 | Bassa | Action su tag mobili (`@v4`) nei job con segreti; `lint-and-test.yml` senza `permissions` | ✅ `permissions: contents: read`; 🔧 pin a SHA |
| REPO-6 | Bassa | Nessun Dependabot; `.gitignore` non copriva keystore/`key.properties`/`google-services.json`/dart-defines | ✅ |
| REPO-7 | — | Branch protection su `main`, 2FA GitHub, chi può lanciare `workflow_dispatch` | 👤 da verificare su GitHub |
| ADMIN-1 | Info | Login via server action, token in cookie httpOnly/secure/SameSite; "admin" deciso solo dal backend; nessun segreto nel browser; Next 16.3.8 (CVE-2025-29927 non applicabile) | ok |
| ADMIN-2 | Bassa | `next.config.ts` senza header di sicurezza; logout non revoca il token; URL di produzione come fallback nel codice | 🔧 |

## 7. Correzioni applicate in questo ramo (file)

Backend: `apps/api/main.py` (CORS, header, handler errori, docs, rate limit),
`apps/api/rate_limit.py` (nuovo), `apps/api/routes/pets.py`, `auth.py`,
`admin.py`, `chat.py`, `chat_response_reports.py`, `speech_to_text.py`,
`apps/api/schemas/{pets,reminders,chat_response_reports,auth}.py`,
`packages/core/application/services/{get_pet_profile,update_pet_profile,send_chat_message,create_reminder,chat_orchestrator}.py`,
`packages/core/application/ports/auth_provider.py`,
`packages/infrastructure/auth/supabase_auth_provider.py`,
`packages/infrastructure/speech/groq_speech_to_text_provider.py`,
`packages/shared/config/settings.py`.
Test nuovi: `tests/unit/test_security_ownership.py`,
`tests/unit/test_security_outbound_anonymization.py`,
`tests/integration/test_security_api.py`; aggiornati: `test_update_pet_profile.py`,
`test_pet_sex_migration.py`, `test_body_condition_species_gate.py`,
`test_firebase_build_config.py`, `test_subscription.py`.

App: `apps/mobile_app/lib/app/bootstrap.dart`,
`lib/features/auth/data/{auth_repository_impl,remember_me_store}.dart`,
`lib/features/location/data/location_preference_store.dart`,
`lib/features/pets/data/pet_demo_store.dart`, `lib/shared/config/app_env_keys.dart`,
`android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/{backup_rules,data_extraction_rules}.xml`,
`android/app/build.gradle.kts`, `vercel.json`.

Repo/CI: `.github/dependabot.yml`, `.github/workflows/lint-and-test.yml`,
`.gitignore`, `scripts/ci/prepare_firebase_build.py`, `docs/runbooks/android_flavors.md`.

SQL: `scripts/setup/security_2026_10_26.sql` (nuovo, da eseguire),
`scripts/setup/supabase_security_hardening.sql` (copia dello script applicato il
2026-10-02).

Strumenti: `scripts/security/check_anon_exposure.py`.

Verifiche eseguite: `pytest` 1705 → 1721 test verdi (16 nuovi), `ruff check`
pulito, `mypy` pulito tranne un errore preesistente in
`presidio_pii_anonymizer.py` (libreria opzionale non installata), `flutter
analyze` pulito, `flutter test` 1229 verdi, `check_i18n` completo.

**Attenzione al deploy** (vale per chi fa il merge): con queste modifiche il
backend in produzione **non parte** se su Vercel mancano
`AUTH_BACKEND=supabase` e `PERSISTENCE_BACKEND=supabase` (è voluto). Vanno
inoltre impostate: `SUPPORT_CONTACT_EMAIL` (prima aveva un default),
`CORS_ALLOWED_ORIGINS` (origine della web app, se usata da browser),
`ADMIN_SCHEDULER_SECRET` (opzionale ma consigliato, stesso valore nel secret
GitHub del workflow `admin-scheduler.yml`). Una build Android `--release`
locale senza `key.properties` ora fallisce: aggiungere `-PallowDebugSigning=true`
solo per prove sul proprio telefono.

## 8. Cosa non è stato verificato

- Variabili d'ambiente effettive su Vercel e stato "Confirm email" al momento
  del merge (il valore letto live il 2026-10-26 era "disattivata").
- Versioni delle dipendenze Python installate su Vercel (nessun lockfile).
- Contenuto delle policy RLS live riga per riga: il controllo con la chiave
  pubblica dimostra che gli anonimi non leggono nulla, non che un utente
  loggato non possa leggere righe altrui tramite l'accesso diretto dell'app
  (tabelle `clinical_events`, `pet_profiles`, `pet_photos`, `reminders`,
  `dog_walks`, `pet_conditions`, `user_locations`): lo schema le protegge con
  `owner_id = auth.uid()`, ma il database "è stato configurato a mano"
  (commento in `supabase_account_eraser.py`). Verifica consigliata: con due
  account di test, provare a leggere l'id dell'altro dall'app.
- Termini contrattuali di Groq, Supabase, Vercel (vedi inventario fornitori).
- Branch protection e 2FA su GitHub, Vercel, Supabase, Google.
