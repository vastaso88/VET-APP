# 21 - La biblioteca di Quokka: regole di ammissione dei testi

Data: 2026-11-17. Sessione «Manuale». Collegato a `docs/llm/07_piano_chat_dalla_biblioteca.md` (piano approvato dal proprietario) e a `docs/compliance/13_parere_fonti_scientifiche_e_diritto_d_autore.md` (parere della Normativa).

**Idea in una riga.** La chat non usa più schede scritte da noi: risponde leggendo **testi originali** conservati sul nostro server. Questo documento dice **quali testi possono entrare** e **come si sceglie, fra due testi, quale usare per primo**. Non si controlla più ogni frase: si controlla il **documento** una volta, all'ingresso.

Parole difficili: **linea guida** = raccomandazioni scritte da un'autorità o da una società scientifica; **rassegna** = articolo che mette insieme molti studi (più affidabile di un singolo studio); **revisione tra pari** = prima della pubblicazione altri esperti controllano l'articolo; **licenza aperta** = il titolare ha dato per iscritto il permesso di riusare il testo (ad esempio CC BY: si può riusare citando l'autore); **valore della rivista** = un numero che dice quanto la rivista è citata dagli altri studiosi (vedi §3).

## 1. Chi ha la precedenza (gerarchia)

Quando più testi rispondono alla stessa domanda, la chat parte dal livello più alto:

| Livello | Cosa | Esempi |
|---|---|---|
| **1** | **Leggi e autorità pubbliche** | leggi, decreti, ordinanze; regolamenti UE; guide di ministeri e agenzie pubbliche (Defra, VMD, ECDC) |
| **2** | **Società scientifiche e linee guida** | WSAVA, ABCD, ESCCAP, RECOVER... *solo se la licenza lo permette* (§2) |
| **3** | **Studi con revisione tra pari** | in ordine: rassegne sistematiche e rassegne, poi studi singoli, poi casi clinici; a parità, vince la rivista con valore più alto (§3); a parità ancora, l'anno più recente |
| **4** | **Università e manuali** | guide di università, manuali, *solo se la licenza lo permette* |

Ci sono quattro eccezioni sensate: una legge vale solo per il suo Paese (per una domanda italiana si cita il testo italiano, non quello di un altro Stato); un testo più vecchio di 15 anni passa sotto uno più recente dello stesso livello; un caso clinico (un solo animale) non prevale mai su una rassegna e va citato come tale.

**Mai**: blog, forum, social, negozi, allevatori, associazioni commerciali, Wikipedia, testi generati da intelligenza artificiale, comunicati di aziende o associazioni commerciali, pagine di prodotti. (Un comunicato di un ministero, come quello del Defra sul caldo, è invece un documento di un'autorità pubblica: livello 1.)

## 1 bis. Scritto per chi, e cosa può fare ogni livello (piano del 20/11/2026)

Dopo la prova del 20/11 (la chat che risponde **solo** dalla biblioteca è risultata poco utile: l'85% dei testi erano studi per ricercatori) la biblioteca ha un altro compito: **Quokka risponde con le sue conoscenze, la biblioteca verifica e cita** (piano `docs/llm/08`). Ne segue un nuovo criterio di ammissione e di priorità:

**Campo `scritto_per`** (nella scheda di ogni testo):

| Valore | Cosa vuol dire | Esempi |
|---|---|---|
| `proprietari` | scritto per chi tiene l'animale: dice cosa fare e cosa evitare | guide e codici di benessere di enti pubblici (nidirect, gov.wales, gov.scot, Defra), avvisi sul caldo, sulla permetrina, sui cibi pericolosi |
| `professionisti` | scritto per chi lavora con gli animali o li controlla: veterinari, venditori, ispettori | guida Defra per le autorità locali (parti per specie), consensi di società |
| `ricercatori` | studio o rassegna scientifica: descrive, misura, discute; non dice al proprietario cosa fare | quasi tutti gli articoli CC BY |
| `legge` | testo di un atto ufficiale | leggi, ordinanze, regolamenti UE |

**Priorità di ammissione** (a parità di licenza): 1) leggi italiane e UE; 2) **guide ufficiali per proprietari** di enti pubblici con licenza aperta; 3) guide per professionisti di enti pubblici; 4) rassegne; 5) studi singoli. **Non si cercano più nuovi studi**: servono solo guide e leggi.

**Ruolo di ciascun livello nella verifica** (campo `ruolo_nella_verifica`):
- **Livello 1 (leggi, guide di enti pubblici): `puo_correggere`.** Se una legge o una guida ufficiale contraddice una frase della risposta, la frase si riscrive dalla fonte, con l'asterisco. Una guida di un altro Paese (UK, ecc.) può correggere un **fatto di cura** (ad esempio «i gigli sono tossici per i gatti») ma **non un obbligo di legge italiano**: per quello vale solo il testo italiano (campo `avvertenza_paese`).
- **Livello 3 (studi): `solo_conferma`.** Uno studio può far mettere l'asterisco a una frase che conferma; non può dare torto al modello (un singolo studio non basta: è l'errore visto nella prova). A parità, **rassegne prima degli studi singoli**, poi valore della rivista, poi anno.

## 2. Quali licenze sono ammesse (via libera della Normativa, 17/11/2026)

Dettaglio e ragioni in `docs/compliance/20_biblioteca_testi_originali_diritti_licenze_e_lettere.md`. Regola in una riga: entra solo ciò che dichiara **per iscritto, sul documento o sulla pagina**, di poter essere riusato anche a fini commerciali e adattato (riassunto, tradotto), oppure ciò che la legge non protegge. Nessun testo giallo o rosso, nemmeno per provare. Mai usare i testi per addestrare modelli.

| Ammessi (semaforo **verde**) | Esclusi finché non c'è un permesso **scritto** |
|---|---|
| Testo di leggi e atti ufficiali (art. 5 L. 633/1941) | Diritti riservati («tutti i diritti riservati»), il «gratuito» senza licenza |
| Enti pubblici con licenza aperta scritta: **OGL v3.0**, **CC BY** (2.0-4.0), **CC0**, **IODL 2.0** | Licenze **NC** («non commerciale»: Quokka è a pagamento) e **ND** («non derivati») |
| Articoli con licenza **CC BY** o **CC0** | **SA** («condividi allo stesso modo») |
| Pubblico dominio | FAO e OMS: di norma NC-SA, si controlla documento per documento |

**Europe PMC (articoli).**
- Solo l'API REST ufficiale (`www.ebi.ac.uk/europepmc/webservices/rest`); mai pagine o PDF di `europepmc.org`.
- Solo articoli con `isOpenAccess` = Y **e** campo `license` esattamente «cc by» o «cc0». Il flag «aperto» da solo non basta: in un campione di 100 articoli aperti, 26 erano NC o NC-ND.
- Una richiesta ogni 10 secondi, con nome onesto e generico, senza dati personali; nessun parallelismo.
- Per ogni testo si registrano id, DOI, licenza letta (nel database e nel file XML) e data; si salvano anche l'avviso di copyright e la dicitura di licenza dell'articolo, per l'attribuzione. Solo il corpo del testo: **non** si salvano figure, tabelle, indirizzi e-mail, ringraziamenti, finanziamenti o conflitti di interessi.
- Solo articoli con revisione tra pari (niente preprint).

**Leggi.**
- Entra solo il **testo dell'atto**: niente commenti, note, massime né impaginazione; niente norme di enti privati (UNI, CEI); opuscoli e rapporti dei ministeri non sono «atti»: per quelli conta la licenza. Niente sentenze né provvedimenti individuali (dati di persone).
- **Normattiva:** riga fonte «Fonte: Normattiva (testo non ufficiale e gratuito; fa fede la Gazzetta Ufficiale a stampa)». Dalla Gazzetta Ufficiale: «Fonte: Gazzetta Ufficiale (testo elettronico non autentico e gratuito; fa fede l'edizione a stampa)». Solo gli atti che servono, uno alla volta, mai le pagine di ricerca. **Si toglie ogni nota redazionale** (note, avvertenze, «N.B.»): possono contenere articoli di altri atti, anche abrogati, che la chat potrebbe attribuire all'atto sbagliato.
- **Vigenza:** un atto abrogato non entra (esempio: il DPR 320/1954, abrogato dal D.Lgs. 136/2022); un atto a termine (ordinanze) entra con le proroghe e con il campo `avvertenza_vigenza`, da riverificare ogni anno (l'O.M. sull'aggressività dei cani è prorogata ogni settembre; ultima: 16/7/2026). Nel riferimento breve e nella risposta si dice «ordinanza ministeriale», non «legge».
- **Siti con `robots.txt` che vieta tutto** (esempio: il Lexbrowser della Provincia di Bolzano, `Disallow: /`): nessuna lettura con programmi, fuori per ora (§7).
- **EUR-Lex:** atti riusabili; testi consolidati e sintesi CC BY 4.0 (con fonte e indicazione «modificato»); pausa di 10 secondi tra le richieste. Il sito eur-lex.europa.eu è **non raggiungibile dallo strumento** (barriera anti-programma; nessun blocco si aggira). Per gli stessi atti la Normativa ammette (compliance/20 §21) il canale dell'Ufficio delle pubblicazioni, **solo** `publications.europa.eu/resource/celex/<CELEX>` (mai `requestAction=rdf` né `/webdav/`), testo italiano, con le intestazioni `Accept: application/xhtml+xml` e `Accept-Language: it`. Condizioni: una richiesta ogni 10 secondi; ci si ferma a una verifica, a un 403/429 o a un reindirizzamento a eur-lex con la sfida; nessuna intestazione che imiti un browser; per le **note** si usa il **consolidato** (CELEX che inizia con 0, con data: CC BY 4.0, senza valore legale), perché `celex/3…` è l'atto come pubblicato e può essere stato modificato; si controlla che il testo sia davvero in italiano; registro per documento: CELEX, versione e data, lingua, indirizzo, data di scarico.

**Enti pubblici italiani.**
- **salute.gov.it:** CC BY 4.0 «ove non diversamente specificato»: si legge la nota della sezione (COVID-19 è NC, quindi no). Il sito blocca i programmi e **il blocco non si aggira**: finché li blocca è «fuori per ora».
- **dati.salute.gov.it:** IODL 2.0, ammesso.
- **iss.it ed EpiCentro:** solo il documento che porta scritto su di sé CC BY.
- **IZS:** no.

La licenza si controlla **per documento, non per sito**, e **due volte**:
- **Articoli scientifici:** nel database (Europe PMC) e nella riga di licenza dentro l'articolo. Se **si contraddicono**, vince la più restrittiva e il testo non entra. Se manca una delle due, il testo non entra.
- **Documenti di governi con licenza di sito** (Regno Unito: OGL): se il documento (un PDF, per esempio) **tace** sulla licenza e il sito dichiara la licenza per tutti i suoi contenuti, **entra** (parere della Normativa, 20/11/2026, doc compliance/20 §17). Nella scheda si registrano: `licenza_nel_documento` = NO, `copyright_nel_documento` (sì/no, con la riga «© Crown copyright …»), la **pagina precisa** della licenza (non la home: `gov.wales/copyright-statement`, `gov.scot/crown-copyright/`, `gov.uk/help/terms-conditions`, la pagina Crown copyright di nidirect/DAERA), la data di lettura e la data di rilettura (**ogni 12 mesi**).
- **Si tolgono** solo i documenti che attribuiscono il testo a un terzo, o che portano «diritti riservati», NC o ND; i passaggi di terzi dentro un documento (per esempio una scheda attribuita a un'associazione, le didascalie e i crediti delle foto) si tolgono dal testo e si annota nella scheda.
- **Solo testo:** niente fotografie, loghi, stemmi né grafici (alcuni PDF, come i codici scozzesi, contengono foto di terzi riprodotte con permesso).
- **Attribuzione** (campo `attribuzione`): ente + «Contains public sector information licensed under the Open Government Licence v3.0» + collegamento + «riassunto e tradotto da Quokka».
- **Vigenza dei codici:** i codici di benessere si controllano ogni anno e si annota la versione in `avvertenza_vigenza` (scozzesi dei cani e dei gatti del 2010: nessuna versione più recente trovata il 20/11/2026; gallesi: cani 2018, gatti 2019, conigli 2009/2011, revisione annunciata ma non pubblicata). Le fonti **gialle** (diritti riservati senza divieti per i programmi, per esempio le linee guida WSAVA) e **rosse** restano fuori: sono elencate nella mappa di copertura come «fonte che servirebbe», per le lettere di richiesta di permesso (le firma il proprietario).

**Abstract.** Di un articolo **non aperto** si possono tenere **solo i metadati** (titolo, autori, anno, rivista, DOI o PMID), senza alcuna frase dell'abstract. Gli abstract di articoli cc by o cc0 sono ammessi come l'articolo intero. Non esiste un campo «solo_abstract».

## 2 bis. Quali argomenti entrano

L'app guida i proprietari a essere **responsabili**, non forma veterinari. Entrano: gestione e cura quotidiana, benessere, etologia e comportamento, alimentazione, prevenzione, **come riconoscere i segni e quando rivolgersi a uno specialista**, doveri e leggi, convivenza con persone e altri animali. **Restano fuori** gli studi su farmaci, terapie chirurgiche e simili: farmacologia, protocolli terapeutici, tecniche operatorie, anestesia (e così le tecniche di diagnostica da specialista). Un caso clinico o una rassegna dove la terapia è solo una parte entra se serve a riconoscere segni e rischi; se il centro è la terapia, no.

## 3. Valore della rivista (spareggio)

- **Cos'è.** L'impact factor classico è a pagamento. Come equivalente gratuito si usa la **citazione media a 2 anni di OpenAlex** (`2yr_mean_citedness`: quante volte, in media, gli articoli della rivista sono citati nei due anni dopo la pubblicazione). OpenAlex è un archivio aperto (licenza CC0). In alternativa si può usare il quartile Scimago.
- **Quando si prende.** **Una sola volta, all'ingresso del documento**; si salva nella scheda (con la data). Non si ricalcola a ogni risposta.
- **A cosa serve.** **Solo come spareggio** tra due studi dello stesso tipo e dello stesso livello. Non sostituisce la gerarchia: una rassegna di una rivista modesta resta sopra uno studio singolo di una rivista famosa. E non dice che lo studio sia vero: dice solo che la rivista è letta e citata.
- **Rivista non indicizzata = fuori.** Se OpenAlex non conosce la rivista, il testo non entra (può essere una rivista predatoria, cioè che pubblica a pagamento senza vero controllo).

## 4. Come si controlla un testo all'ingresso (8 passi, una volta sola)

1. **Tipo e livello**: è una legge, una linea guida, una rassegna, uno studio, un manuale? Si assegna il livello 1-4.
2. **Licenza**: verde, con la riga di licenza trovata e copiata nella scheda.
3. **Rivista** (solo per gli articoli): valore preso da OpenAlex; se manca, il testo non entra.
4. **Controllo in 4 punti dell'ente che lo ospita** (come per le altre fonti): `robots.txt`, pagine dei termini, segnali di riserva leggibili da macchina, avviso nel documento. Per Europe PMC: solo l'interfaccia ufficiale (REST) e solo articoli CC BY o CC0.
5. **Leggi: testo vigente.** Per le leggi si prende il testo *in vigore* (Normattiva) o la Gazzetta Ufficiale, articolo per articolo, con la data di scarico; un atto con efficacia limitata nel tempo (ordinanze) porta l'avvertenza di vigenza.
6. **Testo originale**: si salva il testo intero così com'è, senza riscriverlo, riassumerlo o tradurlo. Niente copie a pezzi.
7. **Argomento:** si escludono studi su farmaci, terapie chirurgiche, anestesia (§2 bis).
8. **Scheda metadati** compilata (vedi §5). Un testo senza scheda completa non entra.

Una fonte può uscire dalla biblioteca in qualsiasi momento (ritiro dell'articolo, cambio di licenza, segnalazione): basta cancellare il suo file.

## 5. Scheda metadati di ogni documento

| Campo | Cosa contiene | Esempio |
|---|---|---|
| `id` | codice stabile e unico | `PMC10385239`, `IT-OM-2013-08-06` |
| `titolo` | titolo originale | |
| `autori` | cognomi degli autori (o l'ente) | `Hall`, `Ministero della Salute` |
| `anno` | anno di pubblicazione | `2023` |
| `rivista_o_ente` | rivista o ente che lo pubblica | `Veterinary Sciences`, `Gazzetta Ufficiale` |
| `livello` | 1, 2, 3 o 4 (§1) | `3` |
| `scritto_per` | `proprietari`, `professionisti`, `ricercatori` o `legge` (§1 bis) | `proprietari` |
| `ruolo_nella_verifica` | `puo_correggere` (livello 1) o `solo_conferma` (studi) | `solo_conferma` |
| `paese` | Paese dell'ente (le guide estere non sono norme italiane) | `UK-Galles`, `IT` |
| `tipo` | `legge`, `linea guida`, `rassegna`, `studio`, `caso clinico`, `manuale` | `studio` |
| `valore_rivista` | numero OpenAlex, fonte e data di rilevazione (solo articoli) | `2,1 (OpenAlex, 2026-11-17)` |
| `licenza` | `CC BY`, `CC0`, `OGL v3.0`, `atto ufficiale`... con l'indirizzo della licenza | |
| `url` / `doi` | dove si trova l'originale (per gli articoli, il collegamento DOI) | |
| `licenza_epmc`, `isOpenAccess`, `licenza_testo`, `copyright_statement`, `licenza_verificata_il` | solo articoli: licenza letta nel database (deve essere «cc by» o «cc0») e nel file XML, avviso di copyright, data del controllo | `cc by`, `© 2025 Rossi et al.` |
| `licenza_letta_su`, `licenza_nel_documento`, `controllo_il`, `robots` | solo guide di enti pubblici: dove è stata letta la licenza, se la riga di licenza c'è anche nel documento (alcuni PDF non l'hanno: se manca, il testo resta «da confermare dalla Normativa»), data del controllo in 4 punti, esito del `robots.txt` | «pagina del sito: OGL v3.0», «NO: riga assente nel PDF» |
| `riga_fonte` | solo leggi: la dicitura obbligatoria | «Normattiva, testo non ufficiale; fa fede la Gazzetta Ufficiale» |
| `lingua` | lingua del testo | `en`, `it` |
| `specie` | gruppi di specie coperti | `cane`, `gatto`, `uccelli`, `tutti` |
| `temi` | temi trattati (parole chiave nostre) | `caldo`, `alimentazione` |
| `scaricato_il` | data di scarico | `2026-11-17` |
| `avvertenza_vigenza` | solo per leggi e ordinanze: se l'atto ha una durata limitata o un dubbio sulla vigenza, lo dice (la chat non lo cita come norma in vigore senza verifica) | «efficacia 12 mesi dalla pubblicazione» |
| `riferimento_breve` | la riga che la chat mette in fondo alla risposta | `Hall et al., 2023`, `MS, O.M. 6/8/2013` |

**Come si scrive il riferimento breve**: un autore → «Cognome, AAAA»; due → «Cognome e Cognome, AAAA»; tre o più → «Cognome et al., AAAA»; ente o legge → sigla e atto («MS, O.M. 6/8/2013», «Reg. UE 2016/429»). Se la chat ha già citato quel testo nella stessa conversazione, non lo ripete.

## 6. Quello che la regola NON fa

- Non dice che un testo ammesso sia *giusto per ogni caso*: un articolo su cani da lavoro non vale per un cane da salotto. Il controllo finale della chat verifica che il passo trovato sostenga davvero la frase.
- Non sostituisce la legge sulle dosi: dosi e quantità di farmaci presenti negli articoli non vengono mai riportate dalla chat (resta il blocco già esistente).
- Non autorizza leggere fonti rosse o gialle: quelle restano **fuori** finché non c'è un permesso scritto (le lettere le prepara questa sessione, le firma il proprietario).
- Non è una revisione veterinaria: per decisione del proprietario (17/11/2026) non ce n'è e non si usa il titolo di nessuno come convalida. Contano solo il livello della fonte e la sua licenza.

## 7. L'elenco bianco: gruppi e campi (piano 08, parere della Normativa del 20/11/2026)

Le fonti che la chat può **leggere al momento** (senza conservare il testo) o dalle quali si possono **conservare** testi interi sono nell'**elenco bianco** (`.local/chat_eval/biblioteca/elenco_bianco_candidati.md` e `.json`). Ogni sito ha un **gruppo**:

| Gruppo | Cosa vuol dire | Cosa si può fare |
|---|---|---|
| **a** | aperto o ufficiale (leggi, enti pubblici con licenza aperta) | lettura e note senza tetto; si conserva il testo se la licenza lo dice |
| **a\*** | come (a), ma solo dopo la lettura della nota legale del sito (se il programma non la raggiunge: fuori per ora) o con riserva ⚖️ per i testi federali USA | come (a) dopo la nota |
| **b** | diritti riservati, senza divieti espliciti | lettura al momento a condizioni (controllo in 4 punti per sito, valido 12 mesi); **nessun testo conservato**; solo note in parole nostre; tetto: 1% delle voci del sito e al massimo 50 note (20 per i siti piccoli); allarme al 50% |
| **c** | chiede un permesso o vieta l'uso automatico o commerciale | **nessuna lettura senza permesso scritto**, nemmeno «per provare» |
| **no** | escluso | - |

**Scadenza.** Le **note** della biblioteca scadono dopo **6 mesi** (decisione del proprietario, 20/11/2026) e vanno rilette alla fonte; il **controllo dei siti** (licenza, `robots.txt`, termini) si rilegge ogni **12 mesi**, salvo diversa indicazione della Normativa.

**Siti che bloccano i programmi: fuori per ora.** Dove il sito blocca i programmi (barriere anti-bot, `robots.txt` che vieta, risposte 403/404) il sito è «non raggiungibile: fuori per ora»; nessun blocco si aggira e nessuno fuori per ora è previsto (decisione del proprietario, 20/11/2026). Dei siti riservati (gruppo c) si leggono solo i termini d'uso, e solo se il loro `robots.txt` consente la lettura ai programmi.

Campi per ogni sito: nome, dominio, pagina di esempio, **gruppo**, livello, scritto per chi, specie e temi, **licenza o condizioni lette** (con la pagina), `robots.txt` (blocca le IA?), raggiungibile dal programma, conservare il testo, **permesso**, **tetto di note** e **contatore** (note create per quel sito), **pagine stimate**, **data del controllo** (valido 12 mesi). Un sito entra solo con il parere della Normativa e il controllo in 4 punti; prima di leggere un host nuovo si controlla il suo `robots.txt`.

## 8. L'elenco bianco: parere sito per sito (controlli del 20/11/2026)

Gruppi come nel §7. Per i siti (c) nessun contenuto è stato letto: solo `robots.txt` e pagina dei termini. **Nessun sito (b) è ancora approvato**: le cinque associazioni britanniche (Blue Cross, PDSA, Cats Protection, Dogs Trust, Battersea) hanno riserve scritte nei termini, come BVA e BSAVA; i termini di Rabbit Welfare Association, ARAV, AVSAB, SCIVAC, ENPA, RCVS e FNOVI non sono stati trovati dal programma: restano **fuori per ora**. Agriculture Victoria, Queensland, EFSA (pareri CC BY-ND), iCatCare, AVMA e ASPCA sono **esclusi**.

| # | Fonte | Gruppo | Livello | Permesso | Tetto note | Contatore | Controllo |
|---|---|---|---|---|---|---|---|
| 1 | Defra, UKHSA, VMD (gov.uk) | a | 1 | no | — | 0 | 2026-11-20 |
| 2 | Scottish Government (gov.scot) | a | 1 | no | — | 0 | 2026-11-20 |
| 3 | Welsh Government (gov.wales) | a | 1 | no | — | 0 | 2026-11-20 |
| 4 | nidirect (Irlanda del Nord) | a | 1 | no | — | 0 | 2026-11-20 |
| 5 | DAERA (Irlanda del Nord) | a | 1 | no | — | 0 | 2026-11-20 |
| 6 | Normattiva e Gazzetta Ufficiale | a | 1 | no | — | 0 | 2026-11-20 |
| 7 | EUR-Lex | a | 1 | no | — | 0 | 2026-11-20 |
| 8 | Ministero della Salute (salute.gov.it) | a* | 1 | no | — | 0 | 2026-11-20 |
| 9 | ECDC | a | 1 | no | — | 0 | 2026-11-20 |
| 10 | Your Europe (Commissione europea): viaggiare con animali | a* | 1 | no, se la nota conferma | — | 0 | 2026-11-20 |
| 11 | Governo irlandese (gov.ie, DAFM) | a* | 1 | sì, se la nota non apre | — | 0 | 2026-11-20 |
| 12 | MPI Nuova Zelanda (codici di benessere) | a | 1 | no | — | 0 | 2026-11-20 |
| 13 | Agriculture Victoria | no | 1 | sì (Stato di Victoria) | 0 | 0 | 2026-11-20 |
| 14 | NSW DPI (Australia) | a* | 1 | no, se la nota si applica al sito DPI | — | 0 | 2026-11-20 |
| 15 | CDC «Healthy Pets» (USA) | a* | 1 | no (riserva) | — | 0 | 2026-11-20 |
| 16 | FDA «Animal Health Literacy» e Consumer Updates (USA) | a* | 1 | no (riserva) | — | 0 | 2026-11-20 |
| 17 | Queensland DPI | c | 1 | sì | 0 | 0 | 2026-11-20 |
| 18 | EFSA (pareri dell'EFSA Journal) | c | 1 | no | pareri 0 | 0 | 2026-11-20 |
| 19 | Svizzera, Ordinanza sulla protezione degli animali OPAn (RS 455.1): **fuori per ora** (Fedlex dinamico e host dei file vietato ai programmi; copia italiana USAV 404; la traduzione inglese USAV non è ufficiale e non si cita). Sulle domande di legge svizzera la chat risponde senza fonte svizzera | a (fuori per ora) | 1 | no | — | 0 | 2026-11-20 |
| 20 | USAV/BLV «Detenzione di animali» (Svizzera) | a* | 1 | sì, se la nota non apre | — | 0 | 2026-11-20 |
| 21 | Austria, 2. Tierhaltungsverordnung (RIS) | a | 1 | no | — | 0 | 2026-11-20 |
| 22 | Germania, gesetze-im-internet.de (Tierschutzgesetz, Tierschutz-Hundeverordnung) | a | 1 | no | — | 0 | 2026-11-20 |
| 23 | Francia, Légifrance (Code rural) | a | 1 | no | — | 0 | 2026-11-20 |
| 24 | MSD Veterinary Manual (Merck) | c | 4 | sì (lettere ferme) | 0 | 0 | 2026-11-20 |
| 25 | RSPCA (UK) | c | 4 | sì | 0 | 0 | 2026-11-20 |
| 26 | Blue Cross (UK) | c | 4 | sì | 0 | 0 | 2026-11-20 |
| 27 | PDSA (UK) | c | 4 | sì | 0 | 0 | 2026-11-20 |
| 28 | Cats Protection (UK) | c | 4 | sì | 0 | 0 | 2026-11-20 |
| 29 | Dogs Trust (UK) | c | 4 | sì | 0 | 0 | 2026-11-20 |
| 30 | Battersea Dogs & Cats Home (UK) | c | 4 | sì | 0 | 0 | 2026-11-20 |
| 31 | Rabbit Welfare Association & Fund (UK) | c | 4 | sì, o passaggio a (b) | 0; se (b): ~20 (sito piccolo, ~600 voci stimate) | 0 | 2026-11-20 |
| 32 | International Cat Care (iCatCare) | no | 2 | sì (bassa priorità) | 0 | 0 | 2026-11-20 |
| 33 | WSAVA (linee guida globali) | c | 2 | sì (modulo) | 0 | 0 | 2026-11-20 |
| 34 | ESCCAP (parassiti) | c | 2 | sì | 0 | 0 | 2026-11-20 |
| 35 | AAV (Association of Avian Veterinarians) | c | 2 | sì | 0 | 0 | 2026-11-20 |
| 36 | ARAV (Association of Reptile and Amphibian Veterinarians) | c | 2 | sì, o passaggio a (b) | 0; se (b): 20 (sito piccolo) | 0 | 2026-11-20 |
| 37 | AVSAB (comportamento) | c | 2 | sì, o passaggio a (b) | 0; se (b): 20 (sito piccolo, ~360 voci) | 0 | 2026-11-20 |
| 38 | AVMA e ASPCA (USA) | no | 4 | sì (bassa priorità) | 0 | 0 | 2026-11-20 |
| 39 | SCIVAC (società scientifica italiana) | c | 2 | sì, o passaggio a (b) | 0; se (b): 20 (sito piccolo) | 0 | 2026-11-20 |
| 40 | ENPA (protezione animali, italiano) | c | 4 | sì, o passaggio a (b) | 0; se (b): 20 (sito piccolo) | 0 | 2026-11-20 |
| 41 | BVA (British Veterinary Association) | c | 2 | sì | 0 | 0 | 2026-11-20 |
| 42 | BSAVA | c | 2 | sì | 0 | 0 | 2026-11-20 |
| 43 | RCVS (Royal College of Veterinary Surgeons) | c | 1 | sì, o passaggio a (b) | 0; se (b): 16 (1% di ~1.600 voci) | 0 | 2026-11-20 |
| 44 | FNOVI (Federazione degli Ordini dei Veterinari) | c | 2 | sì, o passaggio a (b) | 0; se (b): 20 (sito piccolo) | 0 | 2026-11-20 |

Formule di attribuzione (Normativa, §19.1): **OGL** = ente + «Contains public sector information licensed under the Open Government Licence v3.0» + collegamento; **CC BY** = ente + «CC BY 4.0» + collegamento + «modificato»; **NZ** = «This work is based on/includes MPI data which is licensed by MPI for re-use under the Creative Commons Attribution 4.0 International licence»; **NSW** = «© State of New South Wales»; **atto** = «Fonte: [portale] (testo non ufficiale e gratuito; fa fede [bollettino ufficiale])»; **USA** = «Source: [agenzia]» + «l'ente non approva» + collegamento (CDC: «Source: CDC» e nessun cambiamento sostanziale); **(b)** = ente, anno, collegamento, «consultata il [data]» e «© [ente]», nessuna licenza dichiarata. In ogni caso: «riassunto da Quokka», niente loghi, solo testo.

## 9. La griglia: specie × temi di pronto uso (piano 08, 20/11/2026)

La biblioteca delle note e l'elenco bianco delle fonti si organizzano in **caselle**: gruppo di specie × tema. Ogni nota della biblioteca, ogni fonte dell'elenco bianco e ogni domanda raccolta ha una casella (`Sxx-Tyy`). La casella dice dove cercare prima e in che ordine arricchire la biblioteca.

**12 gruppi di specie** (le specie rare usano il gruppo più vicino; una specie non indicata va in «S00» e si chiede o si deduce dalla scheda dell'animale):

| Codice | Gruppo |
|---|---|
| S01 | Cani |
| S02 | Gatti |
| S03 | Conigli |
| S04 | Cavie e cincillà |
| S05 | Piccoli roditori (criceti, ratti, topi, gerbilli, degu) |
| S06 | Furetti |
| S07 | Uccelli da gabbia (pappagalli, cocorite, calopsiti, canarini) |
| S08 | Rettili (lucertole, gechi, camaleonti, serpenti) |
| S09 | Testuggini e tartarughe |
| S10 | Anfibi (axolotl, rane, tritoni) |
| S11 | Pesci d'acqua dolce |
| S12 | Acquario marino |

**12 temi di pronto uso:**

| Codice | Tema | Che cosa contiene |
|---|---|---|
| T01 | Alimentazione | cosa e quanto, frequenza dei pasti, integratori, diete particolari (carne cruda) |
| T02 | Ambiente e alloggio | gabbia, vasca, terrario, temperatura, luce, umidità, spazio, qualità dell'acqua |
| T03 | Cura quotidiana | igiene, unghie, pelo, denti, esercizio, routine |
| T04 | Comportamento e convivenza | educazione, aggressività, paura, abbaio, convivenza con persone, bambini e altri animali |
| T05 | Prevenzione | vaccini, parassiti, sterilizzazione, controlli, identificazione |
| T06 | Segni per cui andare dal veterinario | segni di malattia e quando rivolgersi al veterinario: un tema come gli altri, senza percorsi o priorità a parte (Quokka non gestisce le urgenze; un caso grave segue lo stesso percorso delle altre domande) |
| T07 | Cose tossiche e pericolose | cibi, piante, prodotti, fumi, farmaci umani |
| T08 | Cuccioli e anziani | primi giorni, socializzazione, cure dell'età avanzata |
| T09 | Riproduzione | calore, gravidanza, parto, uova |
| T10 | Viaggi | trasporto, documenti, vacanze, trasloco |
| T11 | Doveri e leggi | obblighi del proprietario, anagrafe, museruola e guinzaglio, specie protette, responsabilità |
| T12 | Fine vita | eutanasia, qualità della vita, lutto |

**Come si usa la griglia** (in coerenza con §1 bis):
- Una **nota** (un fatto) sta in una casella; porta `scritto_per`, livello e paese della fonte. La **prova di sufficienza** guarda la casella: per ogni fatto che serve a una domanda deve esserci una nota accreditata (legge o guida ufficiale, oppure almeno due fonti d'accordo), non scaduta.
- **Chi può correggere**: solo il livello 1 (leggi e guide di enti pubblici; una guida estera solo per fatti di cura, mai per obblighi di legge italiani). Gli studi confermano soltanto; rassegne prima degli studi singoli.
- **Priorità di riempimento**: le caselle con più domande (stima sulle 1239 domande uniche raccolte: forum, banca per specie, messaggi dei giri 2 e 3, 279 scenari di valutazione, casi del confronto; assegnazione automatica per parole chiave, i testi restano in `.local`). Le 20 più chieste:

| # | Casella | Domande |
|---|---|---|
| 1 | S01-T06 Cani / Segni per cui andare dal veterinario | 48 |
| 2 | S02-T06 Gatti / Segni per cui andare dal veterinario | 47 |
| 3 | S11-T02 Pesci d'acqua dolce / Ambiente e alloggio | 46 |
| 4 | S07-T06 Uccelli da gabbia (pappagalli, cocorite, calopsiti, canarini) / Segni per cui andare dal veterinario | 42 |
| 5 | S01-T04 Cani / Comportamento e convivenza | 31 |
| 6 | S01-T01 Cani / Alimentazione | 30 |
| 7 | S10-T06 Anfibi (axolotl, rane, tritoni) / Segni per cui andare dal veterinario | 30 |
| 8 | S05-T06 Piccoli roditori (criceti, ratti, topi, gerbilli, degu) / Segni per cui andare dal veterinario | 30 |
| 9 | S08-T02 Rettili (lucertole, gechi, camaleonti, serpenti) / Ambiente e alloggio | 25 |
| 10 | S08-T06 Rettili (lucertole, gechi, camaleonti, serpenti) / Segni per cui andare dal veterinario | 23 |
| 11 | S02-T01 Gatti / Alimentazione | 22 |
| 12 | S02-T04 Gatti / Comportamento e convivenza | 21 |
| 13 | S07-T02 Uccelli da gabbia (pappagalli, cocorite, calopsiti, canarini) / Ambiente e alloggio | 20 |
| 14 | S05-T04 Piccoli roditori (criceti, ratti, topi, gerbilli, degu) / Comportamento e convivenza | 20 |
| 15 | S05-T02 Piccoli roditori (criceti, ratti, topi, gerbilli, degu) / Ambiente e alloggio | 18 |
| 16 | S01-T11 Cani / Doveri e leggi | 16 |
| 17 | S01-T07 Cani / Cose tossiche e pericolose | 16 |
| 18 | S01-T05 Cani / Prevenzione | 16 |
| 19 | S11-T06 Pesci d'acqua dolce / Segni per cui andare dal veterinario | 16 |
| 20 | S10-T02 Anfibi (axolotl, rane, tritoni) / Ambiente e alloggio | 16 |

Avvertenza sui numeri: le domande vengono da insiemi di prova costruiti anche per mettere alla prova gli animali esotici (anfibi, uccelli, pesci), quindi **sovrastimano gli esotici rispetto all'uso reale**; l'ordine vero si misurerà dal contatore delle domande senza fonte (solo specie e tema). Circa il 22% delle domande è troppo vago o fuori tema (sicurezza, istruzioni del modello) per avere un tema, e il 10% non indica la specie; l'assegnazione automatica sbaglia in qualche caso (stima: circa 8 su 10 giuste in un controllo a campione di 30).
