# 15 - Catalogo delle fonti approvate e prime schede di salute

Data: 2026-11-10. Sessione "Manuale" su richiesta dell'Orchestratore. Parte dal piano `docs/product/13` §2 e dal parere della Normativa `docs/compliance/13_parere_fonti_scientifiche_e_diritto_d_autore.md`; serve alla chat (`docs/product/14_analisi_manifesto_rag.md`). **Prima versione**: nessuna scheda è ancora "rivista" dal proprietario, e nulla è pubblicato.

## 0. In breve

- **Catalogo**: 3 livelli di fonti, con le regole per riviste, diritti d'uso, data di controllo. Una prima lista di **enti e società** (con dove hanno pubblicato, che cosa dicono sul riuso, chi li finanzia) e un elenco di **19 documenti letti per intero** che reggono le prime schede.
- **Prime schede**: 11 di salute non urgente (`data/manuale/`): cane 4, gatto 4, coniglio 3. Ogni frase ha la sua fonte e il punto esatto; il livello è nel file. Tutte in stato `bozza`: manca la revisione del proprietario.
- **Cosa non c'è**: coniglio vaccinazioni (nessuna fonte europea ufficiale apribile), cane perdita di peso (nessuna fonte adeguata), linea guida europea sulla diarrea (non apribile). Dirlo è parte del risultato: per questi temi la chat segue il percorso sicuro, non inventa.
- **Controllo**: ogni scheda è stata scritta da testo letto e poi riletta da una sessione indipendente, frase per frase, a confronto con il testo della fonte. Il primo giro su 146 frasi ha dato: 53 corrette, 62 in parte (cifre riferite alla popolazione sbagliata, cautele perse, riferimenti di pagina sbagliati), 29 traduzioni troppo vicine alla fonte, 2 non sostenute. Ho riscritto tutte le schede e le ho fatte ricontrollare: il secondo giro ha trovato molto meno (136 frasi con fonte: 90 corrette, 34 in parte, 12 ancora troppo vicine alla fonte, 0 non sostenute, quasi tutte cautele perse o riferimenti da precisare); ho corretto anche quelle, ma le correzioni finali non hanno avuto un terzo controllo (§7.1). Il controllo automatico `python scripts/manuale/check_manuale.py` passa: nessuna frase senza fonte (salvo i consigli segnati «nostro»), nessuna fonte senza anno e data, nessuna parola vietata, nessuna dose.
- **Archivio della chat**: `python scripts/manuale/check_manuale.py --esporta` scrive `data/manuale/health_cards.json` nel formato chiesto (id, species, topic, title, body max 4000, source, source_level, state `draft`). Vedi §8.

## 1. Le regole di classificazione

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
| **Ministero della Salute** | 1 | **bloccato** (verifica anti-robot); aperto il portale dei dati aperti dati.salute.gov.it | non verificato dal sito principale | Il portale dati: licenza IODL 2.0 (riuso libero). Per i testi di atti ufficiali: art. 5 legge 633/1941 (la legge sul diritto d'autore non si applica ai testi degli atti ufficiali) e D.Lgs. 36/2006 (riuso dell'informazione pubblica, a fini commerciali e no), da leggere con la Normativa | n.a. |
| **IZS** (Istituti Zooprofilattici) | 1 | izsler.it, izsvenezie.it (aperte singole pagine e PDF) | Schede sulla mixomatosi e la malattia emorragica virale del coniglio (2021); pagina IZSVe sulla variante Toledo (2026) | Nessuna riga di licenza | n.a. |
| **EFSA** | 1 | una pagina aperta; **avvertenza legale bloccata** (429) | Poco sugli animali da compagnia | non verificato | n.a. |
| **EMA** (medicinali veterinari) | 1 | **bloccato** oltre la pagina iniziale (503) | non verificato | non verificato | n.a. |

Conclusione trasversale: **nessuno** degli enti esaminati pubblica le proprie linee guida con una licenza aperta. Per ESCCAP, ABCD, iCatCare e FVE il testo parla esplicitamente di permesso scritto per la riproduzione; WSAVA ha una procedura e un modulo. Il parere della Normativa permette il riassunto di fatti con parole nostre; i permessi servono per copiare, non per riassumere (ma vedi §5).

## 3. Catalogo B: i 19 documenti letti per le prime schede

Tutti aperti **per intero** il 2026-11-10 (testo completo letto; l'elenco completo con titolo, rivista, volume, DOI, indirizzo, licenza, sponsor, data di controllo è in `data/manuale/fonti.json`).

| Id | Documento | Livello | Specie | Diritti | Usata in |
|---|---|---|---|---|---|
| wsava_vacc_2024 | WSAVA, vaccinazione di cani e gatti, 2024 | 1 | cane, gatto | riservati; licenza CC non stabilita | CAN-SAL-01, GAT-SAL-01 |
| esccap_gl3_2022 | ESCCAP GL3, ectoparassiti, 7ª ed. 2022 | 1 | cane, gatto | riservati; permesso per riprodurre | CAN-SAL-02, GAT-SAL-02 |
| wsava_nutr_2011 | WSAVA, valutazione nutrizionale, 2011 | 1 | cane, gatto | riservati; procedura WSAVA | CAN-SAL-03 |
| wsava_treats_dog_2025 | WSAVA, guida per proprietari «Feeding treats», 2025 | 1 | cane | riservati | CAN-SAL-03 |
| aaha_feline_lifestage_2021 | AAHA/AAFP, fasi di vita del gatto, 2021 | 1 | gatto | riservati | GAT-SAL-04 |
| isfm_inappetent_2022 | ISFM, gatto inappetente (ricoverato), 2022 | 1 | gatto | riservati | GAT-SAL-03 |
| icatcare_wont_eat_2022 | iCatCare, guida per proprietari: gatto che non mangia, 2022 | 1 | gatto | riservati | GAT-SAL-03 |
| icatcare_urinary_2025 | iCatCare, guida per proprietari: vie urinarie, 2025 | 1 | gatto | riservati | GAT-SAL-04 |
| webb_hl_2018 | Webb, lipidosi epatica, JFMS 2018 | 2A | gatto | riservati | GAT-SAL-03 |
| batchelor_vomit_2013 | Batchelor et al., vomito nel gatto, JFMS 2013 (finanziata da Pfizer) | 2A | gatto | riservati | GAT-SAL-03 |
| elwood_emesis_2010 | Elwood et al., vomito nel cane, JSAP 2010 (Pfizer) | 2A | cane | riservati | CAN-SAL-04 |
| oneill_diarrhoea_2025 | O'Neill et al., diarrea acuta nel cane, PLoS ONE 2025 | 2B | cane | **CC BY 4.0** | CAN-SAL-04 |
| vetrec_dental_2025 | Jackson et al., denti del coniglio, Vet Rec 2025 | 2A | coniglio | **CC BY 4.0** | CON-SAL-01, 02, 03 |
| animals_odontogenic_2025 | Craciun e Nadas, ascessi dentali, Animals 2025 | 2B | coniglio | **CC BY** | CON-SAL-02 |
| vcna_gi_2013 | DeCubellis e Graham, malattie gastrointestinali, VCNA Exot 2013 | 2A | coniglio, cavia | riservati (Elsevier) | CON-SAL-01, 02 |
| vcna_gastro_2005 | Reusch, gastroenterologia del coniglio, VCNA Exot 2005 (vecchia) | 2A | coniglio | riservati | CON-SAL-01, 02 |
| varga_digestive_2014 | Varga, disturbi digestivi, Textbook of Rabbit Medicine 2014 | 3 | coniglio | riservati | CON-SAL-01 |
| bmcvr_pain_2024 | Forder et al., dolore nel coniglio, BMC Vet Res 2024 | 2A | coniglio | **CC BY 4.0** | CON-SAL-03 |
| animals_welfare_2025 | Fenton et al., problemi di benessere dei piccoli mammiferi, Animals 2025 | 2B | coniglio, cavia, criceto | **CC BY** | CON-SAL-03 |

## 4. Fonti lette ma non usate (e perché)

| Fonte | Perché non è usata come base |
|---|---|
| iCatCare, consenso 2025 sulle basse vie urinarie (JFMS) | Licenza CC BY-NC 4.0 (vieta l'uso commerciale): la scheda poggia sulla guida per proprietari e sulle linee guida AAHA/AAFP |
| AAHA, nutrizione e controllo del peso 2021 | Letta per intero; il PDF stampa solo «© AAHA» ma Crossref la dà come CC BY-NC-ND 4.0: in attesa che la Normativa dica se per un riassunto di fatti basta; i fatti usati nella scheda del peso stanno anche nei testi WSAVA |
| Rassegna 2026 su sarcopenia e cachessia del gatto (JFMS, CC BY-NC); studio 2026 sulla gravità dentale del coniglio (J Vet Dent, CC BY-NC) | Licenza NC |
| Schede WSAVA sul punteggio corporeo e muscolare | Diritti di terzi e procedura WSAVA: non si riproducono; la scheda del peso non le copia |
| ESCCAP GL1 (vermi) | Letta solo nei passaggi chiave: non basta per una scheda sui vermi |
| Foglio illustrativo britannico di Nobivac Myxo-RHD PLUS | È l'autorizzazione per la Gran Bretagna, non per l'UE; le pagine EMA con il testo europeo sono bloccate. Nessuna scheda sul vaccino del coniglio finché non si apre il testo UE o italiano |
| Documenti IZS e Ministero 2011-2026 sul coniglio | Riguardano soprattutto i conigli da allevamento; nessuno dà un calendario per i conigli da compagnia; la pagina del Ministero è bloccata |
| Altri 9 lavori sul coniglio scaricati e non letti | Le copie sono state cancellate. Identificativi PubMed Central dei candidati, per una seconda tornata: PMC12861439 (rassegna sulla malattia emorragica virale, 2025), PMC11504023 (conigli da compagnia vaccinati contro RHDV2, 2024), PMC7106034 (malattie digestive dei piccoli mammiferi esotici, 2013), PMC7129804 (coniglio anziano, 2010), PMC12554809 (obesità), PMC11825090 (pesi standard). Prima di riprenderli, il semaforo (§5.1) |

## 5. Diritti d'uso: cosa serve dalla Normativa

Domande aperte (non sono mie decisioni; il parere `compliance/13` dice che i punti con ⚖️ vanno confermati da un legale):

1. **Riassunto di fatti da fonti «all rights reserved»** (WSAVA, ESCCAP, AAFP/ISFM, iCatCare, Elsevier): il parere lo ammette con parole nostre e una riga «Fonte». ESCCAP, ABCD, iCatCare e FVE scrivono però «permesso scritto per la riproduzione». Conferma che per un riassunto non serve; se la Normativa preferisce, il permesso si chiede lo stesso (contatti: ESCCAP info@esccap.org, WSAVA admin@wsava.org e modulo, FVE info@fve.org).
2. **Fonti CC BY-NC-ND** (AAHA 2021 secondo Crossref) e **CC BY-NC**: il riassunto di fatti con parole nostre è lecito come per i diritti riservati, o le escludiamo del tutto come per ora?
3. **Copie PubMed Central di articoli Elsevier** con la sola licenza COVID-19 (diritto scaduto con l'emergenza): trattare come diritti riservati (riassunto, nessun testo).
4. **Lettura automatica: nota sull'evento (2026-11-10).** Per scrivere le schede, strumenti automatici (sessioni di aiuto di questa sessione) hanno letto **singoli documenti pubblici**, uno alla volta: i PDF di WSAVA, ESCCAP, iCatCare e AAHA/AAFP, e i testi di articoli presi dall'interfaccia XML di Europe PMC (copie PubMed Central). Non sono stati raccolti interi siti. La riserva dei diritti per l'estrazione di testo e dati (art. 70-quater e 70-septies) **non era stata controllata prima**, come chiede il parere §3. Dai controlli della Normativa (Appendice A.4) risulta che ESCCAP, iCatCare ed Elsevier avevano una riserva espressa nei termini, e che per Wiley e SAGE i termini non erano apribili: le fonti coinvolte sono segnate «rosso» nel catalogo. Effetto sulle schede: tutte restano in bozza; le frasi che poggiano su fonti rosse (84) vanno rilette a mano da una persona (`docs/product/15a_lista_rilettura_a_mano.md`). **Copie cancellate**: le cartelle di scaricamento e i testi estratti (nella cartella temporanea di questa sessione), i file di testo prodotti dagli strumenti nella cartella di sessione di Claude Code; nel repository e nell'archivio della chat ci sono solo metadati e le nostre schede. Restano le registrazioni delle sessioni di aiuto (file di sessione dell'applicazione, fuori dal repository), che possono contenere brani letti: la loro cancellazione la decide il proprietario. **Regola nuova** (parere, Appendice A.3): vale il semaforo qui sotto prima di ogni lettura.
5. **Riga «Fonte»**: usata con il formato del parere (ente o autori, titolo, rivista, anno, DOI o indirizzo, «Riassunto di Quokka, verificato il …», e per CC BY «Licenza CC BY; modificato da Quokka»). Si ottiene da `python scripts/manuale/check_manuale.py --righe`.
6. **Diritto sui generis delle banche dati**: nessuna scheda riprende tabelle o elenchi interi; l'archivio che la sessione Chat costruirà contiene le nostre schede, non le fonti.


### 5.1 Il semaforo prima di ogni lettura automatica (dalla Normativa)

| Semaforo | Quando | Cosa si può fare | Fonti oggi |
|---|---|---|---|
| Verde | CC0 o CC BY indicata sulla pagina dell'articolo (Europe PMC: solo il sottoinsieme «uso commerciale consentito») | Lettura automatica, un documento alla volta, con attribuzione | 5: O'Neill 2025, Jackson 2025, Craciun 2025, Forder 2024, Fenton 2025 |
| Giallo | Nessuna riserva trovata ma diritti riservati | Prima il controllo in 4 punti (robots.txt, termini, segnali leggibili da macchina, avviso nel PDF) e la registrazione; poi un documento alla volta | 3: WSAVA (vaccini 2024, nutrizione 2011, guida premi 2025) |
| Rosso | Riserva presente, o controllo impossibile (pagina bloccata), o licenza NC/ND | Solo lettura a mano da una persona, o permesso scritto. **Mai il testo incollato in un modello** | 11: ESCCAP GL3, iCatCare (2), Elsevier (3), AAHA/AAFP, ISFM, Webb, Batchelor (editore SAGE, termini non apribili), Elwood (Wiley, termini non apribili) |

Per ogni fonte, `data/manuale/fonti.json` ha ora `semaforo`, `riserva_estrazione_automatica` (con la data del controllo, 2026-11-10) e `lettura_eseguita`. Le fonti con licenza NC o ND servono solo a confermare fatti già sostenuti da altre fonti, segnate «solo fatti»: oggi nessuna scheda poggia su di esse (iCatCare 2025 e AAHA 2021 non sono usate).

### 5.2 Cosa ha risposto la Normativa (`compliance/13`, Appendice A)

- **ESCCAP, WSAVA, iCatCare, ABCD, FVE**: il riassunto di fatti, con parole nostre e una riga «Fonte», non richiede permesso; il rischio vero è il «compendio» (frasi e struttura della fonte), e la regola è «si scrive dal concetto, non dalla frase». Per le schede su iCatCare, ESCCAP o FVE la Normativa consiglia di scrivere agli enti (bozza in A.5), a scelta del proprietario.
- **CC BY-NC e ND**: i fatti sì, la forma no; non come base unica; si possono usare per confermare fatti, segnando «solo fatti».
- **Lettura automatica già fatta**: difetto di procedura, rischio sostanziale limitato; le tre fonti Elsevier, Elwood, ESCCAP e iCatCare sono rosse, e le loro frasi vanno rilette a mano (15a).

Il controllo di somiglianza richiesto («nessuna sequenza di 6 o più parole uguali alla fonte») ha un limite: le fonti sono in inglese e le schede in italiano, quindi una sequenza di parole uguali non può esistere; il rischio vero è la **traduzione ravvicinata** (stesso ordine delle clausole e degli elenchi). Questo si controlla leggendo la fonte: per le fonti verdi e gialle l'ho fatto con un quarto giro (§7.1); per le rosse è nella lista di rilettura a mano.

## 6. Cosa manca e come sbloccarlo

| Lacuna | Perché | Come |
|---|---|---|
| Vaccinazione del coniglio (mixomatosi, MEV/RHD) | Testo europeo del prodotto non apribile (EMA 503); Ministero e IZS senza calendario per i conigli da compagnia; due intervalli in disaccordo nelle fonti (annuale per il prodotto nuovo, due volte l'anno per il vecchio vaccino vivo) | Il proprietario apre ema.europa.eu (scheda europea del vaccino) e salute.gov.it in un browser normale e mi manda il testo, oppure si chiede il foglietto illustrativo italiano al produttore |
| Cane: perdita di peso e appetito | Nessuna fonte adeguata aperta; il testo AAHA 2023 sulla cura dell'anziano è bloccato | Aprire il testo AAHA in un browser; oppure chiedere un testo di una società europea |
| Cane: diarrea, segni d'allarme | La linea guida europea ENOVAT (Vet J 2024, CC BY) è dietro verifica anti-robot; la scheda poggia su una rassegna del 2010 e su uno studio 2025 | Scaricare il PDF in un browser normale; è CC BY e si può adattare |
| Gatto anziano: dolore e perdita di peso | Fonti buone (cura del gatto anziano AAFP 2021, guida iCatCare sul dolore) già lette ma non ancora scritte | Prossima scheda |
| Gatto: linee guida ABCD | Non lette | Prossima tornata |
| Quartili delle riviste | Vedi §1.1 | Una persona su SCImago/JCR |
| Rinnovo dei permessi | Vedi §5 | Normativa |

## 7. Le 11 schede

File: `data/manuale/<specie>/<CODICE>.json`; fonti: `data/manuale/fonti.json`; controllo: `python scripts/manuale/check_manuale.py`.

| Codice | Titolo | Livello | Fonti principali | Stato |
|---|---|---|---|---|
| CAN-SAL-01 | I vaccini del cane | 1 | WSAVA 2024 | bozza |
| CAN-SAL-02 | Pulci e zecche nel cane | 1 | ESCCAP GL3 2022 | bozza |
| CAN-SAL-03 | Peso e forma del corpo del cane | 1 | WSAVA 2011, guida premi 2025 | bozza |
| CAN-SAL-04 | Il cane vomita o ha la diarrea | 2 | Elwood 2010, O'Neill 2025 | bozza, fonti deboli (§6) |
| GAT-SAL-01 | I vaccini del gatto | 1 | WSAVA 2024 | bozza |
| GAT-SAL-02 | Pulci e zecche nel gatto: i prodotti del cane | 1 | ESCCAP GL3 2022 | bozza |
| GAT-SAL-03 | Il gatto mangia meno o vomita | 2 | ISFM 2022, guida iCatCare, Webb 2018, Batchelor 2013 | bozza |
| GAT-SAL-04 | Il gatto sporca fuori dalla lettiera o fatica a fare pipì | 1 | guida iCatCare 2025, AAHA/AAFP 2021 | bozza |
| CON-SAL-01 | Il coniglio mangia meno o fa meno palline | 3 | Varga 2014, DeCubellis 2013, Vet Rec 2025 | bozza, senza linea guida di società |
| CON-SAL-02 | I denti del coniglio | 2 | Vet Rec 2025, Craciun 2025, DeCubellis 2013 | bozza, senza linea guida di società |
| CON-SAL-03 | Il coniglio nasconde il dolore | 2 | BMC Vet Res 2024, Animals 2025 | bozza |

Cosa serve prima di chiamarle «rivedute»: la lettura del proprietario; la revisione dei punti segnati §6; la decisione della Normativa su §5. Le scelte che ho fatto per prudenza e che il proprietario può correggere:
- ho scritto in «limiti» di ogni scheda cosa la fonte non dice e il consiglio ovvio di rivolgersi al veterinario (è un consiglio nostro, non della fonte);
- nelle schede del cane e del gatto sul vomito e sul non mangiare ho tenuto la soglia **«circa tre giorni»** del gatto come la dicono le fonti, non le 24-48 ore che si sente dire: nessuna fonte letta le dà;
- ho evitato le parole: corso, formazione, lezione, attestato, certificato, patentino, esame, promozione, «veterinario virtuale».

### 7.1 Cosa ha trovato il controllo (e cosa ne ho tratto)

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
