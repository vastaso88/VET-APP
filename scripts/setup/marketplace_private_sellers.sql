-- Mercatino solo per privati (decisione del proprietario, 2026-11-09). Chi
-- pubblica o modifica un annuncio dichiara di vendere come privato, non come
-- attività commerciale; il backend rifiuta senza la dichiarazione e ne salva la
-- data qui. Gli annunci più vecchi restano con null. Idempotente.
alter table public.marketplace_listings
    add column if not exists private_seller_declared_at timestamptz;
-- Quale testo della dichiarazione è stato spuntato (es. '2026-11-09').
alter table public.marketplace_listings
    add column if not exists private_seller_declaration_version text
    check (
        private_seller_declaration_version is null
        or char_length(private_seller_declaration_version) <= 32
    );

-- Anche scrivendo direttamente nella tabella con la propria sessione (finché le
-- policy insert/update esistono: marketplace_lock_writes.sql le toglie), un
-- annuncio nuovo o modificato deve portare la dichiarazione. Policy restrittive:
-- tolgono un diritto, non ne danno. Il backend usa la service role e non passa
-- da qui (la regola lì è nella rotta).
drop policy if exists marketplace_listings_insert_private_seller on public.marketplace_listings;
create policy marketplace_listings_insert_private_seller
on public.marketplace_listings
as restrictive
for insert
to authenticated
with check (private_seller_declared_at is not null);

drop policy if exists marketplace_listings_update_private_seller on public.marketplace_listings;
create policy marketplace_listings_update_private_seller
on public.marketplace_listings
as restrictive
for update
to authenticated
with check (private_seller_declared_at is not null);
