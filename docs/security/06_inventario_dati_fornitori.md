# Inventario dei dati e dei fornitori (sub-responsabili)

Ultimo aggiornamento: 2026-10-26. Serve a tre cose: compilare il **registro dei
trattamenti** (GDPR art. 30), rispondere alla sezione **Data safety** di Google
Play, e sapere a chi chiedere cosa in caso di incidente. Da aggiornare ogni
volta che si aggiunge una funzione che tratta dati personali
(vedi `05_checklist.md`).

Glossario: **titolare** = chi decide (VetApp); **responsabile** o
**sub-responsabile** = fornitore che tratta dati per conto nostro (Supabase,
Vercel, Groq...); **DPA** = Data Processing Agreement, il contratto art. 28 GDPR
che ogni responsabile deve offrire; **SCC** = clausole contrattuali standard UE
per trasferire dati fuori dall'UE; **DPF** = EU-US Data Privacy Framework,
decisione di adeguatezza che permette il trasferimento verso aziende USA
certificate; **TIA** = valutazione dell'impatto del trasferimento.

## 1. Dati trattati

| Categoria | Dati | Dove sono | Base giuridica (da confermare col legale) | Conservazione | Sensibilità |
| --- | --- | --- | --- | --- | --- |
| Account | e-mail, hash password (gestito da Supabase Auth), id utente, data creazione, telefono (facoltativo, in arrivo) | Supabase Auth (IE) | contratto (art. 6.1.b) | fino a cancellazione account | media: e-mail = identificatore diretto |
| Consensi | versione ToS/privacy accettata, flag marketing/analytics, consenso cartella clinica per animale | `account_consents`, `pet_profiles` (Supabase) | obbligo legale (art. 6.1.c, art. 7.1) | fino a cancellazione + prova per 5 anni (da decidere) | bassa |
| Profilo animale | nome, specie, razza, data di nascita, sesso, peso, microchip (se inserito), foto | `pet_profiles`, `pet_weight_measurements`, `pet_photos` + bucket `pet-photos` | contratto | fino a cancellazione | bassa (ma il microchip è collegabile al proprietario tramite anagrafe) |
| Cartella clinica | eventi clinici, note, file (PDF, foto), condizioni croniche; può contenere nome/contatto del veterinario e del proprietario | `clinical_events`, `pet_conditions`, bucket `chat-attachments` | contratto + consenso specifico per l'uso in chat | fino a cancellazione | **alta**: documenti di terzi, dati inferibili sulla famiglia |
| Conversazioni con l'assistente | messaggi, allegati (foto), trascrizioni vocali, risposte, segnalazioni di risposte | `conversations`, `chat_attachments`, `chat_response_reports` | contratto; consenso per cartella clinica | fino a cancellazione; segnalazioni pseudonimizzate | **alta**: testo libero, può contenere qualunque cosa |
| Posizione | posizione GPS o indirizzo manuale, città; percorsi delle passeggiate (serie di punti GPS con orari) | `user_locations`, `dog_walks` | contratto/consenso (permesso OS) | passeggiate: fino a cancellazione | **alta**: abitudini e indirizzo di casa inferibili dai percorsi |
| Mercatino | annunci (titolo, testo, prezzo, foto, posizione arrotondata a ~1 km, città, id utente), segnalazioni | `marketplace_listings`, `marketplace_listing_reports`, bucket `marketplace-photos` (pubblico) | contratto | fino a rimozione | media: annunci pubblici per scelta dell'utente |
| Contributi radar/eventi | segnalazioni luoghi e stelle (con pseudonimo), proposte eventi (con id utente) | `radar_user_reports`, `radar_report_votes`, `radar_place_ratings`, `event_submissions` | legittimo interesse/contratto | 90 giorni per le segnalazioni scadute (da verificare) | bassa (pseudonimo) |
| Abbonamento | piano, stato, scadenza prova, slot fondatore; eventi webhook Stripe (ramo roberto) | `subscriptions`, `billing_*` | contratto | fino a cancellazione + obblighi fiscali | media |
| Uso del servizio | contatori messaggi/giorno per utente, ledger token Groq (senza testo), cache risposte anonimizzate | `chat_user_daily_usage` (30 gg), `llm_usage*` (90 gg), `chat_answer_cache` | legittimo interesse (limitare abusi/costi) | come indicato | bassa |
| Esportazione dati (art. 15/20) | file JSON generato su richiesta con tutte le righe delle tabelle sopra + link firmati ai file validi 15 minuti; telefono e foto profilo inclusi se presenti | generato al volo da `GET /account/export`, **non conservato** lato server; resta sul dispositivo dell'utente | obbligo legale (art. 15, 20) | nessuna (non salvato) | **alta**: il file riunisce tutto; l'app deve avvisare l'utente di conservarlo con cura |
| Log tecnici | log applicativi Vercel (richieste, errori), log Supabase (API, Auth, Postgres) | Vercel (IE/USA), Supabase (IE) | legittimo interesse (sicurezza) | Vercel: 1 ora runtime logs su piano hobby, Supabase: 1 giorno su piano free, 7 su Pro (da verificare col piano attivo) | media (IP, user id) |
| Dati su dispositivo | sessione Supabase, preferenze, cache foto/video, bozze, notifiche programmate | storage privato dell'app Android / localStorage web | — | fino a logout/disinstallazione | vedi audit app |

Non trattiamo: dati sanitari **umani**, dati di minori in modo consapevole (età
minima da far rispettare: vedi quadro normativo), dati di pagamento (Stripe li
tiene lui, noi solo id e stato).

## 2. Fornitori (responsabili e sub-responsabili)

| Fornitore | Ruolo | Dati che riceve | Paese sede / dati | Base del trasferimento | DPA | Stato |
| --- | --- | --- | --- | --- | --- | --- |
| **Supabase Inc.** | database Postgres, autenticazione, storage file | tutto il DB, credenziali, file | sede USA; progetto `ywbuzgwbkrmkukkpysbz` in **Irlanda** (AWS eu-west-1) | dati in UE; accesso di supporto dagli USA coperto da DPA + SCC/DPF (verificare certificazione DPF nella lista ufficiale) | DPA standard accettabile dalla dashboard (Organization → Legal documents) | **da accettare/archiviare** |
| **Vercel Inc.** | hosting backend FastAPI (progetto `vet-app`, regione `dub1` Dublino) e portale admin (`vet-app-34xp`) | tutte le richieste in transito, log runtime, variabili d'ambiente (segreti) | sede USA; funzioni in Irlanda; log/edge network globali | DPA Vercel (include SCC); Vercel è certificata DPF (verificare) | DPA online (vercel.com/legal/dpa) | **da accettare/archiviare** |
| **Groq Inc.** | modelli LLM per chat, classificatore urgenza, visione allegati, trascrizione vocale (Whisper) | testo dei messaggi, cronologia recente, profilo animale sintetico, immagini allegate, audio | **USA** (elaborazione negli USA) | **trasferimento extra-UE**: serve DPA + SCC o DPF (verificare se Groq è nella lista DPF; altrimenti SCC nei termini) + TIA; zero data retention per API da verificare nei termini | termini API Groq | **da verificare: priorità alta** |
| **Google LLC – Firebase App Distribution** | distribuzione APK ai tester | e-mail dei tester, id dispositivo | USA / globale | DPF (Google LLC certificata) + Google Cloud DPA | Firebase Data Processing and Security Terms | accettati implicitamente con l'account; archiviare |
| **Google LLC – Google Play** | distribuzione pubblica, firma app, pagamenti in-app (se usati) | dati di installazione, crash (se abilitati) | USA / globale | Google è titolare autonomo per il Play Store | Developer Distribution Agreement | al lancio |
| **Stripe** (ramo roberto, non ancora in main) | pagamenti abbonamenti | e-mail, importi, metodo di pagamento (mai da noi) | USA / IE (Stripe Payments Europe) | DPF + SCC | Stripe DPA | quando si attiva |
| **OpenStreetMap Foundation – Nominatim** | geocodifica indirizzo manuale (chiamata **diretta dall'app**) | indirizzo digitato + IP del telefono | UK/EU | titolare autonomo (policy OSMF); da citare nell'informativa | nessun DPA (servizio pubblico) | in uso |
| **OpenStreetMap Foundation – tile server** | mappe nell'app (chiamata diretta dall'app) | IP + area di mappa vista (≈ posizione) | UK/EU | come sopra | — | in uso |
| **Overpass API** (overpass-api.de, kumi.systems, private.coffee) | ricerca servizi vicini (dal backend) | coordinate della cella di ricerca (non l'utente) | DE/AT/EU | nessun dato personale diretto (IP del backend Vercel) | — | in uso |
| **Overture Maps / dati comunali (Milano, Torino, Bologna)** | import offline di luoghi | nessun dato personale | — | — | licenze ODbL/CC | in uso |
| **Europe PMC, PubMed (NCBI), Crossref, OpenAlex** | ricerca letteratura scientifica (dal backend) | testo della query normalizzata (può derivare dal messaggio utente: **verificare che non contenga nomi**) | UK, USA, USA, USA | i dati inviati dovrebbero essere solo termini clinici; valutare | — | in uso |
| **DeepL SE** | traduzione bozze testi dell'app (CI, non dati utenti) | stringhe dell'interfaccia | Germania | nessun dato personale | — | in uso in CI |
| **GitHub Inc.** | repository pubblico, CI, secrets | codice, log CI, segreti di build | USA | nessun dato personale degli utenti deve passare da qui | — | in uso |
| **Editori RSS (news)** | notizie nell'app (dal backend) | nessun dato personale (richieste del backend) | vari | — | — | in uso |
| **Presidio (Microsoft, libreria locale)** | anonimizzazione testi | gira nel backend, nessun invio esterno | — | — | — | opzionale (`PII_ANONYMIZER_BACKEND`) |
| **Sentry (Functional Software Inc.)** — adottato il 2026-10-28 (commit cc648c6), **spento finché il proprietario non crea l'organizzazione in regione EU e firma il DPA** (build con `CRASH_REPORTING=true` + `SENTRY_DSN`, più consenso `diagnostics` dell'utente) | segnalazione crash ed errori dell'app Android | come da filtro `scrubCrashEvent`: tipo dell'eccezione, stack trace (file e funzioni del nostro codice), contesti device/os/app/runtime/culture, environment = package name, release = versione+build. **Esclusi**: testo dell'eccezione, messaggi, utente/IP/e-mail, URL/richieste, breadcrumb, extra, tag, contesti dei widget | sede USA; organizzazione nella **regione EU (Francoforte)** | dati in UE; DPA con SCC; DPF dichiarata (verificare) | DPA dalle impostazioni legali dell'organizzazione | consenso opt-in `diagnostics` (art. 6.1.a); conservazione 90 giorni |

## 3. Cosa deve fare il proprietario con questa tabella

1. Scaricare/accettare e **archiviare** i DPA di Supabase, Vercel, Groq, Google
   (cartella privata, non nel repo) con la data.
2. Verificare nella lista ufficiale <https://www.dataprivacyframework.gov/list>
   quali tra Supabase, Vercel, Groq, Google sono certificate; per chi non lo è,
   verificare che il DPA includa le SCC e scrivere una breve **TIA** (una pagina:
   quali dati, quale paese, quali garanzie, perché il rischio è accettabile).
3. Inserire tutti i fornitori nell'**informativa privacy**
   (`docs/compliance/09_informativa_privacy_bozza.md`) con il paese.
4. Per Groq, valutare se attivare un piano con impegno contrattuale di **non
   conservazione / non addestramento** sui dati inviati, oppure spostare la
   chat su un fornitore UE: decisione di prodotto, da prendere prima del lancio.
5. Aggiornare questa tabella quando cambia un fornitore (anche solo il paese
   della regione) e ricontrollare il registro dei trattamenti.

## 4. Elenco per la sezione Data safety di Google Play (bozza)

Dati raccolti (tutti crittografati in transito, cancellabili su richiesta
dall'app): **Informazioni personali** (e-mail, telefono facoltativo, id utente);
**Posizione** (precisa, per mappa/servizi vicini/passeggiate; approssimativa per
Mercatino); **Messaggi** (conversazioni con l'assistente); **Foto e video**
(profilo animale, cartella clinica, allegati, annunci); **Audio** (messaggi
vocali, solo trascrizione); **File e documenti** (cartella clinica);
**Attività nell'app** (contatori d'uso); **Salute**: NO (dati di animali, non
umani: dichiarare come "Altro" se richiesto). Finalità: funzionalità dell'app,
sicurezza/prevenzione abusi; nessuna pubblicità; condivisione con terze parti:
Groq (elaborazione IA), Supabase/Vercel (hosting). Da rivedere con l'audit
dell'app (`02_audit.md`, sezione app) prima di compilare il modulo.
