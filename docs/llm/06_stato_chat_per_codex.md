# 06 — La chat di Quokka oggi: guida per chi ci lavora (Codex)

Stato al 2026-11-10, ramo `Francesco`, commit `8d239d3`. Questo documento descrive la sezione **chat** del backend così com'è nel codice: architettura, flusso di una risposta, regole di sicurezza, modelli, prompt, impostazioni, test, strumenti di misura e decisioni ancora aperte.

I documenti `01`-`05` di questa cartella sono le specifiche iniziali. Diverse parti sono superate: per esempio la pipeline «solo dalle fonti» è stata spenta il 2026-09-21 e sostituita dalla risposta naturale. Quando divergono da questo documento, vale il codice e questo documento.

---

## 1. Cos'è la chat

Quokka è un'app per proprietari di animali: aiuta a capire e gestire il proprio animale (etologia, relazione, cura quotidiana, salute, doveri di chi lo tiene), non sostituisce il veterinario (`docs/product/11_riposizionamento_consapevolezza_proprietario.md`).

La chat riceve un messaggio del proprietario riferito a un animale della sua scheda e restituisce una risposta. In base al caso la risposta è:
- un **testo fisso**: urgenze, dosi, tossici, eutanasia, minori, identità, fuori tema;
- scritta dal **modello**: Claude Haiku 5.5, con Groq come riserva;
- un **misto** dei due: apertura fissa più testo del modello nelle urgenze.

Lingue: italiano, inglese, spagnolo, tedesco (registro «Sie», mai «du»), francese («vous»).

---

## 2. Regole che non si cambiano (sicurezza e dati)

Valgono per ogni modifica (da `CLAUDE.md` e `docs/security/`):

1. **Proprietà dei dati.** Il backend usa la chiave service_role di Supabase: le policy RLS non lo proteggono. Ogni rotta chiama `get_current_user()` e ogni servizio che riceve un id (conversazione, messaggio, animale, allegato) confronta `owner_id` con l'utente. Se non coincide risponde «not found», che nel progetto è un `ValidationError`, cioè **HTTP 400** con `detail` «… not found». Ogni rotta nuova ha il suo test «utente B»; il modello è `tests/unit/test_security_ownership.py`.
2. **Tabella nuova:** `enable row level security`, policy `*_own` (o nessuna policy se solo il service role la legge), riga nel test della cancellazione account se contiene dati utente, riga in `docs/security/06_inventario_dati_fornitori.md`.
3. **Verso i fornitori di IA va solo testo ripulito.** Tutto passa da `ChatOrchestrator._anonymize_for_provider` (nomi, e-mail, telefoni, microchip). Mai e-mail, id utente, telefono, posizione o microchip nel prompt. Un fornitore nuovo richiede contratto, riga nell'inventario e spesso un consenso nuovo: **non aggiungerne.**
4. **Niente segreti** nel codice, nei test, nei log. Solo variabili d'ambiente, documentate per nome in `.env.example`. Il repository è pubblico: nei test solo dati inventati e indirizzi `example.com`.
5. **Log senza dati personali:** niente testo dei messaggi, e-mail, token. Le eccezioni dei fornitori non arrivano mai al client: l'handler è in `apps/api/main.py`.
6. **Input sempre limitato:** `Field(max_length=...)`, dimensione e firma dei file.
7. **Mai prove contro la produzione.** Prove locali con `SUPABASE_URL` vuoto, `PERSISTENCE_BACKEND=in_memory`, `AUTH_BACKEND=bootstrap`. Mai usare la quota Groq di produzione per le misure.
8. **Testi agli utenti:** nominano il fornitore (Anthropic, Groq) dove serve, **mai il modello** (Haiku, Sonnet).
9. **Git:** si lavora sul ramo `Francesco`. Non fare commit, push o merge senza un'istruzione esplicita del proprietario: nel progetto i salvataggi li fa una sessione dedicata.

---

## 3. Comandi

```bash
uv run pytest                                  # tutti i test (~3280, devono passare)
uv run pytest tests/unit/test_xxx.py -q        # test mirati durante il lavoro
uv run ruff check . && uv run ruff format .    # lint e formattazione (riga max 100)
uv run mypy apps packages tests                # tipi stretti; oggi restano solo 3 errori preesistenti su Presidio
uv run uvicorn apps.api.main:app --reload      # API in locale
uv run python tests/unit/test_italian_texts_unchanged.py --update   # aggiorna l'istantanea dei testi italiani approvati, SOLO se il cambio è voluto
uv run python scripts/i18n/check_i18n.py       # controllo delle traduzioni dell'app
```

Python 3.12+, mypy con `disallow_untyped_defs`. Su Windows usare `uv add --system-certs` se l'installazione dà errori di certificato.

---

## 4. Mappa dei file

### Rotte API (`apps/api/routes/`)
| Rotta | File | Note |
|---|---|---|
| `POST /chat` | `chat.py` | un messaggio, una risposta; dietro sottoscrizione attiva |
| `GET /conversations`, `PATCH`, `DELETE /conversations/{id}` | `conversations.py` | elenco, rinomina, cancella |
| `PUT /conversations/{id}/messages/{mid}` | `conversations.py` | modifica un messaggio e rigenera da lì |
| `POST /conversations/{id}/messages/{mid}/not-helpful` | `conversations.py` | pulsante «Non mi ha aiutato» (§10) |
| `GET /conversations/{id}/summary` | `conversations.py` | riepilogo per il veterinario |
| `POST /chat-attachments`, `GET /chat-attachments/{id}/file` | `chat_attachments.py` | foto e PDF |
| `/chat-response-reports` | `chat_response_reports.py` | segnalazioni delle risposte |
| `POST /speech-to-text` | `speech_to_text.py` | dettatura (Groq Whisper) |

Contratti per l'app: `docs/features/chat_conversations_contract.md`, `docs/features/chat_attachments_contract.md`.

### Servizi (`packages/core/application/services/`)
| File | Ruolo |
|---|---|
| `send_chat_message.py` | caso d'uso: carica conversazione, scheda dell'animale e consenso alla cartella, costruisce `ChatOrchestratorInput`, salva risposta e stato |
| `chat_orchestrator.py` | **il cuore** (~3900 righe): ordine dei controlli, testi fissi, urgenze, risposta naturale, controlli sulla risposta |
| `natural_answer_prompt.py` | prompt di sistema: voce, blocchi per tipo di richiesta, note opzionali, prompt d'urgenza |
| `urgency_classifier.py` | classificatore leggero (Haiku): urgenza + categoria + argomento (`health`/`care`/`off_topic`) in JSON |
| `mark_not_helpful.py` | «Non mi ha aiutato» |
| `llm_budget.py` | contatori giornalieri, tetto in euro, tetto Sonnet per piano (**della sessione Pricing: non modificare senza accordo**) |
| `llm_usage_recorder.py` | `InstrumentedLLMClient`: registra token, durata ed esito di ogni chiamata |
| `evidence_query_normalizer.py` | parole chiave in inglese per la ricerca (chiamata leggera) |
| `vet_summary.py` | riepilogo per il veterinario |
| `safety_gate.py` | liste di parole d'emergenza e segnali per specie |
| `medical_record_context_retriever.py`, `reminder_context_retriever.py` | cartella clinica e promemoria, **solo con consenso** |
| `edit_chat_message.py` | riscrittura di un messaggio: ripristina lo stato dall'istantanea `state_after` |

### Dominio
- `packages/core/domain/safety/`: rilevatori e testi fissi in 5 lingue.
  - `harmful_requests.py`: eutanasia, identità, salute umana, richiesta di rivelare il prompt, minori, fuori tema (`OFF_TOPIC_TEXTS`), prezzi, sì/no secco e altro.
  - `triage_clarification.py`: categorie e domande di chiarimento.
  - `first_aid.py`, `clarification_fit.py`, `exposure.py` (esposizione contro intenzione), `human_drug_toxicity.py`, `dosage_request.py`, `emergency_patterns.py`.
- `packages/core/domain/conversation/`: `models.py` (Conversation, ChatMessage, istantanea), `request_kind.py` (REPORT/DIRECT/SYMPTOM), `answer_cache.py`, `answer_cleanup.py`.
- `packages/core/domain/knowledge/`: `duty_notes.py` (doveri in Italia), `relevance.py`, `answer_validation.py`, `dose_in_answer.py`.
- `packages/core/domain/localization.py`: testi fissi d'urgenza e messaggi di sistema nelle 5 lingue.
- `packages/core/domain/medical_record/consent_text.py`: testo del consenso alla cartella clinica e versione.

### Infrastruttura
- `packages/infrastructure/llm/providers/`:
  - `anthropic_llm_client.py`: Claude via SDK ufficiale `anthropic`;
  - `reserve_llm_client.py`: Claude, poi Groq come riserva;
  - `groq_llm_client.py` e `groq_chat_api.py`;
  - `echo_llm_client.py`: finto, per demo e test.
- `packages/infrastructure/llm/retrieval/`: note curate in memoria (in produzione è attivo solo questo) e collegamenti a Europe PMC, PubMed, Crossref e OpenAlex (spenti in produzione).
- `packages/bootstrap/container.py`: collega tutto in base alle impostazioni.

---

## 5. Flusso di una risposta (`ChatOrchestrator._answer`)

L'ordine conta: i controlli deterministici vengono **prima** di qualsiasi modello.

0. **Autolesionismo della persona** (`expresses_self_harm`, dal 2026-11-16): prima di tutto, anche di una domanda di chiarimento in sospeso, una risposta fissa (`SELF_HARM_TEXTS`) con una sola frase generica: rivolgersi subito ai servizi di emergenza o a un servizio di ascolto del proprio Paese. **Nessun numero di telefono e nessun nome di servizio, in nessuna lingua** (decisione del proprietario del 21/11/2026: l'app non gestisce urgenze; il test `test_no_phone_numbers_in_fixed_texts.py` lo controlla su tutti i testi fissi e sulle note lette dal modello). Per un account 14–17 (`owner_is_minor`, da `account_age`) o per un bambino che scrive si aggiunge «parlane subito con un adulto di cui ti fidi». Nessun modello: quelle parole non arrivano al fornitore. Lo sconforto senza autolesionismo (`expresses_hopelessness`, solo in prima persona) segue la stessa frase generica d'apertura, poi il modello.
1. **Risposta a una domanda di chiarimento in sospeso** (`awaiting_safety_clarification`):
   - ferita su una persona → testo fisso;
   - il proprietario smentisce l'urgenza → il messaggio si rilegge come normale (non conta come domanda);
   - altrimenti si valuta la gravità ed eventualmente si va all'urgenza.
2. **Specie effettiva:** una specie diversa nominata nel messaggio vale più della scheda, tranne quando compare solo come qualificatore («la pipetta del cane»).
3. **Eutanasia in casa, minore ferito** → testi fissi. Un minore che scrive riceve «chiama un adulto» davanti a tutto.
4. **Controllo di sicurezza:**
   - SafetyGate più liste d'emergenza, sul testo da cui sono state tolte le sostanze negate;
   - una domanda educativa su un tossico («perché il cioccolato fa male?») non è un'urgenza;
   - un evento passato non è un'urgenza;
   - una domanda di chiarimento che contraddirebbe il messaggio viene saltata.
   Esiti possibili:
   - intenzione di dare un tossico → «No, mai» fisso;
   - urgenza chiara → `_urgent_answer` (§6);
   - caso dubbio → domanda di chiarimento fissa della categoria, che segue specie e sesso dell'animale.
5. **Dosi** → testo fisso, mai una dose. Una domanda mista («funziona? quante gocce?») riceve la frase fissa sulla dose e la risposta sul resto.
6. **Due animali, domanda d'identità, salute umana, richiesta di rivelare il prompt, saluti** → testi fissi.
7. **Ammissione al budget** (`LlmBudget.admit`): limite giornaliero del piano e quota dei modelli. Il messaggio conta come domanda solo se apre un argomento nuovo (§11). Al limite il classificatore legge comunque il messaggio: un'urgenza non viene mai fermata dal limite.
8. **Avvio in parallelo:** classificatore d'urgenza e ricerca delle fonti.
9. **Secondo parere** del classificatore: urgenza → `_urgent_answer`; caso dubbio → domanda di chiarimento, se esiste per quella specie.
10. **Fuori tema:** il classificatore dice `off_topic` **e** il messaggio non nomina animali, specie o il nome dell'animale → `OFF_TOPIC_TEXTS`, senza modello.
11. **Referto** (spiegare un documento) → risposta naturale con il documento come fonte.
12. **Risposta naturale** (`_generate_natural_answer`):
    - cache delle curiosità generali;
    - prompt di sistema con le note opportune;
    - classe di modello (`main` o `strong`, §9).
    Controlli sulla risposta:
    - citazioni esistenti, specie giusta, nessuna dose;
    - tolti prezzi inventati e rimandi rituali al veterinario;
    - nessun sì/no secco, nessuna certificazione;
    - prefissi fissi per bambini a rischio, sconforto, minori, dosi.
    Infine l'avviso sulla cartella clinica.
13. `answer()` pulisce il testo (`clean_answer_text`).

---

## 6. Urgenze

- **Riconoscimento:** solo regole fisse e classificatore, mai la risposta del modello.
- **`_urgent_answer`:** la **prima frase è fissa** (localizzata, dice di agire subito): dal giro 3 sono **tre aperture** a turno (`triage_opening`, `_2`, `_3`, scelta da `_opening_variant`: mai quella già usata nella stessa conversazione). Poi il modello scrive la parte libera sul caso e sulla domanda.
- **Primo gesto per specie e quadro (giro 3):** `_triage_texts` sceglie `bird_fumes` (padella antiaderente, `describes_fume_distress`), `axolotl`, `exotic_cool` (esotico + caldo), `bird_bleeding` / `exotic_bleeding`, `bird_respiratory` per un uccello che respira male. I passi generici non dicono più «al caldo». Le domande di chiarimento sul respiro e sul sangue scattano solo se il proprietario ne parla (`clarifying_question_fits`) e quella sul respiro comincia con un gesto sicuro. I **passi fissi di primo soccorso** della categoria e della specie (`triage_steps_*` in `localization.py`) gli arrivano come note **vincolanti** (`build_emergency_prompt`), e non può aggiungere motivazioni proprie.
- **Ritorno ai testi fissi:** errore, tempo scaduto (`URGENT_ANSWER_TIMEOUT_SECONDS`, 12 s), rifiuto del modello, quota finita, o testo che non passa i controlli (dose, altra specie, solo domande, sì/no) → si torna al testo fisso completo di prima.
- **Fissi e fuori dal modello:** rifiuti di dose, eutanasia in casa, minore ferito, identità.
- **Conteggio:** un'urgenza non consuma mai una domanda del piano.
- **Fonti dei passi d'urgenza:** il proprietario ha deciso (17/11/2026) che non ci sarà una revisione veterinaria; ogni gesto per specie deve avere una fonte pubblicata, altrimenti si riduce ai passi universali sicuri (calma, niente cibo, farmaci o acqua forzati, veterinario subito). I gruppi P-T e i passi generici («niente cibo», «acqua non in eccesso») sono «da fonte bibliografica», in attesa dello studio delle fonti (`docs/product/12_revisione_veterinaria_urgenze.md`). Non aggiungere gesti per specie senza fonte.

---

## 7. Modelli e fornitori

| Ruolo | Modello | Dove |
|---|---|---|
| Risposte e parte libera delle urgenze | Claude Haiku 5.5 (`claude-haiku-5-5`) | `AnthropicLLMClient`, classe `main` |
| Chiamate leggere (classificatore, parole chiave) | Haiku 5.5, `thinking` disattivato | classe `light` |
| «Fratello maggiore» (§9) | Claude Sonnet 5.5 (`ANTHROPIC_MODEL_STRONG`) | classe `strong`, **spento** |
| Riserva automatica | Groq (catena `LLM_MODEL` + `LLM_FALLBACK_MODELS`) | `ReserveLLMClient` |
| Visione allegati, dettatura | Groq | restano su Groq; immagini e audio non vanno ad Anthropic |

Dettagli del client Anthropic:
- **Parametri:** mai `temperature`; `output_config.effort` (`ANTHROPIC_EFFORT`, `ANTHROPIC_EFFORT_LIGHT`).
- **Cache:** il prompt di sistema è diviso in parte stabile e parte variabile, tutte e due in cache.
- **JSON:** si chiede uno schema (`json_schema`); se rifiutato, si ripete chiedendo il JSON a parole.
- **Consumo:** contato per intero (cache scritta, cache letta, ragionamento).
- **Rifiuti:** `stop_reason: refusal` → `LLMRefusal`, che non va alla riserva Groq.

Regione `inference_geo`:
- l'impostazione `ANTHROPIC_INFERENCE_GEO` esiste su `Francesco` ma il client non la invia ancora;
- la invia il ramo **`haiku-activation`**, che resta da parte fino all'attivazione di Anthropic in produzione, insieme al consenso v5 che nomina Anthropic e gli Stati Uniti;
- quel ramo si unisce **solo** il giorno dell'attivazione, insieme alla chiave su Vercel e ai contratti;
- Sonnet usa lo stesso payload, quindi riceve la stessa regione.

Riserva Groq: scatta su errore, tempo o quota finita di Claude, mai su un rifiuto. Con una scadenza passa solo il tempo rimasto, e sotto 3 s non viene chiamata.

---

## 8. Domanda di salute

**Cos'è una domanda di salute** (serve alla seconda prova, §9):
- parole cliniche o di prevenzione (intenti `clinical_question`, `preventive_care`);
- **oppure** parole sui denti nelle 5 lingue (`_DENTAL`; «mostra i denti» resta comportamento);
- **oppure** l'argomento `health` dato dal classificatore.
Non basta il tipo «sintomo» di `request_kind`, che marca come sintomo ogni frase che non è una domanda.

La vecchia regola delle schede per la salute (`HEALTH_SOURCES_RULE`) è stata tolta dal
codice il 20/11/2026: schede non più usate dal piano nuovo (piano 08, `docs/llm/08`).
Con lei sono usciti il selettore delle schede, l'archivio, lo script SQL della tabella e i
relativi test. Se la tabella era stata creata in Supabase, resta lì finché il proprietario
non decide di toglierla.

---

## 9. «Fratello maggiore»: Sonnet (`SONNET_ESCALATION`, spento)

**Quando scrive Sonnet** (sempre previo `LlmBudget.admit_sonnet`):
- la **parte libera delle urgenze**; i passi fissi restano invariati;
- la **prossima risposta di salute** dopo un segnale di insoddisfazione:
  - il pulsante «Non mi ha aiutato», che nel server diventa `escalate_next_health` della conversazione, mai un campo mandato dall'app;
  - oppure «non hai capito» e simili (`_DISSATISFIED`, 5 lingue);
  - oppure la stessa domanda riformulata, misurata come sovrapposizione delle parole con il messaggio precedente.
  Quella risposta riceve la nota «SECOND TRY».

**Tetto:** `admit_sonnet` applica il tetto per piano (Plus 1, Pro 2, Ultra 3 al giorno; `PlanLimits.daily_sonnet_answers`) e il tetto in euro. Con un rifiuto risponde Haiku, **senza dirlo all'utente**. Se il registro non risponde, risponde Haiku.

---

## 10. Contratto con l'app (pulsante «Non mi ha aiutato»)

- `health_answer: bool` sulla risposta di `POST /chat` e della modifica dei messaggi, al livello superiore e dentro `reply`. È vero solo per risposte di salute non urgente scritte dal modello.
- In `GET /conversations`: `messages[].health_answer` e `messages[].not_helpful`.
- `POST /conversations/{id}/messages/{mid}/not-helpful`:
  - corpo vuoto; risponde 200 `{"recorded": true}`, anche alla seconda chiamata (idempotente);
  - 400 «not found» se la conversazione non è dell'utente o il messaggio non è una risposta di salute;
  - non consuma domande.
- Lo stato interno (`escalate_next_health`, `awaiting_anamnesis` e gli altri di `INTERNAL_CONVERSATION_FIELDS`) **non esce mai** dall'API (`Conversation.public_dump`).

---

## 11. Conteggio delle domande (con la sessione Pricing)

`LlmBudget.admit(..., counts_as_question=...)`: conta come domanda del piano **solo il messaggio che apre un argomento**. Non contano, e lo si ricava solo dallo stato sul server:
- **(a)** la risposta a una domanda di chiarimento d'urgenza, anche quando la smentisce;
- **(b)** la risposta alla domanda sul consenso alla cartella;
- **(c)** un turno di intervista in corso;
- **(d)** la risposta a una domanda di **anamnesi** segnata dal server (`awaiting_anamnesis`):
  - il segno lo mette la pipeline quando, su un sintomo vago in modalità «può chiedere», la risposta è **fatta solo di domande** (`_only_questions`: ogni frase deve essere una domanda);
  - una domanda di cortesia finale («Vuoi sapere altro?») **non** basta;
  - una domanda nuova senza parole in comune con il caso conta lo stesso;
- **(e)** la seconda prova dopo «Non mi ha aiutato» o una riformulazione.

Le urgenze non contano mai. Le continuazioni hanno un tetto separato: 3 volte le domande del piano.

**Proprietà del codice:** `llm_budget.py`, `limits.py`, `pricing.py` sono della sessione Pricing. Le chiamate ad `admit` dentro l'orchestratore sono della chat. Nomi da non cambiare: `admit_sonnet`, `counts_as_question`, `sonnet_daily_limit`, `upgrade_plan`.

---

## 12. Prompt (`natural_answer_prompt.py`)

**Struttura:**
- **Parte stabile:** `_VOICE` più il blocco del tipo di richiesta (`_REPORT`, `_DIRECT`, `_SYMPTOM_*`). È la parte in cache, uguale per tutti: **non metterci dati variabili.**
- **Note variabili** in coda, solo quando servono:
  - consapevolezza, comportamento;
  - tossico chiesto per sapere, calendario di prevenzione;
  - minore, bambino a rischio, messaggio lungo, sì/no forzato, animale futuro;
  - visita oggi, dieta vegetale, lutto, sconforto, parte sulla dose;
  - altro paese, causa medica prima, viaggio al sud;
  - seguito di un'urgenza, altro animale, seconda prova.
- Le istruzioni sono in inglese; la risposta nella lingua dell'utente (`response_language_instruction`).

**Lunghezza:** risposte di circa **120-180 parole**, un elenco di passi quando serve, mai tagliare le avvertenze di sicurezza.

**Vincoli fissati dai test:**
- `test_prompt_budget.py`: prompt di sistema ≤ 9700 caratteri; prompt identico tra utenti.
- `test_prompt_repositioning.py`, `test_italian_texts_unchanged.py`: testi italiani approvati, con istantanea.

**Cache delle risposte:** se cambi le regole del prompt in modo che una risposta salvata non valga più, aggiorna `PROMPT_VERSION`, che entra nella chiave della cache.

---

## 13. Impostazioni (variabili d'ambiente)

Fonte di verità: `packages/shared/config/settings.py`. Le principali per la chat:

| Variabile | Predefinito | Note |
|---|---|---|
| `LLM_PROVIDER` | `echo` | `anthropic`, `groq` o `echo` (finto) |
| `ANTHROPIC_API_KEY` | vuoto | richiesta con `anthropic` |
| `ANTHROPIC_MODEL` | `claude-haiku-5-5` | |
| `ANTHROPIC_MODEL_STRONG` | `claude-sonnet-5-5` | |
| `SONNET_ESCALATION` | `false` | §9 |
| `ANTHROPIC_EFFORT`, `ANTHROPIC_EFFORT_LIGHT` | `low` | ammessi `low`, `medium`, `high` |
| `ANTHROPIC_INFERENCE_GEO` | `global` (`us` sul ramo di attivazione) | §7 |
| `ANTHROPIC_THINKING_HEADROOM_TOKENS`, `ANTHROPIC_TIMEOUT_SECONDS` | 1200, 30 | |
| `URGENT_ANSWER_TIMEOUT_SECONDS` | 12 | 0 = solo testi fissi |
| `LLM_API_KEY`, `LLM_MODEL`, `LLM_FALLBACK_MODELS`, `LLM_BASE_URL`, `LLM_MODEL_LIGHT` | | Groq: riserva, visione, dettatura |
| `LLM_DAILY_BUDGET_EUR`, `LLM_USD_PER_EUR` | 1.0, 1.1165 | tetto di spesa giornaliero dei modelli a pagamento (Pricing) |
| `CHAT_DAILY_MESSAGE_LIMIT_PER_USER` | | limite predefinito; i limiti per piano sono in `limits.py` |
| `URGENCY_CLASSIFIER_ENABLED`, `URGENCY_CLASSIFIER_TIMEOUT_SECONDS` | `true`, 6 | |
| `EVIDENCE_BACKEND` | `in_memory` | in produzione `in_memory`, senza chiamate di rete |
| `CHAT_ANSWER_CACHE_ENABLED`, `CHAT_ANSWER_CACHE_TTL_HOURS` | `true`, 24 | |

---

## 14. Stato e decisioni aperte (del proprietario)

1. **Sonnet nelle urgenze** (`SONNET_ESCALATION`): stessa sicurezza di Haiku, testo più concreto, circa 12 volte il costo.
2. In Supabase va eseguito lo script della Pricing `chat_usage_sonnet_followups.sql`.
3. **Attivazione di Anthropic:** chiave su Vercel, contratti, unione del ramo `haiku-activation` (consenso v5, regione). Fino ad allora la produzione risponde con Groq.
4. **Fonti bibliografiche dei passi fissi d'urgenza** (doc 12; niente revisione veterinaria, decisione del 17/11/2026).

**Problemi noti:**
- il classificatore a volte dà «forse» sul vomito del cane.

---

## 15. Misure (riassunto)

Strumento: `scripts/eval/chat_quality/run.py`, con gli scenari in `scenarios*.py` (stress 42, ampi, consapevolezza, quotidiani) e le misure in `docs/features/chat_quality_measurements.md`. Le prove locali usano chiavi di **conti separati** (`EVAL_LLM_API_KEY`, `EVAL_ANTHROPIC_API_KEY`), mai quelle di produzione. Esiste anche un adattatore che fa passare i modelli dal client Claude Code; serve un accesso già fatto e lo gestisce il proprietario.

| Cosa | Risultato |
|---|---|
| Costo Haiku 5.5, risposta completa | ≈ 1,48 $ ogni 1000 risposte (0,00134 € a domanda; nel business plan 0,002 € con il 50% di riserva) |
| Costo Sonnet 5.5 | ≈ 21 $ ogni 1000 risposte |
| Urgenze, sola parte libera (20 scenari) | Haiku ≈ 1,0 $, Sonnet ≈ 12,5 $ ogni 1000; tutti e due 20/20 sui controlli |
| Groq gratuito | 0 $ ma 200.000 token al giorno per conto (circa 70 risposte) |
| Salute con fonte citata, prima delle schede | 0 su 5 |
| Con regola e 11 schede in bozza (storico: schede tolte il 20/11/2026) | 6 su 7 risposte che hanno ricevuto una scheda la citano; riga «Fonte» 7 su 7 |

Non misurati: la latenza reale dell'API Anthropic e il costo con la cache del prompt attiva.

---

## 16. Test di riferimento (`tests/unit/`)

Prima di cambiare il comportamento, leggi il test che lo fissa:
- **Urgenze e sicurezza:** `test_urgent_answer.py`, `test_triage_clarification.py`, `test_emergency_phrasings*.py`, `test_safety_gate*.py`, `test_harmful_requests.py`, `test_exposure.py`, `test_dose_in_answer.py`.
- **Prove di stress e utenti sintetici:** `test_stress_fixes.py`, `test_stress_round3.py`, `test_wide_fixes.py`, `test_synthetic_users_fixes.py`, `test_synthetic_round2_fixes.py`, `test_synthetic_round3_fixes.py` (giro 3: esotici, aperture, dosi, instradamento, quadri vaghi, limite chat per piano). Gli scenari del giro 3 sono anche nell'eval: `scripts/eval/chat_quality/scenarios_giro3.py` (`run --category giro3`).
- **Fornitori:** `test_anthropic_llm_client.py`, `test_groq_model_fallback.py`.
- **Fuori tema, Sonnet, conteggio:** `test_off_topic_reply.py`, `test_fratello_maggiore.py`, `test_question_counting.py`, `test_sonnet_cap_and_followups.py` (Pricing), `test_teeth_and_species_questions.py`.
- **Consenso e dati:** `test_consent_texts_match_behaviour.py`, `test_notes_follow_record_consent.py`, `test_medical_record_consent_privacy.py`, `test_security_ownership.py`.
- **Prompt:** `test_prompt_budget.py`, `test_prompt_repositioning.py`, `test_italian_texts_unchanged.py`.
- **Comuni:** il finto client dei test è `tests/unit/llm_fakes.py` (`RecordingLLMClient`, risposte per scopo con `by_purpose`); l'API completa si prova in `tests/integration/test_api_flows.py`.

---

## 17. Trappole note

- **Consenso alla cartella clinica.** Cartella, note libere della scheda e promemoria (terapie comprese) vanno al modello **solo** con il consenso concesso sulla versione corrente (`effective_decision`; una versione vecchia vale «non deciso»). Lo stesso vale per il riepilogo per il veterinario. Se cambi il testo del consenso, cambia anche `CURRENT_VERSION` in `consent_text.py` **e** `_currentConsentVersion` in `apps/mobile_app/lib/features/pets/data/pet_demo_store.dart`; un test li tiene uguali.
- **Testi fissi:** esistono in 5 lingue con gli stessi segnaposto (`{name}` / `{pet_name}`); un test lo verifica. Il tedesco usa «Sie».
- **Testi italiani approvati:** fissati da un'istantanea. Aggiornala solo se il cambio è voluto.
- **Espressioni regolari multilingue:** lavorano sul testo passato da `normalize_for_matching`, cioè minuscolo e senza accenti. Usa i confini di parola: «denti» non deve trovare «accidenti».
- **File grande:** `chat_orchestrator.py` è lungo; molti metodi sono `@staticmethod` usati anche dai test e dagli strumenti di misura. Cerca i chiamanti prima di cambiare una firma.
- **Dose nel testo del modello:** se il proprietario **non** ha chiesto una quantità, `without_dose_sentences` toglie solo le frasi con la dose e il resto resta; il rifiuto fisso va solo a una richiesta vera (giro 3: il peso «85 g» di una calopsite sostituiva quattro risposte diverse). Il secondo rifiuto di fila usa `dosage_answer_again`.
- **Limite di chat per animale:** con un piano vale `plan.max_chats_per_pet` (Plus 2, Pro 4, Ultra 6); `MAX_ACTIVE_CONVERSATIONS_PER_PET` solo senza piano (sviluppatori).
- **Prove con il modello:** usa `--evidence in_memory`. Il `.env` locale può avere `EVIDENCE_BACKEND=scientific_multi`, che interroga banche dati esterne e non rappresenta la produzione.
