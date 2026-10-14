# Piano multilingua — estensioni su MULTILANG

Coordinatrice: sessione "Multilingua: estensioni su MULTILANG". Ultimo aggiornamento: 2026-10-13.

## Decisioni del proprietario (2026-10-13)

- `origin/MULTILANG` (erykwest) è l'unico ramo multilingua; il nostro ramo `multilingua` viene cancellato.
- Noi aggiungiamo ciò che manca; il lavoro va su rami `ml/<tema>` creati da MULTILANG, con PR verso MULTILANG. Mai in main.
- Inglese = una sola traduzione con bandiere UK / USA / AU.
- Legale: una ricerca per ogni regione (UK, USA, Australia; DE, FR, ES).
- Luoghi dei nuovi paesi dalle fonti aperte già usate (Overture, OSM).
- Mercatino con raggio in km obbligatorio (niente ricerca mondiale). Notizie ed eventi solo del territorio dell'utente.
- Numero build: contatore unico condiviso (prossima 31); non toccare `pubspec`.

## Stato

| # | Tema | Stato |
|---|------|-------|
| 0 | Revisione di MULTILANG | **Fatta** → `REVISIONE_MULTILANG.md` (1 bloccante, 10 alti), messaggio per erykwest inviato |
| 0b | Stress test it/en/es | **Fatto** → `STRESS_TEST_MULTILANG.md` (+ 1.440 screenshot in side-session-notes) |
| PR | Aperte verso MULTILANG | #15 flavor Android (superata da #17, che li contiene già: chiudere o unire per prima) · #16 revisione + stress test + piano + legali UK/US/AU · #17 allineamento main→MULTILANG (conflitti risolti) · #18 legali DE/AT/CH · #19 traduzione FR (con fr-BE/fr-CH) · #20 traduzione DE (con de-AT/de-CH) |
| 1-3 | Legale EN-UK / EN-US / EN-AU | **Bozze consegnate** (8 file ciascuna), in PR #16 |
| 4 | Traduzione DE | **Consegnata** (1.355 chiavi, `values-de`, backend `de` dietro, test, `STRESS_TEST_DE.md`); registro **Sie** (decisione Orchestratore); PR #20 |
| 5 | Traduzione FR | **Consegnata** (1.355 chiavi, `values-fr`, varianti fr-BE/fr-CH, `STRESS_TEST_FR.md`, `FRENCH_BACKEND_WIRING.md`); registro **vous**; PR #19 |
| 6 | Legale DE (DE/AT/CH) | **Bozze consegnate** (24 file), in PR #18 |
| 7-8 | Legale FR / ES | Card proposte all'utente (Francia/Belgio/Svizzera romanda; Spagna + nota America Latina) |
| 9 | Mappe per paese | Da proporre |
| 10 | Notizie, eventi, Mercatino per territorio | Da proporre |
| 11 | Formati e store | Da proporre |

### Note di integrazione DE + FR (verificate 2026-10-14)

- Verifica indipendente: `check_i18n`, `auto_translate check`, pytest (DE 964, FR 962 passati), ruff check ok; ARB DE e FR con 1.355 chiavi e 189 metadata come l'italiano, nessuna chiave vuota o non tradotta, placeholder e plurali coerenti. Un solo test Flutter rosso, già presente su MULTILANG (`language_choice_test`, punto 12).
- **Conflitti tra le PR**: DE e FR toccano gli stessi punti (`auto_translate.py` `DEEPL_TARGETS`, `AppLanguageContext.kt`, `app_language.dart`, `billing_page.dart`, `check_i18n.py`, `test_native_localizations.py`, `app_localizations.dart` generato) e DE tocca anche file della chat (`chat_orchestrator.py`, `localization.py`…) già modificati dalla PR #17. Ordine consigliato: #17 → DE → FR (rigenerare i file `gen-l10n` dopo ogni merge), conflitti risolti da questa sessione.
- **Paese predefinito**: FR ha introdotto `regional_defaults.dart` (`appHomeCountryDefault`, `appNumericDatePattern`) con varianti fr-BE/fr-CH; DE usa ancora "Italien" (`settingsHomeCountryDefault`) e la data numerica `dd.MM.yyyy` dal pattern ARB. Dopo il merge di FR va esteso a DE/AT/CH (e a UK/US/AU).
- **Backend**: `response_locale` e `/account/preferences` accettano solo it/en/es: finché erykwest non estende il `Literal` (punto 8) DE e FR danno 422. I testi `de` del backend sono pronti; quelli `fr` sono in `localization_fr.py`, non collegati (vedi `FRENCH_BACKEND_WIRING.md`).
- **Consensi legali** per DE/FR: da collegare alle bozze delle sessioni legali (ancora fallback italiano in `account_consent_text.py`).

## Risposte dell'Orchestratore (2026-10-13, opzioni consigliate; il proprietario può correggere)

1. Worktree su `origin/MULTILANG`: via gestore git (non lo chiede questa sessione: il blocco dei permessi è su di lei).
2. Correzioni ai bloccanti/alti: le fa erykwest sul suo ramo (messaggio inviato all'Orchestratore).
3. Valuta per paese (£, $, A$, €), anche nei piani/abbonamenti.
4. Inglese neutro, britannico dove serve; data e misure per paese.
5. Data `mm/dd/yyyy` per gli USA.
6. Paese precompilato dedotto dal dispositivo, modificabile.
7. Consensi: versione propria v1 per lingua/regione e lingua mostrata salvata.
8. Ogni testo legale resta **bozza** finché non lo rivede un legale locale: scriverlo in testa a ogni documento.

## Domande per il proprietario (storico, già risposte sopra)

**Procedura**
1. Autorizzi (o fai fare al gestore git) il passaggio del worktree di questa sessione su `origin/MULTILANG`?
2. Le correzioni ai problemi bloccanti/alti di `REVISIONE_MULTILANG.md` le fa erykwest sul suo ramo
   (consigliato: ce le passa l'Orchestratore), oppure le facciamo noi su `ml/fix-backend-multilang` con PR verso MULTILANG?

**Prodotto**
3. Valuta nel Mercatino: "Price in €" va sostituita per paese (£, $, A$, €)? (consigliato: sì)
4. Ortografia inglese unica: britannica o americana? (consigliato: neutra dove possibile, altrimenti britannica con data/misure per paese)
5. Data: il campo "dd/mm/yyyy" deve seguire il paese (USA mm/dd/yyyy)? (consigliato: sì)
6. Paese precompilato in Impostazioni ("Italia"/"Italy"): vuoto o dedotto dal paese del dispositivo? (consigliato: dedotto)

**Legale**
7. I consensi EN/ES oggi usano le stesse versioni dell'italiano: confermi che per ogni lingua/regione si parte da una versione propria (v1) e si salva la lingua mostrata? (consigliato: sì)
8. I testi legali prodotti dalle sessioni sono bozze: serve comunque un controllo di un legale locale prima della pubblicazione.

## Decisione sul registro (2026-10-14)

Tedesco in **Sie** (formale), come da brief dell'Orchestratore; passare a "du" costerebbe una passata su ~270 testi (e sul backend). Possibile rifinitura futura. Francese in **vous**. Varianti bandiera: fr-BE / fr-CH (stessa traduzione fr), de-AT / de-CH (stessa traduzione de); paese predefinito dedotto dal dispositivo.

## Ordine di merge consigliato (2026-10-14)

#17 allineamento (contiene anche i flavor di #15) → #20 DE → #19 FR → #16 documenti → #18 legali DACH. Per evitare conflitti manuali a erykwest è in preparazione il ramo di integrazione `ml/sync-de-fr` (#20 e #19 applicati sopra #17, `gen-l10n` rigenerato): si può prendere quello dopo il merge di #17, o usarlo come guida.
