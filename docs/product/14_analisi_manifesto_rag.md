# 14 — Analisi del "Manifesto architetturale" (router + RAG) contro il codice

Data: 2026-11-10. Autore: sessione Chat LLM interna, su richiesta dell'Orchestratore. Solo analisi: nessun codice è stato cambiato. Il manifesto è arrivato troncato dopo il prompt del router; qui si analizza la parte ricevuta.

## Il manifesto in breve

1. **Router in due fasi.** Claude Haiku 5.5 classifica ogni messaggio in JSON: `categoria` (SALUTE_PERICOLO, GESTIONE_EDUCAZIONE o NON_PERTINENTE), `ragionamento` di al massimo 15 parole, `specie_identificata`. Poi SALUTE_PERICOLO va a Claude Sonnet 5.5, GESTIONE_EDUCAZIONE va a Haiku, NON_PERTINENTE riceve un messaggio fisso e la conversazione si ferma lì.
2. **RAG "a libro chiuso"**, senza ricerca sul web:
   - un corpus di fonti approvate, diviso in pezzi da 200-300 parole con metadati (specie, categoria, fonte);
   - embedding con OpenAI o Voyage, salvati in Qdrant o Pinecone;
   - a ogni domanda: filtro sui metadati del router, 10 pezzi per somiglianza, rerank con Cohere fino a 3, pezzi inseriti nel prompt in `<fonti_approvate>`.
3. **Obiettivo dichiarato:** "azzerare il rischio di allucinazioni mediche".

In sintesi: l'idea di fondo è giusta e metà dell'impianto esiste già. Il pezzo che manca davvero è il corpus. I fornitori proposti (OpenAI o Voyage, Qdrant o Pinecone, Cohere) non servono per un corpus della taglia che Quokka può avere, e ognuno costerebbe un contratto, una riga nell'inventario e un nuovo consenso. "Zero allucinazioni" non è raggiungibile; si può ridurre il rischio e misurarlo.

## (a) Punto per punto: cosa c'è, cosa manca

| Punto del manifesto | Cosa esiste già | Cosa manca | File |
|---|---|---|---|
| Router con un modello | Il **classificatore d'urgenza** su Haiku (chiamata leggera, JSON con `level` emergenza / forse / normale e `category`, schema strutturato, 6 s di tempo massimo). Si attiva dopo le **liste fisse**, che non sbagliano mai in silenzio: SafetyGate, parole d'emergenza, tossici, dosi, eutanasia, minori. Sopra c'è la classificazione del tipo di richiesta, senza modello: referto, domanda diretta o sintomo. | Le tre categorie del manifesto e il campo `specie_identificata`. La specie oggi si ricava dalla scheda e dal messaggio senza modello: specie nominata, avviso "altro animale". | `urgency_classifier.py`, `safety_gate.py`, `triage_clarification.py`, `request_kind.py`, `chat_orchestrator.py` (`_effective_species`) |
| SALUTE_PERICOLO → Sonnet | Le urgenze ricevono un'**apertura fissa** e poi il modello risponde sul caso. I **passi fissi di primo soccorso** gli arrivano come note vincolanti. Il tempo massimo è 12 s, e se qualcosa non va tornano i testi fissi. Rifiuti di dose, eutanasia, minore ferito e identità restano fissi e fuori dal modello. | Una terza classe di modello ("forte") accanto a `main` e `light`. È una modifica piccola: `model_class` nella porta, `ANTHROPIC_MODEL_STRONG`, il budget. | `chat_orchestrator.py` (`_urgent_answer`), `natural_answer_prompt.py` (`build_emergency_prompt`), `anthropic_llm_client.py`, `llm_client.py` |
| GESTIONE_EDUCAZIONE → Haiku | Già così: ogni risposta ordinaria va a Haiku. | — | `anthropic_llm_client.py` |
| NON_PERTINENTE → messaggio fisso e stop | Ci sono risposte fisse per salute umana, domande d'identità, richieste di rivelare il prompt e saluti. Per gli altri argomenti fuori tema (auto, ricette, prezzi) c'è la regola OFF TOPIC nel prompt: una frase gentile, senza contenuto. | Un messaggio fisso per ogni fuori tema: serve il router o una lista. Rischio da misurare: un falso "fuori tema" su una domanda vera è peggio di una risposta breve. | `harmful_requests.py` (IDENTITY_TEXTS, HUMAN_HEALTH_TEXTS, PROMPT_LEAK_TEXTS), `natural_answer_prompt.py` (`_VOICE`, OFF TOPIC) |
| Corpus di fonti approvate | Note curate scritte da noi, in memoria. Vedi (b): circa 4.800 parole in tutto. | Il corpus vero, scritto da noi con le fonti e rivisto da un veterinario. | `in_memory_evidence_retriever.py`, `curated_awareness_evidence_retriever.py`, `curated_husbandry_evidence_retriever.py`, `duty_notes.py`, `species_facts.py` |
| Pezzi da 200-300 parole con metadati | Ogni nota è un `EvidenceSource` con `species`, `clinical_domain`, `tier` e `title`. Le note sono lunghe in media 50-100 parole. | Pezzi più lunghi e un campo "fonte" uniforme (citazione leggibile). | `packages/core/domain/knowledge/models.py` |
| Embedding + database vettoriale | Uno **scheletro pgvector in Supabase** esiste già: tabella `ai.source_document_chunks` con `embedding vector(1536)` e indice, funzione `ai.match_source_chunks`, adattatore `SupabaseEvidenceRetriever`. Però manda un **vettore di zeri**: la pipeline di embedding non è mai stata costruita. In produzione `EVIDENCE_BACKEND` non è impostato, quindi la ricerca è in memoria e non fa chiamate di rete (verificato nel registro rischi, R27). | Un modo di calcolare gli embedding: vedi (c). | `scripts/setup/supabase_llm_sources_schema.sql`, `supabase_evidence_retriever.py`, `bootstrap/container.py` (`_build_evidence_retriever`) |
| Filtro per metadati | La ricerca filtra già per specie e per tipo di domanda (`IntentRoutedEvidenceRetriever`). La soglia di pertinenza scarta le note fuori tema. Le note sui doveri si aggiungono per regola quando il proprietario li nomina. | — | `intent_routed_evidence_retriever.py`, `relevance.py`, `duty_notes.py` (`pinned_duty_notes`) |
| 10 pezzi, rerank a 3 | Nel prompt entrano al massimo 2 fonti da 300 caratteri l'una (`LLM_PROMPT_MAX_SOURCES`, `LLM_PROMPT_SOURCE_CHARS`). | Con pezzi da 250 parole i limiti salgono a 3 × circa 1.600 caratteri, circa +900 token per risposta. Il rerank non serve: vedi (c). | `settings.py` |
| `<fonti_approvate>` nel prompt | Le fonti entrano come "materiale di riferimento opzionale". Gli allegati e i promemoria stanno tra i segni «BEGIN DATA» ed «END DATA» e il prompt li tratta come dati, non come istruzioni. | Rendere le fonti **vincolanti** sulle domande di salute, con citazione: vedi (e). | `natural_answer_prompt.py` (`_REFERENCE_MATERIAL`), `chat_orchestrator.py` (`_data_block`) |
| "Libro chiuso", senza web | Già così in produzione. I collegamenti a Europe PMC, PubMed, Crossref e OpenAlex esistono ma sono spenti. | — | `container.py` |
| Rispondere solo dalle fonti | **Esiste ed è spenta di proposito.** È la via "evidenze rigorose" (`_generate_evidence_answer`, `strict_evidence_intents`): niente fonte, niente risposta. Il 2026-09-21, a confronto diretto, ha dato risposte peggiori sulle domande comuni: non sa ordinare le cause per probabilità e non ragiona sui numeri del proprietario. Da allora è vuota per tutte le intenzioni. | Riaccenderla **solo** su un perimetro stretto (salute, con un corpus vero) e misurarla. | `chat_orchestrator.py` (righe 869-925, `_generate_evidence_answer`) |
| Cache delle risposte | Le curiosità generali si condividono per 24 ore tra proprietari della stessa specie. La cache del prompt di sistema è già attiva sul client Anthropic. | — | `answer_cache.py`, `anthropic_llm_client.py` |

## (b) Il corpus

**Oggi**, misurato nel codice:

| Raccolta | Voci | Parole |
|---|---|---|
| Catalogo generale (`CATALOG`) | 25 | circa 2.100 |
| Note di consapevolezza (etologia, bisogni, errori comuni) | 12 | circa 1.140 |
| Cura e gestione (`HUSBANDRY_CATALOG`) | 8 | circa 890 |
| Doveri del proprietario in Italia | 5 | circa 240 |
| Fatti di specie e paragrafi di etologia | 5 | circa 450 |
| **Totale** | **circa 55** | **circa 4.800**, cioè una ventina di pezzi da 250 parole |

Sono testi scritti da noi, segnati "in attesa di revisione veterinaria" e con l'ente citato nel testo (WSAVA, AVSAB, ISFM, RSPCA, Ministero della Salute). Coprono soprattutto comportamento e gestione di cane, gatto e coniglio, e quasi niente di clinico. Le risposte di salute oggi poggiano sulla conoscenza del modello, non su fonti (prove di stress del 2026-11-06).

**Cosa servirebbe.** Un corpus di salute e gestione per le specie dell'app. A spanne:
- 9 specie con 30-60 schede l'una, cioè 300-500 pezzi;
- ogni scheda scritta con parole nostre, con la fonte citata (ente, documento, anno, pagina o sezione) e rivista da un veterinario;
- prima di tutto i segni d'allarme e il primo soccorso, che sono il cuore di SALUTE_PERICOLO.

Il **manuale "Capire il tuo animale"** (`docs/product/13`, fermo dall'8 novembre) è il corpus naturale. Ha già la politica delle fonti, le 9 specie e una scheda d'esempio: le sue schede sarebbero i pezzi del RAG, con i metadati già previsti.

**Diritti d'autore.** I manuali veterinari (Merck, BSAVA, testi universitari) e la maggior parte delle linee guida sono protetti: non si possono copiare né spezzettare nel database, nemmeno a uso interno di un servizio commerciale. Si possono leggere e riscrivere con parole nostre, citando la fonte.
- I testi di legge e gli atti ufficiali italiani si possono riportare (legge 633/1941, art. 5).
- Le linee guida "libere da leggere" (WSAVA, AAHA, ISFM) non sono per questo libere da copiare: si riassumono.
- Corpus copiato = rischio legale. Corpus riscritto = lavoro editoriale e veterinario, che è il vero costo del progetto.

## (c) Alternative senza fornitori nuovi

| Pezzo del manifesto | Alternativa senza fornitori nuovi | Note |
|---|---|---|
| Qdrant o Pinecone | **Supabase, già in Irlanda e già sotto contratto.** Tre livelli: (1) **ricerca testuale di Postgres** con configurazione italiana e filtro per specie e categoria; (2) **pgvector**, già installato con lo scheletro descritto in (a); (3) per un corpus piccolo, **nessuna ricerca**: tutto il corpus di una specie, 300-500 pezzi ma poche migliaia di parole per area, sta nel prompt di sistema e la cache del prompt lo rende economico. | Zero fornitori nuovi, zero nuovi trasferimenti di dati. |
| Embedding con OpenAI o Voyage | Anthropic **non offre embedding**. Ogni servizio di embedding è un fornitore nuovo che riceve **il testo della domanda**, cioè dati di salute. Servono: contratto sul trattamento dei dati, riga in `docs/security/06`, informativa, **consenso da rifare** (oggi la v5 nomina solo Anthropic e Groq) e una valutazione del trasferimento se fuori dall'UE. Alternative: un modello di embedding locale (`sentence-transformers` multilingue) per il corpus, calcolato una volta sola fuori linea, va bene; per la domanda a ogni messaggio serve un modello in esecuzione, poco adatto alle funzioni Vercel (dimensione e avvio a freddo). Le funzioni di Supabase hanno un modello di embedding integrato, ma è pensato per l'inglese: va verificato sull'italiano prima di contarci. | Raccomandazione: **non** introdurre embedding finché la ricerca testuale non mostra, misurata, di perdere pezzi pertinenti. |
| Rerank con Cohere | Con un corpus di qualche centinaio di pezzi, già filtrato per specie e categoria, i candidati sono pochi. Il rerank aggiunge un fornitore, latenza e costo per spostare l'ordine di 10 voci. Si può usare, se serve, la soglia di pertinenza già esistente (`relevance.py`) oppure chiedere a Haiku di scegliere 3 pezzi tra 10 nella stessa chiamata del router. | Non serve. |

## (d) Costi

Misure che abbiamo, per 1000 risposte complete (classificatore, parole chiave e risposta):

- **Haiku 5.5**: circa **1,48 $**, cioè 0,00148 $ a risposta.
- **Sonnet 5.5**: circa **21 $**, cioè 0,021 $ a risposta.

Sono le misure indicate dall'Orchestratore, dai giri di valutazione del 6-7 novembre; non le ho ricalcolate.

Il rapporto è circa 14 volte e non 20, perché Sonnet scrive risposte più corte. Il cambio è quello del business plan: 1,50 $ = 1,34 €, cioè 0,893 € per dollaro.

Costo medio per domanda con il router (Sonnet su SALUTE_PERICOLO, Haiku sul resto):

| Domande SALUTE_PERICOLO | $ a domanda | € a domanda | Con il +50% di riserva del business plan | Rispetto a 0,002 € del business plan |
|---|---|---|---|---|
| 0% (oggi, solo Haiku) | 0,00148 | 0,00132 | 0,0020 | 1× |
| 20% | 0,00538 | 0,0048 | 0,0072 | **3,6×** |
| 30% | 0,00734 | 0,0066 | 0,0098 | **4,9×** |
| 50% | 0,01124 | 0,0100 | 0,0151 | **7,5×** |

Calcolo: (1 − quota) × 0,00148 + quota × 0,021.

Altri effetti sul costo:
- **Router.** Prende il posto del classificatore d'urgenza, che è già in queste misure: costo quasi invariato.
- **Fonti nel prompt.** Tre pezzi da 250 parole sono circa +1.000 token d'ingresso: circa +0,0001 $ con Haiku e +0,002 $ con Sonnet a risposta. La cache li sconta solo se i pezzi si ripetono.
- **Regione USA** (`inference_geo="us"`, consenso v5): +10% su tutti i token Anthropic.
- **Reale contro test.** Le misure vengono da scenari di test, non da traffico reale. Quanti messaggi sono "di salute" lo dirà solo il primo mese di dati: le domande di salute sono di più delle urgenze vere, e il manifesto le mette tutte insieme.

Con il 30% di domande di salute su Sonnet il costo per domanda è circa **5 volte** quello del business plan. I margini, la soglia giornaliera (§5 del doc 04) e il numero di domande per piano vanno rifatti.

## (e) Rischio: perché "zero allucinazioni" non è garantibile

Anche con fonti approvate il modello può:
- leggere male una fonte o unire due fonti in un'affermazione che nessuna delle due fa;
- riempire un vuoto con la propria conoscenza;
- ricevere dalla ricerca il pezzo sbagliato, oppure non ricevere quello giusto;
- applicare una regola di un'altra specie.

Inoltre le fonti stesse possono essere incomplete o superate. Un modello più grande sbaglia meno spesso, non mai. "Zero" è una promessa che nessun fornitore e nessuna architettura possono fare, e scritta nel materiale pubblico sarebbe anche un rischio legale.

**Cosa riduce davvero il rischio**, in ordine di efficacia per Quokka:

1. **Regole fisse fuori dal modello dove l'errore è grave.** Già fatto: urgenze riconosciute senza modello, apertura e primo soccorso fissi, rifiuti di dose ed eutanasia, controlli sul testo (dosi, specie sbagliata, prezzi, certificazioni), ritorno ai testi fissi.
2. **Rispondere dalle fonti con la citazione, e dire "non ho una fonte" invece di inventare**, solo sulle domande di salute. La via rigorosa esiste: va riaccesa su quel perimetro, con un corpus vero, e verificata con un controllo meccanico delle citazioni (`validate_answer` controlla già che i numeri citati esistano).
3. **Valutazione misurata, non promessa.** Gli scenari di `scripts/eval/chat_quality` (normali, consapevolezza, quotidiani, stress, ampi; più di 120 casi con giudice) e gli utenti sintetici. Ogni cambio di modello o di corpus si misura sugli stessi scenari prima di uscire.
4. **Revisione veterinaria del corpus e dei passi fissi** (`docs/product/12`, revisione delle urgenze, ancora aperta).
5. Solo dopo, e se la misura lo giustifica, **un modello più forte** sul sottoinsieme in cui sbaglia quello piccolo.

## (f) Piano a fasi e raccomandazione

**Raccomandazione:** tenere l'impianto attuale (regole fisse più Haiku, con le urgenze già scritte dal modello entro testi fissi) e investire nel **corpus**, non nei fornitori. Niente Qdrant, Pinecone, OpenAI, Voyage o Cohere per ora. Sonnet solo dove una misura dimostra che serve.

| Fase | Cosa | Fornitori nuovi | Costo |
|---|---|---|---|
| **0. Misura** (prima di decidere) | Sugli scenari d'urgenza e di salute (circa 40-60): **Haiku senza fonti** (oggi), **Haiku con le note vincolanti** (le urgenze lo fanno già), **Sonnet** con le stesse note. Criteri: sicurezza (azione giusta, niente dose, niente "aspetta"), errori fattuali segnati dal giudice e da un veterinario su un campione, lunghezza, latenza. | nessuno | sotto 5 $ di modello: Sonnet circa 0,021 $ × 60, più Haiku e il giudice |
| **1. Corpus** | Riprendere il manuale (doc 13) come corpus: prima i segni d'allarme e il primo soccorso di cane, gatto, coniglio e furetto, poi le altre specie. Schede da 200-300 parole, parole nostre, fonte citata, revisione veterinaria. Salvate in una tabella Supabase con specie, categoria e fonte. | nessuno | lavoro editoriale e veterinario |
| **2. Ricerca** | Ricerca testuale di Postgres con filtro per specie e categoria, al posto della ricerca in memoria. Nel prompt 3 pezzi in `<fonti_approvate>`, con i limiti alzati. Misurare quante volte il pezzo giusto arriva (richiamo) sugli scenari. | nessuno | basso |
| **3. Risposta dalle fonti** | Sulle domande di salute: rispondere dalle fonti con la citazione; "su questo non ho una fonte verificata" quando manca; controllo meccanico delle citazioni. Misurare contro la fase 0. | nessuno | basso |
| **4. Router a tre categorie** | Solo se la fase 0 lo giustifica: router su Haiku con le tre categorie, sopra le liste fisse (che restano prime) e senza far fermare la chat a un falso "fuori tema". Sonnet solo su SALUTE_PERICOLO, con un tetto di spesa. | nessuno (Sonnet è Anthropic) | da 3,6× a 7,5× il costo per domanda (vedi d) |
| **5. Embedding** | Solo se la fase 2 mostra, misurato, che la ricerca testuale perde pezzi pertinenti con un corpus grande (oltre circa 500 pezzi). Allora si sceglie un fornitore di embedding, con contratto, inventario e nuovo consenso. | sì | da valutare |

**Da provare per primo:** la fase 0, cioè Haiku contro Sonnet, tutti e due con le note vincolanti, sugli scenari d'urgenza e di salute. Se Sonnet non è chiaramente più sicuro, il router con Sonnet non vale 4-7 volte il costo. Se lo è, si passa alla fase 4 limitata alle urgenze vere, che sono meno delle "domande di salute".

## Decisioni del proprietario

1. **Manuale come corpus.** Riprendere il doc 13 come corpus del RAG e decidere chi fa la revisione veterinaria.
2. **Misura della fase 0.** Autorizzare la prova Haiku contro Sonnet (sotto 5 $) prima di qualsiasi scelta sul router.
3. **Nessun fornitore nuovo per ora.** Accettarlo: niente OpenAI, Voyage, Qdrant, Pinecone o Cohere; Supabase per la ricerca.
4. **Formulazione pubblica.** Al posto di "zero allucinazioni": risposte dalle fonti approvate, con la fonte indicata, e "non lo so" quando la fonte manca.
5. **Tetto di costo per Sonnet.** Se la misura lo giustifica, decidere quanto costo per domanda è accettabile, rifacendo il doc 04.
