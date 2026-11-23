-- Mercatino: conferma di chi vende e controllo del team (decisioni del proprietario,
-- 2026-11-23; docs/compliance/24). Idempotente. Lo stesso blocco sta in
-- supabase_schema.sql (un test controlla che i due restino allineati).
--
-- Un annuncio il cui testo nomina cibo, integratori o una parola ambigua
-- ("antipulci", "shampoo") si pubblica subito dopo una conferma; il team lo controlla
-- dopo e puo' toglierlo. Se nessuno interviene, resta.
--
-- marketplace_listing_reviews: la conferma (data e versione del testo spuntato), cio'
-- che e' stato confermato e la decisione del team. Si cancella con l'annuncio o con
-- l'account. Si legge e si scrive SOLO dal backend (service_role): la riga contiene
-- la nota e l'id dell'amministratore, che chi vende non deve vedere. Per questo a
-- anon e authenticated e' tolto ogni privilegio; RLS e policy *_own restano come
-- seconda difesa.

create table if not exists public.marketplace_listing_reviews (
    id text primary key,
    listing_id text not null
        references public.marketplace_listings(id) on delete cascade,
    owner_id text not null,
    status text not null default 'open'
        check (status in ('open', 'checked', 'removed', 'superseded')),
    title text not null check (char_length(title) <= 200),
    description text check (description is null or char_length(description) <= 4000),
    category text not null,
    photo_urls jsonb not null default '[]'::jsonb,
    terms jsonb not null default '[]'::jsonb,
    notices jsonb not null default '[]'::jsonb,
    confirmed_at timestamptz not null default now(),
    confirmation_version text not null check (char_length(confirmation_version) <= 32),
    decided_at timestamptz,
    decided_by_admin_id text,
    removal_reason text
        check (removal_reason is null
               or removal_reason in ('food', 'supplement', 'medicine', 'other')),
    note text check (note is null or char_length(note) <= 1000)
);

create index if not exists idx_marketplace_listing_reviews_listing
    on public.marketplace_listing_reviews(listing_id, confirmed_at desc);
create index if not exists idx_marketplace_listing_reviews_owner
    on public.marketplace_listing_reviews(owner_id);
create index if not exists idx_marketplace_listing_reviews_status
    on public.marketplace_listing_reviews(status, confirmed_at);
create index if not exists idx_marketplace_listings_owner
    on public.marketplace_listings(owner_id, created_at desc);

alter table public.marketplace_listing_reviews enable row level security;

drop policy if exists marketplace_listing_reviews_select_own
    on public.marketplace_listing_reviews;
create policy marketplace_listing_reviews_select_own
on public.marketplace_listing_reviews
for select
using (owner_id = auth.uid()::text);

revoke all on table public.marketplace_listing_reviews from anon, authenticated;

-- Registro delle decisioni del team: senza il testo e senza l'id di chi vende, quindi
-- resta dopo la cancellazione dell'annuncio e dell'account (24 mesi). Solo backend:
-- nessuna policy per gli utenti (RLS attiva = nessuno legge), privilegi tolti.
create table if not exists public.marketplace_listing_decision_log (
    id text primary key,
    listing_id text not null,
    outcome text not null check (outcome in ('checked', 'removed', 'restored')),
    reason text check (reason is null or reason in ('food', 'supplement', 'medicine', 'other')),
    admin_id text not null,
    decided_at timestamptz not null default now()
);

create index if not exists idx_marketplace_listing_decision_log_date
    on public.marketplace_listing_decision_log(decided_at);

alter table public.marketplace_listing_decision_log enable row level security;
revoke all on table public.marketplace_listing_decision_log from anon, authenticated;

-- Foto degli annunci tolti dal team: fuori dal bucket pubblico, in questo privato
-- (nessuna policy: ci arriva solo il service_role), finche' il riesame e' possibile.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('marketplace-photos-held', 'marketplace-photos-held', false, 5000000, array['image/jpeg'])
on conflict (id) do update
set public = false,
    file_size_limit = 5000000,
    allowed_mime_types = array['image/jpeg'];

-- Tempi decisi dal proprietario (2026-11-23): un annuncio tolto dal team si cancella, con
-- le foto, 6 mesi dopo la decisione (chi vende puo' cancellarlo prima); il registro dopo
-- 24 mesi. Lo fa il backend ogni ora (POST /admin/lifecycle/prune-removed-listings),
-- perche' da SQL non si cancellano i file.
