# 15 - Catalogo delle fonti approvate e prime schede di salute

Data: 2026-11-10. Sessione "Manuale" su richiesta dell'Orchestratore. Parte dal piano `docs/product/13` §2 e dal parere della Normativa `docs/compliance/13_parere_fonti_scientifiche_e_diritto_d_autore.md`; serve alla chat (`docs/product/14_analisi_manifesto_rag.md`). **Prima versione**: nessuna scheda è ancora "rivista" dal proprietario, e nulla è pubblicato.

## 0. In breve

**Aggiornamento del 2026-11-15 (richiesta del proprietario: informarsi solo su fonti ufficiali).** Le 11 schede sono state ricostruite usando **solo** fonti di livello 1 (enti pubblici, società scientifiche veterinarie), senza nessuna fonte rossa: la lista di rilettura a mano è scesa a **zero frasi**. Il prezzo è che le schede sono più corte: quello che non si trova su una fonte ufficiale consentita è stato tolto, senza sostituirlo con conoscenze del modello. Il quadro per scheda è nel §7; il testo per il proprietario è in `docs/product/16_schede_da_approvare.md` (si rigenera con `python scripts/manuale/check_manuale.py --approvazione`).

- **Catalogo**: 3 livelli di fonti, con le regole per riviste, diritti d'uso, data di controllo. Una prima lista di **enti e società** (§2) e l'elenco delle **11 fonti oggi usate** (§3), tutte gialle o verdi.
- **Schede**: 11 di salute non urgente (`data/manuale/`): cane 3, gatto 4, coniglio 4. Ogni frase ha la sua fonte e il punto esatto, tranne al massimo 3 consigli per scheda segnati «nostro». Tutte in bozza: manca la lettura del proprietario.
- **Cosa non c'è più o non c'è ancora**: cane vomito e diarrea (nessun documento ufficiale su una fonte consentita: scheda tolta), vaccini del coniglio per l'Italia (solo la guida britannica), perdita di peso del cane, vomito del gatto, segni dell'allergia alle pulci, come togliere una zecca (§6).
- **Controllo**: per ogni scheda, una sessione indipendente ha confrontato ogni frase con il testo della fonte (accuratezza e vicinanza alla fonte). I giri di controllo, i problemi trovati e le regole che ne sono uscite sono nel §7.1; le correzioni dell'ultimo giro non hanno avuto un controllo successivo.
- **Archivio della chat**: `python scripts/manuale/check_manuale.py --esporta` scrive `data/manuale/health_cards.json` nel formato chiesto (id, species, topic, title, body max 4000, source, source_level, state `draft`). Vedi §8.

## 1. Le regole di classificazione

**Dal 2026-11-15 le schede usano solo il livello 1** (enti pubblici, società scientifiche veterinarie, norme ufficiali) e nessuna fonte rossa: il livello 2 e 3 e la discussione sui quartili delle riviste (§1.1) restano come regole generali ma non sono più usate.

| Livello | Cosa | Ammesso per |
|---|---|---|
| **1** | Linee guida e posizioni di società scientifiche o enti pubblici; testo ufficiale delle norme; guide per proprietari scritte da quegli stessi enti | affermazioni di salute, prevenzione, doveri |
| **2** | Letteratura con revisione tra pari: revisioni sistematiche o narrative, studi, consensi di esperti pubblicati su rivista | affermazioni di salute, con la fonte detta («uno studio su N animali») |
| **3** | Testi universitari e manuali di esperti | solo dove non c'è di meglio, dichiarato nella scheda, brevi citazioni e riassunto |
| **Escluse** | Blog, forum, siti commerciali (alimenti, accessori, assicurazioni, negozi, allevatori), contenuti generati, Wikipedia, associazioni di benessere come fonte diretta | mai |

Regole che valgono sempre (da doc 13 §2 e dal parere):
- ogni frase indica la fonte e il punto esatto; l'anno e il modo in cui è stata letta (testo completo, solo riassunto) sono nel catalogo;
- si riassume con parole nostre; nessuna copia di testo, tabelle, figure o schemi; citazioni brevissime; nessun logo; «secondo le linee guida X» sì, «approvato da X» no;
- licenze: ammesse CC0 e CC BY (con attribuzione e «modificato da Quokka»); da evitare CC BY-SA; **non** usate come base di una scheda le fonti CC BY-NC o ND (vedi §5);
- uno studio da solo non regge un'affermazione generale; una fonte vecchia si usa solo se l'ente che l'ha pubblicata la presenta ancora come attuale o se una più nuova la conferma (doc 13 §2.4);
- chi ha pagato la fonte lo scriviamo (esempi reali: vaccino WSAVA sostenuto da un produttore di vaccini; rassegne sul vomito pagate da un produttore di un farmaco contro il vomito).

### 1.1 Il livello 2 e le riviste: cosa si è potuto e non si è potuto verificare

Il proprietario ha chiesto riviste di primo quartile nella categoria veterinaria, con il fattore d'impatto confrontato con le altre riviste veterinarie.

- **Non ho potuto verificare i quartili ufficiali.** SCImago e le classifiche JCR sono dietro una verifica anti-robot che non si deve aggirare; per le classifiche di JCR serve un abbonamento.
- **L'indicatore alternativo non è affidabile**: ho provato la «citazioni medie a due anni» di OpenAlex su circa 240 riviste con nome veterinario. Dà risultati incoerenti (per esempio *Veterinary Record*, rivista della BVA, risulta in posizione 157 su 239). Non lo uso.
- **Proposta**: tenere due sottolivelli. **2A** = revisioni e consensi pubblicati su riviste di una società veterinaria o su riviste veterinarie riconosciute; **2B** = altro con revisione tra pari (per esempio *PLoS ONE* e *Animals*, che non sono riviste veterinarie e non hanno un quartile nella categoria veterinaria). Il 2B regge solo frasi descrittive e mai una raccomandazione.
- **Da fare, a mano**: aprire SCImago o JCR in un browser normale e annotare quartile e fattore d'impatto delle riviste già usate: *J Small Anim Pract*, *J Feline Med Surg*, *Vet Rec*, *BMC Vet Res*, *Vet Clin North Am Exot Anim Pract*, *PLoS ONE*, *Animals*. Nel catalogo è un campo (`indicatore_rivista`) ancora vuoto.

## 2. Catalogo A: gli enti e le società

Controllato il 2026-11-10 aprendo le pagine ufficiali. «Bloccato» = l'apertura automatica è rifiutata (verifica anti-robot o errore 403/503); non si aggira, va aperto da una persona o chiesto per iscritto.

| Ente | Livello | Pagina ufficiale aperta | Documenti utili visti (titolo, anno) | Cosa dice sul riuso | Finanziamenti dichiarati |
|---|---|---|---|---|---|
| **WSAVA** (World Small Animal Veterinary Association) | 1 | wsava.org/global-guidelines/ (e le pagine di vaccinazione, nutrizione, dolore, riproduzione, benessere) | Linee guida vaccinazione 2024 (JSAP, doi 10.1111/jsap.13718); linee guida di valutazione nutrizionale 2011 (JSAP) con kit e guide per proprietari (2025); controllo della riproduzione 2024 (JSAP, doi 10.1111/jsap.13724); dolore (2022); benessere (2018) | «All Rights Reserved»; per il kit di nutrizione: risorse «our copyright», chiedono di seguire la loro procedura (SOP v4: uso integrale e invariato, logo, riga di credito; se a scopo di lucro, approvazione del Consiglio) e di compilare un modulo; le tavole sul punteggio corporeo hanno diritti di terzi | Partner industriali (MSD Animal Health, Purina, Zoetis, Hill's, Royal Canin e altri); la linea guida sui vaccini dichiara il sostegno di MSD senza diritto di veto |
| **AAHA** (American Animal Hospital Association) | 1 | **bloccato** (403) | Letto altrove: linee guida nutrizione 2021 (JAAHA 57:153-174), comportamento 2015, fasi di vita del gatto 2021 con AAFP e ISFM | © AAHA; per la nutrizione 2021 Crossref indica CC BY-NC-ND 4.0 (il PDF non lo stampa) | Contributi di aziende (Hill's, Purina, Royal Canin, Boehringer, Zoetis e altre) |
| **ISFM / iCatCare** | 1 | icatcare.org (termini, società veterinaria, rivista JFMS); la pagina delle linee guida non trovata («sito in trasferimento») | Consenso iCatCare 2025 sulle basse vie urinarie (JFMS); consenso ISFM 2022 sul gatto che non mangia (JFMS); guide per proprietari («Cat Carer Guides») 2022-2025 | «Solo uso personale non commerciale»; riuso o ripubblicazione solo con permesso scritto. Il consenso 2025 è CC BY-NC 4.0 | Partner commerciali elencati (Ceva, Elanco, Hill's, IDEXX, Purina, Royal Canin, Vetoquinol, Virbac, Zoetis) |
| **AAFP** (oggi FelineVMA) | 1 | catvets.com/clinical-resources/practice-guidelines | Fasi di vita 2021; cura del gatto anziano 2021; vaccinazione 2020; ambiente 2013; cavità orale 2025; uso degli FANS 2024 | Nessun testo sul riuso trovato | Non indicati nelle pagine aperte (le singole linee guida riportano contributi industriali) |
| **ABCD** (European Advisory Board on Cat Diseases) | 1 | abcdcatsvets.org | Buone pratiche di vaccinazione (2022, aggiornata 2024); panleucopenia; PIF (aggiornata 2026); FeLV, FIV, ecc. | Avviso legale: riproduzione, modifica, pubblicazione vietate senza autorizzazione scritta | Boehringer Ingelheim, MSD, Vétoquinol, Virbac |
| **BSAVA** | 1 | **bloccato** (403) | non verificato | non verificato | non verificato |
| **FECAVA** | 1 | fecava.org | Posizioni e schede (per esempio comportamento e addestramento con FVE e WSAVA, 2024; allevamento sano 2018) | «All rights reserved», nessun testo sul permesso | Scheda 2026 realizzata con Royal Canin; collaborazioni con aziende |
| **FVE** (Federation of Veterinarians of Europe) | 1 | fve.org | Posizione comune su comportamento e addestramento (2024) | Vietata la riproduzione commerciale senza permesso scritto | Soprattutto quote dei soci |
| **AVSAB** | 1 | avsab.org/resources/position-statements/ | Addestramento etico del cane (2021); dominanza; socializzazione del cucciolo; come scegliere un addestratore (2026) | Nessun testo sul riuso | Non indicato |
| **ESVCE** | 1 | esvce.org | Dispositivi elettronici di addestramento; uso di farmaci negli stati fobici (2026) | Solo avvertenza di responsabilità | Non indicato |
| **ESCCAP** | 1 | esccap.org (linee guida 1-9) | GL1 vermi (7ª ed. giugno 2025); GL3 ectoparassiti (7ª ed. gennaio 2022); GL5 malattie da vettori (5ª ed. dicembre 2024); GL7 piccoli mammiferi (1ª ed. luglio 2017) | Il PDF: ogni ridistribuzione o riproduzione richiede il permesso scritto di ESCCAP; il sito vieta la copia senza permesso; il logo non si usa | Aziende del settore (Elanco, IDEXX, MSD, Vetoquinol, Zoetis, Boehringer, Ceva): gli sponsor maggiori possono leggere e commentare le bozze, ESCCAP mantiene il controllo editoriale |
| **ARAV** (rettili e anfibi) | 1 | arav.org | Solo dichiarazioni di posizione politiche; le guide alla cura «in arrivo» | «All Rights Reserved» | Non indicato |
| **AEMV** (mammiferi esotici) | 1 | aemv.org | Schede di cura (coniglio, furetto, criceto, cavia e altri) | «All rights reserved», nessun permesso per ripubblicare | Non indicato |
| **AAV** (uccelli) | 1 | **bloccato** (403) | non verificato | non verificato | non verificato |
| **Ministero della Salute** | 1 | **verde dopo lettura a mano del documento** (parere della Normativa, 17/11/2026: CC BY 4.0 «ove non diversamente specificato», nota di ogni sezione; COVID-19 è NC = rosso). Il sito principale blocca i programmi e il blocco non si aggira: scarico a mano (elenco in doc 21 §7). Portale dati dati.salute.gov.it: IODL 2.0, verde | letta a mano il 17/11/2026 (Normativa, doc compliance/20 §2.2) | Il portale dati: licenza IODL 2.0 (riuso libero). Per i testi di atti ufficiali: art. 5 legge 633/1941 (la legge sul diritto d'autore non si applica ai testi degli atti ufficiali) e D.Lgs. 36/2006 (riuso dell'informazione pubblica, a fini commerciali e no), da leggere con la Normativa | n.a. |
| **IZS** (Istituti Zooprofilattici) | 1 | izsler.it, izsvenezie.it (aperte singole pagine e PDF) | Schede sulla mixomatosi e la malattia emorragica virale del coniglio (2021); pagina IZSVe sulla variante Toledo (2026) | Nessuna riga di licenza | n.a. |
| **EFSA** | 1 | una pagina aperta; **avvertenza legale bloccata** (429) | Poco sugli animali da compagnia | non verificato | n.a. |
| **EMA** (medicinali veterinari) | 1 | **bloccato** oltre la pagina iniziale (503) | non verificato | non verificato | n.a. |

Conclusione trasversale: **nessuno** degli enti esaminati pubblica le proprie linee guida con una licenza aperta. Per ESCCAP, ABCD, iCatCare e FVE il testo parla esplicitamente di permesso scritto per la riproduzione; WSAVA ha una procedura e un modulo. Il parere della Normativa permette il riassunto di fatti con parole nostre; i permessi servono per copiare, non per riassumere (ma vedi §5).

### 2.1 Controlli in 4 punti del 2026-11-15 (nuovi enti)

Eseguiti con uno script che si identifica con un nome onesto, una richiesta alla volta, più la lettura a mano delle pagine dei termini. Esito: **verde** (CC0, CC BY o OGL indicate), **giallo** (diritti riservati, nessuna riserva sull'estrazione né divieto di uso commerciale trovati), **rosso** (riserva presente, uso commerciale vietato, licenza NC/ND, oppure controllo impossibile perché il sito blocca i programmi).

| Host | Esito | Motivo |
|---|---|---|
| gov.scot, gov.wales, nidirect.gov.uk, daera-ni.gov.uk, gov.uk, assets.publishing.service.gov.uk, ukhsa.blog.gov.uk | verde | Open Government Licence v3.0 indicata; robots senza divieti per l'IA (DAERA chiede solo una pausa fra le richieste) |
| ecdc.europa.eu, commission.europa.eu | verde | CC BY 4.0 sui contenuti propri, uso commerciale ammesso con attribuzione |
| wsava.org | giallo | robots senza righe per l'IA; nessuna pagina di termini; «All Rights Reserved» |
| catvets.com (AAFP/FelineVMA) | giallo | robots con pausa di 120 s fra le richieste; nessuna pagina di termini; «All rights reserved» (la maggior parte delle linee guida porta a riviste rosse) |
| aemv.org | giallo (provvisorio) | nessuna pagina di termini, solo informativa privacy non esaminata; non usata |
| fnovi.it | giallo (provvisorio) | tdmrep inconclusivo (403); le diapositive hanno un'autrice di un ente rosso: non usate |
| efsa.europa.eu | giallo | uso con attribuzione, nessuna licenza né divieto; il parere sul coniglio è su Wiley (rosso): non letto |
| fecava.org | rosso (cautela) | termini: niente copia né «sfruttamento» senza consenso scritto; le schede chiedono di contattare FECAVA prima dell'uso; quattro schede sono realizzate con ESCCAP |
| acvim.org | rosso | termini: niente riproduzione né uso commerciale senza consenso |
| catfriendly.com | rosso | Content-Signal ai-train=no e blocco di ClaudeBot |
| capcvet.org, avma.org, bva.co.uk, anses.fr | rosso | uso non commerciale, solo per soci, oppure CC BY-NC-ND |
| izsler.it, izsvenezie.it | rosso | copia a fini di lucro solo con permesso scritto; contenuti CC BY-NC |
| canada.ca, woah.org, medicines.health.europa.eu, cdc.gov, fda.gov, aphis.usda.gov | rosso | controllo impossibile (blocco, certificato scaduto) o divieto di estrazione e di uso commerciale |
| iss.it, epicentro.iss.it | **verde dopo lettura a mano del documento** (17/11/2026) | CC BY 4.0 «salvo ove diversamente indicato», ma alcune opere non sono riusabili a fini commerciali (il BEN di EpiCentro è CC BY-NC-ND): ammesso solo il singolo documento che porta scritto CC BY su di sé; scarico a mano. Il «rosso» del 15/11 dipendeva dal blocco dei programmi |

## 3. Catalogo B: le 11 fonti oggi usate

Tutte lette per intero il 2026-11-10 o il 2026-11-15, dopo il controllo in 4 punti dell'ente che le ospita, **una alla volta**, con copie di lavoro cancellate. L'elenco completo con titolo, indirizzo, licenza, sponsor, data di controllo è in `data/manuale/fonti.json`.

| Id | Documento | Ente | Anno | Semaforo | Usata in |
|---|---|---|---|---|---|
| wsava_vacc_2024 | Linee guida di vaccinazione di cani e gatti | WSAVA | 2024 | giallo | CAN-SAL-01, GAT-SAL-01 |
| wsava_nutr_2011 | Linee guida di valutazione nutrizionale | WSAVA | 2011 | giallo | CAN-SAL-03 |
| wsava_treats_dog_2025 | Guida per proprietari sui premi (cane) | WSAVA | 2025 | giallo | CAN-SAL-03 |
| wsava_wellness_2025 | Principles of Wellness | WSAVA, con HealthforAnimals | 2025 | giallo | CAN-SAL-02, GAT-SAL-02 |
| wsava_feeding_hospitalized_2013 | Scheda per l'alimentazione di cani e gatti ricoverati | WSAVA | 2013 | giallo | GAT-SAL-03 |
| felinevma_nursing_2024 | Note del webinar sul gatto inappetente ricoverato | FelineVMA (già AAFP) | 2024 | giallo | GAT-SAL-03 |
| aafp_urolithiasis_2022 | Dichiarazione di consenso sui calcoli urinari | AAFP | 2022 | giallo | GAT-SAL-04 |
| felinevma_isfm_housesoiling_2024 | Opuscolo per proprietari sulle lettiere | FelineVMA e ISFM | 2024 | giallo (co-titolarità ISFM da confermare) | GAT-SAL-04 |
| scot_rabbit_2018 | Pet Rabbit Welfare Guidance | Governo scozzese | 2018 | verde (OGL v3.0) | CON-SAL-01, 02, 03, 04 |
| vmd_permethrin_2014 | Permethrin: don't put your cat at risk | Veterinary Medicines Directorate (UK) | 2014 | verde (OGL v3.0) | CAN-SAL-02, GAT-SAL-02 |
| ecdc_tbe_2024 | Factsheet about tick-borne encephalitis | ECDC | 2024 | verde (CC BY 4.0) | CAN-SAL-02 |

Note: la guida scozzese, la guida VMD e la scheda ECDC sono **indicazioni ufficiali di altri paesi o per la salute umana** (Regno Unito, Unione europea): non sono norme italiane; le schede lo dicono nei «Limiti». Le note del webinar FelineVMA sono materiale didattico per i veterinari: se un webinar di una società conta come livello 1 lo decide il proprietario (GAT-SAL-03 poggia soprattutto su questo).

## 4. Fonti lette e poi tolte (e perché)

Le fonti usate nel primo giro (2026-11-10) e non più usate dal 2026-11-15, per la richiesta di usare solo fonti ufficiali di livello 1 e nessuna fonte rossa. Le copie sono state cancellate.

| Fonte | Perché non è più usata |
|---|---|
| ESCCAP GL3 (ectoparassiti) | rosso (termini: niente copie né uso commerciale, permesso scritto per riprodurre) |
| iCatCare, guide per proprietari (gatto che non mangia, vie urinarie) e consenso 2025 sulle basse vie urinarie | rosso (termini: solo uso personale non commerciale; il consenso 2025 è CC BY-NC) |
| AAHA/AAFP Feline Life Stage 2021, ISFM gatto inappetente 2022, Webb 2018, Batchelor 2013, Elwood 2010 | rossi (editori SAGE e Wiley con termini non apribili) o livello 2 |
| DeCubellis 2013, Reusch 2005, Varga 2014 (Elsevier) | rossi (riserva espressa) e di livello 2-3 |
| O'Neill 2025, Jackson 2025, Craciun 2025, Forder 2024, Fenton 2025 (CC BY) | verdi, ma di livello 2 (studi singoli e rassegne): fuori dal mandato di usare solo livello 1 |
| AAHA nutrizione 2021 | per Crossref CC BY-NC-ND (il PDF non lo dice); mai usata come base |
| Schede WSAVA sul punteggio corporeo e muscolare | diritti di terzi e procedura WSAVA: non riprodotte |
| ENOVAT (linee guida europee sulla diarrea del cane) e il riassunto WSAVA che ne deriva | rosse (host bloccato; riassunto derivato da ENOVAT) |
| FECAVA (schede sulle malattie da zecca, 2019-2022) | cautela: i termini vietano di «sfruttare» il contenuto senza consenso scritto; mai usate finché la Normativa non decide |
| IZSLER, IZSVe, Ministero della Salute, EMA, ISS, FDA, CDC, USDA | rossi o bloccati (termini non commerciali, CC BY-NC, controllo impossibile) |

Identificativi di altri lavori sul coniglio scaricati in passato e non letti (solo per memoria, copie cancellate): PMC12861439, PMC11504023, PMC7106034, PMC7129804, PMC12554809, PMC11825090. Prima di riprenderli, il semaforo (§5.1).

## 5. Diritti d'uso: cosa serve dalla Normativa

Domande aperte (non sono mie decisioni; il parere `compliance/13` dice che i punti con ⚖️ vanno confermati da un legale):

1. **Riassunto di fatti da fonti «all rights reserved»** (WSAVA, ESCCAP, AAFP/ISFM, iCatCare, Elsevier): il parere lo ammette con parole nostre e una riga «Fonte». ESCCAP, ABCD, iCatCare e FVE scrivono però «permesso scritto per la riproduzione». Conferma che per un riassunto non serve; se la Normativa preferisce, il permesso si chiede lo stesso (contatti: ESCCAP info@esccap.org, WSAVA admin@wsava.org e modulo, FVE info@fve.org).
2. **Fonti CC BY-NC-ND** (AAHA 2021 secondo Crossref) e **CC BY-NC**: il riassunto di fatti con parole nostre è lecito come per i diritti riservati, o le escludiamo del tutto come per ora?
3. **Copie PubMed Central di articoli Elsevier** con la sola licenza COVID-19 (diritto scaduto con l'emergenza): trattare come diritti riservati (riassunto, nessun testo).
4. **Lettura automatica: nota sull'evento (2026-11-10).** Per scrivere le schede, strumenti automatici (sessioni di aiuto di questa sessione) hanno letto **singoli documenti pubblici**, uno alla volta: i PDF di WSAVA, ESCCAP, iCatCare e AAHA/AAFP, e i testi di articoli presi dall'interfaccia XML di Europe PMC (copie PubMed Central). Non sono stati raccolti interi siti. La riserva dei diritti per l'estrazione di testo e dati (art. 70-quater e 70-septies) **non era stata controllata prima**, come chiede il parere §3. Dai controlli della Normativa (Appendice A.4) risulta che ESCCAP, iCatCare ed Elsevier avevano una riserva espressa nei termini, e che per Wiley e SAGE i termini non erano apribili: le fonti coinvolte sono segnate «rosso» nel catalogo. Effetto sulle schede: tutte restano in bozza; le frasi che poggiano su fonti rosse (84) vanno rilette a mano da una persona (`docs/product/15a_lista_rilettura_a_mano.md`). **Copie cancellate**: le cartelle di scaricamento e i testi estratti (nella cartella temporanea di questa sessione), i file di testo prodotti dagli strumenti nella cartella di sessione di Claude Code; nel repository e nell'archivio della chat ci sono solo metadati e le nostre schede. Il 2026-11-15 tutte le letture sono state fatte solo su fonti verdi o gialle, dopo il controllo in 4 punti. Restano le registrazioni delle sessioni di aiuto (file di sessione dell'applicazione, fuori dal repository), che possono contenere brani letti: la loro cancellazione la decide il proprietario. **Regola nuova** (parere, Appendice A.3): vale il semaforo qui sotto prima di ogni lettura.
5. **Riga «Fonte»**: usata con il formato del parere (ente o autori, titolo, rivista, anno, DOI o indirizzo, «Riassunto di Quokka, verificato il …», e per CC BY «Licenza CC BY; modificato da Quokka»). Si ottiene da `python scripts/manuale/check_manuale.py --righe`.
6. **Diritto sui generis delle banche dati**: nessuna scheda riprende tabelle o elenchi interi; l'archivio che la sessione Chat costruirà contiene le nostre schede, non le fonti.


### 5.1 Il semaforo prima di ogni lettura automatica (dalla Normativa)

| Semaforo | Quando | Cosa si può fare | Fonti oggi |
|---|---|---|---|
| Verde | CC0 o CC BY indicata sulla pagina dell'articolo (Europe PMC: solo il sottoinsieme «uso commerciale consentito») | Lettura automatica, un documento alla volta, con attribuzione | 3: guida scozzese 2018, guida VMD 2014, scheda ECDC 2024 |
| Giallo | Nessuna riserva trovata ma diritti riservati | Prima il controllo in 4 punti (robots.txt, termini, segnali leggibili da macchina, avviso nel PDF) e la registrazione; poi un documento alla volta | 8: cinque documenti WSAVA, due di FelineVMA/AAFP, un opuscolo FelineVMA e ISFM |
| Rosso | Riserva presente, o controllo impossibile (pagina bloccata), o licenza NC/ND | Solo lettura a mano da una persona, o permesso scritto. **Mai il testo incollato in un modello** | 0 usate (tutte le fonti rosse sono state tolte dalle schede il 2026-11-15) |

Per ogni fonte, `data/manuale/fonti.json` ha ora `semaforo`, `riserva_estrazione_automatica` (con la data del controllo, 2026-11-10) e `lettura_eseguita`. Le fonti con licenza NC o ND servono solo a confermare fatti già sostenuti da altre fonti, segnate «solo fatti»: oggi nessuna scheda poggia su di esse (iCatCare 2025 e AAHA 2021 non sono usate).

### 5.2 Cosa ha risposto la Normativa (`compliance/13`, Appendice A)

- **ESCCAP, WSAVA, iCatCare, ABCD, FVE**: il riassunto di fatti, con parole nostre e una riga «Fonte», non richiede permesso; il rischio vero è il «compendio» (frasi e struttura della fonte), e la regola è «si scrive dal concetto, non dalla frase». Per le schede su iCatCare, ESCCAP o FVE la Normativa consiglia di scrivere agli enti (bozza in A.5), a scelta del proprietario.
- **CC BY-NC e ND**: i fatti sì, la forma no; non come base unica; si possono usare per confermare fatti, segnando «solo fatti».
- **Lettura automatica già fatta**: difetto di procedura, rischio sostanziale limitato; le tre fonti Elsevier, Elwood, ESCCAP e iCatCare sono rosse, e le loro frasi vanno rilette a mano (15a).

Il controllo di somiglianza richiesto («nessuna sequenza di 6 o più parole uguali alla fonte») ha un limite: le fonti sono in inglese e le schede in italiano, quindi una sequenza di parole uguali non può esistere; il rischio vero è la **traduzione ravvicinata** (stesso ordine delle clausole e degli elenchi). Questo si controlla leggendo la fonte: per le fonti verdi e gialle l'ho fatto con un quarto giro (§7.1); per le rosse è nella lista di rilettura a mano.

## 6. Cosa manca e come sbloccarlo

| Lacuna | Perché | Come |
|---|---|---|
| Cane: vomito e diarrea | Nessun documento ufficiale su fonti consentite (WSAVA, FECAVA, ACVIM): l'unica linea guida (ENOVAT) è bloccata e il riassunto WSAVA ne deriva | Se il proprietario apre ENOVAT (CC BY) in un browser normale e decide che una linea guida pubblicata da un gruppo di esperti conta come livello 1, la scheda si ricostruisce |
| Vaccini del coniglio per l'Italia (età della prima dose, richiami, prodotti che coprono RHDV2) | Il testo europeo del prodotto (EMA), il Ministero e gli IZS sono rossi o bloccati; resta la guida britannica | Il proprietario apre ema.europa.eu (scheda europea del vaccino) e salute.gov.it in un browser normale, o si chiede il foglietto illustrativo italiano |
| Cane: perdita di peso e appetito | Nessuna fonte ufficiale consentita (solo la linea guida WSAVA 2011, già nella scheda del peso) | Il testo AAHA 2023 sulla cura dell'anziano, se il proprietario lo apre |
| Gatto: vomito | Nessun documento ufficiale consentito | Le linee guida ISFM sono rosse; servirebbe un'altra società |
| Pulci e zecche: segni dell'allergia, anemia, tenia, come togliere una zecca | Le fonti ufficiali consentite non lo dicono (ESCCAP e FECAVA sono rosse o cautelative) | Chiedere il permesso a ESCCAP o attendere il parere sulle schede FECAVA |
| Gatto maschio che fatica a urinare = urgenza | Nessuna fonte consentita lo dice per intero | Rimane un consiglio nostro segnato come tale; le urgenze restano ai passi già approvati |
| Quartili delle riviste | Le schede non usano più riviste (§1.1) | Non serve più |
| Rinnovo dei permessi | Vedi §5 | Normativa |

## 7. Le 11 schede

File: `data/manuale/<specie>/<CODICE>.json`; fonti: `data/manuale/fonti.json`; controllo: `python scripts/manuale/check_manuale.py`.

Colonne «tenute / sostituite / tolte»: rispetto alla versione del 2026-11-10; «sostituite» = informazione mantenuta ma ora presa da una fonte ufficiale consentita; «tolte» = frasi senza una fonte ufficiale consentita, eliminate.

| Codice | Titolo | Fonti | Tenute / sostituite / tolte | Resta da rileggere a mano |
|---|---|---|---|---|
| CAN-SAL-01 | I vaccini del cane | WSAVA 2024 | 16 / 0 / 0 | niente |
| CAN-SAL-02 | Pulci e zecche nel cane | WSAVA 2025, VMD, ECDC | 0 / 9 / 5 | niente |
| CAN-SAL-03 | Peso e forma del corpo del cane | WSAVA 2011, guida premi | 13 / 0 / 0 | niente |
| CAN-SAL-04 | vomito e diarrea del cane | - | **scheda tolta** (14 frasi senza fonte consentita) | - |
| GAT-SAL-01 | I vaccini del gatto | WSAVA 2024 | 12 / 0 / 0 | niente |
| GAT-SAL-02 | Pulci e zecche nel gatto | VMD, WSAVA 2025 | 0 / 8 / 2 | niente |
| GAT-SAL-03 | Il gatto mangia poco | WSAVA 2013, note FelineVMA | 0 / 7 / 7 | niente (decisione: un webinar è livello 1?) |
| GAT-SAL-04 | Il gatto sporca fuori dalla lettiera | AAFP 2022, opuscolo FelineVMA/ISFM | 0 / 9 / 2 | niente (conferma co-titolarità ISFM) |
| CON-SAL-01 | Il coniglio mangia meno | guida scozzese | 0 / 10 / 3 | niente |
| CON-SAL-02 | I denti del coniglio | guida scozzese | 0 / 12 / 2 | niente |
| CON-SAL-03 | Il coniglio nasconde il dolore | guida scozzese | 0 / 3 / 3 | niente |
| CON-SAL-04 | I vaccini del coniglio (nuova) | guida scozzese | scheda nuova, 5 frasi | niente |

Cosa serve prima di chiamarle «rivedute»: la lettura del proprietario; la decisione della Normativa su §5 e sulle due cautele (FECAVA e co-titolarità ISFM).

### 7.1 Cosa ha trovato il controllo (e cosa ne ho tratto)

**Giro del 15 novembre (solo fonti ufficiali).** Dopo la ricostruzione, tre sessioni indipendenti hanno controllato di nuovo le schede riscritte contro il testo delle fonti (verdi e gialle, un documento alla volta): coniglio (46 frasi: nessuna non sostenuta, 18 in parte, 4 troppo vicine), pulci e zecche (22: 11 in parte, 12 troppo vicine), gatto (17: 12 in parte, 6 troppo vicine). Gli errori erano di tre tipi: **pagine sbagliate** (per esempio l'avviso di licenza non ha un numero di pagina), **cautele perse** («è una buona idea» diventato «va fatto»; «idealmente» diventato un fatto), **ambito sbagliato** (dati del nord Europa letti come nord Italia; guide per ricoverati lette come consigli al proprietario). Ho corretto tutto; le correzioni di questo giro non hanno avuto un altro controllo indipendente.

Primo giro: 146 frasi (53 corrette, 62 in parte, 29 traduzioni troppo vicine, 2 non sostenute). Secondo giro, dopo la riscrittura: 136 frasi con fonte (90 corrette, 34 in parte, 12 ancora vicine, 0 non sostenute). Quarto giro (dopo la regola del semaforo, solo sulle 54 frasi che poggiano su fonti verdi o gialle: WSAVA e articoli CC BY, un documento alla volta, copie cancellate): 45 corrette e 8 in parte, 0 non sostenute; 8 traduzioni ancora troppo vicine alla fonte, che ho riscritto dal concetto, e alcune cautele e perimetri da precisare, che ho corretto (per esempio: «ogni 3 anni» vale per i vaccini vivi attenuati; «uva e xilitolo» mancavano dall'elenco dei cibi tossici). Per le frasi su fonti rosse il quarto giro non si può fare da parte mia (regola del semaforo): sono nella lista di rilettura a mano. Le correzioni successive (cautele ripristinate, riferimenti di pagina, frasi riformulate) sono state applicate ma **non** ricontrollate: restano `bozza` fino alla lettura del proprietario. Il controllo non sostituisce la sua lettura: una fonte può essere letta male da due sessioni di seguito.

| Tipo di problema | Esempio reale | Regola che ne è uscita |
|---|---|---|
| Cifra riferita alla popolazione sbagliata | «2.219 conigli visitati: 51,2% deceduti» (erano 2.219 conigli già con malattia dentale; il 51,2% riguarda i 547 morti); «500 proprietari» per percentuali che vengono da 345 che hanno valutato dei video | ogni cifra porta il suo campione nella frase |
| Cautela persa | «ogni 3 anni per tutti gli essenziali» (vale per i vaccini vivi attenuati); «punteggio sopra 6 aumenta il rischio» (le prove sono limitate) | si tengono «sembra», «per alcuni», «in molti casi» |
| Regola da veterinario letta come regola da proprietario | la ricontrollo entro 48 ore del vomito; i «3 giorni» per la sonda nel gatto ricoverato; la regola 3-2-1 per la biopsia delle masse | si scrive «per i veterinari» e il consiglio al proprietario è segnato «nostro» |
| Consiglio nostro scritto come fatto della fonte | «non togliere il cibo al gatto che vomita» (la fonte dice che il digiuno di 24-48 ore è la pratica più usata) | i consigli nostri sono segnati `"nostro": true`, mostrati come «Consiglio di Quokka (non della fonte)», al massimo 3 per scheda |
| Traduzione troppo vicina | elenchi di segni nello stesso ordine di una tabella della fonte | si raggruppa per tema con parole nostre (richiesta dalla Normativa) |
| Riferimento sbagliato | «pag. 16» per il cortisone (è la malattia di Lyme); una sezione che non esiste | il «punto» si controlla sul testo, non sull'estratto |
| Errore di senso | «più spesso per i conigli a rischio»: la fonte dice più a lungo tra un controllo e l'altro | confronto frase per frase da una seconda sessione prima di ogni scheda |

## 8. Il formato per la sessione Chat LLM

**File pronto per l'importazione**: `data/manuale/health_cards.json` (un elenco di oggetti), generato dalle schede con `python scripts/manuale/check_manuale.py --esporta`. Ogni oggetto ha i campi chiesti dalla sessione Chat per `health_cards.sql`:

| Campo | Contenuto |
|---|---|
| `id` | codice in minuscolo, per esempio `can-sal-01` |
| `species` | `dog`, `cat`, `rabbit` |
| `topic` | argomento (`vaccini`, `pulci-zecche`, `peso-corporatura`, `vomito-diarrea`, `non-mangia-vomito`, `lettiera-urine`, `non-mangia`, `denti`, `malessere-nascosto`) |
| `title` | titolo |
| `body` | testo in sezioni («In breve», «Cosa sapere», «Cosa osservare», «Cosa non fare», «Quando andare dal veterinario», «Limiti di questa scheda»), una riga per frase; i consigli nostri iniziano con «Consiglio di Quokka (non della fonte):». Massimo 4.000 caratteri: oggi tra 1.500 e 3.500 |
| `source` | citazioni leggibili (ente o autori, titolo, rivista, anno, collegamento, «Riassunto di Quokka, verificato il …», e per CC BY «Licenza CC BY; modificato da Quokka») |
| `source_level` | il livello peggiore tra le fonti usate (1, 2 o 3) |
| `state` | `draft` finché il proprietario non approva (poi `approved`) |

Le citazioni [S1]..[S3] e la riga «Fonte» nella risposta le aggiunge la chat. Il file va rigenerato a ogni modifica delle schede; non si modifica a mano.

**Formato di lavoro** (da cui si genera): una scheda = un file JSON in `data/manuale/<specie>/`. Campi:

- `codice`, `specie`, `area` (SAL...), `argomento` (slug), `titolo`;
- `stato` (`bozza`, `fonti_controllate`, `rivista`, `pubblicata`): **nell'archivio entrano solo `rivista` e `pubblicata`**; le bozze solo in prova;
- `livello_schede` (il peggiore tra i livelli delle fonti usate), `ultimo_controllo`, `scadenza` (12 mesi), `revisione.proprietario` (data);
- `blocchi[]`: `in_breve`, `cosa_sapere`, `cosa_osservare`, `cosa_non_fare`, `quando_andare_dal_veterinario`, `limiti`; ogni `frasi[]` ha `testo` e `fonti[]` = `{id, punto}`, oppure `"nostro": true` per un consiglio di Quokka senza fonte (al massimo 3 per scheda);
- `riassunto_per_chat` (max 1.600 caratteri, quasi un pezzo da 250 parole): cosa la chat può usare e citare;
- `parole_chiave` per la ricerca per specie e argomento;
- `fonti.json`: per ogni `id`, ente, titolo, anno, DOI o indirizzo, livello, diritti, sponsor, `controllata_il`, come è stata aperta.

Regole per la chat (da concordare con la sessione Chat LLM):
1. per le domande di salute la risposta usa **solo** le schede trovate (stessa specie e argomento) e una riga «Fonte» (dalla riga generata) e l'attribuzione CC BY se la scheda ne usa;
2. se una scheda è `bozza` o `scadenza` è passata, non si usa;
3. il blocco `limiti` dice cosa non coprire; la chat non lo completa con conoscenze del modello;
4. le urgenze restano ai passi fissi già approvati: le schede non li sostituiscono.
