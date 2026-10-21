# Dichiarazioni per gli store: età, privacy, IA

Bozza di lavoro per compilare i moduli di Google Play e App Store. **Non è consulenza legale**: parte dalle bozze in `docs/compliance/`
(e, per paese, dai documenti sui rami `ml/revisione-e-legale-en`, `ml/legale-de`, `ml/legale-fr`, `ml/legale-es`, che compaiono in
`docs/compliance/<paese>/` quando le PR sono unite). Le regole degli store cambiano spesso: le citazioni sotto vanno riconfermate
nelle console. Ho letto le pagine ufficiali di Google solo tramite ricerca; per Apple ho letto sintesi di terzi (fonti in fondo).

## 1. Blocchi alla pubblicazione (verificati sul codice)

| # | Cosa | Perché | Dove |
|---|---|---|---|
| B1 | **Manca l'eliminazione dell'account nell'app** (e un link web per chiederla) | Google Play lo richiede per ogni app con account creabili, con domanda nel modulo Data safety; l'App Store lo richiede (linea guida 5.1.1(v)). Disattivare non basta: servono la cancellazione dei dati o l'informativa sulla conservazione | `grep` di `deleteAccount`/`delete_account` in `apps/` e `packages/`: nessun risultato; l'informativa (`09_…`, riga 72) ha ancora "da definire" sulla conservazione |
| B2 | **Abbonamenti non reali**: i metodi di pagamento sono dimostrativi, i prezzi segnaposto | Un abbonamento digitale deve passare dalla fatturazione dello store (Google Play Billing / acquisti in-app Apple). Nelle schede non c'è alcun prezzo né prova gratuita per questo | `docs/auth/01_brainstorm.md` (trial e piani), `features/billing` |
| B3 | **Consenso esplicito prima di inviare dati personali a un'IA di terze parti** (App Store, 5.1.2(i), in vigore da novembre 2025) | Apple chiede di dire dove i dati vanno, anche a IA di terze parti, e di ottenere un permesso esplicito prima. Una riga nell'informativa non basta secondo le fonti consultate. Oggi c'è il consenso per la cartella clinica per animale (`03_…`), ma non ho trovato una schermata che nomini il fornitore (oggi Groq) e cosa gli viene inviato prima della prima domanda in chat | `docs/compliance/04_termini_e_consensi.md`, `09_…` riga 53 |
| B4 | **Segnalazione di contenuti IA offensivi nell'app** (Google Play, norma sui contenuti generati dall'IA) | La norma chiede una segnalazione dentro l'app per le app con IA generativa al centro (la chat lo è). Esiste il servizio `report_chat_response` (backend) e `docs/compliance/02_…` lo cita: da verificare che sia raggiungibile da ogni risposta dell'assistente, in tutte le lingue | `packages/core/application/services/report_chat_response.py` |
| B5 | Anonimizzazione solo per l'italiano | Vedi `README.md`: le schede non italiane dicono che si applicano filtri per la privacy | `docs/i18n/BACKEND_ITALIAN_CLASSIFIERS.md` |
| B6 | Dichiarazione dei servizi in primo piano (posizione) per Play | La passeggiata usa `FOREGROUND_SERVICE_LOCATION`: serve il video/descrizione richiesti da Play | `docs/compliance/05_permessi_dispositivo_os.md`, punto 26 di `08_…` |
| B7 | Account sviluppatore: indirizzo e contatti pubblici (obbligo da "trader" ai sensi del DSA nell'UE) | Entrambi gli store mostrano i dati di contatto nelle schede UE | Console degli store |

B1-B3 impediscono l'approvazione; B4-B7 sono richieste frequenti in revisione.

## 2. Classificazione per età

**Posizione del prodotto:** il servizio è **18+** in tutti i paesi (termini d'uso delle bozze legali per UK, US, AU, DE, AT, CH, FR, BE, ES e
quella italiana). Non è un'app per bambini: in Play scegliere pubblico di destinazione "solo 18+" (nessuna policy Famiglie); non si
raccolgono dati di minori di proposito.

| Store | Cosa fare |
|---|---|
| Google Play | Questionario IARC per il rating: risposte da dare con i dati di oggi → contenuti generati dagli utenti: **sì** (segnalazioni di luoghi, stelle sulle aree cani; Mercatino se pubblico); condivisione della posizione con altri utenti: **no** (la posizione resta dell'utente); acquisti digitali: **sì**; chat con IA: **sì**; violenza, sesso, linguaggio, droghe, gioco d'azzardo: **no**. Il risultato sarà probabilmente un rating giovanile (PEGI 3/12 a seconda delle risposte sui contenuti utente): è il rating del *contenuto*, non l'età minima dichiarata nei termini |
| App Store | Rispondere al questionario aggiornato (livelli 4+, 9+, 13+, 16+, 18+). Le domande nuove riguardano controlli in-app, argomenti medici o di benessere (qui sono salute **degli animali**, non delle persone: rispondere in modo coerente con le definizioni di Apple) e, da settembre 2026, funzioni "social" (feed o scoperta di contenuti degli utenti). Segnalazioni di luoghi e Mercatino potrebbero contare come tali e portare un minimo di 13+. **Raccomandazione: impostare manualmente 18+ su Apple**, coerente con i termini; lo sviluppatore può alzare il livello |

Punto aperto per il proprietario: per l'Australia la bozza legale chiede se l'app resta 18+ e se lasciare segnalazioni e stelle sulle
aree cani (`docs/compliance/au/08_domande_per_proprietario.md`).

## 3. Scheda privacy (Play "Data safety" / App Store "Privacy nutrition label")

Da compilare con i dati reali; la base è `09_informativa_privacy_bozza.md` e `02_pii_anonymization.md`. Valida per tutti i paesi:
le schede degli store sono globali (una sola per app), quindi vale il caso più severo.

| Dato | Raccolto | Condiviso con terzi | Scopo | Facoltativo |
|---|---|---|---|---|
| Email | sì | no (Supabase è fornitore) | Account | no |
| Nome visualizzato | sì | no | Account | sì |
| ID utente | sì | no | Account | no |
| Posizione precisa o approssimativa | sì | sì, in forma ridotta: il centro di una cella a OpenStreetMap/Overpass e l'indirizzo scritto a Nominatim, con l'IP della richiesta | Funzioni dell'app (zona, luoghi vicini, passeggiate) | sì |
| Percorso delle passeggiate | sì | no | Funzioni dell'app | sì |
| Foto e video | sì | no (archiviazione Supabase) | Funzioni dell'app | sì |
| Audio (messaggi vocali) | sì | sì: trascrizione da Groq | Funzioni dell'app | sì |
| Testo della chat, documenti della cartella clinica | sì | sì: Groq (dopo filtri di privacy) | Funzioni dell'app | sì |
| Dati di pagamento | **no** oggi (fatturazione dimostrativa) | — | — | — |
| Analisi d'uso | solo con il consenso "analytics" (Impostazioni → Permessi e consensi); verificare quali SDK | da verificare | Analisi | sì |
| Diagnostica / arresti anomali | da verificare | da verificare | — | — |

Altre risposte: cifratura in transito **sì** (HTTPS); eliminazione dei dati **richiesta dallo store: vedi B1**; nessuna pubblicità e nessun
tracciamento tra app (**da confermare**: oggi non risultano SDK pubblicitari). I fornitori che trattano i dati per conto di VetApp
(Supabase, Vercel, Groq) sono "service provider"; Play non li conta come condivisione se agiscono solo su istruzione, ma
Groq riceve contenuti dell'utente e va dichiarato nell'informativa. Trasferimenti extra-UE: `09_…`, punto 4.

## 4. Dichiarazioni sull'IA

| Dove | Dichiarazione | Stato |
|---|---|---|
| Nell'app | Badge "generato dall'IA" su ogni risposta del modello (AI Act art. 50) | fatto, `01_ai_disclosure.md`; da verificare che la traduzione sia in tutte le lingue |
| Schede | "Le risposte … sono sempre indicate come generate dall'IA", "non fa diagnosi" | presente in tutte le schede (`listings/`) |
| App Store | Linea 5.1.2(i): nominare il fornitore IA e chiedere il permesso prima del primo invio | **da fare (B3)** |
| Google Play | Contenuti generati dall'IA: segnalazione in-app e filtri | **verificare (B4)** |
| UE | AI Act: gli obblighi di trasparenza dell'art. 50 si applicano da agosto 2026; la chat è l'unica funzione generativa | `01_ai_disclosure.md` |

## 5. Per paese

Una voce per paese di disponibilità; il testo legale vero è nei documenti collegati. "Età del consenso" è quella per il trattamento dei dati
(conoscenza generale e bozze legali, da verificare); il servizio resta 18+.

| Paese | Età del consenso al trattamento dati | Cose da sapere per lo store | Documenti |
|---|---|---|---|
| Italia | 14 anni | Informativa `09_…`; consensi `04_…`; IA `01_…` | `docs/compliance/` |
| Regno Unito | 13 anni; Children's Code se «probabile accesso di minori» | Valutazione scritta del Codice se l'app può essere usata da minori; l'app resta 18+ | `docs/compliance/uk/` |
| Stati Uniti | COPPA sotto 13 anni solo con conoscenza effettiva; leggi statali (California ecc.) | Scheda privacy con le categorie CCPA; numeri utili in `06_numeri_utili_us.md` | `docs/compliance/us/` |
| Australia | Codice sulla privacy online dei minori da registrare entro il 10/12/2026 | Domanda aperta sull'età minima e sui contenuti degli utenti | `docs/compliance/au/` |
| Germania | 16 anni; minori con capacità limitata (§§ 104 ss. BGB) | Impressum obbligatorio nelle schede e nell'app | `docs/compliance/de/` |
| Austria | 14 anni (§ 4 DSG) | come la Germania | `docs/compliance/at/` |
| Svizzera | maggiore età 18; nuova legge sulla protezione dei dati | Dichiarare il rappresentante se il titolare è all'estero (da verificare) | `docs/compliance/ch/`, `ch-fr/` |
| Francia | 15 anni | Vendita di animali tra privati limitata (rilevante solo per il Mercatino, non incluso nelle schede) | `docs/compliance/fr/` |
| Belgio | 13 anni | età minima dell'acquirente diversa per regione (Mercatino) | `docs/compliance/be/` |
| Spagna | 14 anni (LOPDGDD art. 7) | AEPD e IA: guide da rispettare; progetto di legge sui minori online ancora in esame | `docs/compliance/es/` |

## Fonti consultate per le regole degli store (riconfermare nelle console)

- Google Play, eliminazione dell'account: <https://support.google.com/googleplay/android-developer/answer/13327111>
- Google Play, contenuti generati dall'IA: <https://support.google.com/googleplay/android-developer/answer/14094294>
- Apple, linea guida 5.1.2(i) sull'IA di terze parti (sintesi): <https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai>
- Apple, nuovi livelli di età 13+/16+/18+ e domande su funzioni social (sintesi): <https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/>, <https://ecorpit.com/app-store-age-rating-social-media-questions-september-2026/>
