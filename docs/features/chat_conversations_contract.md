# Chat: titoli, riassunto per il veterinario, risposta progressiva

Contratto tra backend (sessione "Chat LLM interna") e app (sessione "UI/UX e funzionalità
base"), 2026-10-06. Gli endpoint esistono già nel backend; quelli dell'app sono quelli che
`chat_remote_data_source.dart` già chiama.

## 1. Titolo della conversazione

- Alla creazione il backend genera un titolo breve in italiano dal primo messaggio
  (euristica senza modello, max 40 caratteri): "lo sbadiglio può essere un problema?" →
  "Lo sbadiglio può essere un problema"; "Mi spieghi il referto degli esami del sangue?" →
  "Il referto degli esami del sangue". Fallback: "Nuova conversazione".
- Le conversazioni vecchie ("Chat for {pet_id}") ricevono il titolo dal primo messaggio la
  prima volta che vengono lette (`GET /conversations` o invio di un messaggio) e il nuovo
  titolo viene salvato.
- **Rinomina**: `PATCH /conversations/{id}` con body `{"title": "..."}`.
  - Solo il proprietario; altrimenti 400 `conversation not found` (non si conferma
    l'esistenza di conversazioni altrui).
  - Il titolo viene ripulito (spazi, caratteri di controllo) e tagliato a 60 caratteri;
    vuoto → 400 `invalid_title: ...`.
  - Risposta 200: `{"id": "...", "title": "<titolo salvato>"}`. L'app mostri il titolo
    restituito, non quello digitato.

## 2. Riassunto per il veterinario

- `GET /conversations/{id}/summary` → 200 `{"summary": "<markdown>", "generated_at": "<ISO>"}`.
- Solo il proprietario (400 `conversation not found`); conversazione senza messaggi
  dell'utente → 400 `conversation_empty: ...`; modello non disponibile → 502.
- Il testo è markdown in italiano con intestazione fissa ("Riassunto per il veterinario —
  Thor (Cane)", data, "Non è una diagnosi…"), sezioni fisse (Animale / Motivo del contatto /
  Sintomi riferiti dal proprietario e quando / Cosa è stato osservato / Documenti citati /
  Domande aperte per il veterinario) e una chiusura fissa. Nessun dato del proprietario:
  il testo inviato al modello passa dall'anonimizzatore e il nome del proprietario viene
  tolto.
- È una chiamata al modello (circa 1-2 secondi): l'app mostri un'attesa. Non viene salvato:
  ogni richiesta lo rigenera.

## 3. Risposta progressiva (streaming)

Valutazione tecnica del backend:

- **Fattibile**: Vercel serve risposte in streaming dalle funzioni Python (FastAPI
  `StreamingResponse`); Groq espone `stream=true` (Server-Sent Events) sullo stesso endpoint
  che usiamo.
- **Cosa resta prima dello streaming, senza cambiare**: safety gate, guardia sui dosaggi,
  messaggi fissi sui referti (consenso assente, file illeggibile…), rigenerazione del
  titolo. Tutto questo è deterministico e produce la risposta intera in un colpo: per
  questi casi l'endpoint emette un solo evento con il testo completo.
- **Il nodo**: due controlli oggi avvengono *dopo* aver visto la risposta intera:
  1. "mai un turno di sole domande" dove non è ammesso (si rigenera una volta);
  2. validazione finale (specie sbagliata, citazioni inventate).
  In streaming il testo è già sullo schermo quando li si può valutare.
- **Proposta**:
  - rigenerazione: in streaming si rinuncia e ci si affida alle istruzioni. Dato misurato
    oggi su 20 conversazioni di casi quotidiani: la rigenerazione non è mai scattata
    (1,0 chiamate per risposta); nel giro precedente (34 scenari) la media era 1,04. Il
    costo della rinuncia è quindi raro e si misura con lo strumento di valutazione;
  - validazione finale: se fallisce, l'endpoint chiude lo stream con un evento `notice`
    che l'app mostra sotto la risposta ("Questa risposta potrebbe contenere un errore:
    …"), invece di ritirare il testo;
  - i controlli deterministici a monte restano identici: la sicurezza non cambia.
- **Contratto proposto** (nuovo endpoint, l'attuale `POST /chat` resta):
  `POST /chat/stream`, stesso body di `/chat`, risposta `text/event-stream` con eventi:
  - `meta` — `{"conversation_id", "mode", "title"}` (primo evento, sempre);
  - `delta` — `{"text": "..."}` (frammenti, nell'ordine);
  - `notice` — `{"text": "..."}` (facoltativo, nota da mostrare sotto la risposta);
  - `done` — `{"message_id", "state", "ai_generated"}` (ultimo evento, sempre).
  In caso di errore del modello a metà: evento `error` `{"detail": "..."}` e chiusura;
  il messaggio parziale non viene salvato.
- **Persistenza**: il messaggio dell'assistente viene salvato alla fine dello stream, con
  il testo completo, come oggi.
- **Da fare lato backend se approvato** (non ancora implementato): porta `LLMClient`
  con `stream`, variante streaming in `GroqChatApi`, divisione dell'orchestratore in
  "preparazione" (deterministica) e "chiusura" (post-stream), endpoint. Stima: un ciclo
  di lavoro dedicato con test; va provato su Vercel perché il buffering della piattaforma
  può annullare l'effetto progressivo.
- **Alternativa senza backend**: comparsa progressiva lato app del testo già ricevuto
  (nessuna latenza in meno, solo percezione). Consigliata come primo passo se si vuole
  l'effetto subito.

## Stato (2026-10-06)

- Punti 1 e 2: app allineata (messaggi d'errore mappati: `invalid_title`, `conversation_empty`,
  502). Backend pronto nella working tree, in attesa di rilascio.
- Punto 3: contratto SSE accettato dall'app, con tre richieste recepite: eventi come
  descritti; un messaggio parziale interrotto non viene salvato; `notice` sotto la risposta.
  Implementazione backend solo dopo l'approvazione dell'Orchestratore.
