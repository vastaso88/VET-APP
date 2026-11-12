# Riposizionamento: dalla salute dell'animale alla consapevolezza del proprietario

Data: 2026-11-01. Decisione del proprietario, piano dell'Orchestratore progetto. Sostituisce il posizionamento di `02_visione_prodotto_e_principi.md` §Posizionamento ("Assistente pet evidence-based") e riapre il modulo comportamentale congelato in `03_scope_mvp_v1.md` e `06_backlog_prioritizzato.md`.

## 0. La decisione, con le parole del proprietario

> L'app non lavora più sulla "salute dell'animale", ma sulla consapevolezza del proprietario. Tutto deve avere questo centro, soprattutto la comunicazione al pubblico e il modo di funzionare della chat: rimane sempre il fatto che le risposte debbano essere basate su evidenze scientifiche e su pareri ufficiali, ma l'obiettivo deve tendere a rendere i proprietari degli animali adeguati ad ipotetici patentini. Deve educare alla corretta gestione etologica, di relazione, di salute (anche questa, ma non solo) e tutto ciò che ha a che fare nella relazione uomo-animale in tutte le specie trattate dall'app.

> Non è un corso di formazione o simili, ma uno strumento di divulgazione. Non rilascia attestati e non si sostituisce a corsi.

### Definizione operativa

**Quokka è uno strumento di divulgazione che aiuta chi vive con un animale a capirlo e a gestirlo bene.** Il "patentino" (i percorsi per proprietari di cani: Italia DM 26/11/2009 e ordinanze, Spagna Ley 7/2023 art. 30, Germania Sachkundenachweis, Austria) è il **metro** del livello di consapevolezza a cui tendere, **non il prodotto**: Quokka non è un corso, non fa esami, non rilascia attestati, non sostituisce i percorsi ufficiali né il veterinario, l'educatore o il comportamentalista.

### Le cinque aree (lo scheletro dei contenuti)

Ricalcano i programmi dei percorsi per proprietari e valgono per tutte le specie dell'app (cane, gatto, piccoli mammiferi, uccelli, rettili e anfibi, pesci, altro):

| # | Area | Cosa copre | Esempio di domanda |
|---|---|---|---|
| 1 | **Etologia e comunicazione** | come la specie percepisce, comunica, impara; segnali di stress e di benessere; bisogni di specie | "Perché il mio cane sbadiglia quando lo abbraccio?" |
| 2 | **Relazione e convivenza** | rapporto uomo-animale, bambini, altri animali, spazi pubblici, educazione gentile, cosa non fare | "Come presento il gatto al nuovo cucciolo?" |
| 3 | **Gestione quotidiana e benessere** | alimentazione, ambiente, arricchimento, movimento, igiene, le cinque libertà / i cinque bisogni | "Quanto deve stare in gabbia un coniglio?" |
| 4 | **Salute e prevenzione** | segni da osservare, prevenzione, quando serve il veterinario, come leggere un referto | "Ogni quanto si fa il vermifugo?" (principi, non dosi) |
| 5 | **Doveri e responsabilità** | obblighi di legge per paese (microchip, anagrafe, guinzaglio, RC, trasporto, viaggi), rispetto degli altri, benessere come dovere | "Cosa devo fare per legge quando prendo un cane?" |

La salute resta: è l'area 4 e il motivo per cui esistono cartella clinica, promemoria e monitoraggio. Ma la frase che descrive l'app non parte più da lì.

## 1. Cosa dice il progetto oggi (screening del 2026-11-01)

Quattro ricognizioni indipendenti (chat backend, app, documenti, legale). Sintesi:

| Dove | Stato | Peso |
|---|---|---|
| **Schede store** (`docs/store/listings/*.md`, 7 lingue) | titolo "VetApp: la salute del tuo pet" e varianti; sottotitoli "Salute e cura"; bullet su vaccini e cure | pubblico, il più urgente |
| **Descrittore** "Quokka: salute del tuo animale" | fissato in `docs/marchio/00`, `01` e nei documenti social | pubblico |
| **App, testi** | login/registrazione "gestire salute e documenti"; tutorial "domande sulla salute"; splash "Chiedi al veterinario virtuale" (viola il glossario: l'assistente non si chiama mai così) e "libretto sanitario"; rail "Spazio clinico caldo"; piani "dubbi su salute, comportamento e routine"; `appTitle` e due testi fissi ancora "VET APP" | pubblico |
| **App, struttura** | 4 schede (Home, Animali, Attività, Impostazioni); chat raggiungibile solo dal singolo animale; nessuna superficie di divulgazione (l'unica è la guida alla corporatura, WSAVA, cane/gatto/coniglio) | struttura |
| **Chat, prompt** (`natural_answer_prompt.py`) | "assistant inside a pet-care app"; regole quasi tutte sanitarie; nessuna menzione di etologia, relazione, doveri, posizioni ufficiali; risposte dirette max ~1000 caratteri; su curiosità la parola "veterinario" è vietata | cuore del prodotto |
| **Chat, instradamento** | frase senza "?" = sintomo (anamnesi medica anche per "Toby è aggressivo con gli ospiti"); `behavior_question` ha 5 radici; intento di default `clinical_question`; nessun intento per relazione o doveri | comportamento |
| **Chat, sicurezza** | SafetyGate tratta "perché il cioccolato è tossico?" come esposizione → triage fisso; guardia dosaggi blocca "ogni quanto il vermifugo?" | blocca la divulgazione |
| **Chat, fonti** | registro fonti solo biomediche (WSAVA, AAHA, Merck, PubMed…); niente etologia (ESVCE, AVSAB, ISFM), niente istituzioni (Ministero, FNOVI, UE); il percorso "naturale" può rispondere di suo | evidenze |
| **Valutazione qualità** (`scripts/eval/chat_quality`) | premia risposta diretta, calma, linguaggio semplice, pochi rimandi; non misura il "perché", le fonti, i doveri, la relazione | misura |
| **Documenti prodotto/marketing** | posizionamento "assistente pet evidence-based"; modulo comportamentale **congelato** (`03`, `06`); pitch "dubbi su salute, comportamento e routine" | interno |
| **Legale** (termini, informative, avvisi IA, 11 paesi) | dicono già "ti aiuta a prenderti cura dei tuoi animali" + elenco funzioni; "non è un veterinario" coerente ovunque; nessuna finalità "educazione"; nessun dato di apprendimento inventariato | leggero, salvo dati nuovi |
| **Marchio** (`docs/marchio`) | classe 41 valutata solo come intrattenimento (🟡/🔴); mai come divulgazione per proprietari | da riaprire |
| **Sito** (`apps/site`) | home "l'app per prenderti cura dei tuoi animali" | pubblico, leggero |
| Parole **patentino, etologia, relazione uomo-animale, consapevolezza** | zero occorrenze in tutto il repository | — |

## 2. La frase

Serve una frase che stia in un titolo di store (30 caratteri), funzioni in 5 lingue e non prometta ciò che non siamo (corso, veterinario). Tre proposte; la **prima** è quella usata provvisoriamente da oggi nei testi dell'app finché il proprietario non sceglie:

| | IT | EN | ES | DE | FR |
|---|---|---|---|---|---|
| **A (provvisoria)** | Quokka: capire il tuo animale | Quokka: understand your pet | Quokka: entiende a tu animal | Quokka: dein Tier verstehen | Quokka : comprendre ton animal |
| B | Quokka: conoscere il tuo animale | Quokka: know your pet | Quokka: conoce a tu animal | Quokka: dein Tier kennen | Quokka : connaître ton animal |
| C | Quokka, per proprietari consapevoli | Quokka, for mindful owners | Quokka, para dueños conscientes | Quokka, für bewusste Halter | Quokka, pour des maîtres avertis |

Frase lunga (sottotitolo, sito, prima schermata): *"Capisci perché fa quello che fa, come gestirlo ogni giorno, quali sono i tuoi doveri e quando serve il veterinario. Risposte basate su fonti scientifiche e posizioni ufficiali, per ogni specie."*

## 3. Regole che valgono per tutti (sessioni, testi, codice)

1. **Parole vietate nei testi pubblici**: corso, formazione, lezione, attestato, certificato, patentino, esame, promozione, "veterinario virtuale", "come un veterinario". "Patentino" resta solo nei documenti interni come metro.
2. **"Non è un veterinario"** resta ovunque identico; l'AI Act art. 50 (`chatAiNotice`) non cambia.
3. **Niente gamification che somigli a una certificazione**: nessun badge, punteggio, livello, "hai superato". Se un giorno ci saranno auto-verifiche, saranno senza esito salvato (altrimenti nuova finalità privacy, inventario, Data safety, consenso v4).
4. **Evidenze e posizioni ufficiali**: ogni affermazione di etologia o gestione poggia su linee guida di società scientifiche o enti (WSAVA, FVE/FECAVA, ESVCE, AVSAB, ISFM, RSPCA, AAHA, Ministero della Salute, FNOVI, UE); quando una posizione è dibattuta lo si dice.
5. **Personalizzazione limitata** (Francia: il "téléconseil" personalizzato è esercizio veterinario; Australia: l'assistente non è "amico" o "compagno"): si spiega il "perché" della specie, si danno indicazioni generali di gestione, non piani individuali.
6. **Sicurezza invariata nei fatti**: le esposizioni ("ha mangiato cioccolato") restano triage; cambia solo che le **domande** ("perché il cioccolato è pericoloso?") ricevono una spiegazione.
7. **Tutte le specie**: ogni testo e ogni esempio evita il "cane per default".
8. **Identificativi tecnici e consensi non si toccano**: nessun bump di versione dei consensi per il solo cambio di posizionamento (il significato dei testi legali non cambia); bump solo se arrivano dati nuovi.

## 4. Piano di lavoro

### Fase 1 — Testi e cuore della chat (subito, entra nella build 37)

| # | Cosa | Chi | File principali | Guardie |
|---|---|---|---|---|
| 1.1 | **Testi app**: titolo/sottotitolo auth, tutorial (3 slide), splash (via "veterinario virtuale" e "libretto sanitario"), rail, piani (`billingIncludedAssistant`), stati vuoti animali/promemoria/chat, `chatNewConversationPrompt`, `appTitle` → "Quokka", `'VET APP'` fissi in `splash_page.dart` e `home_shell_page.dart`, `web/manifest.json`, `web/index.html`, `pubspec.yaml` | UI/UX | 5 ARB, `lib/app/splash`, `lib/app/shell`, `web/` | `flutter gen-l10n`, `check_i18n.py` (+allowlist), `glossary.py check`, `auto_translate.py acknowledge`, snapshot italiano `--update`, `widget_test.dart`, `chat_ai_notice_test.dart` |
| 1.2 | **Prompt chat**: identità ("assistente che aiuta chi vive con un animale a capirlo e gestirlo bene"); regola SPIEGA IL PERCHÉ (etologia, specie-specifico); regola POSIZIONI UFFICIALI (preferisci linee guida, dichiara il dibattito); regola DOVERI (menziona l'obbligo di legge del paese quando pertinente, in modo neutro); `_DIRECT` fino a ~1500 caratteri e divieto "veterinario" ridotto al solo rimando rituale (microchip, vaccino obbligatorio possono citarlo); identità small-talk nelle 5 lingue | Chat LLM | `natural_answer_prompt.py`, `chat_orchestrator.py` (`_SMALL_TALK_TEXTS`) | prompt identico tra utenti; soffitto `SYSTEM_PROMPT_MAX_CHARS` (alzare con motivazione se serve); `test_vet_referral_calibration`, `test_prompt_budget`, `test_response_language`, `test_chat_small_talk_and_maintenance`, `test_translation_system` |
| 1.3 | **Cache risposte**: versione del prompt nella chiave, così le risposte "vecchie" non sopravvivono 24 ore | Chat LLM | `answer_cache.py`, orchestratore | `test_answer_cache` |
| 1.4 | **Schede store** 7 lingue: titolo (frase A), sottotitolo, descrizione breve, bullet (assistente per primo: capire, gestire, doveri, quando il veterinario), parole chiave (etologia, comportamento, convivenza) | Orchestratore | `docs/store/listings/*.md`, `02_screenshot_checklist.md` | `test_store_listings`; nome "Quokka" ok nei file (lo store pubblico aspetta il marchio) |
| 1.5 | **Documenti di prodotto e marketing**: posizionamento in `02`, decision log in `09` (sblocco modulo comportamentale), pitch in `docs/marketing/02`, README/CLAUDE.md prima riga | Orchestratore | `docs/product/02,03,06,09`, `docs/marketing/02`, `README.md`, `CLAUDE.md` | — |
| 1.6 | **Sito**: home e meta description con la frase lunga | Orchestratore | `apps/site/tools/pages_it.py` → `build.py` | nessun termine vietato |
| 1.7 | **Legale**: termini §2 "cosa è Quokka" nei 10 paesi + it; avvisi IA §1 "a cosa serve l'assistente" (famiglia "prenderti cura" → "capire e gestire bene il tuo animale"); descrizione store in `us/05` e `uk..es/05 §9`; nessun bump di consenso; aggiungere al quadro AI Act (`docs/security/01` r.254) che "istruzione" dell'Allegato III riguarda istituti e valutazione di studenti, non la divulgazione | MARKETING e NORMATIVA (testi), Cybersicurezza (riga AI Act) | `docs/compliance/*/03_*`, `*/05_*`, `docs/security/01` | pytest; nessuna parola vietata |
| 1.8 | **Comunicazione al pubblico**: le parole del proprietario e questo documento vanno al Gestore Social Media (pilastri, promessa, formati, descrittore sono suoi) | Orchestratore (solo relay) | `docs/social/` (non tocchiamo) | — |

Esito di fase 1: build 37 = nome Quokka + colori + testi del nuovo centro + prompt nuovo. Distribuzione ai tester.

### Fase 2 — La chat ragiona da divulgatore (settimana successiva)

| # | Cosa | Chi | Note |
|---|---|---|---|
| 2.1 | **Instradamento**: radici comportamentali e relazionali (abbaia, tira, salta, ringhia, paura, marca, graffia, miagola, distrugge, separazione, socializz…) e di doveri (microchip, anagrafe, guinzaglio, museruola, viaggio, RC, legge, obbligatorio) → tipo DIRECT con al massimo **una** domanda di contesto (da quando, in che situazione, cosa è cambiato): l'anamnesi vale anche per il comportamento; intento di default non più `clinical_question` per frasi non cliniche | Chat LLM | `request_kind.py`, `chat_orchestrator.py` (`_classify_intent`), `quality.py` (`INTENT_TO_DOMAIN`), `test_request_kind` |
| 2.2 | **SafetyGate**: distinguere **domanda** da **esposizione** per tossici e farmaci (marcatori di esposizione: "ha mangiato", "ho dato", "ieri", quantità; marcatori di domanda: "perché", "è vero che", "quali", "?" senza esposizione). La domanda riceve la spiegazione **con** l'elenco di sicurezza; l'esposizione resta triage. Tutte le fixture attuali (`safety_phrasings*`) restano verdi; nuove fixture per le domande | Chat LLM | `safety_gate.py`, `triage_clarification.py`, `test_safety_gate*`, `test_emergency_phrasings*` |
| 2.3 | **Guardia dosaggi**: "ogni quanto il vermifugo/antiparassitario?" → principi di prevenzione + "prodotto e frequenza li decide il veterinario"; rifiuto solo su mg/kg, compresse, ml | Chat LLM | `dosage_request.py`, `dose_in_answer.py`, `_dosage_guard_result` |
| 2.4 | **Fonti**: registro con enti di etologia/benessere/istituzioni (ESVCE, AVSAB, ISFM/iCatCare, FVE/FECAVA, WSAVA welfare, RSPCA cinque bisogni, Ministero della Salute, FNOVI, EU); note curate "capire la specie" per famiglia (livello D finché il proprietario, veterinario, non le rivede: diventano livello B) | Chat LLM + proprietario (revisione) | `registry_seed.py`, `curated_husbandry_evidence_retriever.py`, `species_facts.py` |
| 2.5 | **Valutazione qualità**: nuovi criteri (spiega il perché; cita o rispecchia posizioni ufficiali; nomina il dovere quando pertinente; relazione; nessuna parola vietata); scenari per 5 aree × 7 specie; solo chiave EVAL | Chat LLM | `scripts/eval/chat_quality/run.py`, `scenarios*.py`, `docs/features/chat_quality_measurements.md` |
| 2.6 | **Rimando rituale**: `strip_ritual_referral` non deve togliere il veterinario quando è un dovere (vaccino obbligatorio, microchip) | Chat LLM | `referral_style.py` |

### Fase 3 — Una superficie di divulgazione nell'app (decisione del proprietario)

| # | Cosa | Note |
|---|---|---|
| 3.1 | Sezione **"Capire il tuo animale"** in Attività (o scheda in Home): schede brevi per specie × 5 aree, con fonte e data, lette dal backend (markdown curato in `data/awareness/<specie>/`), senza salvare progressi | contenuti scritti dalle sessioni, **rivisti dal proprietario**; nessun dato nuovo = nessuna modifica privacy |
| 3.2 | **Chat senza animale** ("Chiedi") dalla Home per domande di specie, per chi non ha ancora un profilo | oggi la chat è solo per animale |
| 3.3 | "Lo sapevi?" rotante in Home, pescato da 3.1 | |
| 3.4 | Scheda animale: campo facoltativo "convivenza" (altri animali, bambini, ore da solo) **solo se** la chat lo usa davvero (minimizzazione) | finalità già coperta ("profilo dei tuoi animali") |
| 3.5 | **Marchio**: addendum al parere su classe 41 letta come "divulgazione/informazione per proprietari" (pubblicazioni elettroniche, informazioni educative), da portare al consulente reale dopo il lancio | `docs/marchio/03_addendum_classe_41.md` |

## 5. Decisioni per il proprietario

1. **La frase**: A, B, C o una tua. Fino alla risposta usiamo A.
2. **Fase 3.1 e 3.2**: vuoi la sezione di schede e la chat senza animale? Sono le due cose che cambiano davvero la struttura dell'app.
3. **Revisione dei contenuti**: le note "capire la specie" (2.4) e le schede (3.1) hanno bisogno di un veterinario che le legga prima che diventino "verificate". Sei tu, o indichi fonti da cui copiare la posizione ufficiale.
4. **Doveri di legge per paese**: li scriviamo per i 7 paesi dell'app partendo dalle ricerche normative già in `docs/compliance/<paese>/01`; conferma che vuoi questo contenuto in chat.

## 6. Cosa non cambia

Nome Quokka, identificativi tecnici, consensi e loro versioni, "non è un veterinario", AI Act art. 50, anonimizzazione verso Groq, gate di sicurezza sulle esposizioni, cartella clinica, promemoria, monitoraggio, passeggiate, mappe, mercatino "solo oggetti", regole della mascotte, divieto di nominare funzioni "Quokka X".
