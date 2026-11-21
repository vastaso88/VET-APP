# QUOKKA — avvio release di test Google Play

Verifica del 21 novembre 2026. Repository richiesto: https://github.com/vastaso88/VET-APP.
Base esaminata: `498ddba8da20b93a299ff0792d115f96f6e508b1` (`main`).
Questo documento distingue codice presente, controlli eseguiti e configurazione esterna non verificata.
**Esito: non ancora pronto per distribuire un test Play completo. Nessun AAB firmato prodotto, nessun upload Play, nessuna pubblicazione in produzione.**

## Stato verificato

| Area | Evidenza | Esito |
| --- | --- | --- |
| Identità | `android/app/build.gradle.kts`: flavor `prod`, `applicationId=com.vetapp.vetapp`, etichetta Quokka; altri flavor hanno suffissi | Identità nel codice verificata. Proprietà/disponibilità del package in Play Console non verificata; non cambiarlo arbitrariamente |
| Versione | `pubspec.yaml`: `0.1.0+41`; Gradle legge `flutter.versionCode/versionName` | Per Play scegliere un codice superiore a tutti quelli già caricati, anche negli altri track. `42` è solo un esempio, non un numero validato contro la console |
| Toolchain | AGP `9.0.1`, wrapper Gradle `9.1.0`, Java target 17, compile SDK 36; CI usa Flutter `3.47.6` | La CI della base ha superato Flutter analyze/test e APK debug `prod`; non dimostra una build release firmata |
| Target SDK | La base ereditava `flutter.targetSdkVersion`; questa modifica imposta esplicitamente `36` | Da confermare sul manifest dell’AAB generato, insieme a minSdk effettivo |
| Firma | Gradle accetta quattro variabili `ANDROID_KEYSTORE_*`/alias/password oppure `android/key.properties`; niente fallback debug implicito | Nessuna chiave di upload o associazione Play App Signing verificata. Lo script nuovo rifiuta alias debug e la pipeline controlla anche il certificato del bundle |
| AAB | Non è stata trovata prova di AAB firmati nei risultati esaminati; nessun artifact nelle prime 12 posizioni della query GitHub | Nuovo workflow manuale predisposto, non eseguito |
| Play Billing client | `in_app_purchase`, controller acquisto/ripristino, prezzi dello store, verifica server prima di concedere accesso, gestione nello store | Implementato nel codice, non collaudato su Play |
| Billing Library | Lockfile `in_app_purchase_android 0.5.5`; archivio ufficiale pub.dev dichiara `com.android.billingclient:billing:9.1.0` | Compatibilità della dipendenza verificata alla fonte; verificare la versione effettivamente risolta e il metadata nel manifest finale |
| Billing backend | Verificatore Google subscriptionsv2, binding account, acknowledge, RTDN OIDC, riconciliazione e migrazione SQL presenti | Nessuna prova della configurazione dei prodotti, credenziali, migrazione applicata, RTDN o scheduler nel backend distribuito |
| Login | Supabase configurabile; bootstrap in modalità production rifiuta credenziali mancanti; recupero `vetapp://auth-callback` | Mancano prove di registrazione, email, reset, rinnovo sessione e cancellazione su dispositivo e backend di test |
| Privacy | App e sito dichiarano che l’informativa completa è in preparazione; documenti italiani hanno ancora segnaposto e decisioni aperte | P0 aperto: non dichiarare completata l’informativa/Data safety |
| Cancellazione | Flusso in app presente, anche dal paywall; nuova pagina pubblica `/delete-account` con contatto già riportato nell’informativa e istruzioni | Pagina compilata localmente; pubblicazione, ricezione richieste e tempi operativi da verificare |
| Paywall | Prezzo e periodo dello store, rinnovo automatico, ripristino e gestione presenti; aggiunti link interni a termini/privacy | I link non sostituiscono testi completi e approvati. Non abilitare `BILLING_DEMO_ENABLED` per Play |

## Repository e deployment reali

- [CI della base](https://github.com/vastaso88/VET-APP/actions/runs/44953489604): Flutter e admin portal riusciti; quality fallita per import Python non ordinati in `apps/api/routes/admin_users.py`. Ordinamento corretto qui; `ruff check .` ora passa localmente.
- Esistono PR aperte, fra cui #61 per errori di tipo in `scripts/sources/fetcher.py`: non risultano integrate nella base esaminata. Non includere le loro correzioni nella readiness di main. Dopo aver riprodotto gli errori di tipo, questa candidatura include una correzione minima indipendente del narrowing charset e rinomina una variabile nel test mercatino, senza cambiare il comportamento previsto.
- I due status Vercel del commit base (`vet-app`, `vet-app-34xp`) riportano **Deployment rate limited — retry in 24 hours**. Non eseguire retry ripetuti, upgrade di piano o deploy di produzione per aggirarlo.
- Ultimi deployment riusciti trovati in GitHub: backend/progetto `vet-app`, SHA `9ae05bce283038403b7c3c5736a0b504292fc02d`, [URL](https://vet-58tako63y-vastaso88-7135s-projects.vercel.app); progetto `vet-app-34xp`, SHA `d3dc401eeea828143ea062137caf31edda5577d0`, [URL](https://vet-app-34xp-gobfaincn-vastaso88-7135s-projects.vercel.app). Gli URL immutabili hanno reindirizzato al login Vercel: lo stato READY/success non prova accessibilità per app o revisori.
- `https://quokkapet.net`, `/legal` e `/delete-account` hanno dato errore TLS da questo ambiente. È una prova di mancata verifica, non una diagnosi definitiva del DNS/certificato. Ripetere da una rete esterna e da Android; nessun bypass TLS nella build.
- Il connettore Vercel disponibile espone soltanto il team `erykwests-projects`, collegato a **erykwest/VET-APP**, con due deployment fermi al commit `ac57d69…`. Non è il repository richiesto. Nessuna variabile o impostazione di quei progetti è stata modificata o assunta valida per `vastaso88`.

## Permessi e dichiarazioni

Manifest sorgente: rete, notifiche, boot, posizione precisa/approssimata, foreground service/location, scrittura esterna limitata ad Android ≤28. Rimosse esplicitamente le autorizzazioni ampie di lettura media. Nessuna dichiarazione di `ACCESS_BACKGROUND_LOCATION` o exact alarms nel manifest principale.

Non basta il manifest sorgente: il manifest unito del bundle deve essere controllato per BILLING/metadata versione, microfono introdotto dai plugin audio, eventuali permessi di terze parti, servizi esportati e `debuggable=false`.
Registrare in Play la motivazione del servizio di localizzazione delle passeggiate, con video che mostri avvio volontario, notifica persistente e arresto. Provare rifiuto posizione/notifiche/microfono e posizione approssimata. Verificare che negare i permessi facoltativi non blocchi il login.

Il binario Flutter e i plugin contengono librerie native: controllare ogni `.so` arm64/x86_64 per pagine 16 KB, la configurazione del bundle e l’installazione su un ambiente 16 KB. La sola versione Flutter/AGP non dimostra compatibilità di tutti i plugin.

Compilare Data safety dal comportamento effettivo di backend e SDK: email/account, posizione, contenuti chat e allegati/voce, dati del dispositivo/diagnostica, acquisti e fornitori IA. Non copiare automaticamente la bozza come dichiarazione finale. Verificare separatamente pubblico di destinazione, IARC, eventuali dichiarazioni salute applicabili alle funzioni effettive, UGC del mercatino e segnalazione contenuti IA. La base contiene una segnalazione “non utile” nella chat: provarne percorso e destinazione, senza assumere che soddisfi ogni requisito di segnalazione abusi. Risolvere l’incoerenza fra documenti “18+” e flussi per utenti 14–17 prima di dichiarare il pubblico.

## Blocchi P0 e responsabilità

1. **Backend e sito di test raggiungibili:** scegliere un deployment del repository corretto e uno spazio dati di test separato; verificare TLS, `/health`, `/legal/consents`, login e `/billing/catalog` senza login Vercel davanti all’API. Non usare URL protetti con credenziali/bypass incorporati nell’app. Registrare SHA del backend effettivamente collaudato.
2. **Identità e firma:** il proprietario conferma package registrato e massimo versionCode, account sviluppatore e upload certificate. Configurare Play App Signing e custodire una chiave di upload stabile. Non generare una chiave sostitutiva se esiste già una chiave registrata.
3. **Privacy:** completare titolare, contatti, fornitori, trasferimenti, conservazione e consensi; pubblicare testo completo a URL pubblico stabile, con percorso di cancellazione funzionante e tempi/deroghe espliciti. La pagina predisposta richiede una casella assistenza effettivamente presidiata. Nessun testo è stato approvato come informativa definitiva.
4. **Billing sandbox:** applicare e verificare la migrazione `supabase/migrations/20261121180000_store_billing.sql` nello spazio test; predisporre Google API, prodotti, RTDN e riconciliazione; collaudare tutte le transizioni indicate sotto. Nessuna di queste operazioni esterne è stata eseguita qui.
5. **Build release e collaudo:** CI completa verde sul commit candidato, bundle firmato, controllo manifest/certificato/versioni e 16 KB; prova reale da Play. I test locali non sostituiscono questo passaggio.

## Come produrre il bundle di test

Il workflow `.github/workflows/android-play-bundle.yml` è **solo manuale**, lavora su `main` e usa l’environment `play-testing`. Produce un artifact per sette giorni, non accede alle API di pubblicazione Play e non effettua upload. È utilizzabile dopo revisione e integrazione delle modifiche; non è stato lanciato.

Nel repository GitHub corretto predisporre l’environment `play-testing`, limitato a `main` e con revisione richiesta per l’accesso ai segreti. Queste sono impostazioni dell’account/repository, non privilegi amministrativi Windows. Se non si dispone dei diritti, il proprietario dell’account può configurarle; non è necessario installare o elevare processi sul PC.

| Tipo | Nome | Contenuto |
| --- | --- | --- |
| Variable | `PLAY_TEST_API_BASE_URL` | Origine HTTPS pubblica del backend di test, senza percorso o query |
| Variable | `PLAY_TEST_SUPABASE_URL` | Origine Supabase del progetto di test |
| Secret | `PLAY_TEST_SUPABASE_PUBLISHABLE_KEY` | Solo chiave pubblicabile/anon client, mai service_role |
| Secret | `PLAY_UPLOAD_KEYSTORE_BASE64` | Keystore della chiave di upload corretta |
| Secret | `PLAY_UPLOAD_KEYSTORE_PASSWORD` | Password keystore |
| Secret | `PLAY_UPLOAD_KEY_ALIAS` | Alias upload, diverso da AndroidDebugKey |
| Secret | `PLAY_UPLOAD_KEY_PASSWORD` | Password chiave |

Inserire questi dati direttamente nell’interfaccia GitHub; non inviarli in chat. I segreti backend Google non vanno nel bundle né in questi dart-defines.
All’avvio del workflow fornire `build_number` superiore al massimo in Play; il validatore controlla intervallo/formato, **non può conoscere il massimo della console**. VersionName resta quella del pubspec.

Il comando di build è:

```sh
flutter build appbundle --release --flavor prod --build-number="$ANDROID_BUILD_NUMBER" \
  --dart-define-from-file="$RUNNER_TEMP/quokka-play/dart-defines.json"
```

Lo script prepara i file privati solo nel runner, forza `ENVIRONMENT=production` per l’autenticazione reale anche verso un backend sandbox e disabilita la modalità demo billing. Il workflow esegue analyze/test, verifica la firma JAR, rifiuta il certificato debug e registra SHA256 del file e certificato pubblico. **Controllare che la fingerprint corrisponda all’upload certificate registrato**; la pipeline non conosce tale fingerprint. I metadati di package nel report build sono il valore atteso dal sorgente: confermarli con bundletool/Play App Bundle Explorer.

La macchina locale non ha Android SDK rilevato; Flutter locale è `3.41.5`, diverso dalla CI. Il wrapper Puro ha tentato senza successo un’elevazione per symlink: non è stato usato per ulteriori operazioni. Nessun AAB locale è quindi dichiarato compilato o firmato.

## Configurazione billing da completare nell’ambiente test

- `BILLING_ENABLED=true`, `BILLING_STORE_ENVIRONMENT=sandbox`, `GOOGLE_PLAY_PACKAGE_NAME=com.vetapp.vetapp` e un `BILLING_ACCOUNT_TOKEN_SECRET` stabile dedicato al test.
- Service account Android Publisher solo lato backend, con autorizzazioni necessarie su ordini/abbonamenti e dati finanziari secondo console; non richiederne la chiave in chat.
- Prodotti `quokka_plus`, `quokka_pro`, `quokka_ultra`, ciascuno con base plan `monthly` e `yearly`, prezzi/localizzazioni approvati. Non assumere che gli ID predefiniti nel codice siano già stati creati.
- License testers configurati prima delle prove d’acquisto. **Un test track da solo non rende gratuiti gli acquisti:** usare account tester di licenza e verificare nel dialogo Play gli strumenti di pagamento di test. Il backend sandbox rifiuta gli acquisti production, ma ciò non impedisce un addebito già avviato nello store con un account non tester.
- RTDN Pub/Sub autenticata su `/billing/google/notifications`, audience e mittente verificati; inviare notifica di test. Scheduler `/billing/reconcile` e retention/eventi controllati.
- Disabilitare override globali come `SUBSCRIPTION_TEST_PLAN` e verificare che i test non concedano accesso per effetto di grant dimostrativi.

Matrice da eseguire e registrare con account/dati di test: acquisto approvato/rifiutato/pendente; completamento pendente; rinnovo; annullamento rinnovo con accesso fino a scadenza; scadenza; grace/account hold; upgrade/downgrade e token collegato; rimborso/revoca; ripristino dopo reinstallazione e secondo dispositivo; tentativo di associare lo stesso acquisto a due account; logout/login su account diverso; riavvio offline e successivo retry; notifica duplicata e fuori ordine. Confermare persistenza server, acknowledge e riconciliazione, non solo messaggio a schermo.

## Passaggi concreti in Play Console

1. Verificare identità sviluppatore, contatti, stato verifiche e tipo account. Creare o aprire **Quokka**; app gratuita con acquisti in-app se è questa la scelta commerciale approvata; confermare il package prima del primo caricamento.
2. Completare scheda essenziale e App content: privacy pubblica completa, Data safety, cancellazione account, accesso all’app, pubblico/rating, ads e dichiarazioni pertinenti ai servizi foreground/altre funzioni.
3. Predisporre account Quokka dedicato ai revisori, stabile e con accesso alle funzioni necessarie anche dopo il trial; fornire istruzioni precise in App access. Non rimuovere autenticazione/MFA globalmente e non esporre le credenziali nei documenti o nel repository.
4. Creare **Internal testing**, inserire la lista di tester e caricare l’AAB verificato nel track interno. Leggere errori e avvisi; non selezionare Production. Usare note che dicano chiaramente che è una versione di test.
5. Dopo la disponibilità, inviare il link di opt-in ai tester tramite il canale scelto dal proprietario; installare dalla scheda Play con lo stesso account Google autorizzato. Non è stato inviato alcun messaggio ai tester in questa attività.
6. Eseguire la matrice Android: primo avvio/login/recupero, export/cancellazione, permessi negati, mappe/passeggiata in background, allegati/audio e billing sandbox. Esaminare Pre-launch report/Android vitals, compatibilità API 36 e 16 KB e aggiornamento fra due versionCode consecutivi.
7. Se l’account personale è soggetto alla regola introdotta per account creati dopo il 13/11/2023, pianificare successivamente **Closed testing con almeno 12 tester iscritti continuativamente per 14 giorni**, poi la richiesta di accesso alla produzione. Il test interno non sostituisce quel requisito e il suo completamento non garantisce approvazione.
8. Solo dopo risultati documentati, dati esterni completati e **conferma esplicita del proprietario**, valutare una release di produzione separata. Questo lavoro non autorizza tale pubblicazione.

## Validazione eseguita e limiti

- Suite Python completa sul candidato: **4379 test superati, 2 saltati, 2383 subtest superati** (50,39 s). Include i test di configurazione build, billing backend/rotte, schede store, fonti e mercatino. Suite mirata iniziale: 100 test e 56 subtest superati.
- `ruff check .`: superato dopo la correzione import. Formattazione Python e mypy del nuovo script: superati.
- Sito: `npm ci --ignore-scripts`, typecheck e build Next riusciti; `/delete-account` è una pagina statica pubblica nel risultato della build. Non distribuita.
- Mypy inizialmente bloccato da tre errori preesistenti in fetcher/test mercatino, poi corretti senza modifica del comportamento. Ora **672 file passano localmente disabilitando soltanto gli errori di import mancanti** (`--disable-error-code import-not-found`): Presidio non è installato nell’ambiente locale con extra dev. La CI con tutti gli extra deve confermare il controllo senza esclusioni; nessuna pretesa di CI completa superata prima del risultato remoto.
- Nuovi link Flutter: analyze e controlli cataloghi riusciti nella prima CI della PR #64 con Flutter 3.47.6; test e compilazione Android ancora in corso al momento di questa nota. Workflow firmato non eseguito; controllo 16 KB e test dispositivo non eseguiti.
- Preview backend del primo commit PR `b008792`: Vercel ha riportato successo per `https://vet-ntu7o1ifn-vastaso88-7135s-projects.vercel.app`; dal controllo locale il nome host non è stato risolto. Il successo del deploy non dimostra l’accessibilità per Android. Preview sito ancora rate limited.

## Fonti ufficiali ricontrollate

- Target richiesto per nuove app: [Android 16 / API 36](https://developer.android.com/google/play/requirements/target-sdk).
- [Versioni Play Billing supportate](https://developer.android.com/google/play/billing/deprecation-faq) e [pacchetto Flutter risolto](https://pub.dev/packages/in_app_purchase_android/versions/0.5.5).
- [Billing per beni/servizi digitali e limiti ai link esterni](https://support.google.com/googleplay/android-developer/answer/10281818).
- [Cancellazione in app e risorsa web](https://support.google.com/googleplay/android-developer/answer/13327111).
- [Privacy e dati utente](https://support.google.com/googleplay/android-developer/answer/10144311).
- [Compatibilità pagine 16 KB](https://developer.android.com/guide/practices/page-sizes).
- [Test per nuovi account personali](https://support.google.com/googleplay/android-developer/answer/14151465).

La console e le verifiche sul bundle candidato restano decisive: questo documento non attesta approvazione Google o conformità legale definitiva.
