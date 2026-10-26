# Audit di sicurezza passivo — backend FastAPI VetApp

Data: 2026-10-26. Worktree: `C:\Users\syste\Documents\VetApp\.claude\worktrees\security-audit-cdfeea` (branch `claude/security-audit-cdfeea`, stato pulito). Audit **in sola lettura del codice**: nessun servizio di produzione contattato, nessuna credenziale usata, nessun file del repo modificato.

Perimetro: `apps/api/` (main.py, routes/*, schemas/*), `packages/` (core/application, infrastructure, bootstrap, shared), `scripts/`, `.github/workflows/`, `scripts/setup/*.sql` (solo come documentazione dello schema: lo stato reale del DB va verificato sul progetto Supabase).

Scala di gravità: **Critica** (accesso a dati di altri utenti o controllo dell'applicazione senza credenziali), **Alta** (bypass di un controllo di sicurezza o indisponibilità del servizio causabile da un singolo utente), **Media** (difesa mancante che serve in produzione; impatto condizionato da configurazione), **Bassa** (igiene, minimizzazione, hardening).

---

## 0. Come funziona l'autenticazione (contesto per tutto il resto)

- `apps/api/main.py:48-61` — un middleware legge `Authorization: Bearer <jwt>` e lo mette in una contextvar (`packages/shared/auth_context.py`). Non verifica nulla.
- `packages/infrastructure/auth/supabase_auth_provider.py:89-113` — `get_current_user()` chiama `self._admin_client.auth.get_user(access_token)`: il token è **verificato lato server da Supabase** (chiamata di rete a GoTrue), non decodificato localmente. Bene. L'unico decode locale senza firma è `sign_in_time_from_token` (righe 39-71) che legge `amr`/`iat` per la cancellazione account: accettabile perché lo stesso token è già stato verificato nella stessa richiesta.
- **Ogni rotta decide da sola se chiamare `get_current_user()`**: non esiste una dependency FastAPI applicata al router. Chi dimentica la chiamata lascia la rotta pubblica (è successo: vedi 1.1).
- `packages/infrastructure/persistence/supabase/client.py:11-26` — **tutti i repository usano un unico client con la SERVICE ROLE KEY**: le policy RLS del database **non si applicano** alle query del backend. Quindi il controllo "è tuo?" deve essere fatto nel codice, servizio per servizio. I repository leggono per id senza filtro proprietario (`supabase_repositories.py:95-96` pet, `116-118` conversazioni, `756-758` allegati): è corretto come design solo se il servizio chiamante confronta `owner_id`. Dove non lo fa, chiunque può leggere/scrivere i dati di chiunque conoscendo l'id.
- L'app Flutter accede anche **direttamente** a Supabase (con anon key + JWT utente, quindi con RLS) alle tabelle `clinical_events`, `pet_profiles`, `pet_photos`, `reminders`, `dog_walks`, `pet_conditions`, `user_locations`, `marketplace_listing_reports`, `local_activities`, `events` e ai bucket `pet-photos`/`marketplace-photos` (grep su `apps/mobile_app/lib`). Quella parte è fuori da questo audit; dipende dalle policy RLS live, da verificare sul progetto (lo schema in `scripts/setup/supabase_schema.sql` abilita RLS su tutte le 35 tabelle `public.*` e definisce policy `*_own` per le tabelle utente, ma il commento in `supabase_account_eraser.py:27-28` dice che "the live database was set up by hand": **da verificare** che corrisponda).

---

## 1. Autenticazione e autorizzazione delle rotte

### 1.1 — GET e PUT `/pets/{pet_id}` senza autenticazione e senza controllo di proprietà
- **Gravità: Critica**
- **Dove:** `apps/api/routes/pets.py:29-32` (GET) e `45-52` (PUT); `packages/core/application/services/get_pet_profile.py:20-24`; `packages/core/application/services/update_pet_profile.py:37-56`.
- **Problema:** le due rotte non chiamano `get_current_user()` e i servizi caricano il profilo per id senza confrontare `owner_id`. Il client Supabase è service-role, quindi RLS non interviene. Confronto: le rotte sorelle `GET/PUT /pets/{pet_id}/medical-record-consent` (pets.py:60-63, set_medical_record_consent.py:32) fanno il controllo correttamente.
  ```python
  @router.get("/{pet_id}")
  def get_pet(pet_id: str) -> dict[str, object]:
      result = get_container().get_pet_profile_service().execute(GetPetProfileInput(pet_id=pet_id))
  ```
- **Impatto in parole semplici:** chiunque su Internet, senza account, conoscendo l'id di un animale, legge il profilo completo (nome, specie, razza, note libere, microchip, stato del consenso alla cartella clinica, `owner_id` del proprietario) e può **riscriverlo** (PUT) cambiando nome, note, microchip ecc. Gli id non sono indovinabili a caso, ma compaiono nelle risposte di altre rotte, negli URL, nei log, nel portale admin e nelle segnalazioni.
- **Correzione consigliata:** in entrambe le rotte aggiungere `user = container.auth_provider.get_current_user()` e passare `owner_id=user.id`; in `GetPetProfileService.execute` e `UpdatePetProfileService.execute` rifiutare con `ValidationError("pet_profile not found")` se `pet_profile.owner_id != data.owner_id` (stesso pattern di `set_medical_record_consent.py:32`). Aggiungere un test d'integrazione "utente B non vede/modifica il pet di A" (oggi `tests/integration/test_api_flows.py:29-34` usa il provider bootstrap e non lo copre). Più in generale: applicare una `Depends(require_user)` a livello di router per tutto ciò che non è esplicitamente pubblico, così la dimenticanza non è più possibile.

### 1.2 — POST `/chat`: `pet_id` e `conversation_id` di altri utenti accettati
- **Gravità: Critica**
- **Dove:** `apps/api/routes/chat.py:12-29`; `packages/core/application/services/send_chat_message.py:181-183` (pet) e `392-397` (conversazione).
- **Problema:** `execute` carica il pet con `self._pet_profile_repository.get(data.pet_id)` e controlla solo che esista; `_load_or_create_conversation` carica `stored = self._repository.get(data.conversation_id)` e la restituisce senza confrontare `conversation.owner_id` con `data.owner_id`. L'unico controllo di proprietà presente è sugli allegati (riga 384) e sul replay (riga 336). Nota: `edit_chat_message.py:58`, `delete_conversation.py:22`, `rename_conversation.py:29`, `vet_summary.py:75` invece controllano correttamente, quindi è una svista specifica di `send_chat_message`.
  ```python
  if data.conversation_id:
      stored = self._repository.get(data.conversation_id)
      if stored:
          return migrate_legacy_title(stored)
  ```
- **Impatto in parole semplici:** un utente autenticato qualsiasi, conoscendo l'id di una conversazione altrui, invia un messaggio in quella chat e riceve in risposta **l'intera conversazione** (`SendChatMessageOutput.conversation`, righe 92-93, con tutti i messaggi dell'altro proprietario), ci scrive dentro e fa generare risposte dal modello sul contesto dell'altro. Conoscendo l'id di un pet altrui può aprire conversazioni su quel pet: l'orchestratore legge allora gli eventi clinici del pet (`medical_record_context_retriever.py:174,195`, se il proprietario ha concesso il consenso a livello pet) e li usa nella risposta, cioè **espone la cartella clinica di un animale a un estraneo**. In più le conversazioni create così contano nel limite "4 per animale" del vero proprietario (riga 400-406), che può essere bloccato dal creare nuove chat. Le misure del peso sono invece filtrate per owner (riga 141-153) e non trapelano.
- **Correzione consigliata:** in `execute` rifiutare se `pet_profile.owner_id != data.owner_id`; in `_load_or_create_conversation` rifiutare se `stored.owner_id != data.owner_id` (come `delete_conversation.py:22`); in `already_answered`/`list_by_pet` filtrare per owner. Aggiungere test unitari su `SendChatMessageService` per i tre casi (pet altrui, conversazione altrui, allegato altrui). Valutare un helper unico `require_owned_pet(repo, pet_id, owner_id)` riusato da tutti i servizi.

### 1.3 — Backend di autenticazione "bootstrap" come default, senza guardia in produzione
- **Gravità: Alta** (diventa Critica se la variabile manca in produzione)
- **Dove:** `packages/shared/config/settings.py:40-41` (`auth_backend` default `"bootstrap"`, `persistence_backend` default `"in_memory"`); `packages/bootstrap/container.py:542-560`; `packages/infrastructure/auth/bootstrap_auth_provider.py:16-21`; `docs/runbooks/vercel_deploy.md:33-39` (documenta proprio `ENVIRONMENT=production` + `AUTH_BACKEND=bootstrap`).
- **Problema:** se `AUTH_BACKEND` non è impostata (o vale altro da `supabase`), `BootstrapAuthProvider.get_current_user()` restituisce sempre `demo-user` senza guardare il token: ogni richiesta è "autenticata". Il validatore `validate_backend_configuration` non impone nulla quando `environment == "production"`. Inoltre con `persistence_backend=supabase` e `auth_backend=bootstrap` i repository scriverebbero sul DB reale sotto l'identità fissa `demo-user`. La memoria di progetto ricorda che il 2026-09-27 la produzione girava con zero variabili Vercel impostate.
- **Impatto:** una regressione di configurazione (nuovo progetto Vercel, rotazione variabili, ambiente di preview) rende tutto il backend accessibile senza credenziali.
- **Correzione consigliata:** nel `model_validator` di `Settings` aggiungere: se `environment == "production"` allora `auth_backend == "supabase"` e `persistence_backend == "supabase"`, altrimenti `ValueError` (il deploy fallisce invece di partire aperto). Far fallire anche il fallback `ModuleNotFoundError -> BootstrapAuthProvider` (container.py:556-558) quando `environment` non è `development`. Correggere il runbook.

### 1.4 — Rotte admin: allowlist email corretta, ma senza verifica che l'email sia confermata
- **Gravità: Media** (da verificare sul progetto Supabase)
- **Dove:** `apps/api/routes/admin.py:72-89` (`_configured_admin_emails`, `_require_admin`); fallback a `DEVELOPER_EMAILS` quando `ADMIN_EMAILS` è vuoto (riga 74).
- **Problema:** l'admin è determinato server-side dall'email del token verificato da Supabase (bene: non da header o body). Però non si controlla `email_confirmed_at`. Se nel progetto Supabase "Confirm email" fosse disattivato, o un indirizzo dell'allowlist non fosse ancora registrato, chiunque potrebbe registrarsi con quell'email via `POST /auth/signup` e diventare admin. `docs/compliance/07_contributi_utenti.md:73` conferma che "il servizio non riceve lo stato di verifica dell'email". Esistono i template "Confirm signup" (`supabase/email_templates/`), quindi la conferma è probabilmente attiva: **da verificare** nel dashboard Auth → Providers → Email.
- **Impatto:** controllo completo del portale admin (moderazione, elenco utenti con email e posizione, ingestion).
- **Correzione consigliata:** in `_require_admin` leggere `email_confirmed_at` dall'utente restituito da `get_user` (esporlo in `AuthenticatedUser`) e rifiutare se nullo; registrare preventivamente tutti gli indirizzi dell'allowlist; non usare `DEVELOPER_EMAILS` come fallback per l'admin (due liste, due scopi).

### 1.5 — Rotta di scheduling `POST /admin/scheduler/tick` con segreto derivato dalla service-role key
- **Gravità: Media**
- **Dove:** `apps/api/routes/admin.py:1099-1112`; `.github/workflows/admin-scheduler.yml:32-40`.
- **Problema:** il token atteso è `sha256("vetapp-admin-scheduler:" + SUPABASE_SERVICE_ROLE_KEY)`: un segreto statico, non ruotabile separatamente, derivato dal segreto più sensibile del sistema, inviato in chiaro (su TLS) dal workflow GitHub a ogni ora. Il confronto usa `hmac.compare_digest` (bene). Non c'è protezione da replay né scadenza. La rotta esegue ingestion Overpass e inserimenti nel DB.
- **Impatto:** chi intercetta/legge il token (log del workflow, proxy, `echo $RESPONSE` non lo stampa ma un errore di curl verboso sì) può far girare a piacere i job schedulati (costo, carico su Overpass, dati inquinati), per sempre, finché non si ruota la service key.
- **Correzione consigliata:** variabile dedicata `ADMIN_SCHEDULER_SECRET` (casuale, 32+ byte) sia su Vercel sia nei secrets GitHub; opzionalmente firma HMAC di `timestamp` con finestra di 5 minuti.

### 1.6 — Promemoria su animali altrui
- **Gravità: Bassa**
- **Dove:** `packages/core/application/services/create_reminder.py:32-35`.
- **Problema:** controlla che il pet esista ma non che sia del chiamante. Il promemoria viene salvato con `owner_id` del chiamante (quindi l'altro proprietario non lo vede), ma la rotta funziona da oracolo di esistenza degli id pet e crea riferimenti pendenti.
- **Correzione:** `if pet is None or pet.owner_id != data.owner_id: raise ValidationError("pet_profile not found")`.

### 1.7 — Portale admin: dati personali più del necessario
- **Gravità: Media** (privacy / minimizzazione)
- **Dove:** `apps/api/routes/admin.py:789-808` (`/admin/geographic` restituisce fino a 500 utenti con email, `address_label`, `latitude`, `longitude`); `admin.py:555-562` (`/admin/moderation/chat/{id}` fa `select("*")` e restituisce `reporter_ref` e `reporter_owner_id`, che `chat_response_reports.py:22-24` dichiara "never returned to a client"); `admin.py:490-525` (report marketplace con `reporter_owner_id` in chiaro).
- **Impatto:** ogni admin (e chiunque comprometta un account admin) vede l'indirizzo di casa degli utenti associato all'email; i pseudonimi dei segnalanti escono dal server contro la regola del codice stesso.
- **Correzione:** in `/admin/geographic` servire solo conteggi per cella o coordinate arrotondate senza email; nei dettagli di moderazione usare liste di colonne esplicite escludendo `reporter_ref`/`reporter_owner_id`.

### 1.8 — Controlli di proprietà verificati e corretti (per completezza)
`GET /chat-attachments/{id}/file` (chat_attachments.py:36-40), `POST /chat-attachments` (upload_chat_attachment.py:92-96), `PATCH/DELETE /conversations/{id}` e `PUT …/messages/{id}` e `GET …/summary`, `POST /chat-response-reports` (report_chat_response.py:55-59), `DELETE /local-services/reports/{id}` (radar_reports.py:323 via pseudonimo), `GET/PUT /pets/{id}/medical-record-consent`, `DELETE /account` (solo l'id dal token + sign-in recente, delete_account.py:35-38), `PUT /account/preferences` (supabase_auth_provider.py:122-134 usa l'id del token). Rotte di maintenance (`/chat/maintenance`, `/chat-response-reports/maintenance`, lista/resolve report) gated su `DEVELOPER_EMAILS` (chat.py:39-40, chat_response_reports.py:27-34): con lista vuota sono chiuse a tutti, bene.

---

## 2. Validazione input e limiti di dimensione

### 2.1 — Upload allegati chat/cartella clinica: buono
`upload_chat_attachment.py:97-113`: limite 4 MB, tipo letto dalla firma del file (`detect_media_type`) ignorando `content_type` ed estensione, solo JPG/PNG/WEBP/PDF, PDF cifrati rifiutati (`pypdf_reader.py:34-37`), max 30 pagine, testo da max 10 pagine e immagini da max 3 (`pypdf_reader.py:27-29`), metadati EXIF/XMP/Info rimossi prima dello storage (righe 122, `media_privacy.py`), chiave di storage = id generato dal server (`local_file_storage.py:29-31` toglie comunque `..`/`/`). Vercel chiude i body oltre 4,5 MB. Nessun path traversal possibile. **Residuo (Bassa):** `pypdf` su PDF ostili può costare CPU (bombe di compressione); `RecursionError` è gestito (riga 49). Suggerimento: timeout per l'analisi e limite sui byte decompressi se disponibile.

### 2.2 — Speech-to-text: nessun limite proprio e iniezione nel corpo multipart
- **Gravità: Media**
- **Dove:** `apps/api/routes/speech_to_text.py:10-23`; `packages/infrastructure/speech/groq_speech_to_text_provider.py:131-145`.
- **Problema:** `filename` e `content_type` arrivano dal client e vengono interpolati **senza escape** nelle intestazioni della parte multipart inviata a Groq:
  ```python
  (f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'.encode(),)
  (f"Content-Type: {content_type}\r\n\r\n".encode(),)
  ```
  Un filename con `"\r\n` chiude la parte e ne apre altre: il client può aggiungere campi del form (`model`, `prompt`, `language`, `temperature`, `response_format`) scelti da lui. Nessun limite di dimensione/durata sull'audio oltre i 4,5 MB di Vercel; nessun controllo del tipo (viene inoltrato qualunque byte).
- **Impatto:** l'utente sceglie il modello di trascrizione (più costoso) o parametri non previsti; carico sulla quota Groq condivisa (vedi 3).
- **Correzione:** non passare il filename del client (usare `audio.<ext>` fisso), rimuovere `\r`, `\n`, `"` da qualunque valore interpolato o costruire il multipart con `email.message`/`requests`; limitare i byte (es. 2 MB) e validare la firma (webm/ogg/m4a/wav) come si fa per le immagini.

### 2.3 — Schemi senza limiti di lunghezza
- **Gravità: Bassa**
- **Dove:** `apps/api/schemas/pets.py:7-23` (name, notes, breed… senza `max_length`), `schemas/reminders.py:6-10`, `schemas/chat_response_reports.py:9-13` (`details` senza limite: viene troncato a 1000 solo dopo l'anonimizzazione, `report_chat_response.py:90`), `schemas/auth.py:4-6`, `schemas/account_consents.py`, `schemas/subscription.py`. Il messaggio chat invece è limitato a 8000 (`schemas/chat.py:8-14`), gli eventi a 200/500 (`routes/events.py:17-26`), le segnalazioni radar a 120/160 (`local_services.py:40-48`).
- **Impatto:** righe DB arbitrariamente grandi (Vercel ferma a 4,5 MB per richiesta), CPU dell'anonimizzatore (`report_chat_response.py:100-102` gira su testo illimitato prima del clip).
- **Correzione:** `Field(max_length=…)` su tutti i campi testo (name 80, notes 2000, details 1000, title 120, email 254, password 72).

### 2.4 — Validazione risposte: `ValidationError` 400 espone testo pydantic
`update_pet_profile.py:52-55` rilancia `str(error)` di pydantic nel body 400 (`main.py:64-66`). Nessun segreto, ma messaggi tecnici all'utente. **Bassa.**

---

## 3. Rate limiting e abuso

### 3.1 — Nessun rate limiting a livello HTTP
- **Gravità: Alta**
- **Dove:** `apps/api/main.py` (nessun middleware di throttling; grep su `apps`/`packages` per "rate"/"limit" trova solo i limiti applicativi sotto).
- **Cosa esiste:** chat 20 messaggi/giorno per owner (`settings.py:138-140`, `llm_budget.py:199-226`; **fail-open** se il ledger non risponde, righe 213-216); 4 conversazioni per pet; segnalazioni radar 5/giorno (`radar_reports.py:243`); eventi `MAX_SUBMISSIONS_PER_DAY` (`submit_event.py:43`); budget token giornaliero per modello (`llm_budget.py`), che quando è esaurito spegne la chat **per tutti**.
- **Cosa manca:**
  - `POST /speech-to-text` (Whisper su Groq) e `POST /chat-attachments` (una chiamata al modello vision per upload, fino a 3 pagine per PDF scansionato) **non contano nel limite giornaliero** dell'utente: un singolo account può chiamare il modello senza limite e consumare il budget Groq condiviso (incidente già vissuto il 2026-10-05: eval → chat di produzione giù). Il budget per modello non distingue chi consuma.
  - `POST /auth/login` e `/auth/signup` sono proxy pubblici verso Supabase (`routes/auth.py:9-20`): nessuna limitazione; tutte le richieste partono dall'IP di uscita di Vercel, quindi un attacco a forza bruta tramite il backend potrebbe far scattare i limiti per-IP di Supabase Auth per **tutti** gli utenti del backend (**da verificare**: dipende dai limiti del progetto). Non c'è ragione per cui l'app passi dal backend per il login quando usa già Supabase direttamente.
  - `PUT /conversations/{id}/messages/{id}` genera una nuova risposta: va verificato che passi da `admit()` come `/chat` (passa da `respond_in`, quindi sì: `send_chat_message.py:258-262`).
  - Nessun limite per IP su rotte pubbliche (`/news`, `/legal/consents`, `/pets/{id}` finché resta pubblica).
- **Correzione:** (1) far passare STT e analisi allegati da `LlmBudget.admit()` (o un contatore dedicato per owner, es. 20 trascrizioni e 10 upload al giorno); (2) togliere `/auth/login` e `/auth/signup` dal backend o limitarli (es. 5/min per IP, `X-Forwarded-For` di Vercel) e aggiungere CAPTCHA/Turnstile lato Supabase; (3) middleware di rate limit per utente+IP (es. `slowapi`, o un contatore in `chat_user_daily_usage` generalizzato); (4) rendere il fail-open di `admit` un fail-closed quando il budget del modello è sotto la soglia di riserva.

---

## 4. CORS, header di sicurezza, HTTPS

### 4.1 — CORS
- **Gravità: Media** (dipende dalla variabile `ENVIRONMENT`)
- **Dove:** `apps/api/main.py:36-45`.
- **Problema:** se `ENVIRONMENT != "production"` → `allow_origins=["*"]`, `allow_methods=["*"]`, `allow_headers=["*"]`. Il default di `ENVIRONMENT` è `"development"` (`settings.py:38`): un deploy Vercel senza la variabile (o un ambiente di preview) è aperto a qualunque origine. In produzione non c'è nessun CORS: il client web Flutter deve quindi essere servito dalla stessa origine o tramite proxy (**da verificare** come è configurato `vet-app-psi-nine.vercel.app` vs la web app). L'auth è Bearer (non cookie), quindi il rischio CSRF classico è basso; il rischio con `*` è che una pagina ostile che ha ottenuto un token possa chiamare l'API dal browser.
- **Correzione:** allowlist esplicita di origini da env (`CORS_ALLOWED_ORIGINS`) in ogni ambiente; mai `*` con `environment` non impostato.

### 4.2 — Header di sicurezza assenti
- **Gravità: Bassa** (API JSON) / **Media** per `/chat-attachments/{id}/file` che serve contenuti utente
- **Dove:** nessun middleware in `main.py`; solo la risposta file imposta `X-Content-Type-Options: nosniff` (`chat_attachments.py:53`).
- **Correzione:** middleware che aggiunge `Strict-Transport-Security: max-age=31536000; includeSubDomains`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, `Cache-Control: no-store` sulle risposte autenticate, `Content-Security-Policy: default-src 'none'; sandbox` sulla rotta file (un PDF/immagine servito `inline` potrebbe essere aperto nel browser dell'utente: con `sandbox` non esegue script). HTTPS è garantito da Vercel; il codice non lo assume in modo errato.

### 4.3 — Documentazione OpenAPI pubblica
`FastAPI(title=…)` senza `docs_url=None` (`main.py:34`), e `GET /` la pubblicizza (`health.py:16`). Espone l'elenco completo di rotte e schemi, incluse le rotte admin. **Bassa**: disattivare `docs`/`redoc`/`openapi` in produzione.

---

## 5. Gestione degli errori

### 5.1 — `ProviderError` restituisce al client il corpo della risposta del provider
- **Gravità: Media**
- **Dove:** `apps/api/main.py:71-73` (`502 {"detail": str(exc)}`); `packages/infrastructure/llm/providers/groq_chat_api.py:200-203` (`f"... status {exc.code}: {detail}"` dove `detail` è il body HTTP di Groq); `groq_speech_to_text_provider.py:117-120` idem; `groq_image_analyzer.py` analogo.
- **Impatto:** l'utente finale (e un attaccante) vede i messaggi grezzi di Groq: nomi dei modelli, limiti e residui di quota dell'organizzazione, id di richiesta, a volte stralci della richiesta rifiutata. Lo stesso vale per `HTTPException(502, detail=f"Geographic ingestion failed: {str(exc)[:500]}")` in admin.py:842-845, 909-912, 1276-1279 (solo admin).
- **Correzione:** nel gestore restituire un messaggio fisso ("Servizio temporaneamente non disponibile") con un `error_id`, e loggare `str(exc)` server-side; nei provider non includere `detail` nel messaggio dell'eccezione ma in un attributo separato.

### 5.2 — Eccezioni non gestite
Non c'è un handler generico: `APIError` di postgrest/storage3, `ValueError` dell'eraser (`supabase_account_eraser.py:100`), `AuthApiError` fuori da `get_current_user` (es. `sign_in_with_password`, `routes/auth.py:19`, con credenziali errate → eccezione non catturata → 500) diventano 500 con body Starlette di default; lo stack finisce nei log Vercel. **Bassa**: aggiungere un handler per `Exception` che logga e risponde JSON generico, e catturare `AuthApiError` in `sign_in_with_password`/`sign_up` (401/400 invece di 500).

---

## 6. Logging e telemetria

- `packages/infrastructure/logging/logger.py:6-9`: `logging.basicConfig` con formato `levelname name message`, livello da `LOG_LEVEL`. Telemetria: `telemetry/noop.py` non fa nulla, `ENABLE_TELEMETRY` default `false`.
- Contenuto dei log (grep completo di `logger.*`/`print(`): **nessun log contiene email, token, prompt, messaggi, coordinate o user id**. `chat_orchestrator.py:825-845` logga solo modalità/stato/provider/specie; `llm_usage_recorder.py:79-96` solo conteggi token; `groq_chat_api.py` solo nomi dei modelli; `pypdf_reader.py:53` solo il tipo dell'eccezione; `media_metadata_cleanup.py:326-329` usa hash dei percorsi proprio per non loggare owner/pet id. Buona disciplina.
- **Residui (Bassa):** `logger.exception(...)` (es. `chat_orchestrator.py:560,568,2242`, `llm_budget.py:195-244`) stampa il traceback con `str(exc)`: se l'eccezione è una `ProviderError` contiene il body di Groq (5.1), se è una `APIError` di postgrest contiene il messaggio del DB con eventualmente valori della riga. `legislative_watch.py` usa `print` (solo script CI). Non è un problema finché i log Vercel sono riservati; sanificando le eccezioni (5.1) si risolve anche qui.
- Supabase stessa logga le chiamate `auth.get_user` per ogni richiesta (una per request: anche un costo di latenza; valutare la verifica locale della firma JWT con la chiave pubblica del progetto e cache, mantenendo la revoca via `exp` breve).

---

## 7. Segreti

- Tutti i segreti vengono da env (`settings.py`, `pydantic-settings`, `.env` non tracciato: `git ls-files` non contiene file `.env`; l'unico è `apps/mobile_app/production.env.example.json` con placeholder). Grep su `scripts/`, `apps/`, `packages/`, `.github/` per pattern di chiavi (JWT `eyJ…`, `gsk_…`, `sk_live`, password letterali): nessun segreto hardcoded. `scripts/ci/prepare_firebase_build.py:62-72` verifica che nell'APK finisca solo una chiave publishable/anon, mai service_role: ottimo.
- Service-role key: usata solo server-side (`client.py`), nei workflow GitHub come secret (`admin-scheduler.yml`, `events-import.yml`, `radar-places-import.yml`), e in `scripts/setup/seed_source_registry.py` (riceve la chiave da argomento/env, non la stampa). Mai loggata.
- **Bassa — riuso della service-role key come materiale crittografico:** `settings.py` `reporter_pseudonym_secret()` usa la service key **grezza** come salt degli pseudonimi dei segnalanti se `REPORTER_PSEUDONYM_SALT` manca; `container.py:753-767` deriva invece la chiave radar con HMAC e un'etichetta (corretto). Usare la stessa derivazione HMAC anche per il reporter, e meglio ancora variabili dedicate: una rotazione della service key oggi orfana tutti gli pseudonimi (già notato nel commento di settings).
- **Bassa — dati personali nei default:** `settings.py` `support_contact_email` default `<titolare@…>` (indirizzo personale del titolare, servito pubblicamente da `/local-services/places` e `/sources`); `overpass_user_agent` contiene l'URL di produzione. Spostare in env senza default.
- `_require_scheduler_token`: vedi 1.5.

---

## 8. Dipendenze

- `pyproject.toml:7-16`: tutte le dipendenze sono con `>=` e **non esiste alcun lock file** (`uv.lock`, `requirements.txt`, `poetry.lock` assenti da `git ls-files`). Ogni build Vercel risolve l'ultima versione disponibile: build non riproducibili e nessun controllo su cosa entra in produzione (supply chain). **Media.** Correzione: committare `uv.lock` (`uv lock`) e far usare `uv sync --frozen`/`requirements.txt` esportato nel build Vercel; aggiungere `pip-audit` (o Dependabot/`uv`-audit) in `lint-and-test.yml`.
- `pip-audit` **non è stato eseguito**: `uv run --with pip-audit pip-audit` fallisce nel worktree per errore TLS (`invalid peer certificate: UnknownIssuer`, probabile antivirus/proxy che intercetta `pypi.org`); non ho riprovato con `--native-tls` per non uscire dal perimetro "un tentativo". Versioni presenti nel venv del checkout principale (`..\..\..\.venv\Lib\site-packages`, da considerare indicative, non quelle di Vercel): fastapi 0.141.1, starlette 1.7.0, pydantic 2.13.5, supabase 2.31.0, postgrest 2.31.0, storage3 2.31.0, supabase_auth 2.31.0, pypdf 6.19.0, python-multipart 0.0.32, uvicorn 0.54.0, h11 0.16.0, anyio 4.15.1, cryptography 48.0.1, pyjwt 2.15.0. Tutte oltre le soglie delle CVE note a me: python-multipart < 0.0.18 (CVE-2024-53981, DoS nel parsing multipart) e < 0.0.7 (CVE-2024-24762); starlette < 0.40.0 (CVE-2024-47874, DoS su form) e < 0.47.2 (CVE-2025-54121); h11 < 0.16.0 (CVE-2025-43859, request smuggling); pypdf < 5.x (varie, loop infiniti / memoria su PDF malformati, es. CVE-2025-55197). Senza lock non c'è garanzia che Vercel abbia le stesse: **da verificare** con `pip freeze` nel build log.
- `xml.etree.ElementTree` per RSS (`news/rss.py:15`) con tetto di 2 MB (`MAX_FEED_BYTES`, `feed_reader.py:29`): ElementTree non risolve entità esterne; la protezione dall'espansione di entità dipende da expat ≥ 2.4.1 del runtime Python 3.12 (ok). Per sicurezza usare `defusedxml`. **Bassa.**

---

## 9. SSRF, parsing, SQL, esecuzione codice

- **SSRF: nessuna.** Tutte le URL in uscita sono fisse: Groq (`LLM_BASE_URL`), feed RSS da catalogo interno (`news/feeds.py`), Overpass da settings con fallback fisso (`overpass_places_source.py`), Europe PMC/PubMed/OpenAlex/Crossref con parametri passati per `urllib.parse.urlencode` (file `*_evidence_retriever.py:118-132`), fonti iCal/legislative lette da file di configurazione nel repo in workflow GitHub (`events/ical_source.py:55`, `compliance/legislative_watch.py:80`). Il `source_url` degli eventi segnalati dagli utenti (`routes/events.py:23`) viene solo salvato, non scaricato. `admin_create_schedule` valida il payload con gli stessi modelli pydantic (`admin.py:964-969`). I link scientifici sono limitati a host noti (`admin.py:250-258`).
- **SQL:** solo query builder PostgREST (`.eq/.in_/.lt`) e `rpc` con parametri JSON; nessuna stringa SQL costruita a mano (grep negativo).
- **Esecuzione codice / deserializzazione:** nessun `eval`, `exec`, `pickle`, `yaml.load`, `os.system`. L'unico `subprocess.run` è in `legislative_watch.py:163` con lista di argomenti fissa (`gh issue create …`), senza shell; il titolo deriva dal nome della fonte nel repo, non da input utente. OK.
- **Parsing PDF/immagini:** `pypdf` puro Python e parser JPEG/PNG/WEBP scritti a mano (`media_privacy.py`): nessuna libreria nativa (niente ImageMagick/Pillow), superficie ridotta; i parser gestiscono `struct.error/IndexError`. Bene.
- **Prompt injection via allegati/record:** fuori perimetro di questo audit (il testo dei documenti caricati e degli eventi clinici entra nel prompt del modello: `upload_chat_attachment.py:134-147`, `medical_record_context_retriever.py`). Segnalo solo che il modello non ha strumenti/azioni, quindi l'impatto è limitato alla qualità della risposta.

---

## 10. Cancellazione account ed esportazione dati

- `DELETE /account` (`account.py:9-21`, `delete_account.py:33-38`): agisce solo sull'id del token; richiede un sign-in negli ultimi 5 minuti letto dall'`amr` del token (`supabase_auth_provider.py:39-71`); cancella prima i dati, poi l'identità (`delete_identity` → `auth.admin.delete_user`). `supabase_account_eraser.py:29-76` elenca esplicitamente tutte le tabelle con dati del proprietario (17 tabelle per owner id, 3 per pseudonimo radar, 1 per pseudonimo chat, `clinical_events` via pet), i file nei bucket `chat-attachments` (per chiave), `pet-photos` e `marketplace-photos` (cartella `<uid>/` con paginazione), e un test confronta l'elenco con lo schema SQL. `_require_user_id` evita il prefisso vuoto che svuoterebbe un bucket intero. **Buono.** Residui: (Bassa) la cancellazione non è transazionale: se `auth.admin.delete_user` fallisce dopo l'erase l'utente può ripetere (previsto); le righe `llm_usage`/`chat_answer_cache` sono aggregate senza owner (ok); i report chat con `reporter_owner_id` legacy vengono cancellati (ok); `scrape_runs.owner_id` contiene l'id dell'admin che ha lanciato il job e **non è nell'elenco** (`admin.py:879`) — se un admin cancella il proprio account resta il suo uid lì (**da verificare** se la tabella è nello schema: il test dell'eraser dovrebbe segnalarlo se lo fosse).
- **Esportazione dati (GDPR art. 20): nessuna rotta.** Grep su `apps/api/routes` per "export" trova solo un commento. **Media** (obbligo normativo, non vulnerabilità): aggiungere `GET /account/export` che restituisca pet, conversazioni, promemoria, consensi, misure, passeggiate, allegati (come zip o JSON con link firmati), con lo stesso vincolo di sign-in recente.

---

## 11. Altri punti (Bassa)

- `GET /marketplace/listings` (`marketplace.py:36-41`) restituisce `owner_id` del venditore (`marketplace/models.py:44`) a ogni utente autenticato: espone gli uid Supabase degli altri (utili per correlare segnalazioni e, finché 1.1/1.2 restano aperte, per attacchi mirati). Escluderlo dal `model_dump` e usare un id listing-scoped per "contatta il venditore".
- `GET /conversations/{id}/summary` (`conversations.py:74-75`) legge conversazione e pet **prima** del controllo di proprietà fatto nel servizio; nessuna fuga nel body, ma letture inutili su dati altrui: spostare il controllo in testa.
- `POST /subscription/select-plan` (`select_plan.py:21-27`): l'utente si assegna qualunque piano (`SubscriptionPlan.ALL`, inclusi quelli a pagamento) senza pagamento, e **nessuna rotta applica `has_access`** (solo `GET /subscription/status` lo calcola; `/chat` non lo controlla). Oggi i prezzi sono placeholder (memoria di progetto), quindi è una scelta di prodotto; quando arriverà il pagamento, il piano dovrà essere scritto solo dal webhook dello store/PSP e `has_access` verificato in `/chat`, `/chat-attachments`, `/speech-to-text`.
- `routes/auth.py:9-20`: login/signup via backend con password in body JSON: ok su TLS, ma raddoppia la superficie (vedi 3.1); se l'app usa già Supabase direttamente, rimuoverle.
- `legal.py`, `news.py`, `health.py`: pubbliche per scelta, senza dati personali. `GET /` e `/health` rivelano `environment` e `app_name`: innocuo.
- Bucket `marketplace-photos` è `public = true` (`supabase_schema.sql:1520-1525`): per scelta (foto annunci pubblici), ma chi ha l'URL vede la foto anche dopo la rimozione dell'annuncio finché il file resta; l'eraser lo cancella con l'account. `chat-attachments` e `pet-photos` sono privati (`923-925`, `1031-1033`) con policy per cartella uid.

---

## Appendice A — Tabella completa delle rotte

Legenda "Auth": **No** = nessuna chiamata a `get_current_user`; **JWT** = `auth_provider.get_current_user()` (Supabase `auth.get_user` server-side); **Dev** = JWT + email in `DEVELOPER_EMAILS`; **Admin** = JWT + email in `ADMIN_EMAILS` (fallback `DEVELOPER_EMAILS`); **Secret** = header `X-VetApp-Scheduler`. "Proprietà": dove viene confrontato `owner_id` con l'utente del token.

| Metodo | Path | Auth | Proprietà / scoping | Note |
|---|---|---|---|---|
| GET | `/` | No | — | health.py:8 |
| GET | `/health` | No | — | health.py:20 |
| GET | `/docs`, `/redoc`, `/openapi.json` | No | — | default FastAPI (4.3) |
| GET | `/legal/consents` | No | — | legal.py:11, catalogo pubblico |
| GET | `/news` | No | — | news.py:20, snapshot condiviso |
| POST | `/auth/signup` | No | — | auth.py:9, proxy Supabase |
| POST | `/auth/login` | No | — | auth.py:17, proxy Supabase |
| GET | `/auth/me` | JWT | id dal token | auth.py:23 |
| GET | `/pets` | JWT | `list_by_owner(user.id)` | pets.py:21 |
| POST | `/pets` | JWT | `owner_id=user.id` | pets.py:35 |
| GET | `/pets/{pet_id}` | **No** | **nessuna** | pets.py:29 — **1.1 Critica** |
| PUT | `/pets/{pet_id}` | **No** | **nessuna** | pets.py:45 — **1.1 Critica** |
| GET | `/pets/{pet_id}/medical-record-consent` | JWT | pets.py:62-63 | ok |
| PUT | `/pets/{pet_id}/medical-record-consent` | JWT | set_medical_record_consent.py:32 | ok |
| GET | `/conversations` | JWT | `list_by_owner` | conversations.py:16 |
| PATCH | `/conversations/{id}` | JWT | rename_conversation.py:29 | ok |
| PUT | `/conversations/{id}/messages/{message_id}` | JWT | edit_chat_message.py:58 | ok; genera risposta LLM, passa da `admit()` |
| GET | `/conversations/{id}/summary` | JWT | vet_summary.py:75 | pre-lettura prima del check (11) |
| DELETE | `/conversations/{id}` | JWT | delete_conversation.py:22 | ok |
| POST | `/chat` | JWT | allegato: send_chat_message.py:384; **pet: nessuna (181-183); conversazione: nessuna (393-397)** | **1.2 Critica**; quota 20/giorno |
| POST | `/chat/maintenance` | Dev | — | chat.py:32 |
| POST | `/chat-attachments` | JWT | upload_chat_attachment.py:92-96 | 4 MB, firma file, metadati rimossi |
| GET | `/chat-attachments/{id}/file` | JWT | chat_attachments.py:36-37 | 404 uniforme, nosniff |
| POST | `/chat-response-reports` | JWT | report_chat_response.py:55-59 | pseudonimo |
| DELETE | `/chat-response-reports/mine` | JWT | id dal token | |
| GET | `/chat-response-reports` | Dev | — | |
| PUT | `/chat-response-reports/{id}/resolve` | Dev | — | |
| POST | `/chat-response-reports/maintenance` | Dev | — | |
| GET | `/reminders` | JWT | `list_by_owner` | reminders.py:11 |
| POST | `/reminders` | JWT | `owner_id=user.id`; **pet non verificato** (create_reminder.py:33) | 1.6 Bassa |
| POST | `/speech-to-text` | JWT | n/a | nessun limite proprio; 2.2, 3.1 |
| GET | `/subscription/status` | JWT | id dal token | |
| POST | `/subscription/select-plan` | JWT | id dal token | qualunque piano senza pagamento (11) |
| GET | `/local-services/places` | JWT | `viewer_id` solo per extra | dati pubblici |
| GET | `/local-services/sources` | JWT | — | |
| GET | `/local-services/countries` | JWT | — | |
| GET | `/local-services/reports/options` | JWT | — | |
| POST | `/local-services/reports` | JWT | pseudonimo `user.id`; 5/giorno; regole accettate | |
| POST | `/local-services/reports/{id}/vote` | JWT | pseudonimo; no auto-voto | |
| DELETE | `/local-services/reports/{id}` | JWT | radar_reports.py:323 | ok |
| PUT | `/local-services/ratings` | JWT | pseudonimo | |
| GET | `/marketplace/listings` | JWT | — | espone `owner_id` venditori (11) |
| POST | `/events/submissions` | JWT | `owner_id=user.id`; limite giornaliero | |
| GET | `/account/consents` | JWT | id dal token | |
| POST | `/account/consents` | JWT | id dal token | |
| GET | `/account/preferences` | JWT | id dal token | |
| PUT | `/account/preferences` | JWT | supabase_auth_provider.py:122-134 | |
| DELETE | `/account` | JWT + sign-in ≤ 5 min | id dal token | 10 |
| GET | `/admin/me` | Admin | — | admin.py:337 |
| GET | `/admin/overview` | Admin | — | elenca tutti gli utenti auth |
| GET | `/admin/moderation` | Admin | — | |
| GET | `/admin/moderation/{queue}/{item_id}` | Admin | — | `select("*")` espone reporter (1.7) |
| POST | `/admin/moderation/chat/{report_id}` | Admin | — | |
| POST | `/admin/moderation/radar/{report_id}` | Admin | — | |
| POST | `/admin/moderation/marketplace/{report_id}` | Admin | — | |
| GET | `/admin/geographic` | Admin | — | email + indirizzo + coordinate di 500 utenti (1.7) |
| POST | `/admin/geographic/preview` | Admin | — | chiama Overpass |
| POST | `/admin/geographic/execute` | Admin | — | ingestion + scrittura DB |
| GET | `/admin/jobs` | Admin | — | |
| GET | `/admin/schedules` | Admin | — | |
| POST | `/admin/schedules` | Admin | — | payload rivalidato |
| POST | `/admin/schedules/{schedule_id}` | Admin | — | run_now esegue ingestion |
| POST | `/admin/scheduler/tick` | **Secret** (sha256 della service key) | — | 1.5 |
| GET | `/admin/scientific` | Admin | — | |
| POST | `/admin/scientific/discover` | Admin | — | chiamate a Europe PMC/PubMed/… |
| POST | `/admin/scientific/ingest` | Admin | — | rpc `admin_ingest_scientific_documents` |

Totale: 66 rotte (3 di documentazione incluse). Pubbliche per scelta: 6. Pubbliche per errore: **2** (`GET/PUT /pets/{pet_id}`). Autenticate ma con proprietà mancante: **2** (`POST /chat` su pet/conversazione; `POST /reminders` su pet).

## Appendice B — Cosa non ho potuto verificare (e perché)

- Stato reale delle policy RLS, dei bucket e dell'opzione "Confirm email" sul progetto Supabase `ywbuz`: audit solo del codice, nessuna chiamata a servizi live.
- Variabili d'ambiente effettive su Vercel (`ENVIRONMENT`, `AUTH_BACKEND`, `ADMIN_EMAILS`, `CORS`): non consultabili da qui; le conseguenze di ciascun caso sono descritte in 1.3 e 4.1.
- CVE sulle versioni in produzione: `pip-audit` bloccato da TLS locale; nessun lock file da cui ricavare le versioni deployate.
- Origine della web app Flutter rispetto all'API (per giudicare l'assenza di CORS in produzione).
