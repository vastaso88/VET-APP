# Passi d'urgenza: testi e fonti

La chat usa questi passi come istruzioni vincolanti nelle urgenze e, se il modello non
risponde, li mostra così come sono. Il proprietario li ha approvati così come sono l'8
novembre 2026. **Il 17/11/2026 sono state tolte le frasi senza fonte o contraddette dalle
fonti**, secondo lo studio `docs/product/20_urgenze_fonti_letteratura.md` §9 (nella
tabella sotto, "Tolto il 17/11").

**Decisione del proprietario (17/11/2026): non ci sarà una revisione veterinaria.** Quokka
non è un'app veterinaria. Ogni gesto specifico per specie deve poggiare su una fonte
pubblicata (linee guida, manuali di riferimento, articoli con revisione dei pari); lo studio
delle fonti lo prepara la sessione "Manuale". Un gesto senza fonte va tolto o ridotto ai passi
universali sicuri: calma, niente cibo, farmaci o acqua forzati, veterinario o pronto soccorso
subito. I testi in tedesco e francese richiedono solo una revisione linguistica.

## Stato delle fonti

| Gruppi | Stato |
|---|---|
| A, B, C, D, E, F, G, H, I, L, N, O, P, Q, R, S | **Confrontati con il doc 20 il 17/11/2026**: tolte le frasi senza fonte o contraddette; aggiunta solo la soglia confermata delle convulsioni (H). Le frasi rimaste che il doc 20 dà come "silenzio" (penombra, gesti durante la crisi) restano come passi universali. |
| T | Confermato dal doc 20 (aria pulita, veterinario adesso). Il doc 20 suggerisce di aggiungere "niente spray o aerosol vicino a lui": aggiunta, non fatta. |
| M e la domanda di chiarimento sul sanguinamento lieve | "Premi con un panno pulito" **senza fonte leggibile** (RECOVER 2026 non consultabile): **decisione del proprietario in sospeso**, testo invariato. |
| Testi su veleni e farmaci (`packages/core/domain/safety/human_drug_toxicity.py`) | Da collegare alle fonti dello stesso studio. |

## Domande aperte per lo studio delle fonti

1. **Temperatura** (risposta del doc 20): nessuna fonte su caldo o freddo per un adulto in
   collasso, né per scaldare a casa un uccello o un piccolo mammifero. Dal 17/11/2026 A, B e
   D non parlano più di temperatura (né "al caldo" né "non scaldarlo"). Resta aperto: i
   **neonati freddi** (cuccioli e gattini), per cui il doc 20 trova "scaldalo piano e non
   dargli da mangiare" (livello allevatore): sarebbe un'aggiunta, non fatta il 17/11.
2. **"Evita acqua in eccesso"**: contraddetto dal comunicato Defra sul caldo; tolto da A e C
   il 17/11/2026.
3. **"Evita cibo"** nel gruppo A: il doc 20 lo conferma solo per i neonati freddi; resta come
   passo universale.
4. **Gruppi I, O, P**: dettagli senza fonte tolti il 17/11 (seconda passata, su indicazione dell'Orchestratore).
5. **Gruppi nuovi suggeriti dal doc 20** (coniglio con larve di mosca, coniglio che respira a
   bocca aperta, rettile con prolasso, neonati freddi, permetrina e gatto): non costruiti.

## I testi

| Gruppo | Quando si usa | Passi |
|---|---|---|
| A | Cane e gatto senza passi propri: torsione, gengive bianche, collasso, sostanze tossiche già assunte (sanguinamento, blocco urinario e respiro hanno ora i gruppi M, N, O) | Contatta subito il veterinario o un pronto soccorso veterinario. Tieni l'animale calmo, tranquillo e al sicuro (fino al 16/11/2026: "al caldo"). Evita cibo o farmaci senza indicazione del veterinario. *Tolto il 17/11: "acqua in eccesso" (contraddetto da Defra).* |
| B | Uccelli, piccoli mammiferi e rettili senza passi propri | Veterinario esperto in esotici o pronto soccorso. Lascia l'animale in un posto tranquillo e in penombra, senza maneggiarlo più del necessario. Non forzarlo a mangiare o a bere, niente farmaci senza indicazione del veterinario. *Tolto il 17/11: "nel suo ambiente alla temperatura di sempre, senza scaldarlo né raffreddarlo di tua iniziativa" (nessuna fonte; gli ospedali scaldano gli uccelli malati, ma non c'è un metodo per casa).* |
| C | Il proprietario parla di caldo, corsa o sole, senza colpo di calore evidente | Veterinario o pronto soccorso. Posto fresco, all'ombra e tranquillo, senza coperte. Evita cibo o farmaci senza indicazione. *Tolto il 17/11: "acqua in eccesso" (contraddetto da Defra).* |
| D | Coniglio o roditore che non mangia | Veterinario esperto in esotici o pronto soccorso: l'intestino di questi animali non può fermarsi. Fieno e acqua a disposizione senza forzare, in un posto tranquillo. Niente farmaci né rimedi casalinghi. *Tolto il 17/11: "dopo poche ore senza mangiare peggiora in fretta" e "al caldo" (nessuna fonte; la guida scozzese sconsiglia le borse dell'acqua calda).* |
| E | Colpo di calore | Chiama subito il veterinario o un pronto soccorso: il colpo di calore è un'emergenza. Ombra o posto fresco e ventilato, bagna con acqua fresca non ghiacciata su pancia, inguine, ascelle e zampe, fai aria, niente coperte né asciugamani bagnati addosso. Se è cosciente, acqua a piccoli sorsi senza forzare. In auto, aria condizionata o finestrini aperti. *Tolto il 17/11: l'ordine "ombra, poi parti" e "uccide in fretta". La fonte sull'ordine ("raffredda prima del viaggio", Vet-COT 2016) è letta solo di seconda mano: finché nessuno la legge di prima mano, il testo non dà un ordine.* |
| F | Morso di vipera | Veterinario subito, telefonando mentre parti. Il più fermo possibile, in braccio o nel trasportino, niente corsa. Niente lacci, incisioni, suzione del veleno o farmaci. *Tolto il 17/11: ghiaccio, lavaggio con acqua, togliere il collare (nessuna fonte).* |
| G | Processionaria | Veterinario subito: i peli continuano a danneggiare per ore e la gola può gonfiarsi. Non strofinare muso, bocca e lingua: strofinare rompe i peli e li spinge più a fondo. Non toccare i bruchi a mani nude, niente latte né farmaci. *Tolto il 17/11: sciacquare bocca e lingua con acqua o fisiologica (nessuna fonte per gli animali).* |
| H | Convulsioni | Crisi da far vedere al veterinario oggi; oltre 5 minuti, o un'altra senza ripresa, **o due o più nelle 24 ore** (aggiunto il 17/11, confermato dal doc 20), pronto soccorso. Durante la crisi niente mani in bocca, sposta gli oggetti, abbassa luci e rumori, non tenerlo fermo. Guarda l'ora, annota durata e cosa fa, lascia che si riprenda. *Tolto il 17/11: niente. Senza fonte ma rimasti: "veterinario oggi" per una crisi singola e i gesti durante la crisi (il doc 20 li segnala come silenzio).* |
| I | Uccello che respira a becco aperto | Veterinario esperto in uccelli: è un segno tardivo e serio. Posto fresco, in penombra e silenzioso, senza sole diretto, non prenderlo in mano se non per il trasporto. Trasportino, niente cibo forzato né farmaci. *Tolto il 17/11: "niente correnti" e "trasportino coperto con un panno leggero" (nessuna fonte). "Posto fresco" resta: il doc 20 lo sostiene quando la stanza è calda.* |
| L | Pesci in difficoltà | Più ossigeno: aeratore. Cambia subito una parte dell'acqua, non tutta, alla stessa temperatura, con biocondizionatore; non dare da mangiare oggi. Misura ammoniaca, nitriti e temperatura; se sono alti ripeti il cambio domani. Se non migliorano, veterinario esperto in pesci o negozio serio, con i valori. *Tolto il 17/11: filtro verso la superficie, togliere il coperchio, "30-40%", "in poche ore" (nessuna fonte).* |
| M | Cane e gatto che sanguinano (dal 16/11/2026) | Premi subito sulla ferita con una garza o un panno pulito, pressione ferma e costante per almeno 5 minuti, senza sollevarlo; se si inzuppa, aggiungine un altro sopra. Chiama il veterinario e parti: sangue a fiotti o che non si ferma con la pressione è un'emergenza. Fai muovere l'animale il meno possibile; niente lacci stretti, polveri, creme o disinfettanti nella ferita, niente farmaci. |
| N | Cane e gatto che si sforzano e fanno poche gocce o niente (dal 16/11/2026) | Chiama subito il veterinario e parti: soprattutto un gatto maschio può avere le vie urinarie bloccate, ed è pericoloso per la vita. Non aspettare per vedere se ci riesce. Nel trasportino, con calma; niente farmaci né rimedi casalinghi. *Tolto il 17/11: "in poche ore" e "non premere sulla pancia" (nessuna fonte).* |
| O | Cane e gatto che respirano male (dal 16/11/2026) | Chiama subito il veterinario e parti: respiro difficile a riposo o a bocca aperta va visto adesso. Posto fresco, ventilato e tranquillo, non prenderlo in braccio se non serve. Trasportino o la posizione che preferisce, aria fresca; niente cibo né farmaci. *Tolto il 17/11: "collare allentato" (nessuna fonte). Senza fonte ma rimasti: posto fresco e ventilato (il doc 20 li segnala come silenzio).* |
| P | Esotici (uccelli, piccoli mammiferi, rettili) quando il proprietario parla di caldo o di colpo di calore (dal 16/11/2026, giro 3) | Veterinario esperto in esotici o pronto soccorso: molti piccoli animali soffrono il caldo e peggiorano in fretta. Nel punto più fresco della casa, all'ombra, aria che circola. Acqua fresca a disposizione senza forzare, niente farmaci. *Tolto il 17/11: "senza correnti dirette", "togli coperture o tessuti dalla gabbia", "niente ghiaccio né acqua gelata addosso" (nessuna fonte).* |
| Q | Axolotl, qualunque urgenza (dal 16/11/2026) | Veterinario esperto in esotici (anfibi). Non scaldare la vasca: vive in acqua fresca (confermato dal doc 20). Se l'acqua è più calda del solito, abbassala piano, senza sbalzi, con la vasca lontano da sole e calore; luce bassa, niente maneggiamenti. Niente farmaci o prodotti nell'acqua, niente cibo forzato. *Tolto il 17/11: "nell'arco di ore", bottiglie, ghiaccio, "niente sale" (nessuna fonte; nessuna fonte sconsiglia il sale).* |
| R | Uccello che sanguina, anche penna in crescita (dal 16/11/2026) | Veterinario per uccelli e parti: anche poco sangue conta, la penna in crescita rotta va fatta vedere. Intanto posto tranquillo in penombra; niente creme, disinfettanti o farmaci. *Tolto il 17/11: premere con garza o panno, polvere emostatica, tenerlo in un panno senza stringere il petto (nessuna fonte; sulla penna rotta i pareri sono divisi).* |
| S | Altri esotici che sanguinano (dal 16/11/2026) | Veterinario per esotici e parti: negli animali piccoli anche poco sangue conta. Posto tranquillo, maneggiare il meno possibile; niente creme, polveri o disinfettanti nella ferita, niente farmaci. *Tolto il 17/11: premere con garza o panno (nessuna fonte; sbagliato per gli anfibi, la cui pelle si tocca solo bagnata).* |
| T | Uccello in difficoltà dopo fumi (padella antiaderente, fumo) (dal 16/11/2026) | Subito fuori dalla stanza dei fumi, in un locale con aria pulita, finestre aperte; spegni il fornello e allontana la padella. Veterinario per uccelli e parti: i fumi di una padella antiaderente surriscaldata sono pericolosi anche in poco tempo, il respiro difficile è un segno serio. Lontano dai fumi, posto tranquillo in penombra, maneggiarlo solo per il trasporto; niente cibo forzato né farmaci. |

Dal 16/11/2026 (giro 3) anche la domanda di chiarimento sul respiro comincia con un gesto: "Intanto lascialo tranquillo in un posto fresco e ben aerato, lontano da fumi, spray o fornelli, senza agitarlo." E non scatta più se il proprietario non parla di respiro. Da collegare alle fonti insieme ai gruppi I e O.

Dal 16/11/2026 anche la domanda di chiarimento per un sanguinamento lieve comincia con il gesto: "Intanto premi sulla ferita con una garza o un panno pulito, fermo e senza sollevarlo, per qualche minuto." Da collegare alle fonti insieme al gruppo M.

Il nome del file resta `12_revisione_veterinaria_urgenze.md` per non rompere i rimandi da altri documenti e dal codice.
