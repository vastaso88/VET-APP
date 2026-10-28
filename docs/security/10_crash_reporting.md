# Segnalazione di crash ed errori: Firebase Crashlytics o Sentry?

Ultimo aggiornamento: 2026-10-28. Parere della sessione Cybersicurezza per la
sessione «APK e App nativa», che farà l'integrazione. Non è consulenza legale.

> **Stato 2026-10-28**: Sentry adottato (commit cc648c6, `apps/mobile_app/lib/shared/crash/crash_reporting.dart`,
> runbook `docs/runbooks/crash_reporting.md`). Resta spento finché il proprietario non crea l'organizzazione in
> regione EU, firma il DPA e passa `CRASH_REPORTING=true` + `SENTRY_DSN` alla build. Verifica del filtro in fondo:
> punti 1-3 risolti (commit 8f0c599), resta la prova con eventi reali.

## In due righe

**Raccomandazione: Sentry, organizzazione nella regione EU (Francoforte),
attivato solo con un consenso "Invia rapporti sugli errori" in Impostazioni,
spento per default, con `sendDefaultPii=false` e pulizia delle briciole di
navigazione.** Crashlytics resta una seconda scelta accettabile se si vuole un
solo fornitore (Google) e si accetta che i dati finiscano negli USA.

Perché: i dati del backend e del database sono tenuti in Irlanda per scelta;
un servizio di diagnostica che manda stack trace, modello del telefono e
identificativi negli Stati Uniti aprirebbe un nuovo trasferimento extra-UE da
giustificare, mentre Sentry permette di restare in UE allo stesso prezzo
(gratis per i volumi di oggi).

## Glossario

- **Crash report**: cosa stava facendo l'app quando si è chiusa (lo "stack
  trace": l'elenco delle funzioni in esecuzione), più modello del telefono,
  versione del sistema, versione dell'app, orario.
- **Breadcrumb** (briciola): la sequenza delle ultime azioni prima del crash
  (schermate aperte, chiamate di rete). Utili per capire, pericolose per la
  privacy: una chiamata di rete registrata con il suo URL può contenere
  coordinate GPS o id di animali.
- **PII**: dati che identificano una persona (e-mail, nome, IP, id utente).
- **DPA**: il contratto art. 28 GDPR con cui il fornitore si impegna a trattare
  i dati solo per nostro conto.

## Cosa raccolgono (fonti ufficiali consultate il 2026-10-28)

| | Firebase Crashlytics | Sentry (Flutter SDK) |
| --- | --- | --- |
| Dati raccolti di base | UUID di installazione Crashlytics, Firebase installation ID, session ID; orario del crash, bundle ID e versione dell'app; sistema operativo e versione, flag root/jailbreak, modello, CPU, RAM, disco; stack trace di ogni thread; classe e messaggio dell'eccezione; immagini binarie caricate; stato in background, rotazione, sensore di prossimità (pagina "Privacy and Security in Firebase") | Stack trace, messaggio dell'eccezione, versione app/SO, modello, orario, breadcrumb (navigazione, log, chiamate HTTP senza corpo), ID evento. **Niente IP, e-mail, id utente o cookie** se `sendDefaultPii` resta falso (default nel SDK Flutter) |
| Dati aggiunti dall'app (facoltativi) | user ID, chiavi personalizzate, log (`FirebaseCrashlytics.instance.setUserIdentifier`, `setCustomKey`, `log`) | `Sentry.configureScope((s) => s.setUser(...))`, tag, contesti, breadcrumb manuali |
| Dove sono trattati | **Servizio "globale": può trattare i dati in qualunque sede Google Cloud**; non è tra i servizi con scelta della regione (pagina Firebase privacy) | Scelta al momento della creazione dell'organizzazione: **US (Iowa) o EU (Francoforte, con backup in UE)**; disponibile anche sul piano gratuito; API su `de.sentry.io` |
| Conservazione | 90 giorni per stack trace e identificativi, poi avvio della rimozione; minidump NDK scartati dopo l'elaborazione | 90 giorni per gli eventi sul piano gratuito (verificare nel piano scelto) |
| Contratto | Termini Firebase con Data Processing and Security Terms; Google LLC certificata DPF | DPA Sentry (Functional Software, Inc.) con SCC; certificazione DPF dichiarata da Sentry (verificare nella lista ufficiale) |
| Spegnimento fino al consenso | `firebase_crashlytics_collection_enabled=false` nel manifest + `setCrashlyticsCollectionEnabled(true)` dopo il consenso (vale dal run successivo: con il flag nel manifest l'SDK non parte prima) | Non inizializzare `SentryFlutter.init` finché il consenso non c'è; oppure `options.beforeSend` che scarta tutto quando il consenso è assente |
| Costo oggi | Gratis | Gratis fino a 5.000 errori/mese (piano Developer) |

Nota importante su Crashlytics: l'SDK porta con sé Firebase Core e un
**Firebase installation ID** persistente per dispositivo, cioè un
identificativo che oggi l'app non ha. Il progetto Firebase `vetapp-test2` è
usato solo per distribuire gli APK ai tester: aggiungere Crashlytics
significherebbe metterci dentro anche i dati degli utenti finali.

## Base giuridica e consenso

- Un crash report è un dato personale quando contiene identificativi
  (installation ID, user ID) o quando lo stack trace e i breadcrumb riportano
  valori dell'utente. Ridotto al minimo (nessun user ID, URL puliti) resta
  comunque collegato a un dispositivo tramite l'installation ID (Crashlytics)
  o all'evento (Sentry) e va trattato come personale.
- Lettura della sessione (da far confermare al legale): la base più solida e
  semplice da spiegare è il **consenso** (art. 6(1)(a)), perché l'accesso al
  dispositivo per inviare dati tecnici a terzi rientra nell'art. 5(3) della
  direttiva ePrivacy / art. 122 del Codice privacy e la diagnostica non è
  "strettamente necessaria" per fornire il servizio richiesto dall'utente.
  Il **legittimo interesse** (art. 6(1)(f)) è difendibile per il solo stack
  trace senza identificativi, ma richiede una valutazione scritta (LIA) e non
  evita la questione ePrivacy. Scelta consigliata: **consenso opt-in**, usando
  il sistema di consensi versionati già presente (`account_consents`), con
  una chiave nuova `diagnostics` separata da `analytics` (finalità diversa:
  stabilità, non misurazione d'uso).
- Testo proposto per Impostazioni → Permessi e consensi: «**Invia rapporti
  sugli errori.** Se l'app si chiude per un errore, inviamo un rapporto
  tecnico (cosa stava facendo l'app, modello del telefono, versione) a
  [Sentry, server in Germania]. Nessun messaggio, foto, posizione o dato
  dell'animale. Puoi spegnerlo quando vuoi.»
- Informativa privacy: aggiungere il fornitore nella tabella «Chi riceve i
  dati» con paese e durata (90 giorni) e la finalità «stabilità dell'app».
- Scheda Data safety: «Info e prestazioni dell'app → Log di arresto anomalo»
  raccolto, non condiviso (fornitore con DPA), facoltativo, finalità Analisi.

## Configurazione minima raccomandata (Sentry)

1. Creare l'organizzazione scegliendo **Data storage location: EU**; accettare
   il DPA dalle impostazioni legali dell'organizzazione e archiviarlo.
2. `SentryFlutter.init` **solo** dopo che `account_consents.diagnostics` è
   vero (e alla revoca: `Sentry.close()`); nessun evento prima del consenso.
3. Opzioni:
   - `options.sendDefaultPii = false` (default, lasciarlo);
   - `options.beforeSend`: scartare l'evento se il consenso è stato revocato;
     rimuovere `event.user`, `event.request` e sostituire con `[redacted]`
     ogni breadcrumb di tipo `http` il cui URL contenga `lat=`, `lon=`,
     `/pets/`, `/conversations/`, `token`;
   - `options.maxBreadcrumbs = 30`, nessun breadcrumb di log applicativo con
     testo dell'utente (non usare `Sentry.addBreadcrumb` con messaggi);
   - `options.attachScreenshot = false`, `options.attachViewHierarchy = false`
     (una schermata può contenere la cartella clinica);
   - `options.enableAutoSessionTracking = false` (altrimenti si misura anche
     l'uso, che è la finalità "analytics", non quella consentita);
   - `options.environment` = flavor; `release` = versione + build;
   - mai `Sentry.configureScope(setUser)` con e-mail o id; se serve correlare
     i crash di uno stesso dispositivo, un hash casuale generato localmente e
     rigenerato alla revoca del consenso.
4. Backend: Sentry per FastAPI è opzionale; se lo si aggiunge, stessa regione
   EU, `send_default_pii=False`, scrubbing dei parametri di query, nessun
   corpo di richiesta, mai il prompt o la risposta del modello.
5. Inserire la nuova dipendenza nel lockfile e in Dependabot (già configurato).
6. Prima del rilascio: provocare un crash di prova con un account di test e
   leggere l'evento ricevuto per verificare che non contenga dati personali.

## Se invece si sceglie Crashlytics

Stesse regole (consenso, nessun `setUserIdentifier` con e-mail/id, nessun log
con testo utente), più: flag `firebase_crashlytics_collection_enabled=false`
nel manifest e abilitazione a runtime dopo il consenso; progetto Firebase
**separato** da quello dei tester o, almeno, consapevolezza che i dati degli
utenti finali stanno in quel progetto; dichiarare il trasferimento USA
nell'informativa (DPF Google) e nell'inventario fornitori; valutare che l'SDK
aggiunge l'installation ID.

## Verifica del filtro (2026-10-28, su `crash_reporting.dart` e `test/shared/crash_reporting_test.dart`)

Confronto con la configurazione minima raccomandata sopra:

| Raccomandazione | Nel codice | Esito |
| --- | --- | --- |
| Avvio solo dopo consenso, stop alla revoca e al logout | `CrashReporting.initialize/applyConsent/onSignedOut`, `CrashConsentStore` | ✅ con test |
| Build flag + DSN fuori dal repo | `kCrashReportingFlag`, `kSentryDsn` da `--dart-define` | ✅ test "nothing can be sent" |
| `sendDefaultPii = false` | impostato | ✅ |
| Nessun screenshot / gerarchia widget | `attachScreenshot = false`, viewHierarchy default off | ✅ |
| Niente session tracking / performance | tutti disattivati | ✅ (più di quanto chiesto) |
| Breadcrumb puliti | `beforeBreadcrumb` scarta tutto, `enableAutoNativeBreadcrumbs = false`, `event.breadcrumbs = null` | ✅ (scelta più severa: nessuna briciola) |
| Nessun user id / e-mail | mai impostati; `event.user = null` | ✅ |
| `environment` = flavor, `release` = versione+build | package name, `version+buildNumber` | ✅ |
| Messaggio dell'eccezione rimosso | `exception.value = null`, `event.message = null`, `flutter_error_details` scartato | ✅ test "nothing of what the owner wrote survives" |
| Mai su web | `isAvailable` falso su web | ✅ |

Punti esaminati (per la sessione APK). Stato al 2026-10-28 dopo il commit 8f0c599 su Francesco:

1. **Crash nativi** — ✅ risolto. `scrubCrashEvent` è un `beforeSend` **Dart** e non può girare per i crash duri del
   livello nativo (eccezioni Java/Kotlin non gestite, crash NDK, ANR), che l'SDK Android invia con la propria
   elaborazione, messaggio dell'eccezione incluso. In `SentryCrashTransport.start` ora sono spenti sia
   `enableNativeCrashHandling` sia `anrEnabled`; nota: in `sentry_flutter` 9.0.0 **`anrEnabled` è attivo di default**
   (`sentry_flutter_options.dart`: `bool anrEnabled = true`), per questo lo spegnimento esplicito era necessario.
   Si rinuncia ai crash del solo servizio nativo di passeggiata.
2. **Contesti `device` e `app`** — ✅ risolto. Non sono più tenuti per intero: vengono ricostruiti da una lista di
   campi ammessi (modello, sistema, versione dell'app...), così cadono anche id di installazione, nome del telefono,
   IMEI, `device_app_hash` e `viewNames`.
3. **Percorsi assoluti nei frame** — ✅ risolto. I percorsi della macchina di build sono tolti dai frame
   (`scrubStackPath`).
4. **`culture`** (lingua e fuso orario) tenuto: dato debole, accettabile. `exception.mechanism`, `event.logger`,
   `event.fingerprint`, `event.threads` non azzerati: senza testo dell'utente nei casi noti.
5. ⏳ **Aperto fino all'account Sentry**: prima del primo rilascio con il flag, provocare un crash Dart con un
   account di test, leggere l'evento ricevuto su Sentry, confermare i punti 1-4 sull'evento reale e annotare qui
   la data.

## Fonti

- Firebase, "Privacy and Security in Firebase": dati di Crashlytics, servizio
  globale, conservazione 90 giorni: <https://firebase.google.com/support/privacy>
- Firebase, gestione installation ID: <https://firebase.google.com/docs/projects/manage-installations>
- Sentry, "Data Storage Location (US or EU)": Francoforte/Iowa, scelta per
  organizzazione, piano gratuito incluso: <https://docs.sentry.io/organization/data-storage-location/>
- Sentry, FAQ sulla regione EU: <https://intercom.help/sentryio/en/articles/13964378>
- Sentry, privacy e sicurezza (DPA, DPF): <https://sentry.io/trust/privacy/>
- Sentry Flutter, opzioni (`beforeSend`, `enableNativeCrashHandling`, `anrEnabled`, `sendDefaultPii`):
  <https://docs.sentry.io/platforms/dart/guides/flutter/configuration/options/>
