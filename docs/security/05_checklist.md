# Checklist di sicurezza

Ultimo aggiornamento: 2026-10-26. Due liste: una da passare **prima di ogni
rilascio** (build Android o deploy del backend), una da passare **quando si
aggiunge una funzione che tratta dati personali**. Chi fa il rilascio (oggi
l'Orchestratore progetto con la sessione gestore git) spunta le voci nel
messaggio di rilascio o nel PR.

## A. Prima di ogni rilascio

### Codice e test
- [ ] `uv run pytest` verde, compresi i test di sicurezza in
      `tests/unit/test_security_*.py` (rotte protette, cancellazione account,
      esposizione RLS attesa).
- [ ] `uv run ruff check .`, `uv run mypy apps packages tests`,
      `flutter analyze`, `flutter test`, `python scripts/i18n/check_i18n.py`
      (o il comando equivalente documentato) senza errori.
- [ ] Nessun `print`/log con e-mail, token, testo dei messaggi, coordinate
      (grep `print(` nei file toccati; nel client nessun `print` fuori da
      `kDebugMode`).
- [ ] Nessuna nuova rotta senza dipendenza di autenticazione; ogni rotta con un
      id in path/body verifica che l'oggetto appartenga all'utente (vedi tabella
      rotte in `02_audit.md`).

### Segreti e configurazione
- [ ] `git diff --cached` non contiene chiavi (`sb_secret_`, `service_role`,
      `gsk_`, `AIza`, `-----BEGIN`, `storePassword`), file `.env*`,
      `*.jks`, `key.properties`, `google-services.json`.
- [ ] Le variabili d'ambiente nuove sono documentate in `.env.example` e
      impostate su Vercel **prima** del deploy (altrimenti il backend va in
      crash all'avvio: vedi incidente ADMIN_EMAILS del 2026-10-06).
- [ ] `ENVIRONMENT=production` su Vercel, `LLM_PROVIDER` e chiavi corrette,
      `PII_ANONYMIZER_BACKEND` nel valore previsto.

### Database (Supabase)
- [ ] Ogni tabella nuova in `scripts/setup/*.sql` ha `enable row level
      security` e policy `*_own` oppure un commento che spiega perché è
      pubblica o solo backend.
- [ ] Gli script SQL nuovi sono idempotenti (`if not exists`, `drop policy if
      exists`) e sono stati **eseguiti sul progetto** (annotare data nel PR).
- [ ] Controllo passivo di esposizione eseguito con la sola chiave publishable
      (vedi `scripts/security/check_anon_exposure.py`): nessuna tabella con dati
      personali restituisce righe senza login.
- [ ] Nessuna funzione `security definer` nuova senza `set search_path` e
      `revoke ... from public, anon, authenticated`.

### App Android / web
- [ ] Build di release con `isMinifyEnabled = true`, `isShrinkResources = true`,
      firma con keystore di release (mai debug), `android:debuggable` assente.
- [ ] Nessun permesso Android nuovo senza motivazione scritta in
      `docs/compliance/05_permessi_dispositivo_os.md`.
- [ ] `CRASH_REPORTING=true` **solo** con `SENTRY_DSN` di un'organizzazione in
      regione **EU** e con il **DPA Sentry firmato** e archiviato; altrimenti la
      build va fatta senza il flag (il servizio resta spento). Mai il DSN nel
      repository o nelle note di rilascio.
- [ ] `flutter pub outdated` e `uv run pip-audit` (o equivalente) controllati;
      nessuna dipendenza con vulnerabilità nota non giustificata.
- [ ] La versione in `pubspec.yaml` è aumentata; le note di rilascio
      menzionano le correzioni di sicurezza (senza dettagli sfruttabili finché
      gli utenti non hanno aggiornato).

### Dopo il deploy
- [ ] Smoke test su produzione **con un account di test**, mai con account o
      dati reali: login, lettura di un animale, una domanda in chat, logout.
- [ ] Log Vercel e Supabase dei primi minuti senza errori 500 ripetuti.

## B. Quando si aggiunge una funzione che tratta dati personali

Esempi: nuovo campo nel profilo, nuova tabella, nuova integrazione esterna,
nuovo permesso del telefono, nuovo uso della chat.

### Prima di scrivere codice
- [ ] **Serve davvero quel dato?** (minimizzazione, GDPR art. 5.1.c). Se sì,
      scrivere in una riga la finalità e la base giuridica (contratto, consenso,
      legittimo interesse, obbligo di legge).
- [ ] Il dato è "sensibile" per gli utenti (posizione, testo libero, documenti
      di terzi, minori)? Se sì, segnalarlo nel PR e valutare se la DPIA
      (`01_quadro_normativo.md`) va aggiornata.
- [ ] Esce verso un **fornitore nuovo** o verso un paese extra-UE? Aggiungere la
      riga in `06_inventario_dati_fornitori.md` e verificare DPA/trasferimento
      **prima** del rilascio.
- [ ] È richiesto un **consenso** (cartella clinica in chat, marketing,
      analytics, posizione in background)? Usare il sistema di consensi
      versionati esistente (`account_consents`), non flag nuovi.

### Durante
- [ ] Tabella con RLS e policy per proprietario; test unitario che un altro
      utente riceve 404/403.
- [ ] Rotta backend con dipendenza di autenticazione e controllo di proprietà
      nel servizio (non solo nel client).
- [ ] Validazione input (lunghezze massime, tipi di file, dimensione), niente
      HTML grezzo renderizzato dal testo utente.
- [ ] Il dato è coperto dalla **cancellazione account** (test
      `test_account_deletion_*` che enumera le tabelle: aggiungere la tabella
      all'elenco o dichiararla non personale) e dall'**export** dei dati
      dell'utente, se esiste.
- [ ] Il dato è coperto dal **logout** sul dispositivo (cache, preferenze,
      bozze cancellate).
- [ ] Non finisce nei log né nel prompt inviato a Groq, salvo necessità
      documentata nella tabella "Dati inviati a Groq" di `02_audit.md`.

### Prima del rilascio
- [ ] Aggiornata l'informativa privacy (bozza in `docs/compliance/`) e, se
      serve, la sezione Data safety di Google Play.
- [ ] Aggiornato `04_registro_rischi.md` se cambia un rischio.
- [ ] Checklist A completata.

## C. Ogni 3 mesi (manutenzione)

- [ ] Rotazione delle chiavi di servizio (Supabase secret, Groq, Firebase
      service account) o almeno verifica che non siano cambiate le persone che
      le conoscono.
- [ ] Revisione degli accessi: chi ha accesso a Supabase, Vercel, GitHub,
      Google Play, Firebase; 2FA attiva per tutti.
- [ ] `pip-audit` / `flutter pub outdated` / Dependabot: aggiornare.
- [ ] Rileggere `04_registro_rischi.md` e `docs/compliance/legislative-watch/`.
- [ ] Pulizia dati scaduti: `chat_usage_cleanup()`, segnalazioni radar
      scadute, cache risposte.
