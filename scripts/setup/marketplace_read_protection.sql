-- Mercatino: protezione della lettura (decisione del proprietario, 2026-10-26).
--
-- PROBLEMA: la policy marketplace_listings_select_all (using (true)) lascia
-- leggere TUTTA la tabella degli annunci a chiunque abbia la anon key, con una
-- query diretta: si aggira il raggio massimo (1-300 km) che il backend impone in
-- GET /marketplace/listings.
--
-- DOPO QUESTO SCRIPT: un utente puo' leggere direttamente solo i PROPRI annunci.
-- Gli annunci altrui li serve solo il backend (service role, che non e'
-- soggetto alle policy): elenco e mappa (GET /marketplace/listings), dettaglio
-- (GET /marketplace/listings/{id}), portale admin (passa dal backend).
--
-- QUANDO ESEGUIRLO: DOPO che sono in produzione il backend nuovo (con
-- GET /marketplace/listings/{id}) e l'app nuova (che non legge piu' la tabella
-- degli altri). Con l'app VECCHIA, che in caso di errore del backend leggeva la
-- tabella direttamente, il Mercatino resterebbe comunque vuoto invece di
-- mostrare annunci fuori raggio: nessun dato esce, ma e' bene non farlo prima.
--
-- Idempotente. Per annullare: ricreare la policy select_all (vedi in fondo).

alter table public.marketplace_listings enable row level security;

drop policy if exists marketplace_listings_select_all on public.marketplace_listings;
drop policy if exists marketplace_listings_select_own on public.marketplace_listings;

create policy marketplace_listings_select_own
on public.marketplace_listings
for select
using (owner_id = auth.uid()::text);

-- Il portale admin (apps/admin_portal) NON legge questa tabella direttamente:
-- chiama il backend (/admin/moderation/..., apps/api/routes/admin.py), che usa
-- la service role. Quindi non serve nessuna policy per gli admin.

-- Verifica (da lanciare con un utente normale, non con la service role): deve
-- restituire solo gli annunci dell'utente, mai quelli di altri.
--   select id, owner_id, title from public.marketplace_listings limit 20;

-- Per annullare (non consigliato):
--   drop policy if exists marketplace_listings_select_own on public.marketplace_listings;
--   create policy marketplace_listings_select_all
--   on public.marketplace_listings for select using (true);
