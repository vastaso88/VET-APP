-- Abbonamenti App Store / Google Play (docs/billing/01_architettura_abbonamenti.md).
--
-- Scritte SOLO dal backend (service_role). Il proprietario legge le proprie
-- righe di store_subscriptions; eventi e token non sono leggibili dall'app.
-- Nessuna credenziale degli store in queste tabelle. Idempotente.

create table if not exists public.store_subscriptions (
    id uuid primary key default gen_random_uuid(),
    owner_id text not null,
    store text not null check (store in ('apple', 'google', 'admin_test')),
    -- Apple originalTransactionId / Google purchase token.
    store_subscription_id text not null,
    latest_transaction_id text,
    product_id text not null,
    plan text not null check (plan in ('plus', 'pro', 'ultra')),
    period text not null check (period in ('monthly', 'yearly')),
    state text not null check (state in (
        'pending', 'active', 'canceled', 'in_grace_period', 'billing_retry', 'on_hold',
        'paused', 'expired', 'revoked', 'refunded', 'replaced'
    )),
    expires_at timestamptz,
    auto_renew boolean not null default false,
    grace_expires_at timestamptz,
    revoked_at timestamptz,
    environment text not null default 'production',
    last_event_at timestamptz not null default now(),
    last_verified_at timestamptz not null default now(),
    verification_error_at timestamptz,
    anomaly text,
    created_at timestamptz not null default now(),
    -- Una sottoscrizione dello store appartiene a un solo account.
    constraint store_subscriptions_store_id_unique unique (store, store_subscription_id)
);
create index if not exists idx_store_subscriptions_owner on public.store_subscriptions(owner_id);
create index if not exists idx_store_subscriptions_verified
    on public.store_subscriptions(last_verified_at);

-- Ogni notifica una sola volta (idempotenza): Apple notificationUUID, Pub/Sub messageId.
create table if not exists public.store_events (
    store text not null,
    event_id text not null,
    notification_type text not null,
    owner_id text,
    store_subscription_id text,
    signed_at timestamptz not null,
    received_at timestamptz not null default now(),
    outcome text not null,
    primary key (store, event_id)
);
create index if not exists idx_store_events_owner on public.store_events(owner_id);

-- Token pseudonimo (appAccountToken / obfuscatedAccountId) -> account.
create table if not exists public.store_account_tokens (
    owner_id text primary key,
    account_token text not null unique,
    created_at timestamptz not null default now()
);

alter table public.store_subscriptions enable row level security;
alter table public.store_events enable row level security;
alter table public.store_account_tokens enable row level security;

drop policy if exists store_subscriptions_select_own on public.store_subscriptions;
create policy store_subscriptions_select_own
on public.store_subscriptions
for select
using (owner_id = auth.uid()::text);

-- store_events e store_account_tokens: nessuna policy = nessun accesso con la
-- chiave publishable/anon; solo il backend (service_role) li legge e scrive.
-- Le policy *_own richieste per le tabelle nuove: lettura in sola visione
-- per la propria riga anche qui, mai scrittura.
drop policy if exists store_events_select_own on public.store_events;
create policy store_events_select_own
on public.store_events
for select
using (owner_id = auth.uid()::text);

drop policy if exists store_account_tokens_select_own on public.store_account_tokens;
create policy store_account_tokens_select_own
on public.store_account_tokens
for select
using (owner_id = auth.uid()::text);

revoke insert, update, delete on public.store_subscriptions from anon, authenticated;
revoke insert, update, delete on public.store_events from anon, authenticated;
revoke insert, update, delete on public.store_account_tokens from anon, authenticated;
