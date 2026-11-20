# Groq: contratto sui dati, conservazione e modelli in anteprima

Data: 2026-11-16. Verifica sulle pagine ufficiali di Groq (nessun accesso con credenziali, niente accettato): un primo giro con un agente di ricerca, poi **riletti a mano sul testo originale** i punti che cambiano una conclusione (§3.6 e §6 del contratto, elenco dei modelli). Non è consulenza legale: i punti ⚖️ vanno confermati da un legale. Serve a chiudere i segnaposto `[GARANZIE_GROQ]` e «giorni di conservazione» di it/02 e a dire all'Orchestratore che cosa non regge. Gemello del [14](14_anthropic_contratto_conservazione_e_regole_d_uso.md) per Anthropic.

## 1. Fatti verificati

| Tema | Che cosa dice Groq | Fonte (pagina ufficiale) | Data della pagina |
|---|---|---|---|
| Contratto sui dati (DPA) | Fa parte del contratto: si accetta con i termini online, nessuna firma. Comprende le clausole contrattuali standard (moduli 2 e 3), l'addendum del Regno Unito e gli adattamenti svizzeri. Per i clienti SEE e svizzeri chi riceve i dati è Groq UK Limited | console.groq.com/docs/legal/customer-data-processing-addendum | in vigore dal 15 ottobre 2025 |
| Data Privacy Framework | **Groq non è nell'elenco** (cercata tra attive e non attive il 16 novembre 2026). Le garanzie sono le clausole standard | dataprivacyframework.gov/list | elenco senza data |
| Conservazione | Di norma non conserva le richieste; le registra per un tempo limitato (fino a 30 giorni) solo per risolvere problemi di funzionamento o sospetti abusi. L'opzione di **conservazione zero** si attiva nella console (Data Controls) e disattiva quella registrazione, la modalità batch e il fine-tuning | console.groq.com/docs/your-data; contratto §4.2 | senza data |
| Addestramento | Non può usare le richieste e le risposte per addestrare modelli senza permesso esplicito | contratto §4.2 | 22 giugno 2026 |
| Dove | Dati conservati in archivi cloud negli Stati Uniti; il contratto ammette il trattamento negli Stati Uniti e in altri paesi; centri dati in Stati Uniti, Australia, Canada, Finlandia, Arabia Saudita; nessuna scelta «solo UE» in autonomia | contratto, DPA §8.1, trust.groq.com/faq | 2025–2026 |
| Fornitori di Groq | Elenco pubblico (18 voci, tra cui Google Cloud, Cloudflare, Stripe); preavviso di 15 giorni agli iscritti | trust.groq.com/subprocessors | aggiornato il 26 novembre 2025 |
| Età | «Devi avere 18 anni» vale per chi accede ai servizi (nostra squadra), non agli utenti della nostra app. Per le app che possono essere usate da minori risponde il cliente della legge applicabile: **non c'è un divieto, come per Anthropic** | contratto §2 e §6 | 22 giugno 2026 |
| Obblighi del cliente | Avere i consensi e dare le informative per il trattamento fatto da Groq (§6.2): **l'informativa deve nominare Groq** | contratto §6.2 | 22 giugno 2026 |

## 2. Il punto che non regge: i modelli in anteprima

Il contratto (§3.6) chiama «Beta Services» tutto ciò che è designato anteprima, e dice che il contratto sui dati **non vale** per i Beta Services, salvo diversa indicazione espressa nella documentazione. La pagina dei modelli (letta il 16 novembre 2026) divide in **produzione** (llama-3.1-8b-instant, llama-3.3-70b-versatile, openai/gpt-oss-120b, openai/gpt-oss-20b, whisper-large-v3, whisper-large-v3-turbo) e **anteprima** («solo per valutazione, da non usare in produzione», tra cui `qwen/qwen3.8-27b`, **l'unico che accetta immagini**, e `openai/gpt-oss-safeguard-20b`).

Nel codice (`packages/shared/config/settings.py`, valori predefiniti; in produzione le variabili d'ambiente possono dire altro, da controllare):
- **Analisi delle immagini**: `VISION_MODEL = qwen/qwen3.8-27b`, nessun modello di riserva. Sono le foto di libretti e referti, che possono contenere nome e indirizzo del proprietario.
- **Catena di riserva della chat**: `LLM_FALLBACK_MODELS = openai/gpt-oss-20b, qwen/qwen3.8-27b`, e `LLM_LIGHT_FALLBACK_MODELS = qwen/qwen3.8-27b`.
- Trascrizione: `whisper-large-v3-turbo` (produzione): a posto. `gpt-oss-safeguard-20b` compare solo nella tabella dei limiti giornalieri.

**Conseguenza.** Le immagini, e la chat quando ripiega su `qwen3.8`, passano da un servizio che il contratto sui dati e le clausole standard non coprono: mancano l'art. 28 (contratto con chi tratta dati per noi) e le garanzie dell'art. 46 per quel trattamento, e l'informativa non può dire che ci sono. È un buco per T1 (dati di persone reali), non solo per il lancio; per la regola del proprietario («dubbio legale: non si implementa, si lascia un'opzione») la strada giusta è togliere ciò che non è coperto.

## 3. Che cosa fare

**Subito, solo configurazione (Orchestratore e Chat):**
1. Togliere `qwen/qwen3.8-27b` dalle due catene di riserva della chat (variabili `LLM_FALLBACK_MODELS` e `LLM_LIGHT_FALLBACK_MODELS` su Vercel, e i valori predefiniti nel codice): restano `openai/gpt-oss-20b` e gli altri modelli in produzione (per esempio `openai/gpt-oss-120b`, `llama-3.3-70b-versatile`).
2. **Immagini** (decisione dell'Orchestratore del 16 novembre: (c) subito, (a) per la build 41; la Chat prepara una modalità «analisi foto spenta» onesta e poi l'Orchestratore cambia le variabili su Vercel). Le strade erano: (a) mandarle ad Anthropic (le versioni attuali leggono le immagini): serve un client per la vista, e l'informativa e il riepilogo del consenso cambiano («Anthropic non riceve immagini né audio» diventa falso per le immagini); (b) chiedere a Groq per iscritto che il contratto sui dati copra quel modello («salvo indicazione espressa nella documentazione»): esito incerto e lento, non da aspettare; (c) **spegnere l'analisi delle immagini** nella build di test finché non c'è (a) o (b). Nella build 41 le immagini vanno ad Anthropic: il riepilogo v4, la riga di Anthropic in it/02 («non riceve immagini né audio») e l'avviso T-B ([15](15_consensi_per_attivita.md)) devono dire che riceve anche le foto. **Fatto in produzione il 16 novembre (main 0f48b65 e c7202a3):** elenco dei modelli in produzione, catene di riserva e vista filtrate all'avvio (anche se `qwen3.8` resta nelle variabili di Vercel), foto salvata senza analisi, frase fissa onesta nella chat; verificato nel codice prima di togliere i marcatori da it/02.

**Azioni del proprietario** (le chiede l'Orchestratore):
- Attivare la **conservazione zero** di Groq nella console (Data Controls): dopo, l'informativa può dire che Groq non conserva le richieste. Le condizioni dicono «clienti idonei»: se l'opzione non compare, scrivere a Groq.
- Archiviare con data una copia del contratto sui dati e dei termini (come per Anthropic, punto 54 del registro).

## 4. Testi

- **it/02 §4 (riga Groq), §5 e §7:** scritti con le garanzie vere (clausole standard, niente Data Privacy Framework, paesi), con il marcatore `[da verificare: l'analisi delle immagini usa un modello in anteprima non coperto dal contratto sui dati]` finché la scelta del punto 3 non è fatta. La riga sulla conservazione dice «fino a 30 giorni, solo per problemi o abusi» e va cambiata in «non conserva» solo dopo che il proprietario ha attivato la conservazione zero.
- Il [14](14_anthropic_contratto_conservazione_e_regole_d_uso.md) §4 e il documento 06 della sicurezza (`docs/security/06_inventario_dati_fornitori.md`, riga di Groq) vanno allineati dalla Sicurezza: contratto sui dati (clausole standard, moduli 2 e 3), nessun DPF, conservazione, **modelli in produzione soltanto**.
- **Frase fissa della chat con le foto spente** (`photo_reading_off`, richiesta della Chat, approvata il 16 novembre con due ritocchi): «Per ora non posso vedere il contenuto delle foto: restano salvate qui e nessun servizio esterno le legge. Descrivimi a parole cosa vedi; se è un libretto o un referto, scrivimi i valori o le voci che ti interessano e te li spiego.» «I valori o le voci» al posto di «i dati o i valori»: non invita a scrivere dati personali. La rassicurazione serve perché l'avviso precedente diceva che le foto andavano a un servizio esterno. Vale solo finché le foto sono spente: con la build 41 la chiave sparisce.
- **Consenso alla cartella clinica (v5):** nessun cambio. «Testo dei documenti allegati» resta vero dove c'è un testo (PDF con testo, documenti già letti); cambiare il testo vorrebbe dire nuova versione e nuovo consenso di tutti, per poi tornare com'era con la build 41.

## 5. Punti ⚖️

1. Se i modelli in anteprima sono davvero fuori dal contratto sui dati senza una conferma scritta di Groq (la clausola dice «salvo indicazione espressa nella documentazione»).
2. Il trattamento in paesi senza decisione di adeguatezza (Arabia Saudita, Australia) con le sole clausole standard e l'importatore nel Regno Unito: valutazione del trasferimento (punto 45 del registro).
3. «Non usare per consulenza medica o professionale» (§4.3): il testo dei Termini e gli avvisi dell'app dicono già che l'assistente non è un veterinario.
