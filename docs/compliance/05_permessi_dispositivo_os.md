# Permessi del dispositivo (OS)

Aggiornato (2026-10-06): audit del manifest della build 0.1.0+24 (sezione in fondo); corrette le righe Fotocamera, Libreria foto e Storage. Aggiornato (2026-09-26): l'app nativa Android è ora in costruzione (sessione "APK e App nativa" — `flutter create --platforms=android`, application ID `com.vetapp.vetapp`). A differenza della versione web, l'app nativa gira dentro il modello di permessi runtime di Android/iOS: questo documento passa da "principi per quando servirà" a un catalogo concreto di cosa dichiarare, quando chiederlo e cosa dire all'utente.

## Due principi, imposti dalle policy Apple/Play Store (non dal GDPR)

1. **Richiesta just-in-time**: chiedi il permesso nel momento in cui l'utente prova a usare la funzione che lo richiede, mai in una schermata iniziale generica prima che serva davvero.
2. **Graceful degradation**: se l'utente nega, disabilita solo quella funzione specifica. L'app deve restare pienamente utilizzabile per tutto il resto. Bloccare l'intero accesso all'app per un permesso OS negato non supera la review di Apple/Google, oltre a essere una pessima esperienza.

L'evento di consenso autorevole per un permesso OS è il dialog nativo del sistema operativo, non un testo scritto dall'app — l'app può solo spiegare *prima* del dialog perché sta per chiederlo (rationale), non registrare essa stessa il consenso come fa per i consensi GDPR in [04_termini_e_consensi.md](04_termini_e_consensi.md).

## Perché dichiarare permessi "probabili" ora, anche se inutilizzati

Discusso con la sessione "APK e App nativa": su Android un permesso deve essere dichiarato in `AndroidManifest.xml` — cioè nel pacchetto installato — perché il popup di richiesta possa comparire in futuro. Un aggiornamento via OTA/code-push (Shorebird) del solo codice Dart **non può aggiungere un permesso nuovo**: se non era già nel manifest installato, serve un nuovo APK che l'utente deve scaricare e installare.

Conseguenza pratica: per i permessi legati a funzioni **plausibili a breve termine** (non usate oggi, ma quasi certe), conviene dichiararle già ora nel manifest. Quando la funzione verrà davvero attivata con un aggiornamento del codice, Android mostrerà il normale popup di richiesta al primo utilizzo — senza bisogno di un nuovo APK. Per i permessi **sensibili o incerti** (es. posizione in background), meglio aspettare una decisione di roadmap esplicita: dichiararli senza usarli comporta comunque una domanda di giustificazione nella review dello store, quindi non è mai "gratis".

**Eccezioni (audit 2026-10-06).** La dichiarazione proattiva non vale per i permessi che Google Play limita (foto e video: `READ_MEDIA_IMAGES` e `READ_MEDIA_VIDEO`) né per quelli che il plugin scelto non richiede (la fotocamera di sistema usata da `image_picker` non ha bisogno di `CAMERA`). E se la funzione futura richiede un nuovo plugin nativo, serve comunque un nuovo APK: dichiarare il permesso prima non evita nulla.

## Catalogo permessi

| Permesso | Android | iOS | Funzione collegata | Stato | Note |
|---|---|---|---|---|---|
| Microfono | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` | Messaggi vocali nella chat (`record` package, già usato in [chat_composer.dart](../../apps/mobile_app/lib/features/chat/presentation/widgets/chat_composer.dart)) | **Necessario subito** — la funzione esiste già nel codice Dart | Non è proattivo: se manca nel manifest generato, l'app crasha o la funzione non funziona al primo uso reale, non è un'opzione rimandabile |
| Posizione precisa (foreground) | `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` | Località (Impostazioni), passeggiate cane, attività/eventi locali (`geolocator`, già in uso) | **Necessario subito** | Solo "while in use" — non "always". Durante una passeggiata attiva il tracciamento prosegue con l'app in secondo piano grazie a un servizio in primo piano con notifica persistente (`FOREGROUND_SERVICE` e `FOREGROUND_SERVICE_LOCATION`), non a `ACCESS_BACKGROUND_LOCATION` |
| Fotocamera | `CAMERA` | `NSCameraUsageDescription` | Foto e video dei propri animali ([pet_gallery_page.dart](../../apps/mobile_app/lib/features/pets/presentation/pages/pet_gallery_page.dart): `image_picker` con `ImageSource.camera`); in prospettiva, la foto di un referto (oggi la cartella clinica usa solo `file_picker`) | **Non necessario oggi: consigliato toglierlo** (audit 2026-10-06) | `image_picker` apre la fotocamera di sistema: senza `CAMERA` nel manifest funziona, e l'app non accede mai alla fotocamera, riceve solo il file scattato. Se `CAMERA` è dichiarato, il plugin lo chiede a runtime prima di aprire la fotocamera. Serve solo per una fotocamera integrata (anteprima propria, scanner di documenti), che richiederebbe comunque un nuovo plugin nativo e quindi un nuovo APK |
| Libreria foto e video | `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` (Android 13+) | `NSPhotoLibraryUsageDescription` (solo se si va oltre il selettore di sistema) | Allegare foto o video già in galleria (`pickMultipleMedia` in pet_gallery_page.dart; `file_picker` per allegati e cartella clinica) | **Non dichiarare** (audit 2026-10-06; prima era "da confermare") | Il codice usa il selettore di sistema, che non richiede permessi. Google Play ammette questi due permessi solo per l'accesso ampio e frequente alla galleria, con dichiarazione e revisione (dettagli nell'audit) |
| Notifiche push | `POST_NOTIFICATIONS` (obbligatorio da Android 13+, prima era implicito) | Autorizzazione via `UNUserNotificationCenter` | Promemoria (vaccinazioni, cure) — oggi solo UI decorativa in Reminders, nessuna notifica reale pianificata | **Dichiarare proattivamente** | I promemoria sono già una feature centrale del prodotto: è il candidato più forte per "dichiara ora, attiva dopo via OTA" |
| Posizione in background | `ACCESS_BACKGROUND_LOCATION` | Autorizzazione "Always" | Ipotetica: tracciare l'intera passeggiata a schermo spento/app in background (oggi `active_walk_page.dart` traccia solo in foreground) | **Non dichiarare ora** | Permesso ad alto scrutinio su entrambi gli store (richiede giustificazione dedicata in review); da valutare solo se/quando la funzione verrà davvero decisa |
| Contatti | — | — | Nessuna funzione attuale o pianificata | **Non dichiarare** | Un permesso dichiarato ma inutilizzato è comunque una domanda in più nella review dello store e un motivo di diffidenza per l'utente |
| Calendario | `READ_CALENDAR` / `WRITE_CALENDAR` | `NSCalendarsUsageDescription` | Idea riaperta dall'utente (2026-09-26): esportare i promemoria (vaccini, cure) sul calendario nativo del telefono | **Non dichiarare** — ma vedi nota | Distinguere due casi ben diversi: (a) **scrivere un singolo promemoria** nel calendario dell'utente — realizzabile con un bottone "Aggiungi al calendario" che passa la mano all'app calendario via intent/file `.ics`, **senza alcun permesso runtime**; (b) **leggere/scrivere l'intero calendario** (il permesso vero e proprio) — ad alto scrutinio in review quanto la posizione in background, e richiede di risolvere prima la sincronizzazione bidirezionale (data spostata o evento cancellato lato calendario vs lato VetApp). Per il bisogno reale di VetApp (scrivere un promemoria, non leggere gli impegni esistenti dell'utente) l'opzione (a) copre quasi tutto il valore a costo/permesso zero — partire da lì. Il permesso pieno (b) si giustifica solo se in futuro serve leggere gli impegni dell'utente (es. proporre orari liberi per una visita) |
| Storage file generico e audio | `READ_EXTERNAL_STORAGE` (fino ad Android 12), `READ_MEDIA_AUDIO` | — | Allegati cartella clinica (`file_picker` con il selettore di sistema) e apertura dei PDF (`open_filex`, da una cartella temporanea dell'app) | **Non dichiarare** | Android 11+ ha già ristretto l'accesso storage ampio. `open_filex` 4.7.0 aggiunge da solo `READ_EXTERNAL_STORAGE` (fino ad Android 12), `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` e `READ_MEDIA_AUDIO`: vanno rimossi, vedi l'audit |

## Testo di richiesta (rationale) — da mostrare prima del popup di sistema

Per ciascun permesso "necessario subito" o "da dichiarare proattivamente", una frase breve e concreta (non generica) da mostrare nell'interfaccia immediatamente prima che scatti il popup nativo, così l'utente capisce perché viene chiesto prima di doverlo indovinare dal dialog di sistema:

- **Microfono**: "Per inviare un messaggio vocale, VetApp ha bisogno di accedere al microfono."
- **Posizione**: "Per suggerirti eventi e attività vicino a te, VetApp ha bisogno della tua posizione." (coerente con quanto già mostrato in Impostazioni → Località)
- **Fotocamera** (solo se `CAMERA` resta nel manifest, vedi audit): "Per fotografare un documento clinico, VetApp ha bisogno di accedere alla fotocamera."
- **Notifiche**: "Per avvisarti quando è ora di un vaccino o di una cura, VetApp vuole inviarti notifiche."

Ogni testo si applica al momento dell'azione specifica (es. l'utente preme "aggiungi messaggio vocale"), mai in una schermata di onboarding generica — coerente con il principio just-in-time sopra.

## Aggiornamento obbligatorio quando un permesso non era già dichiarato

Se una funzione richiede un permesso **non** già presente nel manifest installato (il caso "non dichiarare ora" della tabella, quando/se diventa reale), non basta un aggiornamento silenzioso: l'utente deve installare un nuovo APK. In quel caso, l'app deve dirlo esplicitamente invece di fallire in modo silenzioso o poco chiaro:

- **Testo**: "Per continuare a usare [nome funzione], aggiorna l'app."
- **Azione**: un bottone che porta direttamente allo store/pagina di aggiornamento (Play Store se distribuita lì, pagina di download diretta se sideload/sito proprio — vedi discussione canali di distribuzione nella sessione "APK e App nativa").
- **Dopo l'aggiornamento**: al primo utilizzo della nuova funzione, compare il normale popup di sistema per il nuovo permesso — nessuna azione aggiuntiva richiesta all'app oltre ad averlo dichiarato nel nuovo manifest.

Punto aperto per chi implementa (sessione "APK e App nativa", quando riprenderanno il punto "aggiornamento automatico" rimandato a MVP pronto): serve un meccanismo con cui l'app sappia di essere troppo vecchia per una funzione (es. una versione minima richiesta esposta dal backend, o l'API di in-app update di Play Store) — il testo e il comportamento del bottone sopra sono il requisito, il meccanismo tecnico per rilevare "sei indietro" resta loro da progettare.

## Audit del manifest della build 0.1.0+24 (2026-10-06)

Richiesto dall'Orchestratore: la build 24 mostra `READ_MEDIA_VIDEO` e `READ_MEDIA_AUDIO` nel manifest. Questa sezione verifica la coerenza con il catalogo sopra, le regole di Google Play e l'effetto sull'informativa.

**Cosa ho controllato.** Il manifest fuso di debug (`apps/mobile_app/build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml`), i manifest e il codice dei plugin nella cache di pub, e dove il codice Dart usa i plugin. **Limite:** in questo checkout ci sono solo APK debug, e l'ultima procedura nota per distribuire i test usa `flutter build apk --debug`. Il manifest release quindi non è verificato: i passi per farlo sono sotto.

**Da dove vengono.** Non da `image_picker` né da `video_player`: `image_picker_android` 0.8.13+25 e `video_player_android` 2.12.2 non dichiarano permessi. `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE` (solo fino ad Android 12) e un secondo `READ_MEDIA_IMAGES` li aggiunge il plugin **`open_filex` 4.7.0**, che il codice usa solo per aprire i PDF dei referti ([native_pdf_opener.dart](../../apps/mobile_app/lib/features/medical_records/presentation/native_pdf_opener.dart)). `CAMERA` e `READ_MEDIA_IMAGES` sono invece dichiarati dall'app, come raccomandava la versione precedente di questo documento.

### Permessi del manifest fuso

| Permesso | Origine | Usato? | Azione |
|---|---|---|---|
| `INTERNET` | `src/debug` e `src/profile`, non il manifest principale | Sì: tutta la rete | **Aggiungerlo al manifest principale.** Nessun plugin dell'app lo fornisce (controllati i manifest dei plugin di `pubspec.lock`; le librerie transitive non sono state ispezionate): una build release potrebbe non avere rete |
| `POST_NOTIFICATIONS` | App | Sì: promemoria (richiesta in `notification_permission_page.dart`) | Tenere |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | App | Sì: Località, passeggiate, attività locali | Tenere |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | App | Sì: tracciamento di una passeggiata attiva, con notifica persistente | Tenere. Da dichiarare nell'informativa e, per Play, nella dichiarazione dei servizi in primo piano (punto 26 del registro) |
| `RECORD_AUDIO` | Plugin `record_android` | Sì: messaggi vocali | Tenere |
| `CAMERA` | App (dichiarazione proattiva) | No: `image_picker` usa la fotocamera di sistema | Consigliato toglierlo. Nessun obbligo di policy |
| `READ_MEDIA_IMAGES` | App e `open_filex` | No: selettore di sistema | **Rimuovere** |
| `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE` (≤ API 32) | `open_filex` | No | **Rimuovere** |
| `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED` | Dipendenze transitive | Indiretto | Nessuna azione |
| `com.vetapp.vetapp.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX (permesso di firma interno) | — | Nessuna azione |

### Perché i permessi sui media non servono

- **Foto e video.** `image_picker` usa il selettore di foto di Android da Android 13 in poi (lo scrive il README del plugin) e la fotocamera di sistema. `file_picker` 8.3.7 usa solo gli intent del selettore di documenti (`ACTION_OPEN_DOCUMENT`, `ACTION_GET_CONTENT`) e non contiene codice di richiesta permessi.
- **PDF.** `native_pdf_opener.dart` scrive il PDF nella cartella temporanea dell'app. `open_filex` chiede un permesso solo per i file fuori dalle cartelle dell'app (`pathRequiresPermission()`), quindi qui non lo chiede mai.
- **Audio.** Nessuna funzione legge file audio dalla libreria: i messaggi vocali sono registrati con `record` (`RECORD_AUDIO`).

### Regole di Google Play

Pagina «Photo and Video Permissions», letta il 2026-10-06: [support.google.com/googleplay/android-developer/answer/14115180](https://support.google.com/googleplay/android-developer/answer/14115180). Il testo cambia: riverificarlo prima di pubblicare.

- `READ_MEDIA_IMAGES` e `READ_MEDIA_VIDEO` sono ammessi solo se la funzione principale dell'app richiede accesso ampio e frequente a foto e video (per esempio una galleria o un'app di backup). Serve la dichiarazione in Play Console, soggetta a revisione.
- Per un accesso occasionale, la policy chiede il selettore di sistema. Un selettore proprio non basta come giustificazione.
- Le scadenze sono passate: finestra di dichiarazione dal 2024-09-18 al 2025-01-22, con estensione fino al 2025-05-28. Le app non conformi possono subire azioni, fino alla rimozione.
- La pagina non cita `READ_MEDIA_AUDIO`: nessuna dichiarazione dedicata. Resta un permesso che l'app non usa, da togliere per minimizzazione (art. 5(1)(c) GDPR e art. 25, privacy by design) ⚖️.
- VetApp usa le foto in modo occasionale (galleria dell'animale, allegati) e non ha una funzione principale che giustifichi l'accesso ampio: rientra nel caso del selettore. `READ_MEDIA_IMAGES` e `READ_MEDIA_VIDEO` non vanno dichiarati.

Gli APK di test distribuiti con Firebase non passano da questa revisione: il rischio è alla pubblicazione su Play. Conviene correggere il manifest prima, così il primo caricamento nasce già conforme.

### Raccomandazione tecnica per «APK e App nativa»

In `apps/mobile_app/android/app/src/main/AndroidManifest.xml`:

1. Aggiungere `xmlns:tools="http://schemas.android.com/tools"` al tag `<manifest>`.
2. Cancellare la riga `READ_MEDIA_IMAGES` dichiarata dall'app (lo stesso permesso non può essere dichiarato e rimosso insieme) e, se si accetta la raccomandazione, la riga `CAMERA`. Aggiornare il commento sopra.
3. Aggiungere i marcatori di rimozione: tolgono i permessi anche se li dichiara un plugin.

```xml
<!-- open_filex declares these, but nothing in the app needs them: photos and
     videos go through the system picker, PDFs are opened from the app cache.
     Google Play restricts READ_MEDIA_IMAGES/VIDEO to apps with broad, frequent
     gallery access. See docs/compliance/05_permessi_dispositivo_os.md. -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" tools:node="remove" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" tools:node="remove" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" tools:node="remove" />
```

4. Aggiungere `<uses-permission android:name="android.permission.INTERNET" />` al manifest principale (oggi c'è solo in debug e profile).
5. Lasciare `open_filex` dov'è: sostituirlo non serve.

**Verifica.**

- Manifest release fuso: `cd apps/mobile_app/android && ./gradlew :app:processReleaseManifest`, poi leggere `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml` (il percorso può cambiare con la versione del plugin Android). In alternativa, su un APK: `aapt2 dump permissions app-release.apk` (strumenti in `%LOCALAPPDATA%\Android\Sdk\build-tools\<versione>`).
- Atteso: nessun `READ_MEDIA_*`, nessun `READ_EXTERNAL_STORAGE`, `INTERNET` presente, `CAMERA` assente se rimosso.
- Su un telefono: aprire il PDF di un referto; scegliere una foto dalla galleria (si apre il selettore, senza richiesta di permessi); scattare una foto e girare un video con la fotocamera di sistema.

Togliere permessi con un aggiornamento è silenzioso: nessun nuovo popup e nessun «aggiorna per continuare».

### Effetti sull'informativa e sul modulo «Sicurezza dei dati» di Play

- **Informativa** ([09](09_informativa_privacy_bozza.md)): aggiunta la sezione «Permessi del dispositivo». Le frasi su galleria e fotocamera valgono solo dopo la correzione del manifest. Aggiunti anche i percorsi GPS delle passeggiate, che il backend conserva (`WalkSession.route`: punti con data, ora e precisione), e il fatto che durante una passeggiata attiva la posizione continua a essere rilevata con l'app in secondo piano.
- **Modulo «Sicurezza dei dati» in Play Console** (registro [08](08_punti_aperti_prima_del_lancio.md), punto 26): deve essere coerente con l'informativa. I dati da dichiarare, da confrontare con i campi correnti del modulo: foto e video, registrazioni audio (messaggi vocali), posizione (compresi i percorsi), file e documenti, indirizzo email e identificativi utente.
- **Testo di richiesta della fotocamera**: se `CAMERA` viene tolto, non serve più.
