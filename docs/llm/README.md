# Pacchetto Codex — Engine LLM + Motore Fonti Affidabili

> **Nota storica.** Specifiche iniziali: dal 25/11/2026 Groq non c'è più, l'unico fornitore è Claude.

## Scopo
Questo pacchetto contiene le istruzioni operative per Codex al fine di implementare il motore LLM del prototipo dell'app veterinaria e il sottosistema di retrieval basato su fonti scientifiche verificate.

Il prototipo deve rispettare questi principi:

1. **Groq è il provider LLM iniziale**, scelto per rapidità, semplicità e costo contenuto.
2. **Il modello non è la fonte di verità**: per le domande cliniche, nutrizionali, preventive e comportamentali, la risposta deve essere generata a partire da evidenze indicizzate.
3. **Supabase/Postgres è il backbone** per dati applicativi, metadati delle fonti, embeddings, politiche di accesso e audit trail.
4. **Le fonti devono essere classificate, punteggiate e filtrate** prima di arrivare al prompt del modello.
5. **Le risposte devono contenere tracciabilità**: citazioni, livello di confidenza, limiti dell'evidenza, eventuali red flag cliniche.

## Obiettivo del prototipo
Costruire un MVP in cui l'utente possa:

- registrarsi e creare il profilo del pet;
- porre una domanda in chat;
- ricevere una risposta chiara e contestualizzata;
- visualizzare quali fonti supportano la risposta;
- sapere quando l'app non ha evidenze sufficienti;
- essere reindirizzato a consulto veterinario in presenza di segnali di rischio.

## Perimetro di implementazione richiesto a Codex
Codex deve implementare:

- un **LLM Gateway** provider-agnostic con adapter `GroqProvider`;
- un **motore RAG evidence-first**;
- uno **schema dati Supabase** per journaI, article, chunk, guideline, ranking e audit;
- una **pipeline di ingestione fonti** orientata a PubMed/PMC/Crossref/OpenAlex;
- un **motore di affidabilità** con scoring composto;
- una **chat orchestration** con modalità general / evidence / triage;
- un **output contract** che restituisca risposta, citazioni e confidenza;
- test minimi, seed data e documentazione tecnica.

## Regole architetturali non negoziabili

### 1. No source, no answer
Per le domande cliniche o potenzialmente cliniche il sistema non deve generare una risposta assertiva se il retrieval non produce evidenze ammissibili.

### 2. Nessuna citazione inventata
Il modello può citare soltanto record presenti nel database, recuperati dal retrieval layer.

### 3. Separazione netta dei ruoli
- LLM: comprensione, sintesi, riformulazione, generazione linguistica.
- Retrieval: recupero di evidenze.
- Ranking: priorità e qualità delle fonti.
- Safety layer: gestione limiti e urgenze.

### 4. Provider intercambiabile
Codex non deve hardcodare Groq nel dominio applicativo. Il provider LLM deve essere sostituibile con OpenAI o altri vendor senza riscrivere orchestrazione e prompt logic.

### 5. Tracciabilità completa
Ogni risposta generata deve avere un audit minimo con:
- richiesta utente;
- modalità usata;
- query di retrieval;
- record sorgente selezionati;
- prompt finale inviato al modello;
- output;
- timestamp.

## File inclusi
- `01_SPEC_ARCHITETTURA_LLM.md`
- `02_SPEC_ENGINE_FONTI_E_AFFIDABILITA.md`
- `03_SPEC_SCHEMA_DATI_SUPABASE.md`
- `04_SPEC_PIPELINE_RAG_E_PROMPTING.md`
- `05_SPEC_ROADMAP_IMPLEMENTAZIONE_CODEX.md`

## Definizione di completamento
Questo pacchetto è considerato attuato correttamente quando esiste una prima versione funzionante di backend in grado di:

1. ricevere una domanda utente;
2. classificare l'intento;
3. recuperare chunk affidabili filtrati per specie e dominio;
4. costruire un prompt evidence-first;
5. chiamare Groq;
6. restituire una risposta con citazioni e confidenza;
7. bloccare o limitare la risposta in assenza di fonti affidabili.
