-- Abbonamenti: giorno in cui l'account e' stato visto senza accesso.
--
-- Serve alla conservazione dei dati di chi non rinnova e non cancella
-- l'account (4 mesi, poi cancellazione; avvisi a D+0, 30, 60, 90 e a 14, 7,
-- 3, 1 giorni dalla fine): `access_lost_at` e' il giorno D. Lo scrive solo il
-- backend. Per ora non parte nessun invio e nessuna cancellazione: la colonna
-- serve a mostrare "dati conservati fino al ..." e alla modalita' prova del
-- lavoro giornaliero.
--
-- QUANDO: prima di rilasciare questa versione del backend, altrimenti la data
-- non viene registrata (il resto continua a funzionare). Idempotente.

alter table public.subscriptions add column if not exists access_lost_at timestamptz;

-- Per annullare:
--   alter table public.subscriptions drop column if exists access_lost_at;
