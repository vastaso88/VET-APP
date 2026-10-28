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
| PR | Aperte verso MULTILANG | #15 flavor Android (superata da #17, che li contiene già: chiudere o unire per prima) · #16 revisione + stress test + piano + legali UK/US/AU · #17 allineamento main→MULTILANG (conflitti risolti) · #18 legali DE/AT/CH · #19 traduzione FR (con fr-BE/fr-CH) · #20 traduzione DE (con de-AT/de-CH) · #21 integrazione DE+FR sopra #17 · #22 legale ES · #23 legale FR/BE/CH-fr (dipende da #18) |
| 1-3 | Legale EN-UK / EN-US / EN-AU | **Bozze consegnate** (8 file ciascuna), in PR #16 |
| 4 | Traduzione DE | **Consegnata** (1.355 chiavi, `values-de`, backend `de` dietro, test, `STRESS_TEST_DE.md`); registro **Sie** (decisione Orchestratore); PR #20 |
| 5 | Traduzione FR | **Consegnata** (1.355 chiavi, `values-fr`, varianti fr-BE/fr-CH, `STRESS_TEST_FR.md`, `FRENCH_BACKEND_WIRING.md`); registro **vous**; PR #19 |
| 6 | Legale DE (DE/AT/CH) | **Bozze consegnate** (24 file), in PR #18 |
| 7 | Legale FR (FR/BE/CH romanda) | **Bozze consegnate** (24 file: `fr`, `be`, `ch-fr`; `ch-fr` rimanda a `docs/compliance/ch/` della PR #18: unire #18 prima); PR #23 |
| 8 | Legale ES (Spagna + nota America Latina) | **Bozze consegnate** (9 file, testi in «usted»); PR #22 (nota tú/usted in un secondo commit) |
| 9 | Mappe per paese | Card proposta all'utente |
| 10 | Notizie, eventi, Mercatino per territorio | Card proposta all'utente |
| 11 | Formati e store | Card proposta all'utente (parte da `ml/sync-de-fr`) |

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

## Ordine di merge consigliato (aggiornato 2026-10-14)

**#17 → #21 → #16 → #18 → #23 → #22** (#15, #19 e #20 sono contenute in #17 e #21). La #21 mette già insieme tedesco e francese sopra la #17, con i conflitti risolti.

## Decisioni di prodotto emerse dalle sessioni legali (da confermare dal proprietario)

1. **Mercatino senza animali, in tutti i paesi** (deciso dal proprietario il 2026-10-26; prima era una regola per Germania/Austria/Svizzera, Francia/Belgio e Spagna per le norme locali sulla vendita di animali): vale ovunque, oltre al raggio obbligatorio.
2. **Linea dell'assistente senza diagnosi né prescrizioni**: in Francia la telemedicina veterinaria non ha base legale (Ordre des vétérinaires, 2023) e il consiglio personalizzato rischia l'esercizio abusivo; in DE/ES la telemedicina veterinaria è da verificare. Proposta: informazioni generali e triage, mai diagnosi/prescrizione, in tutti i paesi.
3. **Registro legale**: spagnolo legale in «usted» e interfaccia in «tú»; tedesco in «Sie»; francese in «vous».
4. **Consensi**: il testo legale segue la REGIONE (mai ripiego silenzioso fr-BE/fr-CH→fr-FR o es-XX→es-ES); versione propria v1 e locale mostrata salvata.
5. **Bottone di recesso/disdetta** (obbligo UE): DE dal 19/06/2026, FR dal 19/06/2026, BE dal 14/08/2026, AT dal 01/10/2026 (date da verificare con il legale locale).
6. **Groq e Data Privacy Framework**: Groq non risulta nel DPF; servono SCC o altra base per i trasferimenti verso gli USA (tutte le regioni UE/UK/CH).
7. **Titolare, DPO e mediatore del consumo**: dati da fornire per le informative (domanda comune a tutte le regioni).
