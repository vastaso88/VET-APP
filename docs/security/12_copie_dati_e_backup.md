# Copie dei dati: backup del fornitore e copie manuali

Ultimo aggiornamento: 2026-11-16. Regola concordata tra Sicurezza e Normativa
(`docs/compliance/16_recupero_account_dopo_la_cancellazione.md`, §9.2). Serve a
due cose: che i dati di un account cancellato non sopravvivano in copie
dimenticate, e che dopo un ripristino si possano rifare le cancellazioni
(registro delle cancellazioni, `account_deletion_log`).

## 1. Backup automatici di Supabase (verificato sulle pagine ufficiali)

| Piano Supabase | Backup automatici | Conservazione |
| --- | --- | --- |
| **Free** | **nessuno**: il fornitore non fa backup e non dichiara copie interne né ripristini | solo copie manuali (`supabase db dump`) |
| Pro | giornalieri | 7 giorni |
| Team | giornalieri | 14 giorni |
| Enterprise | giornalieri | fino a 30 giorni |
| Add-on PITR (Pro, Team, Enterprise) | continui, ogni 2 minuti; sostituiscono i giornalieri | 7, 14 o 28 giorni (oltre solo Enterprise) |

- I backup coprono **solo il database**. I file dello Storage (foto, video,
  allegati) non ci sono: un ripristino non riporta i file cancellati dopo il
  backup.
- Cancellando il progetto, il fornitore cancella anche i backup.
- Le pagine non dicono per quanto tempo un dato cancellato resti nei backup
  oltre il periodo indicato sopra.

Fonti, consultate il 2026-11-16:
- <https://supabase.com/docs/guides/platform/backups>
- <https://supabase.com/kb/faqs/platform/free-plan-backups>
- <https://supabase.com/pricing>

**Stato verificato il 2026-11-16** (Orchestratore, pagina Backups della dashboard
di `ywbuzgwbkrmkukkpysbz`): il progetto è sul **piano Free**, «Free Plan does
not include project backups». Conseguenze:

- **Informativa:** il fornitore del database non tiene copie di sicurezza, quindi
  dopo la cancellazione non restano copie da attendere. Vale il periodo di 30
  giorni del ripensamento, a condizione che si rispetti la regola delle copie
  manuali (§2).
- **Ripristino:** non esiste. Se il database si rompe o un dato viene perso, per
  esempio per uno script SQL sbagliato eseguito a mano, non si torna indietro
  (registro dei rischi, R29).
- **Prima di ogni script SQL sul database reale** serve una copia manuale cifrata
  (`supabase db dump`), come eccezione prevista al §2: approvata, annotata,
  scadenza 30 giorni, fuori da cartelle sincronizzate.
- Il passaggio a **Pro** (7 giorni di backup giornalieri) o al PITR è una decisione
  del proprietario prima del lancio. Se cambia il piano, aggiornare questa sezione
  e l'informativa: la frase diventa «7 giorni + 30».

## 2. Copie manuali

Esempi: dump, esportazioni CSV dal pannello, tabelle copiate sul computer,
esportazioni dal portale di amministrazione. Le regole:

1. **Di norma nessuna copia manuale di dati reali.** Per sviluppo e prove si
   usano dati sintetici (`SUPABASE_URL` vuoto per le prove locali).
2. **Eccezione solo se serve** (migrazione, indagine su una violazione,
   ripristino). La approva **per iscritto il proprietario**, dopo aver sentito
   Sicurezza: una sessione di IA consiglia, non approva. Ogni copia va
   annotata nell'**elenco delle copie**: che cosa, dove, chi, perché, data,
   scadenza. L'elenco sta **fuori dal repository**, come il registro delle
   violazioni, perché dice dove si trovano i dati.
3. **Scadenza:** al massimo 30 giorni. Oltre, solo con una nuova approvazione, un
   motivo scritto e **dopo aver rifatto sulla copia le cancellazioni del registro**:
   una copia prolungata non deve contenere account cancellati. È la condizione
   che rende vera la frase dell'informativa «eventuali copie di sicurezza si
   cancellano entro 30 giorni dalla cancellazione definitiva» (it/02 §7). Se
   questa regola cambia, va cambiata anche quella frase.
4. **Custodia:**
   - cifrata, per esempio un archivio AES-256 con la password nel gestore di
     password, oppure un disco cifrato;
   - in un luogo privato con accesso limitato;
   - **mai** in una cartella sincronizzata (Google Drive, OneDrive, iCloud: le
     versioni e i cestini moltiplicano le copie);
   - mai dentro la cartella del progetto o un suo worktree, dove le sessioni di
     IA possono leggerla;
   - mai nel repository, mai incollata in chat o in strumenti di IA.
5. **Prima di usare una copia** si rifanno le cancellazioni del registro. Se
   non si può, la copia non si usa.
6. **Alla scadenza** si cancella la copia, anche dai cestini, e si annota la
   data nell'elenco. L'elenco si controlla ogni mese (`05_checklist.md`,
   sezione C).
7. **«Scarica i miei dati»** è la copia che l'utente chiede per sé, non una
   copia del team. Sul server restano solo collegamenti validi 15 minuti.
8. **Chi trova una copia non in elenco** la cancella e avvisa Sicurezza: può
   essere una violazione (`03_procedura_violazioni.md`).

## 3. Ripristino del database: la procedura

Il registro delle cancellazioni sta nello stesso database. Ripristinando un
backup torna anche un registro più vecchio, senza le cancellazioni avvenute
dopo. Quindi:

1. **Prima del ripristino** esportare `account_deletion_log`. Se esiste, va
   usata anche la copia del registro fuori dal database, nel bucket privato
   (parere di Sicurezza del 2026-11-16).
2. Ripristinare.
3. Ricaricare il registro esportato, poi lanciare lo script che rifà le
   cancellazioni: prima a secco, poi per davvero.
4. Annotare il ripristino nel registro delle violazioni, se era dovuto a un
   incidente, oppure nell'elenco delle copie.
