-- CANCELLAZIONE DELL'ACCOUNT CON PERIODO DI RIPENSAMENTO.
-- Idempotente. Da eseguire PRIMA di mettere online il backend che la usa: senza
-- la tabella, "Elimina account" risponde con un errore e nessun account viene
-- disattivato (il resto dell'app funziona).
--
-- Chi elimina l'account lo vede disattivato subito (il backend risponde 403
-- `account_deactivated` a ogni richiesta, gli annunci del Mercatino spariscono
-- per gli altri) e i dati restano bloccati. Alla scadenza (purge_after,
-- calcolata dall'impostazione ACCOUNT_DELETION_GRACE_DAYS, oggi 30 giorni) un
-- lavoro del backend cancella dati e identita' con lo stesso eraser
-- dell'eliminazione immediata, poi toglie questa riga. Entro la scadenza chi
-- accede con la stessa e-mail (password reimpostabile con il link e-mail) puo'
-- annullare l'eliminazione.
--
-- La scrive solo il backend con la chiave service: nessuna policy di scrittura,
-- scritture tolte ai ruoli anon e authenticated. L'utente legge solo la propria
-- riga. Gestita dal lavoro di fine periodo (supabase_account_eraser.
-- HANDLED_ELSEWHERE): la riga si toglie per ultima.

create table if not exists public.account_deletion_requests (
    owner_id text primary key,
    requested_at timestamptz not null default now(),
    purge_after timestamptz not null
);

create index if not exists idx_account_deletion_requests_purge_after
    on public.account_deletion_requests (purge_after);

alter table public.account_deletion_requests enable row level security;

drop policy if exists account_deletion_requests_select_own on public.account_deletion_requests;
create policy account_deletion_requests_select_own
on public.account_deletion_requests
for select
using (owner_id = auth.uid()::text);

revoke insert, update, delete on public.account_deletion_requests from anon, authenticated;
