> **BOZZA — non è consulenza legale; da rivedere da un avvocato abilitato negli USA prima della pubblicazione**

# USA — ricerca normativa (Quokka)

Sessione "Legale EN-US". Data di consultazione di tutte le fonti: **2026-10-13** (salvo diversa indicazione). Lingua del documento: italiano (uso interno). I testi destinati agli utenti (02–06) sono in inglese americano.

## Come leggere questo documento

- **[P]** = pagina ufficiale/primaria letta direttamente in questa sessione. **[S]** = fonte secondaria (studi legali, blog di conformità, riepiloghi emersi dalla ricerca), **non verificata sul testo di legge**: ogni cifra o data [S] va confermata dall'avvocato sul testo normativo.
- **[N]** = nozione dal contesto generale, nessuna fonte consultata in questa sessione. Non va citata come verificata.
- Le **incertezze** sono dichiarate in fondo a ogni sezione e riassunte nella sezione 12. Dove non ho trovato una norma, lo scrivo: non l'ho inventata.
- Premessa di contesto: gli USA **non hanno una legge federale generale sulla privacy** (equivalente del GDPR). Il quadro è un mosaico: leggi statali "comprehensive" (circa 20 stati in vigore al 1° gen 2026 [S]), più leggi settoriali federali (COPPA, CAN-SPAM, TCPA, FTC Act) e leggi statali su temi specifici (rinnovi automatici, veterinaria, chatbot).

## Sintesi esecutiva (per l'Orchestratore)

1. **Una startup sotto soglia è in gran parte esclusa dalle leggi statali "comprehensive"**, ma non del tutto: California (ricavi ≥ 26,625 mln $, o ≥ 100.000 consumatori/famiglie, o ≥ 50% ricavi dalla vendita/condivisione di dati) e quasi tutti gli altri stati usano soglie su numero di residenti (tipicamente 100.000, in calo a 35.000 in alcuni stati). **Eccezioni che riguardano anche i piccoli**: Texas (nessuna soglia numerica, esenzione solo se "small business" SBA; anche i piccoli devono avere il consenso prima di *vendere* dati sensibili), Connecticut dal 1° lug 2026 (si applica a chiunque tratti dati *sensibili*, a prescindere dal volume) [S]. La **posizione GPS precisa è dato sensibile** in molti stati, e Quokka la tratta (passeggiate).
2. **Anche sotto soglia conviene una privacy policy "da CCPA"**: lo richiedono comunque CalOPPA (qualsiasi servizio online che raccolga dati di residenti californiani, nessuna soglia), Apple e Google (privacy policy, etichette, cancellazione account) e la prudenza commerciale.
3. **Veterinaria**: la regola prudente per un'app è *non diagnosticare né prescrivere* (informazione generale + triage + invio al veterinario). Le leggi statali definiscono la "pratica veterinaria" in modo ampio (comprende dare consigli su diagnosi e cura) [S]; la VCPR (rapporto veterinario-cliente-paziente) è richiesta dalla maggior parte degli stati per diagnosticare/prescrivere e in molti stati si costituisce solo con visita in presenza. Nessun caso di enforcement contro un chatbot per esercizio abusivo trovato.
4. **IA**: la FTC applica la Section 5 anche alle dichiarazioni sull'IA; stanno arrivando leggi statali sui chatbot (alcune già in vigore, altre dal 2027) [S]. L'avviso "sei con un'IA" va fatto comunque.
5. **Abbonamenti/prova gratuita**: ROSCA è in vigore; la regola FTC "click-to-cancel" è stata **annullata** dall'8th Circuit (8 lug 2025); restano ROSCA e le leggi statali sui rinnovi automatici (California, rafforzata dal 1° lug 2025 anche per le prove gratuite).
6. **GDPR continua ad applicarsi** se il titolare è stabilito in Italia, anche per utenti USA (art. 3(1) GDPR) [N]: la policy USA non può peggiorare le garanzie già date. Domanda per il legale.

---

## 1. Leggi statali sulla privacy ("comprehensive")

### 1.1 Quadro e fonti

| Stato | Legge | In vigore | Soglia di applicabilità (sintesi) | Fonte |
|---|---|---|---|---|
| California | CCPA come modificato da CPRA | 2020 / 2023 | **Una** tra: ricavi lordi ≥ **26.625.000 $** (anno precedente; adeguata dal 1° gen 2025 — la prossima rivalutazione è attesa dal 1° gen 2027); acquista/vende/condivide dati di ≥ **100.000** residenti/famiglie; ≥ **50%** dei ricavi da vendita/condivisione di dati personali | [P] https://cppa.ca.gov/faq.html ; [S] https://www.feroot.com/blog/ccpa-applicability-website-california-law/ |
| Virginia | VCDPA | 1° gen 2023 | ≥ 100.000 consumatori, oppure ≥ 25.000 e > 50% dei ricavi da vendita di dati | [S] https://usercentrics.com/us/knowledge-hub/us-state-data-privacy-effective-dates-and-thresholds/ |
| Colorado | CPA | 1° lug 2023 | ≥ 100.000 consumatori, oppure ≥ 25.000 e ricavi/sconti dalla vendita di dati. **Fonti in conflitto** su un abbassamento a 35.000 nel 2026: una lo attribuisce a Colorado, ma altre non lo confermano e sembra una confusione con il Connecticut → **da verificare** | [S] https://privacylawmap.com/states/colorado ; [S] https://www.mvalaw.com/data-points/dont-forget-big-changes-coming-to-colorados-privacy-act-upcoming-deadlines-for-biometrics-and-minors-effective-july-1-2025-and-october-1-2025 |
| Connecticut | CTDPA, come modificato da SB 1295 (PA 25-113) | 1° lug 2023; modifiche 1° lug 2026 | Dal 1° lug 2026: ≥ **35.000** consumatori (esclusi pagamenti), **oppure tratta dati sensibili a prescindere dal volume**, oppure vende dati a prescindere dal volume | [S] https://www.swlaw.com/publication/connecticut-data-privacy-act-2026-amendments/ ; [S] https://www.ebglaw.com/workforce-bulletin/connecticut-overhauls-its-data-privacy-act |
| Utah | UCPA | 31 dic 2023 | Test cumulativo: ricavi > 25 mln $ **e** ≥ 100.000 consumatori (o ≥ 25.000 con > 50% ricavi da vendita di dati). Formulazione esatta da verificare | [S] usercentrics (sopra) |
| Texas | TDPSA | 1° lug 2024 | **Nessuna soglia numerica**: si applica a chi fa affari in Texas e tratta/vende dati personali e **non** è "small business" secondo le definizioni SBA. I "small business" sono esentati dalla maggior parte degli obblighi, **ma non dal divieto di vendere dati sensibili senza consenso** | [S] https://www.dwt.com/blogs/privacy--security-law-blog/2023/07/texas-data-privacy-and-security-act-overview ; [S] https://www.velaw.com/insights/texas-ag-targets-allstate-in-first-enforcement-of-texas-data-privacy-and-security-act/ ; il sito dell'AG del Texas non è stato leggibile (errore 402) |
| Oregon | OCPA | 1° lug 2024 | ≥ 100.000 consumatori (esclusi pagamenti), oppure ≥ 25.000 e > 25% dei ricavi da vendita di dati. Dato di posizione precisa (raggio 1.750 piedi) è sensibile; emendamento 2025: vietata la **vendita** di posizione precisa | [S] https://secureprivacy.ai/blog/oregon-consumer-privacy-act-guide ; [S] https://apps.oregonlegislature.gov/liz/2025R1/Downloads/MeasureAnalysisDocument/91893 |
| Altri (in vigore al 2026) | Tennessee 1° lug 2025; Minnesota 31 lug 2025; Maryland 1° ott 2025 (applicazione al trattamento dal 1° apr 2026); Indiana, Kentucky, Rhode Island 1° gen 2026 (RI: soglia 35.000, nessun periodo di "cure") ; più Delaware, Iowa, Montana, Nebraska, New Hampshire, New Jersey [N] | vedi colonna | variabili (molte 35.000–100.000) | [S] https://www.sheppard.com/insights/blogs/three-states-one-date-ringing-in-the-new-year-with-indiana-kentucky-and-rhode-island ; [S] https://iapp.org/resources/article/key-dates-from-us-comprehensive-state-privacy-laws/ (tracker consultato solo come risultato di ricerca, non letto) |

### 1.2 Una startup sotto soglia è esclusa?

- **California**: sì, **se** sta sotto tutte e tre le soglie. Per una startup con pochi utenti le soglie 1 e 3 non scattano; la soglia 2 (100.000 consumatori/famiglie) sì solo quando si superano quegli utenti (attenzione: i visitatori anonimi del sito possono contare [S]).
- **Virginia, Colorado, Oregon, Utah**: esclusa se sotto 100.000 residenti dello stato (Utah anche sotto 25 mln di ricavi). Il "trigger" di vendita di dati non scatta se non si vendono dati.
- **Connecticut (dal 1° lug 2026)** e **Texas**: **non** si può contare sull'esclusione per dimensioni. CT: basta trattare dati sensibili (la posizione precisa lo è nella maggior parte degli stati [S]) per rientrare [S]. TX: dipende dalla qualifica SBA "small business" (tabelle NAICS, di solito in dipendenti o ricavi) [S]; anche se esentati, niente vendita di dati sensibili senza consenso.
- **Conclusione operativa** (da far confermare): pubblicare comunque un'informativa con sezione "diritti per stato" e rispondere alle richieste di accesso/cancellazione per tutti, come buona pratica e per allinearsi a Apple/Google; è più semplice di un'analisi di soglia stato per stato. Un SaaS o un'app pet non è esentato per il settore: il fatto di essere una startup non esenta.

### 1.3 Diritti, "Do Not Sell/Share", segnali di opt-out

- **California** [P https://oag.ca.gov/privacy/ccpa, pagina aggiornata il 28 ago 2026; https://cppa.ca.gov/faq.html]: diritti di *sapere*, *cancellare*, *correggere*, *limitare* l'uso dei dati sensibili, *opt-out* di vendita/condivisione (incluso via Global Privacy Control), non discriminazione. Notice at collection; privacy policy; link "Do Not Sell or Share My Personal Information" / "Your Privacy Choices" **solo se** il business vende o condivide. Risposta entro **45 giorni** (prorogabile di altri 45); opt-out entro **15 giorni lavorativi**. Per i minori di 16 anni: opt-in alla vendita/condivisione (sotto i 13 serve il genitore).
- **Altri stati**: in generale accesso, correzione, cancellazione, portabilità, opt-out di vendita/pubblicità mirata/profilazione; **consenso (opt-in) per i dati sensibili** in VA, CO, CT, TX e altri [S/N]; Colorado ha aggiunto la posizione precisa tra i dati sensibili (SB 25-276) [S]; termine di risposta tipico 45 giorni [N]; diritto di appello in molti stati [N]. Il **periodo di "cure"** varia: CT e CO non lo concedono più [S]; TX: 30 giorni di preavviso [S].
- **Stato attuale di Quokka**: dai documenti 09 e 08 non risulta alcuno strumento di analisi/pubblicità attivo, e nessuna vendita di dati. Se resta così, il link "Do Not Sell or Share" **non è richiesto** (si mette solo se si vende/condivide); resta l'obbligo di informare. **Da confermare prima della pubblicazione** (cambierebbe se si aggiungessero SDK di pubblicità/analisi). I dati inviati al fornitore di IA (Groq) vanno trattati come comunicazione a *service provider/processor* con contratto adeguato (clausole richieste dal CCPA e dalle altre leggi) — **contratto da verificare** (domanda 7 in 08).
- **Nuovi obblighi California**: regolamenti su decisioni automatizzate (ADMT), valutazioni di rischio e audit di cybersicurezza in vigore dal 1° gen 2026 con scadenze a fasi fino al 2027–2028 [P cppa.ca.gov/faq.html]; si applicano solo ai business già "coperti". Non analizzato in dettaglio.

### 1.4 Dati sull'animale vs dati dell'utente

Le leggi sulla privacy proteggono i dati di **persone**. I dati clinici dell'*animale* non sono "dati sanitari" nel senso delle leggi su dati di salute umani (es. leggi sui "consumer health data" come quella di Washington [N]) — ma nei documenti caricati e nei messaggi di chat possono comparire dati dell'utente (nome, telefono, indirizzo del veterinario, anche condizioni di salute dell'utente). Il filtro PII è a regole e non è una garanzia (docs/compliance/02). Quindi: **trattare l'intero contenuto caricato come potenziale dato personale** nell'informativa. Nessuna fonte consultata affronta il caso "dati sanitari dell'animale": è una **domanda aperta** per il legale.

### 1.5 Incertezze (sez. 1)

- Cifre di soglia e date da fonti [S]; vanno ricontrollate sul testo di legge e sui siti degli AG/CPPA prima di pubblicare.
- Colorado: conflitto di fonti (vedi tabella).
- Elenco completo degli stati e relative soglie: non verificato stato per stato per tutti gli stati oltre i sette elencati.
- La definizione esatta di "dato sensibile" (posizione precisa: raggio, consenso richiesto) varia per stato; non verificata.

---

## 2. CalOPPA

- Cal. Bus. & Prof. Code §§ 22575–22577: chi gestisce un sito/servizio online commerciale che raccoglie "personally identifiable information" da residenti californiani deve **pubblicare in modo evidente una privacy policy** (per i servizi online: "ragionevolmente accessibile"). Contenuto: categorie di dati raccolti e di terzi con cui sono condivisi; come rivedere/correggere i dati (se previsto); come si notificano le modifiche; **data di entrata in vigore**; **come l'operatore risponde ai segnali "Do Not Track"** (si deve *dichiarare*, non si impone una risposta). Si è in violazione se non si pubblica entro 30 giorni dalla notifica di inadempienza. Fonti: [S] https://california.public.law/codes/ca_bus_and_prof_code_section_22575 ; [S] lettera dell'AG californiano https://www.oag.ca.gov/system/files/attachments/press_releases/CalOPPA%20Letter_0.pdf.
- **Nessuna soglia**: vale per qualsiasi app che raccolga dati di residenti californiani. Le app mobili sono coperte come "online service" (l'AG ha scritto a sviluppatori di app; la lettera è citata, il testo completo non è stato letto in questa sessione).
- Incertezze: testo integrale dei sottocommi non letto; verificare su leginfo.legislature.ca.gov.

## 3. COPPA (minori di 13 anni)

- **Cosa dice** [P https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions]: protegge i minori sotto i **13 anni**. Si applica ai servizi *diretti ai minori* e ai servizi generalisti solo con **actual knowledge** di raccogliere dati da under 13. Non c'è obbligo di chiedere l'età; uno "age screen" neutrale è accettabile. Dati personali includono identificatori persistenti, foto/video/audio, geolocalizzazione precisa.
- **Regola emendata**: pubblicata nel Federal Register il **22 apr 2025**, in vigore dal 23 giu 2025, **conformità entro il 22 apr 2026** per la maggior parte degli operatori [S https://www.davispolk.com/insights/client-update/ftc-prioritizes-coppa-enforcement-new-compliance-obligations-take-effect ; https://www.toyassociation.org/ta/PressRoom2/News/2026-News/updated-coppa-rule-requirements-take-effect-april-22.aspx]. Amplia le definizioni (biometrici, audio, geolocalizzazione). Sanzione civile massima riportata: 53.088 $ per violazione [S, non verificata su FTC].
- **Per Quokka**: l'app non è rivolta ai bambini (tema: animali domestici del proprietario). **Scelta consigliata**: riservare il servizio a maggiorenni (18+), come in Italia, e dichiararlo nei Termini e nella policy; se si venisse a sapere che un utente è under 13, cancellare l'account e i dati. Un'età minima di 13 con consenso del genitore comporterebbe un meccanismo di consenso verificabile → sconsigliato. **Nota**: "18" è maggiore età nella maggior parte degli stati, ma non in tutti [N] (Alabama e Nebraska 19, Mississippi 21 [N]): chiedere al legale se serve "18 o la maggiore età nello stato di residenza, se superiore".
- Apple 5.1.4 e Google chiedono di rispettare COPPA e le leggi sui minori [P Apple].
- Incertezze: la FTC "non emette pareri su siti specifici" [P]; categoria di app e target audience da dichiarare nelle schede degli store.

## 4. FTC

### 4.1 Section 5 e dichiarazioni sull'IA

- La FTC Act Section 5 vieta atti o pratiche **sleali o ingannevoli**. L'FTC ha dichiarato che non esiste "esenzione per l'IA": **Operation AI Comply** (25 set 2024) ha colpito aziende che esageravano le capacità dei propri strumenti (es. "robot lawyer" senza test che dimostrassero l'equivalenza con un avvocato) [S https://www.davispolk.com/insights/client-update/ftc-announces-new-enforcement-initiative-targeting-deceptive-ai-practices]. Lezioni utili: non promettere "come un veterinario", testare e poter dimostrare le dichiarazioni, non affermare che le risposte sono "sicure"/"accurate" senza prova.
- Aggiornamento riportato da una fonte [S] (agosto 2025, ripresa nel risultato di ricerca): la FTC ha riaperto e annullato nel dicembre 2025 l'ordine su Rytr; resta illegittima la pratica di recensioni false anche generate da IA. Da verificare sulle pagine FTC.
- Per Quokka: il testo marketing (store, sito) non deve implicare diagnosi, sostituzione del veterinario o precisione non dimostrata. Vedi anche docs/compliance/01_ai_disclosure.md.

### 4.2 Endorsement Guides e recensioni false

- **Endorsement Guides** (16 CFR Parte 255, rivisti nel 2023) [P https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking]: le testimonianze devono essere oneste; i collegamenti materiali (pagamenti, prodotti gratuiti, affiliazioni) vanno dichiarati in modo chiaro e vicino al contenuto; incentivi condizionati a recensioni positive sono problematici; i marketer rispondono dei propri endorser.
- **Regola FTC sulle recensioni e testimonianze false** (16 CFR Parte 465), annunciata il 14 ago 2024, in vigore dal **21 ott 2024** [S https://www.ftc.gov/news-events/news/press-releases/2024/08/federal-trade-commission-announces-final-rule-banning-fake-reviews-testimonials — URL emerso dalla ricerca, non letto; data di entrata in vigore da fonti secondarie]: vieta recensioni/testimonianze false (anche generate da IA), compensi condizionati al sentimento della recensione, recensioni "indipendenti" controllate dall'azienda, soppressione di recensioni negative. Sanzioni civili (51.744 $ per violazione al 2024, rivalutate ogni anno [S]).
- Per Quokka: le "stelle" sulle aree cani e le segnalazioni (docs/compliance/07) sono contenuti degli utenti, non recensioni di Quokka; ma se si pubblicano testimonianze nello store o sul sito servono le regole sopra. Non pagare né scambiare vantaggi per recensioni positive.

### 4.3 Health Breach Notification Rule (HBNR)

- Modificata il 26 apr 2024, pubblicata il 30 mag 2024, in vigore dal **29 lug 2024** [S https://www.insideprivacy.com/health-privacy/ftc-issues-final-rule-to-expand-scope-of-the-health-breach-notification-rule/ ; l'URL del comunicato FTC è https://www.ftc.gov/news-events/news/press-releases/2024/04/ftc-finalizes-changes-health-breach-notification-rule — non letto]. Copre venditori di *personal health records* (PHR) non soggetti a HIPAA: record elettronico di **informazioni sanitarie identificabili di un individuo**, che può attingere da più fonti ed è gestito dall'individuo. Il "breach" include anche **divulgazioni non autorizzate volontarie**, non solo hackeraggi. Sanzioni civili fino a 51.744 $/violazione (2024, rivalutate) [S].
- **Per Quokka**: la regola riguarda dati sanitari di *persone*. La cartella clinica dell'*animale* non sembra rientrare nella definizione di PHR (che riguarda "an individual"), **ma** non ho trovato una fonte che lo affermi per i pet: **domanda aperta** per il legale. Prudenza: se si aggiungessero dati di salute dell'utente (es. allergie), rivalutare.

### 4.4 Rinnovi automatici, ROSCA e "click-to-cancel"

- **ROSCA** (Restore Online Shoppers' Confidence Act): per abbonamenti/prove gratuite con rinnovo online richiede (1) informazioni chiare sui termini **prima** di raccogliere i dati di pagamento, (2) **consenso espresso** al rinnovo, (3) un modo semplice di cancellare. Resta in vigore; sanzioni civili fino a 53.088 $ per violazione (cifra [S], rivalutata annualmente) [S https://www.cooley.com/news/insight/2025/2025-07-11-click-to-cancel-just-got-cancelled-eighth-circuit-vacates-entirety-of-ftcs-negative-option-rule ; https://www.alston.com/en/insights/publications/2025/07/ftc-click-to-cancel-rule-vacated].
- **Regola FTC "Click-to-Cancel"** (Negative Option Rule modificata): **annullata per intero** dall'8th Circuit l'**8 luglio 2025** per vizi procedurali [S]. Restano la Negative Option Rule del 1973 e le leggi statali. Nessuna notizia sul seguito (ricorso, nuova regola) nei risultati: **verificare sul sito FTC**.
- **California ARL** (Bus. & Prof. Code §§ 17600 ss.), modificata da AB 2863, applicabile ai contratti conclusi/modificati/prorogati dal **1° lug 2025**: include le **prove gratuite** con conversione a pagamento, consenso chiaro e documentato, promemoria annuali, avviso di modifiche di prezzo, cancellazione "click to quit" [S https://fenwick.com/insights/publications/california-tightens-requirements-for-automatically-renewing-subscriptions ; https://ktslaw.com/insights/alert/2024/10/california-latest-automatic-renewal-law-amendments-take-effect-in-july-2025]. Anche altri stati (es. New York, Minnesota) hanno leggi analoghe [S].
- **Per Quokka**: oggi non c'è addebito reale (documento 04, "nessun pagamento reale collegato"); la prova è di 10 giorni senza carta e Free è un'opzione reale. **Se in futuro** si usa la fatturazione dello store (Apple/Google) o Stripe con rinnovo automatico, applicare ROSCA + ARL California + le regole dello store (Apple 3.1.2). I Termini (03) contengono la sezione già pronta.

## 5. CAN-SPAM e TCPA

- **CAN-SPAM** [P https://www.ftc.gov/business-guidance/resources/can-spam-act-compliance-guide-business]: per le email *commerciali*: intestazioni oneste, oggetto onesto, **indicare che è pubblicità**, **indirizzo postale valido**, meccanismo di disiscrizione funzionante per almeno 30 giorni, rispettare l'opt-out **entro 10 giorni lavorativi**; nessuna eccezione B2B; sanzione fino a **53.088 $ per email** [S, cifra rivalutata]. CAN-SPAM è un regime **opt-out** (non richiede consenso preventivo) — Quokka mantiene comunque il consenso **opt-in** (`marketing_email`) come in Italia: più rigoroso e coerente. Le email transazionali (conferma account, promemoria richiesti) non sono "commerciali" se rientrano nelle 5 categorie (verificare caso per caso).
- **TCPA**: non rilevante finché non si inviano SMS/chiamate automatizzate di marketing. Se si faranno: consenso scritto preventivo; la regola FCC "one-to-one consent" è stata annullata (11th Circuit, 24 gen 2025); le regole di revoca sono in vigore dall'11 apr 2025; la "revoke-all" è stata rinviata al **31 gen 2027** [S https://www.consumerfinancialserviceslawmonitor.com/2026/01/fcc-further-extends-effective-date-for-tcpa-revoke-all-rule/]. Le notifiche push dell'app non sono SMS: nessun obbligo TCPA noto (non verificato).

## 6. Pratica veterinaria, telemedicina e VCPR

### 6.1 Cosa dicono le fonti

- **AVMA** [P via ricerca; la pagina https://www.avma.org/resources-tools/animal-health-and-welfare/telehealth-telemedicine-veterinary-practice/telehealth-and-vcpr non è stata resa leggibile dal lettore web — contenuto citato dal risultato di ricerca]: una VCPR **non può essere costituita solo con telemedicina** (dichiarazione attribuita a una lettera FDA); la legge federale richiede la VCPR per uso extra-etichetta di farmaci, per le Veterinary Feed Directive e per certi biologici. La politica AVMA: telemedicina solo all'interno di una VCPR esistente, con eccezione per i consigli in emergenza finché l'animale non è visitato; **contraria alla consulenza remota offerta direttamente al pubblico con finalità di diagnosi/cura senza VCPR**, salvo il *teletriage di emergenza*, come il centro antiveleni. AVMA si oppone alla VCPR virtuale.
- **Variazioni per stato** [S https://www.aaha.org/newstat/publications/the-patchwork-quilt-of-state-veterinary-telehealth-laws/ ; mappa della Veterinary Virtual Care Association non letta]: secondo il conteggio citato da AAHA, **19 stati** stabiliscono che la VCPR non può costituirsi con visita virtuale, **22** richiedono che il veterinario abbia "visto"/"conosciuto" il paziente senza chiarire il caso virtuale, **8** ammettono espressamente la VCPR virtuale; altre fonti parlano di 6–8 stati. **I conteggi sono incoerenti tra le fonti.** Citati come permissivi (da verificare): Arizona, Idaho (nessuna prescrizione se la VCPR è elettronica), Vermont, Virginia (eccezioni per sostanze controllate); Rhode Island (2026, fonte unica); New York è indicato come stato senza definizione statutaria di VCPR (fonti divergono). Colorado: HB24-1048 consente consulti virtuali con specialisti tramite il veterinario primario con VCPR in presenza [S https://colovma.org/wp-content/uploads/2025/03/HB24-1048-Overview-070924.pdf].
- **California AB 1399** (in vigore dal 1° gen 2024) [P https://www.vmb.ca.gov/licensees/ab1399_faqs.shtml]: VCPR obbligatoria per prescrivere/somministrare cure; **può costituirsi via telehealth solo con esame in tempo reale audio-video**; l'animale deve trovarsi in California durante la visita; solo veterinari con licenza californiana; avvisi su farmacie; limiti alle prescrizioni (la fonte [S] indica 6 mesi in generale, 14 giorni per antimicrobici, niente sostanze controllate senza visita in presenza — da verificare sul testo).
- **Definizioni di "pratica veterinaria"** [S]: es. West Virginia (https://www.animallaw.info/statute/wv-veterinary-article-10-veterinarians) e New Hampshire (https://www.animallaw.info/statute/nh-veterinary-chapter-332-b-new-hampshire-veterinary-practice-act) includono **diagnosticare, trattare e *dare consigli o raccomandazioni* sulla diagnosi e la cura**. Questo suggerisce che un'app che dice "il tuo cane ha X, dagli Y" potrebbe rientrare, anche se gratuita (ragionamento ricavato dalle definizioni, **non da un caso concreto**).
- **IA**: l'American Association of Veterinary State Boards (AAVSB) ha pubblicato nel 2025 un white paper sull'IA: i veterinari non devono delegare all'IA decisioni diagnostiche o terapeutiche; tra i temi regolatori c'è l'esercizio abusivo [S https://www.op.nysed.gov/sites/op/files/2025-06/AI%20PowerPoint%20Presentation%20Post-Marketing.pdf — slide che lo riassumono; white paper non letto]. **Non ho trovato casi di enforcement contro un chatbot**, né pareri di un board su software di consigli veterinari ai proprietari.

### 6.2 Cosa può e non può fare un'app (proposta prudente, da validare)

| Può (informazione e organizzazione) | Non dovrebbe (rischio di "pratica" o di dichiarazioni ingannevoli) |
|---|---|
| Informazione generale, educativa, con fonti | Diagnosticare ("il tuo cane ha il diabete") |
| Raccogliere sintomi e fare **triage** ("vai dal veterinario ora / entro 24 h") | Prescrivere o indicare dosaggi di farmaci su misura per un animale specifico |
| Promemoria, scadenze, cartella dell'utente, spiegazione generica di un referto ("cosa significa in generale questo valore") con invito a discuterne col veterinario | Sostituire una visita; dire "non serve il veterinario" |
| Dare numeri utili (centri antiveleni, pronto soccorso 24 h) | Promettere esiti o accuratezza non dimostrata |
| Mostrare servizi veterinari vicini | Dichiararsi "veterinario", "dottore", "clinica", usare titoli professionali |

- Il **dosage safety gate** già presente nella chat va rivisto per gli USA (nomi di farmaci e unità diversi: lb, °F).
- L'**exemption** per "il proprietario cura il proprio animale" o "primo soccorso" esiste in alcuni stati [S, non verificata]: non basta a dire che l'app sia fuori.
- **Incertezze**: nessuna fonte primaria letta per gli statuti di ciascuno dei 50 stati; i conteggi VCPR sono incoerenti; la questione "chi pratica" (sviluppatore, utente) è irrisolta; FDA: non ho verificato se un software che dà indicazioni diagnostiche per animali possa essere qualificato come dispositivo veterinario [N, da non asserire].

## 7. Leggi statali sui chatbot/IA

Fonte generale: [S] Orrick, "2026 State Chatbot Laws", https://www.orrick.com/en/Insights/2026/04/2026-State-Chatbot-Laws-Key-Provisions-and-Regulatory-Trends. Quanto segue è **da verificare**:

- **California**: SB 1001 (2019) — divieto di bot usati per ingannare sul fatto di essere umani per influenzare una vendita o un voto; SB 243 (companion chatbot, in vigore dal 1° gen 2026): riguarda *companion bot*, non assistenti di servizio. Quokka non è un companion bot, ma l'avviso "sei con un'IA" è prudente.
- **Utah** AI Policy Act (2024, modificata 2025): obbligo di dichiarare l'uso di IA generativa su richiesta, e proattivamente in contesti ad alto rischio (inclusa la salute, per professioni regolamentate). **Maine** LD 1727: avviso chiaro che non si parla con un umano, se un consumatore ragionevole lo penserebbe. **Colorado**: la legge sull'IA (SB 24-205) è stata rinviata al 30 giu 2026 e le fonti indicano che nel 2026 è stata sostituita da SB 26-189 sulle decisioni automatizzate (firmata 14 mag 2026) e che HB 26-1263 (chatbot, in vigore dal 1° gen 2027) richiederà di dichiarare l'IA — **stato incerto**. Oregon, Washington, Nebraska, Idaho, Tennessee, New York: leggi su companion/chatbot con date dal 2026 al 2027 (numeri di legge in conflitto tra le fonti).
- Impatto per Quokka: servono (1) **avviso chiaro che le risposte sono generate da IA** (già nel prodotto, docs/compliance/01), (2) nessuna affermazione di essere un professionista, (3) un percorso di emergenza chiaro. Questo copre il nocciolo delle leggi viste. Nessuna legge letta impone un bollino sul *contenuto* generato per chatbot informativi, oltre all'avviso.

## 8. Requisiti Apple App Store e Google Play (per gli USA)

- **Apple** [P https://developer.apple.com/app-store/review/guidelines/]:
  - **5.1.1(i)**: link a privacy policy nei metadati di App Store Connect **e** nell'app; deve dire cosa si raccoglie, come, per cosa, con chi si condivide, conservazione/cancellazione, come revocare il consenso.
  - **5.1.1(ii)**: consenso prima di raccogliere dati utente o d'uso, **anche anonimi**; revoca facile. → *analytics* resta opt-in.
  - **5.1.1(v)**: se l'app permette di creare un account, deve permettere di **avviare la cancellazione dell'account dentro l'app**; la sola disattivazione non basta. → verificare che Quokka lo offra (non ho controllato il codice: fuori incarico).
  - **5.1.2(i)** (dal 13 nov 2025 [S]): informare e ottenere **permesso esplicito** prima di condividere dati personali con terzi, **incluse le IA di terzi**. → La schermata di consenso al primo avvio o prima del primo invio alla chat dovrebbe nominare l'invio al fornitore di IA. L'articolo https://developer.apple.com/news/?id=ey6d8onl non è stato aperto.
  - **1.4.1** app mediche: più scrutinio per informazioni che possono causare danni; ricordare di consultare un medico (riferito a esseri umani; per gli animali nessuna regola specifica trovata). **5.1.4** minori; **3.1.2** abbonamenti (descrivere cosa si ottiene per il prezzo, prima di chiedere di abbonarsi); **1.2** contenuti generati dagli utenti: filtro, segnalazione, blocco degli utenti abusivi, contatto pubblicato (rilevante per segnalazioni radar).
  - **Etichette di privacy ("nutrition labels")**: da compilare in App Store Connect (dati raccolti/collegati all'utente, uso per tracking). Nessuna modifica 2025–2026 verificata; due blog ne dichiarano una da set 2026 (fonte unica, non verificata).
- **Google Play** [P https://support.google.com/googleplay/android-developer/answer/13327111]: per app con creazione account, **percorso di cancellazione in-app** (facilmente trovabile) **e link web** per chiedere la cancellazione senza reinstallare; dichiarazione nel modulo **Data safety** (sezione "App content" di Play Console), compresa la conservazione per motivi di sicurezza/legge, da spiegare nella privacy policy; eliminare i dati presso i fornitori di servizi.
  - **Policy sui contenuti generati dall'IA** [S https://support.google.com/googleplay/android-developer/answer/14094294]: le app con chatbot IA centrale devono impedire contenuti offensivi e fornire **segnalazione in-app** dei contenuti IA problematici; non letto direttamente.
  - Data safety: elencare tutti i dati raccolti/condivisi (posizione precisa, foto/video, audio, informazioni sull'animale, dati dell'account) e le pratiche di sicurezza; lo stesso per i dati inviati al fornitore di IA.
- Lo stato di Firebase App Distribution (solo tester) non ha effetto sugli obblighi di pubblicazione.

## 9. Altre norme (non approfondite)

| Tema | Perché potrebbe servire | Stato della ricerca |
|---|---|---|
| Leggi statali sulle **violazioni di dati** (50 stati) | Obbligo di notificare gli utenti residenti in caso di breach | [N] non consultate |
| **DMCA §512** (agente designato) | Per contenuti caricati dagli utenti (foto, segnalazioni) | [N] non consultata; domanda al legale |
| **Section 230** | Protezione su contenuti di terzi | [N] non consultata |
| **California Shine the Light** (Civ. Code § 1798.83) | Informativa su cessioni a terzi per marketing | [N] non consultata; si applica a chi cede dati a terzi per marketing diretto |
| **Accessibilità (ADA)** | App/siti | [N] non consultata |
| **Sales tax** su abbonamenti digitali | Prezzi mostrati in $ | [N] non consultata; domanda 8 |
| **GDPR extraterritoriale** | Titolare in Italia → GDPR per tutti gli utenti | [N]; da confermare |

## 10. Cosa NON ho verificato (esplicito)

- Il testo normativo di tutti gli stati; le soglie di Maryland, Minnesota, Tennessee, Delaware, Iowa, Montana, Nebraska, NH, NJ, Indiana, Kentucky, RI (solo date di entrata in vigore da fonti secondarie).
- Che cosa abbia fatto la FTC dopo luglio 2025 sul "click-to-cancel".
- I testi completi degli statuti sulla pratica veterinaria dei 50 stati.
- Il white paper AAVSB sull'IA.
- Quali parti della ricerca sono cambiate dopo agosto 2026 (la fonte più recente letta è la pagina dell'AG californiano, aggiornata il 28 ago 2026).

## 11. Elenco fonti (consultate il 2026-10-13)

[P] primarie:
- https://cppa.ca.gov/faq.html
- https://oag.ca.gov/privacy/ccpa
- https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
- https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking
- https://www.ftc.gov/business-guidance/resources/can-spam-act-compliance-guide-business (via ricerca; il contenuto è coerente con la guida)
- https://developer.apple.com/app-store/review/guidelines/
- https://support.google.com/googleplay/android-developer/answer/13327111
- https://www.vmb.ca.gov/licensees/ab1399_faqs.shtml
- https://www.aspca.org/pet-care/animal-poison-control
- https://www.petpoisonhelpline.com/faq/
- https://www.poison.org/

[S] secondarie: tutti gli altri URL indicati nel testo.

## 12. Incertezze principali (da portare all'avvocato)

1. Soglie per stato (Colorado in conflitto; Connecticut dal 1° lug 2026; Texas SBA).
2. Se i dati clinici dell'animale e quelli personali in essi contenuti ricadono in categorie "sensibili/health" di qualche legge.
3. GDPR e legge USA: quale prevale/si somma; trasferimenti verso fornitori (Groq, Vercel, Google).
4. Se un'app che dà consigli sulla salute di un animale configura esercizio abusivo in qualche stato; se serve un disclaimer specifico per stato.
5. Se la HBNR si estende ai dati sanitari degli animali (sembra di no).
6. Età minima (18 vs maggiore età dello stato).
7. Clausola di arbitrato e limitazione di responsabilità: enforceability varia per stato.
8. Imposte sulle vendite per abbonamenti, e attuale quadro "click-to-cancel" dopo il vacatur.
