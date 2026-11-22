-- QK-07 (22/11/2026): admin directories paged at the source.
-- NOT APPLIED. Applying it to the real database is the owner's decision.
--
-- Read-only functions for the admin portal (users and pets directories): search,
-- filters, stable ordering and the page are applied INSIDE Postgres, so the API
-- receives one page (plus the country counts) instead of every account / pet.
-- Idempotent (`create or replace`). No table is created, so no RLS policy, no
-- account-deletion row and no supplier-inventory row is needed: the functions only
-- read tables that already have them. Callable by service_role only (the API),
-- never by anon / authenticated; the API checks the admin e-mail before calling
-- (apps/api/routes/admin_users.py and admin_pets.py).
--
-- Ordering uses `collate "C"` so it matches the codepoint ordering the API used
-- before, whatever the database collation is.

-- ---------------------------------------------------------------- users
-- Returns {total, page, page_size, countries, rows}.
--   p_q        part of the e-mail or of the id, case-insensitive ('' = everybody)
--   p_country  '' = all, 'unknown' = no residence country, otherwise an ISO code
--   countries  accounts per country for p_q ONLY: the country filter is not applied
--              to it, so the portal can still show the other countries
--   page       the page actually returned (a page past the end is the last page)
-- Reads auth.users, hence SECURITY DEFINER; only service_role may execute it.
create or replace function public.admin_users_directory(
    p_q text, p_country text, p_page integer, p_page_size integer
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
    v_size integer := least(greatest(coalesce(p_page_size, 50), 1), 100);
    v_needle text := lower(btrim(coalesce(p_q, '')));
    v_country text := coalesce(p_country, '');
    v_total bigint;
    v_countries jsonb;
    v_page integer;
    v_rows jsonb;
begin
    with scope as (
        select coalesce(l.home_country_code, 'unknown') as bucket
          from auth.users u
          left join public.user_locations l on l.owner_id = u.id::text
         where v_needle = ''
            or position(v_needle in lower(coalesce(u.email::text, ''))) > 0
            or position(v_needle in lower(u.id::text)) > 0
    ), counts as (
        select bucket, count(*) as n from scope group by bucket
    )
    select coalesce(sum(n) filter (where v_country = '' or bucket = v_country), 0),
           coalesce(jsonb_object_agg(bucket, n), '{}'::jsonb)
      into v_total, v_countries
      from counts;

    v_page := least(
        greatest(coalesce(p_page, 1), 1),
        greatest(1, ceil(v_total::numeric / v_size)::integer)
    );

    select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc, r.id collate "C" desc),
                    '[]'::jsonb)
      into v_rows
      from (
          select u.id::text as id, u.email::text as email, u.created_at,
                 u.last_sign_in_at, u.email_confirmed_at, u.banned_until,
                 l.home_country_code, l.home_city, l.home_saved_at
            from auth.users u
            left join public.user_locations l on l.owner_id = u.id::text
           where (v_needle = ''
                  or position(v_needle in lower(coalesce(u.email::text, ''))) > 0
                  or position(v_needle in lower(u.id::text)) > 0)
             and (v_country = '' or coalesce(l.home_country_code, 'unknown') = v_country)
           order by u.created_at desc, u.id::text collate "C" desc
           limit v_size offset (v_page - 1) * v_size
      ) r;

    return jsonb_build_object(
        'total', v_total, 'page', v_page, 'page_size', v_size,
        'countries', v_countries, 'rows', v_rows
    );
end;
$$;
revoke all on function public.admin_users_directory(text, text, integer, integer)
    from public, anon, authenticated;
grant execute on function public.admin_users_directory(text, text, integer, integer)
    to service_role;

-- ----------------------------------------------------------------- pets
-- QK-07d: the pet directory no longer reads pet_profiles.is_active / is_exotic /
-- species_group (they exist in production but nothing ever writes them). What it shows is
-- derived from what IS stored, with the same rules as the API's directory_traits.py (a test
-- keeps them in step):
--   group   the species family of `normalize_species` (packages/core/domain/pet_profile/
--           species.py); 'unknown' when the pet has no species at all
--   exotic  a family the radar calls an exotic group: everything that is not dog or cat
--   active  not in Ricordi (is_memorial false)

-- An earlier draft of this function took (group, species); it is removed, nothing used it.
drop function if exists public.admin_species_bucket(text, text);

create or replace function public.admin_species_bucket(p_species text)
returns text language sql immutable set search_path = '' as $$
    select case when label = '' then 'unknown' else case label
        when 'cane' then 'dog' when 'dog' then 'dog'
        when 'gatto' then 'cat' when 'cat' then 'cat'
        when 'piccoli mammiferi' then 'small_mammal' when 'rabbit' then 'small_mammal'
        when 'small_mammal' then 'small_mammal'
        when 'uccello' then 'bird' when 'bird' then 'bird'
        when 'rettili e anfibi' then 'reptile_amphibian' when 'reptile' then 'reptile_amphibian'
        when 'reptile_amphibian' then 'reptile_amphibian'
        when 'pesce' then 'fish' when 'pesci' then 'fish' when 'fish' then 'fish'
        else 'other'
    end end
    from (select lower(btrim(coalesce(p_species, ''))) as label) s;
$$;
revoke all on function public.admin_species_bucket(text) from public, anon, authenticated;
grant execute on function public.admin_species_bucket(text) to service_role;

-- The pets that match the directory filters. p_status: '' | active | inactive | exotic |
-- memorial ('inactive' and 'memorial' are the same pets: the ones in Ricordi). p_region
-- matches the city (users have no region). Only directory fields: never medical notes.
-- The returned columns keep the names the admin panel reads, with derived values.
create or replace function public.admin_pets_scope(
    p_q text, p_species text, p_status text, p_country text, p_region text
) returns table (
    id text, owner_id text, name text, species text, species_group text, breed text,
    is_active boolean, is_exotic boolean, is_memorial boolean, country text, city text
) language sql stable security invoker set search_path = '' as $$
    select b.id, b.owner_id, b.name, b.species, b.species_group, b.breed,
           not b.is_memorial as is_active,
           b.species_group in ('small_mammal', 'bird', 'reptile_amphibian', 'fish', 'other')
               as is_exotic,
           b.is_memorial, b.country, b.city
      from (
          select p.id, p.owner_id, p.name, p.species, p.breed,
                 public.admin_species_bucket(p.species) as species_group,
                 coalesce(p.is_memorial, false) as is_memorial,
                 l.home_country_code as country, l.home_city as city
            from public.pet_profiles p
            left join public.user_locations l on l.owner_id = p.owner_id
      ) b
     where (coalesce(btrim(p_q), '') = ''
            or position(lower(btrim(p_q)) in lower(coalesce(b.name, ''))) > 0
            or position(lower(btrim(p_q)) in lower(coalesce(b.id, ''))) > 0
            or position(lower(btrim(p_q)) in lower(coalesce(b.owner_id, ''))) > 0
            or position(lower(btrim(p_q)) in lower(coalesce(b.breed, ''))) > 0)
       and (coalesce(p_country, '') = '' or upper(coalesce(b.country, '')) = upper(p_country))
       and (coalesce(p_region, '') = ''
            or position(lower(p_region) in lower(coalesce(b.city, ''))) > 0)
       and (coalesce(p_species, '') = '' or b.species_group = p_species)
       and (coalesce(p_status, '') = ''
            or (p_status = 'active' and not b.is_memorial)
            or (p_status = 'inactive' and b.is_memorial)
            or (p_status = 'exotic'
                and b.species_group in ('small_mammal', 'bird', 'reptile_amphibian', 'fish', 'other'))
            or (p_status = 'memorial' and b.is_memorial));
$$;
revoke all on function public.admin_pets_scope(text, text, text, text, text)
    from public, anon, authenticated;
grant execute on function public.admin_pets_scope(text, text, text, text, text)
    to service_role;

-- Returns {total, page, page_size, rows} ordered by name (case-insensitive) then id.
create or replace function public.admin_pets_directory(
    p_q text, p_species text, p_status text, p_country text, p_region text,
    p_page integer, p_page_size integer
) returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
    v_size integer := least(greatest(coalesce(p_page_size, 50), 1), 100);
    v_total bigint;
    v_page integer;
    v_rows jsonb;
begin
    select count(*) into v_total
      from public.admin_pets_scope(p_q, p_species, p_status, p_country, p_region);

    v_page := least(
        greatest(coalesce(p_page, 1), 1),
        greatest(1, ceil(v_total::numeric / v_size)::integer)
    );

    select coalesce(
               jsonb_agg(to_jsonb(r) - 'sort_name' order by r.sort_name collate "C", r.id collate "C"),
               '[]'::jsonb)
      into v_rows
      from (
          select s.*, null::text as region, lower(coalesce(s.name, '')) as sort_name
            from public.admin_pets_scope(p_q, p_species, p_status, p_country, p_region) s
           order by lower(coalesce(s.name, '')) collate "C", s.id collate "C"
           limit v_size offset (v_page - 1) * v_size
      ) r;

    return jsonb_build_object(
        'total', v_total, 'page', v_page, 'page_size', v_size, 'rows', v_rows
    );
end;
$$;
revoke all on function public.admin_pets_directory(text, text, text, text, text, integer, integer)
    from public, anon, authenticated;
grant execute on function public.admin_pets_directory(text, text, text, text, text, integer, integer)
    to service_role;
