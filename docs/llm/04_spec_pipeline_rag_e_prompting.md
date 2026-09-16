# SPEC — Pipeline RAG, Ranking e Prompting

> **Superseded**: dove questo documento (v1) è in contrasto con la VetGPT CORE ENGINE — MASTER
> DIRECTIONAL SPECIFICATION v3, vale la v3. Tenuto come riferimento storico.

## Obiettivo
Definire il comportamento end-to-end della pipeline che trasforma una domanda utente in una risposta basata su evidenze.

## Flusso end-to-end

```text
Input utente
  → normalizzazione query
  → intent classification
  → safety/triage check
  → estrazione filtri (specie, dominio, urgenza, età, contesto)
  → retrieval candidati
  → ranking evidenze
  → selezione fonti finali
  → prompt assembly
  → generazione LLM
  → validazione output
  → formatting risposta
  → audit/logging
```

## Step 1 — Normalizzazione della domanda
Codex deve prevedere una funzione che estragga:
- specie;
- età/stage di vita;
- eventuale patologia;
- eventuale sintomo;
- tono richiesto;
- lingua;
- presenza di documento allegato.

Output esempio:

```json
{
  "species": "cat",
  "life_stage": "senior",
  "clinical_domain": ["nephrology", "nutrition"],
  "suspected_conditions": ["ckd"],
  "urgency": "low",
  "language": "it"
}
```

## Step 2 — Triage e safety
Se la domanda contiene red flag, la pipeline deve ridurre o bloccare il percorso evidence standard e passare a una risposta triage.

## Step 3 — Retrieval candidati
Il retrieval deve unire:
- semantic search su chunk;
- filtri strutturati su metadati;
- esclusione di record non ammissibili.

Regole minime di esclusione:
- `is_retracted = true`
- `eligible_for_rag = false`
- `reliability_tier = 'D'` per domande cliniche sensibili
- specie non rilevante, salvo fallback debole dichiarato

## Step 4 — Ranking
Codex deve implementare un ranker esplicito e testabile.

Input del ranker:
- score semantico;
- final_trust_score;
- recency;
- species relevance;
- guideline boost.

Boost suggerito:
- guideline / consensus: +0.15
- systematic review / meta-analysis: +0.10
- specie corrispondente esatta: +0.10

## Step 5 — Selezione fonti finali
Regole:
- selezionare 3-8 chunk finali;
- preferire diversità di fonte;
- evitare chunk ridondanti;
- includere almeno una fonte ad alta autorità se disponibile.

## Step 6 — Prompt assembly

### Template di sistema per Evidence Mode
Il prompt di sistema deve imporre al modello le seguenti regole:
- rispondi solo sulla base delle evidenze fornite;
- non inventare citazioni;
- distingui tra evidenza forte e debole;
- dichiara quando l'informazione non è sufficiente;
- non formulare diagnosi definitive;
- usa tono chiaro, rassicurante e prudente.

### Struttura del prompt

```text
[System rules]
[User profile + pet profile]
[Intent + extracted filters]
[Evidence snippets]
[Required output schema]
```

## Step 7 — Validazione output
Dopo la risposta del modello, eseguire controlli minimi:
- sono presenti citazioni solo tra quelle fornite?
- il livello di confidenza è coerente con il materiale recuperato?
- ci sono affermazioni assolute non supportate?
- ci sono istruzioni rischiose da mitigare?

In caso di fallimento, forzare un fallback sicuro.

## Step 8 — Formatting risposta
Struttura raccomandata:
- risposta breve;
- cosa sappiamo;
- cosa non sappiamo;
- quando sentire il veterinario;
- fonti.

## Contratti dati

### `ChatRequest`
```ts
interface ChatRequest {
  userId: string
  petId?: string
  message: string
  locale: 'it' | 'en'
  conversationId?: string
}
```

### `ChatResponse`
```ts
interface ChatResponse {
  answer: string
  mode: 'general' | 'evidence' | 'triage'
  confidence: 'low' | 'medium' | 'high'
  sources: SourceRef[]
  limitations: string[]
  safetyFlags: string[]
  recommendedAction?: string
}
```

## Fallback strategy

### Fallback A
Se retrieval insufficiente:
- non improvvisare;
- restituire risposta prudente con limite esplicito.

### Fallback B
Se provider LLM fallisce:
- retry limitato;
- in caso di nuovo fallimento, risposta tecnica controllata lato server.

### Fallback C
Se ranking produce solo evidenza debole:
- output con confidence bassa;
- dichiarazione chiara dei limiti.

## Test richiesti
Codex deve creare test per:
1. red flag → triage mode
2. domanda nutrizionale → evidence mode
3. nessuna fonte affidabile → risposta limitata
4. citazioni non presenti → validazione fallita
5. Groq timeout → fallback gestito

## Acceptance criteria
1. Pipeline deterministica e testabile.
2. Nessuna citazione inventata.
3. Domande cliniche passano da retrieval.
4. Output strutturato e coerente.
