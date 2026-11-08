-- ETA' DICHIARATA (parere docs/compliance/10_pareri_dal_2026_11_06.md §3).
-- Da eseguire PRIMA di mettere online il backend che la usa: finche' la tabella
-- non esiste, il Mercatino e la scelta di un piano a pagamento rispondono
-- 403 `age_required` a tutti (falliscono chiusi); il resto dell'app funziona.
-- Idempotente.
--
-- La data di nascita sta in una tabella a parte, non in user_metadata
-- (che l'utente puo' modificare da se'). La scrive solo il backend con la
-- chiave service: nessuna policy di scrittura, scritture tolte ai ruoli
-- anon e authenticated. L'utente puo' leggere solo la propria riga.
-- Mai mostrata ad altri, mai nei log, cancellata con l'account
-- (supabase_account_eraser.OWNER_TABLES).

create table if not exists public.account_age (
    owner_id text primary key,
    birth_date date not null,
    declared_at timestamptz not null default now(),
    -- Quando un minorenne (14-17) ha confermato di avere l'autorizzazione
    -- di un genitore per un piano a pagamento.
    guardian_ok_at timestamptz
);

alter table public.account_age enable row level security;

drop policy if exists account_age_select_own on public.account_age;
create policy account_age_select_own
on public.account_age
for select
using (owner_id = auth.uid()::text);

revoke insert, update, delete on public.account_age from anon, authenticated;

-- Correzione di una data dichiarata male (diritto di rettifica, art. 16 GDPR):
-- la fa il supporto, dopo aver verificato chi scrive, con
--   update public.account_age set birth_date = 'AAAA-MM-GG' where owner_id = '<id>';
