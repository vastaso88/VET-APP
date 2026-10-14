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
| 0c | PR di allineamento main → MULTILANG | **Aperta** [#17](https://github.com/vastaso88/VET-APP/pull/17) (conflitti risolti, specie per parola intera, CI con `--flavor prod`) |
| 1-3 | Legale EN-UK / EN-US / EN-AU | **Bozze consegnate** in `docs/compliance/uk|us|au/` (8 file ciascuna); da committare in PR |
| 4-5 | Traduzione DE / FR | In corso (sessioni `traduzione-de`, `traduzione-fr`); integrazione con il backend dopo la correzione del 422 |
| 6 | Legale DE (DE/AT/CH) | **Bozze consegnate** in `docs/compliance/de|at|ch/` (24 file, verificati: BOZZA in testa); PR `ml/legale-de` richiesta al gestore git |
| 7-8 | Legale FR / ES | Da proporre |
| 9 | Mappe per paese | Da proporre |
| 10 | Notizie, eventi, Mercatino per territorio | Da proporre |
| 11 | Formati e store | Da proporre |

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
