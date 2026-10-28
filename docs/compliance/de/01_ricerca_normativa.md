> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**

# Germania — ricerca normativa per VetApp (e quadro UE comune a DE/AT)

Sessione: Legale DE. Data di consultazione di tutte le fonti: **2026-10-14**. Lingua dei testi destinati agli utenti: tedesco (Sie-Form), `de-DE`. Documenti interni in italiano. Cartelle sorelle: `../at/` (Austria) e `../ch/` (Svizzera, non UE): questo file contiene anche le **parti UE comuni** (GDPR, AI Act, DSA, direttive consumatori) che `at/01` richiama senza ripetere.

## Come leggere questo documento

- **Affidabilità.** *Primaria* = testo di legge o sito dell'autorità/ente (gesetze-im-internet.de, digital-strategy.ec.europa.eu, bundestieraerztekammer.de). *Secondaria* = studi legali, camere di commercio, stampa di settore, blog. Le fonti secondarie vanno riverificate da un avvocato sulla fonte primaria. Dove ho letto solo un riassunto, lo scrivo.
- **Marcatori.** ✅ letto su fonte primaria · 🟡 solo fonte secondaria o parziale · ❓ non verificato / incerto · ⚖️ da decidere con l'avvocato.
- **Nessuna norma inventata.** Le norme che conosco ma non ho riletto in questa sessione sono segnate «(conoscenza generale, da verificare)» e valgono 🟡 al massimo. Ho trovato che alcune pagine di gesetze-im-internet.de non riportano la data di aggiornamento («Stand»): in quel caso non la indico.
- Premessa di fatto: il titolare è **italiano** (persona o società, dati ancora segnaposto) e quindi **stabilito nell'UE**. Conseguenze: nessun rappresentante ex art. 27 GDPR per DE/AT; autorità capofila probabilmente il **Garante italiano** (art. 56 GDPR, one-stop-shop; 🟡 conoscenza generale), mentre l'utente tedesco può reclamare presso l'autorità del proprio Land (art. 77 GDPR; 🟡 fonte: Landesbeauftragte BW, «Merkblatt Zuständigkeit»).

## 0. Quadro in una pagina

| Tema | Cosa serve a VetApp in Germania | Priorità |
|---|---|---|
| DSGVO + BDSG | Informativa tedesca (doc 02), basi giuridiche, trasferimento verso USA (Groq), diritti, reclamo; DPIA consigliata | Alta |
| TDDDG § 25 | Consenso per memorizzare/leggere info sul dispositivo se non strettamente necessarie (anche in app) | Media |
| Impressum (§ 5 DDG) | Pagina/voce «Impressum» sempre raggiungibile in app e nello store | Alta |
| Preisangabenverordnung (PAngV) | Prezzi dei piani Plus/Pro finali, IVA inclusa | Media |
| Fernabsatz / Widerruf | 14 giorni, perdita anticipata del diritto per servizi/contenuti digitali, **Widerrufsbutton dal 19/06/2026** | Alta |
| Button-Lösung / Kündigungsbutton | «zahlungspflichtig bestellen»; pulsanti di disdetta se l'abbonamento si conclude sul sito/web app | Alta |
| Verbraucherverträge über digitale Produkte (§§ 327 ff. BGB) | Garanzia, aggiornamenti, modifiche del servizio | Media |
| AI Act art. 50 | Dichiarare che si parla con un'IA, **in vigore dal 02/08/2026** | Alta |
| Diritto veterinario | Niente diagnosi finale né prescrizioni; l'app resta su informazioni generali e triage | Alta |
| Tierschutz / Mercatino | Vendita di animali: **vietata in tutti i paesi** (decisione del proprietario, 2026-10-26) | Alta |
| Jugendschutz / età | 18+; capacità negoziale dei minori (§§ 104 ss. BGB) | Media |
| BFSG (accessibilità) | Obbligo per servizi B2C online salvo microimprese | Media ⚖️ |
| Store | Dati del «trader» (DSA), cancellazione account, schede privacy | Media |

## 1. DSGVO e BDSG

- ✅/🟡 Il GDPR (Reg. UE 2016/679) vale per il titolare italiano che tratta dati di utenti in Germania. Nessuna norma tedesca mi risulta che sostituisca la base giuridica; il BDSG integra (p. es. §§ 26, 38). Testo del BDSG non riletto in questa sessione: **(conoscenza generale, da verificare)**.
- 🟡 **Età per il consenso:** in Germania l'art. 8 GDPR resta a **16 anni** (nessuna riduzione nazionale; conoscenza generale). Il servizio è 18+, quindi non è il tema; lo è la capacità negoziale (§ 5).
- 🟡 **Responsabile della protezione dei dati (DPO):** § 38 BDSG impone un DPO se ≥ 20 persone si occupano stabilmente di trattamenti automatizzati (conoscenza generale, da verificare). Per un titolare italiano varrà il diritto italiano/art. 37 GDPR ⚖️.
- 🟡 **Autorità:** in Germania le autorità sono 16+ (una per Land, Baviera divisa per pubblico/privato) più il BfDI. Fonte: [Landesbeauftragter BW – Merkblatt Zuständigkeit](https://www.baden-wuerttemberg.datenschutz.de/wp-content/uploads/2020/07/Merkblatt-Hinweise-zur-datenschutzrechtlichen-Zuständigkeit-3.-Aufl.-Juli-2020.pdf) (luglio 2020, può essere superata). Nell'informativa basta indicare che l'utente può reclamare presso «l'autorità di controllo del suo Land» e il Garante.
- **DPIA:** raccomandata (geolocalizzazione continua nelle passeggiate, IA, dati di salute che l'utente può caricare); stessa analisi serve per l'Italia (art. 35 GDPR).

### Trasferimenti verso gli USA (Groq, fornitore IA)

- 🟡 La Commissione ha adottato la decisione di adeguatezza UE–USA (Data Privacy Framework) nel luglio 2023. Il Tribunale UE l'ha **confermata il 3 settembre 2025** (T-553/23, Latombe); l'impugnazione è **pendente** presso la Corte di giustizia (C-703/25 P, depositata il 31/10/2025). Il 31/07/2026 l'EDPB ha chiesto alla Commissione di valutare l'impatto della sentenza della Corte suprema USA in *Trump v. Slaughter* (29/06/2026). Fonti secondarie: [WilmerHale, 01/12/2025](https://www.wilmerhale.com/en/insights/blogs/wilmerhale-privacy-and-cybersecurity-law/20251201-european-court-of-justice-to-review-challenge-to-eu-us-data-privacy-framework), [ppc.land su EDPB](https://ppc.land/edpb-puts-eu-us-data-pact-in-doubt-as-ftcs-five-commissioners-lose-shield/), [Microsoft interviene (30/06/2026)](https://winbuzzer.com/2026/06/30/microsoft-joins-eu-us-data-privacy-framework-appeal-xcxwbn/). Da riverificare su curia.europa.eu.
- ❓ **Groq non risulta nei risultati come certificata DPF**; non ho letto la lista ufficiale (dataprivacyframework.gov). Se non certificato servono le clausole contrattuali standard (SCC) più una valutazione di impatto del trasferimento. → domanda al proprietario / al fornitore.
- Supabase (Irlanda) e Vercel (Dublino, `dub1`) restano nello SEE secondo la memoria di progetto.

## 2. TDDDG § 25 (cookie e accesso al dispositivo)

- ✅ (via testo riportato da fonte secondaria, la pagina primaria `gesetze-im-internet.de/tdddg/__25.html` ha risposto 404 in questa sessione) § 25 TDDDG: memorizzare informazioni sul terminale dell'utente o accedervi richiede il **consenso** sulla base di informazioni chiare e complete, salvo quando serve **solo** alla trasmissione di un messaggio o è **strettamente necessario** per un servizio digitale che l'utente ha chiesto espressamente. Fonte: [lxgesetze.de – § 25 TDDDG](https://lxgesetze.de/tdddg/25).
- 🟡 Vale anche senza dati personali (identificatori letti dal dispositivo); il trattamento successivo ricade nel GDPR. Guida attuale delle autorità: [DSK – OH Digitale Dienste, Versione 1.2, novembre 2024](https://datenschutzkonferenz-online.de/media/oh/OH_Digitale_Dienste.pdf) (non riletta integralmente; non ho verificato versioni più recenti). Richiede tra l'altro che «accetta» e «rifiuta» abbiano pari rilievo.
- 🟡 Sanzione per violazione del § 25 comma 1: fino a € 300.000 (§ 28 TDDDG), secondo la stessa fonte secondaria.
- Effetto: il token di sessione Supabase e le preferenze locali sono «strettamente necessari». Un eventuale strumento di analisi (oggi **nessuno attivo**, memoria bozza IT) o gli identificatori pubblicitari richiederebbero consenso. La voce `analytics` del catalogo va tenuta vera: o si attiva uno strumento, o si toglie.

## 3. Impressum — § 5 DDG (ex § 5 TMG)

- ✅ Dal 14/05/2024 la «Impressumspflicht» è nel **§ 5 DDG** (Digitale-Dienste-Gesetz), che ha sostituito il TMG. Fonte primaria: [§ 5 DDG](https://www.gesetze-im-internet.de/ddg/__5.html). Elenco letto (comma 1): (1) nome e indirizzo, per persone giuridiche forma giuridica e rappresentanti (e capitale sociale se indicato); (2) dati per contatto rapido e comunicazione diretta, **compreso un indirizzo e-mail**; (3) autorità di vigilanza se serve autorizzazione; (4) registro delle imprese e numero; (5) professioni regolamentate (ordine, titolo, norme professionali); (6) partita IVA / numero d'identificazione economica; (7) stato di liquidazione per AG/KGaA/GmbH; (8) fornitori di servizi media audiovisivi. Comma 2: altri obblighi informativi di altre leggi restano.
- 🟡 Vale per le app offerte «geschäftsmäßig» e va resa **facilmente riconoscibile, direttamente raggiungibile e sempre disponibile**; come regola pratica non più di 2 clic. Un indirizzo con **casella postale non basta**. Fonti: [e-recht24](https://www.e-recht24.de/impressum/10176-app-impressum.html), [IHK München](https://www.ihk-muenchen.de/ratgeber/recht/internetrecht/impressum/). Rilevante anche per la scheda dello store.
- 🟡 Se l'app contiene contenuti giornalistico-redazionali (la sezione «novità»/news?) si aggiunge un responsabile ex § 18 comma 2 MStV (fonte: stesse). ❓ da chiarire se le novità di VetApp sono redazionali.
- ⚖️ Il titolare è italiano: in base al principio dello Stato d'origine (e-commerce) il suo Impressum potrebbe seguire la norma italiana (art. 7 D.Lgs. 70/2003, conoscenza generale), ma conviene un Impressum conforme al § 5 DDG in ogni caso.
- Nota: l'Impressum è anche il posto per le informazioni su **conciliazione consumatori**: § 36 VSBG impone di dichiarare se si partecipa a una procedura di conciliazione (conoscenza generale, da verificare). La piattaforma ODR dell'UE è stata chiusa il 20/07/2025 (conoscenza generale, da verificare): non rimandarvi.

## 4. Consumatori: prezzi, vendita a distanza, recesso, pulsanti

### 4.1 Preisangabenverordnung (PAngV)
- 🟡 Il prezzo verso i consumatori è il **prezzo totale (Gesamtpreis) con IVA e tutti gli elementi**, vicino al prodotto; vale anche per servizi B2C. Fonti: [e-recht24 – PAngV](https://www.e-recht24.de/ecommerce/13092-preisangabenverordnung.html), [IHK Regensburg](https://www.ihk.de/regensburg/fachthemen/recht/werbung-und-wettbewerb/preisangabenverordnung-neue-regeln-5528666). Per sconti: indicazione del prezzo precedente (conoscenza generale, da verificare). Per i piani Plus/Pro (canone mensile / annuale) serve il prezzo del periodo con «inkl. MwSt.» ⚖️.

### 4.2 Button-Lösung (§ 312j BGB)
- ✅ [§ 312j BGB](https://www.gesetze-im-internet.de/bgb/__312j.html): il pulsante d'ordine deve essere ben leggibile e riportare solo «**zahlungspflichtig bestellen**» o formula ugualmente univoca; senza di esso il contratto **non si conclude** (comma 4). Le informazioni di comma 2 vanno date subito prima dell'ordine, in evidenza.
- 🟡 Una prova gratuita **non** elude la Button-Lösung quando serve a trasformarsi in abbonamento a pagamento (OLG Köln, riferito da fonte secondaria, [Ferner Alsdorf](https://www.ferner-alsdorf.de/thema/buttonloesung/)); sentenza non letta ❓.

### 4.3 Kündigungsbutton (§ 312k BGB)
- ✅ [§ 312k BGB](https://www.gesetze-im-internet.de/bgb/__312k.html) (da 01/07/2022): se un sito consente di concludere online un contratto continuativo a pagamento, serve una **funzione di disdetta online**: pulsante «Verträge hier kündigen» (o formula equivalente) → pagina di conferma con identificazione, tipo di disdetta, data → pulsante «jetzt kündigen». Sempre disponibile e facilmente raggiungibile. Salvataggio con data e ora, **conferma immediata in forma testuale**. Se manca, il consumatore può disdire **in qualsiasi momento senza preavviso** (comma 6).
- 🟡 La giurisprudenza è in movimento (LG München I contro Sky, non definitiva; LG Koblenz; un articolo cita BGH I ZR 200/25 su contenuti della pagina di conferma, non verificato) — fonte: [CMS](https://cms.law/de/deu/legal-updates/kuendigungsbutton-gerichte-praezisieren-anforderungen).
- Effetto: la **web app Flutter** (che si apre nel browser) conclude i contratti «su un sito» → vale il § 312k; per gli acquisti dentro gli store, il contratto passa dallo store ⚖️ (domanda al proprietario). Oggi i pagamenti non sono attivi.

### 4.4 Widerruf (§ 355 ss. BGB) e **Widerrufsbutton**
- ✅/🟡 Termine di **14 giorni**; per contenuti digitali non su supporto fisico decorre dalla conclusione del contratto, e solo se il consumatore è stato informato correttamente. [§ 356 BGB](https://www.gesetze-im-internet.de/bgb/__356.html): per i **servizi** il diritto si estingue all'esecuzione completa e, se il servizio è a pagamento, solo se il consumatore ha **chiesto espressamente** l'inizio anticipato e **confermato di sapere** che perde il diritto; per i **contenuti digitali** a pagamento: avvio dell'esecuzione + consenso espresso + conferma di sapere + conferma su supporto durevole (§ 312f). Termine massimo 12 mesi e 14 giorni. La pagina letta numera i commi diversamente da quanto ricordo (Abs. 4/5): citare «§ 356 BGB» senza il comma finché l'avvocato non verifica ❓.
- 🟡 Un abbonamento a un servizio dinamico (come l'assistente IA) è plausibilmente un **servizio digitale** e non un contenuto digitale: l'estinzione anticipata dipende dal servizio **interamente eseguito**; una fonte cita una sentenza CGUE C-234/25 del 09/07/2026 su uno streaming, **non verificata** (un solo documento, [Musterschreiben](https://www.drohnen.de/wp-content/uploads/2026/07/Musterschreiben-Widerruf-Streaming-Abo-FINAL.pdf)) ❓⚖️.
- 🟡 **Widerrufsbutton (§ 356a BGB):** dal **19/06/2026** (attuazione della Direttiva UE 2023/2673, legge pubblicata in BGBl. 2026 I Nr. 28 il 05/02/2026) i contratti a distanza conclusi tramite interfaccia online richiedono una **funzione «Vertrag widerrufen»** sempre disponibile, in evidenza, con conferma immediata di ricezione. Nessuna eccezione per i servizi finanziari. Fonti: [Noerr](https://www.noerr.com/de/insights/umsetzungsgesetz-zum-widerrufsbutton-veroeffentlicht), [Bitkom](https://www.bitkom.org/sites/main/files/2026-05/bitkom-praxisleitfaden-zur-umsetzung-des-widerrufsbuttons.pdf). Non ho letto il testo del § 356a.

### 4.5 Contratti di consumo su prodotti digitali (§§ 327 ff. BGB)
- 🟡 (conoscenza generale, da verificare) Conformità del prodotto digitale, aggiornamenti, limiti alla modifica unilaterale del servizio, diritti del consumatore (ripristino, riduzione del prezzo, recesso), regole sulla garanzia — che vale anche per un servizio «gratuito» pagato con dati. Le clausole di limitazione di responsabilità nei termini (doc 03 §10) vanno viste con le norme sulle AGB (§§ 305 ss., 309 BGB) ⚖️.
- 🟡 Abbonamenti: nelle AGB, il rinnovo tacito indefinito con preavviso massimo di un mese e durata iniziale ≤ 2 anni (§ 309 Nr. 9 BGB dopo il «Gesetz für faire Verbraucherverträge», conoscenza generale, da verificare).

## 5. Età e capacità negoziale

- 🟡 In Germania i minori tra 7 e 17 anni hanno capacità limitata (§§ 106 ss. BGB): i contratti a pagamento richiedono il consenso dei genitori, con il «Taschengeldparagraph» (§ 110 BGB) come eccezione (conoscenza generale, da verificare). Quindi: **18+** per il piano a pagamento è la scelta lineare.
- 🟡 Jugendschutz: nessuna verifica d'età rigida per un'app non «entwicklungsbeeinträchtigend»; il JMStV (Jugendmedienschutz-Staatsvertrag) e il JuSchG (§ 24a) fissano obblighi per fornitori di servizi con contenuti pericolosi/per minori. VetApp dichiara 18+ senza contenuti per soli adulti: ❓ valutare se serve l'impostazione «18+» nelle IARC/USK. Fonte: [WBS.legal](https://www.wbs.legal/medienrecht/jugendmedienschutz/jugendschutz-internet), [USK/IARC](https://usk.de/wp-content/uploads/2023/12/2023-12-07_Stellungnahme-JMStV-E-2023_USK_final.pdf) — letture parziali.
- IARC: Google Play usa IARC (🟡 non vincolante rispetto a USK). Per Apple, valutazione propria (non cercata).

## 6. AI Act (UE) — trasparenza per i chatbot

- ✅ **Art. 50, par. 1:** i fornitori devono progettare i sistemi IA destinati a interagire direttamente con persone in modo che queste siano informate di interagire con un'IA, salvo che sia ovvio. Le Linee guida della Commissione sull'art. 50 sono state pubblicate il **20/07/2026** (ultimo aggiornamento della pagina 31/07/2026); la pagina conferma «These transparency obligations apply from 2 August 2026». Fonte primaria: [Commissione – Guidelines art. 50](https://digital-strategy.ec.europa.eu/en/library/guidelines-transparency-obligations-providers-and-deployers-ai-systems). Non ho letto il PDF.
- 🟡 Fonti secondarie sulle linee guida: l'eccezione «ovvio» è stretta; una dicitura generica come «assistente» non basta; esempi sufficienti: avviso all'inizio della sessione o indicatore permanente sul campo di input. Fonti: [Stephenson Harwood](https://perspectives.stephensonharwood.com/post/102nfqh/eu-ai-act-update-european-commission-adopts-guidelines-on-article-50-transparenc), [CSA research note](https://labs.cloudsecurityalliance.org/research/csa-research-note-eu-ai-act-article-50-transparency-20260729/).
- 🟡 Il **Digital Omnibus** (Reg. UE 2026/1744 secondo le fonti, entrato in vigore il 27/07/2026) ha rinviato i sistemi ad alto rischio (Allegato III al 02/12/2027; Allegato I al 02/08/2028) ma **non l'art. 50**. Per l'art. 50, par. 2 (marcatura leggibile da macchina) i sistemi già sul mercato prima del 02/08/2026 hanno tempo fino al **02/12/2026**. Fonti secondarie discordi su alcuni dettagli: ❓ verificare su EUR-Lex.
- 🟡 Sanzioni: fino a € 15 milioni o 3% del fatturato mondiale (fonti secondarie).
- Effetto su VetApp: VetApp è **fornitore** di un sistema (la chat) basato su un modello di terzi: l'etichetta «KI-generiert», la schermata del primo uso e il piè di pagina (doc 05) servono davvero come obbligo, non solo come buona pratica. VetApp non è un sistema ad alto rischio (nessun uso sanitario umano). ⚖️ L'avvocato conferma il ruolo (fornitore/deployer) e se un'IA che dà consigli sulla salute animale entra in altre categorie.

## 7. Diritto veterinario: diagnosi e prescrizione a distanza

- ✅ **Bundestierärztekammer (BTK), «Empfehlungen … zur Anwendung der veterinärmedizinischen Telemedizin», 01/04/2020** (primaria): l'offerta telemedica è legata a una sede o a un impiego presso un veterinario (MBO § 11); l'esame telemedico può sfociare «al massimo in una **diagnosi provvisoria o di sospetto**», la diagnosi finale richiede visita clinica; i **farmaci soggetti a prescrizione non possono essere prescritti** sulla base di una valutazione telemedica (salvo prescrizioni successive dopo visita); citare nomi commerciali di farmaci Rx su siti nell'ambito della telemedicina è inammissibile (§ 10 HWG). Fonte: [BTK – Empfehlungen](https://www.bundestieraerztekammer.de/d.php?id=5861). Dichiarano di essere raccomandazioni; l'attuazione è competenza dei Länder («Ländersache»).
- 🟡 La BTK ha poi pubblicato «Leitlinien Telemedizin in der veterinärmedizinischen Praxis» (11/11/2021) e un'evoluzione della Musterberufsordnung (§ 12: regola del contatto personale con eccezione per la consulenza esclusivamente mediale «tierärztlich vertretbar», commi 6–8 nella bozza del 2023). Citati in una presentazione dell'Ordine austriaco ([bpt/ÖTK](https://www.tieraerztekammer.at/fileadmin/templates/img/Zukunftstalk2023/Praesentationen/Moder-Siegfried_bpt.pdf)); **non ho letto il testo originale né le Berufsordnungen dei singoli Länder** ❓⚖️.
- ✅ **TAMG § 30** ([primaria](https://www.gesetze-im-internet.de/tamg/__30.html)): i medicinali veterinari soggetti a prescrizione (§ 24 commi 1–2) **non possono essere venduti al dettaglio a distanza**, salvo ordinanza ex § 52 comma 1 n. 11; manca la data di aggiornamento.
- ❓ Non ho trovato una norma federale che riservi a veterinari la «diagnosi» in modo analogo a quanto fa l'Austria (§ 4 TÄG). Chi non è veterinario non commette per ciò solo un reato nel riceverla (esistono i Tierheilpraktiker), ma i **limiti pubblicitari e i rischi di responsabilità** restano. Raccomandazione prudente, coerente con UK/US/AU: **nessuna diagnosi, nessun dosaggio, nessun nome di farmaco Rx, nessun «virtual vet»**.
- ⚖️ Verificare: Heilmittelwerbegesetz (HWG, in particolare § 10 e il divieto di pubblicità ingannevole), UWG (§ 5 pratiche ingannevoli) per le schede dello store.

## 8. Tierschutz e Mercatino (vendita di animali vivi)

- ✅ (più fonti istituzionali) Il **commercio professionale di vertebrati** richiede un'autorizzazione ex **§ 11 TierSchG**. Fonti: [Stadt Karlsruhe](https://web1.karlsruhe.de/service/Buergerdienste/leistung.php?id=6019791), [Merkblatt Erlangen-Höchstadt (12/2024)](https://erlangen-hoechstadt.de/media/15596/2024-12-06-merkblatt-erlaubnis-nach-11.pdf). La «professionalità» dipende dal caso (🟡 soglie indicative per l'allevamento: 3 cagne/3 cucciolate, 5 gatte/5 cucciolate).
- 🟡 Non c'è un divieto federale generale di annunci online di animali; la Berlino ([handout](https://berlin.de/lb/tierschutz/haustierkauf/handout_onlinehandel-002.pdf)) lo definisce «non regolato»; il Bundesrat ha approvato nel 2021 una risoluzione (NRW) per limitarlo ad allevatori con autorizzazione (non è legge). eBay Kleinanzeigen dal 11/2022 richiede la § 11 per cani/gatti sotto 12 mesi (fonte secondaria, [Mimikama](https://www.mimikama.org/?p=293717)).
- **Decisione del proprietario (2026-10-26):** nel Mercatino non si vendono, regalano né scambiano animali, in nessun paese: la regola non dipende più dalla Germania. Questa sezione resta come motivazione giuridica. → doc 03 §8.
- ❓ Ordinanze dei Länder, obbligo di marcatura/registro (Tasso/FINDEFIX): non approfondite.

## 9. Piattaforma, contenuti dell'utente, accessibilità

- 🟡 **DSA** (Reg. UE 2022/2065), attuato in Germania dal **DDG** (che ha sostituito il TMG il 14/05/2024, [e-recht24](https://www.e-recht24.de/news/abmahnung/10176-app-stores-fehlendes-impressum-wird-jetzt-abgemahnt.html)): VetApp ospita contenuti di utenti (segnalazioni, annunci) → obblighi dei servizi di hosting (punto di contatto, meccanismo di segnalazione, motivazione delle rimozioni). Esenzioni per micro/piccole imprese per gli obblighi delle piattaforme online (conoscenza generale, da verificare). L'obbligo di tracciabilità dei «trader» (art. 30) riguarda i marketplace con operatori commerciali; i privati non lo sono, ma un venditore ricorrente può esserlo ⚖️.
- 🟡 **BFSG** (Barrierefreiheitsstärkungsgesetz), in vigore dal **28/06/2025**: i servizi B2C online (e-commerce incluso) devono essere accessibili; esenzione per le microimprese (< 10 persone e fatturato/bilancio ≤ € 2 milioni) solo per i **servizi**; nessun periodo transitorio per app/siti. Fonte: [IHK Koblenz](https://www.ihk.de/koblenz/unternehmensservice/recht/aktuelles/aktuelle-informationen-aus-recht-und-steuern/barrierefreiheit-6616444), [Görg](https://www.goerg.de/de/aktuelles/veroeffentlichungen/20-01-2025/digital-ohne-huerden-was-das-bfsg-fuer-unternehmen-bedeutet). ⚖️ Il titolare italiano è soggetto anche alla propria legge (D.Lgs. 82/2022): l'avvocato indica quale e se la piccola dimensione esonera.

## 10. Store (Apple App Store, Google Play) per la Germania

(conoscenza generale, **non ho letto le policy di oggi**: 🟡/❓)
- Dichiarazione dello status di **trader** (DSA) con nome, indirizzo, telefono, e-mail mostrati sulla scheda dello store: coincide con i dati dell'Impressum.
- Eliminazione dell'account da dentro l'app, schede privacy («nutrition labels»/Data safety), politica privacy raggiungibile da un URL pubblico.
- Valutazione dell'età (IARC su Google Play): coerente con 18+ e con l'assenza di contenuti per adulti.
- Schede dello store: evitare «Tierarzt per App», «Diagnose», «KI-Tierarzt», «Ersatz für Tierarztbesuch» (doc 05 §9).

## 11. Cosa va fatto (sintesi operativa)

1. Impressum in app e store (§ 5 DDG) con i dati del titolare.
2. Informativa privacy tedesca (doc 02) con SCC/DPF per Groq e canale di reclamo.
3. Consensi `de-DE` v1 con lingua mostrata salvata (doc 04).
4. Avviso IA ai sensi dell'art. 50 AI Act (doc 05), già dal primo utilizzo.
5. Prezzi con IVA, Button-Lösung, Kündigungs-/Widerrufsbutton sulla web app (doc 03 §4–5).
6. Mercatino senza animali vivi.
7. Assistente: nessun farmaco Rx, nessun dosaggio, nessuna diagnosi.
8. DPIA (non fatta qui).

## 12. Incertezze (da non trasformare in affermazioni)

- Esistenza e contenuto delle Berufsordnungen dei Länder sulla telemedicina; stato della Musterberufsordnung § 12 (testo non letto).
- Ruolo di VetApp ai fini dell'AI Act (fornitore) e testo definitivo delle linee guida art. 50 (PDF non letto).
- Se Groq è certificata DPF; esito dell'impugnazione C-703/25 P.
- § 356a BGB (letto solo in fonti secondarie), sentenza CGUE C-234/25 (un solo documento), numerazione dei commi del § 356 BGB.
- Se il contratto d'abbonamento in app passa dallo store (quindi niente Kündigungsbutton proprio) o dal sito.
- Applicabilità del BFSG a un titolare italiano di piccole dimensioni.
- Regole per i Länder su annunci di animali vivi; HWG.
- Lingua dei testi per utenti in Germania che usano un'altra lingua (EN, IT): vale la sola traduzione o va il testo tedesco? (domanda in doc 08).
- Valori di sanzioni citati da fonti secondarie (TDDDG € 300.000; AI Act 15 mln/3%).

## Fonti consultate (2026-10-14)

Primarie: [§ 5 DDG](https://www.gesetze-im-internet.de/ddg/__5.html) · [§ 312j BGB](https://www.gesetze-im-internet.de/bgb/__312j.html) · [§ 312k BGB](https://www.gesetze-im-internet.de/bgb/__312k.html) · [§ 356 BGB](https://www.gesetze-im-internet.de/bgb/__356.html) · [§ 30 TAMG](https://www.gesetze-im-internet.de/tamg/__30.html) · [BTK Empfehlungen 01/04/2020](https://www.bundestieraerztekammer.de/d.php?id=5861) · [Commissione UE – Guidelines art. 50](https://digital-strategy.ec.europa.eu/en/library/guidelines-transparency-obligations-providers-and-deployers-ai-systems).
Secondarie: lxgesetze.de (TDDDG), DSK (OH Digitale Dienste), e-recht24, IHK (Regensburg, Koblenz, München), CMS, Noerr, Bitkom, WilmerHale, Stephenson Harwood, CSA, Görg, Mimikama, WBS.legal, USK.
Non raggiungibili: `gesetze-im-internet.de/tdddg/__25.html` (404).
