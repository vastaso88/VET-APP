-- Abbonamenti: scrittura solo dal backend.
--
-- Le policy subscriptions_insert_own e subscriptions_update_own permettono a
-- chi ha la anon key e un proprio token di scrivere la propria riga
-- direttamente nel database: allungare trial_ends_at o scegliere un piano
-- senza passare dal backend. Con i piani a pagamento e il blocco dopo la
-- prova questo salterebbe tutto il controllo. Questo script le toglie: da
-- allora la riga si crea e si aggiorna solo dal backend (chiave service_role,
-- che le policy non toccano). La lettura della propria riga resta
-- (subscriptions_select_own).
--
-- QUANDO: prima di far entrare utenti reali. L'app non scrive mai su questa
-- tabella: passa da /subscription/status e /subscription/select-plan.
-- Idempotente.

drop policy if exists subscriptions_insert_own on public.subscriptions;
drop policy if exists subscriptions_update_own on public.subscriptions;

-- Per annullare:
--   create policy subscriptions_insert_own on public.subscriptions
--   for insert with check (owner_id = auth.uid()::text);
--   create policy subscriptions_update_own on public.subscriptions
--   for update using (owner_id = auth.uid()::text) with check (owner_id = auth.uid()::text);
