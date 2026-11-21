# QUOKKA — preparazione iOS e App Store

Verifica del 21 novembre 2026, partenza da `main` `498ddba8`. Questa preparazione non costituisce una pubblicazione: nessun account Apple, certificato, provisioning profile, prodotto App Store Connect o pagamento reale è stato creato o attivato.

## Progetto e configurazione preparata

- Client Flutter/Dart in `apps/mobile_app`, API Python/FastAPI e Supabase. Flutter **3.47.6**, allineato alla CI esistente; non usare il vecchio SDK locale 3.41.5. Dipendenze native esistenti conservate, lockfile riallineato ai pacchetti fissati da questo SDK.
- Versione sorgente **0.1.0+41**: scegliere un nuovo build number superiore all'ultimo già caricato in App Store Connect; non è stato verificato il numero remoto.
- Progetto Xcode Swift/UIScene in `apps/mobile_app/ios`, iPhone e iPad, deployment target **iOS 15.0**. Questo è il minimo di esecuzione, distinto dall'SDK richiesto per caricare la build.
- Bundle ID proposto **`net.quokkapet.quokka`**. Va confermato/registrato sul team Apple prima della prima distribuzione; se esiste già un'app, usare il suo Bundle ID in tutte e tre le configurazioni Runner, RunnerTests e `APPLE_BUNDLE_ID` del backend. Non inventare un secondo record per aggiornare un'app esistente.
- Nome visualizzato **QUOKKA**, icone opache (anche 1024×1024) dal logo già approvato, launch screen Petrolio. Rigenerazione: `dart run tool/make_ios_icons.dart` dalla cartella mobile.
- CocoaPods per tutti i plugin, Swift Package Manager disattivato solo per questo progetto. Il Podfile abilita i permessi usati dai plugin; Geolocator esclude il permesso Always. Il primo Mac deve risolvere/verificare i pod; conservare `Podfile.lock` della prima risoluzione riuscita.
- Descrizioni di fotocamera, microfono, libreria foto, salvataggio foto e posizione durante l'uso in EN/IT/FR/DE/ES. Nessun accesso rubrica, calendario, tracking pubblicitario o posizione Always aggiunto.
- Callback Supabase `vetapp://auth-callback` registrata; `app_links` gestisce il link, il routing automatico Flutter è disabilitato per evitare conflitti. Aggiungere la callback alla allowlist Supabase dell'ambiente di test e provare recupero password/conferma email su dispositivo.
- Entitlements Runner vuoti: nessun App Group, push/APNs, iCloud o Sign in with Apple senza una funzione corrispondente. In-App Purchase è indicato nelle capabilities Xcode; StoreKit non richiede un entitlement di pagamento inventato. L'autenticazione attuale è email/password, non è stato aggiunto un provider social.
- Manifest Runner `PrivacyInfo.xcprivacy`: niente tracking né API con motivo obbligatorio usate direttamente dal piccolo wrapper Swift. I plugin devono portare i propri manifest: il report aggregato dell'archivio è un controllo obbligatorio, non una dichiarazione che l'app non raccoglie dati.

## Verifica senza firma

La PR attiva `.github/workflows/ios-build.yml` su un runner macOS con Flutter 3.47.6: risoluzione con lockfile, analisi, test e `flutter build ios --release --no-codesign`.

L'artefatto `Runner.app` è **non firmato, senza configurazione di servizio, non installabile né caricabile sullo store**. Serve solo per verificare la compilazione nativa. Nessuna credenziale o configurazione di produzione è usata dal workflow.

## Archivio firmato da un Mac già configurato

Prerequisiti esterni, non verificati da Windows:

1. Apple Developer Program attivo, accesso al team corretto e autorizzazione alla firma/distribuzione. App Store Connect con ruolo adeguato, accordi correnti e, per gli abbonamenti, accordo Paid Applications e dati fiscali/bancari completati dal titolare.
2. Mac con Xcode e iOS SDK **26 o successivo** già installati/configurati, Flutter 3.47.6 e CocoaPods disponibili nell'account utente. Non vengono eseguiti `sudo`, installazioni amministrative o accettazioni di accordi per conto del titolare.
3. Certificato **Apple Distribution con chiave privata**, profilo **App Store Connect** per il Bundle ID/team, oppure firma automatica già configurata da Xcode. Certificato e `.p8` del server billing sono credenziali diverse; un `.p8` non firma l'app.
4. Record app in App Store Connect: Bundle ID coerente, nome/SKU/lingua, piattaforme supportate. Non cambiare l'identità di un'app esistente.
5. File locale di define (partire da `production.env.example.json`), con `ENVIRONMENT=staging` per TestFlight, API e Supabase **di test**, chiave publishable/anon. Nessuna chiave service role, firma Apple o segreto billing va dentro l'app.

Dalla radice del repository, sul Mac:

```bash
APPLE_TEAM_ID=ABCDEFGHIJ bash scripts/release/ios_archive.sh /absolute/path/dart-defines.json 42
```

`42` è solo un esempio. Lo script valida ambiente/URL/chiave pubblica, esegue analisi e test, genera temporaneamente l'impostazione del team e tenta `flutter build ipa` con export `app-store-connect`. Non carica nulla. Se mancano certificati/profili, aprire `apps/mobile_app/ios/Runner.xcworkspace`, selezionare il team in Signing & Capabilities e risolvere la firma con il proprietario. Il CLI non abilita automaticamente la creazione di profili sul portale.

Confermare che esista davvero `apps/mobile_app/build/ios/ipa/*.ipa`: Flutter può produrre l'archivio ma fallire l'export. Il file IPA deve essere presente, firmato e validato; non basta un messaggio di successo dell'archivio. Ispezionare anche entitlements firmati e report privacy da Xcode Organizer.

Con un archivio valido: **Validate App**, caricamento manuale da Organizer/Transporter, attesa elaborazione in Connect, export compliance, gruppo TestFlight interno; beta review e informazioni beta prima di tester esterni. Nessun caricamento eseguito da questa preparazione.

## StoreKit, backend e pagamenti

Il codice corrente usa `in_app_purchase` (StoreKit su iOS), prezzi dello store, ripristino e gestione abbonamenti Apple; la verifica della transazione passa dal backend. Stripe non viene reintrodotto. Le istruzioni e i sei prodotti sono in `docs/billing/02_configurazione_store.md`:

| Piano | Mensile | Annuale |
|---|---|---|
| Plus | `net.quokkapet.plus.monthly` | `net.quokkapet.plus.yearly` |
| Pro | `net.quokkapet.pro.monthly` | `net.quokkapet.pro.yearly` |
| Ultra | `net.quokkapet.ultra.monthly` | `net.quokkapet.ultra.yearly` |

Da completare sull'account del titolare: gruppo di abbonamenti con livelli Ultra > Pro > Plus, prezzi/localizzazioni, disponibilità e screenshot per revisione, chiave In-App Purchase del backend, Bundle ID coerente, root CA Apple e notifiche server V2 sandbox. Il backend di test usa `BILLING_STORE_ENVIRONMENT=sandbox`. TestFlight usa transazioni sandbox anche con una build release: non puntarlo al backend di produzione per provare gli acquisti. Non applicare la migrazione billing o attivare `BILLING_ENABLED` in produzione come parte di questa procedura.

Prove obbligatorie con account sandbox e dispositivo: acquisto mensile/annuale, transazione pending/annullata, rinnovo, upgrade/downgrade, scadenza, rimborso/revoca, ripristino dopo reinstallazione e su secondo dispositivo, acquisto associato a un diverso account QUOKKA, rete assente, notifiche V2 e riconciliazione. La verifica locale con un eventuale file `.storekit` non sostituisce questi test del server Apple.

**Blocchi applicativi prima della revisione:** verificare nel paywall durata/prezzo/rinnovo automatico/disdetta e link funzionanti a termini/EULA e privacy. `StoreSubscriptionSection` oggi offre acquisto/ripristino/gestione ma non contiene questi link: non dichiarare il paywall pronto solo perché StoreKit compila. La prova app di 14 giorni non equivale a una introductory offer Apple: documentarne il funzionamento e farne approvare il testo prima di configurare offerte nello store.

## Privacy, metadati e revisione

`docs/store/03_dichiarazioni_store.md` è una base storica: B2 (billing dimostrativo) non descrive più tutto il codice attuale e i fornitori IA includono oggi **Anthropic e Groq**. Non copiarlo senza riconciliare codice, backend e contratti dell'ambiente distribuito.

Prima dell'invio:

- Pubblicare/confermare URL privacy, supporto e termini/EULA; dati del titolare, conservazione/cancellazione e trasferimenti/fornitori devono essere corretti. Le bozze locali non provano che gli URL pubblici siano disponibili.
- Compilare App Privacy per dati realmente raccolti: contatti/account e ID utente, posizione, foto/video/audio/documenti, messaggi e altri contenuti utente, cronologia acquisti/abbonamenti. I dati clinici degli animali non sono automaticamente dati sanitari umani. Valutare Sentry in base alla build: lo script di archivio mantiene il crash reporting disattivato. Non selezionare «nessun dato raccolto».
- Esplicitare chi riceve dati personali per IA e ottenere il permesso prima dell'invio, anche per messaggi e voce. Esistono avvisi Anthropic/Groq e consenso alla cartella dell'animale, ma non è stato trovato un consenso generale dedicato tra le chiavi account: **verificare/completare il flusso prima di App Review**, non considerare l'avviso da solo un'autorizzazione.
- Provare eliminazione account in-app, inclusa ri-autenticazione e cancellazione backend; spiegare che cancellare l'account non annulla automaticamente un abbonamento Apple. Nessuna prova distruttiva su utenti reali.
- Controllare segnalazione/moderazione/blocco per chat e mercatino/contenuti utente; nomi localizzati e screenshot iPhone/iPad reali, descrizione senza funzioni assenti, accessibilità, classificazione età coerente con il prodotto. Non ereditare automaticamente un vecchio rating 18+ senza riesaminare questionario e flussi d'età correnti.
- Questionario crittografia/export compliance: HTTPS esiste, ma la qualificazione va confermata dal responsabile; non è stata impostata automaticamente `ITSAppUsesNonExemptEncryption=false`.
- Dati DSA/trader per distribuzione UE, diritti sulle risorse, territori, contatto revisore e account demo funzionante con istruzioni per provare anche il paywall.
- Aggiungere alla prima submission tutti gli abbonamenti da sottoporre a revisione insieme alla versione app; lasciare la pubblicazione manuale finché test e verifiche sono conclusi.

## Differenze funzionali iOS ancora aperte

La presenza del wrapper iOS non completa il porting Android:

| Funzione | Stato del codice attuale | Conseguenza |
|---|---|---|
| Promemoria locali | `createPlatformNotificationsGateway` restituisce un no-op fuori Android; anche disponibilità e richiesta contestuale sono limitate ad Android | Implementare/testare il supporto iOS prima di promettere notifiche/promemoria; l'onboarding può chiedere il permesso senza che poi siano pianificati |
| Passeggiate a schermo spento | Foreground service e widget sono Android; nessuna capability background iOS aggiunta | Non promettere tracking iOS in background; decidere e implementare un comportamento coerente prima della pubblicazione |
| Widget schermata Home | Bridge/widget Android, nessuna estensione WidgetKit | Nessun App Group da attivare finché non esiste l'estensione iOS |
| Condivisione/stampa/media | Plugin presenti, non provati su dispositivo Apple | Provare iPad (ancoraggio share sheet), foto/video/PDF, microfono, geolocalizzazione, stampa e permessi rifiutati |
| Autenticazione | Callback configurata nel wrapper | Provare avvio a freddo e app già aperta, reset e conferma email su ambiente test |

## Fonti ufficiali consultate

- [Flutter: build e rilascio iOS](https://docs.flutter.dev/deployment/ios)
- [Apple: requisiti correnti degli SDK](https://developer.apple.com/news/upcoming-requirements/)
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — acquisti digitali/abbonamenti, privacy/IA e cancellazione account.
- [Apple: manifest privacy](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple: invio degli acquisti in-app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [Geolocator: configurazione iOS](https://pub.dev/packages/geolocator)
- [Permission handler: macro CocoaPods](https://pub.dev/packages/permission_handler/versions/11.3.1)
