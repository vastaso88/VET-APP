# Conservazione dei dati della chat

Proposta e implementazione del 2026-10-26 (punto "retention" dell'audit di sicurezza,
`docs/security/02_audit.md`). Le durate sono impostazioni del backend: cambiarle non
richiede codice.

## Cosa si conserva e per quanto

| Dato | Durata | Perché | Impostazione |
|---|---|---|---|
| Conversazioni della chat (messaggi, stato del caso) | **24 mesi dall'ultimo messaggio**; il proprietario può cancellarle prima dall'app | Un caso clinico resta utile da rileggere e da riassumere per il veterinario per più di una stagione; oltre due anni senza un nuovo messaggio non lo è più | `CHAT_CONVERSATION_RETENTION_MONTHS` (0 = mai) |
| File allegati in chat (foto, PDF) e la loro trascrizione | Con la conversazione a cui appartengono | Il file da solo non ha senso senza il messaggio | — |
| File caricati ma mai inviati in un messaggio | **7 giorni** | Sono residui di un invio interrotto | `CHAT_ORPHAN_ATTACHMENT_RETENTION_DAYS` |
| Dettatura vocale | **Non conservata**: l'audio è trascritto e scartato; resta solo il testo che il proprietario sceglie di inviare | — | — |
| Registro delle chiamate al modello (`llm_usage`: conteggi, nessun testo) | 90 giorni | Analisi dei consumi | funzione SQL `chat_usage_cleanup` |
| Contatori giornalieri per utente | 30 giorni | Solo per il limite giornaliero | idem |
| Risposte in cache (domande generali, senza dati personali) | 24 ore | — | `CHAT_ANSWER_CACHE_TTL_HOURS` |

La cartella clinica (documenti caricati nella scheda dell'animale) **non** rientra qui:
resta finché il proprietario la tiene.

## Come avviene la cancellazione

1. **Backend, `POST /chat/maintenance`** (solo account sviluppatore, idempotente): il
   servizio `ChatRetentionService` cancella prima i file dal bucket e poi le righe
   (allegati, poi conversazione), così nel bucket non restano file senza riga. Al massimo
   200 conversazioni per esecuzione; le successive alla prossima. Va chiamato da uno
   scheduler (quotidiano) finché non esiste un job interno.
2. **SQL, `chat_retention_cleanup()`** in `scripts/setup/supabase_schema.sql` (eseguito
   dal proprietario; pg_cron lo lancia alle 03:45 UTC se l'estensione è attiva):
   cancella le conversazioni scadute **che non hanno più allegati** e riporta quanti
   allegati restano da far cancellare al backend. Non tocca i file del bucket: una riga
   di `storage.objects` eliminata via SQL non rimuove i byte dal bucket, per questo la
   parte dei file è del backend.
3. La colonna `conversations.last_message_at` (nuova) è tenuta dal backend a ogni
   salvataggio; lo script la riempie per le conversazioni esistenti dai messaggi stessi.

## Testo per l'informativa (italiano; le altre lingue alle sessioni compliance)

> **Conversazioni con l'assistente.** I messaggi che scambi con l'assistente e i file che
> alleghi in chat sono conservati per 24 mesi dall'ultimo messaggio della conversazione,
> così puoi rileggerli e generare il riassunto per il veterinario. Puoi cancellare una
> conversazione in qualsiasi momento dall'app; trascorsi 24 mesi senza nuovi messaggi la
> cancelliamo noi, insieme ai suoi allegati. Un file caricato ma non inviato viene
> eliminato dopo 7 giorni. La dettatura vocale non viene conservata: l'audio è trascritto
> e subito scartato. Del funzionamento dell'assistente teniamo solo conteggi tecnici
> (numero di richieste, dimensione in token), senza il testo, per 90 giorni.

## Aperto

- Lo scheduler esterno per `POST /chat/maintenance` (o un job interno): oggi la parte
  SQL è schedulabile con pg_cron, quella dei file no.
- Il MULTILANG: le traduzioni del testo dell'informativa.
