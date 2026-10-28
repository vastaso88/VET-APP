> **BOZZA — non è consulenza legale; da rivedere da un solicitor australiano prima della pubblicazione**

# Australia: ricerca normativa per Quokka

Data di consultazione di tutte le fonti: **13/10/2026**. Autrice: sessione «Legale EN-AU». Lingua: italiano (i testi per gli utenti sono nei file 02–05, in inglese australiano).

## Come leggere questo documento

- **Fonte primaria** = sito del regolatore o del governo. **Fonte secondaria** = studio legale o stampa di settore. Dove ho solo fonti secondarie lo scrivo.
- **Non sono riuscita a leggere il testo delle leggi** su legislation.gov.au (nessuna pagina primaria di legge recuperata). I numeri di sezione citati «dalla mia conoscenza» sono marcati *(da verificare)*.
- Dove le fonti si contraddicono o mancano, lo dico in «Incertezze». Non ho inventato norme.
- Data di riferimento: 13/10/2026. Alcune riforme scadono a dicembre 2026 o luglio 2027: **ricontrollare prima del lancio**.

## 1. Privacy Act 1988 e Australian Privacy Principles (APP)

**Chi è coperto.** Il Privacy Act si applica alle agenzie federali e alle organizzazioni con fatturato annuo **superiore a 3 milioni di dollari australiani** (A$); le organizzazioni con fatturato pari o inferiore sono «small business» e in gran parte esenti. *(Fonte primaria: [OAIC, Rights and responsibilities](https://www.oaic.gov.au/privacy/privacy-legislation/the-privacy-act/rights-and-responsibilities), 13/10/2026.)*

**Eccezioni all'esenzione** (la piccola impresa è coperta comunque se, tra l'altro): è un *private sector health service provider*; vende o acquista dati personali; è un credit reporting body; ha fatto opt-in; è collegata a un'impresa coperta; lavora per contratti col governo federale. *(Stessa fonte primaria.)*

**Cosa significa per Quokka.**
- Fatturato in Australia: oggi probabilmente sotto A$3 mln → in teoria esente.
- **Non consiglio di contare sull'esenzione**: (a) la riforma «tranche 2» prevede, secondo fonti secondarie, la rimozione dell'esenzione («agreed in-principle»), ma non ho trovato una fonte primaria che confermi una legge approvata; (b) Apple e Google chiedono informativa e pratiche conformi a prescindere; (c) lo statuto sul *tort* di violazione della privacy vale anche per le piccole imprese (v. sotto); (d) il gruppo è già soggetto al GDPR.
- Il *health service provider* riguarda la salute delle **persone**; l'app tratta salute di **animali**. Dubbio residuo: i dati dell'utente (es. dosaggi che riguardano lui) → chiedere al solicitor. **Incertezza.**
- **Scelta consigliata:** scrivere informativa e processi *come se* gli APP si applicassero (file 02).

**Gli APP.** Sono 13. Ai fini della bozza contano: APP 1 (informativa aperta e trasparente; elenco dei Paesi esteri «se praticabile»), APP 3 (raccolta), APP 5 (avviso al momento della raccolta), APP 6 (uso e comunicazione), APP 7 (marketing diretto), **APP 8 (comunicazione all'estero)**, APP 11 (sicurezza e distruzione), APP 12–13 (accesso e rettifica). *(Fonte primaria: [OAIC, APP](https://www.oaic.gov.au/privacy/australian-privacy-principles) — la pagina raggruppa i principi ma non ne elenca i titoli; i numeri e i titoli qui sopra sono dalla mia conoscenza, da verificare.)*

**APP 8 e fornitori esteri.** Quokka invia dati a Groq (USA?), Vercel, Supabase (Irlanda), Google (Firebase), Nominatim/OSM. Se APP 8 si applica, l'organizzazione che comunica dati all'estero deve in genere adottare misure ragionevoli perché il fornitore rispetti gli APP, e resta responsabile (s 16C) *(da verificare)*. La bozza elenca i Paesi dove noti. **Aperto:** paesi reali di Groq e Vercel (nel file italiano sono ancora «da verificare»).

**Riforme già in vigore: Privacy and Other Legislation Amendment Act 2024.** Assenso reale il 10/12/2024; gran parte delle modifiche in vigore dal giorno dopo; il *tort* statutario per gravi violazioni della privacy in vigore dal **10/06/2025** (fonti secondarie: [MinterEllison](https://www.minterellison.com/articles/privacy-and-other-legislation-amendment-act-2024-now-in-effect), [Landers](https://landers.com.au/legal-insights-news/privacy-milestone-first-tranche-of-privacy-reforms-passed), [McCullough](https://mccullough.com.au/2025/06/23/new-privacy-regulations-and-enforcement-powers/)). Il tort richiede intrusione o uso improprio di informazioni, aspettativa ragionevole di privacy, condotta intenzionale o imprudente, gravità; **non** ho trovato un'esenzione per le piccole imprese.

**Trasparenza sulle decisioni automatizzate.** Le modifiche all'APP 1 sulle decisioni automatizzate scattano 24 mesi dopo l'assenso, cioè il **10/12/2026** (fonti secondarie, stesse di sopra). L'informativa dovrà descrivere le decisioni automatizzate che incidono in modo significativo su diritti o interessi di una persona. La chat di Quokka consiglia, non decide su diritti dell'utente: probabilmente fuori ambito, ma conviene una frase prudente (file 02, sez. 9). **Incertezza:** il testo esatto della soglia «significativo».

**Children's Online Privacy Code.** La legge del 2024 impone all'OAIC di registrare il codice **entro il 10/12/2026**. Bozza (*exposure draft*) pubblicata il 31/03/2026, consultazione chiusa il 05/06/2026; non risulta un codice finale registrato. Nella bozza: consenso del genitore sotto i 15 anni, «interesse superiore del minore»; si applica ai servizi che sono *social media service*, *relevant electronic service* o *designated internet service* ai sensi dell'Online Safety Act 2021. *(Fonti: [OAIC, consultazione](https://www.oaic.gov.au/engage-with-us/consultations/draft-childrens-online-privacy-code-consultation-for-industry,-civil-society,-academia) — primaria, ma la pagina non l'ho letta direttamente, solo tramite la ricerca; [Baker McKenzie](https://www.bakermckenzie.com/en/insight/publications/2026/05/australia-childrens-online-privacy-code-exposure-draft), [Allens](https://www.allens.com.au/insights-news/insights/2026/04/draft-childrens-online-privacy-code-proposed-protections-to-have-material-impact-on-online-services/).)* **Incertezza:** non è chiaro se Quokka rientri; se l'app è 18+ e non è un social, probabilmente no, ma la definizione di *relevant electronic service* è ampia. Da chiedere al solicitor.

**Notifiable Data Breaches (NDB).** Le entità coperte devono notificare OAIC e persone interessate per una violazione probabilmente causa di «serious harm». *(Fonte primaria: [OAIC, NDB](https://www.oaic.gov.au/privacy/notifiable-data-breaches).)* La pagina letta non riporta il termine di valutazione; dalla mia conoscenza è di **30 giorni** per valutare un sospetto *(da verificare)*. Prevedere una procedura interna (file 02, sez. 12).

**Regolatore.** OAIC (Office of the Australian Information Commissioner). Reclami: prima all'organizzazione, poi all'OAIC.

## 2. Spam Act 2003 e Do Not Call Register

- **Spam Act:** i messaggi elettronici commerciali (email, SMS) richiedono **consenso**, identificazione del mittente e **funzione di disiscrizione funzionante**. La disiscrizione ha effetto entro **5 giorni lavorativi** dall'invio della richiesta. Una disiscrizione che richiede login o dati aggiuntivi è stata ritenuta non conforme. *(Fonti secondarie: [Corrs](https://www.corrs.com.au/insights/acma-spam-act-enforcement-and-the-implications-for-business); citazione di [ACMA, indagine CBA](https://acma.gov.au/sites/default/files/2023-06/Investigation%20report%20-%20Commonwealth%20Bank%20of%20Australia.pdf).)* L'importo massimo delle sanzioni: **non verificato**.
- **Effetto su Quokka:** il consenso `marketing_email` deve essere opt-in vero (già così) e **ogni email commerciale** deve avere un link di disiscrizione senza login. Anche le notifiche push promozionali: da chiedere al solicitor se il Spam Act le copre (copre messaggi «elettronici»; push non è chiaramente trattata nelle fonti che ho letto). **Incertezza.**
- **Do Not Call Register:** vale per le **telefonate** di telemarketing verso numeri registrati; le liste vanno ripulite ogni 30 giorni. *(Fonte: [donotcall.gov.au, FAQ](https://www.donotcall.gov.au/industry/industry-faqs), 13/10/2026; orari consentiti: non verificati.)* Quokka oggi non fa telemarketing → **non rilevante**, da riaprire se si farà.

## 3. Australian Consumer Law (ACL)

Tutte le citazioni di sezione sono dalla mia conoscenza *(da verificare sul testo del Competition and Consumer Act 2010, Sch. 2)*.

- **Garanzie dei consumatori** (qualità accettabile, idoneità allo scopo, corrispondenza alla descrizione; per i servizi, *due care and skill*): non si possono escludere (s 64). L'ACCC ha confermato che si applicano ai prodotti digitali e che clausole che negano le garanzie sono ingannevoli. *(Fonti primarie: ACCC su [Sony, A$3,5 mln](https://www.accc.gov.au/media-release/sony-to-pay-35-million-penalty-for-misrepresenting-playstation-gamers-rights) e su [Apple Australia](https://www.accc.gov.au/media-release/apple-australia-gives-undertaking-to-accc-to-improve-its-consumer-guarantees-policies-and-practices).)* → i Termini (file 03) devono dirlo.
- **Pratiche ingannevoli** (s 18, s 29): l'avviso IA e le affermazioni sull'accuratezza non devono essere esagerati.
- **Prezzo unico** (s 48): prezzo mostrato come cifra unica comprensiva di GST 10% e commissioni obbligatorie. *(Fonti secondarie, es. [Lawpath](https://lawpath.com.au/blog/is-it-legal-to-advertise-prices-without-including-gst).)* → prezzi in A$ **inclusivi di GST**.
- **Recensioni:** l'ACCC ha una guida del 2013 su recensioni false/pagate/omesse. *(Fonte primaria: [ACCC](https://www.accc.gov.au/media-release/accc-releases-guidance-about-online-product-reviews); la guida potrebbe essere stata aggiornata: non verificato.)* Quokka non ha recensioni di prodotto, ma ha **stelle e segnalazioni sulle aree cani e sui luoghi** → rispettare i principi (trasparenza dei rapporti commerciali, niente rimozione selettiva dei voti negativi).
- **Clausole abusive nei contratti standard** (s 23): sanzioni attive dal 2023 *(dalla mia conoscenza)*. Evitare: modifica unilaterale senza avviso, rinnovi automatici nascosti, penali di recesso.
- **Abbonamenti e prova gratuita:** il *Competition and Consumer Amendment (Unfair Trading Practices) Bill 2026* risulta approvato; vieta pratiche sleali, il *drip pricing* e le *subscription traps* **dal 01/07/2027**; si applica ai contratti conclusi dopo quella data e a quelli rinnovati o modificati. Risulta anche il raddoppio delle sanzioni (fino a A$100 mln per violazione). *(Fonti secondarie: [K&L Gates](https://www.klgates.com/thought-leadership/Significant-Changes-for-Australian-Competition-and-Consumer-Laws-Doubling-of-Penalties-to-AU100-Million-Per-Offence-and-Unfair-Trading-Practices-to-Be-Prohibited-4-13-2026), [HWL Ebsworth](https://hwlebsworth.com.au/acl-updates-new-unfair-trading-practices-laws-to-apply-from-2027/), [Hall & Wilcox](https://hallandwilcox.com.au/news/new-consumer-law-reforms-for-unfair-trading-practices-pricing-and-subscription-contracts/).)* **Verificare il testo della legge approvata.** Pratica già sanzionata oggi: caso JustAnswer (A$10 mln) per mancata informazione anticipata sui costi ricorrenti *(stampa di settore: [ACS Information Age](https://ia.acs.org.au/article/2026/justanswer-fined--10m-as-subscription-traps-banned.html))*.
- **Effetto su Quokka:** la prova gratuita di 10 giorni deve dire **in anticipo** cosa succede dopo, il prezzo in A$ e come annullare; nessun addebito automatico senza passaggio dedicato (già principio del documento italiano 04).

## 4. Online Safety Act 2021 e eSafety

- **Età minima per i social (dal 10/12/2025):** le piattaforme «age-restricted» devono prendere misure ragionevoli per impedire account a under 16. eSafety ha elencato Facebook, Instagram, Kick, Reddit, Snapchat, Threads, TikTok, Twitch, X, YouTube; ha detto che Discord, GitHub, Messenger, Roblox, Steam, YouTube Kids non rientrano. Sanzioni fino a A$49,5 mln per la piattaforma. *(Fonte primaria: [eSafety](https://esafety.gov.au/young-people/social-media-age-restrictions), tramite ricerca; [Dept. Infrastructure](https://www.infrastructure.gov.au/department/media/news/minimum-age-social-media-access).)* La legge è l'Online Safety Amendment (Social Media Minimum Age) Act 2024 *(dalla mia conoscenza)*.
- **Quokka non è una piattaforma social** (scopo: gestione animali). Ma ha contenuti degli utenti (segnalazioni, stelle) e potrebbe essere letta come servizio con «interazione sociale». **Incertezza**, probabilmente fuori ambito; il 25/03/2026 il Ministro ha registrato una nuova regola per servizi con design dannoso/che crea dipendenza *(fonte secondaria della ricerca; non letta)*.
- **Codici di settore Phase 2 (dal 09/03/2026):** si applicano, tra gli altri, a social, *relevant electronic services*, *designated internet services*, app store, e includono **chatbot IA «compagni»** e materiale generato da IA. Richiedono valutazione del rischio e, dove serve, *age assurance*. *(Fonti: [eSafety, fact sheet aprile 2026](https://www.esafety.gov.au/sites/default/files/2026-04/Age-restricted-Material-Codes-fact-sheet-April2026.pdf) — non letto direttamente; [Bird & Bird](https://cm.twobirds.com/en/insights/2025/australia/digital-duty-of-care-what-phase-2-esafety-codes-demand-from-providers).)* Quokka non è un chatbot compagno; la chat veterinaria è limitata al dominio. **Incertezza:** se la chat generativa sia comunque *designated internet service* con obblighi. Da chiedere al solicitor.
- **Contenuti degli utenti:** prevedere una funzione di segnalazione di contenuti e una politica di rimozione (già in parte nelle regole `contribution_rules`). Le *Basic Online Safety Expectations* e gli schemi di reclamo non ho verificato come si applicano a Quokka: **non verificato**.

## 5. Intelligenza artificiale

- **Nessun obbligo di legge generale specifico per l'IA** in Australia: il Piano nazionale per l'IA (02/12/2025) ha messo in pausa le «mandatory guardrails» e si affida alle leggi esistenti. *(Fonti secondarie: [MinterEllison](https://www.minterellison.com/articles/australia-introduces-a-national-ai-plan-four-things-leaders-need-to-know), [AdNews](https://www.adnews.com.au/news/australia-pauses-ai-guardrails-and-goes-with-a-national-plan).)* Nessuna regola equivalente all'art. 50 dell'AI Act sul badge.
- **Linee guida volontarie:** *Guidance for AI Adoption* (DISR/NAIC, 21/10/2025), sei pratiche essenziali (responsabilità, impatti, rischi, informazioni, test e monitoraggio, controllo umano). *(Fonte primaria: [industry.gov.au](https://www.industry.gov.au/publications/guidance-for-ai-adoption).)*
- **OAIC, guida sui prodotti di IA commerciali (21/10/2024):** gli obblighi privacy valgono per ciò che si immette e per ciò che l'IA genera (anche inferenze o «allucinazioni» su persone identificabili); trasparenza in informativa; consiglio di **non inserire dati personali in chatbot pubblici**; valutare l'impatto sulla privacy (PIA). *(Fonte primaria: [OAIC](https://www.oaic.gov.au/privacy/privacy-guidance-for-organisations-and-government-agencies/guidance-on-privacy-and-the-use-of-commercially-available-ai-products), letta tramite ricerca.)*
- **Effetto su Quokka:** mantenere il badge IA (buona pratica, non obbligo); dichiarare in informativa che si usa un fornitore di IA estero; avviso sul fatto che la risposta può essere errata (file 05); fare una PIA interna.

## 6. Veterinaria: regole statali e territoriali

L'Australia non ha un regolatore nazionale dei veterinari: ogni stato/territorio ha leggi e un *board*. L'AVA nota che la definizione di «atto di scienza veterinaria» e di rapporto *bona fide* veterinario–cliente–paziente (VCPR) può variare. *(Fonte primaria di sintesi: [AVA, Telemedicine practice](https://www.ava.com.au/policy/telemedicine-practice), letta tramite ricerca.)*

| Stato / territorio | Cosa ho trovato (fonte) | Affidabilità |
|---|---|---|
| **NSW** | Veterinary Practitioners Board, linea guida «Technology-based patient consultations» (aprile 2019): diagnosticare via video/telefono è un atto *ristretto*; serve un veterinario registrato in NSW; il veterinario deve ritenere la consulenza appropriata e non dannosa per l'animale. Il Veterinary Practice Act 2003 vieta agli **non registrati** di compiere atti ristretti. È in corso una revisione dell'Act. [AVA PDF](https://www.ava.com.au/siteassets/resources/coronavirus/nsw---technology-based-patient-consultations.pdf) | Media: documento 2019, non verificato se aggiornato |
| **VIC** | Veterinary Practitioners Registration Board, Guideline 13 «Telemedicine»: solo dove esiste già un rapporto veterinario–proprietario–animale; stesso standard di una visita in presenza. [Board](https://www.vetboard.vic.gov.au/VPRBV/VPRBV_Guidelines/Guideline_13_-_Telemedicine_in_the_provision_of_veterinary_services.aspx) | Buona (testo letto in parte) |
| **QLD** | Veterinary Surgeons Board: serve un rapporto *bona fide*; il cliente va informato dei limiti e il consenso registrato. [Board](https://www.vsb.qld.gov.au/for-vets/guidelines-and-policies/guidelines/veterinary-telemedicine) | Media: pagina non apribile, letta via sintesi di ricerca |
| **WA** | Veterinary Surgeons' Board: rapporto *bona fide*; il veterinario deve poter fare almeno una diagnosi preliminare; disponibile per il seguito. [AVA PDF](https://www.ava.com.au/siteassets/resources/coronavirus/wa---guidelines-on-veterinary-telemedicine.pdf) | Media |
| **SA** | VSRBSA: telemedicina solo con VCPR esistente, **salvo emergenza** fino alla visita fisica; senza VCPR i consigli restano generali, non su un animale specifico, **senza diagnosi né trattamento**. Non copre le prescrizioni. [VSRBSA](https://vsrb.sa.gov.au/information-sheet/telemedicine/) | **Alta** (testo letto) |
| **TAS** | Documento dell'epoca COVID: la telemedicina «non è prevista» dagli standard; giudizio professionale. [AVA PDF](https://www.ava.com.au/siteassets/resources/coronavirus/tas---using-veterinary-telemedicine.pdf) | Bassa: datato |
| **ACT** | Solo un avviso COVID del Veterinary Practitioners Board; linee guida successive non trovate. [AVA PDF](https://www.ava.com.au/siteassets/resources/coronavirus/act-vpb---advice-regarding-telemedicine.pdf) | Bassa |
| **NT** | Veterinary Board, «Guideline on Veterinary Telemedicine» (rev. luglio 2020, prossima revisione prevista luglio 2023): veterinario registrato nel territorio; la telemedicina non sostituisce la visita quando è ragionevole. [NT](https://dpir.nt.gov.au/__data/assets/pdf_file/0011/909065/telemedicine.pdf) | Media: datato |

**Sintesi per un'app non veterinaria.** Tutte queste regole disciplinano i **veterinari registrati**. Quokka non è un veterinario. Il rischio è che un'app che «diagnostica» o prescrive per un animale specifico venga letta come esercizio non autorizzato della veterinaria (almeno in NSW, dove la diagnosi è atto ristretto). Perciò la bozza (file 05) dice: informazioni generali, orientamento verso un veterinario, nessuna diagnosi, nessuna prescrizione né dosaggio di farmaci su prescrizione, e in caso di sintomi gravi «vai da un veterinario ora». Ho **inferito** questo rischio; **non ho trovato** una fonte che dica espressamente che un'app di IA infrange le leggi statali: da chiedere a un solicitor locale (domanda 5). Le leggi statali (nomi e testo) non le ho lette.

## 7. Requisiti Apple e Google per l'Australia

- **Apple:** dal **24/02/2026** in Australia, Brasile e Singapore, l'App Store blocca il download di app con rating **18+** a chi non è stato confermato adulto. La **Declared Age Range API** è disponibile; gli sviluppatori restano «solely responsible» per la conformità. Si può alzare il rating oltre il questionario. *(Fonti secondarie: [ACS Information Age](https://ia.acs.org.au/article/2026/apple-begins-app-store-age-checks-in-australia.html), [TechRepublic](https://www.techrepublic.com/article/news-apple-expands-age-verification-api-global-compliance/); non ho letto la pagina Apple.)*
- **Google:** la **Play Age Signals API** doveva partire in Australia e Canada a metà agosto 2026. **Non ho potuto confermare** che sia in funzione. *(Fonti: [MLex](https://www.mlex.com/mlex/data-privacy-security/articles/2507516/google-play-rolls-out-age-range-tools-to-australia-canada-ahead-of-global-launch), [Biometric Update](https://www.biometricupdate.com/202608/google-rolls-out-play-age-signals-api-as-age-assurance-ecosystem-evolves).)*
- **Requisiti generali degli store** (non specifici per l'Australia; dalla mia conoscenza, già presenti nel progetto per UE/Italia): link all'informativa, dichiarazioni sulla raccolta dati (Apple *privacy nutrition labels*, Google *Data safety*), cancellazione dell'account dentro l'app, rating per età coerente. Non ho trovato pagine primarie Apple/Google specifiche per l'Australia.
- **Prezzi:** i piani si vendono in A$ via tier di Apple/Google; il prezzo mostrato è già inclusivo di GST. Verificare in App Store Connect / Play Console i livelli di prezzo disponibili in A$.

## 8. Incertezze riassunte

1. Soglia: fatturato di Quokka vs A$3 mln; dubbio sul *health service provider*.
2. Stato effettivo della riforma «tranche 2» (esenzione piccole imprese) → solo fonti secondarie.
3. Se Quokka rientra nel Children's Online Privacy Code e nei codici eSafety Phase 2.
4. Testo e commencement della legge sulle pratiche sleali/abbonamenti (01/07/2027).
5. Rischio «atto di veterinaria» per un'app di IA: inferito, non fonte diretta; leggi statali non lette.
6. Linee guida TAS, ACT, NT datate; NSW 2019.
7. Importi massimi delle sanzioni (Spam Act, Privacy Act): non verificati.
8. Numeri RSPCA: vedi file 06 (discrepanze).
9. Paesi reali dei fornitori (Groq, Vercel).

## 9. Prossimi controlli suggeriti (prima del lancio)

- Riaprire OAIC (codice minori, tranche 2), eSafety (elenco piattaforme e codici), Federal Register of Legislation (UTP Act), AVA e board statali.
- Far leggere i file 02–05 a un solicitor australiano.
