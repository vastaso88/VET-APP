# Proposta di testo per il `CLAUDE.md` del progetto

Da aggiungere al `CLAUDE.md` di radice (lo fa l'Orchestratore, non questa
sessione), così che ogni sessione di sviluppo rispetti le stesse regole di
sicurezza. Testo proposto, pronto da incollare:

```markdown
## Sicurezza e protezione dati (vale per tutte le sessioni)
Riferimento: `docs/security/` (audit, checklist, registro rischi, procedura violazioni).

- Il backend parla con Supabase con la chiave service_role: le policy RLS NON lo
  proteggono. Ogni rotta chiama `get_current_user()` e ogni servizio che riceve
  un id (pet, conversazione, allegato, promemoria, annuncio) confronta `owner_id`
  con l'utente del token e risponde "not found" se non coincide. Test "utente B"
  obbligatorio per ogni rotta nuova (`tests/unit/test_security_ownership.py` come
  modello).
- Tabella nuova = `enable row level security` + policy `*_own` nello stesso
  script SQL (idempotente) + riga nel test della cancellazione account
  (`supabase_account_eraser`) + riga in `docs/security/06_inventario_dati_fornitori.md`.
  Tabelle pubbliche per scelta vanno commentate come tali e aggiunte
  all'allowlist di `scripts/security/check_anon_exposure.py`.
- Tutto ciò che esce verso Groq o altri provider passa da `_anonymize_for_provider`
  (o dall'anonimizzatore) prima dell'invio; mai e-mail, id utente, telefono,
  posizione, microchip nel prompt. Nuovo fornitore o nuovo paese = riga
  nell'inventario fornitori prima del rilascio.
- Niente segreti nel codice, nei test, nei log, nelle note di rilascio: solo
  variabili d'ambiente (`.env.example` documenta il nome). Niente dati personali
  reali (e-mail, nomi, indirizzi) nel repository, nemmeno nei test: usare
  `example.com`. Il repository è pubblico.
- Log senza dati personali (niente testo dei messaggi, e-mail, coordinate,
  token); eccezioni dei provider mai restituite al client (handler in `main.py`).
- Input dell'utente sempre limitato (`Field(max_length=...)`, dimensione file,
  tipo dalla firma del file) e mai renderizzato come HTML.
- App: nulla di sensibile fuori dallo storage privato dell'app; ogni store
  locale nuovo va svuotato nell'handler `signedOut` di `bootstrap.dart`; nessun
  permesso Android nuovo senza motivazione in `docs/compliance/05_permessi_dispositivo_os.md`;
  ai tester solo build `--release` firmate.
- Mai credenziali o account reali per i test, mai test attivi contro la
  produzione: controlli passivi con la sola chiave publishable, account di test
  sintetici in locale (`SUPABASE_URL` vuoto).
- Prima di ogni rilascio: `docs/security/05_checklist.md` sezione A; per ogni
  funzione che tratta dati personali: sezione B.
- Vulnerabilità scoperta o sospetta violazione di dati: seguire subito
  `docs/security/03_procedura_violazioni.md` (72 ore) e avvisare l'Orchestratore.
```

Nota per l'Orchestratore: il blocco è volutamente breve (il `CLAUDE.md` viene
letto a ogni sessione); i dettagli restano in `docs/security/`.
