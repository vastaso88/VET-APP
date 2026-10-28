# Registro dei rischi (sicurezza e protezione dati)

Ultimo aggiornamento: 2026-10-26. Da rileggere ogni 3 mesi e a ogni
funzione nuova (vedi `05_checklist.md`). Scala: Probabilità e Impatto da 1
(basso) a 3 (alto); Livello = P × I (1-2 basso, 3-4 medio, 6-9 alto).

Glossario: **rischio residuo** = quello che resta dopo le misure già prese;
**proprietario del rischio** = chi decide se accettarlo o ridurlo.

| ID | Rischio (cosa può succedere) | A chi nuoce | P | I | Livello | Misure in atto | Misure da prendere | Proprietario | Stato |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| R1 | Un utente legge o modifica dati di un altro tramite l'API (IDOR) | utenti (cartella clinica, chat) | 2 | 3 | 6 | Controlli di proprietà su pet/chat/promemoria + test (audit 2026-10-26); RLS lato app | Dependency di autenticazione a livello di router; test "utente B" per ogni rotta nuova (checklist B) | sviluppo | ridotto |
| R2 | Tabella o bucket leggibile senza login per una policy sbagliata | utenti | 2 | 3 | 6 | RLS su tutte le tabelle; controllo live con chiave pubblica; script di verifica | Eseguire `security_2026_10_26.sql` (revoca privilegi ad anon); correggere `marketplace_listings`; eseguire il check a ogni rilascio | proprietario + sviluppo | aperto fino all'esecuzione SQL |
| R3 | Chiave service_role o Groq esposta (commit, log, dispositivo) | tutti gli utenti | 1 | 3 | 3 | Nessun segreto nella storia; `.gitignore` esteso; segreti solo in env | GitHub secret scanning attivo; rotazione ogni 3 mesi; procedura violazioni | proprietario | accettato con misure |
| R4 | Account admin compromesso (phishing sulle e-mail note, password riusata) | tutti gli utenti (backoffice vede e-mail e posizioni) | 2 | 3 | 6 | Admin deciso lato server; e-mail verificata richiesta; token in cookie httpOnly | 2FA su Supabase/GitHub/Vercel/Google; `ADMIN_EMAILS` esplicito; ridurre i dati nel portale (`/admin/geographic`) | proprietario | aperto |
| R5 | Registrazione con l'e-mail di un'altra persona (conferma e-mail spenta) | terzi, utenti | 3 | 2 | 6 | Backend: allowlist solo con e-mail verificata | Attivare "Confirm email" su Supabase | proprietario | aperto |
| R6 | Dati personali verso Groq (USA) senza base giuridica solida; foto/audio in chiaro | utenti, veterinari citati nei referti | 3 | 2 | 6 | Anonimizzazione a regole su tutti i testi in uscita; mai e-mail/id/posizione nel prompt | DPA + SCC/DPF Groq, Zero Data Retention, TIA; informativa che cita Groq; valutare OCR/dettatura sul dispositivo | proprietario + legale | aperto |
| R7 | Un singolo utente o bot esaurisce il budget Groq e spegne la chat per tutti | tutti gli utenti (disponibilità) | 3 | 2 | 6 | Quota 20 msg/giorno; budget per modello; rate limit best-effort su dettatura/allegati | Quota per utente anche su visione/dettatura/riassunto; limite durata audio nell'app | sviluppo | ridotto |
| R8 | Telefono condiviso o rubato: dati dell'utente precedente visibili | utenti | 2 | 2 | 4 | Logout pulisce posizione, animali, passeggiata, widget, foto; "Resta connesso" onorato; backup Android disattivato | Spazzare i PDF temporanei al logout; blocco biometrico opzionale (futuro) | sviluppo | ridotto |
| R9 | APK di test debuggabile in giro con credenziali di produzione | tester | 2 | 2 | 4 | Runbook corretto; firma di release obbligatoria | Rimuovere l'artefatto debug dal workflow CI; distribuire solo release firmate | sviluppo | ridotto |
| R10 | Dipendenza con vulnerabilità nota in produzione (nessun lockfile, nessun audit) | tutti | 2 | 2 | 4 | Dependabot configurato | `uv lock` committato; `pip-audit`/`npm audit` in CI; aggiornare i pacchetti Flutter | gestore git | aperto |
| R11 | Risposta dell'assistente con farmaci/dosi o consigli pericolosi (prompt injection, insistenza) | animali e proprietari | 2 | 3 | 6 | Blocchi deterministici su emergenze e dosaggi nella domanda; badge IA; ToS | Validatore della risposta (farmaci/dosi); delimitazione del testo degli allegati; avviso "non è un veterinario" in chat (AI Act art. 50) | sessione Chat | aperto |
| R12 | Violazione di dati non notificata entro 72 ore (nessuno sa cosa fare) | utenti, titolare (sanzioni) | 2 | 3 | 6 | Procedura `03_procedura_violazioni.md` con registro | Esercitazione prima del lancio; contatti aggiornati fuori repo; legale individuato | proprietario | ridotto |
| R13 | Mancanza di DPIA, registro trattamenti, DPA con i fornitori al lancio | titolare (sanzioni), utenti | 3 | 2 | 6 | Inventario dati/fornitori; quadro normativo | DPIA (posizione + IA), registro art. 30, DPA archiviati, informativa definitiva | proprietario + legale | aperto |
| R14 | Utente minore (sotto l'età del consenso digitale, 13-16 a seconda del paese) | minori, titolare | 2 | 2 | 4 | Nessun controllo di età oggi | Soglia di età alla registrazione (decisione legale: 16 unica o per paese) | proprietario + legale | aperto |
| R15 | Posizione di casa inferibile dai percorsi GPS e condivisa con terzi (Nominatim, tile OSM) | utenti | 2 | 2 | 4 | Posizione annunci arrotondata a ~1 km; percorsi solo del proprietario | Dichiarare OSM/Nominatim nell'informativa o passare dal backend; arrotondare l'inizio/fine dei percorsi (futuro) | proprietario | aperto |
| R16 | Workflow CI che pusha su `main` contenuti scaricati da siti esterni | integrità del codice | 1 | 2 | 2 | Nessun input non fidato nei comandi | Push → PR con revisione; action pinnate a SHA; branch protection | sviluppo | aperto |
| R17 | Password dell'account demo nota pubblicamente (rami `roberto`, `MOTORE-ANAMNESI`) | quota Groq, dati demo | 3 | 1 | 3 | Mai su main; non è admin | Eliminare/reset dell'account; rimuovere env Vercel; cancellare i rami | proprietario | aperto |
| R18 | Diritto di accesso/portabilità (artt. 15 e 20) non esercitabile nell'app | utenti, titolare | 1 | 1 | 1 | `GET /account/export` (2026-10-28): JSON con tutte le tabelle della cancellazione + link firmati 15 min, 1 export/10 min, test di allineamento con l'eraser | Pulsante «Scarica i miei dati» in app (sessione UI/UX) | sviluppo | ridotto |
| R19 | Rapporti di crash (Sentry) che trasportano dati personali o partono senza consenso | utenti | 1 | 2 | 2 | Doppio cancello: build flag `CRASH_REPORTING` + DSN e consenso `diagnostics` opt-in; `scrubCrashEvent` toglie testo eccezione, utente, URL, breadcrumb, extra, tag, widget; organizzazione in regione EU; stop al logout | Crash nativi (Kotlin/NDK/ANR) non passano dal filtro Dart: disattivare `enableNativeCrashHandling` o accettarli documentandolo; evento di prova da ispezionare prima del rilascio (`10_crash_reporting.md` §Verifica) | sessione APK + proprietario (DPA) | ridotto |

Rischi **accettati** (motivazione): nessun TLS pinning nell'app (TLS di sistema
sufficiente, pinning complica le rotazioni); bucket `marketplace-photos`
pubblico (foto scelte dall'utente per un annuncio pubblico); nessuna cifratura
applicativa aggiuntiva a riposo oltre quella di Supabase/AWS (proporzionata
alla dimensione del progetto; da rivalutare se si aggiungono dati di salute
umana, che oggi non esistono).
