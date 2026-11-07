-- Mercatino: segnalazioni solo dal backend (OPZIONALE, da fare per ultima).
--
-- Segnalare un annuncio e' un'azione compresa nel piano: dopo la prova chi non
-- si abbona non puo' farla (POST /marketplace/listings/{id}/report risponde
-- 402). Finche' la policy marketplace_listing_reports_insert_own esiste, pero',
-- chi ha la anon key e un proprio token puo' scrivere una segnalazione
-- direttamente nel database e saltare il controllo. Questo script la toglie: da
-- allora si segnala solo dal backend (chiave service_role, che le policy non
-- toccano). Il trigger handle_marketplace_listing_report continua a scattare
-- anche per gli inserimenti del backend: la rimozione automatica dopo tre
-- segnalazioni di persone diverse non cambia.
--
-- QUANDO: solo dopo che l'app nuova (che segnala dal backend) e' l'unica in
-- circolazione. Con l'app vecchia, segnalare un annuncio non salverebbe nulla.
-- Idempotente.

drop policy if exists marketplace_listing_reports_insert_own
    on public.marketplace_listing_reports;

-- Per annullare:
--   create policy marketplace_listing_reports_insert_own
--   on public.marketplace_listing_reports
--   for insert with check (reporter_owner_id = auth.uid()::text);
