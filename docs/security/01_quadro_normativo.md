# VetApp — Quadro normativo di sicurezza e privacy

**Versione:** 1.0 — aggiornato al **26 ottobre 2026**
**Autore:** ricerca interna (assistente IA), da far validare a un legale
**Ambito:** app VetApp (client Flutter Android/web + backend FastAPI + Supabase + Groq + Firebase/Google Play)

---

## 1. Introduzione

### 1.1 Cos'è questo documento

È la mappa delle **regole che VetApp deve (o dovrà) rispettare** in materia di protezione dei dati personali, sicurezza informatica, intelligenza artificiale e distribuzione su Google Play, per ciascuno dei Paesi in cui l'app è o sarà disponibile (Italia oggi; Regno Unito, Irlanda, USA, Australia, Spagna, Germania, Austria, Svizzera, Francia, Belgio in futuro).

Per ogni norma dice: **se si applica a VetApp**, **da quando**, **cosa comporta in pratica** e **chi deve confermarlo**. Serve come base per: la DPIA (vedi §3.a), il registro dei trattamenti, l'informativa privacy, i contratti con i fornitori, la checklist di sicurezza tecnica e il piano di risposta agli incidenti (documenti successivi di `docs/security/`).

### 1.2 Disclaimer

> **Questo documento NON è consulenza legale.** È una ricerca preparatoria scritta da un non-giurista, con fonti ufficiali verificate alla data indicata. Le conclusioni contrassegnate ⚠️ e tutte le voci "da verificare" devono essere confermate da un avvocato specializzato in privacy/IT prima di essere usate per decisioni vincolanti. Le norme cambiano: la data di aggiornamento in testa va controllata prima di ogni riuso.

### 1.3 Legenda

| Simbolo | Significato |
|---|---|
| ✅ | **Obbligo certo**: si applica a VetApp già oggi (o da una data certa indicata) |
| ⚠️ | **Probabile o da confermare**: dipende da un'interpretazione, da un fatto futuro (es. lancio in un Paese) o da un dettaglio non verificabile online |
| ❌ | **Non applicabile oggi**: non si applica nella situazione attuale; indicato cosa la farebbe scattare |

### 1.4 Chi è chi: i termini che useremo (spiegati una volta sola)

- **Dato personale**: qualsiasi informazione riferita a una persona fisica identificata o identificabile (email, nome, posizione GPS, foto in cui si vede il proprietario, IP...). I dati dell'**animale** da soli non sono dati personali; lo diventano quando sono collegati al proprietario (quasi sempre, in VetApp).
- **Interessato**: la persona a cui i dati si riferiscono (l'utente di VetApp, ma anche il veterinario citato in un referto).
- **Titolare del trattamento** ("controller"): chi decide *perché* e *come* si trattano i dati. Oggi è **il proprietario di VetApp come persona fisica** (non c'è ancora una società); quando nascerà la società, sarà lei.
- **Responsabile del trattamento** ("processor"): chi tratta i dati *per conto* del titolare e seguendo le sue istruzioni (Supabase, Vercel, Groq, Google/Firebase).
- **Sub-responsabile**: fornitore del fornitore (es. AWS per Supabase, Google Cloud per Groq).
- **DPA** (Data Processing Agreement / Addendum): il contratto obbligatorio tra titolare e responsabile (art. 28 GDPR).
- **DPO** (Data Protection Officer): figura interna o esterna che vigila sulla conformità; obbligatoria solo in certi casi (art. 37 GDPR).
- **DPIA** (Data Protection Impact Assessment, "valutazione d'impatto"): analisi documentata dei rischi di un trattamento per le persone, obbligatoria quando il rischio è "elevato" (art. 35 GDPR).
- **Registro dei trattamenti**: elenco interno di tutti i trattamenti svolti (art. 30 GDPR).
- **Trasferimento extra-UE**: invio di dati personali fuori dallo Spazio Economico Europeo (SEE) — incluso il semplice *accesso* da un Paese terzo.
- **SCC** (Standard Contractual Clauses, "clausole contrattuali standard"): contratto-tipo approvato dalla Commissione UE (decisione 2021/914) che legittima i trasferimenti extra-UE.
- **DPF** (EU-U.S. Data Privacy Framework): accordo UE-USA per cui le aziende americane *autocertificate* sono considerate "adeguate" (decisione della Commissione del 10 luglio 2023). Esistono anche l'estensione UK e la versione svizzera.
- **TIA** (Transfer Impact Assessment): analisi documentata del rischio che le autorità del Paese di destinazione accedano ai dati; richiesta quando si usano le SCC.
- **Autorità di controllo**: l'ente pubblico che vigila (Italia: Garante per la protezione dei dati personali, "Garante"; UK: ICO; Svizzera: IFPDT/FDPIC; Australia: OAIC; Irlanda: DPC; Spagna: AEPD; Francia: CNIL; Belgio: APD/GBA; Austria: DSB; Germania: autorità dei Länder).
- **Rappresentante** (art. 27 GDPR / UK GDPR / art. 14 LPD svizzera): persona o società nominata in un Paese in cui il titolare non ha sede, come punto di contatto per utenti e autorità.
- **Data breach** ("violazione dei dati personali"): incidente di sicurezza che causa distruzione, perdita, modifica, divulgazione o accesso non autorizzato ai dati.

---

## 2. Tabella riassuntiva

| Norma | Si applica? | Da quando | Cosa comporta (una riga) | Chi lo conferma |
|---|---|---|---|---|
| **GDPR** (Reg. UE 2016/679) | ✅ | 25 mag 2018 | Base legale, informativa, diritti, sicurezza, registro, DPA con i fornitori, breach entro 72 h | Legale privacy |
| GDPR art. 35 — **DPIA** | ✅ (conclusione motivata in §3.a) | prima di lanciare tracciamento GPS e chat IA in produzione | Documento di valutazione d'impatto da redigere e aggiornare | Legale + owner |
| GDPR art. 30 — **registro** | ✅ | subito | Registro dei trattamenti (l'esenzione <250 dipendenti non vale: trattamento non occasionale) | Legale |
| GDPR art. 37 — **DPO** | ❌ (probabile) | — | Non obbligatorio oggi; rivalutare se il monitoraggio diventa "su larga scala" | Legale |
| GDPR art. 27 — **rappresentante** | ❌ in UE (titolare stabilito in Italia) / ⚠️ UK, CH dopo il lancio | al lancio | Nomina rappresentante UK; CH solo se condizioni cumulative | Legale |
| **Trasferimenti extra-UE** (Capo V GDPR) | ✅ | subito | DPF per Google e Vercel; SCC + TIA per Supabase e Groq | Legale |
| **Codice privacy** (d.lgs. 196/2003 mod. d.lgs. 101/2018) | ✅ | 19 set 2018 | Età minima 14 anni per consenso ai servizi online; cookie art. 122; procedura breach online del Garante | Legale |
| **NIS2** (Dir. 2022/2555, d.lgs. 138/2024) | ❌ | — | Non applicabile: sotto le soglie dimensionali; rivalutare se ≥50 dipendenti o >10 M€ e marketplace | Legale / ACN |
| **Cyber Resilience Act** (Reg. UE 2024/2847) | ⚠️ probabile | obblighi di segnalazione dall'11 set 2026; piena applicazione 11 dic 2027 | App = "prodotto con elementi digitali" se messa sul mercato commercialmente; policy vulnerabilità, SBOM, aggiornamenti, supporto | Legale (interpretazione "messa sul mercato") |
| **AI Act** (Reg. UE 2024/1689, mod. Reg. UE 2026/1744) | ✅ art. 50 (chatbot) | 2 ago 2026 (già in vigore) | Dire chiaramente all'utente che parla con un'IA; non è alto rischio | Legale |
| **ePrivacy / cookie** (Dir. 2002/58, art. 122 Codice, Linee guida Garante 2021) | ✅ | subito | localStorage di sessione esente; analytics/marketing solo con consenso; push con opt-in | Legale |
| **UK GDPR + DPA 2018 + DUAA 2025** | ⚠️ al lancio UK | lancio UK | Rappresentante UK, fee ICO (£52/anno tier 1), breach 72 h, IDTA/Addendum o UK-DPF | Legale UK |
| **Svizzera nLPD** | ⚠️ al lancio CH | lancio CH | Informativa, breach "al più presto" all'IFPDT, rappresentante solo se condizioni cumulative, Swiss-US DPF | Legale CH |
| **Australia Privacy Act 1988** | ❌ probabile (small business ≤3 M AUD) | lancio AU | Esente salvo eccezioni; attenzione a Children's Online Privacy Code (entro 10 dic 2026) e tort privacy (10 giu 2025) | Legale AU |
| **USA — CCPA/CPRA e leggi statali** | ❌ oggi | — | Soglie non raggiunte; ma leggi breach di tutti i 50 Stati scattano se esposte credenziali; COPPA se <13 anni; FTC Act §5 | Legale US |
| **IE, ES, DE, AT, FR, BE** (leggi nazionali) | ⚠️ al lancio | lancio | Età consenso: IE 16, ES 14, DE 16, AT 14, FR 15, BE 13; sportello unico (Garante capofila) | Legale |
| **Google Play** (policy) | ✅ | pubblicazione | Data safety, User Data policy, cancellazione account in-app + web, target API 36, verifica sviluppatore/D-U-N-S, dichiarazioni permessi | Owner (Play Console) |
| **OWASP MASVS/MASTG, ASVS 5.0, Top 10 2025, LLM Top 10 2025** | ✅ (standard tecnici, non leggi) | subito | Riferimento per la checklist di sicurezza e i test | Team tecnico |

---

## 3. Sezioni dettagliate

### 3.a GDPR — Regolamento (UE) 2016/679

**Applicabilità: ✅ certa.** Il titolare è stabilito in Italia (art. 3(1)); si applica a *tutti* gli utenti, ovunque siano, e in più agli utenti UE anche quando il titolare non fosse in UE (art. 3(2)). In vigore dal 25 maggio 2018.

Fonte: testo consolidato su EUR-Lex — <https://eur-lex.europa.eu/eli/reg/2016/679/oj> (consultato 26/10/2026).

#### Art. 5(1)(f) — Integrità e riservatezza

I dati vanno trattati "in maniera da garantire un'adeguata sicurezza", compresa la protezione da trattamenti non autorizzati o illeciti e da perdita, distruzione o danno accidentali. È un *principio*: le misure concrete sono all'art. 32. Per VetApp significa, ad esempio: nessun referto veterinario leggibile da altri utenti (controllo accessi riga per riga con Row Level Security su Supabase), backup, HTTPS ovunque.

#### Art. 25 — Privacy by design e by default

Le tutele vanno progettate *dentro* il prodotto fin dall'inizio (by design) e le impostazioni predefinite devono essere le più protettive (by default). In pratica per VetApp:
- raccolta minima: la posizione si chiede solo quando serve (mappa, passeggiata), il telefono è facoltativo;
- impostazioni predefinite: analytics spento finché l'utente non acconsente, posizione manuale preferita al GPS continuo se possibile, condivisione dei referti disattivata;
- conservazione limitata: definire per ogni dato quanto tempo si tiene (es. tracce GPS delle passeggiate: X mesi, poi cancellazione o aggregazione).
- Riferimento utile: EDPB, Linee guida 4/2019 su art. 25 — <https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-42019-article-25-data-protection-design-and_en>.

#### Art. 32 — Sicurezza del trattamento

Chiede misure "adeguate" al rischio, tenendo conto di stato dell'arte, costi, natura dei dati. Il GDPR non impone una lista chiusa, ma nomina esplicitamente: **pseudonimizzazione e cifratura**; capacità di assicurare **riservatezza, integrità, disponibilità e resilienza**; capacità di **ripristinare** l'accesso ai dati dopo un incidente; una **procedura per testare e valutare regolarmente** l'efficacia delle misure.

Cosa è "adeguato" per una piccola app con dati di posizione e referti (proposta operativa, da trasformare nella checklist tecnica):
- **Cifratura**: TLS 1.2+ su ogni connessione; dati a riposo cifrati (Supabase/AWS lo fa di default — da verificare nel piano scelto); file sensibili (referti) in bucket privati con URL firmati a scadenza breve.
- **Pseudonimizzazione**: nella chat IA inviare a Groq solo ciò che serve (specie, età, sintomi), **non** email, nome, posizione esatta, nome del veterinario; separare identificativi utente da contenuti dove possibile.
- **Controllo accessi**: RLS Supabase su ogni tabella; principio del minimo privilegio per le chiavi di servizio; MFA sugli account amministrativi (Supabase, Vercel, Google, Groq, GitHub).
- **Test**: scansione dipendenze (Dependabot/`pip-audit`), test automatici di autorizzazione (utente A non legge dati di B), almeno un penetration test prima del lancio pubblico.
- **Ripristino**: backup automatici (verificare retention nel piano Supabase), prova di restore documentata almeno una volta.
- **Log e monitoraggio**: log degli accessi amministrativi; allarmi su errori 401/403 anomali.
- Riferimenti: ENISA, *Cybersecurity guide for SMEs — 12 steps* (28/06/2021) — <https://www.enisa.europa.eu/publications/cybersecurity-guide-for-smes>; OWASP (vedi §3.n).

#### Artt. 33–34 — Violazioni dei dati personali (data breach)

- **Art. 33(1)**: il titolare notifica al Garante **entro 72 ore** da quando ne viene a conoscenza, salvo che la violazione sia improbabile che presenti un rischio per le persone. Se si notifica in ritardo, vanno motivate le ragioni.
- **Art. 33(2)**: il **responsabile** (Supabase, Vercel, Groq, Google) deve avvisare il titolare "senza ingiustificato ritardo". Tempi contrattuali verificati: Supabase DPA "senza ingiustificato ritardo e, ove possibile, entro 48 ore" (cl. 10, versione 1/8/2026); Groq DPA "entro 72 ore" (eff. 15/10/2025); Vercel DPA "senza ingiustificato ritardo" (eff. 31/3/2026); Google/Firebase Data Processing Terms "promptly and without undue delay" (§7.2.1, agg. 21/8/2024). **Nota pratica**: se Supabase avvisa dopo 48 ore, al titolare restano 24 ore: serve una procedura pronta.
- **Art. 33(5)**: **registro interno delle violazioni**, obbligatorio *per ogni* violazione, anche quelle non notificate (conferma Garante, pagina data breach).
- **Art. 34**: se il rischio per le persone è **elevato** (es. referti con nome e indirizzo esposti, tracce GPS di casa esposte, credenziali rubate), si comunica anche **agli interessati**, salvo che i dati fossero cifrati/incomprensibili o siano state prese misure che azzerano il rischio.
- **Come si notifica in Italia**: procedura telematica obbligatoria dal 1° luglio 2021 sul portale servizi del Garante: <https://servizi.gpdp.it/databreach/s/> (provv. 27 maggio 2021, n. 209). Pagina informativa con facsimile e strumento di autovalutazione: <https://www.garanteprivacy.it/it/data-breach> (consultata 26/10/2026).
- Linee guida EDPB 9/2022 (v2.0, 28/3/2023) — <https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-92022-personal-data-breach-notification-under-gdpr_en>. Nota importante per il futuro: se il titolare fosse *fuori* UE (non è il caso oggi), dovrebbe notificare a *ogni* autorità degli Stati con interessati coinvolti (par. 73).
- ⚠️ **Proposta in corso**: il pacchetto "Digital Omnibus" (proposta COM del 19/11/2025, procedura 2025/0360(COD)) prevede di alzare la soglia a "rischio elevato" e portare il termine a **96 ore**; al 26/10/2026 **non è adottato** (Consiglio in fase di mandato negoziale, ottobre 2026). Resta **72 ore**. Da verificare periodicamente su <https://oeil.secure.europarl.europa.eu/>.

#### Art. 35 — DPIA (valutazione d'impatto)

Obbligatoria quando un trattamento "può presentare un rischio elevato" (art. 35(1)), in particolare per valutazioni sistematiche, dati particolari su larga scala, sorveglianza sistematica (art. 35(3)). Due strumenti ufficiali aiutano a decidere:

**1) I 9 criteri delle Linee guida WP248 rev.01** (Gruppo art. 29, 4/10/2017, fatte proprie dall'EDPB — <https://ec.europa.eu/newsroom/article29/items/611236>): se ne ricorrono **almeno due**, la DPIA è di regola necessaria.

| # | Criterio WP248 | VetApp | Ricorre? |
|---|---|---|---|
| 1 | Valutazione o scoring (profilazione, previsione), incl. "ubicazione o spostamenti" | Grafico crescita/peso, "radar" servizi vicini, suggerimenti chat basati sui sintomi | ⚠️ parziale |
| 2 | Decisioni automatizzate con effetti giuridici o significativi | Nessuna decisione automatica sull'utente; la chat non diagnostica | No |
| 3 | Monitoraggio sistematico | **Tracce GPS delle passeggiate**, posizione utente, storico | **Sì** |
| 4 | Dati sensibili o "di natura estremamente personale" (incl. dati di localizzazione, comunicazioni) | Tracce GPS = rivelano casa, abitudini; chat = testi personali | **Sì** |
| 5 | Trattamento su larga scala | Migliaia di utenti il primo anno: non "larga scala" secondo WP243, ma può diventarlo | No (oggi) |
| 6 | Combinazione/incrocio di dataset | Posizione + referti + foto + marketplace nello stesso profilo | ⚠️ parziale |
| 7 | Interessati vulnerabili | Minori possibili (vedi età consenso); referti contengono dati del veterinario (terzo) | ⚠️ parziale |
| 8 | **Uso innovativo di tecnologie** | **Chat con LLM (Groq) su sintomi dell'animale** | **Sì** |
| 9 | Il trattamento impedisce l'esercizio di un diritto o un servizio | No | No |

**2) L'elenco del Garante** (provv. 11 ottobre 2018, n. 467, G.U. n. 269 del 19/11/2018; doc. web 9058979 — <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/9058979>; allegato con i 12 tipi: doc. web 9059358). Tra le 12 tipologie soggette a DPIA figurano, per quanto rilevante qui: trattamenti valutativi/di profilazione anche tramite app riferiti a "ubicazione o spostamenti" (n. 1); trattamenti su larga scala di dati "aventi carattere estremamente personale", tra cui i **dati di geolocalizzazione** (n. 4); trattamenti non occasionali di dati di **soggetti vulnerabili**, inclusi minori (n. 6); trattamenti con **tecnologie innovative** (es. **intelligenza artificiale**, IoT) quando ricorre almeno un altro criterio WP248 (n. 7). *(Numerazione e formulazione esatte: da verificare sul PDF dell'allegato, che non è stato leggibile automaticamente.)*

**Conclusione: ✅ la DPIA serve.** Ricorrono almeno tre criteri WP248 (monitoraggio sistematico della posizione, dati di localizzazione "estremamente personali", uso innovativo di IA) e due voci dell'elenco del Garante (geolocalizzazione; tecnologie innovative con altro criterio). Va redatta **prima** di mettere in produzione il tracciamento passeggiate e la chat IA (art. 35(1): "prima di procedere al trattamento") e aggiornata a ogni cambiamento rilevante (nuovo fornitore IA, nuova funzione di condivisione). Non serve la consultazione preventiva del Garante (art. 36) se le misure riducono il rischio residuo a un livello accettabile.

Contenuto minimo (art. 35(7)): descrizione del trattamento e finalità; necessità e proporzionalità; valutazione dei rischi per le persone; misure previste. Il Garante mette a disposizione il software PIA della CNIL (gratuito): <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/8630369>.

#### Art. 30 — Registro dei trattamenti

Art. 30(5) esenta le imprese con **meno di 250 dipendenti**, **a meno che** il trattamento: presenti un rischio per le persone, **non sia occasionale**, o riguardi dati particolari/penali. Il trattamento di VetApp è il cuore del servizio e quindi **non occasionale** → ✅ **il registro serve comunque** (anche per il titolare persona fisica). Contenuto: finalità, categorie di interessati e di dati, destinatari, trasferimenti extra-UE, tempi di conservazione, descrizione delle misure di sicurezza. Il Garante offre modelli per PMI: <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/9047529>.

⚠️ Proposta "Omnibus IV" (COM(2025) 501, 21/5/2025, procedura 2025/0130(COD)): alzerebbe l'esenzione a <750 dipendenti e toglierebbe il criterio "non occasionale", mantenendo l'obbligo per i trattamenti ad alto rischio (cioè quelli che richiedono DPIA). Al 26/10/2026 non risulta adottata (fonte: EDPB-EDPS Joint Opinion 1/2025, 8/7/2025 — <https://www.edpb.europa.eu/our-work-tools/our-documents/edpbedps-joint-opinion/edpb-edps-joint-opinion-012025-proposal-regulation-european_en>). Anche se passasse, VetApp dovrebbe tenerlo perché fa trattamenti soggetti a DPIA.

#### Art. 28 — Contratti con i responsabili (DPA)

Ogni fornitore che tratta dati per conto di VetApp deve essere vincolato da un contratto con i contenuti dell'art. 28(3) (istruzioni, riservatezza, sicurezza, sub-responsabili, assistenza, cancellazione, audit). I quattro fornitori offrono DPA "click-through" già conformi; vanno **accettati e archiviati** (PDF con data):

| Fornitore | DPA | Entità contraente | Meccanismo trasferimento | Sub-responsabili |
|---|---|---|---|---|
| Supabase | <https://supabase.com/legal/customer-resources/data-processing-addendum> (v.1, 1/8/2026) | Supabase Pte. Ltd. (Singapore); Supabase Inc. (USA) per supporto | SCC 2021/914 mod. 2 e 3 + UK Addendum + Swiss addendum | <https://supabase.com/legal/customer-resources/subprocessor-list> |
| Vercel | <https://vercel.com/legal/dpa> (eff. 31/3/2026) | Vercel Inc. (Delaware, USA) | SCC 2021/914 mod. 1-2-3 + UK Addendum (B.1.0) + rif. LPD svizzera; DPF non citato nel DPA ma Vercel è certificata | <https://security.vercel.com> |
| Groq | <https://console.groq.com/docs/legal/customer-data-processing-addendum> (eff. 15/10/2025) | "Groq Contracting Party" indicata nel Services Agreement (da verificare) | SCC 2021/914 mod. 2 e 3 + UK IDTA Addendum + SCC con modifiche LPD svizzera | <https://trust.groq.com/subprocessors> |
| Google (Firebase) | <https://firebase.google.com/terms/data-processing-terms> (agg. 21/8/2024) | Google LLC / Google Ireland Ltd / altra affiliata "as applicable" | DPF (Google LLC certificata) e in subordine SCC | <https://firebase.google.com/terms/subprocessors> |

**Attenzione Groq**: per impostazione predefinita Groq dichiara di *non* conservare input/output delle richieste di inferenza, ma i dati del cliente sono conservati in bucket Google Cloud **negli USA** e l'opzione **Zero Data Retention** va attivata nelle impostazioni (fonte: <https://console.groq.com/docs/your-data>, consultata 26/10/2026). Da attivare e documentare.

#### Art. 37 — DPO

Obbligatorio per: autorità pubbliche; attività principali che richiedono **monitoraggio regolare e sistematico su larga scala**; trattamento su larga scala di dati particolari (art. 9) o penali. VetApp: non è pubblica; tratta dati di posizione in modo sistematico ma **non su larga scala** (migliaia di utenti, un solo Paese: cfr. WP243 rev.01 sui fattori di "larga scala" — <https://ec.europa.eu/newsroom/article29/items/612048>); i referti sono dati di animali, non dati sanitari umani (art. 9 non si applica, salvo dettagli incidentali). **Conclusione: ❌ non obbligatorio oggi**, motivazione da riportare nel registro. Da rivalutare se gli utenti superano le decine di migliaia su più Paesi. Nominare comunque un **referente privacy interno** (non è un DPO formale) è buona prassi.

#### Art. 27 — Rappresentante

Serve solo a titolari **non stabiliti** nel territorio in questione. VetApp è stabilita in Italia → ❌ in UE. Scatta invece per **UK** (art. 27 UK GDPR) e, a condizioni molto più restrittive, per **Svizzera** (art. 14 LPD) dopo il lancio in quei Paesi: vedi §3.h e §3.i. Australia e USA non hanno un istituto analogo.

#### Artt. 15–22 — Diritti degli interessati: cosa deve fare l'app

Termine di risposta: **un mese** (art. 12(3)), prorogabile di due in casi complessi; gratuito. In pratica:
- **Accesso (art. 15)**: l'utente può chiedere copia di tutti i suoi dati → funzione "Scarica i miei dati" (profilo, pet, referti, chat, tracce, foto, consensi) o procedura manuale documentata.
- **Rettifica (art. 16)**: modifica dei dati dal profilo.
- **Cancellazione (art. 17)**: "Elimina account" in-app **e** via pagina web (coincide con l'obbligo Google Play, §3.m): deve eliminare tutto, incluse copie su Supabase Storage, e propagare ai responsabili (Groq non conserva; verificare Firebase).
- **Portabilità (art. 20)**: esportazione in formato strutturato (JSON/CSV + file originali dei referti).
- **Opposizione (art. 21)** e revoca consenso (art. 7(3)): toggle per analytics/marketing, facile quanto darlo.
- **Decisioni automatizzate (art. 22)**: non applicabile (nessuna decisione con effetti giuridici).
- Tenere un **log delle richieste** ricevute e evase.

#### Art. 13 — Informativa

Da fornire **al momento della raccolta** (registrazione, prima richiesta di posizione, prima chat). Contenuto obbligatorio: identità e contatti del titolare; finalità e **base giuridica** per ciascuna (contratto per il servizio, consenso per analytics/marketing/posizione di sfondo, legittimo interesse per sicurezza); destinatari (i 4 fornitori, nominati); **trasferimenti extra-UE** e garanzie (DPF / SCC); tempi di conservazione; diritti; diritto di reclamo al Garante; se il conferimento è obbligatorio. Linguaggio semplice, a livelli (sintesi + dettaglio), per i minori ancora più semplice (art. 2-quinquies c.2 Codice). Le versioni vanno archiviate (i consensi sono già versionati nell'app: bene, serve anche l'informativa versionata).

---

### 3.b Trasferimenti extra-UE (Capo V GDPR, artt. 44–49)

**Principio**: i dati possono uscire dal SEE solo verso Paesi "adeguati" (art. 45) o con garanzie adeguate (art. 46: SCC, BCR) o in deroghe eccezionali (art. 49). **Anche l'accesso remoto da un Paese terzo è un trasferimento**: Supabase e Vercel ospitano i dati a **Dublino**, ma il supporto tecnico può accedere dagli USA (Supabase lo dichiara espressamente: "Supabase, Inc. (United States) provides technical support and operational services", FAQ v.1 del 6/10/2026 — <https://supabase.com/legal/privacy-resources/data-residency-and-transfers-faq>). Quindi tutti e quattro i fornitori comportano un trasferimento verso gli USA.

#### EU-U.S. Data Privacy Framework (DPF)

- Decisione di adeguatezza della Commissione del **10 luglio 2023** (C(2023) 4745) — <https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection/eu-us-data-transfers_en>.
- **Validità al 26/10/2026**: il Tribunale UE ha **respinto** il ricorso Latombe (causa T-553/23, sentenza 3 settembre 2025); Latombe ha presentato **appello** alla Corte di giustizia (causa **C-703/25 P**, depositato 31/10/2025, G.U. C/2025/6610). Al 26/10/2026 l'appello è **pendente** (interventi, tra cui Microsoft, a giugno 2026); nessuna sentenza trovata. Il DPF resta valido finché la Corte non decide diversamente; **rischio da monitorare** (ricordare "Schrems II" del 2020, che annullò il Privacy Shield da un giorno all'altro). Fonti: <https://curia.europa.eu/> (cercare C-703/25 P); WilmerHale 1/12/2025 — <https://www.wilmerhale.com/en/insights/blogs/wilmerhale-privacy-and-cybersecurity-law/20251201-european-court-of-justice-to-review-challenge-to-eu-us-data-privacy-framework>.
- **Stato di certificazione dei fornitori** (verificato il 26/10/2026 sulle dichiarazioni dei fornitori; l'elenco ufficiale <https://www.dataprivacyframework.gov/list> **non è leggibile automaticamente** — richiede JavaScript — e va controllato a mano, cercando anche l'estensione UK e la versione svizzera):

| Fornitore | DPF? | Evidenza | Conseguenza |
|---|---|---|---|
| **Google LLC** (Firebase, Play) | ✅ certificata (EU-US, UK Extension, Swiss-US) | <https://policies.google.com/privacy/frameworks> (eff. 23/8/2025): "Google LLC (and its wholly-owned US subsidiaries...) has certified" | Trasferimento coperto dal DPF; i Firebase Data Processing Terms §10.6 lo richiamano |
| **Vercel Inc.** | ✅ certificata (dichiara EU, UK, CH) | Changelog 4/6/2024 — <https://vercel.com/changelog/vercel-is-now-certified-under-the-eu-us-data-privacy-framework-dpf>; guida agg. 10/11/2025 — <https://vercel.com/guides/is-vercel-certified-under-dpf> | Coperto dal DPF; il DPA aggiunge comunque le SCC come rete di sicurezza |
| **Supabase** | ❌ **non certificata** | Il DPA e la FAQ residency (6/10/2026) si basano **solo su SCC**; contraente è Supabase Pte. Ltd. (**Singapore**, Paese non adeguato) + Supabase Inc. (USA) | Servono **SCC** (già nel DPA) + **TIA** (Supabase pubblica la propria TIA su <https://trust.supabase.io>; da scaricare e allegare) |
| **Groq Inc.** | ⚠️ **nessuna evidenza** di certificazione | Privacy policy (eff. 12/11/2025) cita il DPF solo per terzi; DPA (15/10/2025) usa SCC + UK Addendum + Swiss | Servono **SCC** (nel DPA) + **TIA**; dati elaborati e archiviati in **USA** (GCP) — **da verificare** a mano su dataprivacyframework.gov |

#### Clausole contrattuali standard (SCC) — decisione (UE) 2021/914

Contratto-tipo approvato dalla Commissione il 4 giugno 2021 — <https://eur-lex.europa.eu/eli/dec_impl/2021/914/oj>. Modulo 2 = titolare→responsabile (VetApp→Supabase/Groq); modulo 3 = responsabile→sub-responsabile. Vanno **firmate** (nel DPA click-through sono già incluse) e compilate negli allegati (descrizione del trasferimento, misure di sicurezza). Dopo "Schrems II" (C-311/18, 16/7/2020) le SCC richiedono una **TIA**: verificare se le leggi del Paese di destinazione (negli USA: FISA 702, EO 12333) rendono inefficaci le clausole, e prevedere misure supplementari (cifratura, minimizzazione). Guida: EDPB Raccomandazioni 01/2020 — <https://www.edpb.europa.eu/our-work-tools/our-documents/recommendations/recommendations-012020-measures-supplement-transfer_en>.

**Azioni**: (1) scaricare le TIA di Supabase e Groq (se Groq non la fornisce, redigerne una breve); (2) attivare ZDR su Groq; (3) nel DPIA e nell'informativa indicare i quattro trasferimenti; (4) alert sull'esito di C-703/25 P; (5) piano B se il DPF cade: Google e Vercel hanno già le SCC nei DPA.

---

### 3.c Codice privacy italiano (d.lgs. 196/2003, come modificato dal d.lgs. 101/2018) e Garante

In vigore nella versione attuale dal 19 settembre 2018. Testo: <https://www.garanteprivacy.it/codice> (Garante) e Normattiva. Cosa aggiunge al GDPR per VetApp:

- **Art. 2-quinquies — minori**: il consenso ai servizi della società dell'informazione è valido dai **14 anni** (l'Italia ha scelto 14 nel range 13-16 dell'art. 8 GDPR); sotto i 14 serve il consenso di chi esercita la responsabilità genitoriale; l'informativa per i minori deve essere "particolarmente chiara e semplice". **Conseguenza**: l'app deve o (a) dichiarare 14+ e chiedere la data di nascita / autodichiarazione con blocco sotto soglia, o (b) implementare un consenso genitoriale verificabile. L'opzione (a) è la più semplice; va adattata Paese per Paese (§3.l).
- **Art. 2-quaterdecies**: possibilità di designare persone autorizzate al trattamento (i due partner, se accedono ai dati).
- **Art. 122** (cookie e tracciamento): recepisce l'art. 5(3) ePrivacy — vedi §3.g.
- **Art. 130**: comunicazioni promozionali (email/push marketing) solo con consenso (opt-in), salvo "soft spam" ai propri clienti per servizi analoghi con opt-out.
- **Artt. 166 ss.**: sanzioni e procedimento davanti al Garante.
- **Linee guida cookie** del Garante, provv. 10 giugno 2021 n. 231 (G.U. n. 163 del 9/7/2021, operative dal 9/1/2022) — <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/9677876>: vedi §3.g.
- **Notifica violazioni**: procedura online obbligatoria <https://servizi.gpdp.it/databreach/s/> (vedi §3.a, art. 33).
- **Elenco DPIA** provv. 467/2018 (vedi §3.a, art. 35).
- Modelli per PMI (registro semplificato, informative): <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/9047529>.

---

### 3.d NIS2 — Direttiva (UE) 2022/2555 e d.lgs. 4 settembre 2024, n. 138

- Direttiva: <https://eur-lex.europa.eu/eli/dir/2022/2555/oj>. Decreto italiano in vigore dal 16 ottobre 2024: <https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2024-09-04;138>. Autorità: **ACN** (Agenzia per la cybersicurezza nazionale), portale NIS — <https://www.acn.gov.it/portale/nis>.
- **A chi si applica** (art. 3 d.lgs. 138/2024): soggetti pubblici e privati dei settori degli **Allegati I** (altamente critici: energia, trasporti, sanità, digitale/cloud, ecc.) e **II** (critici: tra cui i **"fornitori di servizi digitali": mercati online, motori di ricerca, piattaforme social**) che superano i massimali delle *piccole imprese* della Racc. 2003/361/CE, cioè che sono almeno **medie imprese: ≥50 dipendenti oppure >10 M€ di fatturato o bilancio annuo** (salvo casi speciali in cui si applica indipendentemente dalla dimensione: es. fornitori DNS, registri, alcuni servizi fiduciari).
- **VetApp**: ❌ **non applicabile**. Nessun dipendente, fatturato sotto soglia; la funzione "marketplace tra utenti" potrebbe in teoria far rientrare VetApp tra i "mercati online" dell'Allegato II, ma **solo** superando la soglia di media impresa.
- **Cosa cambierebbe crescendo** (≥50 dipendenti o >10 M€ *e* marketplace attivo): registrazione sulla piattaforma ACN (finestra annuale **1 gennaio–28 febbraio**), aggiornamento annuale (15 aprile–31 maggio), misure di sicurezza (art. 24), notifica incidenti significativi al CSIRT Italia (pre-notifica 24 h, notifica 72 h, relazione finale 1 mese — art. 25), responsabilità degli organi di amministrazione (art. 23). Conviene allineare *fin da ora* la checklist tecnica alle misure "di base" ACN, così il passaggio sarà indolore.
- Nota: i fornitori (Supabase/AWS, Vercel, Google) sono probabilmente soggetti NIS2 come cloud provider: VetApp ne beneficia indirettamente ma non ne eredita gli obblighi.

---

### 3.e Cyber Resilience Act (CRA) — Regolamento (UE) 2024/2847

- Testo: <https://eur-lex.europa.eu/eli/reg/2024/2847/oj>. **Date verificate** (art. 71): entrata in vigore **10 dicembre 2024**; obblighi di **segnalazione** (art. 14) dall'**11 settembre 2026** (quindi **già in vigore oggi** per i prodotti in scope); applicazione generale dall'**11 dicembre 2027**. Fonti di conferma: NCSC Irlanda — <https://ncsc.gov.ie/cra/>; Commissione, linee guida non vincolanti sulla segnalazione, 27/7/2026 (riferite da Jones Day 7/2026 — <https://www.jonesday.com/en/insights/2026/07/eu-cyber-resilience-act-24hour-reporting-duties-start-september-11-2026>). ⚠️ I riferimenti puntuali ad articoli e considerando qui sotto derivano dalla conoscenza del testo, perché EUR-Lex non è stato leggibile automaticamente: **da verificare sul testo ufficiale**.
- **Cosa copre**: i "prodotti con elementi digitali" = *software o hardware* e relative "soluzioni di elaborazione remota dei dati", **messi a disposizione sul mercato** (art. 3, punto 1). "Messa a disposizione sul mercato" = fornitura nell'ambito di un'**attività commerciale**, a titolo oneroso o gratuito (art. 3, punto 22).
- **Esclusi**: servizi puri (**SaaS**, cloud) che non sono "elaborazione remota" necessaria al funzionamento del prodotto (cons. 12); software **open source non commerciale** (cons. 18-19; art. 2); prodotti già regolati da altre norme settoriali (dispositivi medici umani, auto, aviazione).
- **VetApp rientra? ⚠️ Probabile, sì.** L'**app** (Android, e il client web scaricato) è software; è distribuita a utenti finali nell'ambito di un'attività commerciale (abbonamenti Plus/Pro, marketplace) → è un prodotto con elementi digitali di cui VetApp è **fabbricante** (art. 13). Il **backend** FastAPI/Supabase è invece "elaborazione remota dei dati" che fa parte del prodotto (l'app non funziona senza) → rientra nel perimetro del prodotto, non come SaaS autonomo. **Finché l'app è solo in test chiuso** (Firebase App Distribution a un gruppo di tester) non è ancora "immessa sul mercato"; lo sarà alla **pubblicazione su Google Play / web pubblico**. Questo punto (in particolare la gratuità del piano Free e l'assenza di una società) **deve essere confermato da un legale**.
- **Cosa comporta** (art. 13 e Allegato I): sicurezza *by design* lungo tutto il ciclo di vita; nessuna vulnerabilità nota sfruttabile alla consegna; configurazione sicura di default; **aggiornamenti di sicurezza** gratuiti e tempestivi per un **periodo di supporto di almeno 5 anni** (o la vita attesa del prodotto, art. 13(8)); **SBOM** (distinta dei componenti software: librerie Flutter/Python usate); **policy di divulgazione coordinata delle vulnerabilità** (indirizzo a cui segnalare, tempi di risposta); documentazione tecnica; **valutazione di conformità** (per un'app "standard" basta l'autovalutazione interna, Allegato VIII) e **marcatura CE** + dichiarazione di conformità UE.
- **Art. 14 — segnalazione (dall'11/9/2026)**: per **vulnerabilità attivamente sfruttate** e **incidenti gravi** che impattano la sicurezza del prodotto: **early warning entro 24 h**, notifica entro **72 h**, relazione finale entro 14 giorni (vulnerabilità) o 1 mese (incidenti), tramite la **piattaforma unica ENISA** al CSIRT coordinatore (Italia: CSIRT Italia/ACN). Non è richiesto segnalare retroattivamente fatti anteriori all'11/9/2026.
- **Cosa fare ora** (costa poco ed è utile a prescindere): (1) pubblicare un **`SECURITY.md`** nel repo con indirizzo di contatto, policy di divulgazione coordinata e tempi; (2) generare una **SBOM** a ogni build (`pip-audit`/CycloneDX per Python, `flutter pub deps --json` per Dart); (3) processo di aggiornamento: patch delle dipendenze critiche entro giorni, release note di sicurezza; (4) definire il **periodo di supporto** dichiarato; (5) tenere un registro delle vulnerabilità trattate; (6) prima della pubblicazione su Play, far valutare da un legale se preparare la dichiarazione di conformità UE (scadenza 11/12/2027).

---

### 3.f AI Act — Regolamento (UE) 2024/1689, modificato dal Regolamento (UE) 2026/1744 ("Digital Omnibus on AI")

- Testo base: <https://eur-lex.europa.eu/eli/reg/2024/1689/oj>. Modifica: Reg. (UE) 2026/1744, pubblicato in G.U. il 24/7/2026, in vigore dal **27/7/2026** (fonte: Lewis Silkin 27/7/2026 — <https://www.lewissilkin.com/insights/2026/07/27/the-digital-omnibus-on-ai-enters-into-force-today-102nedo>; testo da verificare su EUR-Lex).
- **Ruolo di VetApp**: *deployer* (utilizzatore) di un modello GPAI altrui (Groq fornisce l'inferenza; i modelli sono di Meta/Google/ecc.) **e** *provider* del sistema di IA "chat VetApp" verso i suoi utenti (perché integra il modello in un proprio prodotto con nome proprio).
- **Art. 50(1) — trasparenza chatbot: ✅ obbligo in vigore dal 2 agosto 2026** (non rinviato dall'Omnibus: le fonti confermano che le obbligazioni di trasparenza sono partite come previsto). I sistemi destinati a interagire con persone devono essere progettati in modo che le persone **siano informate che stanno interagendo con un'IA**, a meno che sia ovvio. In pratica: etichetta chiara e persistente nella chat ("Stai parlando con un assistente IA, non con un veterinario"), presente anche nella prima apertura e nell'informativa. Il periodo transitorio dell'Omnibus (fino al **2 dicembre 2026**) riguarda solo la **marcatura leggibile da macchina dei contenuti sintetici** (art. 50(2)) per sistemi già sul mercato prima del 2/8/2026 — non il nostro caso principale, ma se la chat genera testi che l'utente può esportare, valutare il watermark/metadata. Codice di condotta volontario della Commissione sulla trasparenza (giugno 2026) — da verificare su <https://digital-strategy.ec.europa.eu/>.
- **Non ad alto rischio**: l'Allegato III elenca ambiti (biometria, infrastrutture critiche, istruzione, lavoro, servizi essenziali, forze dell'ordine, migrazione, giustizia); la **salute animale non c'è**, e la chat non è un dispositivo medico (Reg. 2017/745 riguarda esseri umani). Quindi niente obblighi degli artt. 8-27. ✅ Da motivare per iscritto nel registro/DPIA. (Per completezza: l'Omnibus ha spostato l'applicazione dell'Allegato III al 2/12/2027 — irrilevante per noi.)
- **Obblighi GPAI** (artt. 51-56, dal 2/8/2025): gravano sul **fornitore del modello**, non su chi lo usa via API. VetApp deve però: scegliere modelli con documentazione; non usare la chat per fini vietati (art. 5).
- **Art. 4 — alfabetizzazione IA**: dal **2 febbraio 2025**; l'Omnibus (2026) l'ha ammorbidito: fornitori e deployer devono "adottare misure per sostenere" l'alfabetizzazione del personale che opera i sistemi, senza un livello minimo prescritto. Per VetApp: una breve formazione documentata dei tre soci sui limiti della chat (allucinazioni, prompt injection, cosa non chiedere al modello).
- **Interazione con GDPR**: le conversazioni sono dati personali → base giuridica (esecuzione del contratto), minimizzazione, DPIA (§3.a), informativa che nomina Groq e gli USA.

---

### 3.g ePrivacy / cookie e notifiche push

- **Direttiva 2002/58/CE, art. 5(3)** (mod. dir. 2009/136): archiviare o leggere informazioni sul dispositivo dell'utente richiede **consenso**, salvo che sia **strettamente necessario** per fornire un servizio esplicitamente richiesto o per la trasmissione della comunicazione. Recepita in Italia dall'**art. 122 Codice privacy**.
- **Vale per tutto**, non solo i cookie: EDPB Linee guida 2/2023 sull'ambito tecnico dell'art. 5(3) (v2.0 adottate il 7/10/2024 — <https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-22023-technical-scope-art-53-eprivacy-directive_en>) includono localStorage, identificatori, SDK nelle app, pixel.
- **Linee guida Garante 10 giugno 2021** (n. 231): identificatori **tecnici** (sessione, autenticazione, preferenze, bilanciamento, sicurezza) → **esenti**; cookie/identificatori **analitici** esenti solo se di prima parte o con IP mascherato e senza incrocio con altri dati, altrimenti consenso; **marketing/profilazione** → consenso preventivo, banner con rifiuto facile quanto l'accettazione, scrolling non vale, riproposizione non prima di 6 mesi.
- **VetApp**: ✅ il **localStorage** del client web usato per la sessione Supabase è **esente** (strettamente necessario per il servizio richiesto); nessun cookie pubblicitario; **analytics opt-in** → corretto, basta che l'opzione sia spenta di default; va comunque descritto tutto nell'informativa (art. 13), non serve un cookie banner se non ci sono tracciatori non necessari, ma una **pagina "strumenti di tracciamento"** sì. Attenzione agli SDK Firebase: **Firebase Analytics/Crashlytics** inviano identificatori → o disattivati o sotto consenso; le **notifiche push** (FCM) usano un token tecnico: esente come funzione richiesta, ma l'invio di notifiche **promozionali** richiede consenso ex art. 130 Codice (opt-in separato), mentre promemoria farmaci/visite sono servizio.
- ⚠️ Il "Digital Omnibus" (proposta 2025/0360(COD)) vorrebbe spostare queste regole nel GDPR (nuovo art. 88a) ed esentare alcune misurazioni; non adottato al 26/10/2026.

---

### 3.h Regno Unito

**Quando**: ⚠️ al lancio UK. Quadro: **UK GDPR** (copia del GDPR adattata post-Brexit) + **Data Protection Act 2018** + **Data (Use and Access) Act 2025 (DUAA)**.
- **DUAA 2025**: Royal Assent **19 giugno 2025** (confermato da ICO — <https://ico.org.uk/about-the-ico/media-centre/news-and-blogs/2025/08/ico-launches-consultations-for-data-use-and-access-act-2025-amendments/>); entrata in vigore **a tappe** (prime disposizioni 19-20 agosto 2025 con SI 2025/904; le modifiche principali alla data protection in fasi nel 2026; piano commencement del governo da verificare su <https://www.legislation.gov.uk/ukpga/2025/18>). Novità rilevanti per VetApp: nuova base "**recognised legitimate interests**"; obbligo per tutte le organizzazioni di avere una **procedura reclami** privacy; alcuni cookie a basso rischio (statistiche/aspetto) **senza consenso** con trasparenza e opt-out; sanzioni PECR allineate al GDPR (max £17,5 M / 4%); l'ICO diventa "Information Commission". Nessuna fonte trovata indica che il DUAA abbia abolito l'art. 27 (lo proponeva il precedente DPDI Bill, decaduto) → **l'obbligo di rappresentante resta** (da verificare sul testo consolidato).
- **Rappresentante UK (art. 27 UK GDPR)**: obbligatorio per titolari senza sede UK che offrono servizi a persone in UK, salvo trattamento **occasionale**, non su larga scala di dati particolari e improbabile rischio. VetApp lanciata in UK = trattamento non occasionale → ⚠️ **serve un rappresentante** (servizi commerciali da ~€/£ poche centinaia l'anno). Guida ICO: <https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/> (sezione "representatives", URL esatto da verificare).
- **Breach**: all'ICO **entro 72 ore** se rischio probabile; modulo online: <https://ico.org.uk/for-organisations/report-a-breach/personal-data-breach/>; guida rapida PMI: <https://ico.org.uk/for-organisations/sme-web-hub/72-hours-how-to-respond-to-a-personal-data-breach>.
- **Data protection fee**: quasi tutti i titolari devono pagare una tassa annuale all'ICO (Data Protection (Charges and Information) Regulations 2018, aggiornate 2025). Dal **17 febbraio 2025**: **Tier 1 £52** (micro: ≤10 dipendenti o fatturato ≤£632k), Tier 2 £78 (≤250 dipendenti o ≤£36 M), Tier 3 £3.763. VetApp = Tier 1. Verificare col "fee self-assessment" ICO: <https://ico.org.uk/for-organisations/data-protection-fee/>. ⚠️ Confermare se un titolare **non stabilito** in UK con rappresentante sia tenuto (l'ICO lo considera generalmente sì).
- **Età consenso**: **13 anni** (DPA 2018, s. 9).
- **Trasferimenti da UK verso USA**: **UK Extension al DPF** operativa dal **12 ottobre 2023** (Google e Vercel la dichiarano); per Supabase e Groq: **IDTA** o **Addendum UK alle SCC UE** (ICO, in vigore dal 21/3/2022 — <https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/international-data-transfer-agreement-and-guidance/>) — entrambi i DPA includono già l'Addendum UK. Dati UK→UE/Italia: l'UE è "adeguata" per il UK; e l'UK è adeguato per l'UE (decisione rinnovata dalla Commissione nel dicembre 2025, da verificare).

---

### 3.i Svizzera

**Quando**: ⚠️ al lancio CH. **nLPD/nFADP** (Legge federale sulla protezione dei dati, RS 235.1) in vigore dal **1° settembre 2023** — <https://www.fedlex.admin.ch/eli/cc/2022/491/it>; ordinanza OPDa RS 235.11. Autorità: **IFPDT/EDÖB/FDPIC** — <https://www.edoeb.admin.ch/>. Si applica anche a titolari esteri i cui trattamenti "esplicano effetti in Svizzera" (art. 3).
- **Rappresentante (art. 14)**: obbligatorio **solo se tutte** le condizioni ricorrono: offerta di beni/servizi o monitoraggio in CH **+** trattamento **su vasta scala** **+** **regolare** **+** **rischio elevato**. L'IFPDT stesso scrive che riguarderà "pochi titolari" — <https://www.edoeb.admin.ch/en/representatives-in-accordance-with-article-14-fadp>. VetApp con qualche centinaio di utenti svizzeri: ❌ probabilmente no; rivalutare crescendo.
- **Violazioni (art. 24)**: notifica all'IFPDT "**il più presto possibile**" (nessun termine in ore) quando la violazione comporta **verosimilmente un rischio elevato** per le persone; informare gli interessati se necessario per la loro tutela o su richiesta dell'IFPDT. Linee guida IFPDT di febbraio 2025 e modulo online: <https://www.edoeb.admin.ch/en/guidelines-data-breach>.
- **Registro (art. 12(5) + art. 24 OPDa)**: esenzione per imprese **<250 dipendenti** che non trattano dati degni di particolare protezione su vasta scala né fanno profilazione a rischio elevato → VetApp esente in CH (ma lo tiene comunque per il GDPR).
- **DPIA (art. 22)**, informativa (art. 19), diritti (art. 25 ss.), **consulente per la protezione dei dati** (art. 10) facoltativo per i privati.
- **Minori**: la LPD non fissa un'età; vale la capacità di discernimento del diritto civile (in pratica ~12-14+): da gestire con la stessa soglia 14 italiana e conferma legale.
- **Trasferimenti CH→USA**: **Swiss-U.S. DPF** riconosciuto dal Consiglio federale il 14/8/2024, efficace dal **15 settembre 2024** — <https://www.admin.ch/gov/en/start/documentation/media-releases.msg-id-102054.html>: Google e Vercel coperti (verificare che la certificazione includa la parte svizzera); Supabase e Groq → SCC con modifiche svizzere (già nei DPA). Dati CH→UE: l'UE è nell'elenco dei Paesi adeguati (Allegato 1 OPDa).

---

### 3.j Australia

**Quando**: ⚠️ al lancio AU. **Privacy Act 1988 (Cth)** e **Australian Privacy Principles (APP)** — <https://www.oaic.gov.au/privacy/australian-privacy-principles>. Autorità: **OAIC**.
- **"Australian link" (s. 5B)**: dal **13 dicembre 2022** basta che l'organizzazione estera "**carries on business in Australia**" (tolto il requisito di raccolta in Australia); la giurisprudenza (Facebook v AIC [2022] FCAFC 9; Clearview) lo legge in modo ampio: un'app offerta a utenti australiani con dati raccolti dai loro dispositivi probabilmente lo integra.
- **Small business exemption**: le organizzazioni con fatturato annuo **≤3 M AUD** sono fuori dal Privacy Act (OAIC — <https://www.oaic.gov.au/privacy/privacy-for-organisations/small-business>), **salvo** che siano health service provider (umani), **commercino in informazioni personali** (vendere/acquistare dati: VetApp no, il marketplace vende prodotti, non dati), contractor del Commonwealth, ecc. → ❌ **VetApp probabilmente esente** finché sotto 3 M AUD. ⚠️ Il governo ha annunciato l'intenzione di **abolire l'esenzione** nella "tranche 2" della riforma (non legiferata al 26/10/2026, da monitorare). È possibile l'**opt-in volontario** (s. 6EA), consigliabile per credibilità.
- **Se/quando coperta**: **Notifiable Data Breaches scheme** (Part IIIC): in caso di sospetto breach, valutazione "ragionevole e sollecita" **entro massimo 30 giorni** (s. 26WH); se "eligible data breach" (probabile **serio danno**), notifica a OAIC e interessati "al più presto"; modulo: <https://webform.oaic.gov.au/prod?entitytype=DBN&layoutcode=DataBreachWF>; panoramica: <https://www.oaic.gov.au/privacy/notifiable-data-breaches/about-the-notifiable-data-breaches-scheme>.
- **Riforme 2024** (Privacy and Other Legislation Amendment Act 2024, approvato novembre 2024): **statutory tort per gravi invasioni della privacy** in vigore dal **10 giugno 2025** — azione civile diretta che **non dipende dall'esenzione small business**: un uso sconsiderato delle tracce GPS potrebbe esporre anche VetApp; obbligo per OAIC di adottare un **Children's Online Privacy Code** entro il **10 dicembre 2026** (bozza pubblicata 31/3/2026, consultazione chiusa 5/6/2026; data di inizio non ancora fissata) — <https://www.oaic.gov.au/privacy/privacy-registers/privacy-codes/childrens-online-privacy-code>: riguarda servizi "likely to be accessed by children"; nella bozza, sotto i 15 anni serve il consenso dei genitori. Se VetApp è 14+/16+ e lo verifica, l'impatto è limitato, ma va seguito.
- **Trasferimenti** (APP 8): chi è coperto deve assicurare che i destinatari esteri rispettino le APP (accountability contrattuale).

---

### 3.k Stati Uniti

**Quando**: ⚠️ al lancio US. **Nessuna legge federale generale sulla privacy.** Quadro a mosaico:
- **California CCPA/CPRA**: si applica a imprese for-profit che fanno affari in California **e** superano **una** delle soglie: ricavi lordi annui > **26.625.000 $** (soglia 2025-2026, adeguata all'inflazione; prossimo aggiornamento 1/1/2027), **oppure** compra/vende/condivide dati di **≥100.000** consumatori o famiglie californiani, **oppure** ≥50% dei ricavi dalla vendita/condivisione di dati. VetApp: ❌ non applicabile inizialmente. Fonte: Cal. Civ. Code §1798.140(d); CPPA — <https://cppa.ca.gov/>.
- **Altri Stati** (20 leggi "comprehensive" in vigore nel 2026): soglia tipica **100.000 consumatori** residenti/anno (Virginia, Colorado, Oregon, ecc.) o 25.000 se si vendono dati; **Connecticut** scesa a **35.000** consumatori dal **1° luglio 2026** (SB 1295, PA 25-113) e senza soglia se si trattano dati sensibili (incl. **geolocalizzazione precisa**) o si vendono dati — ⚠️ da verificare se la clausola "dati sensibili senza soglia" catturi VetApp con pochi utenti nel Connecticut; **Texas TDPSA**: nessuna soglia numerica ma esenzione per le "small business" secondo la definizione SBA (VetApp lo è), salvo il divieto di vendere dati sensibili senza consenso. **Conclusione**: ❌ oggi, ⚠️ monitorare Connecticut e l'eventuale crescita; tabella aggiornata IAPP: <https://iapp.org/resources/article/us-state-privacy-legislation-tracker/>.
- **Leggi statali di notifica breach** (tutti i **50 Stati** + DC e territori): scattano in caso di accesso non autorizzato a "personal information" definita come nome + elementi specifici (SSN, dati finanziari, patente, dati sanitari...) **e, in molti Stati (es. California, Florida, Nevada, New Jersey, Wyoming...), username/email + password**. Quindi ✅ **se un incidente espone le credenziali** (anche solo hash di password + email) di residenti US, scattano obblighi di notifica agli interessati (e in alcuni Stati all'Attorney General), con termini da 30 a 60 giorni o "senza ritardo". Riferimento: NCSL, *Security Breach Notification Laws* — <https://www.ncsl.org/technology-and-communication/security-breach-notification-laws>. Mitigazione: hash robusti (Supabase Auth usa bcrypt — verificare), MFA.
- **COPPA** (15 U.S.C. §6501, 16 CFR 312): raccolta di dati da **minori di 13** anni richiede consenso genitoriale verificabile; regola **modificata** con pubblicazione 22/4/2025, efficace 23/6/2025, **conformità obbligatoria dal 22 aprile 2026** (nuove definizioni, policy scritta di retention) — <https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule>. VetApp: se dichiara 13+/14+ e non si rivolge ai bambini, ❌ non applicabile; serve però una barriera d'età neutrale.
- **FTC Act §5** (15 U.S.C. §45): pratiche "unfair or deceptive": promettere sicurezza/privacy nell'informativa e non mantenerle è sanzionabile dalla FTC; anche l'assenza di misure ragionevoli è "unfair". ✅ Vale per chiunque operi verso consumatori US. Guida: <https://www.ftc.gov/business-guidance/privacy-security>.
- **Health Breach Notification Rule** (16 CFR 318): riguarda "PHR identifiable health information" di **persone**; i dati sanitari degli **animali** non vi rientrano → ❌.
- Consiglio pratico: una **privacy policy "US-style"** (sezione specifica con diritti statali) e l'adesione volontaria a standard (NIST CSF 2.0) dimostrano "ragionevolezza" ex §5.

---

### 3.l Altri Paesi target UE: IE, ES, DE, AT, FR, BE

Regola generale: il GDPR è identico ovunque; per i trattamenti transfrontalieri l'autorità **capofila** è quella dello stabilimento principale (Italia → **Garante**, art. 56), con lo **sportello unico**: le violazioni si notificano **solo al Garante**, che coordina le altre. Cambiano: l'**età di consenso digitale** (art. 8 GDPR, range 13-16) e alcune norme nazionali. ⚠️ Tutte le età sotto sono da verificare sui testi nazionali citati (consultazione 26/10/2026 di fonti secondarie coerenti; Irlanda confermata su risposta ministeriale Oireachtas 23/5/2018).

| Paese | Legge nazionale | Età consenso | Autorità e canale breach |
|---|---|---|---|
| **Irlanda** | Data Protection Act 2018, s. 31 | **16** | **DPC** — <https://www.dataprotection.ie/en/organisations/know-your-obligations/breach-notification> (modulo web) |
| **Spagna** | LOPDGDD 3/2018, art. 7 | **14** | **AEPD** — sede elettronica <https://sedeagpd.gob.es/> ("Notificación de brechas") |
| **Germania** | BDSG (nessuna deroga: default GDPR); cookie: **TDDDG** (ex TTDSG) §25 | **16** | Autorità del **Land** competente (per titolare estero: quella dello Stato dello stabilimento o, via sportello unico, il Garante); elenco: <https://www.bfdi.bund.de/> |
| **Austria** | DSG, §4(4) | **14** | **DSB** — <https://www.dsb.gv.at/> (modulo "Data-Breach-Meldung") |
| **Francia** | Loi 78-17 ("Informatique et Libertés"), art. 45 | **15** (sotto: consenso congiunto minore + genitore) | **CNIL** — <https://notifications.cnil.fr/> |
| **Belgio** | Loi 30 juillet 2018, art. 7 | **13** | **APD/GBA** — <https://www.autoriteprotectiondonnees.be/> (formulaire "fuite de données") |
| *(rif.)* Italia | Codice, art. 2-quinquies | 14 | Garante — servizi.gpdp.it |
| *(rif.)* UK | DPA 2018, s. 9 | 13 | ICO |

**Conseguenza per il prodotto**: l'età minima deve essere **per Paese** (rilevata dal Paese dell'account) oppure un'unica soglia prudente **16 anni** ovunque (semplifica: copre IE/DE, e supera tutte le altre). Sotto soglia: bloccare o implementare consenso genitoriale. Da decidere con il legale. Nota Germania: il TDDDG §25 replica l'art. 5(3) ePrivacy (esenzione per localStorage tecnico confermata).

---

### 3.m Google Play (policy del Play Console)

Tutte ✅ obbligatorie alla pubblicazione (oggi l'app è solo su Firebase App Distribution, cui si applica comunque la Google Play Developer Distribution Agreement per i tester). Fonti consultate 26/10/2026.

- **Data safety section** — <https://support.google.com/googleplay/android-developer/answer/10787469>: obbligatoria dal **20 luglio 2022**; dichiarare ogni dato **raccolto** (trasmesso fuori dal dispositivo, inclusi SDK: Firebase, Supabase) e **condiviso** con terzi, finalità, se obbligatorio/opzionale, **cifratura in transito**, **meccanismo di cancellazione**; deve coincidere con l'informativa. Per VetApp: posizione (precisa), info personali (email, telefono), foto/video, messaggi (chat), file/documenti (referti), info app (interazioni).
- **User Data policy** — <https://support.google.com/googleplay/android-developer/answer/10144311>: link all'informativa in Play Console e **in-app**; **prominent disclosure + consenso** in-app prima di raccogliere dati personali/sensibili in modi inattesi (es. posizione in background); HTTPS; divieto di vendita di dati; SDK conformi.
- **Cancellazione account** — <https://support.google.com/googleplay/android-developer/answer/13327111>: dal **31 maggio 2024** (termine finale) le app con account devono offrire cancellazione **in-app** e un **link web** per chiederla senza reinstallare; la cancellazione deve eliminare i dati associati; il link va dichiarato nella Data safety.
- **Target API level** — <https://developer.android.com/google/play/requirements/target-sdk>: dal **31 agosto 2026** le **nuove app e gli aggiornamenti devono avere target Android 16 (API 36)**; app esistenti almeno API 35 per restare visibili ai nuovi utenti; proroga richiedibile fino al **1° novembre 2026**. (Nel 2025 il requisito era API 35.) Flutter: impostare `targetSdk = 36` in `android/app/build.gradle.kts` e testare i cambi di comportamento Android 16.
- **Play App Signing** — <https://support.google.com/googleplay/android-developer/answer/9842756>: obbligatorio per le nuove app (formato **AAB**); Google custodisce la chiave di firma; conservare la **upload key** in modo sicuro (già un controllo "secrets" per la checklist).
- **Health apps policy** — <https://support.google.com/googleplay/android-developer/answer/12261419>: riguarda app con funzioni "health-related" per **persone** (fitness, medicali, assicurazioni...). VetApp tratta salute **animale** → ❌ non rientra, ma ⚠️ evitare nella scheda store termini che suggeriscano consigli medici umani; dichiarare chiaramente "informazioni, non diagnosi".
- **Permessi**:
  - **Posizione in background** — <https://support.google.com/googleplay/android-developer/answer/9799150>: ammessa solo se centrale per la funzione e con beneficio chiaro; serve **dichiarazione** in Play Console (App content > Sensitive app permissions), **video demo**, **prominent disclosure** in-app con la parola "location" e "when the app is closed/not in use", informativa che la cita. Il tracciamento passeggiate con app in background richiede questa procedura (oppure usare solo foreground service con notifica persistente, che evita `ACCESS_BACKGROUND_LOCATION`: **da valutare tecnicamente**, è la strada più semplice).
  - **Foreground service types** — <https://support.google.com/googleplay/android-developer/answer/13392821>: con target Android 14+ ogni tipo (`location`, `mediaPlayback`...) va dichiarato nel manifest **e** nella dichiarazione in Play Console (App content), con descrizione e, se richiesto, video. Il nostro FGS "walk tracking" → tipo `location`.
  - **Foto/video** — <https://support.google.com/googleplay/android-developer/answer/14115180>: dal **28 maggio 2025** `READ_MEDIA_IMAGES/VIDEO` solo per app con accesso ampio come funzione core (gallerie); altrimenti usare l'**Android Photo Picker** (consigliato per VetApp: niente permesso, niente dichiarazione).
- **Verifica sviluppatore e D-U-N-S** — <https://developer.android.com/developer-verification/guides/faq>: per pubblicare come **organizzazione** serve il numero **D-U-N-S** (gratuito, fino a 28 giorni); come persona fisica serve documento d'identità e indirizzo pubblicato nella scheda. Inoltre la **Android developer verification** (requisito a livello di OS per *tutte* le app installate su dispositivi certificati, anche fuori Play) è operativa dal **30 settembre 2026** in Brasile, Indonesia, Singapore, Thailandia e si estende **globalmente dal 2027** — <https://android-developers.googleblog.com/2026/06/android-developer-verification.html>. Decisione da prendere: pubblicare come persona (nome e indirizzo pubblici) o aspettare la società (D-U-N-S).
- **Play Integrity API** (facoltativo): attesta che l'app non è manomessa e il dispositivo è genuino; utile contro abusi del marketplace e della chat (quota Groq). Non obbligatorio.
- **Families / minori**: se l'app dichiara 14+/16+ e non si rivolge ai bambini, non rientra nella Families policy, ma il **questionario "Target audience and content"** va compilato coerentemente.

---

### 3.n Standard tecnici di riferimento (non sono leggi)

Servono come **metro di "adeguatezza"** per l'art. 32 GDPR e come base per la checklist tecnica. Verificati il 26/10/2026.

- **OWASP MASVS 2.1** (Mobile Application Security Verification Standard) — <https://mas.owasp.org/MASVS/>: 8 gruppi di controlli: **MASVS-STORAGE** (dati sensibili a riposo: niente referti/token in chiaro su disco; usare `flutter_secure_storage`), **MASVS-CRYPTO** (algoritmi e chiavi), **MASVS-AUTH** (autenticazione/sessioni: refresh token, logout remoto), **MASVS-NETWORK** (TLS, eventuale pinning), **MASVS-PLATFORM** (permessi, IPC, WebView), **MASVS-CODE** (dipendenze aggiornate, build sicure), **MASVS-RESILIENCE** (anti-tampering: opzionale per un'app non finanziaria), **MASVS-PRIVACY** (minimizzazione, trasparenza, controlli utente). Dalla v2 non ci sono più i "livelli" L1/L2 ma i **profili di test MAS**.
- **OWASP MASTG** (Mobile Application Security Testing Guide) — <https://mas.owasp.org/MASTG/>: come testare ogni controllo MASVS; checklist scaricabile.
- **OWASP ASVS 5.0.0** (Application Security Verification Standard, rilasciato il **30 maggio 2025**) — <https://owasp.org/www-project-application-security-verification-standard/>: ~350 requisiti in 17 capitoli per il **backend** FastAPI; obiettivo ragionevole: **Livello 1** completo + requisiti L2 su autenticazione, autorizzazione, file upload, logging.
- **OWASP Top 10:2025** (pubblicata novembre 2025) — <https://owasp.org/Top10/2025/>: A01 Broken Access Control (incl. SSRF), A02 Security Misconfiguration, A03 **Software Supply Chain Failures** (nuova), A04 Cryptographic Failures, A05 Injection, A06 Insecure Design, A07 Authentication Failures, A08 Software or Data Integrity Failures, A09 Logging & Alerting Failures, A10 **Mishandling of Exceptional Conditions** (nuova).
- **OWASP Top 10 for LLM Applications 2025** — <https://genai.owasp.org/llm-top-10/>: LLM01 **Prompt Injection** (utente o referto caricato che contiene istruzioni per il modello), LLM02 **Sensitive Information Disclosure** (il modello rivela dati di altri utenti o il system prompt), LLM03 Supply Chain, LLM04 Data/Model Poisoning, LLM05 Improper Output Handling (output del modello renderizzato senza sanitizzazione), LLM06 Excessive Agency, LLM07 System Prompt Leakage, LLM08 Vector/Embedding Weaknesses, LLM09 **Misinformation** (centrale: consigli sanitari errati → i "safety gates" sono la mitigazione), LLM10 **Unbounded Consumption** (esaurimento quota Groq: già vissuto nel 2025 — rate limit per utente).
- **ENISA**, *Cybersecurity guide for SMEs — 12 steps* (28/6/2021) — <https://www.enisa.europa.eu/publications/cybersecurity-guide-for-smes>; **ACN**, misure di base per le PMI — <https://www.acn.gov.it/>.
- **Garante**: non pubblica uno standard tecnico generale; i riferimenti utili sono i provvedimenti su misure di sicurezza e il modello di registro.
- **ISO/IEC 27001:2022**: certificazione di un sistema di gestione della sicurezza; ❌ **non richiesta** da nessuna norma qui esaminata; costosa; eventualmente in futuro per clienti B2B (cliniche). I fornitori lo sono (Supabase SOC 2 Type II, Vercel ISO 27001/SOC 2, Google ISO 27001): le attestazioni vanno raccolte come evidenza di "due diligence" art. 28(1).
- **NIST CSF 2.0** (USA, 2024) — <https://www.nist.gov/cyberframework>: utile per il lancio US come riferimento di "ragionevolezza".

---

## 4. Cosa deve confermare un legale (checklist)

1. **Titolarità oggi**: va bene che il titolare sia la persona fisica del proprietario fino alla costituzione della società? Come gestire il passaggio (informativa, DPA, consensi già raccolti)? I due partner sono "autorizzati" (art. 2-quaterdecies) o contitolari (art. 26)?
2. **DPIA**: conferma della conclusione "necessaria" e del perimetro (GPS + chat IA + referti + marketplace); serve consultazione preventiva art. 36?
3. **Natura dei referti veterinari**: conferma che non sono "dati relativi alla salute" ex art. 9 GDPR, e come trattare i dati del **veterinario terzo** (nome, contatti, firma) contenuti nei file: base giuridica e informativa ex art. 14.
4. **Trasferimenti**: adeguatezza delle SCC + TIA per Supabase (Singapore + USA) e Groq (USA); conferma a mano della presenza/assenza di Groq, Supabase, Vercel, Google LLC nell'elenco DPF, incluse estensione UK e Swiss; piano in caso di annullamento del DPF (C-703/25 P).
5. **Groq e chat IA**: base giuridica del trattamento delle conversazioni; liceità dell'invio a Groq di contenuti dei referti; adeguatezza dell'avviso "stai parlando con un'IA" ai fini dell'art. 50 AI Act; eventuale responsabilità per consigli errati (termini d'uso, disclaimer).
6. **Età minima**: scegliere tra soglia unica 16 anni o soglia per Paese; quale meccanismo di verifica dell'età è "ragionevole" (art. 8(2) GDPR); impatto del Children's Online Privacy Code australiano e di COPPA.
7. **Cyber Resilience Act**: VetApp è "fabbricante" di un "prodotto con elementi digitali" dalla pubblicazione su Play? Il piano Free cambia qualcosa? Il backend è "elaborazione remota" parte del prodotto? Quali adempimenti entro l'11/12/2027 (dichiarazione UE, marcatura CE sull'app)?
8. **NIS2**: conferma di non applicabilità e del criterio di soglia che la farebbe scattare (marketplace = "mercato online"?).
9. **Regno Unito**: necessità del rappresentante art. 27 UK GDPR e della data protection fee per un titolare non stabilito; impatto delle fasi di commencement del DUAA 2025.
10. **Svizzera**: conferma che le condizioni cumulative dell'art. 14 LPD non ricorrono; età minima applicabile.
11. **Australia**: conferma dell'esenzione small business e del rischio da statutory tort; opportunità dell'opt-in s. 6EA.
12. **USA**: conferma di non applicabilità di CCPA/leggi statali (in particolare Connecticut dal 1/7/2026 per i dati di geolocalizzazione precisa) e redazione della sezione "US residents" dell'informativa; procedura breach multi-Stato.
13. **ePrivacy**: conferma che localStorage di sessione e token FCM sono esenti da consenso; se Firebase Crashlytics/Analytics richiedono banner/consenso nell'app e sul web.
14. **Marketplace tra utenti**: VetApp è titolare o solo intermediario per i dati scambiati tra venditore e acquirente? Obblighi DSA (Reg. 2022/2065) per piattaforme che consentono contratti tra consumatori e professionisti (tracciabilità dei venditori art. 30, se vendono professionisti)? Responsabilità sui contenuti.
15. **Informativa e termini**: revisione dell'informativa art. 13, dei termini di servizio (limitazioni di responsabilità sui consigli IA, foro) e della procedura reclami (richiesta anche dal DUAA UK).

---

## 5. Fonti (tutte consultate il 26 ottobre 2026)

### Unione europea
- GDPR, Reg. (UE) 2016/679 — <https://eur-lex.europa.eu/eli/reg/2016/679/oj>
- Decisione SCC 2021/914 — <https://eur-lex.europa.eu/eli/dec_impl/2021/914/oj>
- Decisione di adeguatezza EU-US DPF, 10/7/2023 — <https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection/eu-us-data-transfers_en>
- Tribunale UE, T-553/23 Latombe (3/9/2025) e appello C-703/25 P (G.U. C/2025/6610) — <https://curia.europa.eu/>; <https://eur-lex.europa.eu/eli/C/2025/6610/oj>
- WilmerHale, *European Court of Justice to Review Challenge to EU-U.S. DPF*, 1/12/2025 — <https://www.wilmerhale.com/en/insights/blogs/wilmerhale-privacy-and-cybersecurity-law/20251201-european-court-of-justice-to-review-challenge-to-eu-us-data-privacy-framework>
- WP248 rev.01, Linee guida DPIA (4/10/2017) — <https://ec.europa.eu/newsroom/article29/items/611236>
- WP243 rev.01, Linee guida DPO — <https://ec.europa.eu/newsroom/article29/items/612048>
- EDPB Linee guida 4/2019 (art. 25) — <https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-42019-article-25-data-protection-design-and_en>
- EDPB Linee guida 9/2022 (data breach, v2.0 28/3/2023) — <https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-92022-personal-data-breach-notification-under-gdpr_en>
- EDPB Raccomandazioni 01/2020 (misure supplementari trasferimenti) — <https://www.edpb.europa.eu/our-work-tools/our-documents/recommendations/recommendations-012020-measures-supplement-transfer_en>
- EDPB Linee guida 2/2023 (ambito tecnico art. 5(3) ePrivacy, v2.0 7/10/2024) — <https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-22023-technical-scope-art-53-eprivacy-directive_en>
- EDPB-EDPS Joint Opinion 1/2025 (Omnibus IV, art. 30) — <https://www.edpb.europa.eu/our-work-tools/our-documents/edpbedps-joint-opinion/edpb-edps-joint-opinion-012025-proposal-regulation-european_en>
- Direttiva ePrivacy 2002/58/CE — <https://eur-lex.europa.eu/eli/dir/2002/58/oj>
- NIS2, Dir. (UE) 2022/2555 — <https://eur-lex.europa.eu/eli/dir/2022/2555/oj>
- Cyber Resilience Act, Reg. (UE) 2024/2847 — <https://eur-lex.europa.eu/eli/reg/2024/2847/oj>; NCSC-IE CRA — <https://ncsc.gov.ie/cra/>; Jones Day, *EU CRA 24-hour reporting duties start September 11, 2026* (7/2026) — <https://www.jonesday.com/en/insights/2026/07/eu-cyber-resilience-act-24hour-reporting-duties-start-september-11-2026>; McCann FitzGerald, *CRA: Reporting Obligations apply from 11 September 2026* — <https://www.mccannfitzgerald.com/knowledge/data-privacy-and-cyber-risk/cyber-resilience-act-reporting-obligations-apply-from-11-september-2026>
- AI Act, Reg. (UE) 2024/1689 — <https://eur-lex.europa.eu/eli/reg/2024/1689/oj>; Reg. (UE) 2026/1744 (Digital Omnibus on AI, G.U. 24/7/2026) — Lewis Silkin 27/7/2026 — <https://www.lewissilkin.com/insights/2026/07/27/the-digital-omnibus-on-ai-enters-into-force-today-102nedo>; McCann FitzGerald, *One Month to Go: EU AI Act Transparency Compliance* — <https://www.mccannfitzgerald.com/knowledge/technology-and-innovation/one-month-to-go-eu-ai-act-transparency-compliance>
- Digital Omnibus (GDPR/ePrivacy), procedura 2025/0360(COD) — <https://oeil.secure.europarl.europa.eu/>
- ENISA, *Cybersecurity guide for SMEs* (28/6/2021) — <https://www.enisa.europa.eu/publications/cybersecurity-guide-for-smes>

### Italia
- Codice privacy (d.lgs. 196/2003 mod. d.lgs. 101/2018) — <https://www.garanteprivacy.it/codice>; art. 2-quinquies (Brocardi, agg. 20/2/2026) — <https://www.brocardi.it/codice-della-privacy/parte-i/titolo-i/capo-ii/art2quinquies.html>
- Garante, pagina data breach e procedura telematica — <https://www.garanteprivacy.it/it/data-breach>; <https://servizi.gpdp.it/databreach/s/>
- Garante, provv. 11/10/2018 n. 467 (elenco DPIA), doc. web 9058979 — <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/9058979>; allegato doc. web 9059358
- Garante, Linee guida cookie 10/6/2021 n. 231, doc. web 9677876 — <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/9677876>
- Garante, modelli registro PMI, doc. web 9047529 — <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/9047529>
- Garante, software PIA (CNIL), doc. web 8630369 — <https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/8630369>
- d.lgs. 4/9/2024 n. 138 (NIS2) — Normattiva; ACN portale NIS — <https://www.acn.gov.it/portale/nis>

### Regno Unito
- Data (Use and Access) Act 2025 — <https://www.legislation.gov.uk/ukpga/2025/18>; ICO, consultazioni DUAA (8/2025) — <https://ico.org.uk/about-the-ico/media-centre/news-and-blogs/2025/08/ico-launches-consultations-for-data-use-and-access-act-2025-amendments/>; Kennedys, *DUAA commencement dates* (2026) — <https://www.kennedyslaw.com/en/thought-leadership/article/2026/the-data-use-and-access-act-2025-commencement-dates-and-planned-guidance-for-2026>
- ICO, report a breach — <https://ico.org.uk/for-organisations/report-a-breach/personal-data-breach/>; SME hub 72 ore — <https://ico.org.uk/for-organisations/sme-web-hub/72-hours-how-to-respond-to-a-personal-data-breach>
- ICO, IDTA e Addendum — <https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/international-data-transfer-agreement-and-guidance/>
- ICO, data protection fee — <https://ico.org.uk/for-organisations/data-protection-fee/>; Data Protection (Charges and Information) (Amendment) Regulations 2025 (in vigore 17/2/2025; Lewis Silkin 6/2/2025 — <https://www.lewissilkin.com/insights/2025/02/06/fee-payable-to-the-ico-to-increase-in-february-102jzb9>)
- Fieldfisher, UK GDPR art. 27 annotato — <https://ukgdpr.fieldfisher.com/chapter-4/article-27-gdpr/>

### Svizzera
- LPD RS 235.1 — <https://www.fedlex.admin.ch/eli/cc/2022/491/it>
- IFPDT, rappresentanti art. 14 — <https://www.edoeb.admin.ch/en/representatives-in-accordance-with-article-14-fadp>; linee guida data breach (2/2025) — <https://www.edoeb.admin.ch/en/guidelines-data-breach>
- Consiglio federale, Swiss-US DPF (14/8/2024, efficace 15/9/2024) — <https://www.admin.ch/gov/en/start/documentation/media-releases.msg-id-102054.html>

### Australia
- OAIC, small business — <https://www.oaic.gov.au/privacy/privacy-for-organisations/small-business>; NDB scheme — <https://www.oaic.gov.au/privacy/notifiable-data-breaches/about-the-notifiable-data-breaches-scheme>; *The NDB scheme: an overview* (30 giorni, s. 26WH) — <https://www.oaic.gov.au/__data/assets/pdf_file/0011/5213/the-ndb-scheme-an-overview.pdf>; Children's Online Privacy Code — <https://www.oaic.gov.au/privacy/privacy-registers/privacy-codes/childrens-online-privacy-code>
- Clayton Utz, *More overseas companies subject to the Australian Privacy Act* (4/2023, s. 5B) — <https://www.claytonutz.com/insights/2023/april/more-overseas-companies-to-be-subject-to-the-australian-privacy-act>
- Gilbert + Tobin, *Privacy Amendment Bill* (tort 10/6/2025) — <https://www.gtlaw.com.au/insights/privacy-amendment-bill-a-new-risk-landscape>; DLA Piper, *Exposure draft Children's Online Privacy Code* (4/2026) — <https://privacymatters.dlapiper.com/2026/04/australia-exposure-draft-of-childrens-online-privacy-code-signals-tougher-standards/>

### Stati Uniti
- CPPA (CCPA/CPRA, soglia 26.625.000 $) — <https://cppa.ca.gov/>
- NCSL, *Security Breach Notification Laws* — <https://www.ncsl.org/technology-and-communication/security-breach-notification-laws>
- FTC, COPPA Rule (modifiche 2025, conformità 22/4/2026) — <https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule>; Davis Polk, *FTC prioritizes COPPA enforcement* (16/4/2026) — <https://www.davispolk.com/insights/client-update/ftc-prioritizes-coppa-enforcement-new-compliance-obligations-take-effect>
- FTC, privacy & security guidance — <https://www.ftc.gov/business-guidance/privacy-security>
- Connecticut PA 25-113 (soglia 35.000 dal 1/7/2026) — WilmerHale 31/7/2026 — <https://www.wilmerhale.com/en/insights/blogs/wilmerhale-privacy-and-cybersecurity-law/20260731-connecticut-amends-its-data-privacy-act-to-increase-data-protections>; Texas TDPSA (BakerHostetler) — <https://bakerlaw.com/insights/texas-data-privacy-and-security-act-decoding-the-small-business-exception>
- IAPP, US State Privacy Legislation Tracker — <https://iapp.org/resources/article/us-state-privacy-legislation-tracker/>

### Altri Paesi UE
- Irlanda: Data Protection Act 2018 s. 31 (risposta Oireachtas 23/5/2018) — <https://www.oireachtas.ie/en/debates/question/2018-05-23/77/>; DPC breach — <https://www.dataprotection.ie/en/organisations/know-your-obligations/breach-notification>
- FRA, *Consent to use data on children* (mappa età) — <https://fra.europa.eu/en/publication/2017/mapping-minimum-age-requirements-concerning-rights-child-eu/consent-use-data-children>
- Spagna LOPDGDD 3/2018 (BOE) — <https://www.boe.es/eli/es/lo/2018/12/05/3/con>; Francia Loi 78-17 (Légifrance); Austria DSG (RIS); Belgio Loi 30/7/2018 (Moniteur belge); Germania TDDDG (gesetze-im-internet.de)

### Fornitori
- Supabase DPA (v.1, 1/8/2026) — <https://supabase.com/legal/customer-resources/data-processing-addendum>; Data Residency & Transfers FAQ (6/10/2026) — <https://supabase.com/legal/privacy-resources/data-residency-and-transfers-faq>; privacy — <https://supabase.com/privacy>; TIA — <https://supabase.com/downloads/docs/Supabase+TIA+250314.pdf>
- Vercel DPA (eff. 31/3/2026) — <https://vercel.com/legal/dpa>; DPF changelog 4/6/2024 — <https://vercel.com/changelog/vercel-is-now-certified-under-the-eu-us-data-privacy-framework-dpf>; guida DPF (10/11/2025) — <https://vercel.com/guides/is-vercel-certified-under-dpf>
- Groq privacy policy (eff. 12/11/2025) — <https://groq.com/privacy-policy>; Customer DPA (15/10/2025) — <https://console.groq.com/docs/legal/customer-data-processing-addendum>; Your Data / ZDR — <https://console.groq.com/docs/your-data>; sub-processors — <https://trust.groq.com/subprocessors>
- Google, Privacy Frameworks (DPF, eff. 23/8/2025) — <https://policies.google.com/privacy/frameworks>; Firebase Data Processing Terms (21/8/2024) — <https://firebase.google.com/terms/data-processing-terms>
- Elenco ufficiale DPF (da consultare a mano) — <https://www.dataprivacyframework.gov/list>

### Google Play / Android
- Data safety — <https://support.google.com/googleplay/android-developer/answer/10787469>
- User Data policy — <https://support.google.com/googleplay/android-developer/answer/10144311>
- Cancellazione account — <https://support.google.com/googleplay/android-developer/answer/13327111>
- Target API level — <https://developer.android.com/google/play/requirements/target-sdk>
- Play App Signing — <https://support.google.com/googleplay/android-developer/answer/9842756>
- Health apps — <https://support.google.com/googleplay/android-developer/answer/12261419>
- Background location — <https://support.google.com/googleplay/android-developer/answer/9799150>
- Foreground service types — <https://support.google.com/googleplay/android-developer/answer/13392821>
- Photo and video permissions — <https://support.google.com/googleplay/android-developer/answer/14115180>
- Developer verification FAQ — <https://developer.android.com/developer-verification/guides/faq>; blog 6/2026 — <https://android-developers.googleblog.com/2026/06/android-developer-verification.html>

### Standard tecnici
- OWASP MASVS — <https://mas.owasp.org/MASVS/>; MASTG — <https://mas.owasp.org/MASTG/>
- OWASP ASVS 5.0.0 (30/5/2025) — <https://owasp.org/www-project-application-security-verification-standard/>
- OWASP Top 10:2025 — <https://owasp.org/Top10/2025/>
- OWASP Top 10 for LLM Applications 2025 — <https://genai.owasp.org/llm-top-10/>
- NIST CSF 2.0 — <https://www.nist.gov/cyberframework>
