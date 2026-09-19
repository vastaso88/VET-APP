# SPEC — Architettura Engine LLM

> **Superseded**: dove questo documento (v1) è in contrasto con la VetGPT CORE ENGINE — MASTER
> DIRECTIONAL SPECIFICATION v3, vale la v3. Tenuto come riferimento storico.

## Obiettivo
Implementare un motore LLM modulare, inizialmente appoggiato a Groq, capace di funzionare come chatbot ma con un comportamento controllato da retrieval, ranking delle fonti e policy di affidabilità.

## Principio guida
Il sistema **non deve essere un semplice wrapper attorno a un modello**. Deve essere un orchestratore composto da servizi distinti.

## Architettura logica

```text
Client Chat UI
   ↓
API Gateway / Backend
   ↓
Conversation Orchestrator
   ├── Intent Classifier
   ├── Safety & Triage Guard
   ├── Retrieval Service
   ├── Evidence Ranker
   ├── Prompt Builder
   ├── LLM Gateway
   │      └── GroqProvider
   └── Response Formatter
   ↓
Supabase / Postgres
```

## Componenti richiesti

### 1. Conversation Orchestrator
Responsabilità:
- ricevere input utente e contesto pet;
- classificare la domanda;
- decidere la modalità operativa;
- attivare retrieval, ranking, prompting e generazione;
- restituire output strutturato.

Interfaccia minima:

```ts
interface ChatOrchestrator {
  answer(input: ChatRequest): Promise<ChatResponse>
}
```

### 2. Intent Classifier
Deve classificare almeno queste categorie:
- `general_info`
- `clinical_question`
- `nutrition_question`
- `behavior_question`
- `preventive_care`
- `document_explanation`
- `urgent_red_flag`
- `unknown`

Il classificatore può essere inizialmente rule-based + lightweight model.

### 3. Safety & Triage Guard
Responsabilità:
- intercettare red flag (convulsioni, dispnea, trauma, emorragia, anuria, collasso, ecc.);
- abbassare il grado di autonomia della risposta;
- generare messaggi di escalation verso veterinario o pronto soccorso.

Regole:
- se `urgent_red_flag`, il sistema non deve produrre una pseudo-diagnosi dettagliata;
- deve invece fornire messaggio di urgenza, prudenza e supporto informativo essenziale.

### 4. Retrieval Service
Responsabilità:
- costruire query semantiche e filtri strutturati;
- interrogare il database vettoriale e i metadati;
- restituire candidati eleggibili.

Filtri minimi:
- specie;
- dominio clinico;
- peer-reviewed;
- non retractato;
- tier affidabilità;
- lingua del record se utile;
- recency, se rilevante.

### 5. Evidence Ranker
Responsabilità:
- ordinare i candidati in base a similarità semantica, qualità della fonte e rilevanza clinica;
- selezionare il set finale di evidenze.

Formula iniziale suggerita:

```text
final_score =
  0.40 * semantic_similarity +
  0.20 * source_trust_score +
  0.15 * article_quality_score +
  0.15 * species_relevance +
  0.10 * recency_score
```

### 6. Prompt Builder
Deve costruire prompt differenti per:
- general chat;
- evidence answer;
- triage response;
- document explanation.

Vincoli:
- includere solo fonti effettivamente recuperate;
- vietare inferenze non supportate;
- obbligare il modello a dichiarare incertezza quando le fonti sono limitate.

### 7. LLM Gateway
Obiettivo: astrazione provider.

Interfaccia minima:

```ts
interface LlmProvider {
  generate(params: LlmGenerationRequest): Promise<LlmGenerationResponse>
}
```

Implementazioni richieste:
- `GroqProvider` adesso
- struttura pronta per `OpenAIProvider` in futuro

### 8. Response Formatter
Responsabilità:
- trasformare l'output del modello in un payload stabile per frontend;
- aggiungere metadati, citazioni, confidenza e disclaimer.

## Modalità operative

### Mode A — General
Usare per onboarding, FAQ semplici, spiegazioni non cliniche, navigazione app.

### Mode B — Evidence
Usare per domande cliniche, nutrizionali, preventive, comportamentali.
Questa modalità richiede retrieval e citazioni.

### Mode C — Triage
Usare quando emergono red flag o rischio elevato.
Risposta sintetica, prudente, con orientamento all'azione.

## Contratto di output

```json
{
  "answer": "testo finale",
  "mode": "evidence",
  "confidence": "medium",
  "sources": [
    {
      "title": "...",
      "doi": "...",
      "pmid": "...",
      "year": 2024,
      "journal": "...",
      "tier": "A"
    }
  ],
  "limitations": ["..."],
  "safety_flags": ["..."],
  "recommended_action": "..."
}
```

## Regole per Codex
- Non usare chiamate dirette al provider fuori da `LlmGateway`.
- Tutta la business logic deve essere testabile senza accesso reale al provider.
- Il sistema deve supportare timeout, retry limitati e fallback controllati.
- Non persistere segreti nel repository.
- Ogni risposta deve poter essere ricostruita tramite log applicativi.

## Acceptance criteria
1. Esiste una chiamata unica `answer()` che gestisce l'intero flusso.
2. L'orchestratore seleziona la modalità giusta.
3. Le risposte evidence includono fonti.
4. Le risposte triage bloccano il comportamento eccessivamente assertivo.
5. Groq è incapsulato dietro un adapter.
