# Quando aggiungi una funzione: chiavi IT → bozze → revisione → test

Procedura breve per **ogni modifica che mostra un testo all'utente** (schermata, messaggio, notifica, errore, risposta fissa del backend).
L'italiano è la sorgente: si scrive solo lì, il resto segue. Lingue oggi: `it` (sorgente), `en` (UK/US/AU), `es`, `de` (DE/AT/CH), `fr` (FR/BE/CH).

## I quattro passi

1. **Chiavi IT.** Scrivi i testi in `apps/mobile_app/lib/l10n/app_it.arb` (UI), `packages/core/domain/localization.py` (messaggi fissi del
   backend, con tutte le lingue della chiave), `android/app/src/main/res/values/strings.xml` (testi nativi).
   Una chiave = una frase intera, con segnaposto e plurali ICU; mai testo italiano scritto nel codice. Se la funzione ha un nome, controlla il
   **glossario** (`GLOSSARIO_E_STILE.md`) e, se è nuovo, aggiungilo a `docs/i18n/glossary.json` con le chiavi che sono l'etichetta intera.
2. **Bozze.** Le altre lingue partono da una bozza, mai vuote:
   - *automatica*: il workflow `Translation drafts from Italian` parte da solo sul push (o a mano da Actions), manda a DeepL solo testi del
     repository con glossario e registro giusto (es "tú", de "Sie", fr "vous") e produce l'artifact `translation-drafts-<commit>` con
     `TRANSLATION_REVIEW.md` (elenco **da rivedere**, con i termini del glossario mancanti) e `TRANSLATION_REVIEW.json`;
   - *a mano o con una sessione Claude*: `python scripts/i18n/check_i18n.py --list-missing <lingua>` elenca le chiavi senza traduzione.
     Si traducono tutte le lingue nello stesso lavoro, rispettando glossario e guida di stile.
3. **Revisione.** Una persona rilegge ogni bozza (spuntando `TRANSLATION_REVIEW.md`). Si guarda con più cura: negazioni, testi clinici, triage,
   consensi, nomi delle funzioni, lunghezza (il tedesco si allunga). Il testo italiano ambiguo si corregge alla sorgente e si riparte dal passo 1.
   Poi: `python scripts/i18n/auto_translate.py acknowledge` e si committa il manifest (`docs/i18n/source_manifest.json`) con i cataloghi.
   `acknowledge` attesta che i testi sono stati *rivisti*: non si esegue per far passare il controllo.
4. **Test.** Prima di dire "fatto":

   ```bash
   make i18n-check                              # chiavi, segnaposto, testi non tradotti nel codice, glossario, traduzioni non obsolete
   uv run pytest                                # incluso il backend (tutte le lingue per ogni catalogo) e tests/unit/test_translation_system.py
   cd apps/mobile_app && flutter gen-l10n && flutter analyze && flutter test
   ```

   Se la schermata è nuova, aggiungila a `_pages` in `apps/mobile_app/test/language/language_qa_test.dart`: viene provata in tutte le lingue a
   320×568 (overflow, testo italiano rimasto) e in tedesco con testo di sistema ingrandito 1,5× e 2×.

La CI (job `flutter` e `quality` di `.github/workflows/ci.yml`) esegue gli stessi controlli e **fallisce** se manca una chiave in una lingua,
se un segnaposto non coincide, se una traduzione è obsoleta rispetto al sorgente, se un nome di funzione si discosta dal glossario o se un
layout sfora.

## Cosa non si traduce, cosa non si dimentica

- Non si traducono valori salvati/inviati al backend, nomi propri, parole dell'utente, elenchi di dati, testi del modello (vedi `README.md`).
- Una funzione che mostra **testi legali, consensi o schede store** ha anche un processo proprio: `TESTI_STORE_E_LEGALI.md`.
- Una funzione che cambia **dati per paese** (radar, eventi, notizie, Mercatino, unità, valuta) non scrive formati a mano: usa
  `regional_defaults.dart` / `date_formats.dart`.
- Una nuova **lingua** si aggiunge con la procedura di `README.md` ("Aggiungere una lingua") più: voce in `LANGUAGES` di
  `scripts/i18n/auto_translate.py` e `DEEPL_TARGETS`/`DEEPL_FORMALITY`, colonna nel glossario e nella guida di stile, catalogo in tutti i
  dizionari del backend (il test `test_every_backend_catalog_covers_every_supported_language` elenca ciò che manca).

## Testo da aggiungere al `CLAUDE.md` del progetto (proposta)

```markdown
## Testi e traduzioni (multilingua)
- Nessun testo per l'utente nel codice: UI in `apps/mobile_app/lib/l10n/app_it.arb` (sorgente), messaggi fissi del backend in
  `packages/core/domain/localization.py`, testi nativi in `android/.../values/strings.xml`.
- Ogni modifica di un testo italiano si porta dietro tutte le lingue (en, es, de, fr) nello stesso lavoro: bozza, revisione, `make i18n-check`.
  Procedura e controlli: `docs/i18n/NUOVE_FUNZIONI.md`. Termini e registro: `docs/i18n/glossary.json`, `docs/i18n/GLOSSARIO_E_STILE.md`.
- Mai scrivere a mano valute, formati di data, unità: usare `regional_defaults.dart` / `date_formats.dart`.
- Testi legali, consensi e schede store: `docs/i18n/TESTI_STORE_E_LEGALI.md` (revisione umana/legale obbligatoria).
- Prima di chiudere una funzione con UI: `make i18n-check && uv run pytest` e `flutter test` (inclusi i test di layout in tedesco).
```
