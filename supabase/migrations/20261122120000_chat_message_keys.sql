-- QK-03b: one answer per chat message, even when two serverless instances receive the same
-- message at the same moment.
--
-- The app gives every message its own id (client_message_id) and sends it again on a retry.
-- Before the model is called, the backend reserves (owner_id, client_message_id) here with an
-- insert ... on conflict do nothing: the instance that inserts it answers; a duplicate finds
-- the key, waits, and then finds the answer already stored in conversations. The table is a
-- LOCK only: whether a message was answered is always read from conversations, never from here.
--
-- Only ids and dates are stored: no message text, no e-mail, no name. Keys older than 30 days
-- are removed by the hourly job (POST /admin/lifecycle/prune-chat-message-keys); the account
-- deletion and the data export read it like the other owner tables.
--
-- Backend only: the backend talks to Supabase with the service_role key. RLS is on and the
-- "own rows only" policy is written for completeness; authenticated and anon get no grant.
-- Idempotent: safe to run more than once. Until it is run, the backend works with the lock
-- inside each process (and says so in its log, once every few minutes).
create table if not exists public.chat_message_keys (
    owner_id text not null,
    client_message_id text not null,
    conversation_id text not null,
    claimed_at timestamptz not null default now(),
    answered_reply_id text,
    primary key (owner_id, client_message_id)
);
create index if not exists idx_chat_message_keys_claimed_at
    on public.chat_message_keys(claimed_at);

alter table public.chat_message_keys enable row level security;
revoke all on public.chat_message_keys from public, anon, authenticated;
grant select, insert, update, delete on public.chat_message_keys to service_role;

drop policy if exists chat_message_keys_own on public.chat_message_keys;
create policy chat_message_keys_own on public.chat_message_keys
    for select to authenticated
    using (owner_id = (select auth.uid())::text);
