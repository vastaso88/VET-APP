# Italia — testi legali pubblicabili (sito quokka.pet)

Bozze dei tre testi che Google Play chiede su un sito pubblico, più le domande al proprietario. Sono scritti per essere pubblicati così come sono, **dopo** aver riempito i segnaposto e aver fatto rivedere i punti ⚖️ da un legale italiano.

| File | Cosa è |
|---|---|
| `02_informativa_privacy_it.md` | Informativa sulla privacy (artt. 13–14 GDPR), v2 dell'8 novembre 2026: allineata al codice del 2026-10-28, più Anthropic, registro dei dispositivi, messaggi del Mercatino, età minima e conservazione per chi non rinnova (le parti non ancora nel codice sono marcate «in attesa del codice») |
| `03_termini_di_servizio_it.md` | Termini di servizio v2: senza piano Free, età minima, Mercatino con messaggi e divieto di farmaci («solo oggetti per animali, nessun animale in nessun paese»), conservazione per chi non rinnova |
| `04_pagina_assistenza_it.md` | Pagina di assistenza: contatti, domande frequenti, come eliminare l'account, come segnalare |
| `08_domande_per_proprietario.md` | Le domande a cui deve rispondere il proprietario per riempire i segnaposto, con la colonna «Quando» (prima del test o del lancio) |
| `../10_pareri_dal_2026_11_06.md` | I pareri dietro la v2: quali domande servono prima del test chiuso, età minima, Anthropic, messaggi del Mercatino, conservazione per chi non rinnova |

**Segnaposto.** `[NOME_IN_MAIUSCOLO]` è un dato che deve fornire il proprietario; `[da verificare: …]` e `[da decidere: …]` sono controlli prima della pubblicazione; `[in attesa del codice: …]` descrive una funzione che il codice non ha ancora. Non pubblicare finché questo comando restituisce qualcosa:

```bash
grep -nE "\[[A-Z][A-Z_]+\]|\[(da (verificare|decidere|confermare)|in attesa)" docs/compliance/it/0[234]_*.md
```

(Le «Note per il revisore» in fondo a ogni file vanno tolte alla pubblicazione.)

**Rapporto con il resto.** Nell'app il catalogo dei consensi (`packages/core/domain/consent/account_consent_text.py`) contiene solo le frasi brevi e versionate, che rimandano a questi testi. L'informativa lunga non ha una versione di consenso a sé: alla pubblicazione si aggiorna la frase «L'informativa completa è in preparazione» con un collegamento e si passa alla versione successiva del consenso «Privacy». La base di partenza è `../09_informativa_privacy_bozza.md`; le bozze per paese (`../de`, `../uk`, …) seguono la stessa struttura.

**Nome.** Quokka è il nome provvisorio del prodotto (ricerca di anteriorità del marchio in corso): vedi `../README.md`.

**Dati personali del proprietario.** Non vanno nel repository: titolare, sede, codice fiscale e indirizzi si inseriscono solo nel testo pubblicato.
