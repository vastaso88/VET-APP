# Brainstorm registrazione, login e recupero credenziali

Idee raccolte progressivamente per l'area "Registrazione, log-in e recupero credenziali". Non ancora prioritizzate né validate: servono come materiale grezzo da cui, in futuro, estrarre feature concrete.

## Stato attuale del codice (2026-09-26)

A differenza di altre aree (Impostazioni, Mappe), qui esiste già un'implementazione consistente, non uno spazio vuoto. Punto di partenza per qualunque idea futura:

- **Flutter** (`apps/mobile_app/lib/features/auth/`) — flusso completo end-to-end, architettura pulita (domain/data/presentation):
  - Pagine: [login_page.dart](../../apps/mobile_app/lib/features/auth/presentation/pages/login_page.dart), [register_page.dart](../../apps/mobile_app/lib/features/auth/presentation/pages/register_page.dart), [reset_password_page.dart](../../apps/mobile_app/lib/features/auth/presentation/pages/reset_password_page.dart), più [auth_placeholder_page.dart](../../apps/mobile_app/lib/features/auth/presentation/pages/auth_placeholder_page.dart) come landing (Accedi / Crea un account).
  - Domain: [auth_repository.dart](../../apps/mobile_app/lib/features/auth/domain/auth_repository.dart) (interfaccia: `signInWithPassword`, `signUpWithPassword`, `resetPasswordForEmail`) + relativi usecase.
  - Data: [auth_repository_factory.dart](../../apps/mobile_app/lib/features/auth/data/auth_repository_factory.dart) sceglie a runtime tra [supabase_auth_remote_data_source.dart](../../apps/mobile_app/lib/features/auth/data/supabase_auth_remote_data_source.dart) (Supabase reale) e [fake_auth_remote_data_source.dart](../../apps/mobile_app/lib/features/auth/data/fake_auth_remote_data_source.dart) (doppio in-memory per test/offline), in base a `config.hasSupabaseCredentials`.
- **Backend** (`apps/api/`) — più scarno, solo passthrough:
  - [routes/auth.py](../../apps/api/routes/auth.py): `POST /auth/signup`, `POST /auth/login`, `GET /auth/me`. **Nessuna rotta di recupero password** — il reset oggi passa solo dal client Flutter direttamente a Supabase (`resetPasswordForEmail`), bypassando l'API.
  - Wired via `packages/infrastructure/auth/` (provider Supabase + fake) e `packages/core/application/ports/auth_provider.py` (la porta non ha un metodo di reset).
- **Docs correlati**: [docs/decisions/005-supabase-for-initial-auth-and-data.md](../decisions/005-supabase-for-initial-auth-and-data.md) (scelta di Supabase), [docs/frontend/05-supabase-integration.md](../frontend/05-supabase-integration.md) (integrazione). Nessun doc dedicato ad auth esisteva prima di questo file.

## Gap noti da valutare

- **Reset password lato backend assente**: se in futuro serve tracciare/loggare i tentativi di reset, inviare notifiche interne, o applicare policy custom (es. rate limiting) sul recupero credenziali, serve aggiungere una rotta + metodo sulla porta `auth_provider`. Oggi Supabase gestisce tutto lato client.
- **Nessun test auth-specifico individuato** in una prima passata — da verificare con un grep mirato di `tests/` prima di modificare i flussi esistenti.
- **Link "password dimenticata" dalla pagina di login**: non verificato riga per riga se esiste già un collegamento diretto da `login_page.dart` a `reset_password_page.dart`, o se la pagina di reset è raggiungibile solo come rotta standalone.

## Restyle + trial/piani + logout (2026-09-26)

Implementato in questa sessione, ora che l'estetica delle pagine auth è stata portata sotto la responsabilità di "Registrazione, log-in e recupero credenziali" (non più "UI/UX e funzionalità base"):

- **Restyle**: [auth_widgets.dart](../../apps/mobile_app/lib/features/auth/presentation/widgets/auth_widgets.dart) non usa più un gradiente/colori hardcoded ma i design token reali (`AppColors.background`, colori semantici per i banner) — stesso linguaggio visivo di Impostazioni/Billing. Stesso fix per lo sfondo di [splash_page.dart](../../apps/mobile_app/lib/app/splash/splash_page.dart).
- **"Resta connesso"**: checkbox in login, campo `rememberMe` propagato in `AuthContext`; `PersistentAuthSessionStore.restore()` scarta la sessione locale se non era stata "ricordata" (decisione presa direttamente in questa sessione, non lasciata come TODO: niente revoca remota del token, solo pulizia locale).
- **Logout**: la voce "Esci" in `settings_page.dart` (già presente ma non collegata) ora chiama `AuthRepository.signOut()` e naviga a `/auth`. Bug trovato e corretto nel farlo: serviva `Navigator.of(context, rootNavigator: true)` perché ogni tab della shell ha il proprio Navigator annidato che ignora il nome della route.
- **Trial 10 giorni + piani**: nuovo dominio backend `packages/core/domain/subscription/` (pattern identico ai consensi account), rotte `GET/POST /subscription/status` e `/subscription/select-plan`, allowlist sviluppatori (`Settings.developer_emails`) con accesso illimitato. Lato Flutter: `SubscriptionGate` decide home vs paywall dopo login/cold-start; `PaywallPage` blocca l'accesso a trial scaduto; `billing_page.dart` mostra il countdown reale invece del solo demo store.
- **Bug pre-esistente corretto**: `FakeAuthRemoteDataSource._sessionFor` usava `Random().nextInt(1 << 32)`, che va in `RangeError` su web (dart2js/DDC tronca `<<` a 32 bit) — bloccava ogni registrazione/login sul path senza Supabase. Sostituito con una costante sicura.
- **Ambiente Python risolto (2026-09-26, stesso giorno)**: installato Python 3.12 via `winget install Python.Python.3.12` (bypassa il blocco certificati che impediva a `uv` di scaricare l'interprete da GitHub) e `uv sync --system-certs --extra dev` per installare anche pytest/ruff/mypy. `ruff check .` pulito, `mypy` pulito (a parte 3 errori pre-esistenti e attesi per `presidio_analyzer`, extra `privacy` non installato), **358 test passati** incluso il nuovo `tests/unit/test_subscription.py` (6 test). Comando pronto per il futuro: `uv sync --python "C:\Users\syste\AppData\Local\Programs\Python\Python312\python.exe" --system-certs --extra dev`.
- **Fix testuale (revisione legale/marketing)**: il badge "Più scelto" su Pro in `billing_demo_store.dart` affermava una popolarità reale senza dati a supporto (nessun utente pagante esiste ancora) — sostituito con "Consigliato".
- **Rimosso il bypass "anteprima web senza login"**: su web, senza credenziali Supabase configurate, l'app saltava login/registrazione e apriva direttamente una home demo ("Ospite") — impostato in due punti: `app.dart` (`initialRoute` puntava a `/preview-dashboard` invece che a `/` splash) e `splash_page.dart` (stesso controllo ridondante). Rimossi entrambi, insieme alla route `/preview-dashboard` stessa (`app_router.dart`) così non resta nemmeno raggiungibile digitando l'URL a mano. Ora ogni avvio passa sempre da `SplashPage` → `restoreSession()` → onboarding/login se non c'è una sessione valida, sia su web che su mobile. Verificato: avvio pulito atterra su `/onboarding`.
- **Bug del "Logout" nella pagina Profilo**: separato da quello di Impostazioni, la pagina `profile_page.dart` (Impostazioni → riga "Ospite") aveva un secondo bottone "Logout" mai collegato, puro placeholder. Ora chiama il vero `signOut()` con lo stesso dialog di conferma di Impostazioni.
- **Eliminato il flusso di onboarding a 3 pagine** (welcome/value-proposition/privacy-disclaimer, `lib/features/onboarding/`) su richiesta esplicita dell'utente ("mai visto in un'app", "porcherie portate da vecchie automazioni") — cartella rimossa interamente, nessun altro codice/test ne dipendeva. Lo splash ora manda chi non ha una sessione valida direttamente su `/auth` (non più `/onboarding`, rotta rimossa da `app_router.dart`). Il campo `onboardingCompleted` su `AuthContext`/`AppUser` resta nel modello (usato da Supabase/persistenza) ma non gate più nessuna navigazione.
- **Restyle pagina iniziale**: rimossa la pillola verde "VET APP" in alto (`_BrandRow` in `auth_widgets.dart`, condivisa da tutte le pagine auth) — ora mostra solo il link "Indietro" quando applicabile, nient'altro quando non c'è nulla da cui tornare. Titolo di `auth_placeholder_page.dart` cambiato in "Vet-App: i tuoi pet a portata di zampa".

## Bug: nuovi account vedevano gli animali demo + nuovo flusso di primo accesso (2026-09-26)

- **Bug corretto**: `PetDemoStore` (`lib/features/pets/data/pet_demo_store.dart`) è un singleton in-memory globale, seminato all'avvio con `samplePets` (Moka/Oliver/Rex) **indipendentemente da chi ha fatto login** — ogni account, nuovo o esistente, vedeva sempre lo stesso terzetto. Ora parte vuoto (`_pets = []`).
  - **Attenzione, gap architetturale più ampio** (fuori scope per questa sessione, segnalato non risolto): l'intera feature Pets lato Flutter — e a occhio anche Reminders/Chat/News — non è collegata al backend reale (`packages/core/domain/pet_profile`, che esiste e ha CRUD completo lato API). È tutto locale/in-memory, quindi **niente persiste tra riavvii dell'app**, per nessun account. Chi possiede Pets/Home (probabilmente "UI/UX e funzionalità base" o una sessione di integrazione dedicata) dovrebbe costruire un vero `PetsRemoteDataSource` che chiama `/pets` con l'owner autenticato, sul modello di `HttpAccountConsentsRemoteDataSource`/`HttpSubscriptionRemoteDataSource` già fatti in questa sessione.
- **Nuovo flusso di primo accesso post-registrazione** (`lib/features/first_run/`), sostituisce il semplice dialog "10 giorni gratis":
  1. `PlanIntroPage` — propone la prova gratuita di 10 giorni (CTA primaria, nessuna carta) oppure la scelta immediata di un piano (Free/Plus/Pro, card compatte).
  2. `TutorialPage` — 3 slide scorrevoli (profilo pet, assistente AI, promemoria), con pallini di progresso, "Salta" sempre disponibile, "Avanti"/"Inizia".
  3. `AddFirstPetPromptPage` — invito opzionale/bypassabile ad aggiungere il primo animale, apre il vero `PetCreatePage` oppure "Salta per ora".
  - Bug trovato e corretto durante il test: un `OutlinedButton` inline in una `Row` andava in crash ("BoxConstraints forces an infinite width") perché il tema app-wide impone `minimumSize: Size.fromHeight(...)` (larghezza infinita) a tutti gli `OutlinedButton`/`FilledButton`/`ElevatedButton` — chi aggiunge un bottone di questi *non* a piena larghezza deve sempre passare `minimumSize: Size.zero` esplicito in `styleFrom`.
  - Verificato end-to-end in browser: registrazione → prova gratuita → tutorial → salta/aggiungi pet → home, senza animali demo.

## Richiesta permesso notifiche + audit bug strutturali (2026-09-26, stesso giorno)

- **Nuovo step**: `NotificationPermissionPage` inserita tra `TutorialPage` e `AddFirstPetPromptPage` — chiede il permesso di sistema per le notifiche (naturale dopo che il tutorial ha appena parlato di promemoria), sempre bypassabile ("Non ora"), non blocca mai il flusso anche se la piattaforma non supporta il prompt nativo (try/catch). Aggiunta dipendenza `permission_handler` (pubspec.yaml) e permesso `POST_NOTIFICATIONS` in `android/app/src/main/AndroidManifest.xml` (richiesto da Android 13+). Verificato in browser: nessun crash, flusso completo fino alla home.
- **Audit "bug strutturali"**: cercato in tutto `lib/` altre chiamate `pushNamed`/`pushReplacementNamed`/`pushNamedAndRemoveUntil` per verificare se soffrissero dello stesso bug del Navigator annidato trovato in Impostazioni/Profilo (2026-09-26, sessione precedente) — nessun'altra occorrenza trovata; erano già tutte o su pagine top-level (splash, login, register, paywall) o già corrette con `rootNavigator: true`.
- **Verificato**: le chiamate reali al backend (`/account/consents`, `/subscription/status`) ora vanno correttamente sulla porta 8003 (non più 8090) grazie al fix del `--dart-define=API_BASE_URL` in `.claude/launch.json`.
- **Non toccato di proposito**: la costante `samplePets` in `pet_models.dart` è ora dead code (solo `PetDemoStore` la usava) ma l'ho lasciata perché un'altra sessione sta lavorando proprio su Pets/PetDemoStore in parallelo (task_2930135e) — rischio di conflitto senza beneficio reale.

---

Altre idee su questa area verranno aggiunte in questo file mano a mano.

**Promemoria**: quando il materiale in questo file sarà sufficiente, l'utente chiederà un riassunto delle potenziali feature da validare e pianificare, sintetizzando le idee raccolte qui.
