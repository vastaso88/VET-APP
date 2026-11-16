# Procedura di gestione delle violazioni di dati personali (data breach)

Ultimo aggiornamento: 2026-10-26. Base giuridica: GDPR artt. 33 e 34, Linee guida
EDPB 9/2022 sulla notifica delle violazioni. Non è consulenza legale.

## 0. Glossario in due righe

- **Violazione di dati personali** (data breach): qualunque evento, anche
  accidentale, che porta a **perdita, distruzione, alterazione, divulgazione o
  accesso non autorizzato** a dati personali. Esempi per VetApp: una tabella
  leggibile senza login, una chiave di servizio pubblicata su GitHub, un telefono
  di un socio rubato con la sessione admin aperta, un bug che mostra la cartella
  clinica di un altro utente, un fornitore (Supabase, Vercel, Groq) che ci
  comunica un incidente, un backup perso.
- **Titolare**: chi decide perché e come si trattano i dati. Oggi è il
  proprietario di VetApp come persona fisica; domani la società.
- **Garante**: l'Autorità italiana per la protezione dei dati personali
  (garanteprivacy.it). Per utenti UK → ICO; CH → IFPDT; AU → OAIC; altri paesi UE →
  l'autorità locale (elenco in `01_quadro_normativo.md`).
- **72 ore**: tempo massimo per notificare al Garante dal momento in cui il
  titolare **viene a conoscenza** della violazione, salvo che sia improbabile
  che la violazione presenti un rischio per le persone. L'orologio parte quando
  si ha una ragionevole certezza che qualcosa è successo, non quando si capisce
  tutto.

## 1. Chi fa cosa

| Ruolo | Chi | Compiti |
| --- | --- | --- |
| **Responsabile incidente** (incident lead) | il proprietario (titolare); in sua assenza il socio delegato | decide, tiene il registro, firma la notifica |
| **Tecnico** | chi gestisce backend/Supabase (oggi l'Orchestratore progetto con le sessioni di sviluppo) | contiene, indaga, raccoglie prove, corregge |
| **Comunicazione** | il proprietario | contatta Garante, utenti, fornitori, eventuale legale |
| **Legale** | consulente esterno (da individuare prima del lancio) | valuta rischio, rivede testi di notifica |

Nomi e recapiti aggiornati vanno tenuti **fuori dal repository** (file privato
del titolare): il repository è pubblico.

## 2. Linea del tempo (cosa fare entro quando)

### Ora 0 → 1: rilevare e contenere
1. Annotare **data e ora** in cui si è saputo (è il T0 delle 72 ore) e come
   (segnalazione esterna, allarme, scoperta interna).
2. **Contenere** senza distruggere le prove:
   - chiave esposta → **ruotare** subito (Supabase: Settings → API → rigenera
     la secret key / service_role e, se compromesso, il JWT secret; console
     Groq; Vercel env; GitHub secrets); aggiornare le variabili su Vercel;
     ridistribuire;
   - tabella/bucket aperto → applicare la policy RLS corretta o revocare il
     grant ad `anon`/`authenticated` (vedi `scripts/setup/security_*.sql`);
   - account compromesso → Supabase Auth → revoca sessioni dell'utente,
     reset password; per account admin anche su Vercel/GitHub/Google;
   - bug applicativo → disattivare la funzione (feature flag, rollback su Vercel
     "Instant Rollback") prima di correggere.
3. **Conservare le prove**: esportare i log Supabase (Logs → API/Auth/Postgres)
   e Vercel (Runtime Logs) del periodo; salvare in un posto privato, non nel repo.

### Ora 1 → 24: valutare
4. Compilare la scheda nel **registro violazioni** (sezione 4) con: cosa, quando,
   quali dati, quanti utenti, quali paesi, causa probabile.
5. Valutare il **rischio per le persone** (EDPB 9/2022): tipo di dati
   (credenziali, posizione/percorsi GPS, conversazioni, cartella clinica,
   e-mail), volume, facilità di identificare le persone, gravità delle
   conseguenze (furto di identità, stalking tramite posizione, discriminazione),
   caratteristiche degli utenti.
   - **Nessun rischio probabile** → solo registro interno, niente notifica
     (es. e-mail inviata a destinatario sbagliato ma recuperata, dati cifrati con
     chiave non compromessa).
   - **Rischio** → notifica al Garante entro 72 ore.
   - **Rischio elevato** → notifica al Garante **e** comunicazione agli utenti
     interessati senza ingiustificato ritardo (art. 34).
6. Chiedere al legale di confermare la valutazione, se raggiungibile; non
   aspettare oltre le 48 ore per decidere.

### Ora 24 → 72: notificare
7. **Garante (Italia)**: procedura telematica dedicata
   <https://servizi.gpdp.it/databreach/> (modulo online con autovalutazione;
   verificare sulla pagina le modalità aggiornate). Contenuto minimo (art. 33
   par. 3): natura della violazione, categorie e numero approssimativo di
   interessati e di record, nome e recapito del punto di contatto, conseguenze
   probabili, misure adottate o proposte. Se non si ha tutto, **notificare in
   fasi** (notifica preliminare + integrazioni).
8. Altri paesi, se ci sono utenti interessati: UK → ICO (online, 72 ore);
   CH → IFPDT (portale databreach.edoeb.admin.ch, "al più presto"); AU → OAIC
   (schema NDB: valutazione entro 30 giorni, poi notifica); IE → DPC; ES → AEPD;
   DE → autorità del Land; FR → CNIL; BE → APD; AT → DSB. Per gli USA: leggi
   statali di breach notification se esposte **credenziali** (e-mail + password)
   o altri dati elencati; valutare con legale. Dettagli in
   `01_quadro_normativo.md`.
9. **Fornitori**: se l'incidente coinvolge un fornitore, aprire un ticket
   (Supabase support, Vercel support, Groq) e chiedere conferma scritta del
   perimetro. Se l'incidente parte da noi ma tocca i loro sistemi, avvisarli.

### Comunicazione agli utenti (quando il rischio è elevato)
10. Testo **semplice**, in-app o via e-mail: cosa è successo, quali dati, cosa
    stiamo facendo, cosa può fare l'utente (cambiare password, revocare
    sessioni, attenzione a e-mail sospette), un contatto. Mai minimizzare, mai
    dare colpe a terzi senza certezze. Bozza in appendice B.

### Dopo
11. Causa radice e correzione definitiva con test di non regressione; aggiornare
    `04_registro_rischi.md` e, se serve, le checklist in `05_checklist.md`.
12. Chiudere la scheda nel registro con data di chiusura e lezioni apprese.

## 2 bis. Ripristino del database da backup (registro delle cancellazioni)

Un ripristino riporta il database indietro nel tempo: un account cancellato DOPO
quel backup ricompare, con i suoi dati. Cancellarlo di nuovo non è facoltativo
(art. 17 GDPR): il registro `account_deletion_log` serve a questo. Contiene solo
l'impronta SHA-256 dell'id (etichetta `vetapp-deletion-log-v1:`), la data e il
motivo; mai e-mail, nome, contenuti o id di chi del team l'ha fatta.

Poiché il registro sta nello stesso database, un ripristino lo riporta indietro
insieme al resto. Per questo ogni cancellazione scrive la stessa riga anche in un
oggetto del bucket Storage PRIVATO `deletion-log` (nessuna policy: solo
`service_role`), che il ripristino non tocca.

Procedura:

1. **Prima** del ripristino: esportare la tabella `account_deletion_log` (Table
   editor → Export) e conservare il file fuori dal repository.
2. Ripristinare.
3. Con SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY nel `.env` locale, in prova:
   `uv run --system-certs --with truststore python scripts/maintenance/reapply_deletions.py`
   (conta soltanto: righe nel registro e nella copia, account da cancellare).
4. Se i numeri tornano, aggiungere `--apply`: ricarica nella tabella le righe
   presenti nella copia e mancanti, poi cancella con lo stesso eraser
   dell'eliminazione dell'account ogni account esistente la cui impronta è nel
   registro, anche se la riga era rimasta incompleta.
5. Annotare nel registro delle violazioni (sezione 4) solo i numeri.

Ordine di scrittura (garanzia): la riga si scrive PRIMA di cancellare, con
`completed_at` vuoto, nella tabella e nella copia; si completa dopo. Se la riga
non si può scrivere la cancellazione non parte (si riprova); se la cancellazione
si interrompe a metà, la riga resta incompleta e la riapplicazione la rifà.
`owner_hash` è unico: un nuovo tentativo non duplica.

Durata: una riga serve alla riapplicazione finché esiste un backup che può
contenere l'account (giorni di backup di Supabase + 30; oggi 37, da verificare
sul piano) e, come prova che la cancellazione è stata fatta, 5 anni dalla
cancellazione (da confermare con la Normativa). Valgono entrambe le impostazioni
`DELETION_LOG_REAPPLY_DAYS` e `DELETION_LOG_PROOF_YEARS`; resta il maggiore dei
due. Il lavoro `POST /admin/lifecycle/prune-deletion-log` (programmatore, ogni
ciclo) toglie le righe e le copie più vecchie. Non cambiare algoritmo o etichetta
dell'impronta finché il registro esiste: le righe vecchie non corrisponderebbero
più.

## 3. Segnali che devono far partire la procedura

- Qualcuno (utente, ricercatore, GitHub secret scanning, fornitore) segnala un
  accesso indebito o una chiave esposta.
- Un controllo di `scripts/setup/security_*.sql` o il test di esposizione
  (vedi `05_checklist.md`) trova una tabella leggibile senza login.
- Log Supabase con molte letture da un IP sconosciuto, picchi anomali nel
  ledger Groq, 401/403 a raffica.
- Smarrimento/furto di un dispositivo con sessione admin o app aperta.
- Commit nel repository pubblico contenente `.env`, chiavi `sb_secret_`,
  `gsk_`, token Firebase/Vercel, password.

## 4. Registro delle violazioni (art. 33 par. 5)

Il registro è obbligatorio anche per le violazioni **non** notificate. Tenere il
file compilato **fuori dal repository** (es. cartella privata del titolare,
`registro_violazioni.md` o foglio di calcolo), con una scheda per evento usando
questo modulo:

```
ID violazione: VB-AAAA-NN
Data/ora di scoperta (T0):            Data/ora stimata dell'evento:
Come è stata scoperta:
Descrizione dei fatti:
Sistemi coinvolti (Supabase/Vercel/Groq/app/GitHub/dispositivo):
Categorie di dati:  [ ] e-mail  [ ] telefono  [ ] posizione/percorsi GPS
                    [ ] profili animali  [ ] cartella clinica  [ ] conversazioni
                    [ ] foto/video  [ ] credenziali/sessioni  [ ] consensi  [ ] altro:
Numero stimato di interessati:         Paesi:
Tipo di violazione: [ ] riservatezza  [ ] integrità  [ ] disponibilità
Valutazione del rischio (nessuno/rischio/rischio elevato) e motivazione:
Misure di contenimento adottate (con orario):
Notifica al Garante: [ ] non dovuta (motivo)  [ ] sì, data/ora, n. protocollo
Altre autorità notificate:
Comunicazione agli interessati: [ ] non dovuta  [ ] sì, data, canale, testo
Fornitori coinvolti/avvisati:
Causa radice:
Correzione definitiva (commit/PR):
Lezioni apprese / modifiche a procedure:
Data chiusura:                          Responsabile:
```

## 5. Esercitazione

Una volta l'anno (e prima del lancio pubblico) simulare uno scenario
("la chiave service_role è finita su GitHub") e cronometrare i passi 1-7.
Annotare l'esito nel registro con ID `VB-TEST-AAAA`.

## Appendice A. Contatti da tenere aggiornati (fuori dal repo)

Titolare, socio delegato, legale, Supabase support (dashboard → Support),
Vercel support, Groq support, e-mail di contatto pubblicata nell'informativa.

## Appendice B. Bozza di comunicazione agli utenti

> Oggetto: Avviso importante sulla sicurezza del tuo account VetApp
>
> Il [data] abbiamo scoperto che [descrizione in una frase]. I dati coinvolti
> sono [elenco]. Non sono coinvolti [elenco]. Abbiamo già [misure]. Ti
> consigliamo di [cambiare la password / controllare i tuoi dati / ignorare
> e-mail che chiedono credenziali]. Per domande scrivi a [contatto]. Ci
> dispiace per quanto accaduto e ti terremo aggiornato.
