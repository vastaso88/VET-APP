# Android: tre app sullo stesso telefono (flavor)

L'app Android ha un product flavor nella dimensione `track`, così più build convivono sul telefono:

| Flavor      | Application id                  | Nome sul telefono  | Icona                |
|-------------|---------------------------------|--------------------|----------------------|
| `prod`      | `com.vetapp.vetapp`             | VetApp             | testa Quokka su Petrolio |
| `francesco` | `com.vetapp.vetapp.francesco`   | VetApp Francesco   | testa Quokka + punto blu in basso a destra |
| `roberto`   | `com.vetapp.vetapp.roberto`     | VetApp Roberto     | testa Quokka + punto arancio |

`prod` mantiene l'id storico ed è quello del futuro Play Store. Il flavor non si chiama `main` perché collide con il source set `main`.

> **Dalla build 40 (decisione del proprietario, 2026-11-16) si costruisce e si distribuisce solo `prod`.**
> I flavor `francesco` e `roberto` restano nel codice e le loro app già installate non si toccano, ma non
> vengono più costruiti né distribuiti.
> **Eccezione (proprietario, 2026-11-23):** per vedere il lavoro in corso sul suo telefono si costruisce il
> flavor `francesco` dal ramo Francesco, sull'app Firebase «VetApp Francesco». L'app parla con il server di
> produzione.

## Prima di installare o distribuire un APK (obbligatorio)

Il 2026-11-23 un APK di collaudo è uscito con il `libapp.so` della build precedente, anche se il codice Dart nuovo era già compilato (il passo Gradle `merge…JniLibFolders` non rieseguiva). Regole:

1. Ogni APK per tester o collaudo nasce da una cartella **senza `build/`**, esportata con `git archive <commit>`, con un file `COMMIT.txt` col commit intero.
2. Prima di installare o distribuire: `python scripts/collaudo/apk_strings.py <apk> --commit <cartella>/COMMIT.txt --expect "<testo nuovo>" [--not-sha256 <libapp.so precedente>]`. Esce con errore se manca una stringa nuova nel `libapp.so` di una ABI, o se lo SHA è quello vecchio. Non si installa né si distribuisce se fallisce.
3. `android/app/build.gradle.kts` impedisce che il passo `merge…JniLibFolders` risulti aggiornato; non rimuoverlo.

## Comandi

Con i flavor definiti `flutter build` / `flutter run` per Android **richiedono `--flavor`**:

```bash
cd apps/mobile_app
flutter build apk --debug --flavor prod --dart-define-from-file=.env.production.json
flutter build apk --debug --flavor francesco --dart-define-from-file=.env.production.json
flutter build apk --debug --flavor roberto --dart-define-from-file=.env.production.json

> Sicurezza: un APK `--debug` è `debuggable`, non offuscato e con il VM service
> attivo: chiunque abbia il telefono (o l'APK) legge sessione, posizione e cache
> con `adb run-as`. Va installato **solo sul proprio telefono di sviluppo**. Ai
> tester si distribuiscono solo build `--release` firmate (pipeline Firebase),
> vedi `docs/security/05_checklist.md`.
```

L'APK esce in `build/app/outputs/flutter-apk/app-<flavor>-debug.apk`. Il web non è coinvolto: `flutter run -d chrome` resta invariato.

## Cosa cambia per flavor

- `applicationId` (suffisso) e `resValue` `app_name` in `android/app/build.gradle.kts`; il manifest usa `android:label="@string/app_name"`.
- Il titolo del widget Passeggiate (`dog_walks_widget_title`) punta ad `@string/app_name`. La notifica della passeggiata mostra il nome dell'app nell'intestazione di sistema.
- Icona adattiva (sfondo Petrolio `#0E3B47` + testa Carta, generata dal logo vettoriale approvato) in `android/app/src/main/res/` (`mipmap-anydpi-v26`, `drawable/ic_launcher_art.xml`). Il punto colorato dei flavor sta in `android/app/src/{francesco,roberto}/res/drawable/ic_launcher_foreground.xml` (sovrascrive quello di `main`). Splash nativo: `drawable/launch_background.xml` (Android < 12) e `values-v31/styles.xml` + `drawable/splash_icon.xml` (Android 12+), colore in `values/brand_colors.xml`. Icona di stato delle notifiche: `drawable/ic_stat_quokka.xml`.
- I `ContentProvider` (image_picker, open_filex, share, androidx-startup) e il permesso `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` usano `${applicationId}`: sono già separati per flavor. Il package Kotlin (`namespace`) resta `com.vetapp.vetapp` per tutti.
- Dati, sessione e notifiche sono separati per app (id diverso). Lo stesso account Supabase si può usare in tutte e tre.

## Limite noto: link di recupero password

Il link dell'email di recupero è `vetapp://auth-callback` (`kPasswordRecoveryRedirect`) e lo schema è registrato nel manifest comune: con più app installate Android mostra la scelta dell'app e, se si sceglie quella sbagliata, il recupero non si completa. Per averlo per-app servirebbero uno schema per flavor (manifestPlaceholders + define Dart) e gli URL aggiunti nei Redirect URLs di Supabase Auth.

## Per il workflow del collaboratore (ramo MULTILANG)

Nel passo di build dell'APK:

```bash
flutter build apk --debug --flavor roberto --dart-define-from-file=.env.production.json
# percorso APK: build/app/outputs/flutter-apk/app-roberto-debug.apk
```

Serve inoltre che il ramo contenga questo `build.gradle.kts` (merge di Francesco in MULTILANG), e che nel workflow sia aggiornato il percorso dell'APK (non più `app-debug.apk`).
