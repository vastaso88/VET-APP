# QA finale per lingua

Cosa controllare prima di dire che una lingua (o una variante di paese) è pronta, e quali controlli sono già automatici.
Vale per `it`, `en-GB`, `en-US`, `en-AU`, `de`, `de-AT`, `de-CH`, `fr`, `fr-BE`, `fr-CH`, `es`.

## 1. Controlli automatici (tutti in locale, `SUPABASE_URL` vuoto)

| Comando | Cosa garantisce |
|---|---|
| `make i18n-check` | stesse chiavi e segnaposto in ogni `app_xx.arb`; nessuna stringa italiana scritta nel codice Dart |
| `cd apps/mobile_app && flutter test test/language --dart-define=SUPABASE_URL=` | tutti i test sulle lingue, qui sotto |
| `uv run pytest tests/unit/test_store_listings.py` | limiti di lunghezza e promesse vietate nelle schede store (`docs/store/`) |
| `python scripts/i18n/build_email_templates.py --check` | le email di Supabase (`supabase/email_templates/`) sono aggiornate rispetto allo script |
| `flutter analyze`, `flutter test`, `uv run ruff check .`, `uv run mypy apps packages tests`, `uv run pytest` | la base di sempre |

Test sulle lingue (`apps/mobile_app/test/language/`):

- `regional_formats_test.dart` — **formati per variante**: per ognuna delle 11 varianti valuta (`£ $ A$ € CHF`, lato del simbolo e
  separatori), prezzo del piano e del Mercatino, data numerica, data digitata (ordine e separatore), suggerimento del campo, paese
  predefinito dell'indirizzo, unità. Telefono e CAP per paese. Un test di guardia fallisce se nel codice compare di nuovo un simbolo di
  valuta o un ordine di data scritto a mano fuori da `lib/l10n/regional_defaults.dart`.
- `language_variant_memory_test.dart` — **selettore lingua**: ricorda l'ultima variante per lingua (anche dopo il riavvio); un telefono
  che non dice quale inglese/tedesco/francese viene **interpellato**, mai indovinato.
- `language_qa_test.dart` — **overflow a 320×568** in it/en/de/fr/es su login, registrazione, primi passi, nuovo animale, piani e sezione
  lingua (font Roboto dell'SDK Flutter e stessa scala testo dell'app, vedi `app/app.dart`); **nessun testo italiano residuo** (una
  stringa a schermo uguale a una stringa italiana dell'ARB che nella lingua scelta è diversa fa fallire il test); **cambio lingua a
  runtime** it → de → fr → en-US → es sulle schermate dove il selettore è raggiungibile. Una seconda sezione prova le stesse pagine **in tedesco a 360×640 con il testo di sistema ingrandito 1,5× e 2×** (`_knownLargeTextOverflows` elenca le eccezioni motivate).
- `language_choice_test.dart`, `multilingual_widgets_test.dart`, `german_*`, `french_*`, `account_language_test.dart` — scelta, persistenza,
  priorità sessione > account > dispositivo > telefono > italiano, selettore compatto.

## 2. Difetti noti trovati da questa QA (non risolti qui: appartengono alle sessioni di interfaccia)

Sono elencati in `_knownOverflows` di `language_qa_test.dart`; quando si correggono, togliere la voce.

| Dove | Cosa | Lingue |
|---|---|---|
| `pet_profile_form.dart:390` e `:582` | `DropdownButtonFormField` senza `isExpanded: true`: sfora a destra (80-170 px a 320 px) | tutte, anche l'italiano |
| `pets_scaffold.dart:57` | riga del titolo della pagina "nuovo animale" sfora di 4-29 px | en, de, fr, es |
| `billing_page.dart` | le etichette dei piani usano `appL10n` globale: la pagina non si ridisegna se la lingua cambia mentre è aperta (oggi non può succedere: il selettore non è lì) | tutte |

Già segnalati in precedenza (non ricontrollati qui): `plan_intro_page.dart:112` riga senza `Expanded`; sottotitoli Layout/Località in
Impostazioni troncati; elenco completo nel rapporto dello stress test (`docs/i18n/STRESS_TEST_MULTILANG.md` sul ramo
`ml/revisione-e-legale-en`).

## 3. Strumento manuale: la matrice completa

Per la verifica approfondita (1.920 esecuzioni: 80 schermate × 2 viewport × 2 scale × lingua, con screenshot) esiste il materiale della
sessione coordinatrice in `side-session-notes/…/multilingua_coordinatrice/stress/`:

- `st_area2_tests/stress_*_test.dart` + `stress_harness.dart`: monta ogni pagina con dati finti e raccoglie overflow e testi tagliati in
  `results.jsonl`; `tools/prepare_fonts.sh` prepara i font locali. **Non committare i font né modifiche a `pubspec.yaml`.**
- `st_area3_tests/a3_*_test.dart`: cambio lingua, persistenza, formati.
- Per aggiungere de/fr alle lingue provate, estendere `stressLanguages` in `stress_harness.dart` (oggi `it`, `en`, `es`).

Eseguire la matrice completa prima di una build candidata al rilascio, non a ogni modifica.

## 4. Checklist manuale per ogni lingua (su dispositivo o emulatore)

Con un account di prova e dati finti, per ogni lingua/variante:

1. Primo avvio da telefono con quella lingua e paese: la variante proposta è giusta, oppure viene chiesta (mai en-GB di default).
2. Registrazione, accesso, recupero password: testi, errori, email ricevuta nella lingua (`supabase/email_templates/README.md`).
3. Nuovo animale: data di nascita digitata nel formato del paese (hint e validazione coerenti), peso nell'unità del paese, specie.
4. Promemoria: data digitata, notifica ricevuta nella lingua, orario.
5. Cartella clinica: carica un PDF, consenso all'assistente.
6. Chat: domanda semplice, domanda di urgenza (risposta che rimanda al veterinario), badge "generato dall'IA".
7. Passeggiata: avvio, notifica persistente nella lingua, distanza in km o miglia come previsto, foto.
8. Servizi vicini e indirizzo: modulo indirizzo (ordine CAP/città del paese, esempio di CAP nel campo), mappa che si apre nel paese giusto.
9. Piani: valuta del paese (`£ $ A$ € CHF`), nessun importo inventato.
10. Impostazioni → Lingua: cambio a caldo senza perdere lo stato; en-AU → Español → English torna en-AU.
11. Rotazione e dimensione carattere di sistema grande: nessun testo tagliato nelle schermate sopra.
12. Nessun testo italiano residuo (cercare a occhio titoli, errori, notifiche, widget della home Android).
13. Widget e notifica di passeggiata Android: lingua giusta dopo un cambio lingua.

Esito atteso: tutte le righe spuntate per la lingua, oppure un elenco di difetti con schermata.
