# Audit di sicurezza passivo — client Flutter VetApp (Android + web)

Data: 2026-10-26. Perimetro: `apps/mobile_app/` (lib/, android/, web/, pubspec.yaml, test/) nel worktree `security-audit-cdfeea`, più i file di build/CI che producono il client (`.github/workflows/ci.yml`, `scripts/ci/prepare_firebase_build.py`, `docs/runbooks/android_flavors.md`). Solo lettura: nessuna build, nessuna chiamata a servizi reali, nessuna credenziale. Versione app: `0.1.0+35` (pubspec.yaml:4). Flutter locale: 3.44.1; CI: 3.47.6 (ci.yml:135).

Tutti i percorsi sotto sono relativi a `apps/mobile_app/` salvo diversa indicazione. "da verificare" = non confermabile senza una build/manifest fuso o senza accesso al backend.

## Riepilogo per gravità

| Gravità | # | Titoli |
|---|---|---|
| Critica | 0 | — |
| Alta | 2 | A1 APK `--debug` distribuiti ai tester (debuggable, non offuscati); A2 "Resta connesso" disattivato non onorato con Supabase (sessione sempre persistita) |
| Media | 8 | M1 Backup Android non disabilitato (token + posizione + bozze nei backup cloud); M2 Posizione di casa e dati utente non cancellati al logout; M3 Animali dell'utente precedente visibili al nuovo login se la sincronizzazione fallisce; M4 Indirizzo di casa completo inviato a Nominatim (terza parte) senza informativa dedicata; M5 Release firmata con la chiave di debug se manca la chiave; M6 Web senza CSP/HSTS/anti-clickjacking; M7 `CARTO_API_KEY` compilata nel binario e in query string; M8 `ENVIRONMENT=production` non passato in CI (guardia di bootstrap inerte) |
| Bassa | 12 | B1–B12 sotto |

---

## 1. Segreti nel binario

### Valori compilati con `--dart-define` (tutte le chiavi `String.fromEnvironment`)

Fonte: `lib/shared/config/app_env_keys.dart:1-12` e `lib/shared/config/app_runtime_config_loader.dart:8-56`.

| Chiave | Letta in | Natura | Giudizio |
|---|---|---|---|
| `ENVIRONMENT` | loader:21 | development/staging/production | normale |
| `APP_NAME` | loader:26 | nome | normale |
| `API_BASE_URL` | loader:30 | URL backend | normale (pubblico) |
| `SUPABASE_URL` | loader:8 | URL progetto | normale (pubblico) |
| `SUPABASE_ANON_KEY` | loader:12 | chiave publishable | normale: è pensata per il client, la sicurezza dipende da RLS lato Supabase |
| `LOG_LEVEL` | loader:41 | stringa, **mai letta altrove** (grep su `logLevel`: solo config) | inerte |
| `ENABLE_TELEMETRY` | loader:45 | bool, **mai letta altrove** | inerte |
| `CARTO_API_KEY` | loader:49 | chiave API terza parte | **problematica** (vedi M7) |
| `WALK_MAP_STYLE` | loader:53 | osm/carto | normale |
| `SUPABASE_SERVICE_ROLE_KEY` | **dichiarata solo come nome** in app_env_keys.dart:7, nessun `fromEnvironment` la legge | — | vedi B1 |

CI (`.github/workflows/ci.yml:116-119`, `scripts/ci/prepare_firebase_build.py:103`) compila solo `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`; lo script rifiuta chiavi `service_role`/`secret` (prepare_firebase_build.py:62). Build web Vercel (`scripts/vercel_build_flutter_web.sh:29`) inoltra anche `ENVIRONMENT` e `APP_NAME`.

### Grep di segreti hardcoded (lib/, android/, web/, test/)

Pattern cercati: `sk_live|sk_test|sb_secret|service_role|AIza…|eyJ…|password=|api_key=|secret=|token=`. Risultato: **nessun segreto reale**. Trovati solo:

- `lib/features/auth/data/fake_auth_remote_data_source.dart:24` — password `'VETAPP'` dell'utente demo `demo@vetapp.local`: usata solo quando Supabase non è configurato (`AuthRepositoryFactory.create`, `lib/features/auth/data/auth_repository_factory.dart:26-35`). Vedi B2.
- `lib/shared/config/app_runtime_config_loader.dart:62-63` — due host Supabase ritirati (`dkzzcoastheciitvkiuo`, `noulpaaonqjvprfddipn`) usati come blocklist. Non sono segreti ma restano leggibili nel binario; innocui.
- `test/marketplace/listing_location_test.dart:97` — URL fittizio `x.supabase.co`.

Nessun file keystore/`key.properties`/`google-services.json`/`.env*` è tracciato in git (`git ls-files`; `.gitignore` radice righe 1-2,24; `android/.gitignore` righe 13-15 coprono `key.properties`, `*.keystore`, `*.jks`).

### Finding M7 — `CARTO_API_KEY` compilata nel binario e messa in query string
- **Gravità**: Media (oggi latente: nessuna pipeline la imposta, `walkMapStyle` di default è `osm`).
- **Dove**: `lib/features/dog_walks/presentation/widgets/walk_map_style.dart:27-30` — `'?key=${config.cartoApiKey}'` appeso all'URL dei tile `https://{s}.basemaps.cartocdn.com/...`; `lib/shared/config/app_runtime_config_loader.dart:49-52`.
- **Problema**: un `--dart-define` finisce in chiaro nel codice JS/AOT; chiunque decompili l'APK o guardi il traffico di rete estrae la chiave e consuma la quota CARTO a nome di VetApp.
- **Impatto**: abuso di quota/costi; nessun dato utente esposto.
- **Correzione**: se si attiva CARTO, limitare la chiave per referrer/package nel pannello CARTO, oppure far passare i tile da un endpoint del backend che aggiunge la chiave. In alternativa tenere OSM (scelta attuale) e rimuovere il ramo CARTO.

### Finding B1 — Nome chiave `SUPABASE_SERVICE_ROLE_KEY` presente nel client
- **Gravità**: Bassa.
- **Dove**: `lib/shared/config/app_env_keys.dart:7`.
- **Problema**: la costante esiste ma non è letta; è un invito a cablare in futuro una chiave server nel client.
- **Correzione**: eliminare la riga; aggiungere al check CI (`prepare_firebase_build.py`) un grep che fallisca se `SERVICE_ROLE` compare in `lib/`.

### Finding B2 — Utente demo con password fissa
- **Gravità**: Bassa.
- **Dove**: `lib/features/auth/data/fake_auth_remote_data_source.dart:20-29`.
- **Problema**: in una build senza `SUPABASE_URL` l'app accetta `demo@vetapp.local`/`VETAPP` e salva utenti fittizi in SharedPreferences (`vet_app.fake_auth_users`, riga 19). Non raggiungibile con Supabase configurato, ma vedi M8: in CI `ENVIRONMENT` non è `production`, quindi una build con variabili mancanti partirebbe in modalità demo invece di fallire.
- **Correzione**: con M8 risolto il rischio sparisce; opzionalmente escludere `FakeAuthRemoteDataSource` dalle build `production` con `kReleaseMode`.

---

## 2. Archiviazione locale

### Dove finisce la sessione Supabase
`Supabase.initialize` (`lib/app/bootstrap.dart:61-64`) non passa `authOptions`: valgono i default di supabase_flutter 2.17.2 — `persistSession = true`, `SharedPreferencesLocalStorage` con chiave `sb-<host>-auth-token` (pub cache `supabase_flutter-2.17.2/lib/src/supabase.dart:128-135`), `SharedPreferencesGotrueAsyncStorage` per il code verifier PKCE (riga 123-126), flusso PKCE di default. Quindi:
- **Android**: access token + refresh token in `shared_prefs/FlutterSharedPreferences.xml`, cartella privata dell'app, **non cifrati**. È lo standard supabase_flutter ed è accettabile su dispositivi non rootati; il rischio reale è il backup (M1).
- **Web**: `localStorage` del dominio dell'app. Standard per SPA; leggibile da qualunque script sullo stesso origin (vedi M6 sulle intestazioni).
- Con Supabase attivo il repository usa `MemoryAuthSessionStore` (auth_repository_factory.dart:28-31): il `PersistentAuthSessionStore` (che scriverebbe `access_token`/`refresh_token` in `vet_app.auth_context`, `persistent_auth_session_store.dart:96-102` + `lib/shared/auth/app_session.dart:40-43`) è usato **solo in modalità demo**.

### Inventario di ciò che viene scritto sul dispositivo

| Store | Chiave / percorso | Contenuto | Cancellato al logout? |
|---|---|---|---|
| Supabase (SharedPreferences) | `sb-<host>-auth-token` | access+refresh token, user (email, metadata) | Sì, da `signOut()` (supabase_auth_remote_data_source.dart:340) |
| `OwnerJsonCache` | `vet_app.cache.pets.<ownerId>`, `vet_app.cache.reminders.<ownerId>` | righe server di animali e promemoria (nomi, specie, date, note) | Sì (bootstrap.dart:87, `clearAll`) |
| `WarmStartStore` | `vet_app.warm_start.*`, `vet_app.draft.<page>` | tab aperta, stack pagine, **bozze di testo non inviate** (chat) | Sì (bootstrap.dart:88 → `RouteRestoration.forget` → `WarmStartStore.clear`, warm_start_store.dart:110-123) |
| `LocationPreferenceStore` | `vet_app.location_preference` | **coordinate di casa + etichetta indirizzo, ultima posizione GPS + timestamp** (location_preference_store.dart:88-107) | **No** (vedi M2) |
| `ActiveWalkRecoveryStore` | `vet_app.active_walk_recovery` | passeggiata in corso con traccia GPS (active_walk_recovery_store.dart:19-28) | Solo a fine/scarto passeggiata (home_shell_page.dart:202, active_walk_controller.dart:365); non al logout |
| `home_widget` (SharedPreferences `HomeWidgetPreferences`) | `dog_walks_widget_pets`, `..._active_walk` | id, nome, specie, emoji degli animali (walk_home_widget.dart:67-83) | **No** (vedi M2) |
| `PetPhotoDiskCache` | `<cache dir>/pet_photos/<owner>/<pet>/<id>.jpg` | foto degli animali scaricate (max 200 MB, pet_photo_disk_cache_io.dart:18,29-30) | Sì (bootstrap.dart:86 → pet_photo_repository.dart:144-146) |
| File temporanei | `<temp>/referti_aperti/<ts>_<nome>` (native_pdf_opener.dart:14-19); `<temp>/<export>/<pdf>` (history_export.dart:92-112); `<temp>/chat-voice-<ts>.m4a` (chat_composer.dart:441-443) | **referti medici (PDF)**, export storico clinico, registrazioni vocali | Referti: spazzati solo se più vecchi di 1 h alla prossima apertura; export: cancellato dopo lo share; vocali: cancellati dopo la trascrizione (chat_composer.dart:508). Nessuno al logout (B3) |
| `ProfilePhotoRepository._cache` (memoria) | — | foto profilo | Solo su cancellazione account (delete_account_page.dart:63), non al logout |
| `MedicalRecordFileCache` (memoria) | — | byte dei referti caricati in sessione (medical_record_file_cache.dart:13) | No (solo memoria di processo) |
| Preferenze varie | `vet_app.fake_auth_users`, lingua, unità, layout, notifiche, trial countdown, gallery save | impostazioni non personali | n/a |
| Modalità demo | `vet_app.auth_context` | token demo | Sì |

Nessun uso di Hive, sqflite, flutter_secure_storage, `window.localStorage` diretto. Non esiste cifratura applicativa: tutto si affida alla sandbox dell'app (Android) o all'origin (web).

### Finding M1 — Backup Android non disabilitato
- **Gravità**: Media.
- **Dove**: `android/app/src/main/AndroidManifest.xml:45-48` — `<application>` senza `android:allowBackup`, `android:fullBackupContent`, `android:dataExtractionRules`.
- **Problema**: con `allowBackup` al default (`true`) Android Auto Backup carica su Google Drive `shared_prefs/` e i file dell'app: refresh token Supabase, coordinate di casa, bozze chat, cache JSON di animali/promemoria, snapshot GPS della passeggiata. Da Android 12 (API 31) i trasferimenti device-to-device includono anche questi dati.
- **Impatto**: una copia dei token di sessione e dei dati sanitari/posizionali esce dal dispositivo verso l'account Google dell'utente; su un telefono ripristinato la sessione riparte senza login.
- **Correzione**: aggiungere `android:allowBackup="false"` e, per Android 12+, `android:dataExtractionRules="@xml/data_extraction_rules"` che escluda `sharedpref` e `cache`; oppure `android:fullBackupContent="@xml/backup_rules"` con `<exclude domain="sharedpref" path="FlutterSharedPreferences.xml"/>`. Da inserire nel `<application>`.

### Finding M2 — Dati dell'utente precedente che restano sul dispositivo dopo il logout
- **Gravità**: Media.
- **Dove**: logout = `settings_page.dart:404-416` + handler `AuthChangeEvent.signedOut` in `bootstrap.dart:84-89`. Nessuno dei due tocca `LocationPreferenceStore` (nessun metodo `clear`, location_preference_store.dart), i dati del widget home (`walk_home_widget.dart:82-83`, nessuna cancellazione al logout), `ActiveWalkRecoveryStore`, `ProfilePhotoRepository._cache`, i PDF in `referti_aperti`.
- **Problema**: utente A fa logout, utente B accede sullo stesso telefono: in Impostazioni → Località vede le coordinate e l'etichetta dell'indirizzo di casa di A (lo store è caricato da disco in `ensureLoaded`, non per owner); il widget "Passeggiate" continua a mostrare i nomi degli animali di A finché B non apre la lista animali; una passeggiata di A interrotta può essere proposta a B al riavvio (home_shell_page.dart:180-203, il recupero non confronta l'owner).
- **Impatto**: fuga di posizione di casa e nomi degli animali tra account diversi sullo stesso dispositivo (famiglie, telefoni condivisi, dispositivi di prova).
- **Correzione**: nell'handler `signedOut` di bootstrap.dart:84 aggiungere `LocationPreferenceStore.instance.clear()` (da scrivere: rimuove `vet_app.location_preference` e azzera `_preference`), `syncPetsToHomeWidget(const [])` + azzeramento `dog_walks_widget_active_walk`, `ActiveWalkRecoveryStore().clear()`, `ProfilePhotoRepository.clearLocalCache()`, e la pulizia delle cartelle temporanee `referti_aperti`/export. Meglio ancora: chiavare `vet_app.location_preference` per ownerId come fa `OwnerJsonCache`.

### Finding M3 — Animali dell'utente precedente in memoria al nuovo login
- **Gravità**: Media.
- **Dove**: `lib/features/pets/data/pet_demo_store.dart:214-262`. `_pets` non viene svuotato al logout (nessun `reset` chiamato: grep su `PetDemoStore.instance.(reset|clear)` vuoto). In `_hydrate`, se la query fallisce (riga 258-260, "Leave the local/demo contents in place") la lista di A resta visibile a B; se riesce, gli animali di A marcati `_unsynced` vengono fusi nella lista di B (righe 248-251) e un successivo salvataggio li scriverebbe con `owner_id` di B (`_petToRow`, riga 349-351).
- **Impatto**: con rete assente o lenta (timeout 12 s, riga 237) il nuovo utente vede nomi, specie e foto (cache disco già svuotata, ma la lista no) degli animali di un altro account; in un caso limite dati di A migrano nell'account di B.
- **Correzione**: su `signedOut` chiamare un `PetDemoStore.instance.reset()` che svuoti `_pets`, `_unsynced`, `_hydratedOwnerId`; in `_hydrate` scartare gli `_unsynced` il cui owner non coincide. Stessa verifica per `RemindersRepository` (reminders_repository.dart:143-148, stesso pattern) — da verificare.

### Finding B3 — Referti PDF in cartella temporanea per un'ora
- **Gravità**: Bassa.
- **Dove**: `lib/features/medical_records/presentation/native_pdf_opener.dart:12-19,29-40`.
- **Problema**: il file è nella cache privata dell'app (non condivisa), ma resta leggibile da chi ha accesso al filesystem (root/backup) fino alla prossima apertura di un PDF più di un'ora dopo. L'intent `OpenFilex` espone il file al visualizzatore esterno tramite FileProvider, che è il comportamento voluto.
- **Correzione**: spazzare `referti_aperti` anche al logout e all'avvio; valutare `deleteOnExit` dopo il ritorno dal visualizzatore.

---

## 3. Logout e cancellazione account

### Percorso di logout (Supabase)
1. `settings_page.dart:405` → `AuthRepositoryImpl.signOut` (auth_repository_impl.dart:181-191) → `SupabaseAuthRemoteDataSource.signOut` → `_client.signOut()` scope globale (supabase_auth_remote_data_source.dart:340) → `MemoryAuthSessionStore.clear`.
2. Evento `signedOut` (bootstrap.dart:84-89): reset lingua di sessione, `PetPhotoRepository.clearLocalCaches()` (memoria + disco), `OwnerJsonCache.clearAll()`, `RouteRestoration.forget()` (tab, stack, bozze).
3. `settings_page.dart:410`: `NotificationScheduler.instance.clearAll()` → `cancelAll()` delle notifiche programmate (local_notifications_gateway.dart:110-112).

**Non cancellati**: vedi tabella §2 e M2/M3 (posizione, widget, passeggiata in recupero, foto profilo in memoria, PDF temporanei, lista animali in memoria, `MedicalRecordFileCache`).

Nota: se `signOut()` fallisce per rete, `onFailure` mostra solo una snackbar (settings_page.dart:413-415) e la sessione locale resta; il comportamento di gotrue (rimozione locale prima della chiamata remota) è "da verificare" sulla versione 2.27.2 in lock.

### Cancellazione account
`delete_account_page.dart:54-63`: verifica password (`verifyPassword` = nuovo sign-in), `DELETE {API_BASE_URL}/account` con Bearer (supabase_auth_remote_data_source.dart:294-297), poi `signOut(scope: local)`, `NotificationScheduler.clearAll`, `PetPhotoRepository.clearLocalCaches`, `ProfilePhotoRepository.clearLocalCache`. L'evento `signedOut` scatta anche qui, quindi la pulizia è la stessa del logout più la foto profilo. Restano le lacune di M2.

---

## 4. Android

### Permessi dichiarati (manifest principale + plugin)

Dal `android/app/src/main/AndroidManifest.xml` e dai manifest dei plugin nella pub cache (`record_android-2.2.0`, `flutter_local_notifications-22.3.1`, `video_compress-3.1.4`, `open_filex-4.7.0`):

| Permesso | Origine | Uso nell'app | Nota Play Store |
|---|---|---|---|
| `INTERNET` | main:4 | tutto | nessuna |
| `POST_NOTIFICATIONS` | main:8 (+ plugin) | promemoria, notifica passeggiata | runtime 13+, chiesto in first-run (`notification_permission_page.dart:32`) |
| `RECEIVE_BOOT_COMPLETED` | main:14 | riprogrammare notifiche | nessuna; **non** dichiara `SCHEDULE_EXACT_ALARM` (scelta corretta, commento main:9-13) |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | main:17-18 | Località, passeggiate, servizi vicini | runtime; motivazione ok. **Nessun** `ACCESS_BACKGROUND_LOCATION` |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | main:27-28 | `WalkTrackingService` tipo `location` (main:136-139) | Play richiede la dichiarazione "Foreground service" con tipo *location* nel Play Console + video dimostrativo |
| `WRITE_EXTERNAL_STORAGE` maxSdk 28 | main:37-40 (sostituisce video_compress) | salvataggio in galleria pre-Android 10 (gal) | accettabile |
| `RECORD_AUDIO` | plugin record_android (manifest plugin) | messaggi vocali in chat (`chat_composer.dart:405` chiede `hasPermission`) | runtime; motivazione ok |
| `VIBRATE` | plugin flutter_local_notifications | notifiche | normale |
| `READ_MEDIA_IMAGES/VIDEO/AUDIO`, `READ_EXTERNAL_STORAGE` | open_filex, **rimossi** con `tools:node="remove"` (main:41-44) | — | corretto: Play limita `READ_MEDIA_*` |
| `CAMERA` | non dichiarato | image_picker usa la fotocamera di sistema | corretto |

Il manifest fuso di release non è presente nel checkout (nessuna build eseguita): l'elenco sopra è "da verificare" sul merged manifest, in particolare per plugin non ispezionati (geolocator_android 5.0.4: nel manifest del plugin solo il servizio, nessun permesso; share_plus, file_picker, image_picker_android, gal, home_widget: nessun `uses-permission`).

### Componenti esportati
- `MainActivity` `exported=true` (main:49-58): necessario (launcher). `taskAffinity=""` (main:53) mitiga il task hijacking. `flutter_deeplinking_enabled=false` (main:78-81): nessun URI arriva al router Flutter.
- Intent filter `android.intent.action.VIEW` schema `vetapp://auth-callback` (main:96-101): vedi B4.
- Intent filter `es.antonborri.home_widget.action.LAUNCH` (main:90-92): il widget apre l'app con `homewidget://new_reminder|start_walk?petId=…` (DogWalksWidgetProvider.kt:142-162); `petId` letto in `home_widget_action_store.dart:31`. Un'app terza può lanciare l'activity con un `petId` arbitrario: l'effetto è aprire la schermata "nuovo promemoria"/"passeggiata" per quell'id (nessuna scrittura automatica) — accettabile.
- `DogWalksWidgetProvider` receiver `exported=true` (main:107-116): vedi B5.
- `WalkTrackingService` `exported=false` (main:136-139); receiver flutter_local_notifications `exported=false` (main:119-131). Corretto.
- PendingIntent con `FLAG_IMMUTABLE` (DogWalksWidgetProvider.kt:131,147,420). Corretto.

### Rete in chiaro / TLS
- `android:usesCleartextTraffic` assente → default `false` con targetSdk ≥ 28 (targetSdk = `flutter.targetSdkVersion`, build.gradle.kts:51). Nessun `network_security_config.xml`. Nessun `http://` nel codice (grep: solo namespace XML). OK.
- Nessun certificate pinning (non richiesto; nota informativa).

### Build e firma (`android/app/build.gradle.kts`)
- `applicationId` `com.vetapp.vetapp`; flavor `francesco` e `roberto` con suffisso (righe 77-93). OK.
- Firma release: ordine env CI → `key.properties` → **debug** (righe 106-115, commento 9-15). Vedi M5.
- `isMinifyEnabled`/`isShrinkResources` **non impostati esplicitamente** (riga 106-115 passa solo `proguardFiles`). Il plugin Gradle di Flutter abilita R8 e lo shrink delle risorse sulle release di default; il commento alla riga 112 lo presuppone. Da verificare su una build release (`build/app/outputs/mapping/`): se R8 non fosse attivo i `-keep` di proguard-rules.pro sarebbero inerti e il codice nativo non offuscato.
- Nessun `--obfuscate --split-debug-info` nel comando di release (ci.yml:150-151). Vedi B6.
- `android:debuggable` non forzato nel manifest: dipende dal build type. Vedi A1.
- `gradle.properties`: nessun segreto. `settings.gradle.kts` richiede `local.properties` (git-ignorato).
- `proguard-rules.pro`: solo keep per flutter_local_notifications/Gson. Nessun `-dontobfuscate`.
- Notifica della passeggiata con `VISIBILITY_PUBLIC` (WalkTrackingService.kt:149): titolo/testo (nome dell'animale) visibili sul lock screen. Scelta di prodotto, nota per il "Data safety".

### Finding A1 — APK `--debug` distribuiti ai tester
- **Gravità**: Alta.
- **Dove**: `docs/runbooks/android_flavors.md:19-21,43` (`flutter build apk --debug --flavor … --dart-define-from-file=.env.production.json`), `.github/workflows/ci.yml:56-60` (artefatto `vetapp-test-apk` = `app-prod-debug.apk`), `docs/compliance/05_permessi_dispositivo_os.md:59` conferma che "l'ultima procedura nota per distribuire i test usa `flutter build apk --debug`". La pipeline Firebase (ci.yml:150) invece è `--release`.
- **Problema**: un APK debug ha `android:debuggable=true`, nessun R8, Dart in modalità JIT con il VM service attivo, e contiene le credenziali di produzione (`.env.production.json`). Su un telefono qualunque, `adb shell run-as com.vetapp.vetapp` legge `shared_prefs/` (token Supabase, posizione di casa) e la cache foto; un debugger si collega al processo.
- **Impatto**: chi riceve o intercetta l'APK di test può estrarre la sessione di un tester e i suoi dati sanitari; l'app è banalmente analizzabile.
- **Correzione**: distribuire solo `--release` (flavor incluso) anche per i tester, con la chiave di distribuzione; rimuovere/aggiornare il runbook; far produrre all'artefatto CI "Compile Android native localization" un `--release` o non caricarlo come artefatto scaricabile.

### Finding M5 — Release firmata con la chiave di debug se manca la chiave
- **Gravità**: Media.
- **Dove**: `android/app/build.gradle.kts:110-111` — `signingConfigs.findByName(…) ?: signingConfigs.getByName("debug")`.
- **Problema**: senza `key.properties` o variabili `ANDROID_KEYSTORE_*`, `flutter build apk --release` produce in silenzio un APK release firmato con la chiave di debug locale: non aggiornabile dagli installati con la chiave vera, non pubblicabile, e la chiave di debug è pubblica.
- **Impatto**: rischio di distribuire a tester un APK che non potrà essere aggiornato (richiede disinstallazione) o di confondersi su quale chiave è in uso.
- **Correzione**: fare `require(...)` quando il task è una release destinata alla distribuzione, oppure stampare un `logger.warn` molto visibile; in CI già c'è la verifica (righe 26-31). Il commento alla riga 15 documenta il fallback: renderlo opt-in con `-PallowDebugSigning=true`.

### Finding B4 — Deep link con schema custom per il recupero password
- **Gravità**: Bassa.
- **Dove**: `android/app/src/main/AndroidManifest.xml:96-101`, `lib/features/auth/data/supabase_auth_remote_data_source.dart:12` (`vetapp://auth-callback`).
- **Problema**: un schema personalizzato non è verificato: qualunque app può registrare `vetapp://` e ricevere il link di recupero. Con il flusso PKCE (default) il `code` è inutile senza il verifier salvato in SharedPreferences di VetApp, quindi non c'è furto di sessione; resta la possibilità di far fallire il recupero. I tre flavor sullo stesso telefono registrano tutti lo stesso schema → Android chiede quale app aprire e solo quella che ha avviato il reset può completarlo.
- **Correzione**: passare a Android App Links (`https://<dominio>/auth-callback` con `assetlinks.json`, `autoVerify="true"`) e un dominio per flavor; nel frattempo tenere PKCE (non passare a `implicit`).

### Finding B5 — Receiver del widget che accetta broadcast da qualsiasi app
- **Gravità**: Bassa.
- **Dove**: `DogWalksWidgetProvider.kt:96-98, 235-254` (azione `com.vetapp.vetapp.WIDGET_WALK_CONTROL` con extra `command`/`petId`), manifest main:107-109 `exported=true`.
- **Problema**: un `AppWidgetProvider` deve essere esportato, ma il ramo custom non verifica il mittente: un'app terza può inviare `pause`/`resume` alla passeggiata in corso o far lanciare `MainActivity`.
- **Impatto**: disturbo (pausa indesiderata di una passeggiata), nessun accesso ai dati.
- **Correzione**: proteggere l'azione con un permesso a firma (`android:permission` con `protectionLevel="signature"`) oppure, nel `PendingIntent`, usare un `Intent` esplicito e verificare in `onReceive` che l'azione arrivi solo da un PendingIntent proprio (es. token casuale nell'extra confrontato con uno salvato in prefs).

### Finding B6 — Nessuna offuscazione del codice Dart in release
- **Gravità**: Bassa.
- **Dove**: `.github/workflows/ci.yml:150-151`.
- **Problema**: senza `--obfuscate --split-debug-info=<dir>` i nomi di classi/metodi Dart restano nello snapshot AOT, facilitando il reverse engineering (non espone segreti aggiuntivi: le define sono comunque leggibili).
- **Correzione**: aggiungere i due flag e conservare i simboli come artefatto per leggere gli stack trace.

---

## 5. WebView e browser

Nessuna dipendenza `webview_flutter`/`flutter_inappwebview` (pubspec.yaml). Nessun HTML renderizzato. Le uscite verso l'esterno usano `url_launcher`:
- `events_page.dart:20`, `data_sources_page.dart:114`, `pet_news_card.dart:24`, `radar_place_sheet.dart:448` (`place.websiteUrl` da OpenStreetMap, dato comunitario), `radar_place_sheet.dart:17-25` (`tel:`, Google Maps directions in app esterna), `settings_page.dart:330-337` (`mailto:` supporto), `radar_place_sheet.dart:136` (`mailto:`).
- Su web `url_launcher_web` 2.4.1 rifiuta lo schema `javascript:` e apre con `noopener` (pub cache `url_launcher_web-2.4.1/lib/url_launcher_web.dart:26-30,69`): l'URL comunitario di OSM non può eseguire script nell'origin dell'app. Su Android `launchUrl` apre il browser/app esterna. Nessuna validazione client dello schema per `websiteUrl` (`radar_place.dart:162`): un valore `intent://` o `file://` fornito dal backend aprirebbe un intent esterno; rischio basso, ma è consigliabile accettare solo `http(s)` lato client (B7).

### Finding B7 — URL esterni dal backend non filtrati per schema
- **Gravità**: Bassa.
- **Dove**: `lib/features/nearby_places/domain/radar_place.dart:162-177`, `lib/features/pet_news/data/pet_news_repository.dart:148`.
- **Correzione**: scartare in `fromJson` gli URL il cui `Uri.tryParse(...).scheme` non è `http`/`https`.

---

## 6. Logging in release

- Nessun `print(`; `debugPrint` in tre punti. `debugPrint` **non** è rimosso in release (è solo un `print` con throttling); il `debug` di supabase_flutter è `kDebugMode` (pub cache `supabase.dart:109`), quindi i log del client Supabase sono spenti in release.
- `lib/features/notifications/application/notification_scheduler.dart:152`: `debugPrint('Could not schedule notification ${plan[index]}: $error')` — stampa il `toString()` della notifica pianificata (titolo del promemoria/nome animale/orario, a seconda del `toString` del modello — da verificare). Vedi B8.
- `lib/features/dog_walks/data/dog_walks_repository.dart:18`: `debugPrint('DogWalksRepository: $action failed against Supabase: $error')` — messaggio dell'eccezione Postgrest; non contiene token.
- `lib/features/notifications/data/local_notifications_gateway.dart:90`: solo errore.
- Nessun log di token, email, coordinate o testo dei messaggi. Nessun logger centralizzato gated su `kReleaseMode`.

### Finding B8 — `debugPrint` attivi in release con dati di promemoria
- **Gravità**: Bassa.
- **Dove**: notification_scheduler.dart:152, dog_walks_repository.dart:18.
- **Impatto**: logcat è leggibile solo con accesso al dispositivo (adb/root), ma il contenuto può includere nomi di animali e promemoria sanitari.
- **Correzione**: avvolgere in `if (kDebugMode)` o introdurre un `AppLog` che in release non stampi; `LOG_LEVEL` esiste già come define ma non è usata.

---

## 7. Rete

### Host contattati (grep `https://` in lib/ + plugin noti)
| Host | Dove | Dati inviati |
|---|---|---|
| `SUPABASE_URL` (`*.supabase.co`) | supabase_flutter (auth, PostgREST, Storage) | credenziali, tabelle `pet_profiles`, `reminders`, `clinical_events`, `pet_conditions`, `dog_walks`, `user_locations`, `marketplace_listing_reports`, `events`, `local_activities`, `pet_photos`, bucket foto/profili/annunci |
| `API_BASE_URL` (backend FastAPI) | chat, allegati, STT, consensi, abbonamento, luoghi, marketplace, eventi, news, account delete, testi legali | Bearer token in header; coordinate in query (B9) |
| `tile.openstreetmap.org` | mappe (walk_map_style.dart) | tile x/y/z (zona geografica approssimata), User-Agent |
| `nominatim.openstreetmap.org` | address_geocoder.dart:46,64-75 | **indirizzo di casa completo** (M4) |
| `*.basemaps.cartocdn.com` | solo con `WALK_MAP_STYLE=carto` | tile + `?key=` (M7) |
| `fonts.googleapis.com` / `fonts.gstatic.com` | `google_fonts` 6.3.3 (nessun font in `assets/`) | richiesta font (IP) a Google, al primo avvio e su web ad ogni sessione — da verificare se i font sono poi cachati; nota per l'informativa |
| `www.google.com/maps/dir/` | radar_place_sheet.dart:20-25 (app esterna) | destinazione |
| RSS/pubblicazioni, open data comunali | link aperti nel browser | — |

### Come viene allegato il token
Sempre in header `Authorization: Bearer <access_token>` letto da `CurrentUser.accessToken()` (`lib/shared/auth/current_user.dart:24-26` → `Supabase.instance.client.auth.currentSession?.accessToken`): account_consents_remote_data_source.dart:41, subscription_remote_data_source.dart:38, chat_remote_data_source.dart:151, chat_attachment_remote_data_source.dart:67,131, speech_to_text_remote_data_source.dart:46, event_submission_repository.dart:67, marketplace_repository.dart:159, radar_contributions_repository.dart:177, radar_places_repository.dart:68,117, medical_record_consent_remote_data_source.dart:35, supabase_auth_remote_data_source.dart:296. **Nessun token in query string**. Supabase SDK aggiunge `apikey` (publishable) e Bearer da solo.

### Finding M4 — Indirizzo di casa inviato a Nominatim (terza parte)
- **Gravità**: Media (privacy/conformità, non vulnerabilità).
- **Dove**: `lib/features/location/data/address_geocoder.dart:46,55-75` — `q=<via, CAP, città>, <paese>` verso `https://nominatim.openstreetmap.org/search`, `User-Agent: com.vetapp.mobile_app`.
- **Problema**: via e numero civico dell'utente lasciano l'infrastruttura VetApp verso OSMF; la policy Nominatim vieta l'uso massivo da app mobili senza accordo e richiede attribuzione; l'informativa/Data safety deve dichiarare "Indirizzo → condiviso con terze parti (geocoding)".
- **Correzione**: far passare il geocoding dal backend (che può anche limitare la frequenza e non registrare l'indirizzo), oppure usare un provider con contratto; in ogni caso aggiungere la voce nell'informativa e nel form Data safety.

### Finding B9 — Coordinate in query string verso il backend
- **Gravità**: Bassa.
- **Dove**: radar_places_repository.dart:105-111, marketplace_repository.dart:149-155 (`latitude`, `longitude`, `radius_km` in URL).
- **Problema**: HTTPS protegge la query in transito, ma gli URL finiscono nei log di accesso di Vercel/proxy con l'IP e il token non c'è ma l'utente è identificabile dal Bearer lato server.
- **Correzione**: accettabile; se si vuole ridurre la traccia nei log, passare a `POST` con body o arrotondare le coordinate a ~3 decimali per le ricerche per raggio.

### Finding B10 — UUID dell'utente negli URL pubblici delle foto degli annunci
- **Gravità**: Bassa.
- **Dove**: `lib/features/marketplace/data/listing_photo_store.dart:57-63` — path `<ownerId>/<listingId>/<photoId>.jpg` + `getPublicUrl`.
- **Problema**: l'URL pubblico (bucket pubblico, visibile a chiunque apra l'annuncio) contiene l'`auth.uid` dell'inserzionista: permette di correlare tutti gli annunci di una persona e di collegare l'id ad altre tabelle in caso di errori RLS.
- **Correzione**: usare un id opaco per cartella (es. hash o `listingId/photoId` soltanto) e mantenere il controllo di proprietà in una policy Storage sul metadata.

---

## 8. Build web

- `web/index.html:1-46`: template Flutter standard, nessuna `<meta http-equiv="Content-Security-Policy">`; `<base href="$FLUTTER_BASE_HREF">`; script solo `flutter_bootstrap.js`. `meta description` ancora "Web-first VET APP demo…" (riga 21, e manifest.json:8) — cosmetico.
- `vercel.json:1-13`: solo rewrite SPA; **nessun header** (`Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`/`frame-ancestors`, `Referrer-Policy`, `Permissions-Policy`).
- Service worker: quello generato da Flutter (`flutter_service_worker.js`), cache degli asset; nessuna personalizzazione.
- Storage web: sessione Supabase in `localStorage` (vedi §2), bozze/cache in `localStorage` tramite shared_preferences_web. `usePathUrlStrategy()` (bootstrap.dart:47). `detectSessionInUri` default `true`: i token del link email arrivano nel fragment e vengono consumati dall'SDK.
- `tool/static_server.dart`: server locale di test con `Uri.decodeComponent` sul path e nessuna normalizzazione (`File('${root.path}$decodedPath')`, righe 25-26): possibile path traversal (`/../`) — è uno strumento di sviluppo su loopback, non distribuito; nota solo per non riusarlo altrove.

### Finding M6 — Nessuna intestazione di sicurezza sull'app web
- **Gravità**: Media.
- **Dove**: `vercel.json` (nessuna sezione `headers`), `web/index.html` (nessuna CSP).
- **Problema**: la pagina può essere incorniciata da siti terzi (clickjacking sulle azioni dell'app), non c'è HSTS, e in caso di XSS (es. da un pacchetto compromesso) la sessione in `localStorage` è esfiltrabile senza alcun freno di CSP.
- **Correzione**: in `vercel.json` aggiungere `headers` per `/(.*)`: `Strict-Transport-Security: max-age=63072000; includeSubDomains`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: geolocation=(self), microphone=(self), camera=()`, e una CSP compatibile con Flutter CanvasKit/wasm: `default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; connect-src 'self' https://<progetto>.supabase.co wss://<progetto>.supabase.co https://<api> https://tile.openstreetmap.org https://nominatim.openstreetmap.org https://fonts.gstatic.com; img-src 'self' data: blob: https://tile.openstreetmap.org https://<progetto>.supabase.co; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; frame-ancestors 'none'; base-uri 'self'`. Testare con una build locale (Flutter web di default richiede `'unsafe-eval'`/`'wasm-unsafe-eval'` secondo il renderer — da verificare sulla versione 3.47).

---

## 9. Dipendenze

`pubspec.yaml`: vincoli caret (`^`) per tutto tranne `image: 4.5.4`, `image_picker: 1.1.2`, `video_compress: 3.1.4` (fissate); `pubspec.lock` committato fissa le versioni effettive. `flutter pub outdated` (eseguito, Flutter 3.44.1):

| Pacchetto | Attuale | Aggiornabile senza modifiche | Ultima | Nota |
|---|---|---|---|---|
| supabase_flutter | 2.17.2 | 2.18.3 | 2.18.3 | aggiornare (gotrue 2.27.2 → 2.27.3) |
| file_picker | 8.3.7 | — | 13.3.0 | 5 major indietro; cambia il backend Android (`android_file_picker`) |
| permission_handler | 11.4.0 | — | 13.0.2 | 2 major indietro; `permission_handler_android` 12.1.0 → 14.1.0 |
| share_plus | 10.1.4 | — | 13.3.1 | 3 major |
| package_info_plus | 9.0.1 | — | 10.2.2 | |
| open_filex | 4.7.0 | — | 5.0.0 | la 4.7.0 porta i `READ_MEDIA_*` rimossi a mano nel manifest |
| geolocator | 14.0.2 | — | 14.1.2 | |
| google_fonts | 6.3.3 | — | 9.0.0 | |
| image | 4.5.4 (pin) | — | 4.12.0 | usata per decodifica JPEG/EXIF di input utente: tenere aggiornata |
| image_picker | 1.1.2 (pin) | — | 1.2.4 | |
| flutter_local_notifications | 22.3.1 | 22.3.3 | 22.3.3 | |
| crypto, fl_chart, record, shared_preferences, timezone, url_launcher | minori | sì | | |
| flutter_lints (dev) | 3.0.2 | — | 6.0.0 | |

Advisory note: nessuna vulnerabilità pubblicata che io possa confermare per le versioni in lock → **da verificare** con `dart pub outdated --show-all`/`dart pub get` (che stampa le security advisory di pub.dev) e con l'OSV per `image`, `archive` 4.0.9 (transitiva, 4.5.2 disponibile) e `xml`/`petitparser`. `archive` è usata da `image`/`pdf` per dati di input: priorità di aggiornamento.

---

## 10. Gestione dell'input

- **HTML/Markdown**: nessun `flutter_html`/`flutter_markdown`; la chat usa un renderer minimale proprietario per `**grassetto**` e liste (`chat_message_bubble.dart:120-125`), senza HTML. OK.
- **Referti** (`medical_record_upload_page.dart:119-123`, `pet_condition_form_page.dart:116-119`): `allowedExtensions` pdf/jpg/jpeg/png/webp, `withData: true`; prima dell'upload `attachmentValidationError` (`attachment_media_type.dart:65-74`): limite 4 MB e controllo magic number per i PDF; tipo MIME determinato dai primi byte, non dal nome. Buono.
- **Foto animali / profilo** (`pet_profile_form.dart:263-266`, `profile_edit_page.dart:77`): `FileType.image` con `withData: true`, **nessun limite di dimensione lato client** prima della decodifica (`compressPetPhoto`/`ProfilePhotoRepository.prepare`): un file da decine di MB viene caricato interamente in memoria e decodificato da `image` → possibile OOM su telefoni piccoli (B11). I metadati EXIF vengono rimossi (`pet_photo_repository.dart:111`, `listing_photo_store.dart:18 stripImageMetadata`), la data di scatto è letta e conservata separatamente (riga 70-74). Video: estensioni, 500 MB sorgente, 20 MB caricato, 30 s (`pet_video_rules.dart:16-22,76-113`) e `stripVideoLocationMetadata` (pet_media_importer.dart:240).
- **Allegati chat** (`chat_composer.dart:351-355`): `FileType.image`, `withData: true`, nessun controllo di dimensione prima dell'upload (il backend applica 4 MB). Vedi B11.
- **Percorsi**: `PetPhotoDiskCache._isSafe` (pet_photo_disk_cache_io.dart:38-42) blocca `..`, `\`, segmenti vuoti. `native_pdf_opener.dart:17` sanifica il nome del referto (`[\/:*?"<>|]`). `history_export.dart:103` usa `fileName` costruito dall'app. OK.
- **Audio**: registrazione AAC mono 16 kHz in temp, cancellata dopo l'invio (chat_composer.dart:434-443,508).

### Finding B11 — Nessun limite di dimensione lato client per foto e allegati chat
- **Gravità**: Bassa (robustezza).
- **Dove**: pet_profile_form.dart:263, profile_edit_page.dart:77, chat_composer.dart:351.
- **Correzione**: controllare `file.size` (file_picker lo espone) prima di leggere i byte e rifiutare oltre, es., 25 MB per le foto (poi compresse) e 4 MB per la chat, con lo stesso messaggio usato per i referti.

---

## 11. UX della privacy e consensi

- **Registrazione** (`register_page.dart:121-135, 325-342`): checkbox obbligatoria "accetto Termini e Privacy" (`_acceptTerms`, blocco in `_submit` riga 124-132), con link ai testi completi (`LegalTextPage`, dal catalogo pubblico `legal_texts_remote_data_source.dart`); dopo la creazione dell'account i consensi `termsOfService` e `privacyPolicy` vengono registrati sul backend in best-effort (riga 187-199). Marketing/analytics sono opzionali in Impostazioni → Permessi e consensi. Buono. La Home dell'auth mostra una nota privacy (`auth_placeholder_page.dart:43`).
- **First-run**: `plan_intro_page`, `tutorial_page`, `notification_permission_page` (richiesta `POST_NOTIFICATIONS` con schermata esplicativa prima del popup — notification_permission_page.dart:28-33), `add_first_pet_prompt_page`. Nessuna raccolta dati prima dell'accettazione.
- **Posizione** (`device_location_service.dart:45-55`): `Geolocator.requestPermission()` chiamato direttamente quando l'utente attiva una funzione che la richiede (just-in-time), ma **senza una schermata di rationale propria** prima del popup di sistema; il testo suggerito esiste in `docs/compliance/05_permessi_dispositivo_os.md` ("Per suggerirti eventi e attività vicino a te…") ma non è nel codice (grep del testo: nessun match in lib/). Vedi B12.
- **Microfono**: `_recorder.hasPermission()` al primo uso (chat_composer.dart:403-409), senza rationale.
- **Passeggiata in background**: notifica persistente obbligatoria (WalkTrackingService.kt) e nessuna posizione "sempre": coerente con Play.

### Finding B12 — Manca il rationale in-app prima del popup posizione/microfono
- **Gravità**: Bassa (policy store / UX).
- **Dove**: device_location_service.dart:46-47, chat_composer.dart:405.
- **Correzione**: mostrare un dialog con la frase già scritta in docs/compliance/05 (e gestire `deniedForever` con link a `openAppSettings`, oggi restituito come failure a device_location_service.dart:52-54).

### Finding M8 — `ENVIRONMENT=production` non passato in CI
- **Gravità**: Media (difesa in profondità).
- **Dove**: `scripts/ci/prepare_firebase_build.py:103` (solo tre define), `lib/app/bootstrap.dart:51-56` (la guardia scatta solo se `isProduction`).
- **Problema**: gli APK Firebase hanno `environment = development`; se in futuro un segreto CI sparisse, lo script lo bloccherebbe (riga 70-72), ma una build manuale con `.env.production.json` incompleto partirebbe in modalità demo con `FakeAuthRemoteDataSource` (B2) invece di fallire. Inoltre `isProduction` non è usato altrove, quindi nessun comportamento "production-only" (es. log spenti) è attivo.
- **Correzione**: includere `ENVIRONMENT=production` in `dart-defines.json` e in `.env.production.json` (già previsto da `production.env.example.json:2`); usare `isProduction` per spegnere `debugPrint` e la modalità demo.

### Finding A2 — "Resta connesso" disattivato non onorato con Supabase
- **Gravità**: Alta (aspettativa esplicita dell'utente su dispositivo condiviso).
- **Dove**: `login_page.dart:34,68,154-160` (checkbox `_rememberMe`), `auth_repository_impl.dart:40-56` (passa `rememberMe` solo al `MemoryAuthSessionStore`), `auth_repository_factory.dart:28-31` (con Supabase lo store persistente dell'app non è usato), `bootstrap.dart:61-64` (`Supabase.initialize` senza `authOptions`, quindi `persistSession = true`). Solo il `PersistentAuthSessionStore` demo rispetta la scelta (persistent_auth_session_store.dart:66-76).
- **Problema**: l'utente deseleziona "Resta connesso" su un telefono/browser condiviso; l'SDK Supabase salva comunque la sessione in SharedPreferences/localStorage e al riavvio l'app rientra senza password.
- **Impatto**: chiunque riapra l'app vede cartella clinica, chat e posizione dell'utente che credeva di non aver lasciato la sessione attiva.
- **Correzione**: (a) quando `rememberMe == false`, dopo il sign-in chiamare `Supabase.instance.client.auth` con `persistSession` disattivato non è possibile a runtime; la via pratica è inizializzare Supabase con `FlutterAuthClientOptions(localStorage: <storage proprio>)` che scrive su disco solo se un flag `remember_me` (in prefs) è vero, altrimenti tiene la sessione in memoria; oppure (b) al prossimo avvio, se `remember_me == false` è salvato, eseguire `signOut(scope: local)` prima di mostrare la Home (`restoreSession`). (c) In alternativa rimuovere la checkbox finché non è implementata, per non promettere ciò che non si fa.

---

## 12. Altre note (Bassa / informative)

- **RLS come unica barriera**: diverse cancellazioni/aggiornamenti via PostgREST filtrano solo per `id` senza `owner_id`: `medical_records_repository.dart:276`, `pet_conditions_repository.dart:81`, `reminders_repository.dart:316`, `pet_demo_store.dart:315`. Corretto solo se le policy RLS su `clinical_events`, `pet_conditions`, `reminders`, `pet_profiles` limitano `DELETE`/`UPDATE` a `owner_id = auth.uid()` — **da verificare lato backend** (fuori perimetro). Nel client conviene comunque aggiungere `.eq('owner_id', ownerId)` come fa `dog_walks_repository.dart:239`.
- `Supabase.initialize` senza `debug` esplicito: default `kDebugMode` → nessun log SDK in release. OK.
- Orientamento, `singleTop`, `taskAffinity=""`: OK.
- `web/manifest.json` e `index.html` descrivono l'app come "demo" (cosmetico, da aggiornare prima del Play/Web pubblico).
- `tool/static_server.dart:25-26`: path traversal in uno strumento di sviluppo locale; non distribuire.

---

## Appendice A — Elenco dati per il form "Data safety" di Google Play (derivato dal codice)

Legenda: R = raccolto (lascia il dispositivo verso VetApp/Supabase), C = condiviso con terze parti, D = resta solo sul dispositivo. "Obbligatorio" = necessario per usare la funzione.

| Categoria Play | Tipo di dato | Dove nel codice | R/C/D | Finalità | Note per il form |
|---|---|---|---|---|---|
| Informazioni personali | Email, nome visualizzato | supabase_auth_remote_data_source.dart:33-35,72-80 | R | Funzionalità app, gestione account | obbligatorio; cifrato in transito; cancellabile (DELETE /account) |
| Informazioni personali | Indirizzo (via, CAP, città) | address_geocoder.dart:55-75, location_repository.dart (`user_locations`) | R + **C (OSM Nominatim)** | Funzionalità app (servizi vicini) | facoltativo; dichiarare la condivisione con terzi |
| Posizione | Posizione precisa (GPS) | device_location_service.dart:57-62, dog_walks_repository.dart (`dog_walks` con traccia), radar/marketplace query | R | Funzionalità app (passeggiate, servizi e annunci vicini) | facoltativo; tracce passeggiata salvate sul server |
| Posizione | Posizione approssimativa | tile OSM (zona della mappa) | C (OSM tile server, via IP/tile) | Funzionalità app | implicita nell'uso delle mappe |
| Salute e fitness | Informazioni sanitarie **dell'animale** (referti, patologie, pesi, farmaci) | medical_records_repository.dart (`clinical_events`), pet_conditions_repository.dart, weight_measurements_repository.dart, chat allegati | R | Funzionalità app | non sono dati sanitari della persona secondo Play, ma vanno dichiarati come "Altre informazioni personali"/"File e documenti"; l'LLM della chat li elabora sul backend (dichiarare il fornitore LLM se terzo) |
| File e documenti | PDF/immagini dei referti, foto e video degli animali, foto profilo, foto annunci | chat_attachment_remote_data_source.dart, pet_photo_repository.dart:273, profile_photo_repository.dart:49, listing_photo_store.dart:58 | R | Funzionalità app | foto annunci **pubbliche** (bucket pubblico) |
| Audio | Registrazioni vocali | speech_to_text_remote_data_source.dart (upload m4a/webm) | R | Funzionalità app (dettatura) | elaborate dal backend (dichiarare fornitore STT se terzo); temp cancellato sul device |
| Messaggi | Messaggi della chat con l'assistente | chat_remote_data_source.dart | R | Funzionalità app | conservati sul server (thread) |
| Contenuti generati dall'utente | Annunci marketplace, segnalazioni luoghi/annunci, eventi proposti, voti aree cani | marketplace_repository.dart, radar_contributions_repository.dart, listing_reports_repository.dart, event_submission_repository.dart | R | Funzionalità app | parte è pubblica per gli altri utenti |
| Attività nell'app | Consensi (ToS, privacy, marketing, analytics), piano/abbonamento, lingua preferita | account_consents_remote_data_source.dart, subscription_remote_data_source.dart, signUp `data` | R | Gestione account, conformità | |
| Identificatori dispositivo | — | nessun SDK pubblicitario/analytics; `ENABLE_TELEMETRY` inerte; nessun Firebase SDK nell'app (solo App Distribution lato CI) | — | — | dichiarare "nessuno" |
| Informazioni finanziarie | — | billing con metodi di pagamento **demo** (memoria `settings_page_billing_section`) | — | — | aggiornare quando arriverà un PSP reale |
| Solo sul dispositivo | Bozze chat, preferenze layout/unità, notifiche programmate, cache foto, snapshot passeggiata | WarmStartStore, LayoutSettingsStore, NotificationScheduler, PetPhotoDiskCache, ActiveWalkRecoveryStore | D | — | non vanno dichiarati come raccolti, ma M1 (backup) li farebbe uscire verso Google Drive: dichiarare o disabilitare il backup |

Pratiche di sicurezza da dichiarare: dati cifrati in transito (sì, solo HTTPS); possibilità di richiedere la cancellazione (sì, in-app `DELETE /account`); nessuna cifratura locale aggiuntiva.

## Appendice B — Permessi per la dichiarazione Play

- Foreground service: tipo `location`, giustificazione "tracciamento GPS della passeggiata del cane mentre l'app è in secondo piano, con notifica persistente" (WalkTrackingService.kt, manifest main:136-139). Serve video dimostrativo.
- Posizione: solo in uso (`ACCESS_FINE/COARSE`). Nessuna posizione in background.
- `RECEIVE_BOOT_COMPLETED`: riprogrammazione promemoria.
- `RECORD_AUDIO`: messaggi vocali in chat.
- `POST_NOTIFICATIONS`: promemoria, compleanni, notifica passeggiata.
- Nessun `QUERY_ALL_PACKAGES`, nessun `SCHEDULE_EXACT_ALARM`, nessun `READ_MEDIA_*`, nessun `CAMERA`.
