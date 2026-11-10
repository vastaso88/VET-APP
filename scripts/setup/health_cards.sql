-- Approved health cards: the only sources a health answer may draw on
-- (plan "fratello maggiore", stage 2, 2026-11-10). Idempotent: safe to run
-- again. Content table, NOT personal data: general texts written by the
-- manual project and approved by the owner; nothing about any user.
--
-- Read only by the backend with the service role. Row level security is on
-- and there is no policy: the app (anon and authenticated keys) can neither
-- read nor write it. Not in the allowlist of check_anon_exposure.py on
-- purpose. Not in the account eraser: it holds no user data.

create table if not exists public.health_cards (
    id text primary key,
    -- canonical families (dog, cat, small_mammal, bird, reptile_amphibian,
    -- fish, other), 'rabbit' (its own key: a rabbit's card is not a hamster's),
    -- or 'all'
    species text[] not null,
    topic text not null,
    title text not null,
    body text not null check (char_length(body) <= 4000),
    -- human-readable citation of the source the card was written from
    source text not null,
    -- 1 official bodies and societies, 2 peer-reviewed literature, 3 textbooks
    source_level smallint not null check (source_level between 1 and 3),
    language text not null default 'it',
    -- only 'approved' cards are searchable
    status text not null default 'draft' check (status in ('draft', 'approved', 'retired')),
    approved_by text,
    approved_at timestamptz,
    rights_note text,
    last_checked_at date,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

comment on table public.health_cards is
    'Approved health cards for the chat (general content, no personal data). '
    'Service role only: RLS on, no policy.';

alter table public.health_cards enable row level security;
-- Second defence, as for every backend-only table: without privileges the app
-- cannot even query it, whatever a future policy says.
revoke all on table public.health_cards from anon, authenticated;
grant all on table public.health_cards to service_role;

create index if not exists health_cards_species_idx on public.health_cards using gin (species);
create index if not exists health_cards_search_idx on public.health_cards using gin (
    to_tsvector('italian', title || ' ' || topic || ' ' || body)
);

-- Full-text search in Italian with OR between the words of the question (a
-- natural message never contains every word of a card), approved cards of
-- this species family or of every species, best rank first.
create or replace function public.search_health_cards(
    p_species text,
    p_query text,
    p_limit integer default 10
)
returns table (
    id text,
    species text[],
    topic text,
    title text,
    body text,
    source text,
    source_level smallint,
    language text,
    rank real
)
language sql
stable
security invoker
set search_path = public
as $$
    with q as (
        select nullif(
            replace(plainto_tsquery('italian', coalesce(p_query, ''))::text, '&', '|'),
            ''
        )::tsquery as query
    )
    select c.id, c.species, c.topic, c.title, c.body, c.source, c.source_level, c.language,
           ts_rank(to_tsvector('italian', c.title || ' ' || c.topic || ' ' || c.body), q.query)
               as rank
    from public.health_cards c, q
    where c.status = 'approved'
      and (c.species && array[p_species, 'all'])
      and q.query is not null
      and to_tsvector('italian', c.title || ' ' || c.topic || ' ' || c.body) @@ q.query
    order by rank desc
    limit least(greatest(coalesce(p_limit, 10), 1), 20);
$$;

revoke all on function public.search_health_cards(text, text, integer) from public, anon, authenticated;
grant execute on function public.search_health_cards(text, text, integer) to service_role;
