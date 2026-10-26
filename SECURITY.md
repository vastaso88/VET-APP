# Security Policy / Politica di sicurezza

**English summary.** VetApp is a pet-care app (Flutter client, FastAPI backend, Supabase).
If you find a security vulnerability, please **do not open a public GitHub issue**.
Report it privately via GitHub's *"Report a vulnerability"* button (Security tab →
Private vulnerability reporting) or by e-mail to the support address listed in
`packages/shared/config/settings.py` (`SUPPORT_CONTACT_EMAIL`) with the subject
`[SECURITY]`. We acknowledge reports within 3 working days and aim to fix
confirmed issues within 90 days (critical ones much sooner). Please give us
reasonable time before any public disclosure. Do not access, modify or delete
data that is not yours, do not run denial-of-service or brute-force tests, and
only test against your own accounts. Thank you.

---

## 1. Come segnalare una vulnerabilità

Questa è la politica di **divulgazione coordinata delle vulnerabilità** di VetApp
("coordinated vulnerability disclosure": chi scopre un problema lo comunica in
privato, noi lo correggiamo, poi si può parlarne pubblicamente). Il Cyber
Resilience Act europeo (Reg. UE 2024/2847) chiede a chi distribuisce software di
avere un canale di questo tipo: questo file lo è.

1. **Non aprire una issue pubblica** su GitHub: il repository è pubblico e
   l'informazione sarebbe visibile a tutti prima della correzione.
2. Usa uno di questi canali privati:
   - GitHub → scheda **Security** → **Report a vulnerability** (segnalazione
     privata; il proprietario deve attivarla una volta nelle impostazioni del
     repository, vedi `docs/security/README.md`);
   - e-mail all'indirizzo di supporto configurato in `SUPPORT_CONTACT_EMAIL`
     (vedi `packages/shared/config/settings.py`) con oggetto `[SECURITY]`.
3. Includi, se possibile: descrizione del problema, passi per riprodurlo,
   versione dell'app o commit, impatto stimato. Non allegare dati di altri utenti.

## 2. Cosa ci impegniamo a fare

| Fase | Tempo massimo |
| --- | --- |
| Conferma di ricezione | 3 giorni lavorativi |
| Prima valutazione (gravità, piano) | 10 giorni lavorativi |
| Correzione di una vulnerabilità **critica** (accesso a dati di altri utenti, esecuzione di codice) | il prima possibile, obiettivo 7 giorni |
| Correzione di una vulnerabilità **alta/media** | obiettivo 90 giorni |
| Pubblicazione di una nota di rilascio con il ringraziamento (se gradito) | alla correzione |

Se la vulnerabilità ha comportato una **violazione di dati personali** seguiamo
anche la procedura in `docs/security/03_procedura_violazioni.md` (notifica al
Garante entro 72 ore, GDPR art. 33).

## 3. Regole per chi testa (safe harbour)

Consideriamo in buona fede, e non perseguiamo, chi:
- testa solo con **account propri** e non accede a dati altrui; se un dato altrui
  compare per errore, interrompe il test e ce lo segnala senza conservarlo;
- non esegue attacchi di **negazione del servizio**, brute force, spam, phishing
  o ingegneria sociale verso utenti o soci;
- non modifica né cancella dati, non installa software sui nostri sistemi;
- ci lascia un tempo ragionevole per correggere prima di divulgare.

## 4. Versioni supportate

Supportiamo con correzioni di sicurezza **l'ultima versione pubblicata** dell'app
Android e l'ultima versione del backend distribuita (ramo `main`). Le versioni
precedenti vanno aggiornate.

## 5. Cosa NON è una vulnerabilità

- La chiave Supabase **publishable** (`sb_publishable_...`) e l'URL del progetto
  nel codice dell'app: sono pubblici per progetto, la protezione è nelle regole
  di accesso per riga (RLS) del database.
- Dati che un utente vede dei propri animali o dei propri annunci.
- Annunci del Mercatino ed eventi pubblici: sono pubblicati volontariamente.
- Mancanza di rate limiting su endpoint pubblici privi di effetti (es. `/health`).

Grazie a chi ci aiuta a proteggere gli utenti e i loro animali.
