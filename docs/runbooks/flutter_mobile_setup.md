# Flutter Web Setup

## Obiettivo

Preparare il client Flutter in `apps/mobile_app` e permettere a Codex di lavorare sul frontend web con feedback rapido, mantenendo la configurazione mobile pronta per release successive.

## Stato attuale

La repo contiene un bootstrap Flutter manuale in:

- `apps/mobile_app/`

Il codice non e' stato eseguito in questa sessione perche' `flutter` e `dart` non sono ancora disponibili nel `PATH`.

## Installazione Flutter

1. Scarica Flutter SDK dal sito ufficiale.
2. Estrai la cartella in un path stabile.
3. Aggiungi Flutter al `PATH`.
4. Apri un nuovo terminale e verifica:
   - `flutter --version`
   - `dart --version`
5. Controlla che Chrome sia disponibile per il preview web.
6. Se vuoi preparare la release mobile successiva, aggiungi anche gli strumenti Android o iOS adatti alla tua macchina.
7. Controlla lo stato finale:
   - `flutter doctor`

## Primo avvio del progetto

Dal root della repo:

```powershell
cd apps/mobile_app
flutter pub get
flutter run -d chrome
```

## Target API preview

Per il preview web puoi configurare `API_BASE_URL` in `apps/mobile_app/.env.example` oppure passarlo via `--dart-define` quando vuoi collegarti a un backend reale o di staging.

## Come lavorare bene con Codex su Flutter

Quando Flutter e' installato, il flusso ideale e':

1. tu lanci `flutter run -d chrome`
2. io modifico i file in `apps/mobile_app/lib/`
3. tu fai hot reload con `r`
4. se serve, io leggo errori e li correggo

## Comandi utili

```powershell
cd apps/mobile_app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Prossimi step consigliati

1. installare Flutter e verificare `flutter doctor`
2. far partire `apps/mobile_app` in Chrome
3. rifinire onboarding
4. implementare `auth`
5. collegare API e Supabase


## Supabase canonico

Per build e test collegati al backend reale, usare il progetto `ywbuzgwbkrmkukkpysbz`. Le build che puntano a `dkzzcoastheciitvkiuo` o `noulpaaonqjvprfddipn` sono obsolete e vanno ricompilate.
