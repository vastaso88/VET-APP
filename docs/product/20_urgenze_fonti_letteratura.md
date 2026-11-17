# 20 - Urgenze: cosa dice la letteratura, gruppo per gruppo

Data: 2026-11-17. Sessione «Manuale», su richiesta dell'Orchestratore. Decisione del proprietario (17/11): **nessuna revisione veterinaria**, perché Quokka non è un'app veterinaria; il suo titolo non si usa mai come convalida. Quindi ogni gesto che la chat suggerisce in un'urgenza deve poggiare su una fonte pubblicata; dove la fonte manca o si contraddice, la chat dà **solo i passi universali**.

Questo documento è uno studio, non codice e non testo definitivo: dice, per ogni gruppo di animali, quali gesti hanno una fonte, quanto è solida la prova, e cosa va corretto nelle bozze di `docs/product/12_revisione_veterinaria_urgenze.md` (§6). Scritto per chi non è tecnico: i termini difficili sono spiegati qui sotto.

## 0. In breve

1. **Le fonti leggibili sono poche.** Le fonti che un veterinario consulterebbe per prime (MSD/Merck Veterinary Manual, linee guida RECOVER sul primo soccorso e sulla rianimazione, AAHA, BSAVA, AAV, i testi di medicina degli esotici) sono tutte **chiuse a una lettura automatica**: licenza che vieta la copia (CC BY-NC-ND), termini che vietano programmi e uso commerciale, o siti che bloccano i programmi. Per la regola della Normativa non si leggono (§1). Ho potuto usare guide di enti pubblici (governi di Regno Unito, Scozia e Galles), una società (WSAVA), articoli scientifici ad accesso aperto con licenza CC BY e qualche pagina divulgativa come sostegno.
2. **Dove una fonte c'è, spesso è indiretta**: indicazioni per i venditori di animali, uno studio su cani da lavoro, la descrizione di un solo gatto, la rassegna di un manuale vecchio. Il «livello di prova» di ogni gesto è scritto nelle tabelle (§3).
3. **Cosa ha una fonte decente**: caldo del cane (raffreddare *prima* di partire, non dopo), permetrina e gatto (lavare subito, veterinario subito), crisi convulsive del cane (5 minuti = pronto soccorso), vipera e processionaria (veterinario subito, non legare né incidere), coniglio che non mangia (emergenza), larve di mosca nel coniglio (veterinario subito), fumi di padella antiaderente negli uccelli (aria pulita, veterinario subito), axolotl (mai scaldare la vasca), acqua dell'acquario (cambio **parziale**, mai tutta l'acqua, biocondizionatore, niente medicine).
4. **Cosa non ha una fonte** (quindi solo passi universali): premere sul sanguinamento, rianimazione fatta dal proprietario, ipotermia e caldo per gli esotici, penna in crescita, convulsioni degli esotici, prolassi, ostruzione urinaria (gesti), avvelenamenti (gesti), uova trattenute, furetto (tutto), cavia/cincillà/criceto (tutto).
5. **Sei bozze di `docs/product/12` sono contraddette o non confermate** e vanno corrette (§6): in particolare l'ordine «raffredda e poi parti» per il colpo di calore (la fonte dice l'opposto), «al caldo» nel gruppo D, «sale» e «ghiaccio» per l'axolotl, il «30-40%» per i pesci, la polvere emostatica e la fasciatura del petto per gli uccelli, il «sciacqua la bocca» per la processionaria.

### Parole difficili

- **Colpo di calore**: il corpo si surriscalda e smette di funzionare; è un'emergenza.
- **Ipotermia**: il corpo è troppo freddo.
- **Stasi gastrointestinale** (coniglio, cavia): l'intestino rallenta o si ferma; l'animale smette di mangiare e fare feci; peggiora in fretta.
- **Torsione di stomaco (GDV)** nel cane: lo stomaco si gonfia e gira su sé stesso; pancia gonfia e conati senza vomito; chirurgia d'urgenza.
- **Ostruzione urinaria** del gatto maschio: l'uretra si blocca, non esce urina; pericolosa per la vita.
- **PTFE**: il rivestimento antiaderente di padelle e ferri da stiro; surriscaldato libera fumi tossici per gli uccelli.
- **Penna in crescita («blood feather»)**: penna giovane piena di sangue; se si rompe sanguina.
- **Prolasso**: un organo (intestino, ovidotto, organo genitale) esce dal corpo attraverso l'apertura.
- **Dispnea**: respiro difficile.
- **Termoregolatore esterno**: animale che non produce calore (rettili, anfibi, pesci); la temperatura dell'ambiente decide quella del corpo.
- **Ammoniaca e nitriti**: sostanze tossiche che si accumulano nell'acquario; devono essere zero.
- **Biocondizionatore**: prodotto che elimina cloro e cloramine dall'acqua del rubinetto.

### I passi universali (valgono sempre)

Sono quelli che la chat dà anche quando non c'è nessuna fonte: **chiama subito il veterinario o un pronto soccorso veterinario** (per gli esotici, uno che conosca la specie); **tieni l'animale calmo e muovilo il meno possibile; non forzare cibo, acqua o farmaci; non provocare il vomito; se ha ingerito qualcosa, porta la confezione o una foto dell'etichetta**. Solo gli ultimi due hanno una fonte (non provocare il vomito: per il gatto, caso clinico e rassegna; per gli uccelli, rassegna; la confezione: guida VMD sulla permetrina); gli altri sono prudenza generale, non una fonte: lo dico espressamente, come chiesto.

## 1. Come ho lavorato e cosa non ho potuto leggere

- **Cinque ricerche in parallelo** (cane e gatto; coniglio, cavia, cincillà, roditori e furetto; uccelli; rettili e anfibi; pesci), con le stesse regole: nessun dato a memoria; solo documenti aperti nella ricerca o i metadati bibliografici; **controllo in 4 punti** dell'ente che ospita ogni fonte (robots.txt, termini d'uso, segnali leggibili da macchina, avviso nel documento) prima di leggere; una fonte alla volta; copie cancellate; nessun testo copiato nei file.
- **Semaforo** (parere della Normativa, `compliance/13`): verde = licenza aperta (CC BY, OGL, dominio pubblico); giallo = diritti riservati senza riserve; rosso = riserva, uso commerciale vietato, NC/ND o sito che blocca i programmi. Le fonti rosse **non** sono state lette.
- **Non lette perché rosse** (da far leggere a una persona, se serve): MSD/Merck Veterinary Manual (permesso scritto per il riuso, avvertenza sui riassunti dell'IA, link trappola per i programmi); **RECOVER** (linee guida 2012, 2024 sulla rianimazione, **2026 sul primo soccorso**, 2025 sui neonati: tutte CC BY-NC-ND, e i termini del sito vietano programmi); Vet-COT 2016 (cure prima dell'ospedale: citato di seconda mano in un articolo aperto); AAHA, BSAVA, AAV, ARAV (guide ancora «in arrivo»), FAO, RSPCA, CCAC, RVC; due lavori sul furetto («Emergency medicine of the ferret», 2007; cateterizzazione del furetto maschio, 2011); manuali di rettili e anfibi (Mader) e di esotici.
- **Dove ho dovuto fare una scelta**: il sito **Europe PMC** ha nel `robots.txt` un segnale «ai-train=no» e blocca ClaudeBot; ho usato **solo l'interfaccia ufficiale ebi.ac.uk (REST)**, solo per articoli la cui riga di licenza dice CC BY, per leggere e non per addestrare. Il parere della Normativa (Appendice A.3) lo ammette per il sottoinsieme CC BY; la Normativa deve confermare che la via dell'interfaccia sia accettabile.
- **Limiti**: i riferimenti di pagina dei PDF sono approssimativi dove segnato; le citazioni sono state riassunte da sessioni di aiuto e **non hanno avuto un secondo controllo indipendente** su tutte le frasi (vedi §8).

### Livelli di prova (come li scrivo nelle tabelle)

| Sigla | Significato |
|---|---|
| **Linea guida** | testo di un ente pubblico o di una società scientifica (anche scritto per i venditori o per i veterinari) |
| **Studio** | articolo scientifico con revisione tra pari (descrive uno o più casi, una rassegna, un'indagine) |
| **Manuale** | rassegna o capitolo di manuale (nessuno leggibile: i manuali sono rossi) |
| **Esperienza clinica** | pareri di esperti senza dati |
| **Sostegno** | pagina divulgativa o di un ospedale, utile ma non una fonte |
| **Indiretto** | la fonte parla di un'altra specie o di un altro contesto |
| **Seconda mano** | la fonte è citata dentro un articolo che ho letto; il documento originale non l'ho aperto |

## 2. Cane e gatto

Fonti usate (elenco in §7): guida del governo britannico sulla permetrina (VMD, 2014); comunicato Defra sul caldo (2011); studi sul raffreddamento del cane (2023) e sul gatto (caso clinico, 2026); rassegne europee su zootossine (2024), vipera (2026), processionaria; indagine sui farmaci di emergenza nelle crisi (2023); studi su ostruzione urinaria, torsione di stomaco, dispnea del gatto; caso di perossido di idrogeno nel gatto (2019); rassegne sui neonati; pagine WSAVA e AAFP (permetrina).

### Colpo di calore (cane; gatto)

| Segno | Gesto | Fonte (livello) | Frase consigliata per la chat |
|---|---|---|---|
| Ansima molto e in fretta, tanta saliva, gengive scure, sguardo vitreo, collasso | **Inizia a raffreddarlo subito, prima del viaggio**: telefona al veterinario mentre lo fai | Studio sul raffreddamento 2023 (riporta la raccomandazione Vet-COT 2016, **seconda mano**); le indicazioni si basano soprattutto su studi sulle persone | «Inizia a raffreddarlo subito e telefona al veterinario mentre lo fai.» |
| Cane surriscaldato | Acqua fresca e aria in movimento (ventilatore, aria condizionata) o immersione; ghiaccio e acqua gelata sono discussi (un vecchio esperimento ne vide morire alcuni) | Studio 2023 (rassegna e confronto); studio su 12 cani da lavoro 2023 (l'acqua raffredda più dell'alcol sulle zampe) | «Bagna il pelo con acqua fresca del rubinetto, non ghiaccio, e fai aria con un ventilatore.» |
| Asciugamani bagnati | Sono il metodo casalingo più diffuso ma poco sostenuti; si usano al massimo sulle zone con poco pelo (pancia, interno coscia) perché un asciugamano su tutto il corpo blocca l'aria | Studio 2023 (opinioni di esperti, nessuno studio sui cani) | «Non avvolgerlo in asciugamani bagnati: bagna pancia e interno coscia e usa un ventilatore.» |
| Sveglio | Acqua da bere | Comunicato Defra 2011 (sostegno, vecchio) | «Se è sveglio e ne vuole, acqua fresca a piccoli sorsi, senza forzarlo.» |
| Rischi del raffreddamento | Non mettere la testa sott'acqua (rischio di respirare acqua nei cani svenuti o a muso corto); troppo freddo fa male quanto troppo caldo | Studio 2023 | «Non mettergli la testa sott'acqua.» |
| Gatto | Un caso: la temperatura scese da 43 a 35 gradi in 20 minuti di raffreddamento attivo; i gatti perdono calore in fretta | Studio: un solo caso, 2026 (prova debole) | «Con un gatto raffredda con delicatezza e per poco: si raffredda troppo in fretta.» (bassa prova: facoltativa) |

**Cosa non fare**: ghiaccio o acqua gelata (contestati); asciugamani bagnati avvolti addosso; testa sott'acqua. **Dove le fonti mancano o si contraddicono**: nessuna fonte dà un criterio per smettere senza termometro (la soglia di 41,1 gradi è citata di seconda mano e l'articolo stesso dice che non ha fonte); aria condizionata in auto: nessuna fonte. La chat deve dire «smetti quando è più calmo e non più caldo al tatto» solo come consiglio nostro, o non dirlo.

### Permetrina e gatto (veleno dei prodotti antipulci per cani)

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| Gatto toccato da uno spot-on per cani con permetrina, o da un cane appena trattato: più quieto del solito, bava, tremori, convulsioni, vomito, barcollamento | **Lavare subito con acqua e detersivo delicato; veterinario subito; portare la confezione** | Guida VMD 2014 (linea guida di un ente pubblico, verde); pagina AAFP concorda sul pericolo e sull'urgenza ma non dà primo soccorso (società, giallo) | «Lavalo subito con acqua e un detersivo delicato, poi vai subito dal veterinario con la confezione.» |
| Cane trattato in casa con gatto | Tenere il gatto lontano dal cane appena trattato; non farlo leccare | VMD 2014 | già in `data/manuale/gatto/GAT-SAL-02` |

### Altre sostanze ingerite

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| Ha ingerito una sostanza tossica | **Non provocare il vomito a casa**: nel cane si usa l'acqua ossigenata, ma nel gatto non è raccomandata e può causare gravi danni ai polmoni | Caso clinico 2019 (gatto in insufficienza respiratoria dopo 4 mL di acqua ossigenata al 3%) e la sua rassegna (studio) | «Non provocare tu il vomito. Chiama prima il veterinario e dì cosa ha ingerito.» |
| Contatto con centro antiveleni | Una rassegna dice solo che un centro di Milano riceve chiamate per animali; nessun numero, nessuna regola di accesso | Studio (rassegne 2023-2024) | niente numero né promesse da parte nostra |
| Cosa fare per cioccolato, antigelo, veleno per topi, piante | Nessuna fonte consultabile | - | solo passi universali |

### Convulsioni

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| Crisi che dura 5 minuti o più, oppure una dopo l'altra senza che si riprenda | Emergenza: pronto soccorso subito | Indagine tra proprietari 2023, che riporta le definizioni dell'epilessia (studio) | «Una crisi di 5 minuti o più è un'emergenza: vai subito in pronto soccorso.» |
| Due o più crisi nelle 24 ore | Emergenza (come lo stato epilettico) | Stessa fonte | «Due o più crisi in un giorno: chiama subito il veterinario o il pronto soccorso.» |
| Il veterinario gli ha già dato un farmaco di emergenza per le crisi | Usarlo presto, esattamente come spiegato (nessuna dose) | Stessa fonte (indagine: si usa spesso troppo tardi) | «Se il tuo veterinario ti ha dato un farmaco di emergenza, usalo come ti ha spiegato.» |
| Durante la crisi: niente mani in bocca, toglier gli oggetti, abbassare luci, non tenerlo fermo | Nessuna fonte consultabile | - | passi universali; annotare l'ora segue dalla regola dei 5 minuti |
| Gatto, o crisi singola che passa | Nessuna fonte per «veterinario oggi» | - | senza fonte |

### Ostruzione urinaria (gatto maschio)

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| Si sforza, poche gocce o niente | Veterinario adesso; il blocco dà potassio alto nel sangue e problemi di cuore pericolosi | Studio su 50 gatti maschi, 2022 (solo il pericolo: introduzione) | «Un gatto maschio che si sforza e fa poche gocce o niente può essere in pericolo di vita: vai dal veterinario adesso.» |
| «In poche ore», «non premere la pancia», «non aspettare» | Nessuna fonte consultabile (lo studio stesso non trovò legame tra livello di potassio e sopravvivenza in ospedale) | - | togliere «in poche ore» e «non premere sulla pancia» dalla bozza; «non aspettare» come passo universale |

### Torsione di stomaco (GDV), cane

| Segno | Gesto | Fonte | Frase consigliata |
|---|---|---|---|
| Pancia gonfia, conati senza vomito | Emergenza: pronto soccorso subito, anche di notte; serve la chirurgia; mortalità riportata 10-30%; la maggior parte arriva entro 3 ore dai primi segni | Studio su 130 cani, 2025 (introduzione e risultati) | «Pancia gonfia e conati senza vomito: vai subito in un pronto soccorso, anche di notte.» |
| Cibo e acqua | Nessun gesto; fattori di rischio (cibo secco, tanta acqua, movimento dopo i pasti) | stessa | non dargli da mangiare né da bere |

### Respiro difficile

| Segno | Gesto | Fonte | Frase consigliata |
|---|---|---|---|
| Respira male a riposo, a bocca aperta (gatto), gengive blu o grigie | Veterinario adesso; **toccarlo il meno possibile** (anche un controllo lieve può far collassare un gatto) | Studio su 258 gatti, 2025 (introduzione, indiretta: nessun gesto per proprietari) | «Toccalo il meno possibile e vai subito dal veterinario.» |
| Cane a muso corto con respiro rumoroso | Contattare il veterinario | Pagina WSAVA (sostegno) | stessa |
| Posto fresco, collare allentato, trasportino | Nessuna fonte consultabile | - | passi universali |

### Vipera e processionaria

| Situazione | Gesto | Fonte | Frase consigliata |
|---|---|---|---|
| Morso di vipera (gonfiore, dolore, segni di zanne, letargia, collasso) | **Veterinario subito, telefonando mentre parti**; non farsi aiutare da farmaci (cortisone e antibiotici sono discussi anche tra i veterinari); non legare né incidere né succhiare (le fonti sulle persone dicono che sono errori dannosi) | Studio su un cane in Italia, 2026; rassegna sui veleni, 2026 (persone: indiretta) | «Veterinario subito, telefona mentre parti. Non legare niente, non incidere, non succhiare e non dargli farmaci.» |
| Tenerlo fermo, ghiaccio, lavare con acqua, togliere il collare | Nessuna fonte consultabile | - | **togliere** «ghiaccio», «lava con acqua», «togli il collare» dalla bozza F, salvo una persona li confermi |
| Contatto con processionaria: bava, zampa in bocca, lingua gonfia, respiro difficile | **Veterinario subito e dirlo**; non toccare bruchi e nidi a mani nude; non strofinare | Rassegna europea sui veleni 2024 (lingua, gola, mortalità fino a 3% senza cure rapide); guida del governo britannico (specie diversa) | «Veterinario subito: di' che può essere processionaria. Non toccare i peli a mani nude e non strofinare.» |
| «Sciacqua la bocca con tanta acqua» | Nessuna fonte per gli animali (solo per la pelle e gli occhi delle persone) | - | **togliere** dalla bozza G |

### Sanguinamento, collasso, rianimazione

| Situazione | Gesto | Fonte | Frase consigliata |
|---|---|---|---|
| Sanguinamento: premere con un panno pulito | **Nessuna fonte leggibile**: la linea guida RECOVER 2026 sul primo soccorso esiste ma è rossa | - | passi universali; **decisione del proprietario** se tenere la compressione come gesto non sostenuto (sconsigliato dalla regola) |
| Collasso, gengive pallide | Nessun gesto in nessuna fonte leggibile (la torsione di stomaco riporta gengive pallide nel 14% dei casi, e shock in un quarto) | Studio 2025 (solo presentazione) | passi universali |
| Rianimazione (compressioni, respiro bocca-naso) | Esistono linee guida RECOVER 2012, 2024 e 2026 ma sono tutte rosse; fonti aperte dicono solo che i proprietari sopravvalutano la sopravvivenza (39-45% nelle indagini; 7% dei cani e 19% dei gatti sopravvivono fino alla dimissione in uno studio ospedaliero) | Studio 2025 (non una tecnica) | **non descrivere compressioni**; dire «vai subito al pronto soccorso più vicino e avvisa che arrivi» |
| Aggiungere calore a un adulto in collasso | Nessuna fonte (né a favore né contro); calore sostenuto solo per i neonati | - | non dire «al caldo» né «al fresco» a un adulto, salvo il colpo di calore |

### Neonati (cuccioli e gattini appena nati)

| Segno | Gesto | Fonte | Frase consigliata |
|---|---|---|---|
| Neonato freddo, floscio, non poppa | **Va scaldato subito, piano**: contatto con la madre o un posto tiepido (circa 29-32 gradi la prima settimana); mai lampade o borse molto calde senza protezione (si ustionano) | Rassegna sui neonati 2022 (livello allevatore) | «Un neonato freddo va scaldato subito, piano, e portato dal veterinario.» |
| Cibo o zucchero a un neonato freddo | **Non darli**: da tiepido e solo se si conferma la glicemia bassa; darli per bocca a tutti alla nascita è controindicato | Rassegna sulla glicemia, 2024 | «Non dargli da mangiare né zucchero finché è freddo.» |

## 3. Coniglio, cavia, cincillà, roditori, furetto

Fonti: guida del governo scozzese sul coniglio (2018); codice gallese (2009/2011) e guide gallesi per i venditori (2021); schede AEMV per proprietari (sostegno); sette studi CC BY su coniglio, cavia, cincillà, criceto. **Nessuna fonte aperta dà gesti per cavia, cincillà, criceto, ratto, topo, gerbillo, degu o furetto**: per queste specie solo passi universali. (Per il furetto esistono due lavori rossi: «Emergency medicine of the ferret» e la cateterizzazione; vanno letti da una persona.)

### Coniglio che non mangia o non fa feci (stasi)

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| Non mangia **o** non fa palline; palline più piccole, scure, liquide o assenti; postura curva; pancia premuta a terra | **Emergenza: veterinario subito** (la guida scozzese dice «immediately»; uno studio su proprietari trovò che il 96,8% sceglie «lo stesso giorno») | Guida scozzese 2018, sez. 7 (linea guida, verde); codice gallese (linea guida); studio sui proprietari (indiretta) | «Un coniglio che non mangia o non fa palline è un'emergenza: chiama subito il veterinario.» |
| Fieno e acqua | Fieno e acqua sempre disponibili come alimentazione normale; **«non forzare» non è nella fonte** | Guida scozzese, sez. 4 (linea guida, solo la parte sull'alimentazione) | «Lascia a portata il solito fieno e l'acqua, senza forzarlo.» (la seconda metà è prudenza universale) |
| Medicine, rimedi casalinghi | Nessun farmaco umano né di altri animali: alcuni sono molto pericolosi per i conigli | Guida scozzese, sez. 7 «Medication» (linea guida); scheda AEMV (sostegno) | «Niente farmaci né rimedi casalinghi, a meno che lo dica il veterinario.» |
| Calore, liquidi con la siringa, massaggi | **Nessuna fonte** (né a favore né contro) | - | **togliere «al caldo»** dalla bozza D |
| Quante ore | **Nessuna fonte dà un numero di ore**: «dopo poche ore» non ha fonte | - | togliere «poche ore»; usare «adesso» |

### Caldo / colpo di calore (coniglio; altri piccoli mammiferi)

| Specie | Gesto | Fonte | Frase consigliata |
|---|---|---|---|
| Coniglio | Mettere nel posto più fresco e all'ombra; **bagnare le orecchie con un panno freddo e umido**; superfici fresche o bottiglie ghiacciate (nella guida sono prevenzione); mai in auto o al sole; **niente borse dell'acqua calda** (si ustiona) | Guida scozzese, sez. 3 (linea guida); codice gallese (auto) | «Mettilo nel posto più fresco e all'ombra, bagnagli le orecchie con un panno freddo e umido e chiama subito il veterinario. Mai in auto o al sole.» |
| Cincillà | Caldo e umidità sono un problema; posto fresco e asciutto; **non bagnarlo** (i bagni d'acqua sono tra le cose da evitare, ma è un'inferenza) | Scheda AEMV (sostegno); studio sui cincillà 2024 | «Portalo in una stanza fresca e asciutta e chiama subito il veterinario; non bagnarlo.» (la seconda frase è un'inferenza) |
| Cavia, criceto, ratto, furetto | Nessun gesto di raffreddamento in nessuna fonte | - | passi universali + «portalo fuori dal sole e dal calore» (inferenza dalle regole di prevenzione) |

**Numeri di temperatura**: le fonti non concordano (coniglio 26 o 29 °C; cincillà 18 o 22 °C; furetto 26 o 27 °C): **nessun numero nella chat**.

### Respiro, larve di mosca, ferite, altro

| Segno | Gesto | Fonte | Frase consigliata |
|---|---|---|---|
| Coniglio che respira con la bocca aperta | Emergenza: veterinario adesso | Guida scozzese, sez. 7 (linea guida) | «Un coniglio che respira con la bocca aperta è un'emergenza: chiama subito il veterinario e tienilo calmo.» |
| Larve di mosca (miasi), culetto sporco con il caldo | **Veterinario subito**; la miasi può uccidere in poche ore | Guida scozzese, sez. 7; codice gallese | «Larve di mosca su un coniglio sono un'emergenza: telefona al veterinario e parti.» (nessun gesto a casa: lavaggi e creme non hanno fonte) |
| Convulsioni, sanguinamento, ipotermia, prolasso, ostruzione urinaria, intossicazione, neonati | **Nessuna fonte** per alcuna specie | - | passi universali |
| Caldo per scaldare un animale freddo | Nessuna fonte consiglia di scaldare un piccolo mammifero; la guida scozzese sconsiglia le borse dell'acqua calda (ustioni) e dice che i malati regolano male la temperatura | Guida scozzese, sez. 3 | non scrivere «scaldalo» |

## 4. Uccelli da gabbia

Fonti: rassegna sulle intossicazioni aviarie (2025, Front Vet Sci), caso di olio dell'albero del tè nel cockatiel (2020), consiglio sanitario del Dipartimento della Salute di New York sul caldo (2026, ente pubblico, soprattutto cani e gatti), scheda del laboratorio dell'Università del Texas sul PTFE (2024, sostegno), pagina dell'ospedale MSPCA-Angell sulle emergenze respiratorie degli uccelli (sostegno, scritta per veterinari), domande e risposte di una rivista di appassionati sulle penne con sangue (1998, esperienza clinica).

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| **Fumi da padella antiaderente (PTFE)** surriscaldata: respiro difficile, sibili, debolezza, barcollamento; spesso trovati morti | **Subito fuori dalla stanza con i fumi, aria pulita; veterinario degli uccelli adesso**; i più piccoli (pappagallini, calopsiti) sono i più a rischio; niente spray o aerosol | Rassegna 2025 (studio, seconda mano su testi vecchi); scheda TVMDL 2024 (sostegno); pagina MSPCA (sostegno) | «Portalo subito fuori dalla stanza dei fumi, in aria pulita, e chiama subito il veterinario: questo avvelenamento può essere mortale in fretta.» |
| Respira a becco aperto, coda che si muove ad ogni respiro, piumaggio gonfio | Segno serio: veterinario degli uccelli adesso; **lasciarlo nel trasportino, maneggiarlo il meno possibile** (stress e manipolazione possono essere fatali); se è caldo, posto fresco | Pagina MSPCA (sostegno); consiglio NYC 2026 (linea guida, per il caldo) | «Il respiro a becco aperto è serio: chiama subito il veterinario, lascialo tranquillo nel trasportino e non maneggiarlo.» |
| Caldo, colpo di calore | Posto fresco e in ombra; **spruzzare acqua fresca (non fredda) sul corpo; mai asciugamani bagnati** (trattengono il calore); veterinario | Consiglio NYC 2026 (linea guida per animali in genere, uccelli citati solo nei segni) | «Portalo nella stanza più fresca e in ombra, spruzzagli acqua fresca (non fredda), senza asciugamani bagnati, e chiama il veterinario.» |
| Intossicazione (metalli, cioccolato, avocado, piante, oli essenziali) | **Non provocare il vomito**; dire al veterinario cosa può aver mangiato o toccato; mai oli essenziali sulla pelle | Rassegna 2025; caso del cockatiel 2020 | «Non provocare il vomito: chiama il veterinario e digli cosa può aver mangiato.» |
| Gonfio e sul fondo della gabbia, debole | Emergenza: veterinario adesso | Pagina MSPCA (sostegno) | passi universali |
| Penna in crescita rotta, sanguinamento | **Tre veterinari non sono d'accordo** (toglierla; non toglierla perché rischia di danneggiare il follicolo; spesso basta guardare); nessuna fonte per polvere emostatica, amido di mais o garza premuta | Domande e risposte 1998 (esperienza clinica, sostegno debole) | «Tieni l'uccello calmo e chiama il veterinario. Non togliere tu la penna.» e «se continua a sanguinare, vai subito dal veterinario» |
| Freddo, ipotermia, scaldare un uccello malato | **Nessun metodo per casa**: in ospedale i malati stanno a 29-31 °C con 70% di umidità (sostegno), ma non c'è una fonte per i proprietari; il caso su pulcini di allevamento non è trasferibile | Pagina MSPCA (sostegno); caso su polli 2017 (studio, altro contesto) | «Tienilo in un posto tranquillo, con una temperatura ambiente normale e confortevole; non usare lampade, termofori o asciugacapelli di tua iniziativa.» |
| Uovo trattenuto (femmina), convulsioni, traumi alle ali, unghie che sanguinano, trasporto, **non stringere il petto** | **Nessuna fonte** | - | passi universali; le frasi «non stringergli il petto» e «trasportino coperto con un panno leggero» non hanno fonte |

## 5. Rettili e anfibi (axolotl compreso)

Fonti: guida statutaria Defra per i negozi di animali, parte K sui rettili e gli anfibi (OGL, per venditori); sei studi CC BY (caso di idrocele in un axolotl 2025; temperatura dell'acqua e gonadi dell'axolotl 2023; distocia nei rettili 2026; disturbi riproduttivi dei cheloni 2025; rettili riproduttivi in Italia 2026; guscio rotto 2022; cheloni nel Regno Unito 2025; indagine sui proprietari 2021); la guida all'allevamento dell'axolotl dell'Università del Kentucky (sostegno). **ARAV (associazione dei veterinari dei rettili) non ha ancora pubblicato guide per proprietari.**

### Rettili (lucertole, tartarughe, serpenti)

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| Troppo freddo, lento, non risponde | **Nessuna fonte** su velocità e modo di scaldare né su cosa evitare (acqua calda, lampada vicina, microonde) | - | «Chiama subito un veterinario che conosca i rettili. Rimettilo nel suo terrario abituale con il riscaldamento normale funzionante e non aggiungere fonti di calore di tua iniziativa.» (solo la seconda metà è prudenza) |
| Troppo caldo, sole diretto | Allontanarlo dal sole diretto e dalle fonti di calore; mai in auto | Guida Defra (linea guida, per venditori) | «Portalo fuori dal sole e lontano dal calore, in un posto in ombra e ventilato.» |
| Raffreddare con acqua, niente ghiaccio | **Nessuna fonte** | - | solo passi universali (non usare i gesti dei mammiferi) |
| Tessuto che esce dalla cloaca (**prolasso**) | **Veterinario subito**; l'aria può seccare il tessuto e farlo morire; mantenerlo umido è solo dedotto, non scritto per i proprietari | Studi su cheloni e rettili in Italia (2025-2026) | «Tessuto che esce dalla cloaca: chiama subito un veterinario per rettili. Non spingerlo dentro e non tirare.» (le ultime due frasi sono dedotte: segnalo) |
| Femmina con addome gonfio, spinte, nessun uovo; difficoltà a respirare, zampe posteriori deboli, secrezioni con odore o sangue | Veterinario oggi (segni vaghi) o subito (segni di pericolo); le tartarughe possono trattenere le uova per mesi: la sola ritenzione non è sempre urgente | Studi sulla distocia 2025-2026 | «Se vedi anche difficoltà a respirare, zampe deboli, sangue: veterinario subito.» |
| Guscio rotto | Veterinario; **non incollare né sigillare** una ferita sporca | Caso clinico 2022 (prova debole) | «Non incollare né sigillare il guscio: serve un veterinario per pulirlo.» |
| Ustioni, sanguinamento, convulsioni, intossicazione, bocca aperta per respirare | **Nessuna fonte** (non applicare i consigli per cane e gatto) | - | passi universali |
| Prevenzione | Le fonti di calore devono essere protette: l'animale non deve poterle toccare | Guida Defra (linea guida) | in prevenzione, non in urgenza |

### Anfibi e axolotl

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| Acqua più calda del solito, perdita di appetito, branchie in cattive condizioni | **L'axolotl è un animale d'acqua fredda: mai scaldare la vasca**; portarla via dal sole e dal calore; abbassare la temperatura **con gentilezza, senza sbalzi** | Caso clinico 2025 e studio 2023 (studi); guida Kentucky (sostegno); la regola dei cambi graduali è scritta per i pesci (indiretta) | «L'axolotl vive in acqua fresca: non scaldare mai la vasca. Se l'acqua è più calda del solito, porta la vasca lontano da sole e calore e abbassa la temperatura con calma, senza sbalzi. Chiama oggi un veterinario per esotici.» |
| Cloro e cloramine nell'acqua | Usare solo acqua trattata con biocondizionatore | Guida Defra (anfibi); caso clinico; guida Kentucky | «Aggiungi solo acqua trattata per togliere cloro e cloramine.» |
| Maneggiare | Il meno possibile; con le mani bagnate dell'acqua della vasca (o guanti bagnati non talcati): la pelle è delicata | Caso clinico 2025; guida Defra | «Non toccarlo; se devi, bagnati le mani con l'acqua della sua vasca.» |
| Ghiaccio diretto, bottiglie fredde, «nell'arco di ore» | **Nessuna fonte**; non dare numeri | - | evitare «ghiaccio», «bottiglie», «ore»; dire solo «con calma, senza sbalzi» |
| Sale, medicine, prodotti | Nessuna fonte contro il sale (la guida Kentucky lo usa a bassa dose per la durezza); nessuna lo consiglia in emergenza | Guida Kentucky (sostegno) | «Non aggiungere medicine o prodotti all'acqua se non lo dice il veterinario.» (**non** dire «niente sale» come fatto) |
| Cambio d'acqua | Un caso clinico cambiò il 20% al giorno sotto controllo veterinario: non è una regola; **il 30-40% dei pesci non vale per gli anfibi** | Caso clinico 2025 | non applicare il gruppo dei pesci |
| Sanguinamento o ferita | **Niente garza asciutta né pressione** (la pelle degli anfibi si tocca bagnata) | Guida Defra; caso clinico | solo passi universali |
| Salire in superficie a prendere aria | **Normale** (i polmoni forniscono 40-60% dell'ossigeno); non trattarlo come urgenza | Caso clinico 2025; guida Kentucky | non allarmare |

**Temperature**: la guida Kentucky dice non oltre circa 22 °C; uno studio dice stress sopra 24 °C; il caso clinico indica 14-20 °C: **nessun numero fisso nella chat**.

## 6. Pesci d'acquario d'acqua dolce

Fonti: guida statutaria Defra per i venditori di pesci (parte L, 2026); guida britannica sui trattamenti per i piedi con pesci (2011, altro contesto); rapporto sul benessere dei pesci d'allevamento (altro contesto); due relazioni della WSAVA 2019 sull'acqua nella pratica dei koi e sulle tecniche diagnostiche (livello esperienza clinica); studi su betta e carpe (CC BY). **Nessuna fonte aperta dà il primo soccorso di un proprietario per ammoniaca e nitriti.**

| Segno | Gesto | Fonte (livello) | Frase consigliata |
|---|---|---|---|
| Pesci a galla, apatici, comportamento insolito | Pensare prima all'acqua: guardare e **testare**; i pesci raggruppati vicino alle bolle possono indicare poco ossigeno; **i betta e gli altri labirintidi respirano aria e salgono in superficie normalmente** | WSAVA 2019 (esperienza clinica); guida Defra (linea guida per venditori); rapporto sui pesci d'allevamento (indiretto); studio sul betta | «Un comportamento strano nei pesci è spesso un problema dell'acqua: guarda e testa l'acqua prima di tutto.» |
| Ammoniaca e nitriti alti | Devono essere **zero**; test con kit; **cambio PARZIALE** con acqua trattata, testare di nuovo, ripetere se serve | WSAVA 2019 (esperienza clinica) + guida Defra | «Cambia una parte dell'acqua, non tutta, con acqua trattata con biocondizionatore, e poi testa di nuovo.» |
| **Quanta acqua cambiare** | **Nessuna fonte dà una percentuale**: il «30-40%» non ha fonte | - | togliere il numero; dire «una parte, non tutta» |
| Cloro e cloramine | Usare sempre un biocondizionatore; in alcune zone l'acqua ha cloramine: serve un prodotto che le gestisca (e chieda al gestore dell'acqua) | WSAVA 2019 (esperienza clinica, unica fonte) | «Tratta sempre l'acqua del rubinetto con un biocondizionatore; se nella tua zona c'è cloramina, scegline uno adatto.» |
| Sbalzi di temperatura | Cambiamenti graduali (nei koi non più di circa 3 °C al giorno); il passaggio da caldo a freddo è peggiore | WSAVA 2019; guida Defra | «Porta l'acqua nuova alla stessa temperatura della vasca; niente sbalzi.» |
| Poco ossigeno | Più aerazione e movimento in superficie; **«togli il coperchio» e «filtro verso la superficie» non hanno fonte** | Guida Defra (aerazione col caldo); rapporto sui pesci d'allevamento | «Aggiungi aria con un aeratore o muovi di più la superficie.» |
| Non dare da mangiare oggi | Sostegno solo **indiretto** (pesci d'allevamento a digiuno prima delle procedure): prova bassa | Rapporto sui pesci d'allevamento (indiretto) | «Oggi dai poco o niente da mangiare.» (segno: prova bassa) |
| Quando chiamare | **Nessuna soglia di ore**; per i venditori la guida dice 24 ore; veterinario dei pesci o negozio specializzato con i valori del test | Guida Defra; WSAVA | «Se non migliorano, o ne muore più d'uno, chiama oggi un veterinario dei pesci o un negozio specializzato con i valori del test.» |

**Cosa non fare**: non cambiare tutta l'acqua in una volta (sbalzo termico e chimico); non aggiungere medicine senza una diagnosi (rassegna di opinione 2026 e guida Defra); non pulire tutto il filtro in una volta (rassegna di opinione); la frase «l'acqua del rubinetto uccide i batteri» **non** ha fonte e non va scritta. **Sale (0,1-0,3%) e leganti dell'ammoniaca** vengono da una sola lezione sui koi: nessun passo e nessuna dose.

**Contraddizioni**: gli obiettivi di ammoniaca non sono confrontabili (zero ammoniaca totale in una fonte; 0,02 mg/L di ammoniaca libera nell'altra): non dare ai proprietari un numero «sicuro»; i kit di casa misurano di solito l'ammoniaca totale.

## 7. Elenco delle fonti usate, per gruppo (breve)

- **Cane e gatto**: VMD, «Permethrin: don't put your cat at risk» (2014, OGL); Defra, «Keeping pets healthy during hot weather» (2011, OGL); Hall et al., raffreddamento dei cani con malattia da calore, Vet Sci 2023 (CC BY); studio su 12 cani da lavoro, Animals 2023; caso del gatto con colpo di calore, Vet Sci 2026; zootossine, Toxins 2024; vipera aspis, Vet Sci 2026; rassegna sui morsi di serpente, Front Vet Sci 2026; caterpillar venom, Biomedicines 2020; farmaci di emergenza per le crisi, Front Vet Sci 2023; 50 gatti maschi con ostruzione urinaria, JFMS 2022; 130 cani con torsione di stomaco, Animals 2025; dispnea di 258 gatti, Vet Sci 2025; acqua ossigenata nel gatto, Case Rep Vet Med 2019; video sulla rianimazione per proprietari, JVECC 2025; neonati, Animals 2022; glicemia neonatale, Front Vet Sci 2024; pagina AAFP sulla permetrina; pagina WSAVA sul BOAS.
- **Coniglio e altri**: Scottish Government, «Pet rabbit welfare guidance» (2018, OGL); Welsh Government, «Code of Practice for the Welfare of Rabbits» (2009) e guida per i venditori (2021); schede AEMV (sostegno); Forder et al., BMC Vet Res 2024 (dolore e urgenze); studi VetCompass su cavie e criceti; studio sui cincillà (Animals 2024).
- **Uccelli**: rassegna sulle intossicazioni, Front Vet Sci 2025; tea tree oil, BMC Vet Res 2020; consiglio NYC 2026; scheda TVMDL 2024; MSPCA-Angell; Watchbird 1998.
- **Rettili e anfibi**: Defra, guida statutaria per i venditori, parte K; Cirit et al., idrocele nell'axolotl 2025; temperatura e gonadi 2023; distocia nei rettili, Vet Sci 2026; disturbi riproduttivi dei cheloni, Animals 2025; rettili in Italia, Animals 2026; guscio, Front Vet Sci 2022; VetCompass cheloni, PLoS ONE 2025; Università del Kentucky (sostegno).
- **Pesci**: Defra, parte L; HPA 2011; FAWC; WSAVA 2019 (koi e diagnostica); betta (BMC Zool 2023); informalità nei trattamenti (Animals 2026); nitriti nelle carpe (Vet Sci 2026).

## 8. Quanto fidarsi di questo studio

- Le fonti sono state riassunte da sessioni di aiuto che hanno letto i documenti uno alla volta; **non ho fatto ricontrollare ogni frase da una seconda sessione**, come invece ho fatto per le schede di salute (doc 15), dove il primo giro trovava circa la metà delle frasi imprecise. Prima di mettere una frase di questo documento nella chat, la frase va riletta sul punto indicato della fonte; l'ordine suggerito è: caldo del cane (ordine «raffredda poi parti»), crisi convulsive (due o più nelle 24 ore), acqua ossigenata nel gatto, neonati (scaldare/non nutrire), lavaggio nella permetrina, e le frasi del coniglio sulla guida scozzese.
- **La cosa che più migliorerebbe tutto**: far leggere a una persona le linee guida **RECOVER 2026 sul primo soccorso**, **RECOVER 2024 e 2025** e, per i rettili e gli uccelli, il MSD Veterinary Manual: coprirebbero sanguinamento, collasso, rianimazione, parte dei gesti per esotici. Sono rosse per le regole di diritto d'autore; non ho potuto leggerle.
- **Fonti di Regno Unito**: parecchie sono indicazioni ufficiali britanniche (Scozia, Galles, Defra, VMD), non norme italiane né europee.

## 9. Modifiche da fare in `docs/product/12`

Per ogni gruppo: verdetto (CONFERMATO, CONTRADDETTO, SILENZIO = la fonte non lo dice) e cosa cambiare. Il testo proposto è un suggerimento in italiano semplice, da rileggere.

| Gruppo | Verdetto | Cosa cambiare |
|---|---|---|
| **A** (cane e gatto senza passi propri) | In parte confermato; «evita acqua in eccesso» **non ha fonte** e **contraddice** il comunicato Defra per il caldo; «evita cibo» confermato solo per i neonati freddi; «al caldo» tolto è corretto per gli adulti ma **va rimesso per i neonati** | «Contatta subito il veterinario o un pronto soccorso veterinario. Tieni l'animale calmo, tranquillo e al sicuro. Non forzarlo a mangiare o a bere e non dargli farmaci senza indicazione del veterinario. Non provocare tu il vomito. Se ha ingerito qualcosa o è stato a contatto con un prodotto, porta con te la confezione o una foto dell'etichetta. Se è un neonato che senti freddo, scaldalo piano e non dargli da mangiare.» |
| **B** (uccelli, piccoli mammiferi, rettili senza passi propri) | In parte confermato, in parte silenzio; «non scaldarlo» **non ha fonte** (gli ospedali scaldano gli uccelli malati, ma non c'è un metodo per casa) | Uccelli: «temperatura ambiente normale e confortevole, senza lampade, termofori o asciugacapelli di tua iniziativa». Rettili: «rimettilo nel suo terrario abituale con il riscaldamento normale funzionante, senza aggiungere fonti di calore». Mammiferi: tenere «niente farmaci» (coniglio, confermato); «tranquillo, penombra, non forzare» sono passi universali senza fonte |
| **C** (caldo/sole, senza colpo di calore evidente) | Compatibile; «evita acqua in eccesso» **contraddetto** dal comunicato Defra | «Posto fresco, all'ombra e tranquillo, aria che circola, senza coperte. Se è sveglio, acqua fresca a piccoli sorsi senza forzare. Niente farmaci senza indicazione del veterinario. Se ansima molto, passa subito al colpo di calore.» Togliere «evita acqua in eccesso» per il coniglio |
| **D** (coniglio o roditore che non mangia) | Veterinario adesso: **confermato per il coniglio**; fieno e acqua confermati come alimentazione normale; **«al caldo» senza fonte e in contrasto con la guida scozzese**; **«dopo poche ore» senza fonte** | «Veterinario esperto in esotici o pronto soccorso adesso: un coniglio che non mangia o non fa palline è un'emergenza. Lascia a portata il solito fieno e l'acqua, senza forzarlo, in un posto tranquillo a temperatura normale. Niente farmaci né rimedi casalinghi.» Per cavia, cincillà e roditori: solo passi universali con «veterinario esperto in esotici adesso» |
| **E** (colpo di calore) | In parte confermato, **un punto contraddetto**: «raffredda e poi parti» (la fonte dice di raffreddare **prima** del viaggio); acqua, ventilatore, no ghiaccio, no asciugamani avvolti confermati; **non applicare ai piccoli mammiferi, agli uccelli, ai rettili**: per loro vale P | Cane: «Chiama subito il veterinario e, mentre ti prepari, inizia a raffreddarlo: ombra o posto fresco, acqua fresca del rubinetto (non ghiaccio) sul pelo, soprattutto su pancia e interno coscia, aria con ventilatore. Niente asciugamani bagnati avvolti addosso e non mettergli la testa sott'acqua. Se è sveglio, acqua a piccoli sorsi senza forzare. Parti con l'aria condizionata.» «Appena è più calmo e non più caldo al tatto, smetti» e la frase sul gatto sono consigli deboli: segnalarli come tali |
| **F** (vipera) | In parte confermato; «veterinario subito, telefona mentre parti», «niente lacci, incisioni, farmaci» confermati; **«ghiaccio», «lava con acqua», «togli il collare», «niente suzione» non hanno fonte** | «Veterinario subito, telefonando mentre parti. Tienilo calmo e fermo, in braccio o nel trasportino. Non legare nulla, non incidere, non succhiare il veleno e non dargli farmaci.» Togliere ghiaccio, lavaggio e collare, salvo conferma di una persona |
| **G** (processionaria) | In parte confermato; «veterinario subito, la gola può gonfiarsi» e «niente mani nude sui bruchi» confermati; **«sciacqua la bocca» non ha fonte per gli animali** | «Veterinario subito e di' che può essere processionaria: la gola e la lingua possono gonfiarsi. Non toccare bruchi o nidi a mani nude, non strofinare il muso o la bocca. Niente farmaci.» Togliere lo sciacquo, salvo conferma |
| **H** (convulsioni) | Soglia dei 5 minuti **confermata** (cane); **«un'altra crisi senza ripresa» confermata; «due o più nelle 24 ore» è emergenza** (rischio di sotto-triage con «veterinario oggi»); gesti durante la crisi: silenzio; esotici: silenzio | «Se la crisi dura 5 minuti o più, o ne arriva un'altra senza che si sia ripreso, o sono due o più nelle 24 ore: pronto soccorso subito. Guarda l'ora e annota quanto dura. Se il tuo veterinario ti ha dato un farmaco d'emergenza per le crisi, usalo esattamente come ti ha spiegato.» «Una crisi singola che passa: veterinario oggi» **non ha fonte**: segnalarlo. Per esotici: solo «veterinario subito, posto sicuro e tranquillo, annota l'ora» |
| **I** (uccello a becco aperto) | In parte confermato (serio, veterinario adesso, trasportino, manipolazione minima); **silenzio, penombra, panno leggero** senza fonte | «Veterinario esperto in uccelli adesso. Lascialo tranquillo nel trasportino, lontano da fumi e spray, senza maneggiarlo più del necessario. Se la stanza è calda, portalo in un posto fresco.» Togliere il panno leggero |
| **L** (pesci) | Confermato in sostanza (cambio parziale, biocondizionatore, stessa temperatura, misurare ammoniaca e nitriti, veterinario dei pesci); **«30-40%», «filtro verso la superficie», «togli il coperchio», «in poche ore» non hanno fonte**; «non dare da mangiare» sostenuto solo indirettamente | «Pesci in difficoltà: aggiungi aria (aeratore o più movimento in superficie). Cambia una parte dell'acqua, non tutta, con acqua del rubinetto trattata con biocondizionatore e alla stessa temperatura della vasca. Non aggiungere medicine. Misura ammoniaca, nitriti e temperatura; se sono alti, ripeti un cambio parziale e riprova. Se non migliorano, o ne muore più d'uno, chiama oggi un veterinario dei pesci o un negozio serio con i valori. In alcune zone l'acqua ha cloramine: scegli un biocondizionatore adatto.» «Non dare da mangiare oggi»: prova bassa, può restare come «dai poco o niente» |
| **M** (cane e gatto che sanguinano) | **Silenzio**: la linea guida RECOVER sul primo soccorso (2026) esiste ma è rossa; la compressione con un panno **non ha una fonte leggibile** | Fino a lettura da parte di una persona: passi universali («Chiama subito il veterinario e parti. Tieni l'animale calmo e muoviti il meno possibile. Niente farmaci.»); **decisione del proprietario** se tenere la compressione come gesto non sostenuto |
| **N** (gatto che si sforza) | Il pericolo è confermato; **«in poche ore» e «non premere sulla pancia» non hanno fonte** | «Chiama subito il veterinario e parti: un gatto maschio che si sforza e fa poche gocce o niente può essere in pericolo di vita. Non aspettare. Trasportino, con calma, niente farmaci.» |
| **O** (respiro difficile cane e gatto) | In parte confermato per il gatto (veterinario adesso; manipolazione minima); posto fresco, collare allentato, trasportino: silenzio | «Chiama subito il veterinario e parti: respirare male a riposo o a bocca aperta va visto adesso. Tienilo il più calmo possibile e toccalo il meno possibile. Niente cibo né farmaci.» Il gesto aggiunto della domanda di chiarimento «posto fresco, ben aerato, lontano da fumi» resta compatibile solo per «lontano da fumi e spray» (uccelli) |
| **P** (esotici, caldo) | In parte confermato per il coniglio (ombra, posto fresco, orecchie bagnate, acqua a disposizione, mai in auto); **«niente correnti dirette», «togli le coperture», «niente ghiaccio» senza fonte** | Coniglio: «Veterinario esperto in esotici o pronto soccorso adesso. Mettilo nel posto più fresco e all'ombra, con acqua a disposizione; puoi bagnargli le orecchie con un panno freddo e umido. Mai in auto o al sole. Niente farmaci.» Altri piccoli mammiferi: «nel posto più fresco e all'ombra, acqua a disposizione, niente bagni né ghiaccio»; cincillà: non bagnarlo. Uccelli: «stanza più fresca e in ombra, spruzza acqua fresca (non fredda), mai asciugamani bagnati». Rettili: «lontano dal sole diretto e dalle fonti di calore, in ombra e ventilato»; niente altro |
| **Q** (axolotl) | «Non scaldare la vasca» **confermato**; «abbassa piano» in parte; **«nell'arco di ore», «bottiglie», «ghiaccio diretto» senza fonte; «niente sale» NON sostenuto come fatto**; manca il cloro | «L'axolotl vive in acqua fresca: non scaldare mai la vasca. Se l'acqua è più calda del solito, porta la vasca lontano da sole e calore e abbassa la temperatura con calma, senza sbalzi. Aggiungi solo acqua trattata per togliere cloro e cloramine. Toccalo il meno possibile; se devi, bagnati le mani con l'acqua della vasca. Non aggiungere medicine o prodotti all'acqua se non lo dice il veterinario. Chiama oggi un veterinario per esotici.» Il gruppo dei pesci (30-40%) **non vale** per l'axolotl |
| **R** (uccello che sanguina, penna in crescita) | **Polvere emostatica, garza premuta, panno senza stringere il petto: senza fonte**; «mostrare sempre al veterinario la penna rotta»: i pareri sono divisi | «Tieni l'uccello calmo e tranquillo e chiama subito un veterinario per uccelli. Non togliere la penna da solo e non mettere creme o disinfettanti. Se continua a sanguinare, vai subito.» |
| **S** (altri esotici che sanguinano) | **Silenzio** per tutti; **non adatta agli anfibi** (la pelle si tocca con mani bagnate, niente garza asciutta); per i rettili solo passi universali; guscio: non incollare né sigillare | «Veterinario per esotici subito; maneggialo il meno possibile; niente farmaci, creme o disinfettanti.» Togliere «premi con una garza» per esotici |
| **T** (uccello e fumi) | **Confermato** (aria pulita, veterinario adesso, pericolo anche in poco tempo; piccoli i più a rischio) | Aggiungere «niente spray o aerosol vicino a lui» |

### Gruppi nuovi suggeriti

1. **Coniglio con larve di mosca** (guida scozzese, codice gallese): «veterinario subito», nessun gesto a casa.
2. **Coniglio che respira a bocca aperta** (guida scozzese): «veterinario subito, tienilo calmo».
3. **Rettile con tessuto che esce dalla cloaca, difficoltà a respirare, sangue, zampe deboli**: «veterinario per rettili subito», solo passi universali, senza gesti a casa.
4. **Neonati freddi (cuccioli e gattini)**: scaldare piano, non dare cibo né zucchero (livello allevatore).
5. **Permetrina e gatto**: già coperto da `data/manuale/gatto/GAT-SAL-02`; nei passi d'urgenza serve il gesto «lava con acqua e detersivo delicato», con la fonte VMD.

### Cosa resta da leggere a mano (priorità)

1. RECOVER 2026 sul primo soccorso (sanguinamento, collasso, caldo, convulsioni, intossicazioni).
2. RECOVER 2024 sulla rianimazione e 2025 sui neonati.
3. MSD Veterinary Manual: uccelli, rettili, anfibi, piccoli mammiferi, pesci.
4. Per il furetto: «Emergency medicine of the ferret» (2007) e la cateterizzazione (2011).
5. Il documento Vet-COT 2016 («cure prima dell'ospedale»), da cui viene l'ordine «raffredda poi parti».
