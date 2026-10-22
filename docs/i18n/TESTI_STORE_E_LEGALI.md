# Testi di store, legali ed e-mail: dove stanno, chi li aggiorna

Questi testi **non** passano dalle bozze DeepL: hanno un autore, una revisione umana (nei casi legali, un legale) e controlli propri.
Vale sempre: *nessuna traduzione è un parere legale*; prima del rilascio pubblico serve la revisione di un madrelingua e, per i testi legali,
di un legale del paese.

| Testo | Dove sta | Chi lo aggiorna | Controllo automatico |
|---|---|---|---|
| **Schede store** (titolo, descrizione, novità, parole chiave) per `it`, `en-GB`, `en-US`, `en-AU`, `de`, `fr`, `es` | `docs/store/listings/<codice>.md` | chi cura il lancio (Orchestratore → sessione store/marketing); si aggiornano a ogni funzione visibile all'utente e a ogni cambio di nome | `uv run pytest tests/unit/test_store_listings.py`: lunghezze (titolo 30, breve 80, completa 4000…), lingue presenti, niente prezzi né funzioni non ancora pubbliche |
| **Screenshot e didascalie** per lingua e paese | `docs/store/02_screenshot_checklist.md` | stessi, a ogni cambio di grafica | manuale |
| **Dichiarazioni store** (età, privacy / Data safety, IA) | `docs/store/03_dichiarazioni_store.md` | stessi, con il legale; cambiano se cambiano dati raccolti o fornitori | manuale: sono blocchi alla pubblicazione |
| **Consensi account** (Termini, Informativa, marketing, analisi, regole dei contributi) in italiano, inglese, spagnolo | `packages/core/domain/consent/account_consent_text.py`, servito da `GET /legal/consents?lang=xx` | sessione "legale"; il testo italiano è la bozza di riferimento, le altre lingue la seguono fedelmente. **Ogni modifica di significato cambia la versione** (`CURRENT_VERSIONS`) e riapre il consenso agli utenti | `tests/unit/test_consent_texts_match_behaviour.py`; il test di copertura segnala che **tedesco e francese non hanno ancora il testo**: finché mancano, l'API serve l'italiano |
| **Consenso alla cartella clinica** (v3) | testo italiano in `packages/core/domain/medical_record/consent_text.py`; app: chiave `petsConsentFullText`; chat: `consent_request` in `localization.py` | sessione "legale" / "Cartella clinica"; cambia `CURRENT_VERSION` se cambia il significato | il test confronta italiano del backend, ARB e comportamento reale; le altre lingue sono traduzioni fedeli, da far rileggere |
| **Bozze legali per paese** (UK, USA, Australia; DACH; Spagna; Francia/Belgio/Svizzera romanda) | `docs/compliance/<lingua o paese>/` (una cartella per paese, dai rami `ml/legale-*`) | sessioni legali per lingua | solo documenti: nessun test; verifica a mano che il codice non prometta più del testo (`docs/compliance/08_punti_aperti_prima_del_lancio.md`) |
| **Monitoraggio normativo** | `docs/compliance/legislative-watch/` + workflow `legislative-watch.yml` | job schedulato, revisione umana | report in `reports/` |
| **E-mail di Supabase Auth** (conferma, recupero, cambio e-mail…) in cinque lingue | `supabase/email_templates/` (generate da `scripts/i18n/build_email_templates.py`) | chi cambia il testo modifica lo **script**, rigenera, poi **incolla nel dashboard** Supabase (nulla scrive da solo) | `python scripts/i18n/build_email_templates.py --check` |
| **Testi di sistema Android** (widget, notifica passeggiata) | `android/app/src/main/res/values*/strings.xml` | come la UI: bozze + revisione | `auto_translate.py check` (chiavi e formati `%`) |

## Regole per chi aggiorna

1. **Cambio di significato = nuova versione + nuovo consenso.** Mai riscrivere un testo legale lasciando lo stesso numero di versione.
2. **Italiano prima, poi le altre lingue nello stesso lavoro**; se una lingua non è pronta, si segnala come lacuna nota (come nel test di
   copertura) invece di lasciare un testo vecchio che sembra aggiornato.
3. **Una scheda store per lingua, non per paese** (`de` vale per DE/AT/CH, `fr` per FR/BE/CH); le differenze di paese stanno nella disponibilità per
   territorio e nelle dichiarazioni.
4. Le frasi sul trattamento dei dati (anonimizzazione, fornitori, conservazione) devono corrispondere a ciò che il codice fa **in quella lingua**:
   le regole di anonimizzazione sono scritte per l'italiano (`BACKEND_ITALIAN_CLASSIFIERS.md`); finché non sono estese, nelle schede non italiane si
   usa la formulazione più prudente indicata in `docs/store/README.md`.

## Cosa resta da decidere al proprietario

- Chi fa la revisione madrelingua e quella legale per ogni lingua (oggi nessuna è stata fatta da una persona).
- Testo dei consensi account in **tedesco e francese** (oggi serve l'italiano).
- Quali paesi aprire per primi: determina l'ordine di revisione.
