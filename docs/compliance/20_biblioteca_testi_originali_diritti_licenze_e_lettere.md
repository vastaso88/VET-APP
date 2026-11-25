# Biblioteca di testi originali: diritti, licenze, attribuzione e lettere ai titolari

Data: 2026-11-17. Risposta all'Orchestratore sul piano approvato dal proprietario il 17 novembre ([docs/llm/07](../llm/07_piano_chat_dalla_biblioteca.md), main 03c9495): la chat risponde da un archivio di **testi originali scaricati sul nostro server**, non più da schede scritte a mano. Le pagine citate sono state **aperte a mano in un browser il 17 novembre 2026** (file robots.txt, note legali, avvisi di copyright, testo della licenza CC BY 4.0, pagine di NCBI ed Europe PMC); non ho letto i termini di ogni singolo documento. Non è consulenza legale: i punti ⚖️ (§11) vanno confermati da un legale prima di caricare la biblioteca nel database di produzione.

**Che cosa cambia rispetto al [13](13_parere_fonti_scientifiche_e_diritto_d_autore.md).** Prima si scrivevano schede nostre con parole nostre: bastava riassumere i fatti, che non sono protetti. Ora si **conserva il testo di terzi** e se ne mostrano passi e riassunti: per questo serve una licenza o la non-protezione per legge, e il «riassunto di fatti senza permesso» di 13 A.1 **non basta più** per ciò che entra nella biblioteca. Del 13 restano valide le regole su riassunto e compendio, banche dati, semaforo e controllo in 4 punti.

## 1. In breve

| # | Domanda | Risposta | Dove |
|---|---|---|---|
| 1 | Categorie ammesse | Sì: atti ufficiali (art. 5 L. 633/1941) e documenti con licenza scritta CC0, CC BY, OGL, IODL, o pubblico dominio. Fuori NC, ND, SA, il «gratuito» senza licenza e tutto ciò che non dichiara una licenza. Siti italiani letti oggi: salute.gov.it e iss.it sì **per documento**, IZS no | §2 |
| 2 | Europe PMC e `ai-train=no` | Sì, solo via API REST e solo `cc by` o `cc0`: il segnale è sul sito (non sull'API), riguarda l'addestramento, e la base è la licenza degli autori. Residuo ⚖️ basso | §3 |
| 3 | Attribuzione CC BY | Basta un collegamento a una scheda con le informazioni richieste, se la citazione breve porta lì senza ambiguità. Minimo in 6 punti | §4 |
| 4 | Testo intero nel database e pezzi ai fornitori USA | Nessun limite per le licenze aperte. Inventario e consenso **non cambiano**, a quattro condizioni | §5 |
| 5 | Contatore delle domande senza fonte | Non è un dato personale se resta un contatore aggregato | §6 |
| 6 | Lettere ai titolari | Modello in italiano e inglese; le firma e le invia il proprietario | §8 |
| 7 | Abstract di articoli non aperti (aggiunta del 17 novembre sera) | **No**; sì ai soli metadati e agli abstract di articoli cc by o cc0. Fino a nuovo avviso nessuno li scarica | §12 |
| 8 | Ripiego a memoria dopo il sì dell'utente | Lecito e non ingannevole con avviso ed etichetta **in testo** su ogni risposta; mai per il pericolo; limiti per minori e salute | §13 |
| 9 | Frase fissa «Non ho una fonte su questo…» | Va bene senza pericolo, con due ritocchi; con pericolo evidente non deve comparire da sola | §14 |
| 10 | Vigenza dell'O.M. 6/8/2013, DPR 320/1954, assicurazione a Bolzano, riga fonte di Normattiva | O.M. **in vigore** (prorogata, ultima il 16/7/2026), testo 2013 come modificato dal 2015; **DPR 320/1954 abrogato**; in Alto Adige nessun obbligo generale; riga fonte completa («testo non ufficiale e gratuito») | §15 |
| 11 | Piano 08 (20/11): riga di trasparenza, frase per la persona ferita, licenze delle guide per proprietari | Riga una volta per chat con «trovata in una fonte» (non «verificata»); frase del 112 approvata con due ritocchi; OGL, CC BY, ECDC ed EFSA (solo le pagine, i pareri sono CC BY-ND), agenzie USA come verde con riserva ⚖️ | §16 |
| 12 | Documento senza riga di licenza, ma con licenza del sito (8 PDF di enti UK) | Basta la licenza del sito, registrando pagina e data, se il documento è dell'ente e non dice nulla di contrario (§17); per gli articoli scientifici no | §17 |
| 13 | Piano 08 finale (20/11 sera): lettura al momento di pagine web, note accumulate, indice a tre livelli, messaggio d'attesa, privacy | (a) sì; (b) sì a condizioni; (c) **no senza permesso**: «non conservare» cambia poco; note: tetto per sito e niente per (c); «Con fonti», non «verificata»; messaggio senza superlativi; nessun dato personale se la ricerca è specie + tema | §18 |
| 14 | Parere sito per sito sull'elenco bianco (34 voci, `elenco_bianco_candidati.md`) | **Sì** 1–7, 9, 12, 19, 21–23; **sì a condizioni** 8, 10, 11, 14, 20; **sì con riserva ⚖️** 15, 16; **solo con permesso** 24–27, 29–32, 34; **no** 13, 17, 18 (pareri), 28, 33. Correzioni: Agriculture Victoria **non è aperta**; il disclaimer di MSD **non vieta** l'IA | §19 |
| 15 | Urgenze senza percorso dedicato (20/11 notte): obbligo o cautela, avvisi, persona ferita, negozio e sito | **Cautela, non obbligo** (correggo «obbligatoria» di §13 e §16.1). Senza percorso: avvisi **uguali per tutti** più visibili, regola «mai giudicare la gravità del caso», cancello «urgenze non sotto oggi» come condizione di rilascio; frase del 112 **statica e per Paese**; frase per negozio e sito. Rischi senza attenuarli: rassicurazione sbagliata, prova nel repository pubblico, limiti degli avvisi, direttiva 2024/2853 dal 9/12/2026 ⚖️ | §20 |
| 16 | Elenco bianco: EUR-Lex tramite l'Ufficio delle pubblicazioni; traduzione inglese non ufficiale dell'OPAn svizzera (20/11 notte) | **EUR-Lex:** l'interfaccia Cellar (`publications.europa.eu/resource/celex`) è il canale macchina documentato dall'Ufficio stesso, non un aggiramento, a sei condizioni (nessuna barriera aggirata, pausa di 10 s, versione consolidata, registro, riga fonte «copia non ufficiale»). **OPAn:** la traduzione dell'USAV non è fonte citabile (nessun valore legale, diritti non chiari); il testo ufficiale italiano lo scarica a mano il proprietario da Fedlex (`/filestore/` vietato ai programmi) | §21 |
| 17 | Accesso alle fonti: nome con cui ci si presenta, sfide anti-robot, lettura dei termini (secondo incidente, 20/11 notte) | Circa 95 comandi su circa 50 siti con nome di browser (8–10/11): **prassi, non scivolone**; toccano 3 schede su 11, il catalogo e la **cronologia pubblica** (bozze del 10/11). Il proprietario ha chiuso il progetto delle schede (cancellate il 20/11); cronologia non riscritta, rischio residuo registrato; la lettura dei termini è il controllo dovuto, a condizioni; otto regole di accesso (nome proprio con test positivo, robots → termini → lettura, stop a sfide, registro per richiesta, niente cancellazione dei risultati); dettagli solo nei registri interni | §22 |
| 18 | Griglia delle licenze per il «Cercafonti» (ricerca notturna in tutto il mondo) e regola per le leggi straniere (21/11) | Classi **V** (verde), **VR** (con riserva), **G** (giallo, alla Normativa), **R** (rosso, mai usato), **N** (non raggiungibile); tabelle per licenza, per Paese (atti ufficiali, elenco chiuso) e per tipo di titolare; pagine senza licenza = R; leggi straniere solo testi ufficiali, per chi vive in quel Paese, con vigenza e «non ufficiale»; casi gialli a gruppi; Paesi e fornitori nuovi; il silenzio del proprietario vale solo per V e VR; «No» ≠ «ritirata per diritti»; campione di controllo; decisioni sui gialli in §23.11 | §23 |

## 2. Categorie ammesse (punto 1)

**Regola in una riga.** Entra nella biblioteca solo ciò che dichiara per iscritto, sul documento o sulla pagina, di poter essere riusato anche a fini commerciali e adattato (riassunto, tradotto), oppure ciò che la legge non protegge. Il resto resta fuori fino a un permesso scritto.

### 2.1 Che cosa entra e che cosa no

| Categoria | Entra? | Condizioni |
|---|---|---|
| Testi di atti ufficiali (leggi, decreti, regolamenti, ordinanze, circolari), italiani ed esteri | Sì | Art. 5 L. 633/1941: la legge sul diritto d'autore non si applica ai testi degli atti ufficiali dello Stato e delle amministrazioni pubbliche, italiane e straniere. Solo il **testo dell'atto**: non commenti, note, massime o impaginazione di chi lo pubblica, non norme di enti privati (UNI, CEI), non opuscoli, rapporti o schede divulgative dei ministeri (non sono «atti»: conta la licenza) |
| Sentenze e provvedimenti individuali | No | Sono atti ufficiali, ma contengono dati di persone: fuori dalla biblioteca |
| Contenuti di enti pubblici con licenza aperta scritta: CC BY (versioni 2.0–4.0), CC0, OGL v3.0, IODL 2.0 | Sì | Per documento: la licenza di un sito vale «ove non diversamente specificato». Immagini, loghi e materiale di terzi restano fuori. Attribuzione (§4) |
| Articoli ad accesso aperto con licenza CC BY o CC0 | Sì | Attribuzione e indicazione delle modifiche (§4). Solo testo: né figure né tabelle (dentro un articolo CC BY ci possono essere figure di terzi con altri diritti) |
| Pubblico dominio (per esempio opere del governo federale USA) | Sì | Verificare che il documento non incorpori materiale di terzi; si cita lo stesso |
| CC BY-SA | No | Le modifiche vanno condivise con la stessa licenza: la risposta della chat diventerebbe CC BY-SA |
| CC BY-NC, NC-SA, NC-ND | No | Quokka è a pagamento: NC vieta l'uso commerciale |
| CC BY-ND, ND | No | Vieta le opere derivate: riassunto e traduzione lo sono |
| «Open access» o «gratuito» senza licenza, «diritti riservati», licenza assente | No | Gratuito non vuol dire riutilizzabile. Solo con permesso scritto (§8) |
| FAO e OMS | Da controllare per documento | Di norma CC BY-NC-SA 3.0 IGO: quindi no (da verificare su ogni documento) |

### 2.2 Siti letti il 17 novembre

| Sito | Esito | Che cosa dice la pagina | Condizione |
|---|---|---|---|
| **Normattiva** (avviso legale) | Verde per i testi degli atti | Riproduzione dei testi elettronici consentita se si indicano la fonte, il carattere non autentico e la gratuità; fa fede solo la Gazzetta Ufficiale a stampa; la raccolta è «frutto di una selezione redazionale». robots.txt: aperto salvo le pagine di ricerca; nessun segnale per l'IA | Fonte scritta per intero: «Normattiva (testo non ufficiale e gratuito; fa fede la Gazzetta Ufficiale a stampa)»: servono tutte e tre le indicazioni (§15.5). Solo gli atti che servono, uno alla volta (art. 102-bis); mai le pagine di ricerca |
| **Gazzetta Ufficiale** (home) | Verde per il testo dell'atto | Stessa dicitura di Normattiva; nessun robots.txt (404) | Meglio prendere il testo da Normattiva; niente impaginazione né inserzioni |
| **EUR-Lex** (avviso legale) | Verde | Atti riusabili anche a fini commerciali, salvo diversa indicazione (decisione 2011/833/UE); testi consolidati, sintesi e contenuti editoriali CC BY 4.0 con fonte e indicazione delle modifiche; metadati CC0; eccezioni per documenti con condizioni speciali e materiale di terzi. robots.txt: pausa di 10 secondi | Fonte; per consolidati e sintesi scrivere «modificato»; canali ufficiali, una richiesta ogni 10 s |
| **salute.gov.it** (portale, note legali) | Verde, con lettura della nota di ogni sezione | CC-BY 4.0 «ove non diversamente specificato», con fonte e indirizzo della pagina; esclusi immagini, loghi, marchi e contenuti di terzi. **Sezioni tematiche con note proprie**: COVID-19 = CC 2.5 solo non commerciale e senza opere derivate (**rosso**); Esenzioni dal ticket = CC BY 3.0 (verde). robots.txt: nessun segnale per l'IA | Per il Manuale il sito blocca i programmi: scarico a mano da una persona, **mai aggirare il blocco** |
| **dati.salute.gov.it** | Verde | Dati riusabili e ridistribuibili con IODL 2.0 (dalle note del portale e dal catalogo del Manuale) | Attribuzione |
| **iss.it** (pagina Contatti, copyright) e **EpiCentro** (segue la politica di iss.it) | Giallo: verde solo per il **singolo documento** | CC-BY 4.0 «salvo ove diversamente indicato», con fonte e indirizzo; **ma** la stessa nota avverte che per le opere coperte dal diritto d'autore alcune non sono riusabili a fini commerciali. Il BEN (EpiCentro) è CC BY-NC-ND 4.0 (letto oggi); pubblicazioni più vecchie risultano NC-ND (da una ricerca, non riletto) | Ammesso solo il documento che dichiara CC BY su di sé e non ha diciture contrarie. Il «rosso» del 15 novembre era dovuto al blocco dei programmi: a mano la pagina si apre |
| **IZSVe** (note legali) | Rosso | Testi e tabelle CC BY-NC 4.0 (solo non commerciale); i contenuti «tutti i diritti riservati» sono esclusi anche da quella licenza | Escluso |
| **IZSLER** e gli altri IZS | Rosso | IZSLER: copia a fini di lucro solo con permesso scritto (catalogo del Manuale, 15 novembre; non riletto oggi). Gli altri non sono stati letti | Esclusi finché non si legge la nota di ciascuno |
| UK (gov.uk e simili), ECDC, Commissione europea | Verde (già nel catalogo del Manuale) | OGL v3.0; CC BY 4.0 sui contenuti propri | Come da catalogo |

### 2.3 Quattro cautele

1. **Licenza per documento, non per sito.** La nota di un sito dice «ove non diversamente specificato»: il documento può dire altro (PDF con «© tutti i diritti riservati», rapporti di altri autori, loghi). Si legge la licenza sul documento e la si registra (§7).
2. **Solo testo.** Niente figure, tabelle, immagini, schemi né note redazionali: sono il punto in cui di solito entrano i diritti di terzi.
3. **Niente atti con dati di persone** (sentenze, provvedimenti individuali).
4. **Niente raccolta di intere banche dati.** Si scaricano i documenti che servono, uno alla volta, dai canali ufficiali (diritto sui generis, art. 102-bis; Normattiva stessa dice che la sua raccolta è una selezione redazionale). Niente raschiatura, niente aggiramento di blocchi anti-programma: dove il sito blocca, scarica una persona a mano.

### 2.4 L'eccezione per l'estrazione di testo e dati **non** è la base

L'art. 70-quater (e 70-septies per l'IA) consente l'estrazione di testo e dati solo con accesso legittimo, **se i titolari non hanno riservato i diritti** in modo appropriato, e permette di tenere le copie solo per il tempo necessario all'analisi. La biblioteca conserva i testi in modo permanente e ne mostra passi: non è «estrazione» in quel senso, e molti editori hanno riservato i diritti. Quindi la base per ogni testo è **la licenza (CC BY, OGL, IODL…) o l'art. 5**, mai l'eccezione.

## 3. Europe PMC e il segnale `ai-train=no` (punto 2)

### 3.1 Che cosa dicono le pagine (lette il 17 novembre)

| Cosa | Dove | Che cosa risulta |
|---|---|---|
| Segnale sul **sito** | europepmc.org/robots.txt | `Content-Signal: search=yes,ai-train=no,use=reference`; blocco di ClaudeBot, anthropic-ai, GPTBot, CCBot e altri; commento: le restrizioni sono riserve espresse dei diritti ex art. 4 direttiva 2019/790; per un uso su cui il gestore non scrive nulla (come `ai-input`, cioè la lettura al momento della domanda) «non concede né limita» |
| Segnale sull'**API** | www.ebi.ac.uk/robots.txt (host dell'API REST) | Nessun segnale per l'IA, nessun blocco di bot IA, nessun divieto su /europepmc; solo una pausa di 10 secondi per chi non è un indicizzatore |
| Avviso di copyright | europepmc.org/Copyright | Il materiale è fornito da editori e autori, che tengono i diritti; vietati crawler e scarico in blocco dal **sito**; OAI, REST, SOAP e scarico in blocco sono gli **unici servizi** ammessi per lo scarico automatico; gli articoli così distribuiti valgono con la licenza indicata in ciascuno |
| Sottoinsieme aperto | europepmc.org/downloads/openaccess | Circa 8,4 milioni di articoli; le licenze non sono identiche; gli articoli «gratuiti ma con diritti riservati» non ne fanno parte |
| Campi dell'API | prova con `resultType=core` | `isOpenAccess` e `license` (valori visti: `cc by`, `cc by-nc`, `cc by-nc-nd`). Nel file XML: `<license>` con il collegamento alla licenza, `<copyright-statement>` e `<copyright-holder>` |
| Campione | 100 articoli «aperti» su cani, gatti e conigli | 74 `cc by`, 17 `cc by-nc-nd`, 9 `cc by-nc`: **26 su 100 non erano riusabili** |
| NCBI/PMC | pmc.ncbi.nlm.nih.gov/tools/textmining/ | La categoria «uso commerciale consentito» comprende CC0, CC BY, **CC BY-SA e CC BY-ND**: non basta come filtro |

### 3.2 Perché si può

1. **La base è la licenza.** Un articolo CC BY è offerto dai suoi autori ed editori a chiunque, anche per uso commerciale e con adattamenti. Il gestore del sito non è il titolare degli articoli (lo dice Europe PMC stessa) e non può togliere ciò che la licenza concede. Il segnale protegge i diritti del gestore o riserva quelli per cui non c'è licenza: è la funzione dell'opt-out dell'art. 4, che serve proprio dove non c'è altro permesso.
2. **Il segnale è `ai-train=no`.** Riguarda l'addestramento e la rifinitura di modelli. Noi non addestriamo né rifiniamo: leggiamo i passi al momento della domanda. Su quell'uso il gestore non si esprime (`use=reference` non è definito con precisione: la lettura più ragionevole è che consenta l'uso come riferimento).
3. **L'API è il canale che Europe PMC stessa indica** per lo scarico automatico del sottoinsieme aperto, e il suo host non porta alcun segnale.
4. **I fornitori non addestrano sui nostri dati** (Anthropic, termini commerciali: [14](14_anthropic_contratto_conservazione_e_regole_d_uso.md)): nessun uso dei testi per addestrare, né da parte nostra né dei fornitori.

### 3.3 Regole di scarico

1. **Solo** `www.ebi.ac.uk/europepmc/webservices/rest`. Mai pagine, PDF o ricerca di europepmc.org.
2. Filtro: `isOpenAccess` = `Y` **e** `license` esattamente `cc by` o `cc0`. Si scartano `cc by-nc`, `cc by-nc-nd`, `cc by-nd`, `cc by-sa`, licenze di emergenza (COVID-19) e campo vuoto. Il flag «aperto» e la categoria «uso commerciale» di PMC non bastano.
3. **Doppia lettura:** si controlla anche il file XML (`<license>`, collegamento alla licenza) e si salva `<copyright-statement>` per l'attribuzione. Se i due non coincidono, vince il più restrittivo.
4. Solo articoli con revisione tra pari (niente preprint) e solo corpo del testo: **non** si salvano figure né tabelle.
5. Nome onesto nell'intestazione della richiesta (nome del progetto e un recapito preso da una variabile d'ambiente, mai scritto nel codice), **una richiesta ogni 10 secondi** (200 testi ≈ 35 minuti), nessun parallelismo.
6. Registro per documento (§7). Mai addestrare o rifinire modelli con questi testi.
7. Se Europe PMC o EMBL-EBI chiedono di smettere, si smette e si toglie quanto richiesto.

### 3.4 Residuo ⚖️ e piano B

Resta un rischio **basso**: un legale potrebbe leggere il segnale come riserva anche per la lettura da parte di un sistema di IA al momento della domanda, o ritenere che un opt-out del gestore pesi anche sul sottoinsieme CC BY. **Piano B a costo zero:** gli stessi articoli CC BY dal sito dell'editore (PLOS, BMC, MDPI, Frontiers e simili) con le loro interfacce, dopo il loro controllo in 4 punti ([13](13_parere_fonti_scientifiche_e_diritto_d_autore.md) A.3). Alternativa ufficiale: il servizio cloud e le interfacce di PMC (NCBI), con lo stesso filtro sulla licenza.

## 4. Attribuzione (punto 3)

### 4.1 Che cosa chiede CC BY 4.0

Testo della licenza riletto il 17 novembre:
- **§3(a)(1):** chi condivide il materiale, anche modificato, deve conservare, se forniti: l'indicazione degli autori, un avviso di copyright, un avviso che rimanda alla licenza, un avviso sull'esclusione di garanzie e un collegamento al materiale; deve **indicare se lo ha modificato**; deve **indicare la licenza** con il testo o un collegamento.
- **§3(a)(2):** si può farlo «in modo ragionevole in base al mezzo e al contesto»; la licenza stessa dice che può bastare **un collegamento a una risorsa che contiene le informazioni**. È ciò che rende possibile una citazione breve in chat.
- **§3(a)(3):** se il titolare lo chiede, si tolgono le informazioni di attribuzione «per quanto ragionevolmente possibile».
- **§2(a)(5)(C):** nessuna autorizzazione a far pensare di essere collegati o approvati dagli autori.
- **§2(b)(1):** i diritti morali (per esempio l'integrità dell'opera) **non sono concessi**; il titolare rinuncia a farli valere solo per quanto necessario all'uso. In Italia l'autore conserva comunque il diritto di opporsi a deformazioni che ledano il suo onore o la sua reputazione (art. 20 L. 633/1941).
- **§6(b):** se si sbaglia l'attribuzione, la licenza torna valida da sola se si corregge entro 30 giorni da quando ci si accorge dell'errore.

Un riassunto o una traduzione fatti da un modello vanno trattati come **adattamento**, anche se in teoria usano solo fatti: non si può contare su un confine netto tra idea ed espressione.

### 4.2 Il minimo che raccomando

La citazione breve della chat (asterisco in apice e «Autore, AAAA») basta **se** un tocco su di essa, o una pagina «Fonti e licenze» raggiungibile dalla chat, porta a una scheda con questi sei punti:

1. **Autori** (tutti i nomi fino a sei; oltre, il primo e «e altri» solo se il collegamento porta all'elenco completo) o ente, e **titolo**;
2. **rivista o ente e anno**, con **collegamento al documento originale** (DOI o indirizzo);
3. **avviso di copyright** se il documento lo ha (campo `copyright-statement`, per esempio «© 2025 Rossi et al.»);
4. **licenza**: nome e versione con collegamento al testo (per esempio «CC BY 4.0»), più la dicitura di licenza dell'articolo (`license-p`) se c'è;
5. **«Riassunto e tradotto da Quokka (modificato)»**;
6. **non approvazione:** «Gli autori non hanno approvato questa risposta».

Per i testi di legge: ente, atto e data, «GU n. …», «Fonte: Normattiva (testo non ufficiale e gratuito; fa fede la Gazzetta Ufficiale a stampa)», «Riassunto da Quokka».

**Se la citazione non si ripete nella stessa chat** (come nel piano): resta difendibile se la prima citazione di quella fonte nella chat è completa e c'è un elenco «Fonti di questa conversazione» a portata di mano (menu della chat); altrimenti l'asterisco si ripete. ⚖️ rischio basso.

**Citazioni uguali:** due documenti con lo stesso primo autore e lo stesso anno prendono una lettera (2021a, 2021b), assegnata dal codice.

### 4.3 Esempi

**Scheda «Fonte» (articolo CC BY; dati inventati).**
> Rossi M., Bianchi L. (2025). *Titolo dell'articolo.* Nome della rivista. doi:10.xxxx/xxxxx [Apri l'articolo]. © 2025 Rossi et al. Licenza CC BY 4.0 [testo della licenza]. Riassunto e tradotto da Quokka (modificato). Gli autori non hanno approvato questa risposta.

**Scheda «Fonte» (atto).**
> Ministero della Salute, ordinanza del [data], GU n. [numero] del [data]. Fonte: Normattiva (testo non ufficiale e gratuito; fa fede la Gazzetta Ufficiale a stampa). Riassunto da Quokka.

**Pagina «Fonti e licenze»** (Impostazioni → Informazioni; testo di partenza, in attesa della build che la contiene):
> Le risposte di Quokka partono da documenti di terzi: leggi e atti ufficiali, documenti di enti pubblici e articoli scientifici ad accesso aperto. Li usiamo nei limiti delle loro licenze (per esempio CC BY 4.0) e li riassumiamo o traduciamo con parole nostre: per questo ogni riferimento dice «riassunto» o «modificato». Citare un autore o un ente non vuol dire che abbia approvato Quokka o questa risposta, e un riassunto può contenere errori: per capire meglio apri il documento originale dal collegamento; per la salute del tuo animale rivolgiti a un veterinario. I testi di legge vengono da Normattiva, EUR-Lex e dalla Gazzetta Ufficiale: sono gratuiti e non ufficiali. I nomi degli autori vengono dai documenti pubblici e si usano solo per citarli. Se sei titolare dei diritti su un documento e vuoi che lo togliamo o che cambiamo la citazione, scrivi a [indirizzo per i titolari dei diritti: da definire]. Elenco dei documenti: …

### 4.4 Regole di sostanza

1. **La citazione la scrive il codice, non il modello.** Il modello mette solo un segnaposto legato all'identificativo del passo usato; il codice controlla che l'identificativo sia in biblioteca e ne ricava la citazione dai metadati. È il controllo «ogni fonte citata è in biblioteca, con licenza ammessa» del piano, e impedisce citazioni inventate.
2. **Si cita un autore solo per un fatto che il passo contiene.** Una citazione sbagliata attribuisce all'autore cose che non ha scritto (e con i diritti morali è il rischio più concreto per i titolari), e per l'utente è una pratica scorretta (artt. 21–22 Codice del consumo). Il controllo finale del piano («ogni fatto ha dietro un passo») è anche questo.
3. **Nessuna frase che faccia pensare a un'approvazione.** «Secondo [fonte]» sì; «approvato da…», logo, marchio no.
4. **Fedeltà.** Niente distorsioni che possano ledere l'autore: la chat riporta ciò che la fonte dice, con i limiti che la fonte dichiara.
5. **Rimozione e correzione:** §7.

## 5. Testo intero nel database e pezzi ai fornitori negli USA (punto 4)

### 5.1 Licenze

Nessun limite per le licenze aperte. CC BY 4.0 è mondiale, gratuita e non esclusiva: consente di riprodurre il materiale **in tutto o in parte**, in qualsiasi formato, e di produrre e condividere materiale adattato; non lega l'uso a un luogo. Il database in Irlanda (Supabase) è riproduzione; mandare un passo a un fornitore perché generi la risposta **non è «condividere con il pubblico»**: il fornitore agisce per noi come servizio tecnico e per contratto non addestra sui nostri dati. Gli atti ufficiali non sono protetti. I termini dei fornitori fanno carico al cliente dei contenuti che invia (da verificare nel testo di Anthropic): per i testi senza diritti non li avremmo, un motivo in più per tenerli fuori.

### 5.2 Dati personali

I testi in sé **non sono dati personali**, tranne i **nomi degli autori** (e a volte indirizzi e-mail e ringraziamenti). Raccomando:
- si salvano nomi, anno, rivista, DOI; **non** si salvano indirizzi e-mail, telefoni, indirizzi, sezione «autore per la corrispondenza» né ringraziamenti (minimizzazione, art. 5(1)(c) GDPR);
- base: interesse legittimo (art. 6(1)(f)) a rispettare la licenza e citare correttamente; l'informazione agli interessati (art. 14) si dà con la pagina «Fonti e licenze» (da dove vengono i nomi, a chi scrivere): avvisare ogni autore è uno sforzo sproporzionato (art. 14(5)(b)) ⚖️ rischio minimo.

### 5.3 Inventario dei fornitori e consenso: **non cambiano**, finché valgono quattro condizioni

La domanda dell'utente, già ripulita, viaggia verso gli stessi fornitori e con le stesse categorie di dati di oggi; i passi aggiunti non sono dati dell'utente. Conferma quindi la tua lettura. **Cambierebbe** (e prima del rilascio servono una riga in `docs/security/06`, in it/02 e, se serve, nel consenso) se:
1. la **ricerca nella biblioteca** usasse un servizio esterno (per esempio incorporamenti o ricerca per significato) che riceve la domanda: nuovo fornitore o nuovo flusso. Oggi il piano dice «ricerca per parole nel database»: va bene;
2. si mescolassero alla biblioteca **testi dell'utente** (allegati, cartella clinica);
3. ai fornitori andassero **più dati dell'utente** per cercare meglio (nuove categorie del profilo);
4. si usassero **modelli o fornitori nuovi** fuori dal contratto sui dati (vedi [19](19_groq_contratto_conservazione_e_modelli_in_anteprima.md): solo modelli in produzione).

Aggiornamento consigliato, non obbligatorio, a cura della Sicurezza: in `docs/security/06` una riga «estratti di testi pubblici (leggi, articoli aperti): non sono dati personali» nelle righe dei fornitori della chat. Supabase Pro per lo spazio: stesso fornitore e stessa regione, nessun cambio.

### 5.4 Banca dati, accesso e repository

- Le tabelle della biblioteca e del contatore: **RLS attivo e nessuna policy per `anon` e `authenticated`** (le legge solo il backend con la chiave di servizio), con un commento che lo spieghi: così i testi di terzi non possono mai essere serviti al pubblico dal database. L'app **non espone il testo intero**, né un'interfaccia che lo restituisca; mostra citazioni e, se serve, un passo breve.
- **Mai testo di terzi nel repository** (è pubblico), nemmeno CC BY: nel repository stanno gli script, le regole e i metadati, non i testi. I file di prova restano in locale, fuori dal repository.

## 6. Contatore delle domande senza fonte (punto 5)

**Conferma: non è un dato personale**, a queste condizioni (considerando 26 GDPR: dato anonimo se non si può risalire a una persona con mezzi ragionevoli):
1. Si registra **solo** una coppia **specie + tema, scelta da un elenco chiuso**, e si **incrementa un contatore** (riga per specie, tema e settimana): niente riga per evento.
2. Niente testo della domanda, niente identificativo di utente, di sessione, di conversazione, di dispositivo, indirizzo IP, versione dell'app o paese; niente ora precisa (solo la settimana).
3. Niente collegamento con altre tabelle: il contatore non si incrocia con account, piano, animali o consensi.
4. Elenco dei temi **chiuso e generico**: un tema «altro» invece di valori rari che identificherebbero un caso.
5. Tabella chiusa ai client (come in §5.4) e usata solo per le statistiche interne.

Se una delle condizioni cade (per esempio si aggiunge l'identificativo dell'utente «per i duplicati»), diventa un dato personale: base giuridica, informativa e conservazione. **L'operazione che classifica la domanda** (specie e tema) fa parte del trattamento della chat già dichiarato, quindi non serve un consenso nuovo. Una riga facoltativa in it/02 (finalità «migliorare il servizio con conteggi anonimi e aggregati») dà trasparenza.

## 7. Registro minimo per documento e rimozione

**Registro** (interno; nel database accanto al testo, non nel repository). Per ogni documento:
- identificativo, **indirizzo canonico**, DOI se c'è, titolo, autori (solo nomi), ente o rivista, anno;
- **licenza letta** (nome, versione, collegamento) e **dove** è stata letta (pagina, XML, nota del sito), con la **data** del controllo; avviso di copyright (`copyright-statement`) e dicitura di licenza dell'articolo;
- tipo (atto, ente pubblico, articolo), livello della gerarchia, **esito del semaforo** e controllo in 4 punti dell'host;
- come è stato scaricato (API, a mano), data, impronta del testo; segno «solo testo, senza figure né tabelle»;
- eventuale **permesso scritto** (file della risposta, data, ambito, scadenza);
- stato: attivo, in verifica, **tolto** (con motivo e data).

Il controllo si ripete ogni **12 mesi** e a ogni nuovo scarico. Se la licenza di un documento cambia in senso restrittivo, la versione già scaricata resta coperta dalla licenza di allora, ma si ferma l'uso se il titolare chiede di toglierla o si hanno dubbi.

**Rimozione (procedura).** Indirizzo per i titolari dei diritti (nella pagina «Fonti e licenze»). Entro **3 giorni lavorativi** da una richiesta motivata: stato «tolto» per il documento, pezzi tolti dal database e dalle cache, risposta al titolare; il documento resta nell'elenco dei **tolti** perché lo scarico non lo riprenda. Se la richiesta riguarda solo l'attribuzione, si corregge entro 30 giorni (§4.1). Impegno verso i titolari nelle lettere: **al massimo 30 giorni**.

## 8. Lettere ai titolari (punto 6)

### 8.1 A chi e quando

Servono per usare nella biblioteca testi con diritti riservati: **MSD Veterinary Manual** (manuali commerciali), **RECOVER**, **WSAVA**, **ESCCAP**, **ABCD**, **FECAVA**, e analogamente iCatCare e FVE. Contatti degli enti già nel catalogo ([docs/product/15](../product/15_catalogo_fonti_approvate.md) §5 e A.5 del 13); per MSD e RECOVER non ho indirizzi verificati: si cerca il **modulo permessi** sul loro sito. Per la sola richiesta di «non opposizione» sui riassunti di fatti vale la bozza breve di 13 A.5; **questa lettera serve per l'uso del testo**. Ci vogliono settimane: si invia **prima** di caricare i testi, e finché manca la risposta i testi non entrano nell'archivio dell'app.

### 8.2 Prima di inviare

1. **Chi firma.** Oggi non c'è una società ([08](08_punti_aperti_prima_del_lancio.md) punto 58): la firma impegna la persona. Si chiede di **estendere il permesso alla società che gestirà Quokka**. La lettera non cita titoli professionali come garanzia.
2. **Verificare che nulla di quanto si descrive sia già stato fatto** con i testi del destinatario (letti in automatico, conservati, mostrati). Se è successo, la lettera va rivista da un legale prima dell'invio.
3. **Elenco preciso dei documenti** (titolo, anno, indirizzo): meglio chiedere pochi testi precisi che «tutto il sito».
4. Non promettere ciò che non si mantiene: la lettera dice solo cose vere oggi (nessun addestramento; fornitori con divieto contrattuale di addestrare; archivio privato nell'UE; nessuna figura o tabella; nessun logo).
5. **Il compenso** non si offre: si dice che si è disponibili a discuterne. Se la risposta lo chiede, decide il proprietario.

### 8.3 Cosa chiedere (permesso minimo utile)

1. Conservare il testo in un archivio **privato**, su un server nell'Unione europea.
2. Usarne **passi, riassunti e traduzioni** nelle risposte agli utenti, in più lingue, con indicazione della fonte.
3. **Inviare i passi a fornitori di IA** solo per generare la risposta, per contratto senza addestramento.
4. In un'app **a pagamento**, in tutti i paesi in cui è disponibile.
5. Durata: finché l'app è attiva, con **rimozione entro 30 giorni** da una richiesta; **estensione alla società** futura.
6. Citazione **come preferiscono**; nessun logo salvo richiesta.

### 8.4 Testi pronti all'invio

Lettera in italiano e in inglese, paragrafo per gli editori commerciali, modulo di tre campi del MSD Veterinary Manual e sollecito sono nel kit [20a](20a_lettere_permesso_ai_titolari.md). Dal 17 novembre sera la richiesta comprende anche gli **abstract** dei documenti elencati (§12).

### 8.5 Destinatari prioritari

Elenco ordinato e vie di contatto in [20a](20a_lettere_permesso_ai_titolari.md) §2. L'ordine è provvisorio: lo riordino quando la sessione Manuale consegna la mappa di copertura (`.local/chat_eval/biblioteca/copertura.md`).

### 8.6 Dopo la risposta

1. Si **archivia la risposta** (file, data, chi l'ha scritta, ambito, durata) nel registro (§7); il permesso vale solo se scritto e dato da chi ne ha titolo (ufficio diritti o permessi).
2. **Il silenzio non è un consenso.** Un solo sollecito dopo 30 giorni; poi il testo resta fuori.
3. Se la risposta pone **condizioni o un compenso**, decide il proprietario; nessun testo entra finché non sono accettate per iscritto.
4. Un «no» o una condizione non rispettabile si registra e il testo resta escluso (si cerca la stessa informazione in fonti aperte).
5. Il testo effettivamente concesso decide la citazione e le lingue: la scheda «Fonte» si adegua.

## 9. Altri punti che il piano fa emergere

1. **«Valore della rivista» (equivalente dell'impact factor).** L'Impact Factor e i quartili del *Journal Citation Reports* sono dati e marchio di Clarivate: usarli per ordinare la biblioteca o mostrarli in un'app commerciale richiede una licenza (dai termini d'uso, da verificare). **Usare un indicatore aperto**: i dati di OpenAlex sono CC0 (per esempio la media di citazioni a due anni di ciascuna rivista), presi una volta all'ingresso come dice il piano. Nei testi del prodotto lo si chiama «indice di citazione della rivista», non «impact factor». I metadati bibliografici (titolo, autori, anno, rivista, DOI) sono fatti e si prendono liberamente da OpenAlex o Crossref; gli **abstract** sono protetti e si salvano solo se l'articolo è CC BY.
2. **Promesse sulle fonti** (negozio, sito, social): non scrivere «ogni risposta ha una fonte», perché il piano prevede la frase «non ho una fonte su questo». Dire «quando c'è una fonte la indichiamo, quando non c'è lo diciamo» (artt. 21–22 Codice del consumo). Niente «validato da scienziati o veterinari» (nessuna revisione veterinaria, decisione del proprietario).
3. **La PROVA** (150–200 testi): via libera **solo a testi verdi** (§2 e §3), file locali fuori dal repository, registro per documento già nella prova, estratti ai modelli solo di testi verdi (modelli in produzione, vedi [19](19_groq_contratto_conservazione_e_modelli_in_anteprima.md)); nessun testo giallo o rosso nemmeno «per provare»; il rapporto non riporta passi lunghi degli originali (citazioni brevi e riassunti). Domande di prova senza dati personali.
4. **Le 11 schede esistenti** restano come testi della biblioteca: sono nostre, ma poggiano su fonti gialle (WSAVA e altre): entrano come testi **nostri**, con la riga «Fonte» già prevista, non come testo delle fonti.
5. **Documenti del Manuale già letti** (rossi o gialli, [13](13_parere_fonti_scientifiche_e_diritto_d_autore.md) A.3): non entrano nella biblioteca.

## 10. Chi fa che cosa

| Chi | Che cosa |
|---|---|
| **Manuale** | Aggiornare il catalogo (§2.2): Normattiva, Gazzetta Ufficiale, EUR-Lex verdi per gli atti; salute.gov.it e iss.it «verde dopo lettura a mano del documento»; IZSVe rosso. Regole di scarico di Europe PMC (§3.3), registro per documento (§7), nessun blocco aggirato |
| **Chat LLM interna** | Citazione scritta dal codice (§4.4); dati della scheda «Fonte» dal registro; contatore (§6); RLS e tabelle chiuse (§5.4); procedura di rimozione (§7) |
| **Sicurezza** | Riga in `docs/security/06` (§5.3) e controllo che le tabelle della biblioteca non siano esposte |
| **Orchestratore** | Portare al proprietario: lettere (§8), firma e società, pagina «Fonti e licenze» in una build, indirizzo per i titolari; decidere se far confermare i punti ⚖️ da un legale prima del database di produzione |
| **Normativa (io)** | Registro [08](08_punti_aperti_prima_del_lancio.md) punto 68; testo della pagina «Fonti e licenze» e della scheda «Fonte» in 5 lingue quando entrano in una build; rilettura dei permessi ricevuti |

**Aggiunte del 17 novembre sera.** *Manuale:* nessun abstract non aperto (§12), solo metadati. *Chat:* etichetta e avviso del ripiego aggiunti dal codice, nessuna attribuzione a memoria, nessun ripiego per il pericolo e per i minori su temi di salute (§13). *Orchestratore:* decide avviso, etichetta e frase fissa (§13 e §14), porta al proprietario il kit di lettere ([20a](20a_lettere_permesso_ai_titolari.md)). *Normativa:* traduzioni di avviso ed etichetta dopo l'approvazione; riordino dei destinatari quando arriva `copertura.md`.

## 11. Punti ⚖️ per un legale

1. Se il segnale `ai-train=no` e la riserva ex art. 4 di europepmc.org pesano anche sulla lettura da parte di un'IA al momento della domanda, e se un opt-out del gestore incide sugli articoli CC BY dell'API.
2. Se riassunto e traduzione fatti da un modello sono «adattamento» ai fini di CC BY (li trattiamo come tali).
3. Se una citazione non ripetuta nella stessa chat, con elenco delle fonti della conversazione, basta come attribuzione.
4. La clausola di iss.it sugli usi commerciali delle opere protette, e come leggere «salvo ove diversamente indicato» per un documento con licenza non scritta.
5. I diritti morali (art. 20) quando una sintesi di un modello semplifica o distorce un risultato scientifico.
6. La base per i nomi degli autori (interesse legittimo) e l'esenzione dall'informare ogni autore (art. 14(5)(b)).
7. Il valore dei termini d'uso di un sito accettati solo navigando (come per FVE o ESCCAP, [13](13_parere_fonti_scientifiche_e_diritto_d_autore.md) A.1) se in futuro si decidesse di usarne i testi con permesso.
8. L'uso dell'indicatore OpenAlex per ordinare le fonti rispetto all'Impact Factor di Clarivate.
9. Se risposte a memoria su sintomi (senza diagnosi né dosi) restano informazioni generali o possono essere lette come atto della professione veterinaria (art. 348 codice penale, [11](11_esclusioni_responsabilita.md) §3.2).
10. Se l'avviso e l'etichetta del ripiego a memoria bastano per gli utenti di 14–17 anni con le misure richieste da Anthropic (registro [08](08_punti_aperti_prima_del_lancio.md) punto 57).
11. Se, dopo l'abrogazione del DPR 320/1954 (D.Lgs. 136/2022), esista una norma statale sull'osservazione e la segnalazione del cane che ha morsicato o valgano solo i protocolli di Regioni e ASL (§15.2).
12. Se le guide delle agenzie federali USA (FDA, CDC, USDA) sono libere anche in Italia e nell'Unione europea, dove l'art. 5 L. 633/1941 copre solo gli atti ufficiali: la lettura prudente le tratta come «verde con riserva» grazie al permesso espresso delle agenzie (§16.4).
13. Se «trovata in una fonte», con l'avviso che il riscontro è automatico, basta come dichiarazione non ingannevole quando il confronto è fatto da un modello (§16.2).
14. Se la lettura al momento, da parte di un sistema di IA, di una pagina con riserva espressa (termini d'uso o segnale leggibile da macchina) rientra nella copia temporanea (art. 68-bis) o è un'estrazione di testo e dati non coperta (art. 70-quater e 70-septies), anche senza conservare nulla (§18.3).
15. Se l'accumulo nel tempo di note in parole nostre da una banca di dati online è estrazione ripetuta e sistematica di parti non sostanziali (art. 102-bis e 102-ter L. 633/1941; dir. 96/9/CE art. 7(5) e 8) e se il tetto prudenziale per sito è adeguato (§18.4).
16. Se l'indice a tre livelli («Con fonti ufficiali», «In parte con fonti», «Senza fonti») è non ingannevole per il consumatore medio (artt. 21–22 Codice del consumo), dato che il controllo è automatico (§18.5).
17. Se un testo sbagliato prodotto da un'IA che dà informazioni sulla salute degli animali è un «difetto del software» ai fini della direttiva (UE) 2024/2853 (che non tratta come prodotto l'«informazione»), se la morte di un animale è «danno a una cosa» risarcibile per quella via, e a che punto è il recepimento italiano (§20.7, n. 4).
18. Se l'assenza di un percorso d'urgenza, per una funzione che tratta sintomi e salute degli animali e che sarà usata prevedibilmente anche in emergenza, è colpa nella progettazione (artt. 1176 e 2043 c.c.) nonostante avvisi uguali per tutti, una regola «mai giudicare la gravità del caso» e un cancello di prova (§20.7, n. 1–3).
19. Se la traduzione non ufficiale di un atto straniero, fatta dall'amministrazione che lo ha emanato (come l'inglese dell'USAV per l'ordinanza svizzera sugli animali), è protetta in Italia: l'art. 5 L. 633/1941 non la nomina, la Convenzione di Berna (art. 2, c. 4) rinvia alle leggi nazionali e l'art. 5, c. 2, URG protegge in Svizzera solo le traduzioni ufficiali (§21.2).
20. Se una traduzione vicina di un testo protetto, pubblicata nella cronologia di un repository pubblico, è una riproduzione o un'elaborazione illecita (artt. 16 e 18 L. 633/1941) anche se poi sostituita da una versione in parole proprie, e se serve riscrivere la cronologia (§22.3, n. 4).
21. Se leggere pagine pubbliche con un nome di browser contro i termini d'uso o contro un `robots.txt` scritto per nome è una violazione contrattuale azionabile nell'Unione europea, un'elusione di misure tecnologiche (art. 102-quater L. 633/1941) o un accesso abusivo (art. 615-ter c.p.), e se il passaggio al browser dopo una sfida anti-robot cambia la valutazione (§22.3, n. 1–3).
22. Se un filtro automatico che applica la tabella di §23 (licenza dichiarata, elenco chiuso di portali per gli atti ufficiali, controlli di accesso) basta come controllo per documento per le licenze aperte e per l'attribuzione CC BY, senza lettura umana e con il silenzio del proprietario come assenso di prodotto; e se l'elenco di §23.3 (Spagna art. 13 LPI, Paesi Bassi art. 11 Auteurswet, Australia, Nuova Zelanda s. 27, Canada, USA §105 fuori dagli USA) regge per l'uso in tutti i Paesi in cui l'app è offerta, e se le versioni consolidate non ufficiali dei portali (Germania, Spagna, Regno Unito) restano coperte dalle norme sugli atti ufficiali.
23. Se i documenti pubblicati da una pubblica amministrazione italiana senza licenza espressa sono dati aperti per legge (art. 52, c. 2, CAD) anche quando il sito riporta «tutti i diritti riservati» sui documenti, e se per le leggi e i regolamenti regionali la riserva del portale è ininfluente (art. 5 L. 633/1941) (§23.11).
24. Se la clausola «Quokka non gestisce le urgenze», scritta come descrizione del servizio, esce dal giudizio di vessatorietà (art. 34, c. 2, Codice del consumo) e dall'art. 1341, c. 2, c.c.; e se l'approvazione specifica delle altre clausole dei Termini è dovuta nei contratti con consumatori ([22](22_clausola_quokka_non_gestisce_urgenze.md) §3).

## 12. Abstract e metadati (aggiunta del 17 novembre sera)

**Domanda** (proposta del proprietario, via Orchestratore): rispondere dagli abstract quando il testo intero ha diritti riservati. Si possono scaricare, conservare sul server e dare al modello gli abstract di articoli non aperti (PubMed, Europe PMC, siti degli editori)? Se la conservazione non è ammessa, si possono almeno tenere e citare i metadati?

**Risposta.** **No** agli abstract di articoli non aperti; **sì** ai metadati. Fino a nuovo avviso nessuno scarica abstract non aperti.

### 12.1 Perché

1. **L'abstract non è un metadato**: è testo scritto da autori o editori, protetto come il resto dell'articolo. Che PubMed o Europe PMC lo mostrino gratis e lo rendano scaricabile non lo rende riusabile.
2. **NLM** (note web, lette il 17 novembre): riprodurre materiale protetto oltre il fair use degli Stati Uniti richiede il permesso scritto del titolare; spetta a chi usa verificare i diritti e NLM non ne garantisce lo stato per nessun elemento. Da una ricerca (non riletto alla fonte): NLM dichiara di non detenere i diritti sugli abstract di PubMed, che restano agli editori.
3. **Europe PMC** (avviso di copyright, 17 novembre): il materiale è degli editori e degli autori e i servizi automatici sono pensati per il sottoinsieme aperto; il fatto che l'API restituisca l'abstract di un record non aperto non è un permesso.
4. **«Abstract aperti» di Crossref** (iniziativa I4OA): gli editori aderenti li rendono consultabili tramite Crossref, ma non ho trovato una licenza di riuso (blog di Crossref e commenti, 17 novembre): si trattano come protetti.
5. **Conservare** gli abstract sul server è riproduzione permanente; **darli al modello** è un invio a un fornitore. L'eccezione sull'estrazione di testo e dati (art. 70-quater) non regge (copie permanenti e riserve dei diritti: §2.4 e [13](13_parere_fonti_scientifiche_e_diritto_d_autore.md) A.3); l'art. 70 L. 633/1941 (riassunto e citazione per critica o discussione) non copre un archivio né un uso sistematico; in UE non c'è un fair use generale.

### 12.2 Che cosa è ammesso

| Elemento | Ammesso? | Condizioni |
|---|---|---|
| Abstract di articoli con licenza cc by, cc0 o pubblico dominio | Sì | Come l'articolo (§3): filtro sul campo `license` e sul file XML, attribuzione (§4). In PubMed la licenza può stare nell'elemento `CopyrightInformation` dell'abstract |
| Abstract di articoli NC, ND, SA, a diritti riservati o senza licenza (PubMed, Europe PMC, siti degli editori, Crossref) | **No** | Né scaricarli, né conservarli, né darli al modello, nemmeno «per provare» |
| Frasi tratte da un abstract, anche un solo periodo | No | Espressione protetta; la citazione breve dell'art. 70 non basta per un uso sistematico a fini commerciali |
| **Metadati**: titolo, autori, anno, rivista, DOI o PMID, lingua, tipo di documento | **Sì** | Fatti bibliografici; fonti libere (OpenAlex è CC0, Crossref). Si conservano e si citano |
| Parole chiave degli autori e termini MeSH | Con cautela | Brevi e fattuali: ammessi come metadati, mai come testo continuo |

### 12.3 Come si usano i metadati

1. Come **riferimento «per approfondire»**: titolo, autori, anno e collegamento, senza dire che la chat li ha letti.
2. Per **trovare** testi aperti sullo stesso tema e per **preparare le richieste di permesso** (20a).
3. Per **misurare che cosa manca** (insieme al contatore del §6).
4. **Non** come prova di una frase: la chat non cita «Autore, AAAA» per un fatto che il modello non ha letto: sarebbe una citazione falsa, che inganna l'utente e attribuisce all'autore ciò che non ha scritto (§4.4). Lo impedisce già il controllo del piano («ogni fatto ha dietro un passo») insieme alla regola «la citazione la scrive il codice dai passi usati».

### 12.4 Regola tecnica per il bibliotecario

L'API di Europe PMC restituisce l'abstract di quasi tutti i record, anche non aperti: la disponibilità tecnica non è un permesso. Si controlla `license` **prima** di salvare qualsiasi testo; per i record non aperti si salvano solo i metadati. Per coprire un tema senza abstract: i permessi (20a), le fonti aperte sullo stesso fatto, le licenze a pagamento con gli editori (fuori portata per ora).

## 13. Ripiego a memoria dopo il sì dell'utente (aggiunta del 17 novembre sera)

> **Superato il 20 novembre dal [piano 08](../llm/08_piano_quokka_risponde_biblioteca_verifica.md):** la chat risponde sempre e non c'è più l'offerta con i due pulsanti. Che cosa decade e che cosa resta: §16.1.
>
> **Correzione del 20 novembre notte:** l'apertura urgente di [11](11_esclusioni_responsabilita.md) §3.2, citata nel §13.3 n. 6 e nel §13.4, **non è un obbligo di legge** ma una cautela; dopo la decisione del proprietario non c'è più un percorso d'urgenza: §20.

**Flusso proposto.** La biblioteca non trova nulla → la chat lo dice e offre di rispondere con le conoscenze generali dell'IA → solo dopo il sì dell'utente risponde il modello a memoria, con un'etichetta.

**Risposta.** È lecito e non ingannevole a quattro condizioni: l'utente sceglie dopo aver capito che cosa significa; **ogni** risposta a memoria porta l'etichetta; il pericolo non passa mai da qui; valgono le stesse regole di sicurezza della modalità con fonti.

### 13.1 Testi proposti (italiano; le altre lingue dopo l'approvazione)

| Dove | Testo |
|---|---|
| **Avviso quando non c'è una fonte** (messaggio a regole, senza badge IA: [01](01_ai_disclosure.md)) | «Non ho trovato una fonte su questo tra quelle che ho a disposizione (leggi, enti pubblici, articoli scientifici ad accesso aperto). Se hai dubbi, rivolgiti a un veterinario o a un altro specialista; in caso di emergenza chiama subito il tuo veterinario o la clinica più vicina. Se vuoi, posso comunque risponderti con le conoscenze generali dell'intelligenza artificiale: non sono verificate su fonti e possono essere incomplete o sbagliate.» |
| **Pulsanti** (stesso peso visivo) | «Sì, rispondi con le conoscenze generali» · «No, grazie» |
| **Etichetta**, in testo, all'inizio di ogni risposta a memoria (con il badge «Generato da IA») | «Risposta dalle conoscenze generali dell'IA, senza fonti verificate: può essere incompleta o sbagliata. Non è una visita né una diagnosi.» |
| **Etichetta breve** (intestazione del messaggio) | «Senza fonti verificate» |
| **Se l'utente dice no** | La frase fissa del §14 |

### 13.2 Perché questi testi

- **«tra quelle che ho a disposizione»** al posto di «nelle fonti ufficiali e autorevoli non ho trovato nulla»: la seconda può far credere che non esista nulla di ufficiale sul tema (omissione o azione ingannevole, artt. 21–22 Codice del consumo). La biblioteca è una selezione, e il testo lo dice.
- **Le «conoscenze generali dell'IA»** sono spiegate: non verificate, incomplete o sbagliate.
- **Frasi già approvate**: «può sbagliare», «non è una visita né una diagnosi», «in caso di emergenza chiama subito…» vengono da [11](11_esclusioni_responsabilita.md) §3.2 e dall'avviso T-A: l'utente vede le stesse parole.
- **In testo, non solo icona o colore**: l'etichetta resta quando si copia o si fa una schermata e si legge con le tecnologie assistive. Il badge «Generato da IA» (art. 50 AI Act, [01](01_ai_disclosure.md)) resta, e l'etichetta si aggiunge.

### 13.3 Regole per la Chat

1. L'etichetta la aggiunge il **codice**, non il modello, in **ogni** risposta a memoria (non una volta per chat).
2. **Una scelta per domanda**: il sì vale per quella domanda; niente «rispondi sempre a memoria»; niente nuova offerta se la stessa domanda si ripete.
3. Pulsanti con lo stesso peso, «No, grazie» sempre presente, nessuna frase che spinga.
4. Stesse regole di sicurezza della modalità con fonti ([07](../llm/07_piano_chat_dalla_biblioteca.md), «Restano fuori dalla discussione»): mai dosi, mai scelta di farmaci, mai diagnosi (art. 348 codice penale ⚖️, [11](11_esclusioni_responsabilita.md) §3.2), mai autolesionismo o danni a persone; anonimizzazione e consensi invariati.
5. **Niente attribuzioni a memoria**: il modello non cita enti, autori, studi, linee guida, numeri di studi né collegamenti (non può verificarli: sarebbe un'attribuzione falsa, §4.4); un controllo del codice toglie «secondo [ente o studio]» e i collegamenti.
6. **Stesso controllo di pericolo** prima e dopo la risposta: se emerge un pericolo, la risposta si apre con il testo di urgenza già approvato («Questa situazione può essere urgente. Non aspettare: contatta subito un veterinario. Quokka non può valutare il tuo animale.»).
7. Nessun asterisco e nessuna riga «Fonte»: l'etichetta ne prende il posto.
8. Contatori anonimi (§6): quante volte si offre il ripiego e quante si accetta.

### 13.4 Limiti

- **Pericolo o urgenza riconosciuti**: **niente offerta di ripiego**; la risposta si apre con il testo di urgenza di [11](11_esclusioni_responsabilita.md) §3.2. Il ripiego non può diventare un'alternativa al veterinario (ritarderebbe la cura). La classificazione può sbagliare: per questo l'avviso contiene sempre «in caso di emergenza chiama subito…».
- **Temi di salute senza pericolo**: ammessi solo come informazioni generali e prudenti, con la riga «Per la salute del tuo animale decide il veterinario»; mai dosi, farmaci né diagnosi.
- **Minori di 14–17 anni**: la legge non vieta il ripiego, ma Anthropic chiede misure per i minori ([14](14_anthropic_contratto_conservazione_e_regole_d_uso.md) §1, registro punto 57: se si resta a 14 anni, con le misure). Raccomando: per i minori **nessun ripiego su salute, sintomi, farmaci e comportamenti pericolosi** (si rimanda a un adulto e al veterinario); sugli altri temi, stesso avviso in parole semplici. Se il backend non conosce la fascia d'età, vale la regola prudente per chi risulta minorenne.
- **Lingue**: avviso, pulsanti ed etichetta nelle 5 lingue; le traduzioni le preparo quando il testo italiano è approvato e passano da Revisione traduzioni.
- **Dati personali**: nessun cambio (stessa ripulitura, stessi fornitori dichiarati); consenso v5 e informativa invariati.
- **Natura del «sì»**: è una scelta di prodotto, non un consenso GDPR; non si registra per ogni utente (basta il contatore anonimo).

## 14. Frase fissa quando manca la fonte (aggiunta del 17 novembre sera)

> **Superata il 20 novembre dal piano 08** (senza testo la frase resta senza asterisco, nessun messaggio fisso): §16.1. Resta valido il ragionamento sul pericolo evidente.

**Proposta dell'Orchestratore:** «Non ho una fonte su questo; se lo reputi necessario, rivolgiti a uno specialista.»

- **Senza pericolo va bene, con due ritocchi**: «se hai dubbi» invece di «se lo reputi necessario» (non lascia la valutazione al solo utente) e «a un veterinario o a uno specialista» invece di «a uno specialista» (per chi ha un animale non è chiaro chi sia lo «specialista»): **«Non ho una fonte su questo; se hai dubbi, rivolgiti a un veterinario o a uno specialista.»**
- **Con pericolo evidente è un problema** e non deve mai comparire da sola: «se lo reputi necessario» affida all'utente una valutazione di urgenza che l'app ha già riconosciuto, e «specialista» è vago. La risposta si apre con il testo di urgenza di [11](11_esclusioni_responsabilita.md) §3.2 (indipendente dalle fonti); la frase fissa può seguire solo per la parte senza fonte («Su questo non ho una fonte da citarti.»). Per il pericolo verso le persone (morsi, aggressioni): pronto soccorso o numero di emergenza, prima di tutto.
- È un messaggio a regole: `ai_generated = False`, senza badge ([01](01_ai_disclosure.md)).

## 15. Atti pubblici per i casi 37 e 60: vigenza e riferimenti (aggiunta del 17 novembre sera)

**Richiesta dell'Orchestratore:** (1) vigenza dell'O.M. 6/8/2013 (l'art. 7 dice «efficacia 12 mesi»); (2) riferimenti corretti per la segnalazione del morso (DPR 320/1954 art. 86), la responsabilità (art. 2052 c.c.) e l'obbligo di assicurazione in provincia di Bolzano; (3) conferma della riga fonte di Normattiva. Controllato sulle fonti ufficiali (Gazzetta Ufficiale, Normattiva, Lexbrowser della Provincia autonoma di Bolzano, Ministero della Salute) il 17 novembre 2026.

**In breve.** (1) L'ordinanza è **in vigore**: prorogata ogni anno, l'ultima il 16 luglio 2026 per 12 mesi dal 5 settembre 2026; il testo da usare è quello del 2013 **come modificato dall'O.M. 3 agosto 2015** (cambia l'art. 1, c. 5). (2) Il **DPR 320/1954 è abrogato** per intero, art. 86 compreso, dal D.Lgs. 136/2022: non è più una norma da citare. L'art. 2052 c.c. è in vigore e invariato. In Alto Adige **non risulta un obbligo generale di assicurazione RC per i cani**: c'è solo quello statale per i cani iscritti nel registro «a rischio elevato». (3) La riga fonte di Normattiva va **completata** («testo non ufficiale e gratuito»).

### 15.1 O.M. 6 agosto 2013: in vigore, prorogata, con una modifica

| Atto | Gazzetta Ufficiale | Che cosa fa |
|---|---|---|
| O.M. 6 agosto 2013 | n. 209 del 6/9/2013 (13A07313) | Testo base; art. 7: efficacia 12 mesi dalla pubblicazione |
| O.M. 28 agosto 2014 | n. 208 dell'8/9/2014 (14A06915) | Proroga di 12 mesi, nessuna modifica |
| O.M. 3 agosto 2015 | n. 209 del 9/9/2015 (15A06718) | «Proroga, con modifica»: **sostituisce l'art. 1, c. 5** (i comuni e i servizi veterinari delle ASL «possono» organizzare i percorsi formativi, il «patentino»; possono promuoverli anche veterinari liberi professionisti) e proroga di 12 mesi |
| Proroghe 2016–2024 | non riletto atto per atto | Solo proroga: le premesse del 2025 e del 2026 non citano altri atti «con modifica» |
| O.M. 10 luglio 2025 | n. 192 del 20/8/2025 (25A04616) | Proroga di 12 mesi dal 4/9/2025 |
| **O.M. 16 luglio 2026** | **n. 206 del 5/9/2026 (26A04624)** | **Proroga di 12 mesi dal 5/9/2026** (fino a inizio settembre 2027); le premesse parlano ancora di «nelle more» di una disciplina organica |

- **Testo in vigore:** l'O.M. del 2013 come modificata dal 2015. Restano come nel 2013, tra l'altro: responsabilità civile e penale del proprietario (art. 1, c. 1); guinzaglio fino a 1,50 m nelle aree urbane e nei luoghi aperti al pubblico, salvo le aree per cani, e museruola sempre con sé da applicare se c'è rischio o su richiesta delle autorità (c. 3, lett. a e b); raccolta delle feci (c. 4); art. 3 (dopo una morsicatura o un'aggressione i servizi veterinari attivano un percorso di accertamento; registro dei cani a rischio elevato; polizza di responsabilità civile, guinzaglio e museruola per chi vi è iscritto); art. 4 (divieti di possesso); art. 5 (esclusioni, per esempio i cani da pastore per guinzaglio e museruola).
- **Pagina del Ministero** («Tutela dall'aggressione dei cani», aggiornata il 7/9/2026, CC BY 4.0): è un buon riassunto, ma dice che i comuni «devono» mettere a disposizione i percorsi formativi, mentre il testo modificato dice «possono»: **prevale il testo dell'atto**. Come testi della biblioteca: gli atti; la pagina solo come guida, con questa avvertenza.
- **Che cosa mettere nella biblioteca:** l'O.M. 2013 (già presente), l'O.M. 3/8/2015 e l'O.M. 16/7/2026 (due testi brevi). Il testo del 2013 resta com'è (regola «testo originale» del [doc 21](../product/21_biblioteca_regole_di_ammissione.md)): la sostituzione dell'art. 1, c. 5 va nella scheda, non nel testo.
- **Avvertenza di vigenza** (campo `avvertenza_vigenza` dell'O.M. 2013): «Ordinanza contingibile e urgente a termine, in vigore come modificata dall'O.M. 3/8/2015 (art. 1, c. 5 sostituito: percorsi formativi facoltativi) e prorogata ogni anno; ultima proroga O.M. 16/7/2026 (GU n. 206 del 5/9/2026), 12 mesi dal 5/9/2026. Il richiamo agli artt. 86 e 87 del DPR 320/1954 (art. 3, c. 1) è superato: il DPR è abrogato dal D.Lgs. 136/2022. Da riverificare ogni settembre.» Nella risposta si dice «ordinanza ministeriale, prorogata ogni anno», non «legge».
- **Limite:** l'ordinanza non copre le regole dei singoli comuni e delle regioni (caso 60: ordinanze comunali): la chat rimanda al proprio Comune e alla ASL.

### 15.2 Segnalazione del morso: il DPR 320/1954 non è più in vigore

- **Verificato** su Normattiva (testo vigente al 17/11/2026): tutti i 165 articoli del Regolamento di polizia veterinaria, l'art. 86 compreso, risultano «abrogati dal D.Lgs. 5 agosto 2022, n. 136»; l'art. 32, c. 1, lett. u) di quel decreto (GU del 12/9/2022) abroga il DPR dalla sua entrata in vigore.
- **Che cosa diceva l'art. 86** (testo originale, GU 1954): isolamento e osservazione per 10 giorni, nei canili comunali, dei cani e dei gatti che hanno morsicato, con osservazione a domicilio su richiesta. Non era una «segnalazione» in senso stretto, e oggi non vale più. L'art. 3, c. 1 dell'O.M. lo richiama ancora («fatto salvo quanto stabilito dagli articoli 86 e 87»), ma le premesse del 2026 non citano più il DPR (tra i «visto» c'è il D.Lgs. 136/2022): richiamo superato.
- **Che cosa vale oggi:** art. 3, c. 1 dell'O.M. (a seguito di morsicatura o aggressione i servizi veterinari attivano un percorso mirato all'accertamento delle condizioni dell'animale e della corretta gestione) e art. 1, c. 6 (il veterinario libero professionista segnala alla ASL i cani che richiedono una valutazione comportamentale). Per le modalità di segnalazione e di osservazione dopo un morso **non ho trovato una norma statale che sostituisca l'art. 86**: valgono i protocolli di Regioni e ASL, non uniformi. La chat rimanda al Servizio veterinario della ASL e al medico o al pronto soccorso per la persona morsa, **senza dire «10 giorni» come obbligo di legge**. ⚖️
- **Non scaricare** il DPR 320/1954 come testo vigente.

### 15.3 Responsabilità: art. 2052 del Codice civile

- Testo (Normattiva, vigente al 17/11/2026; nessuna modifica registrata; uguale a quello della Gazzetta Ufficiale 1942): «Il proprietario di un animale o chi se ne serve per il tempo in cui lo ha in uso, è responsabile dei danni cagionati dall'animale, sia che fosse sotto la sua custodia, sia che fosse smarrito o fuggito, salvo che provi il caso fortuito.» Collegato all'art. 1, c. 1 dell'O.M.
- **Come scaricare solo l'articolo:** la pagina dell'articolo sulla Gazzetta Ufficiale è leggera e dà il testo del 1942, uguale al vigente: `gazzettaufficiale.it/atto/serie_generale/caricaArticolo?art.progressivo=0&art.idArticolo=2052&art.versione=1&art.codiceRedazionale=042U0262&art.dataPubblicazioneGazzetta=1942-04-04&art.idGruppo=258&art.idSottoArticolo1=10&art.idSottoArticolo=1&art.flagTipoArticolo=2`. Normattiva restituisce l'intero codice (10 MB in Akoma Ntoso): si taglia da «Art. 2052.».
- Citazione breve: «Art. 2052 c.c.».

### 15.4 Alto Adige: nessun obbligo generale di assicurazione RC per i cani

- **Letti per intero sul Lexbrowser** (17/11/2026): la legge provinciale 15 maggio 2000, n. 9 («Interventi per la protezione degli animali e prevenzione del randagismo», B.U. 30/5/2000, n. 23, Suppl. 2) e il D.P.P. 8 luglio 2013, n. 19 (regolamento di esecuzione, B.U. 16/7/2013, n. 29). **Nessuna disposizione impone ai proprietari di cani una polizza di responsabilità civile**: le uniche occorrenze di «assicur-» riguardano l'assicurazione delle guardie zoofile e i premi per i volontari.
- **Che cosa dicono sui cani:** art. 6 L.P. (anagrafe; dal 1/1/2022 profilo genetico a spese del proprietario, con le esenzioni dei cc. 4-bis e 4-ter, L.P. 2/2024; i cani pericolosi in una sezione dell'anagrafe); art. 17 DPP 19/2013 (definizione di cane pericoloso, elenco tenuto dal Servizio veterinario, museruola e guinzaglio nei luoghi accessibili al pubblico, eutanasia consigliata in casi estremi).
- **L'unico obbligo di polizza è statale** e vale anche in Alto Adige: O.M. art. 3, c. 4, per i proprietari dei cani iscritti nel registro dei cani «a rischio elevato» (con guinzaglio e museruola). Da una ricerca (non riletto): la Corte costituzionale (sent. 222/2006) ha riconosciuto allo Stato il potere di adottare ordinanze di questo tipo, su ricorso della Provincia di Bolzano.
- **Per il caso 37** la chat può dire: «Non risulta un obbligo generale di assicurazione per i cani in Alto Adige; c'è per i proprietari di cani iscritti nel registro dei cani a rischio elevato (ordinanza ministeriale). Il proprietario risponde comunque dei danni (art. 2052 c.c.): un'assicurazione è prudente.» Limite: letti i testi provinciali, non i regolamenti dei singoli comuni.
- **Testi per la biblioteca:** L.P. 9/2000, art. 6, e D.P.P. 19/2013, artt. 16/bis e 17: atti ufficiali (art. 5 L. 633/1941): si prende il testo, non le note né le massime del sito. Fonte: «Lexbrowser, Provincia autonoma di Bolzano (testo consolidato); fa fede il Bollettino Ufficiale» (non ho trovato una nota legale sul sito: da riverificare). Il sito limita le richieste (pagina «TooManyRequests»): una pagina alla volta, con pause; **mai aggirare il limite**.

### 15.5 Normattiva: la riga fonte

- **Avviso legale letto il 17/11** (§2.2): la riproduzione dei testi elettronici è consentita se si menzionano **la fonte, il carattere non autentico e la gratuità**; l'unico testo ufficiale è la Gazzetta Ufficiale a stampa. La stessa dicitura è sulla home della Gazzetta Ufficiale.
- **Riga fonte completa:** «Fonte: Normattiva (testo non ufficiale e gratuito; fa fede la Gazzetta Ufficiale a stampa)»; per un testo preso dalla Gazzetta Ufficiale: «Fonte: Gazzetta Ufficiale (testo elettronico non autentico e gratuito; fa fede l'edizione a stampa)». La forma breve «Normattiva, testo non ufficiale» **non basta** (manca «gratuito»): corretta in §2.2.
- **Scarico tecnico:** le funzioni di esportazione del portale (Akoma Ntoso: `normattiva.it/do/atto/caricaAKN?dataGU=AAAAMMGG&codiceRedaz=…&dataVigenza=AAAAMMGG`), una richiesta alla volta; mai le pagine di ricerca (robots.txt).

### 15.6 Che cosa fare adesso

1. **Manuale:** aggiornare `avvertenza_vigenza` dell'O.M. 2013 (testo in §15.1) e aggiungere l'O.M. 3/8/2015 e l'O.M. 16/7/2026; **non** aggiungere il DPR 320/1954; aggiungere art. 2052 c.c., L.P. 9/2000 art. 6, D.P.P. 19/2013 artt. 16/bis e 17.
2. **Chat:** dire «ordinanza ministeriale, prorogata ogni anno» e non «legge»; non citare «10 giorni» né l'art. 86; per l'Alto Adige usare la formulazione del §15.4; per il caso 60 rimandare al Comune.
3. **Riverifica ogni settembre** (cercare l'ordinanza di proroga in Gazzetta Ufficiale) e a ogni nuova ordinanza; registrare la data del controllo.

## 16. Piano 08 (20 novembre): riga di trasparenza, persona ferita, licenze delle guide per proprietari

**Richiesta dell'Orchestratore** sul [piano 08](../llm/08_piano_quokka_risponde_biblioteca_verifica.md) («Quokka risponde, la biblioteca verifica e cita»): tre pareri brevi. Pagine ufficiali lette il 20 novembre 2026.

### 16.1 Che cosa decade e che cosa resta

| Testo o regola | Dopo il piano 08 |
|---|---|
| Avviso «Non ho trovato una fonte…» con offerta e due pulsanti (§13.1) | **Decade** |
| Etichetta lunga e breve su ogni risposta a memoria (§13.1) | **Decade**: la sostituiscono la riga una volta per chat (§16.2), l'asterisco e la scheda «Fonte» (§4.2) |
| Frase fissa «Non ho una fonte su questo…» (§14) | **Decade**: senza testo, la frase resta senza asterisco |
| Regole §13.3 n. 1–3 e 7–8 (etichetta per risposta, una scelta per domanda, pulsanti, contatori) e limiti §13.4 sul ripiego | **Decadono** |
| Regole §13.3 n. 4–5: mai dosi, farmaci, diagnosi; **niente attribuzioni a memoria** (il modello non cita enti, autori, studi, link: la citazione la scrive il codice) | **Restano** per tutta la chat (la seconda conta ancora di più) |
| Regola §13.3 n. 6: stesso controllo di pericolo prima e dopo la risposta, con apertura urgente | **Decade** dopo la decisione del proprietario (nessuna corsia per le urgenze): §20.3 |
| Apertura urgente di [11](11_esclusioni_responsabilita.md) §3.2: «Questa situazione può essere urgente. Non aspettare: contatta subito un veterinario. Quokka non può valutare il tuo animale.» | **Non si usa più come percorso** (decisione del proprietario riferita il 20 novembre). **Non era un obbligo di legge**: correzione al «resta valida e obbligatoria» scritto qui prima, era una cautela. Il testo storico è un modello per gli avvisi uguali per tutti: §20.4 |
| Riga fissa sotto il campo di scrittura, avviso T-A (`noticeChatAi`), badge «Generato da IA» | **Restano** |
| Misure per i minori di 14–17 anni (registro 08, punto 57) | **Restano** (valgono per tutta la chat, non solo per il vecchio ripiego) |

### 16.2 Riga di trasparenza

**Testo proposto** (italiano, prima persona come `chatAiNotice`; le altre lingue dopo l'approvazione):
> Rispondo con un'intelligenza artificiale e posso sbagliare. Le frasi con l'asterisco* le ho trovate in una fonte che ti indico (controllo automatico: la fonte può non valere per il tuo caso). Le altre vengono dalle conoscenze generali dell'IA e possono essere incomplete o sbagliate. Non sostituisco il veterinario.

**Versione breve** (spazi stretti): «Le frasi con * sono trovate in una fonte (controllo automatico); le altre vengono dalle conoscenze generali dell'IA e possono sbagliare.»

- **«Trovata in una fonte», non «verificata».** «Verificata» promette un controllo affidabile e che la fonte valga per il caso; il confronto è automatico, nella prova la fedeltà delle citazioni era 1,89 su 2 (non 2), e alcune fonti sono di altri Paesi (la scheda «Fonte» deve dire il Paese, per esempio «guida del governo scozzese»). Da evitare anche «validata», «convalidata», «controllata da esperti». ⚖️ rischio basso se si resta su «trovata».
- **Una volta per chat basta**, come primo messaggio dell'assistente (non in un menu), **se restano tre cose**: il badge «Generato da IA» su ogni risposta, la riga fissa sotto il campo di scrittura («può sbagliare… in emergenza chiama subito…») e la scheda «Fonte» dietro ogni asterisco (con «riscontro automatico» e «gli autori non hanno approvato questa risposta»). Base: art. 50(1) AI Act (avviso all'inizio dell'interazione, già coperto dal badge) e, per la parte «cosa è confermato», la non ingannevolezza (artt. 21–22 Codice del consumo) soddisfatta da asterisco, scheda e riga fissa. **Consigliato, non obbligatorio:** una didascalia piccola per risposta («Con fonti: 2» / «Nessuna frase con fonte»), perché l'asterisco spiega ciò che è confermato ma non dice che «nessun asterisco» significa «non confermato».
- **Minori di 14–17 anni:** nessun cambio di legge: la chat risponde già dalle conoscenze generali, come oggi, con le misure del punto 57. La riga è in parole semplici e va bene così; non serve una versione diversa.
- **Che cosa non promettere in negozio e sul sito:** «risposte verificate, validate, certificate»; «controllate da veterinari o esperti» (nessuna revisione veterinaria, decisione del proprietario); «ogni risposta ha una fonte» o percentuali non misurate e non aggiornate; «basato sull'evidenza» o «sulle linee guida ufficiali» in generale; «affidabile», «senza errori», «sostituisce una visita», «diagnosi», «cura», gestione di emergenze; **nomi o loghi degli enti citati** (CDC, Ministero, ECDC… come se fossero partner o approvassero: le licenze e l'OGL lo vietano, il CDC minaccia segnalazioni); «aggiornato alle ultime norme» (le ordinanze scadono). **Si può dire:** «Quando una frase trova riscontro in una fonte (leggi, guide di enti pubblici, articoli scientifici ad accesso aperto), la segniamo con un asterisco e citiamo la fonte. Il resto viene dalle conoscenze generali di un'IA e può sbagliare. Non sostituisce il veterinario.» La pagina «Fonti e licenze» (§4.3) resta obbligatoria.

### 16.3 Frase per la persona ferita

La frase della Chat, «Se una persona è ferita o in pericolo, vai al pronto soccorso o chiama il 112.», è **approvata con due ritocchi**:
1. **L'ordine e l'urgenza:** «Se una persona è ferita o in pericolo, chiama subito il 112 o vai al pronto soccorso.» (con una ferita grave non ci si sposta da soli).
2. **Il Paese:** *superato il 21 novembre 2026: nessun numero di telefono nei testi fissi, per nessun Paese.*

Va **prima** di ogni altra riga quando c'è una persona ferita (le persone prima). Dal 20 novembre notte non c'è più un'apertura urgente per l'animale (§20): la frase si ripete nella riga fissa (§20.5).

### 16.4 Licenze per la «biblioteca per proprietari»

Valgono le regole del §2 (licenza scritta per documento, attribuzione, niente loghi né stemmi, niente materiale di terzi, controllo in 4 punti prima di una lettura automatica). Letto il 20 novembre:

| Ente | Esito | Condizioni |
|---|---|---|
| **Galles** (gov.wales) | Verde | Dichiara l'uso libero dell'informazione (loghi esclusi) con l'Open Government Licence v3.0. Il logo del governo gallese è soggetto a permesso |
| **Irlanda del Nord** (nidirect) | Verde | Stessa formula con OGL v3.0; esclusi loghi, stemmi e Royal Arms, e materiale di terzi (le mappe e i dati di Land & Property Services hanno una licenza a parte: da una ricerca). Condizione OGL: attribuzione («Contains public sector information licensed under the Open Government Licence v3.0») e collegamento alla licenza; non far pensare ad approvazione |
| **Australia, enti del Commonwealth** (per esempio DAFF) | Verde | CC BY 4.0 «salvo diversa indicazione»; esclusi lo stemma del Commonwealth, il logo del dipartimento e i contenuti di terzi etichettati; attribuzione nel formato indicato. **Stati e territori:** ogni sito ha la sua nota (di solito CC BY, con eccezioni): da leggere uno per uno, non letti |
| **Nuova Zelanda** (per esempio MPI) | Verde | Copyright della Corona con CC BY 4.0 «salvo diversa indicazione»; esclusi emblemi, stemmi, loghi e materiale di terzi. **Attribuzione diversa se si adatta il testo** (riassunto o traduzione): «This work is based on/includes MPI data which is licensed by MPI for re-use under the Creative Commons Attribution 4.0 International licence». Documenti più vecchi: CC BY 3.0 (ammessa; da una ricerca) |
| **ECDC** | Verde | CC BY 4.0 «salvo diversa indicazione», anche per uso commerciale e adattamenti, a tre condizioni insieme: ECDC come autore, collegamento alla licenza, indicazione delle modifiche. Esclusi i contenuti di terzi (anche i dati di terzi nelle banche dati) e il logo |
| **EFSA, pagine del sito** | Verde con avvertenza | Riuso autorizzato citando EFSA come fonte (la nota non indica limiti NC o ND); **le condizioni dei singoli documenti prevalgono**; logo escluso; se il testo adottato differisce dalla pagina, prevale quello adottato |
| **EFSA, pareri scientifici (EFSA Journal)** | **Escluso** | Licenza **CC BY-ND 4.0** (in Europe PMC: «cc by-nd» in tutti i 37 articoli con licenza indicata del campione 2026): ND vieta riassunti e traduzioni |
| **FDA** | Verde con riserva ⚖️ | La politica del sito dice che testi e grafica sono di pubblico dominio e ripubblicabili da chiunque senza permesso; credito gradito, non richiesto; l'FDA preferisce i collegamenti alle copie perché aggiorna di continuo |
| **USDA** (inclusa APHIS) | Verde con riserva ⚖️ | «La maggior parte delle informazioni» è di pubblico dominio; credito richiesto («U.S. Department of Agriculture»); i materiali protetti sono etichettati; simboli e loghi esclusi |
| **CDC** | Verde con riserva ⚖️ | Gran parte dei contenuti è di pubblico dominio; eccezioni: risorse e immagini di appaltatori, beneficiari di fondi o concesse da terzi, e opere di stati e comuni. **Quattro condizioni:** attribuzione («Source: CDC»), avviso di non approvazione ben visibile, nessuna modifica del contenuto sostanziale, indicazione che il materiale è disponibile sul sito dell'agenzia. Logo escluso |

**Agenzie federali USA in Italia.** Negli USA le loro opere non sono protette (17 U.S.C. §105). In Italia l'art. 5 L. 633/1941 esclude dalla tutela solo i testi degli **atti ufficiali** (anche stranieri), non le guide e gli opuscoli. Per la regola del confronto dei termini (convenzione di Berna, art. 7(8); direttiva 2006/116/CE, art. 7) si ritiene di solito che opere mai protette nel Paese d'origine non lo siano neppure da noi, ma la questione non è pacifica, e **il CDC stesso avverte** che altri Paesi potrebbero proteggerle. La soluzione pratica è il **permesso espresso** delle agenzie, che permettono il riuso («liberamente», senza chiedere il permesso): chi eventualmente detenesse diritti all'estero (il governo USA) lo ha concesso. Quindi **verde con riserva ⚖️**, a queste condizioni: (1) testo scritto dall'agenzia (niente ©, appaltatori, foto di terzi, enti statali o locali); (2) la pagina o la politica del sito dice «pubblico dominio» o riuso libero, e si registra dove; (3) attribuzione, avviso di non approvazione e collegamento (le 4 condizioni del CDC valgono per tutte); (4) niente loghi; (5) riassunto fedele, senza cambiare il senso; (6) la scheda «Fonte» dice «USA» (non sono norme italiane: farmaci e malattie possono differire); (7) riscarico periodico (FDA e CDC aggiornano di continuo).

**Siti che bloccano i programmi.** Dai file `robots.txt` letti oggi: **cdc.gov** non vieta nulla ai programmi in generale (solo alcune cartelle e tre bot nominati), **fda.gov** chiede una pausa di 30 secondi ed esclude alcune cartelle, **usda.gov** non pone divieti; nessuno ha segnali per l'IA. Il «rosso» del catalogo era un **blocco tecnico**, non una riserva di diritti: «rosso per blocco» non è «rosso per riserva». Per i testi di pubblico dominio il blocco non crea diritti da riservare. **Lo scarico a mano del proprietario va bene** (non si aggira nulla) e, letti a mano il documento e i termini, il documento passa a verde: come per salute.gov.it e iss.it. Se un sito blocca anche lo scarico a mano, no.

### 16.5 Lexbrowser: robots e correzione

Il `robots.txt` del Lexbrowser (Provincia di Bolzano) vieta **tutti** i programmi (`Disallow: /`): la segnalazione del Manuale è esatta (verificato il 20/11). Ho letto le pagine della L.P. 9/2000 e del D.P.P. 19/2013 (§15.4) con il browser integrato, una alla volta e rispettando la pausa imposta dal sito, **senza aver controllato prima il robots.txt**: dovevo farlo. Non ho salvato né copiato testo nel repository (atti ufficiali, art. 5) e la conclusione giuridica non cambia, ma per la biblioteca vale lo **scarico a mano** del proprietario. Da ora: `robots.txt` controllato prima di leggere un host nuovo.

## 17. Documento senza riga di licenza, con licenza del sito (20 novembre)

**Domanda dell'Orchestratore:** otto PDF di enti UK (5 del Galles, 2 della Scozia, 1 del VMD sulla permetrina) hanno la licenza OGL scritta sul sito ma non dentro il documento (`licenza_nel_documento = NO`): basta la licenza del sito, con pagina e data, o vanno tolti finché non c'è una conferma scritta?

**Risposta: basta la licenza del sito**, non serve una conferma scritta. Controllati il 20/11 gli otto testi e le note dei tre siti: nessun PDF dice qualcosa di diverso dal sito (è **silenzio, non contraddizione**).

- **Che cosa dicono i siti:** gov.wales: l'informazione sul sito (loghi esclusi) è riusabile con l'OGL; gov.scot («Crown Copyright» e piè di pagina): tutto il contenuto è OGL v3.0, esclusi i «graphic assets», i loghi e il materiale identificato come di terzi (alcune fotografie); gov.uk: la maggior parte dei contenuti è Crown copyright con OGL «salvo diversa indicazione», e quando un contenuto non è OGL di solito se ne cita l'autore o il titolare. I tre `robots.txt` non vietano nulla ai programmi in generale (gov.uk: pausa solo per bot nominati).
- **Che cosa dicono i documenti:** 7 su 8 portano «Crown copyright» (Scozia 2010 ×2 e Galles 2018–2019 ×4 sul frontespizio; il riepilogo gallese sul coniglio in fondo, «Crown Copyright 2011 WG 13038»); il leaflet del VMD non ha riga di diritti, né crediti di terzi. I due testi scozzesi hanno una pagina «Image credits» con fotografie di terzi (Blue Cross, Advocates for Animals, privati): sono immagini, che la biblioteca non conserva (solo testo).
- **Perché regge:** per le opere del governo (Crown copyright) la licenza la concede **l'ente che pubblica**, con una dichiarazione valida per tutta l'informazione del sito; il PDF non deve ripeterla. Per gli **articoli scientifici** è diverso: la licenza appartiene a ciascun articolo (autori ed editore), quindi un articolo senza licenza nel database o nel documento **non entra**.

**Condizioni (tutte):**
1. Il documento è **dell'ente** (riga «© Crown copyright» o ente autore sul frontespizio) e sta su un sito che dichiara la licenza per l'informazione che pubblica (gov.wales, gov.scot, gov.uk e `assets.publishing.service.gov.uk`).
2. **Nessuna dicitura contraria** nel documento: «tutti i diritti riservati», licenza NC o ND, copyright di terzi sul testo. Le foto e i loghi non si conservano.
3. **Registro:** `licenza_nel_documento: NO`, più «© nel documento: sì/no», la **pagina precisa** della licenza (gov.wales: `gov.wales/copyright-statement`; gov.scot: `gov.scot/crown-copyright/` e non la home; gov.uk: `gov.uk/help/terms-conditions`), la data, e una frase di riscontro. Rilettura ogni 12 mesi o se la nota cambia.
4. **Attribuzione OGL** nella scheda «Fonte»: ente, «Contains public sector information licensed under the Open Government Licence v3.0», collegamento alla licenza, «riassunto e tradotto da Quokka», nessuna frase che faccia pensare ad approvazione.

**Si toglie** se: il PDF attribuisce il testo a un terzo (un documento di un'altra organizzazione ospitato sul sito del governo); compare «diritti riservati», NC o ND; la nota del sito cambia o sparisce; il documento è stato ritirato dal sito.

**Ritocco consigliato al doc 21 §2** («la licenza si controlla due volte… se le due non coincidono, il testo non entra»): «**non coincidono** vuol dire che si contraddicono. Se il documento **tace** e l'ente è un governo che dichiara la licenza per tutto il sito (OGL, CC BY), entra alle condizioni del §17 del parere 20. Per gli articoli scientifici la licenza deve stare nel database o nel documento, altrimenti non entra.»

**Due note a margine:** (1) la vigenza dei codici (le versioni più recenti dei codici scozzesi del 2010 e di quelli gallesi) non è stata controllata: va registrata con `avvertenza_vigenza`, come per l'ordinanza sui cani; (2) il codice gallese per i gatti contiene un segnaposto editoriale non risolto («Appendix xx (add Blue Cross link)»): non è un problema di diritti, ma la chat non deve citarlo.

## 18. Piano 08 finale: lettura al momento, note accumulate, indice, messaggio d'attesa e privacy (20 novembre sera)

**Richiesta dell'Orchestratore** (sul [piano 08](../llm/08_piano_quokka_risponde_biblioteca_verifica.md) del 20/11, versione finale): un **elenco bianco** di fonti; quando la biblioteca non basta, il server **legge al momento** le pagine dell'elenco con lo strumento web del fornitore (Anthropic), senza conservarne il testo; i fatti verificati si salvano come **note compatte** in parole nostre (affermazione, fonte con link, data) e si accumulano. Cinque pareri; il parere sito per sito arriva con `elenco_bianco_candidati.md` (non ancora presente il 20/11). Pagine lette il 20 novembre.

### 18.1 Come funziona lo strumento (pagine di Anthropic)

- È uno **strumento del server**: l'API legge la pagina durante la richiesta e la mette nel contesto del modello. La **ricerca web** costa 10 USD ogni 1.000 ricerche più i token e si può limitare ai siti dell'elenco (`allowed_domains`, anche dalla Console). La **lettura di una pagina** (web fetch) riguarda solo URL già presenti nella conversazione (difesa contro l'esfiltrazione: i link vanno dati dall'elenco bianco) e non legge pagine costruite con JavaScript.
- **Rispetta il `robots.txt` e non aggira i CAPTCHA** (pagina «Does Anthropic crawl data from the web…»; la pagina dello strumento elenca «robots.txt» tra le restrizioni lato Anthropic: errore `url_not_allowed`). Anthropic descrive tre agenti, ognuno bloccabile da un sito: **ClaudeBot** (addestramento), **Claude-SearchBot** (indice di ricerca) e **Claude-User** (richieste degli utenti); con quale nome legga lo strumento dell'API non è scritto nelle pagine lette: la prova tecnica lo verifica, e il controllo in 4 punti considera tutti e tre. Un sito che li blocca o blocca `*` non si legge comunque; un sito che **non blocca e vieta nei termini** sì: lì il rispetto è nostro.
- **Conservazione:** lo strumento è idoneo alla conservazione zero, che **non è attiva** ([14](14_anthropic_contratto_conservazione_e_regole_d_uso.md): ingressi e uscite fino a 30 giorni, più a lungo se segnalati). «Senza conservare» vale per **il nostro server**: il testo letto resta nei sistemi del fornitore fino a 30 giorni.
- **Sicurezza:** le pagine di terzi sono contenuto non fidato (possono contenere istruzioni): i paletti (mai dosi, farmaci, diagnosi) li impone il codice **dopo** la lettura (competenza della Sicurezza).

### 18.2 Lettura al momento: tre gruppi

| Gruppo | Parere | Condizioni |
|---|---|---|
| **(a) Aperti o ufficiali** (leggi, enti pubblici con licenza aperta, §2 e §16) | **Sì** | Licenze già approvate; per questi si può anche conservare il testo |
| **(b) Diritti riservati, senza divieti espliciti** (per esempio società scientifiche) | **Sì a condizioni** | Controllo in 4 punti **per sito**, registrato e valido 12 mesi (robots anche per Claude-User e ClaudeBot, segnale `ai-input`, termini, riserve leggibili da macchina, avviso nel documento); lettura mirata a una domanda, mai a tappeto; nessun testo conservato da noi (neanche nei log e nelle tracce); fatto in parole nostre; fonte, link e data; tetto di note (§18.4) |
| **(c) Chiedono un permesso o vietano l'uso automatico o commerciale** (MSD Veterinary Manual, associazioni di protezione animale con schede di cura che vietano o riservano) | **No senza permesso scritto** | «Non conservare» non basta (§18.3). Si legge solo dopo un permesso; nel frattempo, nessuna lettura automatica, nemmeno «per provare» |

**Un sito sta in (b) solo se** il `robots.txt` non blocca Claude-User, ClaudeBot né `*`, non ha `ai-input=no` (né una riserva generale), i termini non vietano l'uso automatico, commerciale o per l'IA, e non ci sono riserve nelle intestazioni o nel documento. `ai-train=no` da solo non vieta la lettura (non addestriamo), come per Europe PMC (§3). Un permesso scritto sposta il sito in (a) per l'uso concesso.

**Siti già guardati il 20/11** (robots; i termini vanno letti sito per sito): MSD Veterinary Manual: nessuna restrizione per le IA nel robots; © Merck tutti i diritti riservati; «Permissions» chiede un permesso per riusare contenuti; «Partnerships» vende contenuti, API e widget agli sviluppatori di app; i termini d'uso rimandano ai siti nazionali (non letti) → (c). Blue Cross e Dogs Trust: robots senza restrizioni per le IA; RSPCA: blocca GPTBot (non Claude) e molti raccoglitori: segnale di cautela; termini di tutte e tre da leggere.

### 18.3 «Non conservare»: che cosa cambia davvero

- **Per (b) conta:** copia solo temporanea, nessun archivio, nessuna banca dati nostra: è una condizione dell'eccezione sull'estrazione di testo e dati (art. 70-quater e 70-septies; copie solo per il tempo necessario) e riduce il rischio di danno.
- **Per (c) cambia poco**, perché il divieto o la riserva colpiscono **la lettura**, non la conservazione: (1) la **copia temporanea** si fa lo stesso, nello strumento del fornitore (fino a 30 giorni); (2) se la riserva è **leggibile da macchina o scritta nei termini**, l'eccezione non copre (ad Amburgo nel 2024 una riserva scritta nei termini è bastata, da verificare); (3) i **termini d'uso** possono vietare la lettura automatica anche dove non c'è diritto d'autore (CGUE, Ryanair, C-30/14); (4) per i siti che **vendono licenze agli sviluppatori di app** (MSD «Partnerships») pesa il mercato: leggerli senza licenza lo erode; (5) per chi **riceve da noi una lettera di permesso**, leggerlo al volo prima della risposta renderebbe fuorviante la frase «finché non avremo la vostra risposta non inseriremo i vostri testi» ([20a](20a_lettere_permesso_ai_titolari.md)).
- **Che cosa dire al proprietario:** il rischio **scende** (niente archivio, niente copia da mostrare), ma **non è «molto basso» per i siti (c)**: resta l'atto di leggere. Ordine di grandezza (prudenziale, non una stima legale): (b) basso ma non nullo; associazioni di protezione animale senza divieti espliciti medio-basso, risolvibile con una lettera; siti con divieto o riserva automatica alto; MSD medio-alto. ⚖️

### 18.4 Accumulo di note

- **Diritto d'autore:** i fatti in parole nostre non sono protetti; il rischio è copiare espressione, scelta e ordine. Una nota = un fatto; nessuna sequenza di 6 o più parole uguali alla pagina (controllo automatico **mentre il testo è ancora in memoria**, poi si scarta); niente tabelle, elenchi o struttura della fonte.
- **Banche dati: sì, può rilevare.** Un sito grande e strutturato (manuale, elenco di tossici, banca dati di razze) può essere una «banca di dati» (art. 102-bis e 102-ter L. 633/1941; dir. 96/9/CE, art. 7): è vietata l'estrazione o il reimpiego, **anche temporanei**, di una parte sostanziale, e l'estrazione **ripetuta e sistematica di parti non sostanziali** che contrasti con la normale gestione o pregiudichi ingiustificatamente il costitutore (art. 7(5)). Il diritto protegge i **dati**, anche non protetti dal diritto d'autore, e vale anche se non teniamo il testo. L'utente legittimo può estrarre parti non sostanziali (art. 8 e 15 della direttiva), ma non in modo sistematico e dannoso. Il rischio non è la nota singola ma **la somma nel tempo**. La giurisprudenza (CGUE: *Directmedia*, C-304/07; *Apis-Hristovich*, C-545/07; *Innoweb*, C-202/12, per la lettura in tempo reale) guarda al totale cumulato: da verificare. ⚖️
- **Tetto per sito: sì, conviene.** Non c'è una soglia di legge: è una regola prudenziale, da rivedere dopo 3 mesi. **(a): nessuno. (b): al massimo l'1% delle voci o pagine del sito (dalla mappa del sito) e comunque 50 note; per i siti piccoli 20 note e mai una sezione intera; allarme al 50%. (c): zero.** I siti piccoli (poche schede) pongono più un problema di scelta e ordine che di banca di dati.
- **Condizioni di sicurezza:** solo (a) e (b); note create **a richiesta di una domanda**, mai riempimento di una sezione o di una lista; anche «partire già pieni» con le mille domande passa dagli stessi controlli e dallo stesso tetto, con pause tra le letture; fonte, link e data in ogni nota; **contatore per sito**; rimozione di tutte le note di un sito **entro 3 giorni** se il titolare lo chiede; scadenza a 12 mesi; **nessuna nota con dati dell'utente** (§18.7). Con un **permesso scritto** il tetto cade.

### 18.5 Citare con asterisco e indice a tre livelli

- **Citare una fonte riservata letta al momento** (ente, anno, link) **è corretto**, a tre condizioni: il riferimento è **vero** (lo scrive il codice dal passo letto, mai il modello); nessuna frase che faccia pensare ad approvazione e **niente loghi** («riassunto da Quokka: l'ente non ha approvato»); la scheda dice **«consultata il [data]»** e non indica una licenza che non c'è («© [ente]»). Il collegamento a una pagina pubblica è lecito. Per i siti (c) il problema non è citare ma aver letto.
- **Indice a tre livelli: parole.** L'indice misura **da dove vengono le frasi, non se sono giuste**. Proposta: verde **«Con fonti ufficiali»**, giallo **«In parte con fonti»**, grigio **«Senza fonti: conoscenze generali dell'IA»**; nome dell'indice **«Fonti»** (non «verifica» né «affidabilità»), sempre con icona e parola, mai solo colore. Evitare **«Verificata»** (promette più di un controllo automatico che può sbagliare e di una fonte che può non valere per il caso). **Verde solo se ogni frase controllabile ha un riscontro in una legge o in un documento di un ente pubblico**: «ufficiali» deve essere vero alla lettera; con una società scientifica, un manuale, un'associazione o un articolo il livello è giallo. Per le fonti di altri Paesi la scheda dice il Paese («guida del governo scozzese»).
- **Spiegazione a portata di tocco:** «Verde: le frasi con l'asterisco* hanno riscontro in leggi o documenti di enti pubblici. Giallo: solo alcune frasi hanno una fonte. Grigio: nessuna fonte, conoscenze generali dell'IA. Il controllo è automatico e la fonte può non valere per il tuo caso. Non sostituisco il veterinario.»
- **Non promettere:** che il verde significhi giusto, sicuro o adatto al tuo animale o al tuo Paese; «verificata da esperti o veterinari»; «affidabile»; «approvata» o «ufficiale» se non lo è; «aggiornata»; nessun rosso; nelle urgenze si mostra solo l'avviso d'urgenza (come nel piano). In negozio e sul sito vale il §16.2: l'indice non è una certificazione.

### 18.6 Messaggio d'attesa

«Sto cercando la risposta più affidabile per questo caso…» **non va**: «più affidabile» è un superlativo che non si può provare e promette un esito; lo stesso per «consulto gli esperti», «verifico» o «ci sono quasi». Proposta: **«Sto cercando fonti per la tua domanda…»** (alternativa: «Controllo se trovo fonti su questo…»). Se il tempo scade: **«Non ho trovato altre fonti in tempo: ti rispondo con ciò che ho.»** (poi riga di trasparenza e indice giallo o grigio). Le altre lingue dopo l'approvazione dell'italiano.

### 18.7 Privacy

- **La ricerca (specie + tema, niente dati personali)** non comporta nuovo trattamento di dati personali: il fornitore è già nostro responsabile e i siti terzi vedono l'indirizzo di Anthropic e un URL o un termine di ricerca, non l'utente. **Condizioni:** la ricerca è costruita da specie e tema (meglio da elenchi chiusi) o controllata a campione; **non si imposta `user_location`** nello strumento di ricerca (invierebbe una posizione); le ricerche non si registrano con identificativi dell'utente. Se le ricerche contenessero testo libero della domanda, informativa e inventario andrebbero aggiornati.
- **Inventario dei fornitori e informativa:** nessuna riga obbligatoria per il GDPR se vale quanto sopra; **consigliata** una riga in `docs/security/06` (a cura della Sicurezza): «strumenti web del fornitore (ricerca e lettura di pagine): ricevono solo specie e tema e gli URL dell'elenco bianco; rispettano robots.txt; ingressi e uscite fino a 30 giorni; nessun dato personale». L'informativa ([it/02](it/02_informativa_privacy_it.md)) non cambia.
- **Le note non sono trattamento di dati personali** se: contengono solo specie, tema, affermazione, condizioni generali, fonti, **data** (non l'ora), punteggio e scadenza; **nessun** identificativo di utente, sessione o dispositivo, **nessun testo della domanda**, nessun dato dell'animale di una persona (età, peso, malattie di un caso); il contatore delle domande senza fonte resta aggregato (§6). Il trattamento che le produce (la chat) è già dichiarato. Gli unici nomi sono quelli degli autori nelle fonti (§5.2).
- **Tracce e log:** il testo restituito dallo strumento non va nei log, nelle tracce degli errori né negli strumenti di osservabilità (diritto d'autore e privacy); le ricerche, se registrate, senza identificativi.

### 18.8 L'elenco bianco: campi e procedura

Per ogni sito, oltre ai campi del piano: **gruppo (a/b/c)**, data del controllo in 4 punti (con l'esito per robots, `ai-input`, termini, intestazioni e documento), **permesso scritto** (file e ambito), **tetto di note e contatore**, indirizzo per le richieste dei titolari. Un sito entra solo con il mio parere («sì / sì a condizioni / solo con permesso / no») e il controllo in 4 punti, valido 12 mesi. Prima di leggere un host nuovo si controlla il suo `robots.txt` (anche per la lettura a mano).

## 19. Elenco bianco: parere sito per sito (20 novembre sera)

Sul file `.local/chat_eval/biblioteca/elenco_bianco_candidati.md` della sessione Manuale (34 voci; per i siti riservati sono stati letti solo robots e condizioni, mai i contenuti: **metodo corretto**). Gruppi come in §18.2. «A mano» = scarico da parte del proprietario, perché il sito blocca i programmi (non si aggira nulla).

**Due correzioni ai dati del file.** (1) **Agriculture Victoria (voce 13) non è aperta**: la nota di copyright (letta il 20/11) dice che il copyright è dello Stato di Victoria e che nulla può essere riprodotto o usato per scopi commerciali; solo uso personale, interno o non commerciale con citazione del titolare. Il CC BY del portale generale vic.gov.au non vale per questo sito. (2) Il **«Veterinary Disclaimer» di MSD (voce 24) non vieta l'uso con IA**: dice che MSD non risponde delle sintesi, traduzioni o elaborazioni fatte da altri con strumenti di IA e che gli utenti devono rispettare il diritto d'autore. MSD resta «solo con permesso» per altri motivi (diritti riservati, pagina «Permissions», pagina «Partnerships» che vende licenze agli sviluppatori di app: §18.3).

| # | Fonte | Parere | Condizioni |
|---|---|---|---|
| 1 | Defra, UKHSA, VMD (gov.uk) | **Sì** | OGL v3.0; attribuzione; fuori ciò che il documento attribuisce a terzi; solo testo |
| 2 | gov.scot | **Sì** | OGL v3.0; solo testo (foto e «graphic assets» esclusi) |
| 3 | gov.wales | **Sì** | OGL v3.0; documenti senza riga di licenza: §17 |
| 4 | nidirect | **Sì** | OGL v3.0; logo escluso |
| 5 | DAERA (Irlanda del Nord) | **Sì** | OGL v3.0; pausa di 5 secondi tra le letture |
| 6 | Normattiva e Gazzetta Ufficiale | **Sì** | Riga fonte completa (§15.5); vigenza riverificata ogni settembre per le ordinanze; mai le pagine di ricerca |
| 7 | EUR-Lex | **Sì** | Decisione 2011/833/UE; consolidati CC BY 4.0 con «modificato»; pausa di 10 secondi; accesso tramite l'interfaccia Cellar dell'Ufficio delle pubblicazioni, non la facciata di EUR-Lex (§21.1) |
| 8 | salute.gov.it | **Sì a condizioni** | CC BY 4.0 «ove non diversamente specificato»: nota di ogni sezione (COVID-19 escluso); a mano finché la barriera può tornare; `robots.txt` anomalo: niente lettura al volo |
| 9 | ECDC | **Sì** | CC BY 4.0, tre condizioni; terzi e logo esclusi |
| 10 | Commissione europea, Your Europe | **Sì a condizioni** | Nota della Commissione letta: CC BY 4.0 «salvo diversa indicazione»; da leggere la nota del portale; terzi, loghi esclusi |
| 11 | gov.ie (DAFM) | **Sì a condizioni** | Nota non raggiungibile: leggerla a mano; fino ad allora no |
| 12 | MPI Nuova Zelanda | **Sì** | CC BY 4.0 (nota letta il 20/11, §16.4); attribuzione per adattamenti; a mano (barriera) |
| 13 | Agriculture Victoria | **No senza permesso** | Non aperta (vedi sopra); permesso possibile |
| 14 | NSW DPI | **Sì a condizioni** | Nota non letta (blocco): leggerla a mano; senza licenza scritta, solo con permesso |
| 15 | CDC «Healthy Pets» | **Sì con riserva ⚖️** | §16.4: quattro condizioni del CDC; testo dell'agenzia, niente foto né appaltatori; a mano (blocco) |
| 16 | FDA (salute animale) | **Sì con riserva ⚖️** | Politica del sito letta il 20/11 (pubblico dominio, credito gradito); a mano; riscarico periodico |
| 17 | Queensland DPI | **No senza permesso** | Riproduzione vietata senza permesso scritto |
| 18 | EFSA | **No** per i pareri | CC BY-ND (ND vieta riassunti e traduzioni); le pagine del sito sì, ma non c'è una guida per proprietari |
| 19 | Svizzera, OPAn (RS 455.1) | **Sì** | Atto ufficiale (art. 5 L. 633/1941, anche straniero); preferire il testo autentico di Fedlex; scheda «Svizzera»: vale per chi vive lì |
| 20 | Svizzera, USAV «Detenzione di animali» | **Sì a condizioni** | Non sono atti: serve la nota legale (non letta, 403): a mano; fino ad allora no |
| 21 | Austria, 2. Tierhaltungsverordnung (RIS) | **Sì** | Atto ufficiale; in tedesco; versione consolidata: citare la data, fa fede il bollettino ufficiale |
| 22 | Germania, Tierschutzgesetz e Tierschutz-Hundeverordnung | **Sì** | Atto ufficiale; in tedesco; il testo di gesetze-im-internet.de è consolidato, non ufficiale |
| 23 | Francia, Légifrance | **Sì** | Atto ufficiale e Licence Ouverte 2.0 (equivale a CC BY); a mano (barriera); in francese |
| 24 | MSD Veterinary Manual | **Solo con permesso** | §18.3 e correzione sopra; lettere ferme; nessuna lettura al volo |
| 25 | RSPCA | **Solo con permesso** | Copyright RSPCA o di terzi; blocca GPTBot |
| 26 | Blue Cross, PDSA, Cats Protection, Dogs Trust, Battersea | **Solo con permesso** (per ora) | Se la lettura a mano dei termini non trova riserve né divieti, passano a (b): una per una |
| 27 | Rabbit Welfare Association & Fund | **Solo con permesso** | Termini non letti |
| 28 | International Cat Care | **No oggi** | Solo uso personale non commerciale; permesso possibile (lettera) |
| 29 | WSAVA | **Solo con permesso** | Diritti riservati e procedura con modulo per il riuso |
| 30 | ESCCAP | **Solo con permesso** | Vieta di stampare o copiare senza permesso (e raccolta automatica, [13](13_parere_fonti_scientifiche_e_diritto_d_autore.md) A.4) |
| 31 | AAV | **Solo con permesso** | Blocca i programmi; termini non letti |
| 32 | ARAV e AVSAB | **Solo con permesso** | Finché i termini non sono letti a mano |
| 33 | AVMA e ASPCA | **No oggi** | AVMA: tutti i diritti riservati; ASPCA: uso personale non commerciale, copia e riuso vietati; permesso possibile |
| 34 | SCIVAC ed ENPA | **Solo con permesso** | Utili perché in italiano; termini non letti: a mano; se non c'è divieto, passano a (b) |

**Per la prova tecnica:** misurare tempo e costo sulle voci **1–7, 9 e 19–22** (aperte, robots in regola); per (b) non c'è ancora nessun sito autorizzato: ne bastano due o tre, scelti tra le voci 26, 27, 32 e 34, dopo la lettura a mano dei termini e il controllo in 4 punti. Le voci con barriera (8, 11, 12, 14–16, 20, 23, 31) falliscono comunque se lette dal programma: si scaricano a mano. **Specie ancora scoperte** (uccelli, rettili, criceto, furetto, pesci): Victoria non le risolve; restano le voci 12 (MPI), 14 (NSW, dopo la nota), 19 e 21 (leggi) e i permessi di AAV, ARAV e AEMV (lettere).

### 19.1 Campi per il file dell'elenco bianco (tabella da riportare)

Stessi pareri di §19, nelle colonne richieste dall'Orchestratore, perché la sessione Manuale li copi nel file. **Gruppo:** a = aperto o ufficiale, b = riservato senza divieti espliciti, c = chiede un permesso o vieta. «Dopo la nota» = diventa (a) solo se la nota di licenza, letta a mano, lo conferma; altrimenti (c). «A mano» = scarico del proprietario perché il sito blocca i programmi. **Tetto note:** «—» = nessuno; 0 = nessuna nota; per (b) 50 note e al massimo l'1% delle voci del sito (20 note per i siti piccoli). **Conservare il testo** vale solo per (a); per (b) si conserva solo la nota.

**Formule di attribuzione** (si scrivono nella scheda «Fonte», insieme a «riassunto da Quokka» e «l'ente non ha approvato»):
- **OGL:** ente + «Contains public sector information licensed under the Open Government Licence v3.0» + collegamento alla licenza.
- **CC BY:** ente come autore + «CC BY 4.0» con il collegamento alla licenza + «modificato». **NZ:** la formula di MPI; se si adatta: «This work is based on/includes MPI data which is licensed by MPI for re-use under the Creative Commons Attribution 4.0 International licence».
- **Atto:** «Fonte: [portale] (testo consolidato, non ufficiale e gratuito; fa fede [bollettino ufficiale])», data di consultazione e Paese (per Normattiva la riga completa del §15.5).
- **USA:** «Source: [agenzia]», avviso che l'agenzia non approva, collegamento alla pagina dell'agenzia («Source: CDC» e le altre tre condizioni per il CDC); «guida USA».
- **(b):** ente, anno, collegamento, «consultata il [data]» e «© [ente]»; nessuna licenza dichiarata.

| # | Fonte | Gruppo | Lettura al momento | Conservare il testo | Tetto note | Attribuzione | Permesso |
|---|---|---|---|---|---|---|---|
| 1 | Defra, UKHSA, VMD (gov.uk) | a | sì | sì | — | OGL | no |
| 2 | gov.scot | a | sì | sì (solo testo) | — | OGL | no |
| 3 | gov.wales | a | sì | sì | — | OGL | no |
| 4 | nidirect | a | sì | sì | — | OGL | no |
| 5 | DAERA | a | sì (pausa 5 s) | sì | — | OGL | no |
| 6 | Normattiva e Gazzetta Ufficiale | a | sì (mai la ricerca) | sì | — | Atto (riga completa) | no |
| 7 | EUR-Lex | a | sì (pausa 10 s; via Cellar, §21.1) | sì | — | CC BY per i consolidati; Atto per gli atti | no |
| 8 | salute.gov.it | a dopo la nota di sezione | a mano | sì | — | CC BY, con l'indirizzo della pagina | no (COVID-19 escluso) |
| 9 | ECDC | a | sì | sì | — | CC BY (tre condizioni) | no |
| 10 | Your Europe (Commissione) | a dopo la nota del portale | sì, dopo la nota | sì, dopo la nota | — | CC BY («© Unione europea») | no, se la nota conferma |
| 11 | gov.ie (DAFM) | a dopo la nota | a mano | dopo la nota | — | secondo la nota | sì, se la nota non apre |
| 12 | MPI Nuova Zelanda | a | a mano | sì | — | NZ | no |
| 13 | Agriculture Victoria | c | no | no | 0 | — | sì (Stato di Victoria) |
| 14 | NSW DPI | a dopo la nota | a mano | dopo la nota | — | secondo la nota | sì, se la nota non apre |
| 15 | CDC «Healthy Pets» | a con riserva ⚖️ | a mano | sì, con riserva | — | USA (quattro condizioni) | no (riserva ⚖️) |
| 16 | FDA | a con riserva ⚖️ | a mano | sì, con riserva | — | USA | no (riserva ⚖️) |
| 17 | Queensland DPI | c | no | no | 0 | — | sì |
| 18 | EFSA | pareri: c (CC BY-ND); pagine del sito: a | pareri no; pagine sì | pareri no; pagine sì | pareri 0; pagine — | pagine: «Fonte: EFSA» | no |
| 19 | Svizzera, OPAn (RS 455.1) | a | sì (Fedlex) | sì | — | Atto («Svizzera») | no |
| 20 | USAV/BLV «Detenzione di animali» | a dopo la nota legale | a mano | dopo la nota | — | secondo la nota | sì, se la nota non apre |
| 21 | Austria, RIS | a | sì | sì | — | Atto (fa fede il BGBl) | no |
| 22 | Germania, gesetze-im-internet.de | a | sì | sì | — | Atto (fa fede il Bundesgesetzblatt) | no |
| 23 | Légifrance | a | a mano | sì | — | Atto + «Licence Ouverte 2.0» | no |
| 24 | MSD Veterinary Manual | c | no | no | 0 | — | sì (lettere ferme) |
| 25 | RSPCA | c | no | no | 0 | — | sì |
| 26 | Blue Cross, PDSA, Cats Protection, Dogs Trust, Battersea | c; b dopo la lettura a mano dei termini | no; se b: sì (controllo in 4 punti) | no | 0; se b: 50 e 1% | se b: formula (b) | sì, o passaggio a b |
| 27 | Rabbit Welfare Association & Fund | c; b dopo i termini | come 26 | no | come 26 | come 26 | sì, o passaggio a b |
| 28 | International Cat Care | c (uso personale non commerciale) | no | no | 0 | — | sì |
| 29 | WSAVA | c | no | no | 0 | — | sì (modulo di riuso) |
| 30 | ESCCAP | c | no | no | 0 | — | sì |
| 31 | AAV | c | no (blocco) | no | 0 | — | sì |
| 32 | ARAV e AVSAB | c; b dopo i termini | come 26 | no | come 26 | come 26 | sì, o passaggio a b |
| 33 | AVMA e ASPCA | c | no | no | 0 | — | sì (bassa priorità) |
| 34 | SCIVAC ed ENPA | c; b dopo i termini | come 26 | no | come 26 | come 26 | sì, o passaggio a b |

**Regole comuni:** controllo in 4 punti registrato per ogni sito (valido 12 mesi); prima di un host nuovo si legge il suo `robots.txt`; nessuna lettura di un sito (c) né «per provare»; per i siti a cui si scrive per un permesso, nessuna lettura al volo prima della risposta (§18.3); il testo letto non entra in log o tracce; contatore per sito e allarme al 50% del tetto.

## 20. Urgenze: nessuna corsia preferenziale (20 novembre notte)

**Richiesta dell'Orchestratore progetto**, dopo la decisione del proprietario riferita il 20 novembre: «Non gestiamo le urgenze. L'urgenza deve essere trattata come il resto: esce l'informazione che è un'urgenza perché lo si capisce dalle fonti. Nessuna corsia preferenziale.» (già detto il 17: «l'app non è un pronto soccorso»). Il [piano 08](../llm/08_piano_quokka_risponde_biblioteca_verifica.md) (main c08d53f) ne trae: nessun avviso anticipato, nessun primo messaggio separato, nessun passo d'urgenza scritto da noi, stessa attesa per ogni domanda (al massimo 20 secondi), note che scadono dopo 6 mesi. Quattro domande, con l'invito a scrivere i rischi **senza attenuarli**, perché decide il proprietario. Non è consulenza legale: gli articoli dei codici sono citati dal testo noto e **non sono stati riletti oggi su Normattiva** (come in [11](11_esclusioni_responsabilita.md) §2); i punti ⚖️ 17 e 18 (§11) vanno a un legale.

**In breve**

1. **Non è un obbligo di legge, è una cautela.** Correggo il mio «obbligatoria» di §13 e §16.1 (§20.1).
2. Senza percorso d'urgenza gli avvisi generali **non bastano così come sono** (11 px, grigi): servono avvisi **uguali per tutti** (non sono una corsia), più visibili, e una **regola sulle risposte**: mai giudicare la gravità del caso dell'utente (§20.4).
3. La frase per la **persona ferita (112) resta**, meglio statica e per Paese (§20.5).
4. Negozio e sito: una frase fissa e un elenco di parole da non usare (§20.6).
5. **Rischi** (§20.7): il più pesante è una **rassicurazione sbagliata** su un caso grave, senza più un pavimento fisso; poi la prova a posteriori nel repository pubblico, i limiti di legge degli avvisi e la direttiva (UE) 2024/2853 dal 9 dicembre 2026 ⚖️.

### 20.1 Correzione mia

Nel §13.3 (n. 6), nel §13.4 e nel §16.1 (riga «Apertura urgente») avevo scritto che l'apertura urgente di [11](11_esclusioni_responsabilita.md) §3.2 «resta valida e obbligatoria», o che va usata sempre. **Non è esatto:** nessuna norma la impone. Era una cautela che raccomandavo, e «obbligatoria» era una parola troppo forte; può aver contribuito a riportare nel piano un percorso d'urgenza che il proprietario non vuole. Ho corretto il §16.1 e aggiunto una nota al §13; in 11 §3.2 la riga «Testo nelle risposte urgenti» è segnata come non più usata. Una cautela non prevale sulla decisione del proprietario: quello che gli devo è il quadro dei rischi (§20.7) e le misure che li riducono senza ricreare una corsia (§20.4).

### 20.2 È un obbligo di legge? (domanda 1)

**No: è una cautela.** Che cosa dicono davvero le norme che entrano nel ragionamento:

| Norma | Che cosa dice | Impone un testo d'urgenza? |
|---|---|---|
| Art. 50(1) Reg. (UE) 2024/1689 (AI Act) | chi interagisce con un'IA va informato che lo è | **No**: riguarda solo il dire che è un'IA (lo coprono badge e riga fissa) |
| Allegato III, punto 5(d), AI Act ⚖️ | alto rischio per i sistemi che valutano e classificano le chiamate di emergenza, smistano i soccorsi o fanno il triage dei pazienti | **No**: parla di soccorso e sanità delle persone, non degli animali. Semmai dice il contrario: nessuna norma ci chiede un classificatore d'emergenze |
| Art. 348 codice penale (esercizio abusivo di una professione) ⚖️ | l'attività riservata (diagnosi, prescrizione) non si fa senza abilitazione | **No**: spiega perché la chat non fa diagnosi; «Quokka non può valutare il tuo animale» è coerente, non imposto. Un triage nostro (decidere che cosa è urgente) è più vicino all'attività riservata di un'informazione generale |
| Artt. 1176, 1218 e 2043 codice civile ⚖️ | diligenza dovuta (più alta per chi svolge un'attività professionale); responsabilità per inadempimento e per fatto illecito | **No**: sono il metro con cui un giudice valuterebbe se il servizio è stato progettato con prudenza |
| Art. 1227 codice civile | il risarcimento si riduce se il danneggiato poteva evitare il danno con l'ordinaria diligenza | **No**: è una difesa, e funziona se l'utente è stato avvisato in modo chiaro |
| Artt. 20–22 Codice del consumo | pratica scorretta; azione e omissione ingannevole | **Indirettamente**: vietano di far credere che l'app riconosca o gestisca le emergenze, e di tacere ciò che serve al consumatore per decidere |
| Artt. 135-octies ss. Codice del consumo | il servizio digitale ha le qualità e le prestazioni promesse e quelle che il consumatore può aspettarsi | **Indirettamente**: ciò che promettiamo (e non promettiamo) definisce la conformità |
| Art. 36, c. 2, lett. a e c, Codice del consumo; art. 1229 codice civile ⚖️ | nulla l'esclusione della responsabilità per morte o danno alla persona e di clausole che l'utente non ha potuto conoscere; nullo il patto di esonero per dolo o colpa grave | **No**, ma fissano il **limite** di ciò che gli avvisi possono fare (§20.7, n. 3) |
| Direttiva (UE) 2024/2853 ⚖️ | dal 9 dicembre 2026 il software è un «prodotto»; per il difetto risponde il produttore; si guarda alla presentazione (avvertenze, istruzioni) e all'uso ragionevolmente prevedibile; non si esclude per contratto | **No**, ma sposta il rischio (§20.7, n. 4). Numeri degli articoli da verificare |
| L. 132/2025 (norme nazionali sull'IA) ⚖️ | non riletta oggi | per quanto ricordo riguarda la sanità e le professioni intellettuali delle persone, non gli animali: da verificare |

**Non conosco una norma specifica per le chat sulla salute degli animali.** Quello che la legge pesa è la **ragionevolezza dell'insieme**: (a) che cosa promettiamo, (b) che cosa vede l'utente nel momento in cui scrive, (c) che cosa risponde la chat. L'apertura urgente era una misura sul punto (c). Se la si toglie, il peso passa su (a) e (b) e su una regola per (c) (§20.4).

### 20.3 Che cosa decade e che cosa resta

| Testo o regola | Dopo la decisione del proprietario |
|---|---|
| Apertura urgente di [11](11_esclusioni_responsabilita.md) §3.2 nelle risposte («Questa situazione può essere urgente. Non aspettare: contatta subito un veterinario. Quokka non può valutare il tuo animale.») | **Non si usa più come percorso.** Il testo storico resta come modello per gli avvisi uguali per tutti (§20.4). La stringa è ancora in `packages/core/domain/localization.py` (riga 398): la Chat decide se toglierla o riusarla |
| Regola §13.3 n. 6 (controllo di pericolo prima e dopo la risposta, con apertura obbligata) | **Decade** nella parte che apre con il testo; restano il divieto di dosi, farmaci e diagnosi (§13.3 n. 4) e le attribuzioni scritte dal codice |
| Riga fissa, avviso T-A, badge «Generato da IA», misure per i minori di 14–17 anni (punto 57) | **Restano**; la riga fissa va rafforzata (§20.4) |
| Frase per la persona ferita (§16.3) | **Resta** (§20.5) |
| Cancello di prova «urgenze e sicurezza non sotto oggi» (piano 08, prova 2) | **Resta**, e lo propongo come condizione di rilascio (§20.8) |

### 20.4 Gli avvisi generali bastano? (domanda 2)

**Sono il minimo, non bastano da soli, e oggi sono deboli proprio dove servono.** Il testo dell'app (`chatAiNotice`: «Rispondo con un'intelligenza artificiale: non sostituisco il veterinario. In emergenza chiama subito una clinica.») è in carattere piccolo (11 px) e grigio, sotto il titolo, con una piccola icona; chi scrive in fretta non lo legge, e non dice che la chat può non riconoscere un'urgenza. Una regola che l'utente non ha potuto conoscere non protegge ([11](11_esclusioni_responsabilita.md) §2, art. 36 c. 2 lett. c): gli avvisi importanti vanno nel punto d'uso.

**«Uguali per tutti»** = stesso testo per ogni utente e ogni domanda, in un posto fisso, **non attivato da un riconoscimento**: per questo non è una corsia. Proposte (italiano; le altre lingue dopo l'approvazione):

| Dove | Oggi | Proposta |
|---|---|---|
| **Riga fissa della chat** | `chatAiNotice`, 11 px, colore secondario | Più visibile (carattere normale, contrasto, sempre presente). Testo: «Risponde un'IA e può sbagliare. Non è un servizio di emergenza e può non riconoscere un'urgenza. Se hai un dubbio, non aspettare la risposta: chiama subito il tuo veterinario o la clinica più vicina. Persona ferita o in pericolo: 112.» Versione breve: «Può sbagliare e non è un servizio di emergenza. Se pensi che sia urgente, chiama subito il veterinario. Persona ferita: 112.» |
| **Schermata d'attesa** («Sto cercando fonti per la tua domanda…») | da costruire | Sotto il messaggio, uguale per tutti: «Se è un'emergenza non aspettare: chiama subito il tuo veterinario.» **Da decidere dal proprietario**: il piano dice «nessun avviso anticipato»; un testo uguale per tutti non classifica nessuno, ma resta un avviso sulla schermata d'attesa. Io lo consiglio; senza, restano la riga fissa e la riga di trasparenza come minimo |
| **Riga di trasparenza** (§16.2, una volta per chat) | «… Non sostituisco il veterinario.» | Aggiungere: «Non sono un servizio di emergenza: se hai fretta, chiama subito il veterinario.» |
| **Info** «Cosa fa e cosa non fa l'assistente» ([11](11_esclusioni_responsabilita.md) §3.2) | «non è un servizio di emergenza» | Aggiungere «e può non riconoscere un'urgenza» |
| **Termini** §2 ([it/03](it/03_termini_di_servizio_it.md)) | «In caso di emergenza vai subito da un veterinario o in una clinica. Non rimandare una visita per qualcosa che ha detto l'app.» | Aggiungere: «Quokka non è un servizio di emergenza e può non riconoscere un'urgenza.» (da includere nella versione di lancio) |
| **Assistenza** ([it/04](it/04_pagina_assistenza_it.md), «Il mio animale sta male») | «Quokka non è un servizio di emergenza. Chiama subito il tuo veterinario o la clinica veterinaria più vicina.» | Già a posto |
| **Paywall** (`billingPaywallEmergencyTitle` e `Body`) | «Se il tuo animale è in pericolo: chiama subito il tuo veterinario o una clinica veterinaria d'urgenza. Quokka non sostituisce una visita.» | Resta |
| **Primo uso** («Cosa fa e non fa») | da definire | Una riga: «Non è un servizio di emergenza e può non riconoscere un'urgenza» |
| **Facoltativo**: pulsante fisso «Trova una clinica» | non c'è | Apre la mappa dei servizi già presente (con il suo avviso «in emergenza chiama prima»); uguale per tutti, nessun riconoscimento. La posizione resta soggetta al consenso già previsto |

**Regola sulle risposte** (non è una corsia: vale per tutte le risposte; la decide la Chat):

- La risposta **non giudica la gravità del caso dell'utente** («non è grave», «puoi aspettare», «non è niente», «è normale») a meno che una fonte letta lo dica per quella situazione precisa, e anche allora aggiunge che il caso lo valuta il veterinario.
- Se la fonte letta indica rischio per la vita o urgenza, la risposta lo riporta **senza attenuarlo**.
- Restano ammessi le informazioni generali e i segni per cui andare dal veterinario.

Perché: il rischio che pesa di più non è la mancanza di un testo, è una **rassicurazione sbagliata** (§20.7, n. 1). La regola è coerente con il divieto di diagnosi (art. 348 c.p. ⚖️): la chat non valuta il singolo animale, né in un senso né nell'altro.

### 20.5 La frase per la persona ferita (domanda 3)

La frase «Se una persona è ferita o in pericolo, chiama subito il 112 o vai al pronto soccorso.» (§16.3, approvata con due ritocchi) **resta**, e la consiglio **statica**.

- **Non rientra nella decisione sugli animali.** La decisione del proprietario riguarda le urgenze dell'animale. Per le persone l'app non gestisce nulla: indica soltanto dove rivolgersi. Non è un servizio, è un rinvio.
- **Rischio reale e prevedibile**: morsi, graffi, calci (anche di animali grandi), morsi di serpente, zoonosi; il Manuale e la chat trattano già il morso (casi 37 e 60, §15). Il danno alla persona è proprio quello che nessun avviso può escludere (art. 36 c. 2 lett. a; art. 1229 c.c.): l'unica difesa è dire dove andare. Costo: una riga.
- **Meglio nella riga fissa** («Persona ferita o in pericolo: 112»), così non dipende da un riconoscimento fatto dal sistema; per **Paese dell'utente** come in §16.3 (*superato il 21 novembre 2026: nessun numero nei testi fissi*).
- Se la Chat tiene anche un messaggio **a regole su parole chiave** (lavoro A: «comportamento pericoloso verso persone»), va bene: è un rinvio ai soccorsi, non un percorso per gli animali; lo si presenti al proprietario come tale. Il testo resta condizionale («Se una persona è ferita…»), mai «ho capito che sei ferito».
- AI Act, allegato III, punto 5(d): un rinvio fisso non è uno smistamento di soccorsi; lo sarebbe di più un sistema che classifica i messaggi d'emergenza delle persone. Un motivo in più per il testo statico ⚖️ (rischio basso).

### 20.6 Negozio e sito (domanda 4)

**Frase** (italiano; per scheda del negozio, sito, pagina di assistenza e primo uso):

> Quokka non è un servizio di emergenza e può non riconoscere un'urgenza. Non sostituisce il veterinario. Se pensi che il tuo animale o una persona sia in pericolo, non aspettare una risposta: chiama subito il veterinario, la clinica o il numero di emergenza.

**Breve** (limiti di caratteri): «Non è un servizio di emergenza e non sostituisce il veterinario.»

**Come dirlo correttamente**: descrivere l'app per ciò che fa (aiutare il proprietario a capire il proprio animale, informazioni generali con fonti), **dire una volta, in modo chiaro, ciò che non fa**, e non promettere né far intendere il contrario.

**Da non scrivere** nel negozio, sul sito, nei post e nei reel: «emergenze», «pronto soccorso», «primo soccorso», «24 ore su 24», «sempre disponibile», «ti dice se è grave», «capisce se sta male», «risposte immediate» o «in pochi secondi» (l'attesa arriva a 20 secondi), e schermate o scene d'emergenza mostrate come funzione dell'app. Restano valide le formule da evitare del §16.2 («verificata», «validata», «controllata da esperti»).

**Negozi** (pagine lette il 20 novembre; i testi cambiano, da ricontrollare al caricamento):

- *Google Play*: la dichiarazione «App di salute» (Health apps declaration) va compilata da **tutte** le app; per le app di salute che non sono dispositivi medici la descrizione deve avere un'avvertenza (non è un dispositivo medico, non diagnostica né cura). La regola è pensata per la salute umana: per un'app sugli animali compilare in modo coerente, senza dichiarare funzioni che non ci sono; la frase sopra e «non fa diagnosi» ne rispettano lo spirito. Da chiarire nella console prima del caricamento.
- *Apple*: la linea guida 1.4.1 (app mediche che possono dare informazioni inesatte: più controlli) riguarda le app per le persone. Un forum cita una frase che chiede di ricordare di consultare un medico: **non l'ho trovata nel testo attuale**, da verificare. Non dichiarare diagnosi né gestione di urgenze; indicare le fonti nelle note ai revisori.
- *Fuori dall'Europa* (Stati Uniti, Regno Unito, Australia): valgono i pareri delle sessioni legali per regione; qui solo la frase.

### 20.7 Rischi, senza attenuarli

1. **Rassicurazione sbagliata su un caso grave** — gravità **alta**; probabilità bassa per ogni conversazione, ma certa su molti utenti. Oggi il classificatore d'urgenza e il testo fisso sono un pavimento; col piano 08 il tono lo decide il modello e, in 20 secondi, una fonte debole o nessuna. Una risposta calma e ben scritta su un caso che era grave (per esempio torsione dello stomaco nel cane, blocco urinario nel gatto maschio, stasi intestinale nel coniglio, colpo di calore, ingestione di tossici, difficoltà respiratoria negli uccelli) può far aspettare, e l'animale può morire. È lo scenario che genera cause, recensioni e articoli. Lo riducono: la regola «mai giudicare la gravità» e gli avvisi (§20.4) e il cancello di prova «urgenze e sicurezza non sotto oggi», da tenere come **condizione di rilascio** e da rifare a ogni cambio di modello, prompt o elenco di fonti. Se non passa, si rivede la decisione, non il cancello.
2. **Prova a posteriori** — gravità **media**. Il repository è pubblico: i piani in `docs/llm` e le decisioni registrate lasciano leggere che esisteva un percorso d'urgenza e che è stato tolto per scelta; se i rapporti di prova sono pubblicati o richiesti in giudizio, anche che le prove lo davano migliore sulle urgenze. In una controversia «ha tolto di proposito una misura che funzionava» pesa più di «non l'ha mai avuta». Lo riduce una valutazione del rischio **datata e motivata** (questo §20) con le misure compensative di §20.8: una scelta di prodotto spiegata, con contromisure e verifiche, è difendibile; una rimozione senza spiegazione no.
3. **Gli avvisi hanno un limite di legge** — gravità **media**. Non si esclude la responsabilità per morte o danno alla persona (art. 36 c. 2 lett. a) né per dolo o colpa grave (art. 1229 c.c.). Per la morte di un animale gli avvisi aiutano (riducono il risarcimento se l'utente poteva evitare il danno, art. 1227 c.c.; definiscono ciò che promettiamo) ma non coprono un servizio che ha rassicurato a torto: un avviso non rimedia a un consiglio sbagliato.
4. **Direttiva (UE) 2024/2853, dal 9 dicembre 2026** — gravità **media, incerta** ⚖️. Il software è un «prodotto»; il produttore risponde del difetto senza che si provi la sua colpa; si guarda alla presentazione (avvertenze) e all'uso prevedibile; non si esclude per contratto. Incertezze: se il testo sbagliato di un'IA sia «difetto del software» o «informazione» (che la direttiva non tratta come prodotto); se la morte di un animale sia «danno a una cosa» risarcibile per questa via (il danno alla persona lo è comunque); il recepimento italiano (legge di delega del 17 marzo 2026, n. 36; decreto delegato: stato da verificare in Gazzetta Ufficiale, da una ricerca non riletta alla fonte). Il lancio previsto il 10–20 dicembre 2026 cade subito dopo la data.
5. **Uso prevedibile** — gravità **media**. La chat tratta sintomi e «quando andare dal veterinario»: l'uso in emergenza è prevedibile, e scrivere «non è un servizio di emergenza» non lo fa sparire. Gli avvisi dichiarano lo scopo e riducono l'aspettativa; non annullano la prevedibilità.
6. **Minori di 14–17 anni** — gravità **medio-bassa**. Da soli con un animale in difficoltà leggono meno gli avvisi e si fidano di più. La riga fissa è in parole semplici; restano le misure del punto 57 del registro 08.
7. **Promozione** — **bassa, controllabile**. Un post, un reel o una scheda di negozio che lasciassero intendere la gestione di emergenze trasformerebbero una scelta difendibile in pratica ingannevole (artt. 21–22 Codice del consumo). Si controlla con §20.6 e con la sessione social.
8. **Attesa fino a 20 secondi** — **bassa**. Sul ritardo concordo con il proprietario: pochi secondi non cambiano l'esito di un animale che non è ancora dal veterinario. Il rischio è solo che l'utente aspetti la risposta invece di chiamare: lo copre la frase sulla schermata d'attesa (§20.4).

**Dall'altra parte**, togliere un triage nostro **riduce** due rischi: quello di «attività riservata» (art. 348 c.p. ⚖️: decidere che cosa è urgente è più vicino alla valutazione del caso che a un'informazione generale) e quello di scrivere noi testi di sicurezza che, se sbagliati, sono nostri (i passi d'urgenza scritti a mano hanno richiesto più correzioni dopo lo studio della letteratura, commit 277e70a).

### 20.8 Condizioni che raccomando se il proprietario conferma «nessuna corsia»

1. Avvisi uguali per tutti di §20.4: riga fissa più visibile, schermata d'attesa, riga di trasparenza, Info, Termini, Assistenza, primo uso.
2. Regola sulle risposte «mai giudicare la gravità del caso», nel prompt e con un controllo del codice.
3. Cancello di prova «urgenze e sicurezza non sotto oggi» come **condizione di rilascio**, rifatto a ogni cambio di modello, prompt o elenco di fonti; se non passa, la decisione torna al proprietario.
4. Frase per la persona ferita nella riga fissa, per Paese (§20.5).
5. Negozio, sito, post e reel: la frase di §20.6 e le parole da non usare.
6. Questa valutazione conservata nel repository, datata, e rivista dopo il primo trimestre con i reclami e le segnalazioni ricevuti. Le nuove frasi si traducono nelle 5 lingue dopo l'approvazione dell'italiano.
7. Punti ⚖️ 17 e 18 a un legale prima del lancio (la scadenza di recepimento della direttiva sul prodotto è il 9 dicembre 2026).

### 20.9 Incoerenze da allineare (a cura degli altri)

- **Piano 08**: la sezione «Verifica» (riga ~191) elenca ancora «apertura urgente quando serve» e il lavoro A (riga ~166) dice «pericolo deciso dalle regole»: contraddicono «nessuna corsia». Resta il cancello «urgenze e sicurezza non sotto oggi» (riga ~178), che io terrei.
- **Codice**: `packages/core/domain/localization.py` (riga 398), stringa dell'apertura urgente: la Chat decide se toglierla o riusarla negli avvisi.
- **Termini e informativa in preparazione** ([it/03](it/03_termini_di_servizio_it.md) §2): la frase di §20.4 si aggiunge al momento di chiudere la T1.
- **Fatto**: 11 §3.2 annotata; §13 e §16.1 di questo documento corretti.

### 20.10 Decisioni del 20 novembre (riferite dall'Orchestratore) e registrazione

Dopo il parere, l'Orchestratore ha portato il quadro al proprietario e ha riferito queste decisioni (piano 08 aggiornato su main, a46ccb4). Le registro con la fonte di ciascuna e con i rischi che sono stati esposti:

| # | Decisione | Nota della Normativa |
|---|---|---|
| 1 | **Apertura urgente: tolta.** | Vale la correzione di §20.1: non era un obbligo. |
| 2 | **Frase del 112 per la persona ferita: tolta**, per decisione esplicita del proprietario. Motivo riferito: «chi ha un ferito davanti non apre l'app». | **La scelta è sua e il rischio gli è stato esposto** (§20.5 e §20.7 n. 3: nessun avviso esclude la responsabilità per il danno alla persona, art. 36 c. 2 lett. a Codice del consumo e art. 1229 c.c.). Nessuna norma impone la frase (§20.2). Caso residuo: la persona **chiede all'app di un morso o di un'aggressione** (il Manuale e la chat trattano già il morso, casi 37 e 60) e la risposta parla solo del cane e degli obblighi di legge; lo copre soltanto ciò che dicono le fonti lette. Rischio registrato come **accettato dal proprietario** |
| 3 | **Regola 2e adottata** («mai giudicare la gravità senza fonte; non attenuare un rischio indicato dalla fonte») per tutte le risposte e come **condizione di rilascio**: zero rassicurazioni sbagliate sui casi gravi nella prova. | È la misura più efficace contro il rischio n. 1 di §20.7. Per renderla verificabile la prova deve avere casi in cui la fonte dice «urgente» e casi in cui un modello tenderebbe a rassicurare |
| 4 | **Avvisi: una sola riga di interfaccia, uguale per tutti.** Niente frase sulla schermata d'attesa: **scelta dell'Orchestratore, non del proprietario**, per rispettare «nessun avviso anticipato». | Delle proposte di §20.4: adottata (a) in forma ridotta (§20.11), adottate (d) ed (e); **non adottate** (b), (c) e il pulsante (f). La frase d'attesa non la ritengo indispensabile (§20.7 n. 8, rischio basso); ritiro anche la (c): la riga fissa porta il messaggio |
| 5 | **Termini, Info, negozio e sito**: «non è un servizio di emergenza», come proposto. | Frasi in §20.11, senza il riferimento alla persona ferita (coerenza con la decisione 2) |
| 6 | **Fonti che richiedono un permesso**: restano non lette. Il proprietario aveva chiesto di leggerle senza citarle; l'Orchestratore ha risposto di no. | **Concordo.** Leggere senza citare è comunque leggere: la riserva colpisce la lettura (§18.3), non la citazione |

### 20.11 Testi definitivi proposti dalla Normativa (da approvare)

**Riga di interfaccia** (italiano; le altre lingue dopo l'approvazione), 98 caratteri:

> Risponde un'IA e può sbagliare. Non è un servizio di emergenza: nel dubbio, chiama il veterinario.

- **La bozza dell'Orchestratore** («… Non è un servizio di emergenza e non sostituisce il veterinario.», 96 caratteri) **regge come minimo**: dichiara la natura del servizio e che l'IA sbaglia, e non fa credere che l'app gestisca emergenze. Perde l'unica parte che dice **che cosa fare**, e così si indebolisce la difesa del concorso di colpa (art. 1227 c.c.). Per questo propongo «nel dubbio, chiama il veterinario», che occupa lo stesso spazio; «non sostituisce il veterinario» è già nel badge, nella riga di trasparenza, nei Termini e nel primo uso.
- **Senza «può non riconoscere un'urgenza» la riga regge.** Quella frase serviva a evitare che si legga il silenzio dell'app come «allora non è urgente». Con la regola 2e il silenzio non rassicura più: il rischio si sposta sulla regola, che è condizione di rilascio. Se la regola non supera il cancello, la riga da sola non basta a compensare. La frase resta nei Termini, nell'Info e nel negozio, dove lo spazio non manca.

**Negozio, sito e pagina di assistenza:** «Quokka non è un servizio di emergenza e può non riconoscere un'urgenza. Non sostituisce il veterinario: se pensi che il tuo animale sia in pericolo, non aspettare una risposta e chiama subito il veterinario o la clinica.» Breve: «Non è un servizio di emergenza e non sostituisce il veterinario.» Restano valide le parole da non scrivere (§20.6).

**Termini §2** ([it/03](it/03_termini_di_servizio_it.md)): «Quokka non è un servizio di emergenza e può non riconoscere un'urgenza. In caso di emergenza vai subito da un veterinario o in una clinica.» (inserita il 20 novembre). **Info** ([11](11_esclusioni_responsabilita.md) §3.2): «non è un servizio di emergenza e può non riconoscere un'urgenza» (inserita).

### 20.12 Prova tecnica della Chat su pagine campione (da registrare)

L'Orchestratore riferisce che la sessione Chat, in una prova tecnica **partita prima del mio parere sull'elenco bianco (§19)**, ha letto **una volta** una pagina campione di nove siti (per ognuno 2 richieste semplici e 1 lettura del modello); nessun testo conservato. Il dettaglio (siti, date, esiti) sta **solo nei registri interni** (`.local/chat_eval/prova2/prova_tecnica.md` e `.local/chat_eval/biblioteca/registro_user_agent.md`): **nei documenti pubblici non si mettono nomi di siti per gli incidenti** (decisione del proprietario riferita dall'Orchestratore, 20 novembre).

| Gruppo (§19) | Giudizio |
|---|---|
| Licenza aperta o ente pubblico con riuso consentito (verde, anche con riserva), senza barriere note (tre siti) | nessun problema per una lettura; per l'agenzia USA, dove il sito non ha `robots.txt` (nessuna restrizione per i programmi), vale «verde con riserva» (§16.4) |
| Licenza aperta, ma con barriere note (tre siti) | **diritti: nessun problema; accesso: possibile aggiramento di fatto** (vedi «Esito del registro»). Nel §19 sono già «a mano» (barriera, `robots.txt` anomalo, nota non raggiungibile): la prova è anteriore |
| **(c): solo con permesso** (tre siti) | **lettura fatta senza permesso, una volta, prima del parere**: da **registrare**, non va ripetuta |

**Giudizio.** Prova una tantum, anteriore al parere, senza testo conservato: **non serve sanare nulla con i titolari**; se uno di loro lo chiedesse, si risponde con il registro interno. Per i siti (c) **nessuna lettura, nemmeno «per prova»**, né nella prova 2 né in produzione. Le pagine lette dal modello sono passate ad Anthropic (conservazione fino a 30 giorni, §18.3), anche per i siti (c).

**Il nome usato nelle richieste.** Delle due «richieste semplici» a ogni sito, una si presentava con il nome di un browser e l'altra con il nome dell'agente di un'altra azienda; **corretto**: ora ogni richiesta del programma si presenta con un nome proprio. Le richieste partivano solo dopo la lettura del `robots.txt`. Giudizio, che dipende dall'**esito di ciascuna delle due richieste, sito per sito**:

- *Stessa risposta con le due identità*: nessun aggiramento di fatto. Resta uno **scivolone di identificazione**, già corretto: non crea un'esposizione nuova (una stringa di User-Agent non è una misura di sicurezza; nessuna credenziale né area protetta; una pagina pubblica letta una volta; reato informatico: rischio molto basso ⚖️) e non cambia «nessuna sanatoria, non ripetere». Per i siti (c) **peggiora la posizione in buona fede**, e va in registro come **violazione delle nostre regole** («nessun blocco aggirato», §21.1 condizione 2).
- *Identità onesta bloccata o sfidata e nome di browser passato*: **aggiramento di fatto** di quel sito. Si scrive così nel registro, **nessuna nuova richiesta a quell'host** (né a mano né con un programma, salvo permesso scritto) e va detto al proprietario come incidente. Con nulla conservato il danno pratico resta basso; la regola però è stata violata.
- **Il nome dell'agente di un'altra azienda** è una **falsa attribuzione** anche se il `robots.txt` lo consentiva: non si usa mai.
- **Nessuna comunicazione ai siti ora**; se un titolare lo chiede, si risponde con il registro. Nelle lettere di permesso non si menziona il test, salvo domanda.

**Esito del registro (20 novembre notte, riferito dall'Orchestratore).** (1) Gli esiti delle due richieste semplici **non sono ricostruibili** per nessuno dei nove siti: i codici stavano solo nel file dei risultati, cancellato quando è stato applicato il §19. (2) Su sei siti il modello ha letto con il nome da programma IA: **nessun aggiramento**. (3) Su **tre siti con barriere note** la lettura del modello è fallita: **non si può escludere** che la richiesta con il nome di browser sia passata dove il nome da programma veniva fermato. La Chat la tratta come **possibile aggiramento di fatto**: nessuna nuova richiesta a quei tre host; riferito al proprietario come incidente. Di quelle risposte non è stato usato nulla (solo byte e token, cancellati). (4) Anche la «richiesta 1» si presentava con il nome dell'agente di un'altra azienda. (5) Su disco restano solo misure e `robots.txt`; cancellati i campi con due parole di descrizione della pagina. (6) Tutti gli altri strumenti, compresi quelli della sessione Manuale, usano un nome proprio; nuovo test automatico sui nomi.

**Giudizio sui tre siti con barriere.** La Chat ha fatto la cosa giusta: nel dubbio, trattarlo come aggiramento. **Bastano lo stop e la registrazione, con tre precisazioni.** (a) **Nessun nuovo tentativo per sciogliere il dubbio**: ripetere le due richieste per vedere quale passa sarebbe una nuova richiesta a un sito con barriera e, se passasse quella con il nome di browser, un aggiramento certo; il dubbio resta scritto come «possibile». (b) Nessuna comunicazione ai siti e nessun dato da cancellare. (c) I tre host restano **fuori da ogni lettura da programma**, anche al momento: nell'elenco bianco «lettura al momento: no; scarico a mano» (§19). **Gravità:** rischio giuridico **basso** (contenuti con licenza aperta o nota da leggere a mano, una richiesta per sito, nulla conservato, nessuna credenziale né area protetta); **non è una violazione di dati personali** (la procedura delle 72 ore di `docs/security/03` non si applica); è però una violazione della regola «nessuna barriera aggirata» (§18.3, §21.1), riferita al proprietario come incidente. **Test automatico: meglio positivo**: ogni User-Agent deve **iniziare con «Quokka»**; il controllo su «Mozilla» e «Claude» resta come minimo.

### 20.13 Il 112 scritto dal modello: minore solo in casa (20 novembre notte)

**Quesito dell'Orchestratore.** Nella prova 2 la chat nuova, a un ragazzo di 12 anni solo con il cane che sta male, ha scritto da sé «chiama un familiare, un vicino o il 112 se non riesci a trovare nessuno»; la frase fissa del 112 è stata tolta dal proprietario il 20 novembre. **Parere: riformulare**, non lasciare e non vietare ogni accenno, con una regola del prompt valida per tutte le risposte (non è una corsia). **Proposta della Normativa, in attesa del sì del proprietario** per il punto 4; i punti 1–3 non dipendono da lui:

1. Con un minore (da profilo o dichiarato in chat) la prima indicazione è **«un adulto di cui ti fidi»** (un familiare, un vicino): è già la regola raccomandata per i minori (§13.4; registro 08, punto 57).
2. **Il modello non scrive numeri di telefono, nemmeno il 112**: a memoria possono essere sbagliati per il Paese dell'utente (§16.3) e il 112 non è una linea veterinaria.
3. Per il cane: se non c'è un adulto e sta molto male, **«una clinica veterinaria»**.
4. Se il ragazzo o un'altra persona è ferita o in pericolo, **«chiama subito i soccorsi o il numero di emergenza del tuo Paese»**, senza cifre. Non è la riga fissa tolta dal proprietario ma una frase di buon senso dentro la risposta; se il proprietario preferisce che il modello non dica nulla, il punto 4 cade e restano 1–3.

Un utente di 12 anni è sotto l'età minima (14, Termini §1): non cambia la risposta, che coinvolge comunque un adulto. Nessun obbligo di legge: è prudenza per i minori.

## 21. Elenco bianco: EUR-Lex tramite l'Ufficio delle pubblicazioni e legge svizzera sugli animali (20 novembre notte)

Due domande della sessione Manuale, portate dall'Orchestratore. Pagine e file letti il 20 novembre 2026; i `robots.txt` con una sola richiesta ciascuno.

### 21.1 EUR-Lex: `publications.europa.eu/resource/celex/<CELEX>` è un accesso corretto o un aggiramento?

**È un accesso corretto, a condizioni.** Che cosa ho trovato:

- **EUR-Lex** (`eur-lex.europa.eu`): una richiesta con un programma al suo `robots.txt` ha restituito una risposta vuota, coerente con la barriera anti-automatica segnalata dalla sessione Manuale. Il file, letto a mano il 17 novembre, chiedeva una pausa di 10 secondi (§2.2).
- **La pagina ufficiale «Reuse EUR-Lex content»** dice che i contenuti si riusano gratuitamente, a condizioni di copyright; che EUR-Lex li prende da un archivio comune (Cellar); che i documenti si scaricano **direttamente dall'interfaccia REST e dal punto SPARQL di Cellar**; e che per grandi volumi si usa l'accesso diretto a Cellar o il *data dump* (serve un account EU Login). L'indirizzo `publications.europa.eu/resource/celex/<CELEX>`, con l'intestazione `Accept` per il formato e `Accept-Language` per la lingua, è l'**interfaccia di diffusione documentata** di Cellar (la documentazione usa codici di lingua di tre lettere, per esempio `ita`).
- **`robots.txt` di `publications.europa.eu`**: `Allow: /` per tutti, con divieti su alcuni percorsi (tra cui `*requestAction=rdf`, `/webdav/*` e i parametri di sessione dei portali); `/resource/celex/` non è tra questi.

**Giudizio.** La barriera riguarda la **facciata** di EUR-Lex; la stessa istituzione indica Cellar come canale per scaricare i testi con un programma, e il suo `robots.txt` lo consente. **Non è un aggiramento**: non si evita nessuna misura posta a quell'indirizzo, non si finge di essere un browser, non si supera nessuna sfida. Non vedo un'elusione di misure tecnologiche di protezione (art. 102-quater L. 633/1941) ⚖️, rischio basso: la barriera protegge il servizio dagli abusi, non un diritto d'autore su atti riusabili. **Sarebbe** un aggiramento: fingersi un browser su `eur-lex.europa.eu`, superare la sfida con un browser automatico, cambiare indirizzo IP, usare specchi di terzi.

**Condizioni:**

1. Solo l'interfaccia documentata (`/resource/celex/...`) e i percorsi che il `robots.txt` non vieta: niente `requestAction=rdf`, `/webdav/`, pagine dei portali.
2. **Nessuna barriera incontrata e aggirata**: se la risposta o un reindirizzamento porta a una pagina di verifica, a un blocco (403, 429) o a una pagina di `eur-lex.europa.eu` con la sfida, ci si ferma e non si insiste. Nessuna intestazione che imiti un browser; nome di client generico, senza dati del progetto o delle persone.
3. Una richiesta ogni 10 secondi (la pausa del `robots.txt` di EUR-Lex, tenuta come regola nostra). Per decine di atti basta; per centinaia o più, il *data dump* con EU Login.
4. **Controllare lingua e versione restituite**: la lingua deve essere quella chiesta. `celex/3…` è l'atto **come pubblicato** (può essere stato modificato o abrogato: non lo si presenta come «in vigore»); la versione **consolidata** (CELEX che inizia con `0`, con data) è quella da usare per le note, e la data si scrive. Il consolidato è uno strumento di documentazione senza valore legale: fa fede solo la Gazzetta ufficiale dell'UE.
5. Registro per documento (§7): CELEX, versione (originale o consolidata e data), lingua, indirizzo, data di scarico.
6. Riuso: atti secondo la decisione 2011/833/UE; testi consolidati CC BY 4.0 con la fonte e la dicitura «modificato» (§2.2).

**Riga fonte.** Atto come pubblicato: «Fonte: [tipo e numero], GU UE L [n.] del [data]. Testo dell'Ufficio delle pubblicazioni dell'Unione europea (publications.europa.eu), copia non ufficiale: fa fede solo la Gazzetta ufficiale dell'Unione europea.» Testo consolidato: «Fonte: testo consolidato del [tipo e numero], versione del [data], Ufficio delle pubblicazioni dell'Unione europea (EUR-Lex), licenza CC BY 4.0. Testo senza valore legale: fa fede solo la Gazzetta ufficiale. Estratto o riassunto modificato da Quokka.»

### 21.2 Ordinanza svizzera sulla protezione degli animali (OPAn): la traduzione inglese non ufficiale dell'USAV

**Meglio lasciarla fuori come fonte citabile finché non c'è il testo ufficiale.** Come aiuto di lettura interno è ammessa, a condizioni. Perché:

1. **Non è la legge, e lo dichiara.** Il PDF inglese dell'USAV che ho trovato oggi (revisione dell'ordinanza del 20 dicembre 2024) porta la dicitura «solo a scopo informativo, senza valore legale»; fanno fede il tedesco, il francese e l'italiano. Mostrare all'utente un testo così come «legge svizzera» è un'attribuzione imprecisa (§4.4).
2. **Diritti non chiari.** In Svizzera non sono protette le traduzioni *ufficiali* di leggi e ordinanze (art. 5, c. 2, URG). In Italia l'art. 5 L. 633/1941 copre i **testi degli atti ufficiali**, anche stranieri, ma non dice nulla sulle traduzioni; la Convenzione di Berna (art. 2, c. 4) lascia la questione alle leggi nazionali. Una traduzione *non ufficiale* fatta da un ufficio federale non rientra con certezza in nessuna delle due ⚖️. I termini del sito USAV non li ho letti oggi (il suo `robots.txt` non vieta nulla).
3. **Errore a catena.** La catena tedesco o francese → inglese → italiano aggiunge errori proprio dove l'OPAn ha numeri e obblighi (spazi minimi, animali che vivono in gruppo, corsi). Il PDF trovato oggi è una **modifica** dell'ordinanza, non il testo consolidato: rischio di versione vecchia.
4. **Il testo ufficiale esiste ed è libero**: l'italiano su Fedlex (RS 455.1 per l'ordinanza, RS 455 per la legge; numeri da confermare). È un atto ufficiale: art. 5 L. 633/1941 e, in Svizzera, art. 5, c. 1, lett. a, URG. Gruppo (a).

**Come procurarselo.** `www.fedlex.admin.ch` è dinamico e il suo `robots.txt` non vieta nulla, ma lo strumento non lo legge. I file dei testi (PDF e XML) stanno, di norma, sotto `/filestore/` dell'host dati (`fedlex.data.admin.ch`), che il suo `robots.txt` **vieta a tutti i programmi**: **li scarica a mano il proprietario**, come per Lexbrowser (§16.5), e **non** si provano dalla porta di servizio. Percorso dei file da confermare allo scarico. Riga fonte: «Fonte: Fedlex, Raccolta sistematica del diritto federale (RS 455.1), versione del [data], testo in italiano. Testo consolidato senza valore legale: fa fede la Raccolta ufficiale.» ⚖️ da confermare sulle note legali di Fedlex.

**Nel frattempo.** Per le domande sulla legge svizzera la chat risponde senza fonte svizzera e senza asterisco, e rinvia all'ufficio veterinario cantonale o all'USAV (formula alla Chat).

**Se la squadra vuole comunque usare la traduzione inglese** (per preparare le note prima dell'italiano): (a) solo come aiuto di lettura, **mai citata all'utente**; (b) al massimo il livello «In parte con fonti», mai «Con fonti ufficiali»; (c) nessuna nota con numeri o obblighi prima del riscontro sul testo ufficiale; (d) registrare pagina dell'USAV, data e dicitura; (e) se un giorno fosse citata, la dicitura è: «Traduzione inglese non ufficiale dell'Ordinanza svizzera sulla protezione degli animali, pubblicata dall'USAV per informazione e senza valore legale; fa fede il testo ufficiale in tedesco, francese e italiano (Fedlex).»

## 22. Accesso alle fonti: nome con cui ci si presenta, sfide anti-robot e lettura dei termini (20 novembre notte)

**Richiesta dell'Orchestratore progetto**, dopo il controllo della sessione Manuale sui nomi usati nelle richieste. Il registro completo (siti, comandi, date) sta in `.local/chat_eval/biblioteca/registro_user_agent.md`, **fuori dal repository**: qui, nel repository pubblico, mettiamo le regole e il giudizio, **senza nomi di siti**. Non è consulenza legale: i punti ⚖️ (§11, n. 20 e 21) vanno a un legale.

### 22.1 Che cosa è emerso

Nelle giornate dell'8 e 10 novembre, nella fase delle schede di salute e del catalogo delle fonti, circa 95 comandi `curl` (della sessione Manuale e di 5 sotto-agenti) si sono presentati con un nome di browser su circa 50 siti, e uno strumento della piattaforma ha letto 101 pagine singole su circa 40 siti con un nome che la sessione non sceglie. Una dozzina di siti ha risposto con una sfida anti-robot o un rifiuto. Accertato il 20 novembre: in due casi, dopo una sfida su `curl`, la pagina è stata aperta con il browser del programma (in uno dopo aver provato altre copie con il nome di browser); la sfida **non è stata superata** (attesa, uno screenshot, nessun clic) e **nulla è stato letto né usato**. Dal 15 novembre le richieste usano nomi propri. Le 206 note della biblioteca vengono solo da letture con nome onesto (17–20 novembre). **Tre schede di salute su undici** (41 frasi) poggiavano su documenti di una società professionale letti con il nome di browser, e il catalogo delle fonti (doc 15) è stato compilato quasi tutto così; il 20 novembre il proprietario ha chiuso il progetto delle schede (§22.4). Per molti siti non si sa come avrebbero risposto a un programma onesto.

### 22.2 Che cosa cambia rispetto al primo incidente (§20.12)

| | Primo incidente | Secondo incidente |
|---|---|---|
| Dimensione | 9 siti, una pagina ciascuno, 2 richieste | circa 50 siti, circa 95 comandi, 5 sotto-agenti, 2 giorni |
| Natura | prova tecnica: una richiesta su due con nome di browser | **prassi di lavoro**: il nome di browser era il nome usuale dei comandi |
| Uso del contenuto | nulla conservato | contenuto usato per schede e catalogo, **pubblicati nel repository** |
| Dopo una sfida | nessun passaggio ad altro strumento accertato | **due casi** di ricerca di un'altra strada (altre copie con nome di browser, poi il browser del programma): sfida **non superata**, nulla letto né usato |
| Esiti | non ricostruibili | stima automatica sul testo delle risposte; per i siti mai provati con nome onesto non si sa come avrebbero risposto |
| Resta uguale | nessun dato personale, nessuna credenziale, pagine pubbliche, nulla da notificare a un'autorità | idem |

### 22.3 Rischi, senza attenuarli

1. **Aggiramento delle indicazioni leggibili da macchina.** Un `robots.txt` scritto per i robot di IA per nome non si applica a una richiesta con nome di browser. Dove un sito aveva una regola così e la richiesta ricevette il contenuto, la sua preferenza dichiarata è stata evasa. Non sappiamo quali siti avessero regole per nome né che cosa dicesse il file l'8 e il 10 novembre. Effetto: indebolisce la buona fede in qualunque contestazione e pesa sulle future richieste di permesso.
2. **Violazione dei termini d'uso** (probabilità bassa, impatto basso o medio). Molti editori e società vietano robot e raccolta automatica; con un nome di browser la violazione è **consapevole**. Possibili: blocco dell'indirizzo, diffida. Il valore di un divieto contrattuale su pagine pubbliche in Europa è discusso (CGUE C-30/14) ⚖️.
3. **Passaggio dopo una sfida** (accertato: tentativo fallito). In due casi, dopo il blocco di un `curl`, si è cercata un'altra strada: prima altre copie con il nome di browser, poi il browser del programma. La sfida **non è stata superata** (attesa di 18 secondi in un caso, uno screenshot, nessun clic), l'articolo a pagamento **non è stato letto** e **nulla è stato usato**: nessun accesso, nessun contenuto. Resta una condotta che le nostre regole (§18.3, §21.1) vietano (nessun cambio di strumento dopo un blocco) e che anche le regole d'uso degli strumenti dell'agente vietano (CAPTCHA e controlli anti-bot): da riferire come tale. Rischio giuridico praticamente nullo, perché non c'è stato accesso ⚖️. Un dettaglio minore: a un'interfaccia che chiede un indirizzo di posta ne era stato dato uno non valido; per le interfacce che lo chiedono serve un indirizzo di progetto, non personale e non inventato (decide il proprietario).
4. **Storia pubblica del repository: il rischio più concreto, e indipendente dal nome usato.** Le bozze del 10 novembre (commit 2aff180 e efcfcd8) sono nella cronologia pubblica. Accertato il 20 novembre: **100 frasi in 8 schede** poggiavano su fonti poi tolte, circa 80 su fonti a diritti riservati (rosse) e 23 su studi con licenza CC BY (che consente la traduzione con attribuzione). Il controllo di vicinanza di allora riguardò solo le fonti verdi e gialle (8 frasi vicine su 54, più 20 parafrasi vicine, tutte riscritte in efcfcd8); le fonti rosse **non furono riesaminate**: un giro precedente ne aveva segnalate 8 come vicine, ma su un testo poi riscritto prima del commit e mai rigiudicato, e la lista di rilettura a mano non fu mai fatta. **La vicinanza non è oggi verificabile** (le copie degli originali sono state cancellate); le frasi senza giudizio sono «non segnalate», non «verificate». Se in quelle bozze ci sono frasi che seguono da vicino testi protetti, sono una traduzione pubblicata (artt. 16 e 18 L. 633/1941) ⚖️. Probabilità di contestazione bassa oggi, **più alta dopo il lancio** (il repository è pubblico e il progetto sarà visibile). La conseguenza realistica è una richiesta di rimozione, che al gestore del repository può portare alla disattivazione del repository finché il contenuto non è tolto. Togliere i file dal ramo attuale non le toglie dalla cronologia. Dopo la cancellazione delle schede (20 novembre) il controllo automatico non trova più quelle frasi nel ramo attuale (restano 4 corrispondenze di una stringa generica dell'app).
5. **Affermazioni pubbliche.** Non va detto in negozio, sul sito o nella pagina «Fonti e licenze» che le fonti raccolte l'8 e il 10 novembre (schede e catalogo, oggi chiusi) sono prese «nel rispetto delle regole dei siti» (artt. 21–22 Codice del consumo). Per la biblioteca (letture del 17–20 novembre) l'affermazione si può fare solo con il registro in mano. Il messaggio del commit 089925b («fonti … che consentono la lettura automatica») non è provato per tutte le fonti: non si ripete.
6. **Strumenti della piattaforma.** Nome non scelto, rispetto del `robots.txt` non noto; letture di pagine singole di termini e note legali. Rischio basso (§22.5).
7. **Esposizione per ammissione.** Il repository è pubblico: i dettagli degli incidenti (siti, comandi, esiti) restano nei registri interni; nei documenti pubblici, regole e giudizio senza nomi. **Deciso dal proprietario il 20 novembre** (riferito dall'Orchestratore): nei documenti pubblici niente nomi di siti per gli incidenti; il dettaglio resta nei registri interni. Il §20.12 e il registro 08 sono stati ridotti di conseguenza.

### 22.4 Schede e catalogo: progetto chiuso il 20 novembre

**Decisione del proprietario** (riferita dall'Orchestratore, 20 novembre): cancellare tutte le schede di salute e ciò che rimanda ad esse. Fatto e pubblicato su `main` (235b309): le 11 schede tolte; `fonti.json` e `health_cards.json` ridotti a liste vuote; i documenti 15a e 16 cancellati; i documenti 13 e 15 dell'area prodotto con la nota «progetto delle schede chiuso il 20/11/2026». Il codice che le leggeva, già spento, lo toglie la sessione Chat dopo la prova 2. **Ritiro parziale, riscrittura su fonti verdi e ripasso a mano non servono più**: sono superati.

- **Controllo automatico dopo la cancellazione** (sequenze di 6 o più parole uguali tra le 100 frasi delle bozze e il ramo attuale): restano 4 corrispondenze, tutte la stessa stringa dell'app di 6 parole anatomiche generiche. **La condizione «nessuna frase stretta nel ramo attuale» è soddisfatta**, con un limite: il controllo confronta le nostre frasi, non gli originali (non più disponibili).
- **Il catalogo** (doc 15) resta come descrizione di fonti e licenze, con la nota di chiusura; prima di usare una fonte si legge la sua nota.
- **Cronologia pubblica: non si riscrive.** Il rischio residuo è quello del §22.3 n. 4 (probabilità bassa oggi, più alta dopo il lancio; la conseguenza realistica è una richiesta di rimozione che può portare alla disattivazione del repository): lo si registra (registro 08, punto 69) e si tiene pronta la procedura del §22.9.
- **Indirizzo pubblico per i titolari dei diritti**: il proprietario non ha ancora risposto; resta un punto aperto ad **alta priorità** (così scrivono a noi prima che al gestore del repository).

### 22.5 Lettura dei termini con uno strumento della piattaforma o con il browser

**È il controllo dovuto, a condizioni.** Leggere le pagine legali di un sito (termini, note di copyright, `robots.txt`) per classificarlo è previsto dal controllo in 4 punti e non è uso del contenuto. Condizioni: (1) nome onesto (lo strumento della piattaforma ha il suo, non scelto da noi, e va bene; mai un nome di browser per un programma); (2) prima il `robots.txt`; (3) una pagina per volta, nessuna scansione; (4) se compaiono sfide, CAPTCHA o rifiuti, **ci si ferma** e la pagina la legge a mano il proprietario; (5) registrare URL, data, strumento ed esito. Il browser del programma: stesso criterio; non si completano controlli anti-bot. Con lo strumento della piattaforma il rispetto del `robots.txt` non è noto (la pagina di Anthropic sui suoi agenti dice che l'agente per le richieste degli utenti lo rispetta: da riverificare per questo strumento): per la sola lettura di una pagina legale il rischio è basso.

### 22.6 Regole di accesso (valgono per tutti gli strumenti e le sessioni)

1. Nome proprio del progetto (`Quokka…`), mai un nome di browser né di un'altra azienda; test automatico **positivo** (il nome deve iniziare con «Quokka»).
2. Ordine: `robots.txt` (per nome e per `*`, segnali `Content-Signal` e `ai-train`) → termini → decisione → eventuale lettura.
3. **Stop a sfida, CAPTCHA, 403/429 e blocchi**: nessun cambio di strumento (nemmeno il browser del programma), nessuna riprova con un altro nome. Si passa a mano o a un canale documentato dal gestore (§21).
4. Un host con blocco entra nell'elenco «a mano»; nessuna richiesta «di prova».
5. Pausa di 10 secondi tra richieste allo stesso host, **anche tra comandi e sotto-agenti in parallelo** (il turno si prenota in modo atomico prima di aspettare: §22.10); campioni, non scansioni.
6. **Registro per richiesta**: data, nome, URL, codice di esito, conservato per tutto il lavoro. **Non si cancella il file dei risultati prima di averlo registrato** (nel primo incidente i codici di esito erano stati cancellati: oggi non si sa che cosa è successo).
7. Dopo un incidente: registro interno, avviso al proprietario, nessuna nuova richiesta all'host, nessuna nuova prova per «capire».
8. Nessuna comunicazione ai siti salvo loro richiesta; se arriva, si risponde con il registro.

### 22.7 Stato (20 novembre notte)

Decisioni del proprietario riferite dall'Orchestratore: schede cancellate (§22.4); cronologia non riscritta, rischio residuo registrato (§22.3 n. 4, §22.9); nei documenti pubblici niente nomi di siti per gli incidenti, il dettaglio resta nei registri interni (`.local/`). Resta aperto l'indirizzo pubblico per i titolari dei diritti (alta priorità). La regola del §22.8 la inserisce l'Orchestratore in `CLAUDE.md` dopo il sì del proprietario.

### 22.8 Testo breve per `CLAUDE.md` (da approvare; senza nomi di siti)

> **Richieste a siti esterni** (vale per tutte le sessioni e per i sotto-agenti; riferimento: `docs/compliance/20` §22)
>
> - **Nome**: ogni programma o comando (`curl`, script) che contatta un sito esterno si presenta con un nome proprio che inizia con «Quokka» (`-A "QuokkaLibrarian/0.1"`). Mai un nome di browser o di un'altra azienda, mai dati personali nel nome. Un test fallisce se il nome non inizia con «Quokka».
> - **Ordine**: prima `robots.txt` (per nome e per `*`; contano anche `ai-train=no` e `Content-Signal`), poi i termini d'uso, poi il contenuto. Se c'è un divieto, non si legge da programma.
> - **Stop** a sfida, CAPTCHA, pagina di verifica, 403, 429 o blocco: nessun altro strumento o nome «per passare», nessuna riprova. L'host passa a «a mano».
> - **Comandi a mano e sotto-agenti**: stesse regole; 10 secondi tra richieste allo stesso host, **anche tra più comandi o sotto-agenti insieme: il turno si prenota in modo atomico (blocco condiviso) prima di aspettare, e il primo 403, 429 o sfida ferma tutti per quell'host**; ogni richiesta registrata (data, nome, URL, esito) in un file che non si cancella prima di averlo riportato nel registro. Il brief di ogni sotto-agente include questa regola.
> - **`WebFetch` e browser del programma**: solo pagine singole di termini e note legali, `robots.txt` e fonti ufficiali o con licenza aperta; mai il contenuto di siti che chiedono permesso o hanno barriere. Il browser non completa CAPTCHA né controlli anti-bot.
> - **Nessun contatto con i siti** o i loro titolari: lettere e richieste di permesso le invia il proprietario.
> - **Se succede**: avvisare subito l'Orchestratore, scrivere nel registro interno (`.local/`, mai nel repository pubblico), nessuna nuova richiesta a quell'host, nessuna prova «per capire».
> - **Eccezioni**: solo con permesso scritto del titolare del sito, valido per ciò che dice.

**Consiglio tecnico** (non mio): un unico comando per le richieste a siti esterni (nome proprio, lettura di `robots.txt`, pausa, registro dei codici di esito) rende la regola il comportamento predefinito invece di una disciplina da ricordare.

### 22.9 Procedura di rimozione su richiesta (da tenere pronta)

1. Un titolare scrive (all'indirizzo pubblico per i titolari dei diritti, o al gestore del repository).
2. **Entro 24 ore** si tolgono dal ramo attuale i file o le frasi indicati, anche se la richiesta non è provata.
3. **Entro 3 giorni lavorativi** si risponde: si chiede che cosa è contestato e si dice che cosa è stato tolto. Il merito non si discute per iscritto prima di aver sentito un legale ⚖️.
4. Se la richiesta riguarda la cronologia: il proprietario decide la riscrittura per i soli file interessati, da fare con il gestore git in un momento concordato con tutte le sessioni (copie di lavoro, rami, pubblicazione).
5. Registro interno: data, titolare, che cosa è stato tolto, risposta.
6. Se è il gestore del repository ad avvisare per primo: stessa procedura, con precedenza assoluta (un repository disattivato ferma anche la pubblicazione).

### 22.10 Terzo incidente: pausa di 10 secondi non rispettata tra comandi in parallelo (21 novembre sera)

**Richiesta dell'Orchestratore progetto.** Il dettaglio (siti, orari) sta solo nel registro interno (`.local/cercafonti/incidenti.md`); qui regole e giudizio, **senza nomi di siti** (§22.3 n. 7). Non è consulenza legale.

**Che cosa è successo.** Durante la ricerca grande del Cercafonti più sotto-agenti e il comando di importazione hanno lavorato insieme. Il programma teneva l'«ultimo turno» di ogni host in un file, ma lo leggeva e lo scriveva senza prenotarlo (una gara tra comandi): due comandi partiti insieme leggevano lo stesso valore e colpivano l'host nello stesso secondo. Sul registro (273 richieste) si contano **53 coppie di richieste allo stesso host a meno di 9,5 secondi**, su 9 host. Un host pubblico statunitense ha risposto 403 dopo tre richieste nello stesso secondo: è stato **fermato, senza riprove**. Nessun altro host ha dato 403, 429 o sfide (solo reindirizzamenti, qualche 404, tre errori di rete). `robots.txt` rispettati; nessun dato personale; nessun contenuto usato in modo diverso dal previsto. Corretto in giornata: il turno si prenota in modo atomico con un blocco prima di aspettare, più un test (due comandi partiti insieme non colpiscono l'host nello stesso momento). Avvisati l'Orchestratore e il proprietario.

**Giudizio.**

1. **Natura.** Violazione della **nostra** regola dei 10 secondi (§22.6 n. 5) per un difetto tecnico, **non un aggiramento**: nessuna sfida superata, nessun cambio di strumento o di nome; al primo 403 ci si è fermati, come da regola.
2. **Rischio giuridico: basso.** Il 403 dopo una raffica è un limite di frequenza del sito, non un divieto di accesso; fermarsi è la condotta giusta (insistere sarebbe stato il caso del §22.3 n. 3). Conseguenze pratiche possibili: blocco dell'indirizzo, una segnalazione di abuso. Niente da notificare a un'autorità (nessun dato personale, nessun incidente di sicurezza nostro) ⚖️.
3. **I contenuti già letti** restano valutabili con la griglia del §23: i diritti non dipendono dalla velocità delle richieste. Dall'host fermato non è arrivato contenuto dopo il 403.
4. **L'host fermato resta fuori**, senza riprove e senza «prove per capire» (§22.6 n. 3–4). La riammissione non la decido io: la regola prevede solo il permesso scritto del titolare o lo scarico a mano del proprietario (per i documenti del governo federale USA vale l'art. 105 del Titolo 17 dello U.S. Code, con la riserva del §23.3 ⚖️). Nessun altro canale per lo stesso contenuto senza un mio parere scritto sul canale (come per il §21).
5. **Nessuna comunicazione al sito** (§22.6 n. 8): né lettere di scuse né richieste di sblocco; se scrive lui, si risponde con il registro.

**Altre misure (raccomandazioni della Normativa).**

1. **Un solo comando per tutte le richieste**, con il turno prenotato: funziona solo se *tutte* le richieste lo usano. Nel brief dei sotto-agenti: niente `curl` diretti e niente lettura con gli strumenti della piattaforma (`WebFetch`, browser) di più pagine dello stesso host, perché quegli strumenti non passano dal blocco.
2. **Interruttore condiviso.** Il primo 403, 429, sfida o rifiuto di un lavoratore ferma **tutti** per quell'host e per lo stesso dominio registrabile (i servizi di un governo stanno spesso dietro la stessa protezione). **Eccezione approvata il 21 novembre sera** per i suffissi «ombrello» di istituzioni diverse (oggi `europa.eu`, trattato come un suffisso pubblico, come `gov.uk`): il blocco vale per l'host e i suoi sottodomini; l'elenco dei suffissi è **chiuso** e coperto da un test; se un secondo host dello stesso suffisso dà 403, 429 o sfida nello stesso giorno, si ferma tutto il suffisso. L'elenco degli host fermati si legge **prima di ogni richiesta**, non a inizio giro.
3. **Tetto di parallelismo.** Al massimo 3 lavoratori insieme e mai due sullo stesso Paese, finché un giro intero non mostra zero coppie sotto i 10 secondi; poi il vincolo per Paese si può togliere, il tetto di 3 resta.
4. **Controllo automatico a fine giro.** Dal registro, la distanza minima per host: sotto i 10 secondi il giro è «non conforme» e l'Orchestratore riceve l'avviso (è il controllo con cui sono state contate le 53 coppie).
5. **Una frase in più in `CLAUDE.md`** nel punto sui sotto-agenti (testo nel §22.8).

## 23. Griglia delle licenze per il «Cercafonti» e regola per le leggi straniere (21 novembre)

**Richiesta dell'Orchestratore progetto** per la nuova sessione «Cercafonti» (piano approvato dal proprietario il 21 novembre, §2 e §4: ricerca notturna in tutto il mondo; il filtro automatico applica questa griglia; alla Normativa arrivano solo i casi gialli o dubbi, a gruppi). Con tutto il mondo il parere sito per sito (§19) non regge: qui c'è la regola. **Il diritto è una parte del filtro**; le altre (chi l'ha scritta, livello, data, due fonti d'accordo) restano al piano. Valgono le regole di accesso del §22.6 e di `CLAUDE.md`. Non è consulenza legale: le norme straniere sono citate dal testo noto e **non sono state rilette alla fonte oggi**; il punto ⚖️ 22 (§11) va a un legale.

### 23.1 Classi, effetti e ordine dei controlli

| Classe | Significa | Che cosa si può fare |
|---|---|---|
| **V verde** | licenza o norma che consente copia, adattamento e uso commerciale, al più con attribuzione | conservare il testo; note in parole nostre; citazioni brevi con la riga fonte; riassunto e traduzione («modificato»); inviare i pezzi ai fornitori dichiarati |
| **VR verde con riserva** ⚖️ | come V, ma la base lascia un residuo di diritto (oggi: opere del governo federale USA fuori dagli USA; documenti di pubbliche amministrazioni italiane aperti per legge; testi coordinati dei portali regionali italiani) | come V, segnato «con riserva» nel registro; nessun nome o logo dell'ente come se approvasse |
| **G giallo** | caso non coperto dalla tabella o prova incerta | **non si usa**; si manda alla Normativa (23.7); il silenzio del proprietario **non** lo rende verde |
| **R rosso** | nessun diritto di uso, o uso vietato | **mai usato**, nemmeno con il sì del proprietario; si conservano solo i dati bibliografici (titolo, ente, anno, indirizzo) e, se utile, una riga nel foglio «fonti da chiedere» (23.9); l'unica uscita è un permesso scritto del titolare, archiviato e valido per ciò che dice |
| **N non raggiungibile** | diritti verdi ma accesso bloccato o vietato ai programmi | non si usa; resta in sospeso; nessuna riprova (§22.6) |

«Verde solo link e note» (V-L) esiste solo se lo decido io per un gruppo di gialli: il Cercafonti non lo assegna da solo. Lo stesso vale per **V-F, «verde solo fatti»** (§23.12): le schede prodotto delle case madri, host per host.

**Ordine dei controlli** (si ferma al primo che respinge):

1. **Accesso.** `robots.txt` con il nostro nome e per `*`; `Content-Signal: ai-input=no` ferma; `ai-train=no` da solo non ferma (non addestriamo modelli) ma si registra ⚖️ (§11, n. 1); `robots.txt` assente (404) = nessuna restrizione; errore 5xx o file illeggibile = stop; regole per nome verso altri robot di IA: si registrano. Sfida, CAPTCHA, 403, 429 o blocco = **N**, senza riprova. Poi i termini: il divieto di accesso automatico, di uso per IA o di uso commerciale = **R**.
2. **Prova della licenza**, in quest'ordine: dato leggibile da macchina (identificatore SPDX, `rel="license"`, campo licenza di Crossref, Europe PMC o OpenAlex); riga «©» del documento; pagina delle note legali del sito. Si conserva la frase esatta (al massimo 25 parole), l'indirizzo e la data. Prove che si contraddicono = **G**.
3. **Ambito.** Una licenza **di sito** vale per il documento se copre quel tipo di contenuto («tutto il contenuto», «le pubblicazioni»), è sullo stesso dominio e il documento non porta altro «©» né altra licenza. C'è materiale di terzi (figure, tabelle, foto, loghi con «©» altrui)? Se non si può separare = **G**. Il testo conservato non include mai immagini.
4. **Classe** dalle tabelle 23.2–23.4.
5. **Registro della prova** (23.10): senza prova conservata la fonte non è verde.

### 23.2 Tabella A: licenza dichiarata → classe

| Licenza o dichiarazione trovata | Classe | Condizioni | Riga fonte |
|---|---|---|---|
| CC0 1.0; Public Domain Mark; PDDL | **V** | — | fonte e titolo (non obbligatorie, ma si scrivono) |
| CC BY 2.0, 2.5, 3.0, 4.0, anche i testi nazionali, **senza** altri elementi | **V** | solo «Attribution»; per le versioni IGO vedi sotto | autore o ente, titolo, indirizzo, «CC BY [versione]» con il collegamento, «modificato» se riassunto o tradotto; nessun segno di approvazione |
| OGL v3.0 (anche v2 e v1) del Regno Unito | **V** | esclusi materiale di terzi, dati personali, stemmi e loghi | «Contains public sector information licensed under the Open Government Licence v3.0» |
| Open Government Licence – Canada 2.0 | **V** | esclusi i materiali indicati nella licenza | «Contains information licensed under the Open Government Licence – Canada» |
| Licence Ouverte / Open Licence 2.0 (Francia) | **V** | indicare fonte e data di aggiornamento | «Source : [produttore], Licence Ouverte 2.0» |
| Datenlizenz Deutschland – Namensnennung 2.0 (dl-de/by-2-0) e Zero 2.0 (dl-de/zero-2-0) | **V** | solo queste versioni | «© [ente], dl-de/by-2-0, [collegamento]»; modifiche indicate |
| IODL 2.0 (Italia) | **V** | solo la v2.0 (la 1.0 prevedeva la condivisione allo stesso modo) ⚖️ | fonte come in §4.2 |
| Istituzioni e agenzie dell'UE: CC BY 4.0, o «riproduzione autorizzata con citazione della fonte» (decisione 2011/833/UE per la Commissione, avvisi analoghi per le altre) | **V** | la dichiarazione va trovata; dominio `*.europa.eu`; «salvo diversa indicazione»; esclusi i pareri dell'EFSA Journal (CC BY-ND) e il materiale di terzi | come §21.1 |
| Opere del governo federale USA (17 U.S.C. §105) | **VR** ⚖️ | dominio di un'agenzia **federale** (non Stati, città, università, anche se `.gov` o `.edu`); nessun «©» di terzi; nessuna immagine, stemma o logo | «Fonte: [agenzia], opera del governo federale USA (dominio pubblico negli USA); nessuna approvazione dell'agenzia» |
| Documenti di una **pubblica amministrazione italiana** (presente nell'IPA, indicepa.gov.it) pubblicati **senza licenza espressa** e senza riserva: art. 52, c. 2, CAD ⚖️ | **VR** | il documento è opera dell'ente (nessun «©» né credito di terzi); nessun dato personale; con «tutti i diritti riservati», «riproduzione vietata» o una licenza restrittiva vale la riga G o R | «Fonte: [ente], [titolo], [indirizzo], letto il [data]; documento pubblicato dall'ente senza licenza espressa (dati aperti per legge, art. 52 CAD)» |
| CC BY 3.0 IGO e 4.0 IGO (organizzazioni intergovernative) | **G** | clausole speciali | — |
| Licenza aperta nazionale non in tabella, della famiglia compatibile con CC BY (per esempio NLOD 2.0 della Norvegia, le condizioni standard del governo giapponese v2, KOGL tipo 1 della Corea, OGDL di Taiwan, GODL-India, Singapore Open Data Licence) | **G** al primo caso | la confermo e la aggiungo qui come V | — |
| Licenza sul sito ma non sul documento; documento con «©» diverso o con licenza diversa | **G** | — | — |
| Licenza aperta ma con `tdm-reservation: 1` (riserva leggibile da macchina) | **G** | conflitto tra licenza e riserva | — |
| Qualunque CC con **NC**, **ND** o **SA** (BY-NC, BY-ND, BY-NC-ND, BY-NC-SA, BY-SA, tutte le versioni); GFDL | **R** | NC: siamo commerciali; ND: riassunto e traduzione sono opere derivate; SA: l'obbligo si estenderebbe alle nostre note | — |
| Licenza «non commerciale» di governo (UK Non-Commercial Government Licence, KOGL tipo 2–4, dl-de/by-nc) | **R** | — | — |
| CC BY-NC-SA 3.0 IGO (di norma OMS, FAO e altre organizzazioni intergovernative) | **R** | — | — |
| «Tutti i diritti riservati»; «© [anno] [ente]» senza licenza; «per uso personale», «uso educativo», «per informazione», «riproduzione vietata», «chiedere il permesso» | **R** | per le pubbliche amministrazioni italiane con «tutti i diritti riservati» o «riproduzione vietata» sui documenti: **G** (conflitto con l'art. 52 CAD; decido io, di norma R salvo per leggi e regolamenti) | — |
| «Gratuito», «ad accesso libero», «open access» **senza** licenza (Bronze OA); copie di autori o di archivi senza licenza | **R** | gratis non è licenza (§2.1) | — |

### 23.3 Tabella B: leggi e atti ufficiali per Paese

La base è la norma nazionale che esclude gli atti ufficiali dal diritto d'autore, o la licenza del portale. L'elenco è **chiuso**: un Paese si aggiunge solo con la procedura di 23.8. L'uso è per i Paesi in cui l'app è offerta; dove l'opera è libera in un Paese e protetta in un altro vale il caso più restrittivo.

| Paese o ente | Base | Portali ufficiali | Classe | Note |
|---|---|---|---|---|
| Italia, Stato | art. 5 L. 633/1941 | Normattiva (versione vigente, indirizzo con `!vig=`), Gazzetta Ufficiale | **V** | riga fonte di §15.5 («non ufficiale e gratuito»); vigenza di §15; nel registro «consolidata al [data]» |
| Italia, Regioni e Province autonome | art. 5 L. 633/1941; art. 52, c. 2, CAD ⚖️ | bollettini ufficiali (BUR) e banche dati dei testi coordinati gestite dalla Regione o dal Consiglio regionale (per esempio Demetra) | **V** per i bollettini; **VR** per i testi coordinati | solo leggi e regolamenti, senza note, storia o commenti; la riserva «tutti i diritti riservati» dei portali non cambia la classe per i testi di legge, ma si registra la frase; un divieto **espresso** di accesso automatico o di riproduzione dei testi di legge = **R**; citare con i collegamenti ufficiali (URN) indicati dal portale, senza loghi né marchi; riga fonte «testo coordinato non ufficiale, aggiornato al [data]; fa fede il BUR»; ambito regionale: si cita solo a chi vive in quella Regione (§23.11) |
| Unione europea | decisione 2011/833/UE; consolidati CC BY 4.0 | EUR-Lex, tramite l'Ufficio delle pubblicazioni | **V** | §21.1: consolidato con data, «copia non ufficiale» |
| Unione europea, atti ripubblicati dal BOE (sezione «Diario Oficial de la Unión Europea») | decisione 2011/833/UE (la base è dell'UE, non del BOE) | BOE, pagine «DOUE-L», solo il «texto original» | **VR** | copia informativa: fa fede la Gazzetta ufficiale dell'UE; riga fonte, ambito e date di applicazione sempre riportati; passa a **V** quando si legge la copia di EUR-Lex (§23.11, 25 novembre) |
| Germania | §5 UrhG | gesetze-im-internet.de, Bundesgesetzblatt, portali dei Länder | **V** | fa fede la pubblicazione ufficiale; confermata il 21/11 sera: la frase di riuso non serve (la base è la norma e il portale è dello Stato); le versioni di gesetze-im-internet.de sono consolidate e non ufficiali: dirlo, con la data («Stand»); solo testo di legge e regolamento, non commenti né decisioni dei tribunali (**G**) |
| Austria | §7 UrhG | RIS | **V** | idem |
| Francia | Licence Ouverte 2.0 | Légifrance | **V** | — |
| Svizzera | art. 5, c. 1, lett. a, URG | Fedlex e raccolte cantonali | **N** | i file di Fedlex sono vietati ai programmi (§21.2) |
| Regno Unito | OGL v3.0 | legislation.gov.uk (anche Scozia, Galles, Irlanda del Nord) | **V** | i testi «revised» non sono ufficiali: dirlo |
| USA, federale | 17 U.S.C. §105 | uscode.house.gov, ecfr.gov, federalregister.gov, govinfo.gov, congress.gov | **VR** ⚖️ | solo il testo di legge, non le annotazioni degli editori; leggi degli **Stati**: **G** |
| Spagna | art. 13 LPI | BOE | **V** se si conserva la pagina dell'avviso legale; altrimenti **G** | ⚖️; confermata il 21/11 sera (pagina conservata); solo disposizioni e legislazione consolidata (la consolidata è informativa, senza valore giuridico: dirlo); esclusi loghi, marchi e la Biblioteca Jurídica Digital (CC BY-NC-ND: **R**) |
| Paesi Bassi | art. 11 Auteurswet | wetten.overheid.nl | **V** se si conserva la pagina sul riuso; altrimenti **G** | ⚖️ |
| Australia, Commonwealth | CC BY 4.0 del Federal Register of Legislation | legislation.gov.au | **V** se si conserva la dichiarazione; Stati e territori: **G** | ⚖️ |
| Nuova Zelanda | s. 27 Copyright Act 1994 | legislation.govt.nz | **V** se si conserva la pagina; altrimenti **G** | ⚖️ |
| Canada, federale | Reproduction of Federal Law Order (SI/97-5) | laws-lois.justice.gc.ca | **G** al primo caso | condizioni dell'ordine: accuratezza, nessuna approvazione, non presentare come versione ufficiale; province: **G**; le **pagine** di canada.ca sono di norma «non commerciali»: **R** salvo OGL-Canada |
| Belgio, Irlanda e tutti gli altri Paesi | — | — | **G** per Paese al primo caso (23.8) | poi li aggiungo qui |

### 23.4 Tabella C: per tipo di titolare, quando manca la licenza dichiarata

| Titolare | Che cosa aspettarsi | Senza licenza dichiarata |
|---|---|---|
| Parlamento, governo, gazzetta ufficiale (leggi e regolamenti) | tabella B | **G** se il Paese non è in tabella B |
| Ministeri, agenzie veterinarie e sanitarie pubbliche, enti pubblici di ricerca | spesso licenza aperta (Regno Unito, Australia, Nuova Zelanda, Francia, UE, Italia per il Ministero della Salute); altrove «tutti i diritti riservati» o «riproduzione non commerciale» | **R**: il pubblico non è libero per presunzione; **eccezione Italia**: riga CAD della Tabella A (**VR**); altri Paesi dell'UE: **G** al primo caso (la direttiva (UE) 2019/1024 sul riutilizzo dell'informazione del settore pubblico dà un diritto di riutilizzo, ma le condizioni sono nazionali) |
| Università pubbliche, servizi di divulgazione, facoltà di veterinaria | di norma «©» dell'ateneo; a volte CC BY-NC-ND | **R** |
| Organizzazioni intergovernative (OMS, FAO, WOAH e simili) | di norma NC-SA o «chiedere il permesso» | **R**; foglio «fonti da chiedere» se utili |
| Società scientifiche, editori, associazioni professionali, enti di beneficenza, aziende | «tutti i diritti riservati»; articoli ad accesso aperto con CC BY solo se dichiarato sul singolo articolo | **R** |
| Articoli scientifici | licenza **del singolo articolo** (Crossref; Europe PMC con filtro cc by e cc0; il sottoinsieme «uso commerciale» di PMC comprende anche licenze SA e ND: per noi no); **mai** abstract di articoli non aperti (§12) | **R**, con soli metadati |
| Siti non ufficiali: blog, forum, social, negozi, allevatori, Wikipedia, testi fatti con l'IA | — | **R** (fuori dal piano) |

### 23.5 Pagine senza licenza

- Una pagina o un documento senza licenza e senza norma sugli atti ufficiali è **R**: i diritti sono riservati per legge. «Si può scaricare», «open access» e «gratuito» non sono licenze.
- **Unica eccezione** (§17): un documento che è opera dell'ente stesso, senza «©» di terzi, su un sito che dichiara una licenza generale per tutto il contenuto (per esempio l'OGL su gov.uk): **V**, registrando la pagina del sito e la data.
- Di una fonte **R** si conservano solo i dati bibliografici; non si legge il testo oltre ciò che serve a classificarla (pagina dei termini e `robots.txt`). Se è utile e non esiste un'alternativa aperta: una riga nel foglio «fonti da chiedere» (23.9). I fatti **non** si ricopiano «in parole nostre» da una fonte R: il metodo del [13](13_parere_fonti_scientifiche_e_diritto_d_autore.md) non vale per il Cercafonti. **Unica eccezione:** V-F, le schede prodotto delle case madri (§23.12, 25 novembre 2026).

### 23.6 Leggi straniere: come citarle e usarle

1. **Solo testi ufficiali**, nella lingua originale, dal portale di 23.3. Niente commenti, annotazioni o sommari di editori; niente traduzioni di terzi (§21.2).
2. **Versione e vigenza.** Si registra «consolidata al [data]» o «testo originale» e la catena delle modifiche; si controlla che l'atto non sia abrogato (§15.2: un riferimento citato da altri può essere morto); gli atti con scadenza (come le ordinanze annuali) si controllano alla scadenza. Ricontrollo ogni 3 mesi (piano).
3. **Una legge si usa per chi vive in quel Paese**, o per chi chiede di viaggiare, importare o trasferirsi lì. Mai la legge di un Paese applicata a un utente di un altro; se il Paese dell'utente è sconosciuto, si chiede oppure si risponde in generale.
4. **Livello.** Nazionale, regionale, comunale: si registra il livello; una regola locale non diventa nazionale.
5. **Citazione nella risposta.** Paese, atto (tipo, numero, data), articolo, indirizzo ufficiale, «testo consolidato non ufficiale, controllato il [data]»; con la riga «Non è consulenza legale: per il tuo caso chiedi all'autorità competente».
6. **Traduzione.** Si può (gli atti ufficiali sono liberi), ma si scrive «traduzione nostra, non ufficiale»; dove esiste una versione ufficiale nella lingua dell'utente si usa quella (UE, Svizzera).
7. **Sanzioni e importi** solo dal testo, mai arrotondati o aggiornati a memoria; se la norma rinvia a un allegato o a un decreto, si cita anche quello.
8. **Sentenze e decisioni di autorità**: **G** (dati personali, regole diverse per Paese).
9. Una legge di un Paese **non** in tabella B è **G**: non si cita.

### 23.7 Casi gialli: che cosa mandarmi, a gruppi

Un messaggio (o un file in `.local/cercafonti/gialli/` con il percorso nel messaggio) **per gruppo**, cioè per **stesso motivo** (per esempio «licenza aperta nazionale non in tabella: [Paese]»), al massimo uno al giorno. Contenuto:

1. **Motivo** (riga della tabella che l'ha reso giallo) e **domanda** in una frase («la licenza X copre i testi del sito Y?»).
2. **Per ogni fonte** (al massimo 10 per gruppo; se sono di più, 10 a campione e il numero totale): indirizzo del documento; indirizzo della pagina con la licenza o il «©» e la **frase esatta** (al massimo 25 parole); titolare e Paese; tipo (legge, guida per proprietari, guida per professionisti, linea guida, revisione); data di lettura; esito di `robots.txt` (nostro nome e `*`) e segnali (`Content-Signal`, `tdm-reservation`); pagina dei termini e frase rilevante (al massimo 25 parole); materiale di terzi (sì, no, non so); uso previsto (testo conservato, note, citazioni), specie e tema; esiste un'alternativa aperta (sì o no).
3. **Proposta** del Cercafonti (V, VR, R o V-L) e perché.
4. **Mai il testo della fonte**, oltre alle frasi di licenza e di termini.

Io rispondo con la decisione per il gruppo, la riga da aggiungere alle tabelle e le condizioni. Il Cercafonti applica la stessa regola ai casi simili senza chiedere di nuovo. **Fino alla risposta la fonte non si usa.** L'attesa non blocca le altre fonti.

### 23.8 Paesi e fornitori nuovi: che cosa segnalare

- **Paese nuovo** (come fonte): Paese; lingue ufficiali; portale ufficiale delle leggi e dei ministeri (indirizzo); norma nazionale sul diritto d'autore per gli atti ufficiali (articolo e indirizzo del testo ufficiale); licenza o termini di riuso del portale (indirizzo e frase, al massimo 25 parole); esito di `robots.txt`; traduzioni ufficiali; se l'app è o sarà offerta lì (lo decide l'Orchestratore). Lo aggiungo alla tabella B; se l'app è offerta nel Paese preparo anche i documenti del Paese (termini, informativa).
- **Fornitore nuovo** (strumenti del Cercafonti, anche per ricerca, lettura, hosting, foglio Google, pagina di controllo): nome; Paese del fornitore e dei server; servizio; **che cosa riceve** (solo specie e tema? indirizzo IP del computer? mai dati personali né testi di utenti); conservazione e uso per l'addestramento (indirizzo dei termini o del DPA); account usato (di chi); costo. Lo segnalo alla Sicurezza per `docs/security/06` **prima dell'uso** (§18.7: ricerca solo con specie e tema, mai `user_location`).

### 23.9 Foglio «Quokka – fonti da chiedere»: che cosa scrivere

Una riga per fonte rossa utile: titolare; sito; che cosa copre; caselle; perché è utile; esiste un'alternativa aperta (sì o no, quale); priorità; **la prova**: indirizzo della pagina e frase (al massimo 25 parole) che mostra il «tutti i diritti riservati» o il divieto. Niente testo della fonte, niente dati personali, niente indirizzi di persone: solo l'indirizzo generale di contatto pubblicato dal titolare. Nessuna e-mail parte da noi: decide il proprietario, con il kit di lettere ([20a](20a_lettere_permesso_ai_titolari.md)).

### 23.10 Silenzio e «No» del proprietario, registro della prova, ricontrollo, campione

- **Il silenzio vale sì solo per V e VR**: è una scelta di prodotto, non una verifica di diritto. I G e gli R non compaiono con i pulsanti OK e No: i G vengono a me, gli R vanno al foglio. Un «OK» del proprietario su un giallo o un rosso non vale.
- **«No»** = lista «non approvata»: scelta di qualità, nessun effetto di diritto; testo e note escono dall'uso. Diversa è **«ritirata per diritti»** (licenza cambiata o ritirata, richiesta del titolare, errore del filtro): testo, note e citazioni escono **entro 3 giorni** (§7, §22.9) e la fonte diventa R.
- **Registro della prova**, per ogni fonte: indirizzo del documento e della prova; frase della prova (al massimo 25 parole); data; titolare; Paese; licenza (identificatore); regola applicata (riga della tabella); classe; esito di `robots.txt` e segnali; materiale di terzi; riga fonte; data del prossimo controllo (leggi 3 mesi, guide 6). **Senza prova conservata la fonte non è verde.**
- **Ricontrollo** (piano §5): a ogni giro si rileggono anche licenza, `robots.txt` e termini; se sono diventati restrittivi o la prova non c'è più: **ritirata per diritti**.
- **Campione di controllo.** Nelle prime due settimane il Cercafonti mi manda 10 fonti **verdi** a caso a notte (prova e classe), poi 5 a settimana. Se trovo un errore: si ferma la regola interessata, le fonti che l'hanno usata si ritirano entro 3 giorni e correggo la tabella.

### 23.11 Decisioni sui gialli e correzioni del campione (registro)

**21 novembre, gruppo «portali regionali italiani» (prima notte).** Domanda: un portale come Demetra (testo coordinato delle leggi della Regione Emilia-Romagna) vale come «gazzetta delle Regioni»? **Decisione: VR, non V**, solo per **leggi e regolamenti** (testo coordinato). Il testo di una legge regionale è un atto ufficiale (art. 5 L. 633/1941) e il testo coordinato ne riporta le modifiche senza creazione; il portale però dichiara «tutti i diritti riservati» su marchi, loghi e «documenti» (note legali): la frase non cambia la classe per i testi di legge, ma è un conflitto di prova, per questo «con riserva» ⚖️ (§11, n. 23). Condizioni: solo l'articolo di legge (niente note, storia, commenti); si cita con il collegamento ufficiale (URN) che il portale indica, senza loghi né marchi; riga fonte «Fonte: [portale], [ente] (testo coordinato non ufficiale, aggiornato al [data]; fa fede il BUR)»; ambito regionale (si cita solo a chi vive in quella Regione). Gli altri documenti dello stesso portale (resoconti, atti istruttori): **R**. Per le altre Regioni la regola vale (Tabella B) se il portale è gestito dalla Regione o dal Consiglio regionale e le note legali non vietano **espressamente** l'accesso automatico o la riproduzione dei testi di legge.

**21 novembre, campione della notte pilota (8 fonti verificate sulle pagine).** Quattro pagine di gov.uk: **V confermata** (la frase dell'OGL sta nel piè di pagina; i crediti a terzi si controllano nel testo). Due pagine di un'agenzia federale USA: **VR confermata**, con la prova completata dalla frase positiva del Dipartimento dell'Interno («Generally, materials produced by federal agencies are in the public domain and may be reproduced without permission… not all materials appearing on this web site are in the public domain») e da quella dell'agenzia («We will identify material we use from sources outside the Service»): testo scritto dall'agenzia, senza crediti di terzi, immagini e logo esclusi. Due leggi di Normattiva: **classe V confermata, ma la frase di prova non è sulla pagina citata** (la pagina dice che i testi non hanno carattere di ufficialità e che la riproduzione è consentita purché si menzionino la fonte e il carattere non autentico e gratuito). È un errore di registrazione, **non di classe**: nessun ritiro. Regole nuove: (1) la frase di prova si **copia** dalla pagina e un controllo automatico verifica che compaia nel testo della pagina; la base di legge (art. 5) è un campo a parte; (2) per le leggi si registra la versione («consolidata al [data]» o «testo originale») e si usa il testo **vigente** (Normattiva: indirizzo con `!vig=`), non l'originale; (3) nel campo della regola si scrive il nome della riga della tabella, non il numero di riga del documento.

**21 novembre, pubbliche amministrazioni italiane senza licenza espressa.** Nuova riga nella Tabella A (art. 52, c. 2, CAD ⚖️): i dati e i documenti pubblicati da una pubblica amministrazione italiana senza l'espressa adozione di una licenza si intendono rilasciati come dati aperti (salvo i dati personali): **VR**, se il documento è opera dell'ente, l'ente è una pubblica amministrazione (IPA), non c'è riserva esplicita né credito di terzi. Con «tutti i diritti riservati» o una licenza restrittiva: **G** o **R**. Prima di classificare **R** una pagina senza licenza dichiarata, si controlla la pagina delle note legali del sito e se ne registra l'indirizzo.

**21 novembre sera, giro grande (223 fonti V/VR in uso, 10 N, 2 G).** *Campione di 10 fonti* (5 pagine di gov.uk, 3 di Normattiva, 1 di nidirect, 1 di gov.wales; controllo sulle prove registrate: frase, pagina, regola, tipo): **V confermata per tutte**, con tre correzioni. (1) **Frasi di prova tagliate a metà frase** (nidirect e gov.wales; quella del Galles include «Our logo The use of our logo is»): si copia una frase intera che mostri l'ambito (al massimo 25 parole). (2) **Tipo sbagliato**: una pagina di notizie del governo gallese è segnata «legge»; un «tipo: legge» la farebbe citare come atto giuridico. Solo il testo di un atto ufficiale è «legge»: da controllare i tipi di tutte le pagine dei portali di governo. (3) **Attribuzione vuota per 7 host** (nidirect, gov.wales, DAERA e legislation.gov.uk con OGL; ECDC, agriculture.gov.au e oesterreich.gv.at con CC BY): l'attribuzione è una **condizione della licenza** (OGL v3.0; CC BY 4.0 §3(a)), non un'opzione, e prima dell'uso va compilata: OGL, la frase indicata dall'ente nella sua pagina e, se manca, «Contains public sector information licensed under the Open Government Licence v3.0.»; CC BY, ente, titolo, licenza con indirizzo e l'indicazione «riassunto da Quokka»; per legislation.gov.uk anche «versione aggiornata (revised), non ufficiale» quando serve. *Tabella B:* **Spagna (BOE): V**, la condizione (pagina dell'avviso legale conservata) è soddisfatta; solo disposizioni e legislazione consolidata, con la riga fonte «texto consolidado, carácter informativo» per la consolidata («texto oficial» solo per il testo pubblicato nella Gazzetta) e la data di aggiornamento; esclusi loghi, marchi, **Biblioteca Jurídica Digital** (CC BY-NC-ND: R) e ogni pagina che non sia un testo di legge. **Germania (gesetze-im-internet.de): V**, la prova basta: la base è il §5 UrhG e il portale è dello Stato (lo prova l'Impressum); riga fonte con il Ministero federale della Giustizia e la data («konsolidierte, nicht amtliche Fassung, Stand: [data]; maßgeblich ist das Bundesgesetzblatt»); solo testo di legge e regolamento federale, non commenti né sentenze; le leggi dei Länder dai portali dei Länder. *Enti nuovi:* **V** per nidirect, gov.wales, DAERA, legislation.gov.uk (OGL), ECDC, agriculture.gov.au e oesterreich.gv.at (CC BY 4.0), solo testo scritto dall'ente; **VR** per gli enti federali USA (usgs.gov con la sua frase positiva; per un secondo ente la frase «most information… is considered public domain» è più debole: solo testo scritto dall'agenzia, senza immagini né crediti di terzi). *Gialli (2):* il file arriva domani; fino ad allora **non si usano**. Indicazione provvisoria: un sito senza pagina dei termini né licenza è **R**; per un sito regionale italiano vale l'art. 52, c. 2, CAD (**VR**) se il sito non porta alcuna riserva esplicita, e la licenza CC BY di un portale con **dominio diverso non vale come prova primaria** (§23.1, n. 3). *Difetto corretto dal Cercafonti* (istante di partenza nel registro, turno con blocco condiviso, «www.x» uguale a «x», un 403 ferma il dominio registrabile; §22.10): **conforme** (distanza minima 10,0 s dopo le 19:41).

**21 novembre sera, prova di un altro strumento per la sola lettura (Gemini, interfaccia web).** Richiesta del Cercafonti per risparmiare token: classificare per pertinenza (specie, tema) 20 testi **già scaricati** con le nostre regole. **Sì alla prova, come strumento di lavoro e non come fornitore del prodotto**, a queste condizioni. (1) **Account**: meglio quello del progetto, in un profilo Chrome separato, non l'account personale del proprietario (rischio: limitazione dell'account; i termini generali di Google vietano di accedere ai servizi con metodi diversi dall'interfaccia e dalle istruzioni fornite: un agente che usa l'interfaccia è un caso grigio ⚖️, termini non riletti il 21/11); se il proprietario sceglie il suo, decide lui con il rischio esposto. (2) **Pacchetto**: solo testi **V o VR** già in uso; mai R, G o N; **niente testi con `ai-train=no` o `tdm-reservation`** (un account consumer può addestrarsi sulle conversazioni); prima dell'invio si tolgono e-mail e telefoni con lo stesso anonimizzatore dei fornitori; nessun dato di utenti, nessuna chiave, nessun nome di persona nelle istruzioni. (3) **Nessun accesso a siti**: lo strumento non apre pagine né cerca (le nostre regole di accesso valgono per ogni programma: nome «Quokka»); estensioni e ricerca spente; se Google mostra una verifica o un CAPTCHA, ci si ferma. (4) **Cronologia**: attività dell'app spenta o chat temporanea; a fine prova si cancellano le conversazioni; registro interno con data, strumento e **numero e identificativi** dei testi (non il contenuto). (5) **Lo strumento non decide mai i diritti**: le classi V, VR, G, R e N restano della griglia; può proporre solo pertinenza, specie e tema, e gli esiti si controllano a campione sul testo. (6) **Inventario dei fornitori** (`docs/security/06`): nessuna riga per la prova (nessun dato personale degli utenti); se si estende, serve un servizio con contratto commerciale (senza addestramento sui dati) e la riga solo se tocca dati personali.

**22 novembre, esito della prova (20 testi V/VR).** Condizioni rispettate: pacchetto V/VR in uso, nessun testo con `ai-train=no` o `tdm-reservation`, anonimizzatore, nessun accesso a siti, diritti non toccati dallo strumento. **Scelta del proprietario**: account personale invece di quello del progetto, con il rischio esposto (era ammesso); l'invio l'ha premuto lui; conversazione normale, da cancellare (registro interno). **Pertinenza**: la seconda lettura ha giudicato poco adatte 5 fonti su 20 che i nostri agenti avevano tenuto (quattro o cinque discutibili davvero) e non ha introdotto errori evidenti: è utile come seconda lettura. **Estensione: no a guidare l'interfaccia web di Gemini con un agente**: il `robots.txt` del servizio dichiara che l'area dell'app non è per i programmi, i termini di Google ammettono l'accesso dall'interfaccia fornita, il rischio è per l'account e non c'è una traccia affidabile. **Vie ammesse per una seconda lettura**: (1) un secondo passaggio con un altro modello dello stesso fornitore già in uso (nessun nuovo fornitore); (2) l'API a pagamento di Google, con termini commerciali e senza addestramento, con le regole del pacchetto e la chiave solo in variabile d'ambiente, mai nel repository; (3) a mano, per lotti piccoli. La pertinenza non tocca i diritti: le classi restano della griglia.

**25 novembre, gruppo «enti pubblici senza pagina dei termini» e «atti UE ripubblicati dal BOE»** (file del Cercafonti del 22 novembre; quattro punti).
1. **Regola generale: un sito pubblico senza termini, licenza né «©» resta R** (§23.5): non c'è un diritto di uso per presunzione, e un 404 sulla pagina delle note legali non è una licenza. Il Cercafonti registra l'indirizzo e la data del 404 («non c'è»). Eccezione: l'ente è una pubblica amministrazione italiana senza riserva (riga CAD della Tabella A: VR). Un'altra prova (licenza nel documento, «©» con licenza, dichiarazione dell'ente) cambia la classe caso per caso.
2. **Segretariato britannico per le specie non native** (guida per proprietari): **R**. Foglio «fonti da chiedere», priorità bassa; l'alternativa aperta (gov.uk) è già in uso.
3. **Regione Emilia-Romagna, sito tematico «Ambiente»** (guida per proprietari sulla detenzione di animali esotici invasivi): **VR**, riga CAD (art. 52, c. 2 ⚖️). La Regione è nell'IPA, il documento è opera dell'ente, nessun «©» né riserva trovati, e le note legali del sito rispondono 404 (registrato). La licenza CC BY 4.0 dichiarata dal portale regionale **non** vale come prova (dominio diverso; altri siti tematici della Regione hanno licenze NC e ND): la decisione è **per sito tematico** e non si estende agli altri domini della Regione. Condizioni: a ogni lettura né la pagina né il piè di pagina portano una licenza o un «©» (una licenza restrittiva, NC o ND, o «tutti i diritti riservati» = **G**); crediti e foto di terzi non entrano (il testo conservato non include immagini); riga fonte della Tabella A; la guida vale per chi vive in Emilia-Romagna quando parla di regole regionali.
4. **Atti dell'UE ripubblicati dal BOE** (sezione «Diario Oficial de la Unión Europea», «texto original»): **VR, non V**. La base del riuso è la decisione 2011/833/UE (dell'UE, non del BOE) e il testo è l'originale, con gli estremi della Gazzetta ufficiale dell'UE (verificato sulla pagina salvata del regolamento 2026/1818); la riserva è che la copia non è quella di EUR-Lex. Condizioni: solo il «texto original» (non sintesi o note del BOE), nessun logo del BOE; riga fonte «Fonte: BOE, texto original del DOUE n. [numero] del [data] (copia informativa); fa fede la Gazzetta ufficiale dell'UE»; ambito e date di applicazione sempre riportati (un regolamento può applicarsi in date diverse per articolo). Passa a V quando il Cercafonti legge la copia di EUR-Lex dal canale dell'Ufficio delle pubblicazioni (§21.1). Vale per i due regolamenti del gruppo (viaggi con animali da compagnia; benessere e tracciabilità di cani e gatti) e per i simili. Riga nuova nella Tabella B.

### 23.12 Schede prodotto delle case madri: V-F, «verde solo fatti» (25 novembre 2026)

**Domanda del Cercafonti, riferita dall'Orchestratore** (decisione del proprietario del 25 novembre sui prodotti non farmacologici: la casa madre è una fonte certa per dire che cosa è un prodotto): si possono leggere da programma le pagine prodotto di una casa madre che non dà alcuna licenza («All Rights Reserved») ma non vieta la lettura in `robots.txt` né nei termini, e usarne solo i fatti, con parole nostre, citazione e link? **Risposta: sì, solo a certe condizioni.** Nessuna richiesta ai siti per scrivere questo parere. Le norme sono citate a ricordo e **non sono state rilette oggi** ⚖️.

**Perché è possibile.** Il diritto d'autore protegge l'espressione, non il dato (artt. 1–2 L. 633/1941): nome, produttore, composizione dichiarata, specie, forma, avvertenze, quantità e frequenza d'uso dell'etichetta sono fatti, e per i mangimi sono informazioni che l'etichetta deve riportare per legge (reg. (CE) 767/2009, a ricordo). Non prendiamo ciò che è protetto: testi di vendita, slogan, foto, loghi, impaginazione. «All Rights Reserved» è una riserva generica sulle opere: non è la riserva dell'estrazione di testi e dati che la legge richiede **espressa e appropriata** (art. 70-quater L. 633/1941; direttiva (UE) 2019/790, art. 4(3) e considerando 18: per i contenuti online, di norma un segnale leggibile da macchina o una clausola dei termini). La copia temporanea della pagina serve solo a estrarre il fatto. Il rischio vero è la correttezza: una quantità o un'avvertenza sbagliata o superata fa male all'animale; di qui le condizioni.

**Classe.** Per i siti in generale non cambia nulla: **R**. Nasce **V-F** (come V-L: la assegno io, **host per host**, mai il Cercafonti da solo), solo per le pagine di una casa madre che descrivono **il suo** prodotto: scheda prodotto, scheda tecnica, etichetta, scheda di sicurezza. Il resto dello stesso sito (blog, consigli, negozio di altri marchi, recensioni) resta R. Il rivenditore ufficiale vale solo per nome, formato e confezione (regola del proprietario).

**Condizioni (tutte):**
1. **Elenco chiuso di campi:** nome, produttore, composizione dichiarata, specie, forma, confezioni, avvertenze, quantità e frequenza «secondo l'etichetta» (solo per i prodotti non farmacologici), data e versione della scheda. Mai prezzo, disponibilità, foto, loghi, slogan.
2. **Pagine una per una**, solo di prodotti che servono a una voce della lista o a una domanda: non si scorre il catalogo, non si seguono i collegamenti per elencarlo (diritto sulle banche dati, art. 102-bis ss. L. 633/1941); al massimo 5 pagine per host a notte; 10 secondi tra le richieste.
3. **Prima i termini, da soli** (§22.6): un divieto di lettura automatica, di uso per IA o commerciale, o di riproduzione dei contenuti lascia l'host in R; `Content-Signal: ai-input=no` ferma; pagina dei termini non trovata = nessuna lettura. In Germania la riserva sull'estrazione di testi e dati può stare anche nelle condizioni d'uso in linguaggio naturale (§ 44b UrhG, a ricordo): si leggono le condizioni d'uso del sito, non solo quelle di vendita.
4. **Parole nostre.** Frase di prova interna fino a 25 parole, solo nel registro: **mai data al modello della chat**, mai mostrata.
5. **Come appare:** «Secondo l'etichetta di *produttore* (scheda del *data*): …», con il link, «riassunto da Quokka» e l'invito a guardare la confezione che si ha in mano. Mai «consigliato da Quokka», mai collegamenti di vendita o di affiliazione, nessun invito a comprare; il marchio solo per dire che cosa è (uso descrittivo, art. 21 c.p.i., a ricordo). **Riga fonte:** «Fonte: *produttore*, *nome del prodotto*, scheda del *data* (versione *x*, se c'è), *indirizzo della pagina*; fatti riassunti da Quokka». Se la pagina non porta una data scrive «pagina letta il *data*»; se la scheda è di un altro mercato (per esempio un'etichetta per gli Stati Uniti) la riga lo dice, perché la confezione venduta in Italia può avere un'altra formula; l'indirizzo è quello della casa madre, mai di un negozio o di un collegamento di affiliazione; la composizione e le cifre sono «dichiarate dal produttore».
6. **Fuori i prodotti che sono medicinali per come si presentano:** se la pagina li dà come cura o prevenzione di una malattia, o «da usare sotto controllo veterinario» (convalescenza, diete), il prodotto esce: nessuna quantità e frequenza. Le promesse di efficacia delle altre pagine restano solo «dichiarazione del produttore».
7. **Quantità mai calcolate** e niente tabelle per peso: se l'etichetta dà la dose in base al peso, si dice «dipende dal peso: guarda la tabella sull'etichetta», senza numeri.
8. **Ricontrollo ogni 90 giorni** o quando cambia l'impronta della pagina; pagina sparita o cambiata = il fatto non si usa finché non è riletto.
9. **Rimozione su richiesta** (§22.9): se la casa madre lo chiede, entro 24 ore si tolgono i fatti indicati e l'host torna R (§23.10, «ritirata per diritti»). Nessun contatto con i siti: lettere e richieste di permesso le invia il proprietario.

**Registro per host:** data, esito di `robots.txt` (nome Quokka e `*`, `ai-train`, `ai-input`, `Content-Signal`), frase dei termini (al massimo 25 parole), pagine ammesse e campi. Le decisioni sui singoli siti stanno nel registro interno, non qui.

**⚖️ Una sola domanda al legale per tutta la categoria:** la riserva generica «All Rights Reserved», senza clausole su estrazione di testi e dati, impedisce l'uso descritto (art. 70-quater)? La mia lettura è no; non blocca finché le condizioni sono rispettate.

## Fonti consultate il 17 novembre 2026

- Art. 5 L. 633/1941 (atti ufficiali) e art. 20 (diritti morali): [Brocardi art. 5](https://brocardi.it/legge-diritto-autore/titolo-i/capo-i/art5.html).
- [Normattiva, avviso legale](https://www.normattiva.it/staticPage/legal) e [robots.txt](https://www.normattiva.it/robots.txt); [Gazzetta Ufficiale, home](https://www.gazzettaufficiale.it/).
- [EUR-Lex, avviso legale](https://eur-lex.europa.eu/content/legal-notice/legal-notice.html) e [robots.txt](https://eur-lex.europa.eu/robots.txt).
- [salute.gov.it, note legali](https://www.salute.gov.it/new/it/altro/note-legali-2/); sezioni [COVID-19](https://www.salute.gov.it/new/it/tema/covid-19/legal-notice/) ed [Esenzioni dal ticket](https://www.salute.gov.it/new/it/tema/esenzioni-dal-ticket/note-legali/).
- [ISS, contatti e copyright](https://www.iss.it/contatti); [EpiCentro, disclaimer](https://www.epicentro.iss.it/chi-siamo/disclaimer); [BEN, copyright](https://www.epicentro.iss.it/ben/privacy).
- [IZSVe, note legali](https://www.izsvenezie.it/note-legali/).
- [Europe PMC, robots.txt](https://europepmc.org/robots.txt), [avviso di copyright](https://europepmc.org/Copyright), [sottoinsieme aperto](https://europepmc.org/downloads/openaccess), [API REST](https://europepmc.org/RestfulWebService); [EBI, robots.txt](https://www.ebi.ac.uk/robots.txt).
- [NCBI PMC, sottoinsieme aperto](https://pmc.ncbi.nlm.nih.gov/tools/openftlist/) e [dataset per text mining](https://pmc.ncbi.nlm.nih.gov/tools/textmining/).
- [Testo di CC BY 4.0](https://creativecommons.org/licenses/by/4.0/legalcode.en) (§2(a)(5)(C), §2(b)(1), §3(a), §6(b)).
- [NLM, note web e copyright](https://www.nlm.nih.gov/web_policies.html#copyright); [Crossref, Open Abstracts](https://www.crossref.org/blog/open-abstracts-where-are-we/).
- [MSD Veterinary Manual, Permissions](https://www.msdvetmanual.com/resourcespages/permissions); [RECOVER, sito](https://recoverinitiative.org/); [AAHA, termini d'uso](https://www.aaha.org/about-aaha/terms-of-use/).
- Atti del §15: [GU, O.M. 16 luglio 2026](https://www.gazzettaufficiale.it/atto/vediMenuHTML?atto.dataPubblicazioneGazzetta=2026-09-05&atto.codiceRedazionale=26A04624&tipoSerie=serie_generale&tipoVigenza=originario); [GU, O.M. 10 luglio 2025](https://www.gazzettaufficiale.it/atto/vediMenuHTML?atto.dataPubblicazioneGazzetta=2025-08-20&atto.codiceRedazionale=25A04616&tipoSerie=serie_generale&tipoVigenza=originario); [GU, O.M. 3 agosto 2015](https://www.gazzettaufficiale.it/atto/serie_generale/caricaDettaglioAtto/originario?atto.dataPubblicazioneGazzetta=2015-09-09&atto.codiceRedazionale=15A06718&elenco30giorni=false); [GU, O.M. 28 agosto 2014](https://www.gazzettaufficiale.it/atto/serie_generale/caricaDettaglioAtto/originario?atto.dataPubblicazioneGazzetta=2014-09-08&atto.codiceRedazionale=14A06915&elenco30giorni=false); [GU, O.M. 6 agosto 2013](https://www.gazzettaufficiale.it/eli/gu/2013/09/06/209/sg/pdf); [Ministero della Salute, Tutela dall'aggressione dei cani](https://www.salute.gov.it/new/it/tema/animali-daffezione/tutela-dallaggressione-dei-cani/).
- [Normattiva, DPR 320/1954 (vigente)](https://www.normattiva.it/uri-res/N2Ls?urn:nir:presidente.repubblica:decreto:1954-02-08;320!vig=) e [D.Lgs. 136/2022](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2022-08-05;136!vig=) (art. 32); [Codice civile, art. 2052 (GU)](https://www.gazzettaufficiale.it/atto/serie_generale/caricaArticolo?art.progressivo=0&art.idArticolo=2052&art.versione=1&art.codiceRedazionale=042U0262&art.dataPubblicazioneGazzetta=1942-04-04&art.idGruppo=258&art.idSottoArticolo1=10&art.idSottoArticolo=1&art.flagTipoArticolo=2); [Lexbrowser, L.P. 9/2000](https://lexbrowser.provinz.bz.it/doc/it/lp-2000-9/legge_provinciale_15_maggio_2000_n_9.aspx) e [D.P.P. 19/2013](https://lexbrowser.provinz.bz.it/doc/it/197176/decreto_del_presidente_della_provincia_8_luglio_2013_n_19.aspx).
- Siti del §19 (20 novembre): [Agriculture Victoria, copyright](https://agriculture.vic.gov.au/copyright); [MSD Veterinary Manual, disclaimer](https://www.msdvetmanual.com/resourcespages/disclaimer); [Commissione europea, avviso legale](https://commission.europa.eu/legal-notice_en); robots.txt di [Agriculture Victoria](https://agriculture.vic.gov.au/robots.txt).
- Strumenti web e siti del §18 (20 novembre): [Anthropic, Web fetch tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool); [Anthropic, Web search tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool); [Anthropic, crawler e robots](https://support.claude.com/en/articles/8896518-what-is-claudebot); [MSD Veterinary Manual, Partnerships](https://www.msdvetmanual.com/content/partnerships), [Permissions](https://www.msdvetmanual.com/resourcespages/permissions), [termini](https://www.msdvetmanual.com/content/termsofuse); robots.txt di [MSD](https://www.msdvetmanual.com/robots.txt), [RSPCA](https://www.rspca.org.uk/robots.txt), [Blue Cross](https://www.bluecross.org.uk/robots.txt), [Dogs Trust](https://www.dogstrust.org.uk/robots.txt). Giurisprudenza e Amburgo 2024: da una ricerca e dal [13](13_parere_fonti_scientifiche_e_diritto_d_autore.md), da verificare.
- Siti del §17: [gov.scot, Crown Copyright](https://www.gov.scot/crown-copyright/); [GOV.UK, Terms and conditions](https://www.gov.uk/help/terms-conditions); [gov.wales](https://www.gov.wales/copyright-statement); robots.txt di [gov.scot](https://www.gov.scot/robots.txt) e [gov.uk](https://www.gov.uk/robots.txt).
- Licenze del §16.4 (20 novembre): [gov.wales](https://www.gov.wales/copyright-statement); [nidirect](https://www.nidirect.gov.uk/articles/crown-copyright); [DAFF](https://www.agriculture.gov.au/about/copyright); [MPI](https://www.mpi.govt.nz/about-this-site/mpi-copyright); [ECDC](https://www.ecdc.europa.eu/en/ecdc-intellectual-property-notices); [EFSA](https://www.efsa.europa.eu/en/legalnotice); [FDA](https://www.fda.gov/about-fda/about-website/website-policies); [CDC](https://www.cdc.gov/other/agencymaterials.html); [USDA](https://www.usda.gov/about-usda/policies-and-links); robots.txt di [cdc.gov](https://www.cdc.gov/robots.txt), [fda.gov](https://www.fda.gov/robots.txt) e [Lexbrowser](https://lexbrowser.provinz.bz.it/robots.txt); licenze degli articoli EFSA Journal dall'API di Europe PMC.
- Urgenze (§20, 20 novembre notte): [Play Console Help, Health Content and Services](https://support.google.com/googleplay/android-developer/answer/16679511) e [Health apps declaration](https://support.google.com/googleplay/android-developer/answer/14738291); [Apple, App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (la frase sul medico non trovata nel testo attuale); direttiva (UE) 2024/2853, allegato III dell'AI Act, L. 132/2025 e stato del recepimento italiano: da ricerche e dal testo noto, non riletti alla fonte; articoli dei codici civile, penale e del consumo: dal testo noto, non riletti oggi su Normattiva. Testi dell'app letti nel codice: `chat_ai_notice.dart` (11 px) e `app_it.arb` (`chatAiNotice`, `noticeChatAi`, `billingPaywallEmergency*`).
- Elenco bianco, accessi (§21, 20 novembre notte): [EUR-Lex, Reuse EUR-Lex content](https://eur-lex.europa.eu/content/help/data-reuse/reuse-contents-eurlex-details.html) (letta a mano); robots.txt di [publications.europa.eu](https://publications.europa.eu/robots.txt), [www.fedlex.admin.ch](https://www.fedlex.admin.ch/robots.txt), [fedlex.data.admin.ch](https://fedlex.data.admin.ch/robots.txt) e [www.blv.admin.ch](https://www.blv.admin.ch/robots.txt); documentazione dell'interfaccia Cellar dell'Ufficio delle pubblicazioni (da una ricerca, non riletta alla fonte); [PDF inglese dell'USAV sulla revisione dell'ordinanza sulla protezione degli animali](https://www.blv.admin.ch/dam/blv/en/dokumente/tiere/rechts-und-vollzugsgrundlagen/aenderung-tschv-2024.pdf.download.pdf/Revision241220-TSchV-engl.final.pdf) (dicitura «senza valore legale» da un riassunto di ricerca, non riletta nel PDF); art. 5 URG (da una ricerca, non riletto su Fedlex).
- Ricerche (non riletti alla fonte; aggiunte del 17 novembre sera: diritti sugli abstract di PubMed, indirizzo permissions@aaha.org, licenze degli articoli RECOVER 2024, percorso permessi di ABCD): documentazione di OpenAlex sui dati CC0 e termini d'uso del *Journal Citation Reports*: da verificare prima di decidere l'indicatore.
