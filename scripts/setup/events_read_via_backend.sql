-- Eventi: lettura solo dal backend (OPZIONALE, da fare per ultima).
--
-- Gli eventi sono compresi nel piano: dopo la prova chi non si abbona non li
-- vede (GET /events risponde 402). Finche' la policy events_select_public
-- esiste, pero', chi ha la anon key puo' leggere la tabella direttamente e
-- saltare il controllo. Questo script la toglie: da allora gli eventi si
-- leggono solo da GET /events del backend (chiave service_role, che le policy
-- non toccano). Gli script di curatela scrivono con la service role e non
-- cambiano.
--
-- QUANDO: solo dopo che l'app nuova (che legge gli eventi dal backend) e'
-- l'unica in circolazione. Con l'app vecchia, la pagina Eventi resterebbe vuota
-- ("non sono riuscito a leggere"). Idempotente.

drop policy if exists events_select_public on public.events;

-- Per annullare:
--   create policy events_select_public on public.events
--   for select using (status in ('published', 'cancelled', 'postponed') and audience = 'public');
