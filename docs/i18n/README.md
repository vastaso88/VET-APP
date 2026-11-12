# Traduzioni (i18n) dell'app Flutter

IT (sorgente), EN, ES, DE e FR sono disponibili per tutta l'app (tutte le chiavi di `app_it.arb` in ogni catalogo; EN vale per UK/US/AU, DE per
DE/AT/CH, FR per FR/BE/CH). I testi fissi del backend sono in tutte e cinque le lingue ([FRENCH_BACKEND_WIRING.md](FRENCH_BACKEND_WIRING.md));
controllo di layout in [STRESS_TEST_FR.md](STRESS_TEST_FR.md) e [STRESS_TEST_DE.md](STRESS_TEST_DE.md).
Vedi [integrazione MULTILANG](MULTILANG_IMPLEMENTATION.md) per preferenze account, chat, testi legali, controlli e prova della branch.

## Sistema per le traduzioni future (leggere prima di toccare un testo)

| Documento | A cosa serve |
|---|---|
| [NUOVE_FUNZIONI.md](NUOVE_FUNZIONI.md) | la procedura: chiavi IT → bozze → revisione → test |
| [GLOSSARIO_E_STILE.md](GLOSSARIO_E_STILE.md) + `glossary.json` | termini di funzioni e veterinari per lingua, registro (tu/tú/Sie/vous), tono, punteggiatura |
| [AUTOMATIC_TRANSLATION.md](AUTOMATIC_TRANSLATION.md) | bozze DeepL, elenco "da rivedere", cosa deve configurare il proprietario (`DEEPL_API_KEY`) |
| [TESTI_STORE_E_LEGALI.md](TESTI_STORE_E_LEGALI.md) | schede store, consensi, testi legali ed e-mail: dove stanno e chi li aggiorna |
| [QA_FINALE_PER_LINGUA.md](QA_FINALE_PER_LINGUA.md) | cosa controllare prima di dire che una lingua è pronta |

L'italiano è la lingua **sorgente**: tutte le frasi visibili stanno in `apps/mobile_app/lib/l10n/app_it.arb` (template). Le altre lingue sono file `app_xx.arb` accanto. Le classi `AppLocalizations*` in `lib/l10n/` sono **generate** da `flutter gen-l10n` (config: `apps/mobile_app/l10n.yaml`; si rigenerano da sole con `flutter pub get`/`flutter run`/`flutter build`, ma sono tenute nel repo).

## Come si usa una frase nel codice
```dart
import '../../../l10n/l10n.dart';          // percorso relativo

Text(context.l10n.settingsLayoutTitle)     // nei widget
appL10n.notificationsReminderTitle         // dove non c'è un BuildContext (domain, repository, notifiche)
```
`context.l10n` ripiega sulla lingua corrente se l'albero non ha i delegati (test con un `MaterialApp` semplice). `appL10n` legge la lingua corrente da `AppLocaleHolder`. Al cambio lingua `VetApp` ricostruisce tutta la UI, quindi anche i testi letti con `appL10n` si aggiornano.

Date e numeri:
- `lib/l10n/date_formats.dart`: `appDateFormat('d MMM y')`, `formatAppDate(...)`, `appShortMonths()`, `appLongWeekdaysMondayFirst()`, `appDecimalSeparator()`… usano la lingua e il paese scelti (mesi minuscoli in italiano).
- Il formato **salvato/inviato** delle date non cambia mai (es. data di nascita pet `"05 mag 2021"`, ISO verso il backend): cambia solo come le mostriamo.
- Unità di misura: `UnitSettingsStore` (Metrico/Regno Unito/USA). Il default segue il paese della variante di lingua scelta (`defaultUnitsForLocale`: GB→UK, US→USA, resto metrico) e viene ignorato se l'utente ha già scelto le unità a mano.
- Fuso orario delle notifiche: quello del telefono (`flutter_timezone`, ripiego `Europe/Rome`), vedi `notification_time_zone.dart`.

## Aggiungere una frase
1. Scegli una chiave camelCase con il prefisso dell'area: `chatInputHint`, `walksSummaryTitle`, `settingsLayoutDensityLabel`. Il nome descrive il significato, non il testo. Se il testo è un "Annulla/Salva/Chiudi…" generico usa le chiavi `common*`.
2. Aggiungila in `app_it.arb`. Una chiave = una frase intera, mai frammenti concatenati.
   - Variabili: `"petsCount": "{name} ha {count} foto"` + `"@petsCount": {"placeholders": {"name": {"type": "String"}, "count": {"type": "int"}}}`.
   - Plurali ICU: `"{count, plural, =0{Nessun profilo} =1{1 profilo} other{{count} profili}}"`.
   - L'apostrofo si scrive normale (`l'animale`); le graffe `{ }` letterali non sono ammesse.
3. `flutter gen-l10n` (o `flutter pub get`) e usa `context.l10n.chiave`.
4. Se esistono già altre lingue, aggiungi la chiave anche lì (vedi sotto: il controllo fallisce se manca).

## Aggiungere una lingua
1. Crea `lib/l10n/app_xx.arb` (`"@@locale": "xx"`). Parti dalle chiavi da tradurre: `python scripts/i18n/check_i18n.py --list-missing xx` (stampa `chiave<TAB>testo italiano`).
2. `flutter gen-l10n`: `AppLocalizations.supportedLocales` ora include la lingua; da quel momento **compaiono da sole** la pagina di scelta lingua al primo avvio (prima della registrazione) e la sezione "Lingua" in Impostazioni (con una sola lingua sono nascoste/saltate).
3. Le varianti con bandiera sono in `lib/features/language/domain/app_language.dart` (`allLanguageVariants`): per aggiungere un paese a una lingua esistente basta una riga (es. 🇨🇦 `en-CA`); le tre inglesi 🇬🇧 🇺🇸 🇦🇺 usano la stessa traduzione `en` ma paesi diversi (unità e formati).
4. Android nativo (notifica passeggiata, widget home): aggiungi `android/app/src/main/res/values-xx/strings.xml` con le stesse chiavi di `values-it/strings.xml`. `AppLanguageContext` applica la preferenza dell'app alle risorse native; aggiorna anche il suo elenco di lingue supportate. Le stringhe passate da Dart seguono la stessa scelta.
5. Backend: la lingua viaggia nel campo `language` di `POST /chat` e `PUT …/messages/{id}` e nell'header `Accept-Language` (it/en/de/fr/es; prompt con istruzione "rispondi nella lingua…"). I **testi legali/consensi** restano nel catalogo backend: aggiungi la lingua in `CONSENT_TEXTS_BY_LANGUAGE` (`packages/core/domain/consent/account_consent_text.py`, ripiego a `it`). I classificatori a parole chiave italiane (red flag, ponte IT→EN in `relevance.py`, ecc.) sono elencati in `docs/i18n/BACKEND_ITALIAN_CLASSIFIERS.md` e vanno resi multilingua a parte.
6. Registra la lingua nei test (`test/language`) e nelle voci elencate in `check_i18n.py` se serve (di norma niente).

## Far tradurre le chiavi mancanti
`python scripts/i18n/check_i18n.py --list-missing de` elenca le chiavi senza traduzione. Una sessione Claude può tradurle direttamente: dagli `app_it.arb` e (se esiste) `app_en.arb` come riferimento, chiedile di aggiungere le chiavi mancanti a `app_de.arb` **mantenendo identici placeholder, plurali ICU e chiavi `@…`** (il controllo verifica che i segnaposto coincidano). Poi:
```bash
python scripts/i18n/check_i18n.py --arb-only
cd apps/mobile_app && flutter gen-l10n && flutter test
```

## Guardie automatiche
`python scripts/i18n/check_i18n.py` (o `make i18n-check`; è anche in `tests/unit/test_check_i18n_script.py`, quindi in `uv run pytest`):
1. segnala le stringhe italiane scritte direttamente nel codice Dart fuori da `lib/l10n` (euristica: lettere accentate o parole italiane frequenti dentro un literal). Le eccezioni giustificate stanno in `scripts/i18n/allowlist.txt` (riga `percorso :: sottostringa`, oppure un file intero); **scrivi sempre il motivo**.
2. richiede EN/ES/DE/FR e confronta ogni `app_xx.arb` con il template: **fallisce** per chiavi mancanti o aggiuntive, valori vuoti e segnaposto incompatibili.
3. `glossary.py check` (nome delle funzioni uguale al glossario) e `auto_translate.py check` (traduzioni non obsolete) completano il controllo in CI, vedi [AUTOMATIC_TRANSLATION.md](AUTOMATIC_TRANSLATION.md).
4. segnala anche testi passati direttamente ai widget in altre lingue o su più righe. Resta un controllo euristico: la revisione del codice deve verificare i testi costruiti dinamicamente.

## Cosa NON tradurre
- chiavi tecniche, codici di errore, id, URL, log, chiavi SharedPreferences, nomi di route, testi dei test;
- nomi propri (VetApp, OpenStreetMap…) e i nomi delle lingue (sono scritti nella lingua stessa);
- valori salvati o inviati al backend (specie `Cane`, formato `05 mag 2021`, ecc.): si traduce l'etichetta mostrata, non il valore;
- testi legali/consensi: arrivano dal backend (`GET /legal/consents?lang=xx`);
- elenchi dati: razze e specie (`pet_breeds.dart`, `pet_species_breeds.dart`, `fish_species.dart`), titoli e fonti delle notizie, nomi dei luoghi (OSM/Overture);
- le risposte del modello di chat (il backend risponde nella lingua richiesta).

## Messaggi di errore dal backend
Dove l'app mostra un messaggio del backend, i codici/testi noti sono mappati a chiavi locali (es. `localizedBackendMessage` in `chat_remote_data_source.dart`); un messaggio sconosciuto viene mostrato così com'è. Elenco dei non mappati: nel report del lavoro di predisposizione.
