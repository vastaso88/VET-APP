# Righe di account che non esistono più

Data: 2026-11-23. Proposta di Cybersicurezza: decide il proprietario. I numeri di produzione e la
valutazione dell'evento stanno nel registro interno (`.local/security/`), non qui.

**Riga orfana** = una riga che porta l'id di un account che non è più tra gli utenti.

## 1. Perché succede

1. **Tabelle fuori dagli script.** Un database può avere tabelle create a mano: la cancellazione va
   confrontata con le tabelle che esistono davvero, non solo con lo schema del repository.
2. **Account tolti dalla dashboard di Supabase.** Quel comando elimina solo l'accesso e non chiama la
   nostra cancellazione.
3. **Dati di prova** con un proprietario inventato (`demo-user`, `shared`): non sono persone.

## 2. Che cosa cambia

| Che cosa | Dove |
| --- | --- |
| Cancellazione ed esportazione coprono le tabelle vecchie; dove non esistono si saltano senza nota | `LEGACY_OWNER_TABLES` in `supabase_account_eraser.py` |
| Via i due automatismi vecchi (iscrizione e limite di animali; il secondo è già disabilitato) | migrazione `20261123200000_remove_legacy_signup_triggers.sql` |
| Ai ruoli dell'app non restano TRUNCATE, TRIGGER e REFERENCES | migrazione `20261123201000_app_roles_no_truncate.sql` |
| Pulizia una tantum delle righe orfane, lanciata dal proprietario | `scripts/maintenance/erase_orphan_rows.sql` |
| Il portale non mostra indirizzo e posizione di nessuno (pronto, aspetta la conferma del socio) | `admin_dashboard.py`, mappa del portale |
| Rete di controllo sui nomi di produzione | `scripts/security/production_tables.json`, `test_production_tables_covered.py` |

**Ordine in produzione:** conferma di chi ha creato il vecchio sistema (il socio che cura il portale)
→ copia manuale (doc 12) → migrazioni → deploy del codice → pulizia (parte 1, parte 2, parte 1). Le
tabelle vecchie si tolgono solo dopo il deploy: il portale di oggi legge `owner_profiles`. Non prima di
aver chiesto per `radar_*`, `pricing_*` e `scrape_runs`.

**Che cosa resta fuori dalla pulizia:** gli account esistenti, anche in pausa o in attesa di
eliminazione; i proprietari di prova; il registro delle cancellazioni; le conversazioni del Mercatino
tenute per una segnalazione; le righe `radar_*`, che portano un centro di ricerca e vanno tolte appena
arriva la conferma; i file nei contenitori, che non si cancellano da SQL. Il contenitore
`clinical-documents` del vecchio sistema è nella cancellazione per i file che hanno una riga; un file
senza riga si vede nella parte 1 e si toglie dalla dashboard, Storage (non è un account). Gli acquisti del vecchio sistema si cancellano: sono solo righe dimostrative.

## 3. La fotografia dei nomi (a ogni rilascio)

L'Orchestratore lancia questa query in produzione (sola lettura, nessun valore delle righe) e salva il
risultato, così com'è, in `scripts/security/production_tables.json`. Se compare una tabella che la
cancellazione non conosce, o una dichiarata «non personale» con una colonna che nomina una persona, il
test fallisce e dice quale.

```sql
select jsonb_pretty(jsonb_build_object(
         'read_on', current_date,
         'tables', jsonb_object_agg(table_name, colonne order by table_name))) as fotografia
  from (select c.table_name, jsonb_agg(c.column_name order by c.ordinal_position) as colonne
          from information_schema.columns c
          join information_schema.tables t
            on t.table_schema = c.table_schema and t.table_name = c.table_name
         where c.table_schema = 'public' and t.table_type = 'BASE TABLE'
         group by c.table_name) x;
```

Quella di oggi è provvisoria (nomi del 22 novembre, colonne solo delle tabelle vecchie). Limite: la
fotografia vale il giorno in cui è fatta. Una tabella creata a mano dopo si vede al rilascio
successivo.

## 4. Perché non succeda più con la dashboard

| Strada | A favore | Contro |
| --- | --- | --- |
| A. Vincolo verso gli utenti con cancellazione a cascata | automatica, dentro il database | `owner_id` è testo e l'id utente è un UUID: cambia il tipo di decine di colonne; lascia i file; cancella anche le conversazioni segnalate da tenere |
| B. Automatismo alla cancellazione dell'utente | immediato | sta su una tabella non nostra; un suo errore blocca la cancellazione; lascia i file; ripete in SQL regole che esistono già nel codice; nessun ripensamento |
| C. Lavoro periodico che trova gli orfani e usa la nostra cancellazione | una sola regola per tutti, file compresi, scrive il registro | codice nuovo; un elenco utenti letto male sembrerebbe «tutti orfani»: servono i freni qui sotto |
| **D. Regola + conteggio a ogni rilascio + pulizia a mano (consigliata ora)** | nessun codice che cancella da solo; pochi account | dipende da una persona |

**Consiglio:** D adesso, C dopo il lancio se gli orfani ricompaiono. Freni per C: confronto fatto dentro
il database e non su un elenco scaricato; attesa di 7 giorni dalla prima volta che l'orfano è visto; al
massimo 3 account per giro; se gli orfani superano 5 o il 10% degli account non cancella nulla e avvisa.
Gli account in pausa esistono ancora, quindi non sono orfani; Ricordi, registro delle cancellazioni e
conversazioni tenute seguono le regole della cancellazione di sempre.

**Regola per tutti, da subito: un account non si elimina mai dalla dashboard di Supabase, nemmeno un
account di prova.** Si usa la nostra cancellazione:

- **in produzione**: si entra nell'app con quell'account e si sceglie «Elimina subito». Se la password non
  c'è più, prima si recupera con l'e-mail; se nemmeno l'e-mail è raggiungibile, non si tocca nulla e si
  avvisa l'Orchestratore. Nessuna chat chiede o consiglia di farlo dalla dashboard;
- **sul gemello**: `gemello.py azzera`, che usa la stessa cancellazione;
- gli account di prova in produzione sono già esclusi dalle regole (`CLAUDE.md`): se ne esiste ancora uno
  vecchio, si elimina come sopra e si annota nel registro interno.
