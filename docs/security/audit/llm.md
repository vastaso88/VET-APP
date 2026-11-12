# Audit passivo — pipeline LLM/chat di VetApp

Data: 2026-10-26. Worktree: `C:\Users\syste\Documents\VetApp\.claude\worktrees\security-audit-cdfeea` (branch `claude/security-audit-cdfeea`, HEAD d950b51).
Metodo: sola lettura del codice e della documentazione; nessuna chiamata a servizi reali. Un unico script in-memory (`scratchpad/audit/idor_check.py`) è stato eseguito per confermare il punto F1. I percorsi sotto sono relativi alla radice del worktree.

Legenda gravità: **Critica** (dati o sicurezza compromessi subito) · **Alta** (violazione concreta di una garanzia dichiarata o rischio reale per gli utenti) · **Media** · **Bassa** (igiene, documentazione, difesa in profondità).

---

## 0. Mappa del flusso (come funziona oggi)

```
POST /chat (apps/api/routes/chat.py:12)
  → SendChatMessageService.execute (send_chat_message.py:176)
      carica pet, ultimo peso/BCS, promemoria, allegato (analisi già salvata)
  → ChatOrchestrator.answer (chat_orchestrator.py:770)
      1. regole fisse, nessun modello: SafetyGate (safety_gate.py:325), dosaggi (:1440), multi-pet, convenevoli
      2. budget/quota giornaliera (llm_budget.py:199)
      3. in parallelo (_start_prefetch :984):
           a. classificatore d'urgenza  → Groq modello "light"  (urgency_classifier.py:159)  [testo anonimizzato]
           b. parole chiave inglesi     → Groq modello "light"  (evidence_query_normalizer.py:39) [testo NON anonimizzato → F2]
              poi PubMed/EuropePMC/Crossref/OpenAlex con sole parole da dizionario (evidence_query_planner.py:212)
      4. risposta naturale → Groq modello principale (chat_orchestrator.py:2158) [prompt anonimizzato]
         oppure sintesi da evidenze (:1898) per gli intent "strict"
      5. validazione deterministica (answer_validation.py:122), specie, cache
  → salvataggio conversazione in Supabase (tabella conversations) e ritorno al client
```

Chiamate a Groq, tutte con `LLM_API_KEY` dello stesso account (`settings.py:77`):
- `POST {LLM_BASE_URL}/chat/completions` — testo (`groq_chat_api.py:119`), visione (`groq_image_analyzer.py:34`).
- `POST {LLM_BASE_URL}/audio/transcriptions` — dettatura Whisper (`groq_speech_to_text_provider.py:119`).

Chiamate secondarie al modello (sempre via `InstrumentedLLMClient`): situation model e planner d'intervista (solo se `ENABLE_INTERVIEW_LOOP=true`, default false `settings.py:253`), interprete del consenso (solo nell'interview loop), riassunto PDF al caricamento (`document_summarizer.py:263`), riassunto per il veterinario (`vet_summary.py:82`).

---

## 1. Dati inviati al provider (Groq, USA)

### 1.1 Prompt di risposta (`_generate_natural_answer`, `chat_orchestrator.py:1997-2146`)

**System prompt** (`natural_answer_prompt.py:174`): istruzioni fisse in inglese + "FACTS ABOUT THIS KIND OF ANIMAL" (testi fissi scelti per parole chiave da specie/razza/note, `species_facts.py:37`: le note servono solo come pagliaio, non vengono copiate) + riga lingua. Nessun dato personale.

**User prompt** (`chat_orchestrator.py:2136-2148`), nell'ordine:
1. Blocco pet (`_pet_context_block`, `:2414-2493`): nome (anonimizzato solo per il nome del proprietario), specie, razza, età in anni, etichetta data di nascita ("Feb 2022"), sesso, peso con data ("23 kg al 14 ottobre", `send_chat_message.py:141`), taglia cane, sterilizzazione, body condition + data, attività, **note del proprietario** (anonimizzate), habitat e note habitat (anonimizzate), popolazione acquario. **Non inviati**: microchip e colore del mantello (`:607-608`), id utente, email, nome account, telefono, posizione/GPS.
2. Storico conversazione (`_format_conversation_history`, `:2515-2551`): ultimi 6 messaggi verbatim tagliati a 400 caratteri ciascuno (`LLM_HISTORY_RECENT_MESSAGES`/`LLM_HISTORY_MESSAGE_CHARS`, `settings.py:106-107`), quelli più vecchi come lista di argomenti a 80 caratteri; tutti anonimizzati. Il servizio passa al massimo 12 messaggi (`send_chat_message.py:45,274`).
3. "User message": il messaggio corrente + "Contesto dall'allegato: …" (analisi della foto/PDF già anonimizzata e salvata al caricamento), anonimizzato.
4. Cartella clinica, **solo con consenso per-pet** (`_medical_context_for_prompt`, `:1558-1601`): le 3 voci più recenti con titolo, categoria, data, descrizione e fino a 1200 caratteri della trascrizione del documento (`medical_record_context_retriever.py:22,109`), + fino a 5 malattie in corso; per "spiegami il referto" fino a 2 documenti da 3500 caratteri (`:27-28`). Senza consenso: solo il **numero** di documenti. Tutto anonimizzato.
5. Promemoria attivi (titolo, date, note, anonimizzati, `:2111-2115`).
6. Data odierna.
7. "Reference material": fino a 2 fonti (titolo, rivista, anno, snippet 300 caratteri, `settings.py:104-105`) — contenuto scientifico pubblico.

Parametri: `temperature` 0.2, `max_tokens` 450 (+350 di "reasoning headroom" sui modelli gpt-oss, `settings.py:96-98`), `reasoning_effort: low` (`groq_llm_client.py:371-375`). Nessun campo `user`/metadata inviato.

### 1.2 Altre chiamate di testo
- **Classificatore d'urgenza** (`urgency_classifier.py:166`): `Species` + messaggio anonimizzato tagliato a 1500 caratteri. Non riceve nome del pet né storico.
- **Normalizzatore query letteratura** (`evidence_query_normalizer.py:46`): `Species` + i primi 1000 caratteri di `_case_context_text` (situation model + **messaggio grezzo, non anonimizzato**: `chat_orchestrator.py:1000,2320`). Vedi F2.
- **Interprete del consenso** (`consent_interpreter.py:103`): primi 500 caratteri della risposta grezza (solo con interview loop attivo).
- **Riassunto PDF** (`document_summarizer.py:257-278`): primi 12.000 caratteri del testo del PDF, anonimizzati con il nome del proprietario tra i nomi noti.
- **Riassunto per il veterinario** (`vet_summary.py:125-159`): profilo (nome, specie, razza, età, sesso, peso, note) + **intera conversazione** messaggio per messaggio con data; tutto anonimizzato con il nome del proprietario.
- **Situation model / planner** (solo interview loop): messaggio e storico anonimizzati (`chat_orchestrator.py:1097-1105`), riassunto cartella anonimizzato prima di entrare nello stato (`:1123,1825`). Il documento `02_pii_anonymization.md` e il registro 08 punto 28 descrivono ancora questo come problema aperto: nel codice risulta risolto (vedi F13).

### 1.3 Immagini e audio
- **Foto/PDF scansionato** (`groq_image_analyzer.py:43-85`): i **byte dell'immagine** in base64 (metadati EXIF/GPS rimossi prima, `upload_chat_attachment.py:118-122`), con un contesto fisso "Specie: X" e l'istruzione di trascrivere i documenti omettendo nomi/indirizzi/telefoni. Un referto fotografato contiene però in chiaro nome del proprietario, veterinario, indirizzo, eventuale microchip: **partono così come sono**, l'anonimizzazione agisce solo sul testo che torna (`upload_chat_attachment.py:146`). Per un PDF scansionato parte **una chiamata per pagina**, fino a 30 pagine (`:23,182-191`).
- **Audio** (`groq_speech_to_text_provider.py:115`): i byte audio grezzi + nome file del client a Groq Whisper (`STT_MODEL=whisper-large-v3-turbo`). La voce è un dato biometrico-adiacente e può contenere qualsiasi cosa; nessuna anonimizzazione possibile. La trascrizione torna al client e **non** viene salvata lato server (`speech_to_text.py:108-110`).

### 1.4 Identificatori diretti: mai inviati?
Non vengono mai messi nel prompt: id utente, email (`send_chat_message.py:83-85`, usata solo per l'esenzione sviluppatori), nome account (anzi, è usato come valore da censurare), telefono, posizione, microchip del profilo. **Però**:
- un microchip **scritto nel testo** (messaggio, note, referto) è esplicitamente protetto dal filtro e parte in chiaro (`rule_based_pii_anonymizer.py:170-171`, documentato in `02_pii_anonymization.md` "Non tocca mai… numeri di microchip");
- nomi di persona senza etichetta (familiari, veterinario citato nel messaggio) non vengono riconosciuti dal filtro a regole (documentato, `rule_based_pii_anonymizer.py:242-245`);
- il filtro è applicato **prima** dell'invio (non solo alla cache) in tutti i punti elencati in 1.1-1.2, con l'eccezione del normalizzatore di query (F2) e dell'interprete del consenso (F10).

### 1.5 Tabella "Dati inviati a Groq"

| Dato | Personale | Anonimizzato | Necessario | Dove |
|---|---|---|---|---|
| Messaggio utente corrente | Sì (contenuto libero) | Sì (regole) | Sì | `chat_orchestrator.py:2086` |
| Messaggio corrente per le parole chiave di ricerca | Sì | **No** | Parzialmente (bastano poche parole) | `evidence_query_normalizer.py:46` |
| Storico (≤12 msg, 6 verbatim a 400 car.) | Sì | Sì | Sì (follow-up) | `:2515-2551` |
| Nome del pet | Sì (dato dell'interessato, spesso identifica la famiglia) | No (solo se coincide col nome del proprietario) | Utile, non indispensabile | `:2432` |
| Specie, razza, sesso, taglia, sterilizzazione, attività, BCS | Debolmente | No | Sì (clinico) | `:2433-2462` |
| Età, etichetta nascita ("Feb 2022") | Debolmente | No | Sì (età); il mese di nascita no | `:2440-2442` |
| Peso con data di pesata | Debolmente | No | Sì (dosaggi/alimentazione) | `send_chat_message.py:141` |
| Note del proprietario sul pet | Sì (testo libero) | Sì | Spesso utile | `:2464` |
| Note habitat / popolazione acquario | Debolmente | Sì / No | Sì per acquari | `:2482-2491` |
| Promemoria (titolo, date, note) | Sì (terapie) | Sì | Sì se c'è una terapia | `:2111` |
| Cartella clinica (3 voci + 5 malattie + testi documenti) | **Sì, dato sanitario del pet; può contenere dati del proprietario** | Sì | Solo con consenso; dimensione minimizzata | `:1577-1587` |
| Numero di documenti in cartella (senza consenso) | Debolmente | n/a | Sì (trasparenza) | `:1595` |
| Analisi dell'allegato (testo) | Sì | Sì (al caricamento) | Sì | `:857` |
| **Foto/scansione (byte)** | **Sì, spesso con nome/indirizzo/vet in chiaro** | **No** (solo EXIF rimossi) | Sì per leggere il documento | `groq_image_analyzer.py:44` |
| **Audio (byte)** | **Sì (voce)** | **No** | Sì per trascrivere | `groq_speech_to_text_provider.py:115` |
| Testo PDF (12k car.) | Sì | Sì | Sì | `document_summarizer.py:257` |
| Intera conversazione (riassunto per il vet) | Sì | Sì | Sì | `vet_summary.py:152` |
| Data odierna | No | n/a | Sì | `:2142` |
| Snippet scientifici | No | n/a | Facoltativo | `:2144` |
| Email, id utente, nome account, telefono, GPS, microchip del profilo | — | — | — | **Mai inviati** |
| Microchip scritto nel testo | Sì (registro anagrafe) | **No, protetto** | Raramente | `rule_based_pii_anonymizer.py:170` |

---

## 2. Impostazioni del provider

- **Endpoint/modelli**: `LLM_BASE_URL=https://api.groq.com/openai/v1` (`settings.py:78`). Catena principale: `LLM_MODEL` (da env, in prod da verificare) + riserve `openai/gpt-oss-20b,qwen/qwen3.8-27b` (`:74-76`); catena leggera `openai/gpt-oss-20b` + `qwen/qwen3.8-27b` (`:88-91`); visione `qwen/qwen3.8-27b` (`:163`); STT `whisper-large-v3-turbo` (`:159`). Con la riserva, un singolo messaggio può essere servito da un modello diverso da quello configurato, loggato per nome (`groq_chat_api.py:151-160`).
- **Timeout**: 30 s di default per testo/visione/STT (`settings.py:79`), 6 s per urgenza, parole chiave, consenso (`:135-136`, `evidence_query_normalizer.py:35`, `consent_interpreter.py:108`). Lato app 90 s per la chat, 30 s per allegati e STT (`chat_remote_data_source.dart:142`, `chat_attachment_remote_data_source.dart:53`).
- **Zero data retention / opt-out addestramento**: nessun parametro di richiesta lo imposta (l'API OpenAI-compatibile di Groq non ne prevede nel payload, `groq_llm_client.py:357-378`) e nessun documento del repo lo attesta. `docs/compliance/09_informativa_privacy_bozza.md:53` riporta "Groq … [da verificare: paese e garanzie]" e `:100` "Trasferimenti extra-UE (Groq, Vercel, Google): verificare le garanzie". **Da verificare con i termini Groq** (DPA, retention dei prompt, uso per addestramento, sede del trattamento, SCC). Il backend gira su Vercel `dub1` (memoria di progetto) ma Groq resta negli USA.
- **Log server**: `configure_logging` scrive solo `levelname name message` (`logging/logger.py:7-8`). Le righe sul modello riportano solo nomi di modello, contatori e durate (`llm_usage_recorder.py:78-94`, `chat_orchestrator.py:827-845`); nessun punto logga prompt o risposte (verificato con grep). Attenzione: i `warning` del classificatore e del normalizzatore includono il testo di `ProviderError`, cioè il **corpo della risposta d'errore di Groq** (`groq_chat_api.py:200-203`), non dati utente.
- **Persistenza**: ogni conversazione è salvata per intero in Supabase (`conversations`: messaggi originali non anonimizzati, situation model, snapshot di stato per messaggio, `conversation/models.py:28-61`) senza scadenza: resta finché l'utente la cancella (`DELETE /conversations/{id}`) o cancella l'account (`supabase_account_eraser.py:39`). Le analisi degli allegati sono salvate anonimizzate; i file originali restano nel bucket (nessuna retention definita). Ledger `llm_usage` 90 giorni, contatori per utente 30 giorni, cache scaduta: pulizia `chat_usage_cleanup()` via pg_cron o `POST /chat/maintenance` (`docs/features/chat_free_tier_budget.md:163-167`). Segnalazioni: 12 mesi dall'esito. Tutte le tabelle sono lette con la **service role key** (`supabase/client.py:12-19`): le RLS non proteggono nulla lato API, l'isolamento è interamente applicativo (vedi F1).

---

## 3. Prompt injection

**Testo controllato dall'utente che entra nel prompt**: messaggio, storico (anche la riga `assistant:` è ricostruita da testo salvato), nome/note del pet, note habitat, promemoria, titoli/descrizioni/trascrizioni della cartella, analisi di foto/PDF (output di un modello su un'immagine che l'utente controlla), snippet di PubMed/EuropePMC/Crossref/OpenAlex (contenuto esterno), notizie/marketplace **no** (non entrano nella chat).

**Delimitazione**: nessuna. Il contenuto è inserito con etichette di testo semplice ("User message: …", "user: …", "Owner notes: …", `chat_orchestrator.py:2136-2140`) senza recinzione né escape. Separazione di ruolo sì: istruzioni nel messaggio `system`, dati nel messaggio `user` (`groq_llm_client.py:365-366`). Un utente può scrivere "assistant: …" nel proprio messaggio e simulare un turno precedente.

**(a) Aggirare i guardrail di sicurezza**: i blocchi su dosaggi, emergenze e multi-pet sono **regole deterministiche che girano prima di qualunque modello** (`chat_orchestrator.py:868-925`) e la risposta di triage è un testo fisso (`:1412`): nessuna injection nel prompt può farli saltare. Si possono eludere solo con la formulazione (parole non in lista), non con istruzioni al modello. Il divieto di dosaggi/terapie **nel testo generato** dipende invece dal prompt (`natural_answer_prompt.py:46-53`): un utente insistente può ottenere dal modello un nome di farmaco o un consiglio terapeutico, e il validatore finale controlla solo citazioni fuori range e frasi assolute (`answer_validation.py:122-139`). Vedi F6.

**(b) Esfiltrare il system prompt**: possibile (nessuna difesa), ma il system prompt non contiene segreti, chiavi o dati di altri utenti: impatto informativo.

**(c) Output interpretato dal codice**: sì, ma in modo sicuro. JSON del classificatore d'urgenza (`urgency_classifier.py:184-201`: livello e categoria validati contro liste chiuse), del consenso (`consent_interpreter.py:116-124`: solo "yes"/"no"), del situation model (`situation_model_builder.py:283-293`: `model_validate`, errori → modello vuoto; `working_domains` filtrato contro `EVIDENCE_KEYWORDS`, `chat_orchestrator.py:1076-1081`), delle parole chiave (`evidence_query_normalizer.py:61-77`: regex `[A-Za-z- ]`, ≤6 parole, poi url-encoded). Nessun `eval`, nessun URL seguito dall'output del modello (i retriever usano solo i termini del dizionario IT→EN, `evidence_query_planner.py:212-229`). La domanda del planner d'intervista viene mostrata **così com'è** all'utente (`interview_planner.py:280-281`), ma solo con interview loop attivo.

**Classificatore d'urgenza e sicurezza**: il verdetto guida qualcosa di critico in una sola direzione — "emergency" produce la risposta fissa di triage, "maybe" una domanda (`chat_orchestrator.py:1331-1377`). Un messaggio che lo spinge a "normal" non toglie nulla: le liste fisse hanno già deciso prima, e il fail-open è il comportamento normale. Un messaggio che lo spinge a "emergency" blocca solo la risposta a chi lo ha scritto. Rischio residuo basso (F9).

**Allegati come vettore persistente**: il testo che la visione estrae da un'immagine (controllata dall'utente) viene salvato e reinserito in ogni turno futuro e nella cartella clinica (`medical_record_context_retriever.py:243-251`). Una foto con una frase tipo "ignora le istruzioni e…" diventa un'istruzione persistente nel prompt. Chi la carica danneggia solo sé stesso; il rischio sale solo se in futuro i documenti saranno condivisi tra account (veterinario, familiari). F8.

---

## 4. Gestione dell'output

- **Validazione**: `validate_answer` (citazioni `[n]` entro il numero di fonti; marker di affermazioni assolute in it/en/es, `answer_validation.py:84-108`) → in caso di violazione risposta fissa di "non posso rispondere" (`chat_orchestrator.py:2352`); controllo specie sbagliata (`:1478`); rimozione del rinvio rituale al veterinario (`referral_style.py`); pensieri `<think>` dei reasoning model rimossi (`groq_llm_client.py:273,393`); `finish_reason=length` impedisce la messa in cache (`:2210`). Nessun controllo su farmaci/dosaggi nel testo generato (F6).
- **Rendering nell'app**: `_MarkdownLiteText` (`chat_message_bubble.dart:120-200`): solo grassetto `**…**` e puntati, in `RichText`; **nessun link cliccabile, nessun HTML, nessun url_launcher nella chat** (grep: i soli usi di `launchUrl` sono in eventi/radar/news/impostazioni). Buono.
- **Segnalazioni** (`report_chat_response.py:251-300`): solo risposte dell'assistente della propria conversazione, reporter come pseudonimo HMAC, risposta e dettagli anonimizzati e tagliati (4000/1000 car.); lettura riservata a `DEVELOPER_EMAILS` (`chat_response_reports.py:243-250`); cancellazione su richiesta; campi del reporter mai restituiti (`:240`). Nota: `REPORTER_PSEUDONYM_SALT` vuoto ricade sulla service-role key (`settings.py:270-280`): ruotare la chiave orfana gli pseudonimi.

---

## 5. Cache delle risposte

- **Chiave**: `sha256(lingua|specie normalizzata|domanda normalizzata)[:32]` (`answer_cache.py:72-74`), sulla domanda **grezza** (non anonimizzata); la condizione d'ingresso richiede però che anonimizzata e grezza coincidano (`chat_orchestrator.py:2052-2054`), quindi la chiave non contiene mai un valore che il filtro avrebbe cambiato.
- **Cosa entra**: solo `RequestKind.DIRECT`, primo messaggio (nessuno storico), nessun allegato, 8-200 caratteri, nessuna cifra, nessuna parola "personale" (it/en), non contiene il nome **di questo** pet (`answer_cache.py:49-69`). In modalità cache il prompt contiene **solo la specie** (`:2420-2422`), niente cartella, promemoria o storico (`:2097-2110`), quindi la risposta è generica per costruzione; il suggerimento sul peso è aggiunto dopo la lettura dalla cache (`:771`).
- **Può l'utente A ricevere dati di B?** Nel caso italiano/inglese praticamente no. Rischio residuo: la lista di parole personali è solo it/en (`:32-37`); in de/fr/es ("mein Hund Bello hat…", senza cifre) la domanda può entrare in cache con un nome di animale **diverso da quello del profilo**, il modello può ripeterlo nella risposta e un altro proprietario della stessa specie/lingua lo vedrà (F11, Bassa).
- **Presidio in produzione?** No. Default `PII_ANONYMIZER_BACKEND=rules` (`settings.py:259`); Presidio solo se installato (extra `privacy`) e selezionato; su Vercel non è installato ("troppo pesante per il runtime serverless", `container.py:655-659`). In produzione `noop` viene forzato a `rules` (`:660-666`). Quando Presidio non è importabile si ricade **sulle regole, mai su niente** (`:654-659`). Il runbook dice il contrario (default noop, errore in produzione): è obsoleto (F13).
- **Cache non disponibile**: eccezioni catturate, si risponde senza cache (`chat_orchestrator.py:2236-2249,2296-2297`).

---

## 6. Costi e abusi

- **Messaggi chat**: 20/giorno per utente (`CHAT_DAILY_MESSAGE_LIMIT_PER_USER`, `settings.py:128`), contati in `admit` (`llm_budget.py:199-225`) **solo sul percorso chat** (incluso `PUT …/messages/{id}` che passa da `respond_in`); esenti `DEVELOPER_EMAILS`; convenevoli ed emergenze non contati; **fail-open** se il ledger non risponde (`:215-217`). Messaggio ≤ 8000 caratteri (`schemas/chat.py:8`). Max 4 conversazioni attive per pet (`settings.py:260`).
- **Budget giornaliero per modello**: 200k token (`:112-121`), con riserva all'80% e modelli alternativi; esaurito tutto → risposta fissa gentile con il tempo di attesa, senza dettagli interni (`chat_orchestrator.py:1379-1410`). Buono.
- **Allegati**: 4 MB, 30 pagine PDF (`upload_chat_attachment.py:22-23`), **nessun limite per utente al numero di caricamenti**; una scansione da 30 pagine costa 30 chiamate di visione da 700 token (`:182-191`), ripetibile all'infinito (F5).
- **Dettatura**: **nessun limite** di durata/dimensione lato app (`chat_composer.dart`, solo contatore visivo) né lato API (il body viene letto per intero, `speech_to_text.py:112`); l'unico tetto è il limite Vercel di 4,5 MB per richiesta. Nessun limite per utente (F5).
- **Riassunto per il veterinario**: nessun limite per utente; ogni chiamata rimanda l'intera conversazione (1200 token di risposta) (F5).
- **Errori che espongono interni**: `ProviderError` → HTTP 502 con `str(exc)` (`main.py:77-79`), che per Groq contiene **il corpo della risposta d'errore del provider** (`groq_chat_api.py:200-203`, `groq_speech_to_text_provider.py:137-140`). Sul percorso chat è intercettato (`chat_orchestrator.py:1910,2168`), ma su `/speech-to-text` e `/conversations/{id}/summary` arriva al client (F7).

---

## 7. Trasparenza (AI Act art. 50)

- Ogni risposta ha `ai_generated` (`send_chat_message.py:97`); l'app mostra il badge "Generato da IA" sul singolo messaggio (`chat_message_bubble.dart:38,84`; `app_it.arb:894`). Le risposte fisse (triage, dosaggi, quota) hanno `ai_generated=false` e **nessun badge**: scelta documentata in `docs/compliance/01_ai_disclosure.md`.
- "Non è un veterinario": presente nel testo dei Termini di Servizio accettati alla registrazione (`account_consent_text.py:25-31`: "i suggerimenti dell'assistente non sostituiscono il parere di un veterinario") e nella sintesi privacy ("inviato a un fornitore esterno di intelligenza artificiale", `:36-49`); nel riassunto per il vet (`chatSummaryDisclaimer`, `app_it.arb:350`). **Nella schermata di chat non c'è alcuna frase** del tipo "assistente automatico, non sostituisce il veterinario": l'empty state dice solo "inizia il dialogo con l'assistente" (`app_it.arb:267`); il prompt vieta esplicitamente al modello di dire di non essere un veterinario (`natural_answer_prompt.py:87`). `01_ai_disclosure.md` cita una pagina di onboarding (`onboarding_privacy_disclaimer_page.dart`) che **non esiste più** (`features/onboarding/presentation/pages` assente). Vedi F12.
- Il consenso cartella clinica (`petsConsentFullText`, `app_it.arb:2`) spiega bene cosa viene letto e che va a un fornitore esterno di IA.

---

## Findings

### F1 — Gravità **Alta** · Nessun controllo di proprietà su pet e conversazione in `POST /chat`
**Dove**: `packages/core/application/services/send_chat_message.py:181-183` (`pet_profile_repository.get(data.pet_id)` senza confronto con `owner_id`), `:392-397` (`_load_or_create_conversation`: `repository.get(conversation_id)` senza confronto). Le repository Supabase `get` non filtrano per owner (`supabase_repositories.py:95,116`) e usano la service-role key (`client.py:12-19`), quindi le RLS non intervengono. Per confronto, modifica/rinomina/cancellazione/riassunto/segnalazione controllano tutte l'owner (`edit_chat_message.py:58`, `delete_conversation.py:22`, `vet_summary.py:75`, `report_chat_response.py:255`) e anche `already_answered` lo fa (`:336`).
**Problema**: confermato con lo script in-memory `scratchpad/audit/idor_check.py`: l'utente A, conoscendo `pet_id` o `conversation_id` di B, invia un messaggio e riceve indietro **tutta la conversazione di B** (`out.conversation.messages`), il nome e le note del pet di B entrano nel prompt e nella risposta; se B ha dato il consenso alla cartella, anche i referti di B vengono letti e spiegati ad A (il consenso è letto dal profilo del pet, `:223-227`). A può inoltre scrivere nella conversazione di B. Gli id sono UUID4 (`entity.py:5`), quindi non indovinabili: serve una fuga di id (log, link, bug del client), il che tiene la gravità sotto "Critica".
**Impatto**: lettura e scrittura della chat e della cartella clinica di un altro utente, senza traccia.
**Correzione**: in `execute`/`respond_in` rifiutare se `pet_profile.owner_id != data.owner_id` e se `stored.owner_id != data.owner_id` (stesso messaggio "not found" per entrambi i casi). Aggiungere un test unitario. In prospettiva: far accettare un `owner_id` a `get` nelle repository.

### F2 — Gravità **Alta** · Il messaggio grezzo va a Groq non anonimizzato attraverso il normalizzatore di query
**Dove**: `chat_orchestrator.py:1000` (`query = _case_context_text(situation, message)`, con `message` grezzo) → `:2320-2323` → `evidence_query_normalizer.py:43-53` (`user_prompt=f"Species…\nQuestion: {question[:1000]}"`, nessuna chiamata all'anonimizzatore). Attivo di default (`EVIDENCE_QUERY_NORMALIZER_ENABLED=true`, `settings.py:139`) su ogni messaggio non-convenevole e non "strict", cioè quasi tutti.
**Problema**: ogni messaggio (con numeri di telefono, email, nomi, indirizzi, microchip, frasi come "Proprietario: Mario Rossi") parte in chiaro verso il provider USA, in parallelo al prompt anonimizzato. Il confine dichiarato in `docs/compliance/02_pii_anonymization.md` ("la retrieval usa il testo originale — è un servizio locale") è stato scavalcato dalla build 32 senza aggiornare il filtro.
**Impatto**: l'anonimizzazione prima dell'invio, promessa nei documenti di compliance, oggi non vale per questa chiamata.
**Correzione**: in `_start_prefetch` e `_retrieve_optional_evidence` passare `self._anonymize_for_provider(query, data)` al normalizzatore (la query verso i retriever esterni può restare grezza: usa solo il dizionario). Aggiungere un test che verifichi che il client LLM non riceva mai testo con un'email nel `purpose="evidence_query"`.

### F3 — Gravità **Alta** · Immagini e audio partono in chiaro (nessuna minimizzazione possibile a valle)
**Dove**: `groq_image_analyzer.py:44,77`; `groq_speech_to_text_provider.py:115-135`; `upload_chat_attachment.py:118-122,169-193`.
**Problema**: una foto di referto porta nome, cognome, indirizzo, telefono del proprietario, nome del veterinario, a volte microchip; l'audio porta la voce. Il filtro agisce solo sul testo di ritorno. Documentato come rischio residuo (`02_pii_anonymization.md`, "Immagini e audio") e la sintesi privacy avverte che allegati e vocali vanno a un fornitore esterno — quindi la trasparenza c'è, la minimizzazione no.
**Impatto**: dati identificativi del proprietario e di terzi (il veterinario) trasferiti negli USA senza necessità clinica.
**Correzione**: (1) chiudere il punto "da verificare" su Groq (DPA, retention, no-training) prima dell'apertura; (2) valutare un OCR locale (Tesseract/pypdfium su Vercel è pesante, ma un servizio UE o il device stesso possono farlo) e mandare al modello solo il testo filtrato; (3) per la dettatura valutare l'STT on-device (Android/iOS lo offrono) e lasciare Groq Whisper solo come ripiego esplicito; (4) nell'informativa indicare Groq per nome.

### F4 — Gravità **Media** · Microchip esplicitamente protetto dall'anonimizzazione
**Dove**: `rule_based_pii_anonymizer.py:170-171` (`protect=True`), `02_pii_anonymization.md` ("Non tocca mai… numeri di microchip").
**Problema**: il microchip è un identificatore univoco registrato all'anagrafe con il nome e l'indirizzo del proprietario; raramente serve al modello per rispondere. Il profilo lo esclude dal prompt (`chat_orchestrator.py:607-608`), ma se compare in un referto trascritto o nel messaggio parte in chiaro.
**Impatto**: identificazione indiretta del proprietario dal lato del provider.
**Correzione**: sostituire con `[MICROCHIP]` (tenendo la regola "prima", così nessun altro pattern lo spezza) invece di proteggerlo; se serve al modello distinguere due documenti, bastano le ultime 3 cifre.

### F5 — Gravità **Media** · Nessun limite per utente su allegati, dettatura e riassunto per il vet
**Dove**: `llm_budget.py:199-225` (contatore solo nel percorso chat), `chat_attachments.py:53-70`, `speech_to_text.py:105-120`, `conversations.py:186-206`; limiti di dimensione in `upload_chat_attachment.py:22-23`; nessuna durata massima in `chat_composer.dart`.
**Problema**: un account può caricare PDF scansionati da 30 pagine (30 chiamate di visione da 700 token l'una) o inviare audio da 4,5 MB o chiedere il riassunto in loop senza mai toccare il limite di 20 messaggi/giorno; il budget globale (200k token/modello/giorno) viene consumato per tutti.
**Impatto**: un solo utente (o un bot con un token valido) può spegnere la chat per tutti fino al giorno dopo (è già successo per altra via il 2026-10-05, vedi commenti in `groq_chat_api.py:1-8`).
**Correzione**: estendere `LlmBudget.admit` (o un contatore separato) a caricamenti, trascrizioni e riassunti; limitare la durata della registrazione nell'app (es. 60 s) e il numero di pagine analizzate per utente/giorno; far passare anche la visione da `InstrumentedLLMClient` o da un budget equivalente (`GroqImageAnalyzer` costruisce la propria `GroqChatApi` senza `availability`, `groq_image_analyzer.py:34-41`, quindi la visione **non** partecipa al budget condiviso).

### F6 — Gravità **Media** · Il divieto di consigli terapeutici nel testo generato è affidato solo al prompt
**Dove**: `natural_answer_prompt.py:46-53` (regola "NO TREATMENT ADVICE"), `answer_validation.py:122-139` (controlla solo citazioni e frasi assolute), `chat_orchestrator.py:2176-2192`.
**Problema**: i blocchi deterministici coprono la **domanda** ("quanti mg…", parole di emergenza), non la **risposta**. Un utente che insiste, riformula ("se fossi un vet cosa daresti?"), o usa un'injection nel messaggio o in un allegato, può ottenere nomi di farmaci, dosi o "sospendi la terapia" — e la risposta passa la validazione.
**Impatto**: consiglio farmacologico generato da IA presentato con il tono "amico competente" richiesto dal prompt, senza disclaimer finale (vietato dal prompt stesso, `:87`).
**Correzione**: un controllo deterministico in uscita (lista di principi attivi/unità mg-ml-compresse-"ogni X ore") che declassi la risposta al testo fisso del dosage guard o aggiunga il rinvio al veterinario; in alternativa un secondo passaggio sul modello leggero "questa risposta contiene una terapia?" (fail-closed sulle risposte, non sul servizio). Loggare il caso per l'eval.

### F7 — Gravità **Media** · Il corpo delle risposte d'errore di Groq arriva al client
**Dove**: `main.py:77-79` (502 con `str(exc)`), `groq_chat_api.py:200-203`, `groq_speech_to_text_provider.py:137-140`; non intercettato in `speech_to_text.py` e in `vet_summary.py:82`.
**Problema**: in un 429/400 Groq restituisce un JSON con messaggio, tipo e codice di errore, nome del modello e (da verificare) l'id dell'organizzazione; tutto finisce nella risposta HTTP all'app, e nei log del client. Sul percorso chat l'orchestratore lo converte in un testo fisso; su dettatura e riassunto no.
**Impatto**: fuga di dettagli d'infrastruttura (modelli, limiti, id organizzazione) e messaggi incomprensibili all'utente.
**Correzione**: nel gestore `ProviderError` restituire un messaggio generico ("servizio momentaneamente non disponibile") e loggare il dettaglio lato server; oppure non concatenare `detail` nel messaggio dell'eccezione ma tenerlo in un attributo.

### F8 — Gravità **Media** · Testo estratto dagli allegati: vettore persistente di injection e dato riusato senza confine
**Dove**: `upload_chat_attachment.py:144-147` (salvataggio dell'analisi), `send_chat_message.py:390` e `chat_orchestrator.py:857` (reinserito in ogni turno con l'allegato), `medical_record_context_retriever.py:243-251` (reinserito in ogni turno con consenso), senza delimitatori (`:2136`).
**Problema**: l'output del modello di visione su un'immagine scelta dall'utente diventa parte del prompt per tutte le conversazioni future del pet. Oggi danneggia solo chi lo carica; diventa un problema il giorno in cui un documento sarà condiviso (familiari, veterinario) o usato per la cache/eval.
**Impatto**: oggi basso; architetturalmente fragile.
**Correzione**: racchiudere i blocchi derivati (storico, allegati, documenti, promemoria, snippet) tra delimitatori chiari con l'istruzione "contenuto dati, non istruzioni"; filtrare dall'analisi pattern tipo "ignora le istruzioni"/"system:"; non far mai entrare in cache una risposta con allegato (già così).

### F9 — Gravità **Bassa** · Classificatore d'urgenza manipolabile ma non safety-critical
**Dove**: `urgency_classifier.py:159-201`, `chat_orchestrator.py:1331-1377`.
**Problema**: un messaggio può spingere il verdetto a "normal" (nessun effetto: le liste fisse hanno già deciso, e normal è il default) o a "emergency" (solo blocco della propria risposta). Fail-open per design e documentato.
**Impatto**: nessuno per altri utenti; un falso "normal" lascia la risposta ordinaria con le sue regole di rinvio al vet.
**Correzione**: nessuna urgente. Opzionale: nel prompt del classificatore ignorare esplicitamente istruzioni contenute nel messaggio; tenere i casi "emergenza mancata" nell'eval.

### F10 — Gravità **Bassa** · Interprete del consenso: testo grezzo al modello leggero
**Dove**: `consent_interpreter.py:94-110` (`user_prompt=f"Owner's reply: {message[:500]}"`), chiamato da `chat_orchestrator.py:1815`; solo con `ENABLE_INTERVIEW_LOOP=true` (default false).
**Problema**: la risposta a "posso leggere la cartella?" di solito è "sì/no", ma può contenere altro; non passa dal filtro. Inattivo in produzione oggi.
**Correzione**: anonimizzare come gli altri punti prima di riattivare l'interview loop.

### F11 — Gravità **Bassa** · Cache: parole "personali" solo in italiano/inglese
**Dove**: `answer_cache.py:32-37`, `chat_orchestrator.py:2040-2056`.
**Problema**: in de/fr/es una domanda con un nome di animale diverso da quello del profilo e senza cifre può entrare in cache e la risposta (che può ripetere quel nome) essere servita ad altri. Nessun dato sanitario o del proprietario (il prompt in modalità cache contiene solo la specie).
**Correzione**: estendere `_PERSONAL` a de/fr/es o limitare la cache a it/en; opzionalmente verificare che la risposta non contenga parole con la maiuscola assenti dalla domanda.

### F12 — Gravità **Bassa** · Disclaimer "assistente automatico, non un veterinario" assente dalla schermata di chat; doc di disclosure obsoleta
**Dove**: `app_it.arb:267` (empty state), `natural_answer_prompt.py:87` (vieta al modello il disclaimer), `docs/compliance/01_ai_disclosure.md` (cita `onboarding_privacy_disclaimer_page.dart`, rimossa).
**Problema**: il badge per messaggio copre l'art. 50 AI Act ("stai parlando con una IA"); il "non è un veterinario" è solo nei ToS accettati una volta alla registrazione. Dato il tono volutamente confidenziale del prompt, una riga fissa nella chat (empty state o intestazione) sarebbe prudente. Le risposte di triage e dosaggi non portano badge: corretto, ma il testo fisso non dice che è automatico.
**Correzione**: una riga permanente nell'empty state/intestazione ("Assistente automatico: non sostituisce il veterinario; in emergenza chiama subito"), aggiornare `01_ai_disclosure.md` eliminando il riferimento all'onboarding.

### F13 — Gravità **Bassa** · Documentazione privacy non allineata al codice
**Dove**: `docs/runbooks/pii_anonymizer_setup.md:3,22` (default `noop`, "in produzione solleva un errore"): il codice ha default `rules` e ripiego sulle regole (`settings.py:259`, `container.py:646-666`). `02_pii_anonymization.md` e registro 08 punto 28: `known_medical_context` descritto come non anonimizzato, ma `chat_orchestrator.py:1123,1825` lo anonimizzano. `02_pii_anonymization.md` dichiara la retrieval "locale": non lo è più (F2). `09_informativa_privacy_bozza.md:53`: fornitore "da verificare".
**Correzione**: aggiornare i tre documenti; chiudere il punto 28; aprire un punto per F2 e per i termini Groq.

### F14 — Gravità **Bassa** · Conversazioni e file senza periodo di conservazione
**Dove**: `conversation/models.py:48-61`, `supabase_account_eraser.py:33-39`, `docs/features/chat_free_tier_budget.md:163-167` (retention solo per ledger/cache).
**Problema**: messaggi originali (non anonimizzati), snapshot di stato e file allegati restano a tempo indeterminato; è il prodotto, ma l'informativa dovrà dire per quanto, e i tester attuali sono persone reali.
**Correzione**: definire una retention (es. conversazioni inattive da N mesi, file orfani) e inserirla nell'informativa; già previsto un punto analogo per i percorsi delle passeggiate (`09_informativa_privacy_bozza.md:104`).

### F15 — Gravità **Bassa** · Nome file del client nel multipart verso Groq
**Dove**: `groq_speech_to_text_provider.py:159` (`filename="{filename}"` senza escape), `speech_to_text.py:117`.
**Problema**: un nome file con `"` o CR/LF altera l'header multipart; l'effetto peggiore è una richiesta malformata verso Groq (nessun impatto su altri utenti). Igiene.
**Correzione**: usare un nome fisso ("audio.m4a" in base al content-type).

---

## Cosa funziona bene (da mantenere)
- Guardrail di sicurezza (emergenze, dosaggi, multi-pet) deterministici e **prima** del modello; risposte fisse non manipolabili.
- Anonimizzazione **prima dell'invio** sul prompt principale, sullo storico, su note/promemoria/cartella/PDF/riassunto, con il nome del proprietario come valore noto; `noop` rifiutato in produzione.
- Nessun identificatore d'account nel prompt; nessun `user`/metadata nella richiesta; EXIF/GPS rimossi dalle foto.
- Output del modello sempre trattato come dati: JSON validato contro liste chiuse, nessun eval, nessun URL seguito, rendering senza link/HTML.
- Log senza contenuti; ledger e budget con messaggi d'errore utente puliti; cache limitata a domande generiche con solo la specie nel prompt.
- Segnalazioni pseudonimizzate, anonimizzate, con retention e lettura riservata.

## Priorità consigliata
1. F1 (controllo owner in `SendChatMessageService`) — poche righe, un test.
2. F2 (anonimizzare la query del normalizzatore) — una riga, un test.
3. F7 (messaggio generico sui `ProviderError`) — poche righe.
4. F5 (limiti su allegati/dettatura/riassunto + visione nel budget).
5. F3/F4 (termini Groq, microchip, OCR/STT locali) — decisioni di prodotto e compliance prima del lancio.
6. F6, F8, F12, F13, F14, F11, F10, F9, F15.
