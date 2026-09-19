# SPEC — Engine Fonti e Affidabilità

> **Superseded**: dove questo documento (v1) è in contrasto con la VetGPT CORE ENGINE — MASTER
> DIRECTIONAL SPECIFICATION v3, vale la v3. Tenuto come riferimento storico.

## Obiettivo
Costruire un sottosistema che acquisisce, normalizza, classifica e indicizza fonti scientifiche veterinariamente rilevanti, in modo da alimentare il chatbot con evidenze affidabili.

## Principio guida
L'affidabilità non può dipendere da un solo indicatore. Serve uno **score composto** che consideri qualità della rivista, qualità dell'articolo, rilevanza clinica, pertinenza di specie e integrità editoriale.

## Fonti upstream prioritarie
Codex deve progettare la pipeline con priorità per:
- PubMed / NCBI E-utilities
- PubMed Central / PMC Open Access
- Crossref
- OpenAlex
- eventuali guideline o consensus statement da enti e società scientifiche

## Modello di affidabilità

### Concetti separati
1. **Journal quality** — reputazione e segnali bibliometrici della fonte editoriale.
2. **Article quality** — forza metodologica del singolo studio.
3. **Clinical relevance** — utilità reale per rispondere alla domanda.
4. **Species relevance** — corrispondenza tra specie studiata e specie del pet.
5. **Integrity status** — retraction, correction, preprint, peer review, versioning.

## Tier di affidabilità

### Tier A
- guideline
- consensus statement
- systematic review
- meta-analysis
- review clinicamente forte in riviste autorevoli

### Tier B
- randomized trial
- controlled trial
- cohort study
- strong observational study

### Tier C
- case series
- case report
- narrative review
- studio preliminare

### Tier D
- preprint
- opinione
- materiale non peer-reviewed
- contenuto scarsamente verificabile

## Regole hard
- articoli retractati: esclusi sempre;
- articoli con correzioni critiche: esclusione o forte penalizzazione;
- preprint: esclusi di default per clinica sensibile;
- documenti senza metadati minimi: non indicizzare nel corpus principale.

## Scoring proposto

### 1. `source_trust_score`
Valori input suggeriti:
- indicizzazione in database autorevoli;
- SJR / quartile;
- CiteScore;
- JIF se disponibile;
- reputazione dell'ente per guideline.

### 2. `article_quality_score`
Valutare:
- publication type;
- study design;
- dimensione campionaria se disponibile;
- presenza di outcome clinicamente utili;
- chiarezza dei limiti.

### 3. `species_relevance_score`
- 1.0 se specie perfettamente corrispondente;
- 0.6 se evidenza trasversale plausibile;
- 0.2 se specie diversa ma eventualmente utile solo a supporto debole.

### 4. `integrity_penalty`
- retractato: blocco totale;
- corrected: penalità variabile;
- preprint: penalità forte o esclusione.

### Formula finale suggerita

```text
final_trust_score =
  (0.35 * source_trust_score) +
  (0.30 * article_quality_score) +
  (0.20 * clinical_relevance_score) +
  (0.15 * species_relevance_score) - integrity_penalty
```

## Ingest pipeline

### Step 1 — Discovery
Recuperare identificativi e metadata di base.

### Step 2 — Normalization
Normalizzare:
- DOI
- PMID / PMCID
- titolo
- abstract
- anno
- journal
- publication type
- species tag
- clinical domain

### Step 3 — Enrichment
Arricchire con:
- metriche journal-level se disponibili;
- citation count;
- stato editoriale;
- open access / full text availability.

### Step 4 — Classification
Assegnare:
- tier affidabilità;
- punteggi;
- tag clinici;
- tag specie;
- eligibility RAG.

### Step 5 — Chunking
Segmentare full text / abstract in chunk semanticamente utili.

### Step 6 — Embedding
Produrre embeddings e salvarli nel database vettoriale.

### Step 7 — Audit
Registrare quando e come il record è stato ingestito o aggiornato.

## Estrazione di claim
Quando possibile, Codex deve prevedere una struttura per estrarre claim atomici, per esempio:
- relazione dieta → outcome;
- farmaco → effetto;
- sintomo → ipotesi differenziali principali;
- marker di laboratorio → interpretazione.

Non serve una perfezione iniziale. Serve una struttura futura.

## Policy di utilizzo nel chatbot

### Domande cliniche o nutrizionali
Servono almeno:
- una guideline forte;
- oppure due fonti Tier A/B coerenti.

### Domande con evidenza debole
Il sistema può rispondere solo se:
- lo dichiara esplicitamente;
- abbassa la confidence;
- rende chiari i limiti.

### Assenza di evidenza
Il sistema deve dire che non dispone di evidenza sufficiente.

## Non-obiettivi del prototipo
- bibliometria perfetta;
- full-text parsing universale di ogni editore;
- coverage completa del dominio veterinario;
- automazione totale della valutazione metodologica.

## Acceptance criteria
1. Ogni articolo indicizzato ha tier, punteggi e integrity status.
2. Il retrieval può filtrare per specie e livello di affidabilità.
3. Le fonti escluse non entrano nei prompt.
4. Il sistema può essere aggiornato periodicamente senza duplicati.
