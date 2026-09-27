# Permessi del dispositivo (OS)

Aggiornato (2026-09-26): l'app nativa Android è ora in costruzione (sessione "APK e App nativa" — `flutter create --platforms=android`, application ID `com.vetapp.vetapp`). A differenza della versione web, l'app nativa gira dentro il modello di permessi runtime di Android/iOS: questo documento passa da "principi per quando servirà" a un catalogo concreto di cosa dichiarare, quando chiederlo e cosa dire all'utente.

## Due principi, imposti dalle policy Apple/Play Store (non dal GDPR)

1. **Richiesta just-in-time**: chiedi il permesso nel momento in cui l'utente prova a usare la funzione che lo richiede, mai in una schermata iniziale generica prima che serva davvero.
2. **Graceful degradation**: se l'utente nega, disabilita solo quella funzione specifica. L'app deve restare pienamente utilizzabile per tutto il resto. Bloccare l'intero accesso all'app per un permesso OS negato non supera la review di Apple/Google, oltre a essere una pessima esperienza.

L'evento di consenso autorevole per un permesso OS è il dialog nativo del sistema operativo, non un testo scritto dall'app — l'app può solo spiegare *prima* del dialog perché sta per chiederlo (rationale), non registrare essa stessa il consenso come fa per i consensi GDPR in [04_termini_e_consensi.md](04_termini_e_consensi.md).

## Perché dichiarare permessi "probabili" ora, anche se inutilizzati

Discusso con la sessione "APK e App nativa": su Android un permesso deve essere dichiarato in `AndroidManifest.xml` — cioè nel pacchetto installato — perché il popup di richiesta possa comparire in futuro. Un aggiornamento via OTA/code-push (Shorebird) del solo codice Dart **non può aggiungere un permesso nuovo**: se non era già nel manifest installato, serve un nuovo APK che l'utente deve scaricare e installare.

Conseguenza pratica: per i permessi legati a funzioni **plausibili a breve termine** (non usate oggi, ma quasi certe), conviene dichiararle già ora nel manifest. Quando la funzione verrà davvero attivata con un aggiornamento del codice, Android mostrerà il normale popup di richiesta al primo utilizzo — senza bisogno di un nuovo APK. Per i permessi **sensibili o incerti** (es. posizione in background), meglio aspettare una decisione di roadmap esplicita: dichiararli senza usarli comporta comunque una domanda di giustificazione nella review dello store, quindi non è mai "gratis".

## Catalogo permessi

| Permesso | Android | iOS | Funzione collegata | Stato | Note |
|---|---|---|---|---|---|
| Microfono | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` | Messaggi vocali nella chat (`record` package, già usato in [chat_composer.dart](../../apps/mobile_app/lib/features/chat/presentation/widgets/chat_composer.dart)) | **Necessario subito** — la funzione esiste già nel codice Dart | Non è proattivo: se manca nel manifest generato, l'app crasha o la funzione non funziona al primo uso reale, non è un'opzione rimandabile |
| Posizione precisa (foreground) | `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` | Località (Impostazioni), passeggiate cane, attività/eventi locali (`geolocator`, già in uso) | **Necessario subito** | Solo "while in use" — non "always" |
| Fotocamera | `CAMERA` | `NSCameraUsageDescription` | Non ancora nel codice: oggi la cartella clinica accetta solo file già esistenti ([medical_record_upload_page.dart](../../apps/mobile_app/lib/features/medical_records/presentation/pages/medical_record_upload_page.dart) usa solo `file_picker`) — scattare la foto di un referto/libretto invece di doverlo prima salvare come file è un miglioramento UX quasi scontato | **Dichiarare proattivamente** | Utile anche per una futura foto profilo pet o foto annuncio nel marketplace |
| Libreria foto | `READ_MEDIA_IMAGES` (Android 13+) | `NSPhotoLibraryUsageDescription` (solo se si va oltre il selettore di sistema) | Stesso caso della fotocamera, per allegare una foto già esistente in galleria | **Dichiarare proattivamente**, ma verificare quale package si sceglie: usando il photo picker di sistema (es. `image_picker` in modalità picker), Android non richiede questo permesso in modo esplicito | Da confermare con chi implementa, in base al package scelto |
| Notifiche push | `POST_NOTIFICATIONS` (obbligatorio da Android 13+, prima era implicito) | Autorizzazione via `UNUserNotificationCenter` | Promemoria (vaccinazioni, cure) — oggi solo UI decorativa in Reminders, nessuna notifica reale pianificata | **Dichiarare proattivamente** | I promemoria sono già una feature centrale del prodotto: è il candidato più forte per "dichiara ora, attiva dopo via OTA" |
| Posizione in background | `ACCESS_BACKGROUND_LOCATION` | Autorizzazione "Always" | Ipotetica: tracciare l'intera passeggiata a schermo spento/app in background (oggi `active_walk_page.dart` traccia solo in foreground) | **Non dichiarare ora** | Permesso ad alto scrutinio su entrambi gli store (richiede giustificazione dedicata in review); da valutare solo se/quando la funzione verrà davvero decisa |
| Contatti | — | — | Nessuna funzione attuale o pianificata | **Non dichiarare** | Un permesso dichiarato ma inutilizzato è comunque una domanda in più nella review dello store e un motivo di diffidenza per l'utente |
| Calendario | `READ_CALENDAR` / `WRITE_CALENDAR` | `NSCalendarsUsageDescription` | Idea riaperta dall'utente (2026-09-26): esportare i promemoria (vaccini, cure) sul calendario nativo del telefono | **Non dichiarare** — ma vedi nota | Distinguere due casi ben diversi: (a) **scrivere un singolo promemoria** nel calendario dell'utente — realizzabile con un bottone "Aggiungi al calendario" che passa la mano all'app calendario via intent/file `.ics`, **senza alcun permesso runtime**; (b) **leggere/scrivere l'intero calendario** (il permesso vero e proprio) — ad alto scrutinio in review quanto la posizione in background, e richiede di risolvere prima la sincronizzazione bidirezionale (data spostata o evento cancellato lato calendario vs lato VetApp). Per il bisogno reale di VetApp (scrivere un promemoria, non leggere gli impegni esistenti dell'utente) l'opzione (a) copre quasi tutto il valore a costo/permesso zero — partire da lì. Il permesso pieno (b) si giustifica solo se in futuro serve leggere gli impegni dell'utente (es. proporre orari liberi per una visita) |
| Storage file generico | — (gestito da `file_picker` senza permessi ampi su Android moderno) | — | Allegati cartella clinica | Nessuna azione | Android 11+ ha già ristretto/deprecato l'accesso storage ampio; `file_picker` usa il selettore di sistema |

## Testo di richiesta (rationale) — da mostrare prima del popup di sistema

Per ciascun permesso "necessario subito" o "da dichiarare proattivamente", una frase breve e concreta (non generica) da mostrare nell'interfaccia immediatamente prima che scatti il popup nativo, così l'utente capisce perché viene chiesto prima di doverlo indovinare dal dialog di sistema:

- **Microfono**: "Per inviare un messaggio vocale, VetApp ha bisogno di accedere al microfono."
- **Posizione**: "Per suggerirti eventi e attività vicino a te, VetApp ha bisogno della tua posizione." (coerente con quanto già mostrato in Impostazioni → Località)
- **Fotocamera**: "Per fotografare un documento clinico, VetApp ha bisogno di accedere alla fotocamera."
- **Notifiche**: "Per avvisarti quando è ora di un vaccino o di una cura, VetApp vuole inviarti notifiche."

Ogni testo si applica al momento dell'azione specifica (es. l'utente preme "aggiungi messaggio vocale"), mai in una schermata di onboarding generica — coerente con il principio just-in-time sopra.

## Aggiornamento obbligatorio quando un permesso non era già dichiarato

Se una funzione richiede un permesso **non** già presente nel manifest installato (il caso "non dichiarare ora" della tabella, quando/se diventa reale), non basta un aggiornamento silenzioso: l'utente deve installare un nuovo APK. In quel caso, l'app deve dirlo esplicitamente invece di fallire in modo silenzioso o poco chiaro:

- **Testo**: "Per continuare a usare [nome funzione], aggiorna l'app."
- **Azione**: un bottone che porta direttamente allo store/pagina di aggiornamento (Play Store se distribuita lì, pagina di download diretta se sideload/sito proprio — vedi discussione canali di distribuzione nella sessione "APK e App nativa").
- **Dopo l'aggiornamento**: al primo utilizzo della nuova funzione, compare il normale popup di sistema per il nuovo permesso — nessuna azione aggiuntiva richiesta all'app oltre ad averlo dichiarato nel nuovo manifest.

Punto aperto per chi implementa (sessione "APK e App nativa", quando riprenderanno il punto "aggiornamento automatico" rimandato a MVP pronto): serve un meccanismo con cui l'app sappia di essere troppo vecchia per una funzione (es. una versione minima richiesta esposta dal backend, o l'API di in-app update di Play Store) — il testo e il comportamento del bottone sopra sono il requisito, il meccanismo tecnico per rilevare "sei indietro" resta loro da progettare.
