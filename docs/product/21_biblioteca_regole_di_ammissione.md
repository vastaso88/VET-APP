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
- **Siti con `robots.txt` che vieta tutto** (esempio: il Lexbrowser della Provincia di Bolzano, `Disallow: /`): nessuna lettura con programmi, scarico a mano (§7).
- **EUR-Lex:** atti riusabili; testi consolidati e sintesi CC BY 4.0 (con fonte e indicazione «modificato»); pausa di 10 secondi tra le richieste.

**Enti pubblici italiani.**
- **salute.gov.it:** CC BY 4.0 «ove non diversamente specificato»: si legge la nota della sezione (COVID-19 è NC, quindi no). Il sito blocca i programmi e **il blocco non si aggira**: quei documenti li scarica una persona a mano (elenco per il proprietario sotto).
- **dati.salute.gov.it:** IODL 2.0, ammesso.
- **iss.it ed EpiCentro:** solo il documento che porta scritto su di sé CC BY.
- **IZS:** no.

La licenza si controlla **per documento, non per sito**, e **due volte**: nel database o sulla pagina e nella riga di licenza dentro il documento. Se non coincidono, vince la più restrittiva e il testo non entra. Le fonti **gialle** (diritti riservati senza divieti per i programmi, per esempio le linee guida WSAVA) e **rosse** restano fuori: sono elencate nella mappa di copertura come «fonte che servirebbe», per le lettere di richiesta di permesso (le firma il proprietario).

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
| `tipo` | `legge`, `linea guida`, `rassegna`, `studio`, `caso clinico`, `manuale` | `studio` |
| `valore_rivista` | numero OpenAlex, fonte e data di rilevazione (solo articoli) | `2,1 (OpenAlex, 2026-11-17)` |
| `licenza` | `CC BY`, `CC0`, `OGL v3.0`, `atto ufficiale`... con l'indirizzo della licenza | |
| `url` / `doi` | dove si trova l'originale (per gli articoli, il collegamento DOI) | |
| `licenza_epmc`, `isOpenAccess`, `licenza_testo`, `copyright_statement`, `licenza_verificata_il` | solo articoli: licenza letta nel database (deve essere «cc by» o «cc0») e nel file XML, avviso di copyright, data del controllo | `cc by`, `© 2025 Rossi et al.` |
| `riga_fonte` | solo leggi: la dicitura obbligatoria | «Normattiva, testo non ufficiale; fa fede la Gazzetta Ufficiale» |
| `lingua` | lingua del testo | `en`, `it` |
| `specie` | gruppi di specie coperti | `cane`, `gatto`, `uccelli`, `tutti` |
| `temi` | temi trattati (parole chiave nostre) | `caldo`, `urgenza` |
| `scaricato_il` | data di scarico | `2026-11-17` |
| `avvertenza_vigenza` | solo per leggi e ordinanze: se l'atto ha una durata limitata o un dubbio sulla vigenza, lo dice (la chat non lo cita come norma in vigore senza verifica) | «efficacia 12 mesi dalla pubblicazione» |
| `riferimento_breve` | la riga che la chat mette in fondo alla risposta | `Hall et al., 2023`, `MS, O.M. 6/8/2013` |

**Come si scrive il riferimento breve**: un autore → «Cognome, AAAA»; due → «Cognome e Cognome, AAAA»; tre o più → «Cognome et al., AAAA»; ente o legge → sigla e atto («MS, O.M. 6/8/2013», «Reg. UE 2016/429»). Se la chat ha già citato quel testo nella stessa conversazione, non lo ripete.

## 6. Quello che la regola NON fa

- Non dice che un testo ammesso sia *giusto per ogni caso*: un articolo su cani da lavoro non vale per un cane da salotto. Il controllo finale della chat verifica che il passo trovato sostenga davvero la frase.
- Non sostituisce la legge sulle dosi: dosi e quantità di farmaci presenti negli articoli non vengono mai riportate dalla chat (resta il blocco già esistente).
- Non autorizza leggere fonti rosse o gialle: quelle restano **fuori** finché non c'è un permesso scritto (le lettere le prepara questa sessione, le firma il proprietario).
- Non è una revisione veterinaria: per decisione del proprietario (17/11/2026) non ce n'è e non si usa il titolo di nessuno come convalida. Contano solo il livello della fonte e la sua licenza.

## 7. Da scaricare a mano (salute.gov.it blocca i programmi)

Il sito del Ministero della Salute non si può leggere con un programma e il blocco non si aggira: i documenti che servono li scarica **una persona**, apre la nota della sezione, controlla che il documento dichiari CC BY 4.0 e non sia di sezioni NC (come COVID-19). Titoli indicativi, da cercare sul sito (non ho verificato gli indirizzi):

1. **Alto Adige, Lexbrowser della Provincia (robots.txt vieta ogni programma):** legge provinciale 15 maggio 2000, n. 9, **art. 6**, e decreto del Presidente della Provincia 8 luglio 2013, n. 19, **artt. 16/bis e 17** (testo consolidato, senza note né massime; fa fede il Bollettino Ufficiale). Servono al caso «assicurazione RC del cane in Alto Adige» (la verifica della Normativa non trova un obbligo provinciale).
2. **Anagrafe degli animali d'affezione**: obblighi di identificazione e registrazione (microchip) di cani, gatti e furetti; chi li fa e quando.
3. **Percorsi formativi per i proprietari di cani («patentino»)**: a chi si applicano.
4. **Cosa fare dopo un morso**: modalità di segnalazione e osservazione dell'animale (il DPR 320/1954, art. 86, è abrogato dal D.Lgs. 136/2022 e non c'è una norma statale che lo sostituisca: valgono i protocolli di Regioni e ASL; cercare la pagina del Ministero o della propria Regione).
5. **Viaggiare con animali da compagnia** (identificazione, vaccinazione antirabbica).
6. **Cani aggressivi e registro dei cani a rischio**, se pubblicato come scheda del Ministero; la pagina «Tutela dall'aggressione dei cani» del Ministero è un buon riassunto ma dice che i comuni «devono» organizzare i percorsi formativi, mentre l'atto modificato dice «possono»: prevale il testo dell'atto.

Per ognuno: salvare il testo, l'indirizzo, la data di scarico e la dicitura di licenza trovata; passare poi il file a questa sessione, che lo mette in biblioteca con la scheda del §5.
