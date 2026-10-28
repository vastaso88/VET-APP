# Segnalazione degli errori (crash) — come si accende

Stato (2026-10-28): **pronta e spenta**. L'app contiene l'integrazione con Sentry, ma nessuna build la usa finché il proprietario non fa i passi qui sotto. Scelta e motivi (Sentry in UE, consenso opt-in): [docs/security/10_crash_reporting.md](../security/10_crash_reporting.md).

## Come funziona (due porte, tutte e due chiuse di default)

1. **La build deve permetterlo.** Si accende solo con due `--dart-define`: `CRASH_REPORTING=true` e `SENTRY_DSN=<indirizzo del progetto>`. Senza, `CrashReporting.isAvailable` è falso: niente parte, niente si salva, nemmeno la riga in Impostazioni compare.
2. **L'utente deve acconsentire.** In Impostazioni → Permessi e consensi compare «Invia rapporti sugli errori» (consenso `diagnostics` dell'account, spento di default, revocabile). Finché non lo accende, il servizio non parte. Se lo spegne, o esce dall'account, il servizio si ferma subito. La decisione è copiata sul telefono (`CrashConsentStore`) per poter ripartire all'avvio senza rete; dopo un accesso la si rilegge dall'account durante la schermata iniziale.

Mai sul web. Il codice è in `apps/mobile_app/lib/shared/crash/crash_reporting.dart`.

## Cosa viene inviato (e cosa no)

Inviato: tipo dell'eccezione, stack trace (nomi di file e funzioni del nostro codice), modello e sistema del telefono, versione dell'app, app (`com.vetapp.vetapp[.francesco|.roberto]`).

Mai inviato — lo garantisce `scrubCrashEvent`, l'ultimo filtro prima dell'invio, con test: testo dell'eccezione (può contenere ciò che l'utente ha scritto), messaggi, utente (id, e-mail, IP), richiesta/URL, briciole di navigazione (tutte scartate, più severo del consigliato), dati extra, tag, i contesti che non descrivono telefono/app (in particolare `flutter_error_details`), schermate e gerarchia delle viste. Nessun identificativo utente viene impostato; niente tracciamento di sessioni, prestazioni o interazioni; niente richieste HTTP fallite; niente elenco dei pacchetti.

## Cosa deve fare il proprietario (io non lo faccio)

1. Su sentry.io creare l'organizzazione scegliendo **Data storage location: EU (Francoforte)** e un progetto Flutter/Dart. Copiare il DSN. Accettare e archiviare il DPA (impostazioni legali dell'organizzazione).
2. Il DSN non va nel repository, nei test, nelle note di rilascio né in `.env.production.json` committato: lo si passa solo alla build, per esempio in un file locale ignorato da git come `.env.production.json` (`SENTRY_DSN` accanto a `SUPABASE_URL`) usato con `--dart-define-from-file`, oppure `--dart-define=SENTRY_DSN=...` a riga di comando. In più serve `--dart-define=CRASH_REPORTING=true`.
3. Prima di mettere la build in mano ai tester (CLAUDE.md, sezione sicurezza): aggiungere Sentry (Functional Software, Inc., server UE) a `docs/security/06_inventario_dati_fornitori.md` e nell'informativa privacy («Chi riceve i dati»: paese, 90 giorni, finalità «stabilità dell'app»); aggiornare la scheda *Data safety* di Play (log di arresto anomalo, raccolto, facoltativo). Il testo del consenso (IT/EN/ES) è nel catalogo del backend (`account_consent_text.py`, chiave `diagnostics`, v1) e va riletto dal legale; DE/FR seguono il processo di `docs/i18n/TESTI_STORE_E_LEGALI.md` (oggi il catalogo del backend serve solo it/en/es e ripiega sull'italiano).
4. Con un account di test sintetico (mai quelli reali): accendere il consenso, provocare un errore di prova e leggere l'evento ricevuto su Sentry per controllare che non contenga dati personali (punto 6 della raccomandazione).

## Note tecniche

- Nessun permesso Android in più (verificato sul manifest fuso release). `sentry_flutter` aggiunge un `ContentProvider` (`SentryPerformanceProvider`) che misura solo i tempi di avvio dell'app, senza inviare nulla se il servizio non parte.
- `sentry_flutter` è fissato alla serie 9: la 10 richiede Android 8 (minSdk 26) e noi siamo a minSdk 24 (Android 7). Se si alza il minSdk, si può passare alla 10.
- Per i crash nativi e per leggere gli stack con i nomi veri nelle build release servirebbe caricare i simboli (mapping R8, simboli Dart) con gli strumenti Sentry: non è configurato, e non c'è nulla da caricare finché le build non sono offuscate (Dart oggi non lo è; R8 sì, per il codice Android).
- Se il servizio fallisce all'avvio (indirizzo sbagliato, nessuna rete) resta spento e l'app va avanti.
- Se in futuro si preferisse Crashlytics (seconda scelta della raccomandazione), `CrashTransport` è il punto da sostituire: consenso, filtri e interruttore restano gli stessi.
