# Revisione veterinaria dei passi d'urgenza

Da far rivedere a un veterinario per piccoli animali ed esotici. La chat li usa come
istruzioni vincolanti nelle urgenze e, se il modello non risponde, li mostra così come sono.
Non sono ancora stati rivisti da un veterinario.

Per ogni riga indicare: va bene, oppure come va scritta. Se un consiglio non vale per tutti i
casi del gruppo, scrivere il caso. Ogni gruppo può avere il proprio testo.

## Da valutare per primi

1. **"Al caldo"** nel gruppo A vale anche per blocco urinario, torsione gastrica, gengive
   bianche e sostanze tossiche. È corretto?
2. **"Evita acqua in eccesso"** nel gruppo A, anche per chi ha sete intensa. È corretto?
3. **"Evita cibo"** nei gruppi A e B, anche per cuccioli o sospetta ipoglicemia. È corretto?
4. **"Al caldo, al buio"** nel gruppo B per un rettile o per un animale che fatica a respirare.
   È corretto?

## I testi

| Gruppo | Quando si usa | Passi |
|---|---|---|
| A | Cane e gatto senza passi propri: blocco urinario, torsione, gengive bianche, sanguinamento, respiro, collasso, sostanze tossiche già assunte | Contatta subito il veterinario o un pronto soccorso veterinario. Tieni l'animale calmo, al caldo e al sicuro. Evita cibo, acqua in eccesso o farmaci senza indicazione del veterinario. |
| B | Uccelli, piccoli mammiferi e rettili senza passi propri | Veterinario esperto in esotici o pronto soccorso. Tieni l'animale al caldo, al buio e in un posto tranquillo, senza maneggiarlo più del necessario. Evita cibo, acqua forzata o farmaci senza indicazione del veterinario. |
| C | Il proprietario parla di caldo, corsa o sole, senza colpo di calore evidente | Veterinario o pronto soccorso. Posto fresco, all'ombra e tranquillo, senza coperte. Evita cibo, acqua in eccesso o farmaci senza indicazione. |
| D | Coniglio o roditore che non mangia | Veterinario esperto in esotici o pronto soccorso: l'intestino di questi animali non può fermarsi, e dopo poche ore senza mangiare peggiora in fretta. Fieno e acqua a disposizione senza forzare, al caldo e tranquillo. Niente farmaci né rimedi casalinghi. |
| E | Colpo di calore | Ombra o posto fresco e ventilato, poi parti verso il veterinario. Bagna con acqua fresca non ghiacciata su pancia, inguine, ascelle e zampe, fai aria, niente coperte né asciugamani bagnati addosso. Se è cosciente, acqua a piccoli sorsi senza forzare. In auto, aria condizionata o finestrini aperti. |
| F | Morso di vipera | Veterinario subito, telefonando mentre parti. Il più fermo possibile, in braccio o nel trasportino, niente corsa. Niente lacci, incisioni, suzione del veleno, ghiaccio o farmaci. Lava solo con acqua e togli il collare, perché la zona si gonfia. |
| G | Processionaria | Veterinario subito: i peli continuano a danneggiare per ore e la gola può gonfiarsi. Con i guanti, sciacqua bocca e lingua con tanta acqua fresca o fisiologica, senza strofinare. Non toccare i bruchi a mani nude, niente latte né farmaci. |
| H | Convulsioni | Crisi da far vedere al veterinario oggi; oltre 5 minuti, o un'altra senza ripresa, pronto soccorso. Durante la crisi niente mani in bocca, sposta gli oggetti, abbassa luci e rumori, non tenerlo fermo. Guarda l'ora, annota durata e cosa fa, lascia che si riprenda. |
| I | Uccello che respira a becco aperto | Veterinario esperto in uccelli: è un segno tardivo e serio. Posto fresco, in penombra, silenzio, niente correnti né sole, non prenderlo in mano se non per il trasporto. Trasportino coperto con un panno leggero, niente cibo forzato né farmaci. |
| L | Pesci in difficoltà | Più ossigeno: aeratore, filtro verso la superficie, togli il coperchio. Cambia subito il 30-40% dell'acqua, alla stessa temperatura, con biocondizionatore; non dare da mangiare oggi. Misura ammoniaca, nitriti e temperatura; se sono alti ripeti il cambio domani. Se non migliorano in poche ore, veterinario esperto in pesci o negozio serio, con i valori. |

Anche i testi sui singoli veleni e farmaci sono da rivedere: `packages/core/domain/safety/human_drug_toxicity.py`.
