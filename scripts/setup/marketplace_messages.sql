-- Mercatino: messaggi dentro l'app (decisione del proprietario, 2026-11-07) e
-- blocco di una persona dal Mercatino da parte del team di moderazione.
-- Un compratore scrive al venditore di un annuncio e nessuno dei due conosce il
-- numero, l'e-mail o l'id dell'altro. Idempotente. Lo stesso blocco sta in
-- supabase_schema.sql (un test controlla che i due restino allineati).
--
-- Si scrive e si legge SOLO dal backend (chiave service_role, che non passa da
-- RLS): lì stanno le regole (partecipazione, abbonamento, blocchi, limite
-- giornaliero, annuncio chiuso). Per questo a anon e authenticated è tolto ogni
-- privilegio: leggere direttamente una conversazione mostrerebbe l'id dell'altra
-- persona. RLS e policy *_own restano come seconda difesa, nel caso i privilegi
-- venissero ridati per errore; nessuna policy permette di scrivere.

create table if not exists public.marketplace_conversations (
    id text primary key,
    -- Null quando l'annuncio viene cancellato: la conversazione resta leggibile.
    listing_id text references public.marketplace_listings(id) on delete set null,
    listing_title text not null check (char_length(listing_title) <= 200),
    buyer_id text not null,
    seller_id text not null,
    buyer_unread integer not null default 0 check (buyer_unread >= 0),
    seller_unread integer not null default 0 check (seller_unread >= 0),
    moderation_closed_at timestamptz,
    created_at timestamptz not null default now(),
    last_message_at timestamptz not null default now(),
    check (buyer_id <> seller_id)
);

create table if not exists public.marketplace_messages (
    id text primary key,
    conversation_id text not null
        references public.marketplace_conversations(id) on delete cascade,
    sender_id text not null,
    body text not null check (char_length(body) between 1 and 1000),
    created_at timestamptz not null default now()
);

create table if not exists public.marketplace_user_blocks (
    blocker_id text not null,
    blocked_id text not null,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id)
);

create table if not exists public.marketplace_conversation_reports (
    id text primary key,
    conversation_id text not null
        references public.marketplace_conversations(id) on delete cascade,
    reporter_id text not null,
    reason text not null
        check (reason in ('spam', 'scam', 'harassment', 'inappropriate', 'other')),
    status text not null default 'open' check (status in ('open', 'dismissed', 'resolved')),
    resolution_action text,
    resolution_note text check (resolution_note is null or char_length(resolution_note) <= 1000),
    resolved_at timestamptz,
    resolved_by_admin_id text,
    created_at timestamptz not null default now(),
    unique (conversation_id, reporter_id)
);

create table if not exists public.marketplace_user_restrictions (
    -- Una riga per persona: il team la tiene fuori dal Mercatino (niente annunci
    -- nuovi, niente modifiche, niente messaggi). Annullare il blocco riempie
    -- lifted_at e lascia la riga, con chi e quando.
    owner_id text primary key,
    reason text not null
        check (reason in ('spam', 'scam', 'harassment', 'prohibited_items', 'other')),
    note text check (note is null or char_length(note) <= 1000),
    created_at timestamptz not null default now(),
    created_by_admin_id text,
    lifted_at timestamptz,
    lifted_by_admin_id text
);

-- Una sola conversazione per annuncio e compratore. I NULL (annuncio cancellato)
-- non collidono tra loro.
create unique index if not exists idx_marketplace_conversations_listing_buyer
    on public.marketplace_conversations(listing_id, buyer_id);
create index if not exists idx_marketplace_conversations_buyer
    on public.marketplace_conversations(buyer_id, last_message_at desc);
create index if not exists idx_marketplace_conversations_seller
    on public.marketplace_conversations(seller_id, last_message_at desc);
create index if not exists idx_marketplace_messages_conversation
    on public.marketplace_messages(conversation_id, created_at desc);
create index if not exists idx_marketplace_messages_sender
    on public.marketplace_messages(sender_id);
create index if not exists idx_marketplace_user_blocks_blocked
    on public.marketplace_user_blocks(blocked_id);
create index if not exists idx_marketplace_conversation_reports_reporter
    on public.marketplace_conversation_reports(reporter_id);
create index if not exists idx_marketplace_conversation_reports_status
    on public.marketplace_conversation_reports(status, created_at desc);

alter table public.marketplace_conversations enable row level security;
alter table public.marketplace_messages enable row level security;
alter table public.marketplace_user_blocks enable row level security;
alter table public.marketplace_conversation_reports enable row level security;
alter table public.marketplace_user_restrictions enable row level security;

drop policy if exists marketplace_conversations_select_own on public.marketplace_conversations;
create policy marketplace_conversations_select_own
on public.marketplace_conversations
for select
using (buyer_id = auth.uid()::text or seller_id = auth.uid()::text);

drop policy if exists marketplace_messages_select_own on public.marketplace_messages;
create policy marketplace_messages_select_own
on public.marketplace_messages
for select
using (sender_id = auth.uid()::text);

drop policy if exists marketplace_user_blocks_select_own on public.marketplace_user_blocks;
create policy marketplace_user_blocks_select_own
on public.marketplace_user_blocks
for select
using (blocker_id = auth.uid()::text);

drop policy if exists marketplace_conversation_reports_select_own
    on public.marketplace_conversation_reports;
create policy marketplace_conversation_reports_select_own
on public.marketplace_conversation_reports
for select
using (reporter_id = auth.uid()::text);

revoke all on table public.marketplace_conversations from anon, authenticated;
revoke all on table public.marketplace_messages from anon, authenticated;
revoke all on table public.marketplace_user_blocks from anon, authenticated;
revoke all on table public.marketplace_conversation_reports from anon, authenticated;
revoke all on table public.marketplace_user_restrictions from anon, authenticated;

drop policy if exists marketplace_user_restrictions_select_own
    on public.marketplace_user_restrictions;
create policy marketplace_user_restrictions_select_own
on public.marketplace_user_restrictions
for select
using (owner_id = auth.uid()::text);

-- Chi è bloccato non pubblica né modifica annunci nemmeno scrivendo direttamente
-- nella tabella con la propria sessione (finché le policy insert/update esistono:
-- marketplace_lock_writes.sql le toglie). La funzione guarda solo chi chiama, così
-- nessuno può chiedere se un'altra persona è bloccata.
create or replace function public.marketplace_caller_is_restricted()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.marketplace_user_restrictions r
        where r.owner_id = auth.uid()::text and r.lifted_at is null
    );
$$;
revoke all on function public.marketplace_caller_is_restricted()
    from public, anon, authenticated;
grant execute on function public.marketplace_caller_is_restricted()
    to authenticated;

drop policy if exists marketplace_listings_insert_not_restricted on public.marketplace_listings;
create policy marketplace_listings_insert_not_restricted
on public.marketplace_listings
as restrictive
for insert
to authenticated
with check (not public.marketplace_caller_is_restricted());

drop policy if exists marketplace_listings_update_not_restricted on public.marketplace_listings;
create policy marketplace_listings_update_not_restricted
on public.marketplace_listings
as restrictive
for update
to authenticated
using (not public.marketplace_caller_is_restricted())
with check (not public.marketplace_caller_is_restricted());

-- Conservazione (decisione del proprietario, 2026-11-07): la conversazione si
-- cancella 6 mesi dopo l'ultimo messaggio se l'annuncio è chiuso, 12 mesi dopo
-- l'ultimo messaggio comunque; mai finché ha una segnalazione aperta. Messaggi e
-- segnalazioni seguono la conversazione (on delete cascade). I blocchi tra utenti
-- restano finché esiste l'account; un blocco del team annullato da più di 12 mesi
-- si cancella, uno in vigore resta.
create or replace function public.marketplace_messages_cleanup()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    conversation_rows integer;
    restriction_rows integer;
begin
    delete from public.marketplace_conversations c
    where not exists (
            select 1 from public.marketplace_conversation_reports r
            where r.conversation_id = c.id and r.status = 'open'
        )
        and (
            c.last_message_at < now() - interval '12 months'
            or (
                c.last_message_at < now() - interval '6 months'
                and (
                    c.listing_id is null
                    or c.moderation_closed_at is not null
                    or exists (
                        select 1 from public.marketplace_listings l
                        where l.id = c.listing_id and l.status not in ('active', 'reserved')
                    )
                )
            )
        );
    get diagnostics conversation_rows = row_count;
    delete from public.marketplace_user_restrictions
    where lifted_at is not null and lifted_at < now() - interval '12 months';
    get diagnostics restriction_rows = row_count;
    return jsonb_build_object(
        'marketplace_conversations', conversation_rows,
        'marketplace_user_restrictions', restriction_rows
    );
end;
$$;
revoke all on function public.marketplace_messages_cleanup()
    from public, anon, authenticated;
grant execute on function public.marketplace_messages_cleanup()
    to service_role;

-- La riga per la pulizia automatica, ogni notte alle 03:30 UTC. Serve pg_cron
-- (Supabase: Database > Extensions); senza, questo blocco non fa nulla.
do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.unschedule(jobid)
            from cron.job where jobname = 'vetapp-marketplace-messages-cleanup';
        perform cron.schedule(
            'vetapp-marketplace-messages-cleanup',
            '30 3 * * *',
            'select public.marketplace_messages_cleanup()'
        );
    end if;
end
$$;
