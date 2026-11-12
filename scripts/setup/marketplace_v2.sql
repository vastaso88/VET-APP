-- Mercatino v2 (2026-10-07, session "Mercatino"). Idempotent: safe to run
-- more than once. The same block is at the end of supabase_schema.sql, so a
-- fresh setup gets it too; run THIS file once on the existing database.
--
-- 1. target_species: which animals a listing is for (dog, cat, small_mammal,
--    bird, reptile_amphibian, fish, other, or "all" for generic items). The app
--    requires at least one; rows saved before this stay empty and count as
--    suitable for every species.
-- 2. Category list replaced; rows with the old values are rewritten to the
--    closest new one (the app reads both anyway).
-- 3. A guard trigger: positions are rounded to the ~1 km grid in the
--    database too, and an author can no longer reset report_count or bring
--    back a listing that moderation removed (the update_own policy alone let
--    them change every column of their own row).
-- 4. Public 'marketplace-photos' bucket: anyone can view (listings are
--    public), only the author writes/deletes inside <their id>/... .

alter table public.marketplace_listings
    add column if not exists target_species jsonb not null default '[]'::jsonb;

-- Old form saved "0" as a price; free items are "in regalo" (null) now.
update public.marketplace_listings set price_cents = null where price_cents <= 0;

-- Rows written before the grid (randomly offset positions) are snapped too.
update public.marketplace_listings
set latitude = round(latitude::numeric, 2)::double precision,
    longitude = round(longitude::numeric, 2)::double precision
where latitude <> round(latitude::numeric, 2)::double precision
   or longitude <> round(longitude::numeric, 2)::double precision;

update public.marketplace_listings
set category = case category
        when 'transport_carriers' then 'kennels_carriers'
        when 'food' then 'feeding'
        when 'grooming' then 'hygiene_grooming'
        else 'other'
    end
where category in ('transport_carriers', 'food', 'grooming', 'accessories', 'health_wellness');

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listings_category_check'
          and conrelid = 'public.marketplace_listings'::regclass
    ) then
        alter table public.marketplace_listings
            add constraint marketplace_listings_category_check
            check (category in (
                'kennels_carriers', 'leashes_collars', 'toys', 'clothing', 'feeding',
                'hygiene_grooming', 'aquariums_terrariums', 'cages_aviaries', 'other'
            ));
    end if;
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listings_price_check'
          and conrelid = 'public.marketplace_listings'::regclass
    ) then
        alter table public.marketplace_listings
            add constraint marketplace_listings_price_check
            check (price_cents is null or price_cents > 0);
    end if;
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listings_photos_check'
          and conrelid = 'public.marketplace_listings'::regclass
    ) then
        alter table public.marketplace_listings
            add constraint marketplace_listings_photos_check
            check (jsonb_typeof(photo_urls) = 'array' and jsonb_array_length(photo_urls) <= 6);
    end if;
end;
$$;

-- Runs as the caller (no security definer), so current_user tells a regular
-- app user ('authenticated'/'anon') apart from the service role (admin
-- moderation in apps/api/routes/admin.py) and from the report trigger,
-- which runs as its owner and must keep updating report_count/status.
create or replace function public.guard_marketplace_listing()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    new.latitude := round(new.latitude::numeric, 2)::double precision;
    new.longitude := round(new.longitude::numeric, 2)::double precision;

    if current_user in ('authenticated', 'anon') then
        if tg_op = 'INSERT' then
            new.report_count := 0;
            new.status := 'active';
        else
            new.owner_id := old.owner_id;
            new.created_at := old.created_at;
            new.report_count := old.report_count;
            if old.status = 'removed' or new.status = 'removed' then
                new.status := old.status;
            end if;
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists marketplace_listing_guard on public.marketplace_listings;
create trigger marketplace_listing_guard
before insert or update on public.marketplace_listings
for each row execute function public.guard_marketplace_listing();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('marketplace-photos', 'marketplace-photos', true, 5000000, array['image/jpeg'])
on conflict (id) do update
set public = true,
    file_size_limit = 5000000,
    allowed_mime_types = array['image/jpeg'];

-- Viewing goes through the public url and needs no policy; this select
-- policy is what Storage requires (with delete) for the author to remove
-- their own photos.
drop policy if exists marketplace_photos_objects_select_own on storage.objects;
create policy marketplace_photos_objects_select_own on storage.objects
for select using (
    bucket_id = 'marketplace-photos' and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists marketplace_photos_objects_insert_own on storage.objects;
create policy marketplace_photos_objects_insert_own on storage.objects
for insert with check (
    bucket_id = 'marketplace-photos' and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists marketplace_photos_objects_delete_own on storage.objects;
create policy marketplace_photos_objects_delete_own on storage.objects
for delete using (
    bucket_id = 'marketplace-photos' and (storage.foldername(name))[1] = auth.uid()::text
);
