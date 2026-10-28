# Dichiarazioni per gli store: età, privacy, IA

Bozza di lavoro per compilare i moduli di Google Play e App Store. **Non è consulenza legale**: parte dalle bozze in `docs/compliance/`
(e, per paese, dai documenti sui rami `ml/revisione-e-legale-en`, `ml/legale-de`, `ml/legale-fr`, `ml/legale-es`, che compaiono in
`docs/compliance/<paese>/` quando le PR sono unite). Le regole degli store cambiano spesso: le citazioni sotto vanno riconfermate
nelle console. Ho letto le pagine ufficiali di Google solo tramite ricerca; per Apple ho letto sintesi di terzi (fonti in fondo).

## 1. Blocchi alla pubblicazione (verificati sul codice)

| # | Cosa | Perché | Dove |
|---|---|---|---|
| B1 | **Eliminazione dell'account**: fatta nell'app (Impostazioni → Account → Elimina account, con nuova verifica della password; `DELETE /account` cancella ogni tabella e file, test di copertura sullo schema). **Manca ancora la pagina web** per chiedere la cancellazione senza l'app, richiesta da Play (link da inserire nel modulo Data safety) | Google Play la richiede per ogni app con account; App Store 5.1.1(v) | `apps/api/routes/account.py`, `delete_account_page.dart`; da fare: una pagina statica (es. sul sito o nel portale) con istruzioni e un contatto e-mail |
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

Aggiornata il 2026-10-28 dalla sessione Cybersicurezza sul codice del ramo Francesco (build 36, nome Quokka).
Coerente con `docs/security/06_inventario_dati_fornitori.md` e con `docs/compliance/09_informativa_privacy_bozza.md`
(versione 2026-10-28: cognome, telefono facoltativo, foto profilo). La scheda degli store è una sola per app in tutto il mondo:
vale il caso più severo.

### 3.1 Come risponde Google alle domande "condiviso?"

Google Play considera **"condivisione"** il trasferimento a una terza parte che tratta i dati per conto proprio. **Non** è
condivisione il trasferimento a un **fornitore che tratta i dati solo per conto nostro** su istruzione contrattuale
(service provider): Supabase (database, autenticazione, file), Vercel (hosting del backend), Groq (modelli per chat,
visione, trascrizione) e Firebase App Distribution (solo tester) rientrano qui, **a condizione** che esista il contratto
di trattamento (DPA) con ciascuno (vedi inventario fornitori: Groq da firmare). Vanno comunque nominati nell'informativa.
Sono invece **condivisione** vera e propria: **OpenStreetMap Foundation** (Nominatim riceve l'indirizzo scritto a mano e
l'IP del telefono; il server delle mappe riceve l'IP e l'area visualizzata) e, se si attivasse, un servizio di crash
reporting non coperto da DPA. Non sono condivisione: i trasferimenti richiesti dalla legge, quelli anonimizzati, quelli
decisi dall'utente (condividere un referto con il proprio veterinario dal telefono).

### 3.2 Risposte al modulo, tipo per tipo

Colonne: Raccolto (lasciando il dispositivo) · Condiviso · Trattato solo temporaneamente (ephemeral) · Obbligatorio ·
Finalità (voci del modulo Play). "Funzionalità" = App functionality; "Sicurezza" = Fraud prevention, security and compliance;
"Account" = Account management.

| Categoria Play → tipo | Raccolto | Condiviso | Temporaneo | Obbligatorio | Finalità | Note dal codice |
|---|---|---|---|---|---|---|
| Informazioni personali → **Nome** | sì (nome visualizzato, cognome) | no | no | sì (nome alla registrazione) | Account, Funzionalità | `display_name`/`surname` nei metadati Supabase Auth |
| Informazioni personali → **Indirizzo email** | sì | no | no | sì | Account, Funzionalità, Sicurezza | Supabase Auth; usata anche per l'allowlist admin/sviluppatori |
| Informazioni personali → **ID utente** | sì | no | no | sì | Account, Funzionalità, Sicurezza | UUID Supabase; pseudonimizzato nelle segnalazioni |
| Informazioni personali → **Numero di telefono** | sì | no | no | **no** (facoltativo) | Account | Metadati profilo; nessuna funzione lo usa oggi; cancellabile dal profilo |
| Informazioni personali → **Indirizzo** | sì (indirizzo di casa scritto a mano, se scelto) | **sì**: OpenStreetMap Nominatim riceve il testo dell'indirizzo per trovarne le coordinate | no | no | Funzionalità | `address_geocoder.dart` chiama Nominatim **dal telefono**; coordinate e etichetta salvate in `user_locations` |
| Informazioni personali → Altre info | sì (specie, razza, nome, dati clinici degli **animali**) | no | no | no | Funzionalità | Non sono dati sanitari dell'utente: dichiarare qui, non in "Salute e fitness" |
| Posizione → **Posizione approssimativa** | sì | **sì**: il server delle mappe OSM riceve l'IP e l'area visualizzata | no | no | Funzionalità | Mercatino usa coordinate arrotondate a ~1 km |
| Posizione → **Posizione precisa** | sì (GPS per passeggiate, servizi vicini, posizione attuale) | no (il backend interroga Overpass con il centro di una cella, non con la posizione dell'utente) | no | no | Funzionalità | Percorsi in `dog_walks`; nessuna posizione in background |
| Messaggi → **Altri messaggi in-app** | sì (conversazioni con l'assistente) | no (Groq = fornitore) | no | no | Funzionalità | Testo anonimizzato prima dell'invio al modello; salvato in `conversations` |
| Foto e video → **Foto** / **Video** | sì (profilo animale, galleria, allegati chat/cartella, foto profilo, foto annunci) | no (Groq = fornitore per l'analisi delle foto in chat); le foto degli annunci sono **pubbliche** per scelta dell'utente | no | no | Funzionalità | Metadati EXIF/posizione rimossi; bucket privati tranne `marketplace-photos` |
| Audio → **Registrazioni vocali** | sì (dettatura in chat) | no (Groq = fornitore per la trascrizione) | **sì**: l'audio non è salvato, resta solo il testo | no | Funzionalità | `speech_to_text.py`: niente persistenza |
| File e documenti | sì (referti PDF e immagini della cartella clinica) | no (Groq = fornitore, solo con consenso per animale) | no | no | Funzionalità | Bucket privato `chat-attachments`; testo anonimizzato |
| Salute e fitness | **no** | — | — | — | — | I dati clinici sono degli animali |
| Informazioni finanziarie | **no** | — | — | — | — | Nessun pagamento reale oggi; quando arriva: Play Billing, nessun dato di carta nell'app |
| Contatti | no | — | — | — | — | Nessun accesso alla rubrica |
| Calendario | no | — | — | — | — | Promemoria interni all'app, notifiche locali |
| Attività nell'app → **Interazioni con l'app** | no (nessun SDK di analisi) | — | — | — | — | Il consenso "analytics" in Impostazioni esiste ma oggi non attiva alcun SDK: rispondere **no** finché resta così |
| Attività nell'app → **Contenuti generati dagli utenti** | sì (annunci, segnalazioni di luoghi e stelle, proposte di eventi, segnalazioni di risposte) | no (annunci ed eventi approvati sono visibili agli altri utenti dentro l'app: Play non lo conta come condivisione con terzi) | no | no | Funzionalità | Pseudonimi per le segnalazioni radar |
| Cronologia web / navigazione | no | — | — | — | — | — |
| Info e prestazioni dell'app → **Log di arresto anomalo / Diagnostica** | **no oggi**; se si adotta il crash reporting (vedi `docs/security/10_crash_reporting.md`) → sì, non condiviso (fornitore con DPA), facoltativo, finalità Analisi | — | — | — | — | Nessun SDK oggi |
| ID dispositivo o altri ID | no | — | — | — | — | Nessun ID pubblicitario; solo l'installation ID se si adotta Crashlytics |

### 3.3 Altre risposte del modulo

| Domanda | Risposta | Base |
|---|---|---|
| I dati sono crittografati in transito? | **Sì** | HTTPS verso Supabase, backend Vercel e Nominatim/OSM; HSTS sul backend e sulla web app |
| Gli utenti possono chiedere la cancellazione dei dati? | **Sì**, nell'app (Impostazioni → Account → Elimina account) | `DELETE /account`; **serve anche l'URL della pagina web** (vedi B1) |
| L'app permette di cancellare alcuni dati senza eliminare l'account? | Sì | Animali, conversazioni, promemoria, foto, annunci, posizione, telefono e foto profilo si cancellano singolarmente |
| Esportazione dei dati | Sì | `GET /account/export` (pulsante in app in arrivo) |
| L'app segue la Famiglie policy / è rivolta a minori? | No (18+) | Sezione 2 |
| Revisione di sicurezza indipendente (MASA) | No | Facoltativa |
| Raccolta dati obbligatoria per usare l'app | Solo nome, e-mail, ID utente; tutto il resto è facoltativo | Modulo "Required/Optional" |

### 3.4 Cosa deve essere vero prima di inviare la scheda

1. DPA firmati o accettati con Supabase, Vercel, Google (Firebase) e **Groq**: senza DPA, Groq va dichiarato come "condiviso" per messaggi, foto, audio e documenti.
2. Pagina web per la richiesta di cancellazione (B1) pubblicata e linkata nel modulo.
3. Informativa privacy pubblicata a un URL stabile (la scheda la richiede) che nomini tutti i fornitori, OSM/Nominatim compreso.
4. Se si attiva il crash reporting: aggiornare la riga "Log di arresto anomalo" e l'informativa.
5. Rileggere questa tabella a ogni funzione che tratta dati nuovi (`docs/security/05_checklist.md`, sezione B).

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
