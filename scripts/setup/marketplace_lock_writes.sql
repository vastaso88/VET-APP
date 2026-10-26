-- Mercatino: scrittura solo dal backend (OPZIONALE, da fare dopo la protezione
-- della lettura: scripts/setup/marketplace_read_protection.sql).
--
-- Il filtro "niente animali" sui testi decide nel backend (POST/PUT
-- /marketplace/listings). Finche' le policy marketplace_listings_insert_own e
-- marketplace_listings_update_own esistono, chi ha la anon key e un proprio
-- token puo' pero' scrivere un annuncio direttamente nel database e saltare il
-- filtro. Questo script le toglie: da allora si pubblica e si modifica solo
-- dal backend. La cancellazione del proprio annuncio resta diretta
-- (marketplace_listings_delete_own).
--
-- QUANDO: solo dopo che l'app nuova (che pubblica e modifica tramite il
-- backend) e' l'unica in circolazione. Con l'app vecchia, pubblicare darebbe
-- errore. Idempotente.

drop policy if exists marketplace_listings_insert_own on public.marketplace_listings;
drop policy if exists marketplace_listings_update_own on public.marketplace_listings;

-- Per annullare:
--   create policy marketplace_listings_insert_own on public.marketplace_listings
--   for insert with check (owner_id = auth.uid()::text);
--   create policy marketplace_listings_update_own on public.marketplace_listings
--   for update using (owner_id = auth.uid()::text) with check (owner_id = auth.uid()::text);
