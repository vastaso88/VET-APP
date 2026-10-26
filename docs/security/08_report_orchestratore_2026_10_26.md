# Report all'Orchestratore: cybersicurezza e protezione dati (2026-10-26)

Sessione "Cybersicurezza e protezione dati". Lavoro nel worktree
`.claude/worktrees/security-audit-cdfeea` (ramo `claude/security-audit-cdfeea`),
**nessun commit** eseguito, nessuna credenziale usata, nessun test intrusivo:
solo letture con la chiave pubblica sul progetto Supabase.

## 1. In parole semplici: i 5 rischi più importanti e cosa è stato fatto

1. **Chiunque poteva leggere e riscrivere il profilo di un animale conoscendone
   l'id, senza nemmeno fare login** (due rotte del backend senza controllo).
   Un utente loggato poteva inoltre **entrare nella chat di un altro** e far
   leggere al modello la cartella clinica di un animale non suo. → **Corretto**
   nel codice, con test che lo impediscono per il futuro. Non risulta sia
   stato sfruttato (gli id sono casuali), ma era la falla più grave.
2. **La conferma dell'e-mail è spenta su Supabase**: oggi ci si può registrare
   con l'indirizzo di un'altra persona. Siccome "chi è admin" si decide
   dall'e-mail, era una porta verso il backoffice. → Il backend ora pretende
   un'e-mail verificata per admin e sviluppatori; **il proprietario deve
   attivare "Confirm email"** nella dashboard (2 minuti).
3. **Dati verso gli Stati Uniti (Groq) senza garanzie documentate.** Il testo
   dei messaggi è anonimizzato prima di partire, ma un passaggio (la ricerca
   di parole chiave per la letteratura) mandava il **messaggio grezzo**: →
   corretto. Restano foto di referti e audio in chiaro: serve il contratto
   (DPA) con Groq, l'opzione "Zero Data Retention" e una valutazione del
   trasferimento. È la decisione di conformità più importante prima del
   lancio.
4. **Il telefono conservava troppo**: backup su Google Drive di sessione e
   indirizzo di casa, "Resta connesso" ignorato, dati del vecchio utente
   (casa, animali, passeggiata) visibili al successivo. → Tutto corretto. Gli
   APK **debug** distribuiti ai tester (leggibili da chiunque abbia il
   telefono) sono vietati dal runbook; resta da togliere l'artefatto debug dal
   workflow CI.
5. **Nessun freno agli abusi e nessun piano per gli incidenti**: un solo
   account poteva spegnere la chat per tutti consumando il budget Groq; non
   esisteva una procedura per le violazioni di dati (72 ore) né una politica
   di segnalazione delle vulnerabilità. → Limiti best-effort sulle rotte
   costose, `SECURITY.md`, procedura violazioni con registro, registro rischi,
   checklist, inventario fornitori, quadro normativo.

Il quadro normativo (`01_quadro_normativo.md`) conclude: GDPR pienamente
applicabile con **DPIA necessaria** (posizione GPS + IA); AI Act art. 50
(avviso "stai parlando con un'IA") **già in vigore dal 2 agosto 2026** e
l'avviso manca nella schermata chat; Cyber Resilience Act **probabilmente**
applicabile all'app pubblicata (obbligo di segnalazione vulnerabilità dall'11
settembre 2026: `SECURITY.md` lo copre); NIS2 non applicabile; Google Play
richiede target API 36, Data safety, cancellazione account.

## 2. Correzioni fatte (nel worktree, da committare dal gestore git)

Tutte verificate: `pytest` 1721 verdi (16 test di sicurezza nuovi), `ruff` e
`mypy` puliti (mypy ha 3 errori preesistenti nel file Presidio opzionale, non
toccato), `flutter analyze` pulito, `flutter test` 1229 verdi, `check_i18n` ok.
Elenco completo con file in `02_audit.md` §7. Sintesi:

- Backend: proprietà su `GET/PUT /pets/{id}`, `POST /chat`, `POST /reminders`;
  guardia "produzione richiede Supabase"; e-mail verificata per admin/dev;
  messaggi d'errore generici con `error_id`; header di sicurezza, CORS da
  allowlist in produzione, docs spenti in produzione; rate limit best-effort;
  limite 4 MB e sanificazione per la dettatura; lunghezze massime sugli input;
  segreto scheduler dedicato; pseudonimo del segnalante non più esposto
  all'admin; e-mail personale tolta dai default; anonimizzazione anche sulla
  query di ricerca letteratura.
- App: backup Android disattivato; logout completo; "Resta connesso" onorato;
  release non firmabile per sbaglio con la chiave di debug; header di sicurezza
  sul web; `ENVIRONMENT=production` nelle build CI; nome della chiave
  service_role rimosso dal client; runbook APK debug corretto.
- Repo/CI: Dependabot; `lint-and-test.yml` a sola lettura; `.gitignore` esteso
  a keystore/key.properties/google-services/dart-defines; e-mail reali tolte
  da un test; script di hardening del 2026-10-02 riportato su questo ramo.
- Sezione permanente `docs/security/` (10 file) + `SECURITY.md` in radice +
  `scripts/security/check_anon_exposure.py`.

**Attenzione al deploy.** Prima del merge su `main` verificare su Vercel:
`ENVIRONMENT=production`, `AUTH_BACKEND=supabase`, `PERSISTENCE_BACKEND=supabase`
(altrimenti il backend ora **rifiuta di partire**, è voluto), e aggiungere
`SUPPORT_CONTACT_EMAIL` (prima aveva un default), `CORS_ALLOWED_ORIGINS` se la
web app chiama l'API da un'altra origine, `ADMIN_SCHEDULER_SECRET` (opzionale,
stesso valore nel secret GitHub). Una build Android `--release` senza chiave
ora fallisce: `-PallowDebugSigning=true` solo per prove locali.

## 3. SQL da eseguire (SQL Editor Supabase, progetto ywbuzgwbkrmkukkpysbz), in ordine

1. `scripts/setup/supabase_schema.sql` (aggiornato: in produzione manca la
   tabella `radar_country_coverage`).
2. `scripts/setup/security_2026_10_26.sql` (nuovo): toglie i privilegi al
   ruolo anonimo su tutte le tabelle con dati personali e al ruolo
   "authenticated" sulle tabelle solo-backend, cambia i privilegi di default
   per le tabelle future, chiude e limita i bucket. In fondo al file ci sono le
   query di verifica (devono restituire 0 righe).
3. Dopo: `uv run python scripts/security/check_anon_exposure.py` con
   `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` → deve segnalare solo
   `marketplace_listings` finché la sessione UI/UX non ha corretto la policy.

## 4. Azioni per il proprietario (non automatizzabili)

| Priorità | Azione | Dove |
| --- | --- | --- |
| Subito | Attivare **Confirm email** | Supabase → Authentication → Providers → Email |
| Subito | **Eliminare o resettare** l'account demo `demo-founder-01@…` la cui password è nel codice dei rami `roberto` e `MOTORE-ANAMNESI`; rimuovere le env `DEMO_FOUNDER_*` su Vercel; cancellare quei rami dopo aver integrato il necessario | Supabase → Users; Vercel; GitHub |
| Subito | **2FA** su tutti gli account: Supabase, Vercel, GitHub, Google (Play/Firebase), Groq | ogni servizio |
| Subito | `ADMIN_EMAILS` esplicito su Vercel (non il fallback sugli sviluppatori); `SUPPORT_CONTACT_EMAIL`; `ADMIN_SCHEDULER_SECRET` | Vercel → Environment Variables (+ GitHub secret) |
| Settimana | Attivare su GitHub: Private vulnerability reporting, Secret scanning + Push protection, Dependabot alerts, branch protection su `main` | GitHub → Settings → Code security |
| Settimana | Committare `uv.lock` (`uv lock`, togliere la riga da `.gitignore`) e `package-lock.json` del portale admin | gestore git |
| Prima del lancio | **DPA con Groq** + attivare Zero Data Retention; archiviare i DPA di Supabase, Vercel, Google; verificare la certificazione DPF nella lista ufficiale; scrivere la TIA | contratti, cartella privata |
| Prima del lancio | **DPIA** (posizione GPS + chat IA), **registro dei trattamenti** (art. 30), informativa definitiva che nomina i fornitori, soglia di età alla registrazione | con il legale |
| Prima del lancio | Esercitazione della procedura violazioni (`03_procedura_violazioni.md`) e contatti aggiornati fuori repo | proprietario |
| Ogni 3 mesi | Rotazione chiavi (service_role, Groq, Firebase SA), revisione accessi, `05_checklist.md` sezione C | proprietario |

Rotazione chiavi: dalla scansione di tutta la storia git (403 commit, 34 rami)
**nessuna chiave riservata** (Supabase secret/service_role, Groq, Firebase,
Google, keystore) è mai stata committata. L'unica credenziale esposta è la
password dell'account demo: va eliminata/resettata, la storia pubblica non si
riscrive.

## 5. Lavoro per le altre sessioni (da dispacciare)

- **UI/UX e funzionalità base**: policy `marketplace_listings` solo per utenti
  loggati e `owner_id` fuori dalla risposta API (DB-1, BE-16); avviso "stai
  parlando con un assistente automatico, non con un veterinario" nella
  schermata chat (AI Act art. 50, LLM-8); testo di spiegazione prima dei
  permessi posizione/microfono.
- **Chat LLM interna**: validatore della risposta contro farmaci/dosi (LLM-5);
  delimitare il testo degli allegati nel prompt (LLM-6); quota per utente su
  visione/dettatura/riassunto (BE-4/LLM-4); retention conversazioni e file.
- **Backend**: rotta di esportazione dati `GET /account/export` (BE-12);
  `REPORTER_PSEUDONYM_SALT` dedicato (BE-19); `legislative-watch` da push
  diretto a PR (REPO-3); action pinnate a SHA.
- **Mappe / radar**: geocodifica Nominatim dal backend o informativa (APP-6);
  proxy per `CARTO_API_KEY` se si attiva (APP-9).
- **Portale admin (Roberto)**: `/admin/geographic` senza e-mail e con
  coordinate arrotondate (BE-8); header di sicurezza in `next.config.ts`;
  logout che revoca il token (ADMIN-2).
- **Gestore git**: commit di questo worktree (37 file modificati, 15 nuovi) su
  `Francesco` → `main`; `uv.lock`; rimuovere l'artefatto `app-prod-debug.apk`
  da `ci.yml` o renderlo release firmata (APP-1).
- **Orchestratore**: incollare in `CLAUDE.md` il testo di
  `07_proposta_claude_md.md`.

## 6. Cosa deve verificare un legale

Elenco completo (15 punti) in `01_quadro_normativo.md` §4. I principali:
1. DPIA obbligatoria per GPS + IA: conferma e redazione.
2. Base giuridica di ogni trattamento (contratto vs consenso), in particolare
   posizione, cartella clinica in chat, marketing.
3. Trasferimenti USA: DPF (Google, Vercel) vs SCC + TIA (Supabase, Groq);
   validità del DPF dopo il ricorso pendente alla Corte di giustizia.
4. Se il Cyber Resilience Act si applica all'app (gratuita in test chiuso vs
   pubblicata con piani a pagamento) e da quando.
5. Età minima unica (16) o per paese (IT 14, FR 15, BE 13…) e come verificarla.
6. Rappresentante UK (art. 27 UK GDPR) e tassa ICO al lancio UK; Svizzera.
7. Marketplace tra utenti: obblighi DSA e responsabilità per i contenuti.
8. Testi: informativa, ToS, consenso cartella clinica, comunicazione di
   violazione agli utenti (bozze in `docs/compliance/` e in
   `03_procedura_violazioni.md` appendice B).
9. Conservazione: quanto tenere conversazioni, file, log, consensi dopo la
   cancellazione dell'account.
10. Chi è il titolare oggi (persona fisica) e cosa cambia con la società.
