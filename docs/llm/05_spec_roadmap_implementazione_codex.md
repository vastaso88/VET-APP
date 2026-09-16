# SPEC — Roadmap di Implementazione per Codex

> **Superseded**: dove questo documento (v1) è in contrasto con la VetGPT CORE ENGINE — MASTER
> DIRECTIONAL SPECIFICATION v3, vale la v3. Tenuto come riferimento storico.

## Obiettivo
Guidare Codex nell'implementazione incrementale del sistema, riducendo il rischio e massimizzando la velocità di consegna del prototipo.

## Strategia generale
Lavorare per vertical slice. Ogni milestone deve produrre software eseguibile, non solo struttura.

## Milestone 0 — Fondazioni di progetto
Codex deve:
- creare struttura repo backend/frontend coerente con il resto del progetto;
- definire variabili ambiente;
- predisporre configurazione Supabase;
- creare modulo `llm/`, `retrieval/`, `sources/`, `chat/`, `audit/`, `tests/`.

Deliverable:
- repo bootstrappata;
- file `.env.example`;
- struttura moduli;
- README tecnico.

## Milestone 1 — LLM Gateway con Groq
Codex deve:
- creare interfaccia provider astratta;
- implementare `GroqProvider`;
- aggiungere health check e gestione errori;
- creare test di integrazione mockati.

Deliverable:
- chiamata singola funzionante al provider;
- adapter indipendente dal resto del dominio.

## Milestone 2 — Schema Supabase e seed
Codex deve:
- scrivere migrazioni SQL;
- creare tabelle chiave;
- abilitare pgvector;
- predisporre seed data.

Deliverable:
- database avviabile da zero;
- seed dimostrativi;
- funzione base di similarity search.

## Milestone 3 — Ingestion pipeline fonti
Codex deve:
- implementare client per discovery metadata;
- normalizzare record;
- salvare articoli e chunk;
- calcolare tier e score iniziali.

Deliverable:
- script CLI o job di ingestione;
- almeno 20 articoli dimostrativi correttamente indicizzati.

## Milestone 4 — Retrieval + ranking
Codex deve:
- implementare query semantiche;
- filtrare per specie e tier;
- aggiungere ranker esplicito;
- produrre selected evidence set.

Deliverable:
- endpoint o servizio che riceve query e restituisce fonti ordinate.

## Milestone 5 — Chat orchestration end-to-end
Codex deve:
- unire classificazione, safety, retrieval, prompting e provider;
- produrre output strutturato;
- salvare audit trail.

Deliverable:
- endpoint chat funzionante.

## Milestone 6 — Hardening del prototipo
Codex deve:
- migliorare logging;
- aggiungere test edge case;
- gestire timeout e retry;
- affinare fallback e messaggi di limite.

Deliverable:
- prototipo stabile per demo interna.

## Priorità di sviluppo
Ordine di priorità:
1. pipeline chat funzionante con Groq
2. retrieval affidabile
3. citazioni e confidenza
4. audit trail
5. arricchimento fonti
6. refinement UI

## Definition of Done per milestone
Una milestone è chiusa solo se:
- il codice gira localmente;
- esistono test minimi;
- la documentazione è aggiornata;
- non ci sono segreti hardcodati;
- il comportamento è osservabile via log.

## Convenzioni di codice
Codex deve:
- preferire moduli piccoli e testabili;
- evitare funzioni monolitiche;
- usare DTO/contract chiari;
- separare dominio, infrastruttura e adapter esterni;
- commentare solo dove serve davvero.

## Anti-pattern vietati
- chiamare Groq direttamente dal controller;
- usare il modello senza retrieval per domande cliniche;
- mischiare scoring fonti e rendering UI;
- salvare citazioni come testo libero non verificabile;
- affidarsi solo a impact factor come criterio unico di verità.

## Estensioni future già previste
- `OpenAIProvider`
- analisi documenti PDF clinici
- triage più avanzato
- supporto multimodale
- ranking con feedback utente e outcome reali

## Output atteso finale del prototipo
Alla fine delle milestone iniziali, il sistema deve essere in grado di:
- rispondere a una domanda sul pet;
- dichiarare su quali fonti si basa;
- limitarsi in assenza di evidenza;
- reindirizzare a veterinario quando necessario;
- essere tecnicamente pronto al passaggio da Groq a provider premium.

## Nota futura — Gestione admin delle fonti
Nelle fasi successive deve essere prevista un'interfaccia di amministrazione per:
- aggiornare manualmente la rubrica delle fonti affidabili
- importare e revisionare snapshot dei ranking esterni
- pianificare aggiornamenti periodici dei dati di discovery e classificazione
- promuovere o bloccare documenti candidati all'ingestione e alla vettorializzazione
