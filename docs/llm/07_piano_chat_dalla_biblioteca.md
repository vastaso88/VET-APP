# Piano approvato il 17/11/2026: la chat risponde dalla biblioteca di fonti ufficiali sul nostro server

## Contesto

Il proprietario ha respinto le schede scritte a mano e la corsia veloce per le urgenze. Decisioni
sue (17/11/2026):
- nessuna scheda preimpostata: solo uno schema di ricerca e uno schema di risposta;
- un archivio di **testi originali scaricati sul nostro server** (leggi, articoli scientifici,
  documenti ufficiali), da ampliare di volta in volta;
- le urgenze seguono la stessa strada delle altre domande: conta la qualità, non la velocità;
- gerarchia delle fonti, con il valore della rivista (tipo impact factor) come criterio;
- citazioni brevissime: asterisco in apice e in fondo «Autore, AAAA» o «MS, riferimento breve»,
  mai ripetute se già indicate nella stessa chat;
- controllo finale delle risposte: sì, da provare e misurare.

Obiettivo invariato: non inventare, solo fonti validate, risposte naturali e gradevoli, rimando
allo specialista quando c'è pericolo reale (salute o comportamento verso persone/altri animali).

## Come funziona

**Fuori dalla chat: il bibliotecario** (script, non gira durante le risposte)
- Scarica i testi originali ammessi e li salva a pezzi con: livello della fonte, tipo di documento,
  autore, anno, rivista, valore della rivista, licenza, indirizzo.
- Ammessi (diritti): leggi e atti ufficiali; enti pubblici con licenza aperta; articoli ad accesso
  aperto con licenza di riuso libero (CC0, CC BY). Esclusi finché non c'è un permesso scritto:
  manuali commerciali, linee guida con diritti riservati, licenze «non commerciale».
- Gerarchia: (1) leggi e autorità pubbliche; (2) società scientifiche e linee guida; (3) studi con
  revisione tra pari: rassegne prima degli studi singoli, poi valore della rivista (equivalente
  gratuito dell'impact factor, preso una volta all'ingresso), poi anno; (4) università e manuali.
  Mai blog, forum, social, negozi, allevatori, Wikipedia, testi di IA.
- Crescita: ogni domanda rimasta senza fonte viene contata (solo specie + tema, mai il testo); ogni
  settimana il bibliotecario cerca testi per i temi più richiesti.
- Riuso di ciò che esiste: disegno delle tabelle già scritto e mai riempito
  (`scripts/setup/supabase_llm_sources_schema.sql`: `ai.source_documents`,
  `ai.source_document_chunks`, `ai.tier_rank`, `ai.rank_source_documents`,
  `admin_ingest_scientific_documents`); collegamenti a Europe PMC, PubMed, OpenAlex, Crossref in
  `packages/infrastructure/llm/retrieval/` (oggi spenti) usati per scaricare, non per rispondere.

**Dentro la chat: quattro passi, uguali per tutte le domande**
1. *Capire la domanda* (Haiku leggero): specie, tema, se c'è pericolo, se è troppo vaga (allora 2-3
   domande); parole di ricerca in inglese e italiano, senza dati personali.
2. *Cercare nella biblioteca*: ricerca per parole nel database + scelta dei passi migliori; ordine
   dato dalla gerarchia.
3. *Scrivere dai passi trovati*: prosa libera, circa 150-180 parole; asterisco dove serve; in fondo
   il riferimento breve; al massimo 2-3 fonti; nessuna ripetizione di fonti già citate nella chat.
   Se c'è pericolo, la risposta lo dice per prima cosa e indica lo specialista giusto.
4. *Controllo*: ogni fatto ha dietro un passo trovato? Altrimenti la frase si toglie o si riscrive
   una volta. Niente trovato: «non ho una fonte su questo» + a chi rivolgersi (unica frase fissa).

Restano fuori dalla discussione, perché sono legge e sicurezza: mai dosi, autolesionismo, ferita a
una persona, richieste dannose, anonimizzazione, consensi, limiti dei piani, avviso «risponde un'IA».

## Cosa sparisce

Frasi fisse attivate da parole chiave (aperture d'urgenza, domande di chiarimento fisse, «non trovo
documenti», «profilo di un altro animale»), passi d'urgenza per specie scritti da noi,
citazioni-segnaposto e note non verificate, il progetto delle schede scritte a mano (le 11 esistenti
restano come testi della biblioteca).

## Primo passo: prova, senza toccare l'app

1. Mini-biblioteca di 150-200 testi sui temi delle 61 domande del confronto (file locali, ricerca
   semplice: niente database di produzione).
2. Chat di prova che risponde solo da lì, con citazioni nel formato deciso.
3. Stesso giudice alla cieca, a fianco di Quokka attuale, Haiku nudo e Sonnet nudo.
4. Misure: fatti inventati, utilità, domande senza fonte (per gruppo di specie), qualità delle
   fonti scelte, tempo, costo, falsi allarmi del controllo.
5. Rapporto per non tecnici in `.local/chat_eval/biblioteca/report.md`.

Chi: sessione Chat LLM interna (prototipo e misure), sessione Manuale (regole di ammissione e
scarico dei testi), Normativa (conferma diritti e licenze prima di scaricare). Solo strumenti di
prova, mai chiavi né dati di produzione.

**Si costruisce nell'app solo se** inventa meno dei modelli nudi, è utile almeno quanto Haiku nudo
e il proprietario accetta la quota di domande senza fonte.

## Se la prova va bene (dopo il sì del proprietario)

- Biblioteca vera nel database (SQL lanciato dal proprietario; valutare Supabase Pro per lo spazio).
- Nuovo percorso di risposta dietro un interruttore, la chat attuale resta finché la nuova non la
  batte sui 279 casi + i 61 del confronto; giro 4 degli utenti di prova.
- App: asterischi e riferimenti brevi (build successiva).
- Lettere di richiesta permesso ai titolari delle fonti escluse (le preparo io, le manda il
  proprietario).
- Subito, a parte: togliere dalle urgenze di oggi le frasi contraddette dallo studio (doc 20).

## Rischi

- **Copertura**: senza i manuali con diritti riservati, alcuni temi (primo soccorso degli esotici)
  resteranno senza fonte finché non arrivano permessi o articoli aperti.
- **Testi tecnici**: gli articoli scientifici vanno tradotti in parole da proprietario; contengono
  dosi, che la chat non deve mai riportare (controllo a codice esistente).
- **Ricerca in 5 lingue** su testi quasi tutti in inglese: da misurare nella prova.
- **Costo**: più testo letto per risposta; nessun costo per ricerca. Da misurare.

## Verifica

Prova: rapporto con le misure sopra e 5 esempi affiancati. Costruzione: `uv run pytest`, `ruff`,
`mypy`; controllo a codice che ogni fonte citata sia in biblioteca, con livello e licenza ammessi.
